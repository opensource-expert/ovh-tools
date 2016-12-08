#!/bin/bash
# set timezone and clock
echo Europe/Paris > /etc/timezone 
dpkg-reconfigure -f noninteractive tzdata
apt-get install -y git etckeeper

cd /root
git clone https://github.com/saltstack/salt-bootstrap.git
master=saltmaster.opensource-expert.com
cd ~/salt-bootstrap
./bootstrap-salt.sh -U -A $master

# root login OK
sed -i -e 's/^.\+ssh-rsa/ssh-rsa/' /root/.ssh/authorized_keys
echo "$(date) finished" > /root/init_script
