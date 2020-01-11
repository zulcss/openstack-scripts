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
module: rbd_image
short_description: Manages ceph RBD images
description:
  - Manages ceph rbd image command line tool
  version_added: "1.0"
options:
  status:
    description:
      - manage rbd images
    required: True
    default: none
'''

import sys
import json
import os
from ansible.module_utils.basic import AnsibleModule

def image_convert_size(image_info):
  ''' covert size of the image to be compatible with OSP '''
  image_info['object_size'] = str(int(image_info['object_size'])/(1024**2))
  return image_info

def cmd_check_image(m, params):
  ''' check if image exists '''
  rc, out, err = m.run_command("rbd info %s/%s --format json" % (params['pool'],params['name']))
  if rc:
    return False
  return image_convert_size(json.loads(out))

def cmd_runner(m, params):
  ''' command runner/parser '''
  image_info = cmd_check_image(m, params)
  if params['state'] == 'present':
    if image_info:
      return False, False, dict(image=image_info)
    else:
      rc, out, err = m.run_command("rbd create -s %s %s/%s" % (str(params['size']), params['pool'], params['name']))
      if rc:
        return True, False, dict(msg="failed: '%s'" % (err), stdout=out, stderr=err)
      return False, True, dict(image=cmd_check_image(m, params))
  if params['state'] == 'absent':
    if image_info:
      rc, out, err = m.run_command("rbd rm %s/%s" % (params['pool'], params['name']))
      if rc:
        return True, False, dict(msg="failed: '%s'" % (err), stdout=out, stderr=err)
      return False, True, dict(msg="image removed")
    else:
      return False, False, dict(msg="image does't exists")

def main():

  module = AnsibleModule(argument_spec={
      "state": {
        "required": True, 
        "choices": ['present', 'absent'],
        "type": "str",
      },
      "name": {
        "required": True, 
        "default": None,
        "type": "str",
      },
      "size": {
        "required": False, 
        "default": None,
        "type": "str",
      },
      "pool": {
        "required": False,
        "default": "volumes",
        "type": "str"
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
