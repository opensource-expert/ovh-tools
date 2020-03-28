#!/usr/bin/env bash
#
# install script
#
# Usage: ./install.sh
#
# VimF12: execute
# @c: 0"ry$

set -euo pipefail

# empty if you run it as root
SUDO=""

# uncomment to run as user
SUDO=sudo

$SUDO apt update
$SUDO apt install -y git curl tree vim
git clone https://github.com/opensource-expert/ovh-tools.git
# install jq 1.6, not yet available in package repository
JQ_URL=https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
$SUDO wget $JQ_URL -O /usr/local/bin/jq
$SUDO chmod a+x /usr/local/bin/jq
$SUDO apt install -y python-pip python-dev
cd ~/ovh-tools
$SUDO pip install -r requirements.txt

cd ~
git clone https://github.com/yadutaf/ovh-cli.git
cd ovh-cli/
$SUDO pip install wheel
$SUDO pip install setuptools
$SUDO pip install -r requirements.txt
# downloads json for API, this script return 1
./ovh-eu || true

# initialize credential
cd ~/ovh-tools
./mk_cred.py new
mv ovh_conf.tmp ovh.conf
cd ../ovh-cli
ln -s ../ovh-tools/ovh.conf .

# show result
./ovh-eu  auth current-credential
