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
# only require for mk_cred.py
# will install a lot a stuff
$SUDO apt install -y python-pip python-dev
cd ~/ovh-tools
$SUDO pip install -r requirements.txt


# install ovh-cli-go
OVH_CLI=https://github.com/opensource-expert/ovh-cli-go/releases/download/v0.3/ovh-cli_linux_amd64
$SUDO wget $OVH_CLI -O /usr/local/bin/ovh-cli
$SUDO chmod a+x /usr/local/bin/ovh-cli
ovh-cli --version


# initialize credential
cd ~/ovh-tools
./mk_cred.py new
mv ovh_conf.tmp ovh.conf
ln -s ~/ovh-tools/ovh.conf ~/.ovh.conf

# test ovh-cli
ovh-cli GET /me | jq .firstname
ovh-cli GET /auth/currentCredential | jq .
