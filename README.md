# Ansible Role: bitlocker

[![Build Status](https://img.shields.io/travis/itigoag/ansible.bitlocker.svg?branch=master&style=popout-square)](https://travis-ci.org/itigoag/ansible.bitlocker) [![license](https://img.shields.io/github/license/mashape/apistatus.svg?style=popout-square)](https://sbaerlo.ch/license) [![Ansible Galaxy](http://img.shields.io/badge/ansible--galaxy-bitlocker-blue.svg?style=popout-square)](https://galaxy.ansible.com/itigoag/ansible.bitlocker) [![Ansible Role](https://img.shields.io/ansible/role/d/id.svg?style=popout-square)](https://galaxy.ansible.com/itigoag/bitlocker)

## Description

Enables BitLocker on your Windows machine.

## Installation

```bash
ansible-galaxy install ansible.bitlocker
```

## Requirements
* Windows
  * Windows 8 or higher (tested on Windows 10),
  * Windows Server 2012 or higher.
* TPM module 1.2 or higher

## Role Variables

| Variable             | Default     | Comments (type)                                   |
| :---                 | :---        | :---                                              |
| bitlocker_mount | 'C:' | The mountpoint (driveletter) of the volume to encrypt. This parameter will also support the values: 'All' (Encrypt all volumes), 'OS' (Encrypt the OS volume, typically C:), or 'Data' (Encrypt all non-OS volumes) |
| bitlocker_state | enabled | enabled or disabled |
| bitlocker_encryption | XtsAes256 | encryption algorithm |
| bitlocker_keyprotector | RecoveryPasswordProtector | Key protector to use: RecoveryPasswordProtector or TpmProtector. Note: only the Operating System volume can be protected with TPM, other volumes can be protected with a RecoveryPassword |

TBD: The script will also try to backup the 'Recovery' KeyProtector to AD. This may become optional in a future version

## Dependencies
* No dependencies with other modules

## Example Playbook
Example playbook using all defaults (will enable BitLocker on C:)
```yml
- hosts: all
  roles:
     - ansible.bitlocker
```
Example playbook using modified arguments
```yml
- hosts: Windows
  roles:
    - role: ansible.bitlocker
      bitlocker_encryption: "XtsAes256"
      bitlocker_mount: 'All'
```
Example playbook using variables
```yml
- hosts: Windows
  roles:
    - role: ansible.bitlocker
      vars:
        bitlocker_encryption: "XtsAes128"
        bitlocker_mount: 'C:'
```


## Changelog
* 1.0 Simon Bärlocher; Initial version
* 2.0 Evi Vanoost; added BitLocker facts
* 3.0 Ben van Zanten; moved values to vars, allow multiple volumes to be BitLockered
      Updated the BitLocker scripts to work with variables. Defaults are set in defaults\main.yml,
      variables are 'translated' in the Role file: tasks\main.yml  from 'bitlocker_mount' to 'mount' in the included Module.
      Added new meta/argument_specs.yml to validate the parameters.
      Script can now BitLocker multiple volumes, where the C: drive is protected via a TPM, the other (data) volumes are unlocked via the C: drive.
      Script will also try to backup the recovery information to Active Directory

## Author

* [Simon Bärlocher](https://sbaerlocher.ch)

## License

This project is under the MIT License. See the [LICENSE](https://sbaerlo.ch/license) file for the full license text.

## Copyright

* (c) 2019, Simon Bärlocher
* (c) 2020, Evi Vanoost
* (c) 2021, Ben van Zanten
* (c) 2021, Striveworks Inc.
