#!powershell

# Copyright: (c) 2019, Simon Baerlocher <s.baerlocher@sbaerlocher.ch>
# Copyright: (c) 2019, ITIGO AG <opensource@itigo.ch>
# Copyright: (c) 2021, Striveworks Inc.
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$spec = @{
    options = @{
        mount        = @{ type = "str"; required = $true }
        state        = @{ type = "str"; required = $false ; default='enabled'; choices= 'enabled','disabled' }
        encryption   = @{ type = "str"; required = $false; choices = 'Aes128','Aes256','XtsAes128','XtsAes256' }
        keyprotector = @{
            type = 'str'
            default = 'RecoveryPasswordProtector'
            choices = 'RecoveryPasswordProtector', 'TpmProtector'
        }
        backup_to_ad        = @{ type = "bool" }
        hardware_encryption = @{ type = "bool" }
        skip_hardware_test  = @{ type = "bool" }
        used_space_only     = @{ type = "bool" }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$mount        = $module.Params.mount
$state        = $module.Params.state
$keyprotector = $module.Params.keyprotector
$backup2AD    = $module.Params.backup_to_ad
# Create hashtables for parameter splatting of several other optional parameters, later
if ([string]::IsNullOrEmpty($module.Params.encryption)) { $encryptionParam=@{} } else { $encryptionParam=@{'EncryptionMethod'=$module.Params.encryption} }
$hardwareEncrParam=@{'HardwareEncryption'=[Boolean]$module.Params.hardware_encryption}
$skipHardwareTestParam=@{'SkipHardwareTest'=[Boolean]$module.Params.skip_hardware_test}
$usedSpaceOnlyParam=@{'UsedSpaceOnly'=[Boolean]$module.Params.used_space_only}

# Create a new result object
$ret = @{
    changed = $false
    after = $Null
    before = $Null
    value = @()
}

# Start Time of the script, will be used to search the Windows Event logs for BitLocker events after this time.
$StartScriptTime = Get-Date

# BitLockering multiple drives; a typical configuration is where the C: drive is protected by TPM (TPM can only protect the OS volume),
#   then the other volumes (data) are protected with information stored on the C: volume itself.
# DriveType 3: LocalDisk - https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-logicaldisk
$AllLocalVolumes = @( Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object -ExpandProperty DeviceID )
$AllDataVolumes = $AllLocalVolumes | Where-Object { $_ -notin $Env:SystemDrive }
switch -Regex ($mount.ToString().Trim()) {
    '^[C-Z]\:$' { if ($_ -in $AllLocalVolumes) { $runOnVolumes = $_ } else { Write-Error "Volume $_ is not found locally" }; Break }
    '^All$'     { $runOnVolumes = $AllLocalVolumes ; Break }
    '^Data$'    { $runOnVolumes = $AllDataVolumes ; Break }
    '^OS$'      { $runOnVolumes = $Env:SystemDrive; Break }
    default     { $runOnVolumes = $Null ; Write-Error "$_ is not found, no action"}
}

# The Enable-BitLockerAutoUnlock cmdlet enables automatic unlocking for a volume protected by BitLocker Disk Encryption.
# You can configure BitLocker to automatically unlock volumes that do not host an operating system.
#   After a user unlocks the operating system volume, BitLocker uses encrypted information stored in the registry and volume
#   metadata to unlock any data volumes that use automatic unlocking.

if ($state -eq "enabled") {
    foreach ($runVolume in $runOnVolumes) {
        $protectionstatus = (Get-BitLockerVolume -MountPoint $runVolume).ProtectionStatus
        if ( $protectionstatus -eq "Off" ) {
            if (-not $module.CheckMode) {
                # Assume -TpmProtector  is used... But replace it with another one (RecoveryPasswordProtector) if NOT BitLockering the SystemDrive or if the arguments specify so.
                $ProtectorParam = @{"TpmProtector"=$True}
                if ( ($keyprotector -eq "RecoveryPasswordProtector") -or ($runVolume -ne $Env:SystemDrive) ) {
                    $ProtectorParam = @{"RecoveryPasswordProtector"=$True}
                }
                try {
                    $res = Enable-BitLocker -MountPoint $runVolume @ProtectorParam @encryptionParam @hardwareEncrParam @skipHardwareTestParam @usedSpaceOnlyParam -ErrorAction Stop
                    $ret.value += $res
                } catch {
                    $module.FailJSON("Error enabling BitLocker", $_)
                }
                # if NOT BitLockering the system volume, add autounlock to the datadrives
                if ($runVolume -ne $Env:SystemDrive) {
                    try {
                        $res = Enable-BitLockerAutoUnlock -MountPoint $runVolume -ErrorAction Stop
                        $ret.value += $res
                    } catch {
                        $module.FailJSON("Error enabling BitLocker Autounlock for non-system volumes", $_)
                    }
                }
            }
            $ret.changed = $true
        }

        if ($backup2AD) {

            # Always backup to (A)AD, even if the old protectionstatus was already On
            # Backup the BitLocker Recovery key to (A)AD... (if configured)
            # DomainRole: 0 = workgroup workstation, 1 = domain joined workstation, 2 = workgroup server, 3 = domain joined server, 4 = (Backup) Domain Controller, 5 = (Primary) Domain Controller
            $DomainRole = (Get-CimInstance -ClassName win32_ComputerSystem).DomainRole
            $RecoveryKeyProtector = Get-BitLockerVolume -MountPoint $runVolume | Select-Object -ExpandProperty KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
            if ($RecoveryKeyProtector) {    # if AD Domain joined...
                if ($DomainRole -in (1,3,4,5)) {
                    try {
                        $res = Backup-BitLockerKeyProtector -MountPoint $runVolume -KeyProtectorId $RecoveryKeyProtector.KeyProtectorId -ErrorAction Stop
                        $ret.value += $res
                    } catch {
                        $module.Warn([string]::Format("Device is AD Joined, backup to Active Directory failed: {0}", $_.ToString() ))
                    }
                } else { # Non AD-joined, maybe AAD joined or -enrolled.
                    if ((dsregcmd /status ) -match 'AzureAdJoined\s*\:\s*YES') {
                        try {
                            $res = BackupToAAD-BitLockerKeyProtector -MountPoint $runVolume -KeyProtectorId $RecoveryKeyProtector.KeyProtectorId -ErrorAction Stop
                            $ret.value += $res
                            # Retrieve from the Windows Eventlog whether backup was successful:
                            Start-Sleep -Seconds 2
                            $WinEvents = Get-WinEvent -FilterHashTable @{LogName='Microsoft-Windows-BitLocker/BitLocker Management';Id=845; StartTime=$StartScriptTime} -ErrorAction SilentlyContinue
                            if ($WinEvents) { $module.LogEvent("$WinEvents.Message")}
                            else {
                                $WinEvents = Get-WinEvent -FilterHashTable @{LogName='Microsoft-Windows-BitLocker/BitLocker Management';Id=846; StartTime=$StartScriptTime} -ErrorAction SilentlyContinue
                                if ($WinEvents) { $module.Warn("$WinEvents.Message")}
                                else {
                                    $module.warn("Error backing up... no Windows event found")
                                }
                            }
                        } catch {
                            $module.Warn([string]::Format("Device is Azure AD Joined, backup to Azure Active Directory failed: {0}", $_.ToString() ))
                        }
                    } else {
                        $module.Warn("Device is not AD joined, nor Azure AD joined, cannot backup key to (A)AD")
                    }
                }
            }
        } else {
            $module.Warn("NOT backing up BitLocker recovery information to (A)AD since bitlocker_backup_to_ad is False")
        }
    }
}

if ($state -eq "disabled") {
    foreach ($runVolume in $runOnVolumes) {
        $protectionstatus = (Get-BitLockerVolume -MountPoint $runVolume).ProtectionStatus
        if ( $protectionstatus -eq "On" ) {
            if (-not $module.CheckMode) {
                Disable-BitLocker -MountPoint $mount
            }
            $ret.changed = $true
        }
    }
}

# # Return result
# Exit-Json -obj $result

# Return information
$module.Diff.before = @( 'C:\' )
$module.Diff.after = @( 'C:' )

$module.Result.changed = $ret.changed
$module.Result.value = $ret.value

$module.ExitJson()
