#!/bin/bash

source ~/stackrc

openstack baremetal node list --format value -c UUID | \
   xargs -I{} openstack baremetal node set {} --property root_device='{"name": "/dev/sda"}'

