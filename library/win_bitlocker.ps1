#!powershell

# Copyright: (c) 2019, Simon Baerlocher <s.baerlocher@sbaerlocher.ch>
# Copyright: (c) 2019, ITIGO AG <opensource@itigo.ch>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.ArgvParser
#Requires -Module Ansible.ModuleUtils.CommandUtil
#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$params     = Parse-Args -arguments $args -supports_check_mode $true
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false
$diff       = Get-AnsibleParam -obj $params -name "_ansible_diff"       -type "bool" -default $false

# of the following Parametersets: -AdAccountOrGroupProtector, -PasswordProtector, -TpmAndPinProtector, -TpmAndPinAndStartupKeyProtector, -RecoveryKeyProtector, -RecoveryPasswordProtector, -StartupKeyProtector, -TpmAndStartupKeyProtector, -TpmProtector
#    only the following 2 are currently implemented: -RecoveryPasswordProtector and -TpmProtector.
# Note the Enable-BitLocker cmdlet only allows one of these methods or combinations when you enable encryption, but you can use the Add-BitLockerKeyProtector cmdlet to add other protectors.
$mount        = Get-AnsibleParam -obj $params -name "mount"        -type "str" -failifempty $true
$state        = Get-AnsibleParam -obj $params -name "state"        -type "str" -default "enabled" -validateset "enabled", "disabled"
$encryption   = Get-AnsibleParam -obj $params -name "encryption"   -type "str" -validateset "Aes128","Aes256","XtsAes128","XtsAes256"
$keyprotector = Get-AnsibleParam -obj $params -name "keyprotector" -type "str" -default "RecoveryPasswordProtector" -validateset "RecoveryPasswordProtector","TpmProtector"

# Create a new result object
$result = @{
    changed = $false
}

# Create a hashtable for parameter splatting of 'Encryption' later.
if ([string]::IsNullOrEmpty($encryption)) {
    $encryptionParam=@{}
} else {
    $encryptionParam=@{'EncryptionMethod'=$encryption}
}

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

Add-Warning -obj $result -message "mount: $mount  ; "

# The Enable-BitLockerAutoUnlock cmdlet enables automatic unlocking for a volume protected by BitLocker Disk Encryption.
# You can configure BitLocker to automatically unlock volumes that do not host an operating system.
#   After a user unlocks the operating system volume, BitLocker uses encrypted information stored in the registry and volume
#   metadata to unlock any data volumes that use automatic unlocking.

if ($state -eq "enabled") {
    foreach ($runVolume in $runOnVolumes) {
        $protectionstatus = (Get-BitLockerVolume -MountPoint $runVolume).ProtectionStatus
        if ( $protectionstatus -eq "Off" ) {
            if (-not $check_mode) {
                # Assume -TpmProtector  is used... But replace it with another one (RecoveryPasswordProtector) if NOT BitLockering the SystemDrive or if the arguments specify so.
                $ProtectorParam = @{"TpmProtector"=$True}
                if ( ($keyprotector -eq "RecoveryPasswordProtector") -or ($runVolume -ne $Env:SystemDrive) ) {
                    $ProtectorParam = @{"RecoveryPasswordProtector"=$True}
                }
                $res = Enable-BitLocker -MountPoint $runVolume @ProtectorParam @encryptionParam
                $result.res = $res
                # if NOT BitLockering the system volume, add autounlock to the datadrives
                if ($runVolume -ne $Env:SystemDrive) {
                    $res = Enable-BitLockerAutoUnlock -MountPoint $runVolume
                    $result.res += $res
                }

                # Backup the BitLocker Recovery key to AD... (if configured. Todo: parameterize this)
                $RecoveryKeyProtector = Get-BitLockerVolume -MountPoint $runVolume | Select-Object -ExpandProperty KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
                if ($RecoveryKeyProtector) {
                    $res = Backup-BitLockerKeyProtector -MountPoint $runVolume -KeyProtectorId $RecoveryKeyProtector.KeyProtectorId
                    $result.res += $res
                }
            }
            $result.changed = $true
        }
    }
}

if ($state -eq "disabled") {
    foreach ($runVolume in $runOnVolumes) {
        $protectionstatus = (Get-BitLockerVolume -MountPoint $runVolume).ProtectionStatus
        if ( $protectionstatus -eq "On" ) {
            if (-not $check_mode) {
                Disable-BitLocker -MountPoint $mount
            }
            $result.changed = $true
        }
    }
}

# Return result
Exit-Json -obj $result
