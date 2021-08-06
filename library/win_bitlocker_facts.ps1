#!powershell

# Copyright: (c) 2019, Simon Baerlocher <s.baerlocher@sbaerlocher.ch>
# Copyright: (c) 2019, ITIGO AG <opensource@itigo.ch>
# Copyright: (c) 2020, Evi Vanoost <evi.vanoost@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

# This modules does not accept any options
$spec = @{
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$module.LogEvent("Get-BitLockerVolume",'Information',$True)

# Return information
$module.Result.changed = $False
$module.Result.ansible_facts = @{
    ansible_bitlocker = @( Get-BitLockerVolume )
}

$module.ExitJson()
