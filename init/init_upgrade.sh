#!/bin/bash
# upgrade
apt-get update
nohup apt-get upgrade -y > /root/upgrade.log &
