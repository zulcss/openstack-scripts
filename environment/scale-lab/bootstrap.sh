#!/bin/bash

# setup ansible and shade on python3

set -xo pipefail
sudo yum install -y python3-pip python3-virtualenv
rm -rf ~/.local
pip3 install --user ansible shade
virtualenv /var/tmp/venv_shade
