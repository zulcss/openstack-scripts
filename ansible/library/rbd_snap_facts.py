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
module: rbd_snap_facts
short_description: Retrieve facts about a snapshot within rbd command.
version_added: "1.0"
author: "Tomas Rusnak (trusnak@redhat.com)"
description:
  - Retrieve facts about a snapshot from rbd command.
notes:
  - Facts are placed in the C(rbd) variable.
requirements:
  - "python >= 2.6"
  - "rbd"
options:
  image:
    description:
      - Name or ID of the image
    required: true
  pool:
    description:
      - Name of the pool where  is stored
    required: false
extends_documentation_fragment: ceph
'''

def cmd_runner(m, params):
  if params['name']:
    rc, out, err = m.run_command("rbd snap ls %s/%s --format json" % (params['pool'], params['name']))
    if rc:
      return True, False, dict(msg="failed: '%s'" % (err), stdout=out, stderr=err)
    if out:
      data = json.loads(out)
      #data['size'] = str(int(data['size'])/(1024**2))
      return False, False, dict(image=data)
  return True, False, dict(response="failed, name must be specified")

def main():
  module = AnsibleModule(argument_spec={
      "name": {
        "required": True,
        "default": None,
        "type": "str",
      },
      "pool": {
        "required": False,
        "default": "volumes",
        "type": "str",
      },
  }, supports_check_mode=True)

  is_error, has_changed, result = cmd_runner(module, module.params)
  if not is_error:
    module.exit_json(changed=has_changed, **result)
  else:
    module.fail_json(msg="Error", meta=result)

from ansible.module_utils.basic import *
if __name__ == '__main__':
  main()
