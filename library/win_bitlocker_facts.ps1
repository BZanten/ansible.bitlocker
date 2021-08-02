#!powershell

# Copyright: (c) 2019, Simon Baerlocher <s.baerlocher@sbaerlocher.ch> 
# Copyright: (c) 2019, ITIGO AG <opensource@itigo.ch>
# Copyright: (c) 2020, Evi Vanoost <evi.vanoost@gmail.com> 
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.ArgvParser
#Requires -Module Ansible.ModuleUtils.CommandUtil
#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

# Create a new result object
$result = @{
    changed       = $false
    ansible_facts = @{
        ansible_bitlocker = @()
    }
}

$result.ansible_facts.ansible_bitlocker = @(Get-BitlockerVolume)

Exit-Json -obj $result
