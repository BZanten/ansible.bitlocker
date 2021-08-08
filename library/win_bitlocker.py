#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2021, B. v. Zanten
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_bitlocker
short_description: Configure BitLocker volume encryption
description:
    - Configure BitLocker (Full Volume Encryption) on harddisk volumes.
options:
  mount:
    description:
      - Mountpoint to encrypt, like C: or D:
    required: yes
    type: str
  state:
    description:
      - enabled or disabled
    required: no
    type: str
  encryption:
    description:
      - Algorithm to use:  'Aes128','Aes256','XtsAes128','XtsAes256'
    required: no
    type: str
  keyprotector:
    description:
      - How is the BitLocker key protected, possibilities: TpmProtector, RecoveryPasswordProtector
    required: no
    type: str
  backup_to_ad:
    description:
      - (Try to) backup the Recovery key protector to (Azure) AD
    required: no
    type: bool
  hardware_encryption:
    description:
      - Use disk hardware to encrypt the contents
    required: no
    type: bool
  skip_hardware_test:
    description:
      - Allow BitLocker without a TPM
    required: no
    type: bool
  used_space_only:
    description:
      - default: false; if set will only ecrypt disk sectors that contain data, not empty sectors
    required: no
    type: bool

notes:
- The module can BitLocker multiple volumes, typically the C:/OS volume is protected by the TPM, the other (Data) volumes are protected with information stored on the C: drive

author:
- Ben van Zanten (BZanten)
'''

EXAMPLES = r'''
- name: Configure BitLocker
  win_bitlocker:
    mount: 'C:'

- name: Configure BitLocker
  win_bitlocker:
    mount: 'OS'
    state: 'enabled'
    used_space_only: 'true'

'''

RETURN = r'''
value:
  description: Typical output from 'Get-BitLockerVolume'
  returned: always
  type: str
  sample: False

'''
