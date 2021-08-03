# Ansible Role: bitlocker

[![Build Status](https://img.shields.io/travis/itigoag/ansible.bitlocker.svg?branch=master&style=popout-square)](https://travis-ci.org/itigoag/ansible.bitlocker) [![license](https://img.shields.io/github/license/mashape/apistatus.svg?style=popout-square)](https://sbaerlo.ch/licence) [![Ansible Galaxy](http://img.shields.io/badge/ansible--galaxy-bitlocker-blue.svg?style=popout-square)](https://galaxy.ansible.com/itigoag/bitlocker) [![Ansible Role](https://img.shields.io/ansible/role/d/id.svg?style=popout-square)](https://galaxy.ansible.com/itigoag/bitlocker)

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
| bitlocker_mount | C: | The mountpoint (driveletter) of the volume to encrypt |
| bitlocker_state | enabled | enabled or disabled |
| bitlocker_encryption | XtsAes256 | encryption algorithm |
| bitlocker_keyprotector | RecoveryPasswordProtector | Key protector to use: RecoveryPasswordProtector or TpmProtector |

## Dependencies

## Example Playbook

```yml
- hosts: all
  roles:
     - ansible.bitlocker
```

## Changelog
* 1.0 Simon Bärlocher; Initial version
* 2.0 Evi Vanoost; added BitLocker facts
* 3.0 Ben van Zanten; moved values to vars, allow multiple volumes to be BitLockered

## Author

* [Simon Bärlocher](https://sbaerlocher.ch)

## License

This project is under the MIT License. See the [LICENSE](https://sbaerlo.ch/licence) file for the full license text.

## Copyright

(c) 2019, Simon Bärlocher
(c) 2020, Evi Vanoost
