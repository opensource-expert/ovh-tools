#!/bin/bash
# enable root login
sed -i -e 's/^.\+ssh-rsa/ssh-rsa/' /root/.ssh/authorized_keys
# set timezone and clock
echo Europe/Paris > /etc/timezone 
dpkg-reconfigure -f noninteractive tzdata
# upgrade
apt-get update
apt-get upgrade -y > /root/upgrade.log
apt-get install vim tree git -y >> /root/install.log
