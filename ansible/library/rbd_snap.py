#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright (c) 2017 Tomas Rusnak <trusnak@redhat.com>
#
# This module is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this software.  If not, see <http://www.gnu.org/licenses/>.

ANSIBLE_METADATA = {'metadata_version': '1.0',
                    'status': ['preview'],
                    'supported_by': 'community'}

DOCUMENTATION = '''
---
module: rbd_snap
short_description: Manages ceph RBD snapshots
description:
  - Manages ceph rbd snapshot command line tool
  version_added: "1.0"
options:
  status:
    description:
      - manage rbd snapshots
    required: True
    default: none
'''

import sys
import json
import os
from ansible.module_utils.basic import AnsibleModule

def convert_size(snap_info):
  ''' convert size to be compatible with OSP '''
  snap_info['size'] = str(int(snap_info['size'])/(1024**2))
  return snap_info

def cmd_check_snap(m, params):
  ''' check if snapshot exists '''
  rc, out, err = m.run_command("rbd snap list %s/%s@%s --format json" % 
    (params['pool'], params['name'], params['snap']))
  if rc:
    return False
  return convert_size(json.loads(out))

def cmd_runner(m, params):
  ''' command runner/parser '''
  snap_info = cmd_check_snap(m, params)
  if params['state'] == 'present':
    if snap_info:
      return False, False, dict(snap=snap_info)
    else:
      rc, out, err = m.run_command("rbd snap create -s %s %s/%s@%s" % (str(params['size']), 
        params['pool'], params['name'], params['snap']))
      if rc:
        return True, False, dict(msg="failed: '%s'" % (err), stdout=out, stderr=err)
      return False, True, dict(snap=cmd_check_snap(m, params))
  if params['state'] == 'absent':
    if snap_info:
      rc, out, err = m.run_command("rbd snap rm %s/%s@%s" % (params['pool'], params['name']),
        params['snap'])
      if rc == 16:
        return True, False, dict(msg="snapshot is protected from removal: '%s'" %
          (err), stdout=out, stderr=err)
      if rc:
        return True, False, dict(msg="failed: '%s'" % (err), stdout=out, stderr=err)
      return False, True, dict(msg="snapshot removed")
    else:
      return False, False, dict(msg="snapshot doesn't exists")
  if params['state'] == 'protect':
    if snap_info:
      rc, out, err = m.run_command("rbd snap protect %s/%s@%s" % (params['pool'], params['name']),
        params['snap'])
      if rc == 16:
        return False, False, dict(msg="snapshot is already protected: '%s'" % (err), stdout=out, stderr=err)
      if rc:
        return True, False, dict(msg="failed: '%s'" % (err), stdout=out, stderr=err)
      return False, True, dict(snap=cmd_check_snap(m, params))
    else:
      return False, False, dict(msg="snapshot doesn't exists")
  if params['state'] == 'unprotect':
    if snap_info:
      rc, out, err = m.run_command("rbd snap unprotect %s/%s@%s" % (params['pool'], params['name']),
        params['snap'])
      if rc == 22:
        return False, False, dict(msg="snapshot is already unprotected: '%s'" % (err), stdout=out, stderr=err)
      if rc:
        return True, False, dict(msg="failed: '%s'" % (err), stdout=out, stderr=err)
      return False, True, dict(snap=cmd_check_snap(m, params))
    else:
      return False, False, dict(msg="snapshot doesn't exists")
  if params['state'] == 'rollback':
    if snap_info:
      rc, out, err = m.run_command("rbd snap rollback %s/%s@%s" % (params['pool'], params['name'], 
        params['snap']))
      if rc:
        return True, False, dict(msg="failed: '%s'" % (err), stdout=out, stderr=err)
      return False, True, dict(snap=cmd_check_snap(m, params))
    else:
      return False, False, dict(msg="snapshot doesn't exists")
  if params['state'] == 'rename':
    if snap_info:
      rc, out, err = m.run_command("rbd snap rename %s/%s@%s %s/%s@%s" % (params['pool'], params['name'], 
        params['snap'], params['destpool'], params['name'], params['destsnap']))
      if rc:
        return True, False, dict(msg="failed: '%s'" % (err), stdout=out, stderr=err)
      return False, True, dict(snap=cmd_check_snap(m, params))
    else:
      return False, False, dict(msg="snapshot doesn't exists")



def main():

  module = AnsibleModule(argument_spec={
      "state": {
        "required": True,
        "choices": ['present', 'absent', 'protect', 'unprotect', 'rollback', 'rename'],
        "type": "str",
      },
      "name": {
        "required": True,
        "default": None,
        "type": "str",
      },
      "pool": {
        "required": False,
        "default": "volumes",
        "type": "str"
      },
       "snap": {
        "required": False,
        "default": None,
        "type": "str",
      },
      "destpool": {
        "required": False,
        "default": "volumes",
        "type": "str"
      },
       "destsnap": {
        "required": False,
        "default": None,
        "type": "str",
      },
    },
    supports_check_mode=True)

  if 'state' in module.params and module.params['state']:
    is_error, has_changed, result = cmd_runner(module, module.params)
  if not is_error:
    module.exit_json(changed=has_changed, **result)
  else:
    module.fail_json(msg="Error", meta=result)

if __name__ == "__main__":
  main()

