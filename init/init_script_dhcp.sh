#!/bin/bash
# set timezone and clock
echo Europe/Paris > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

apt-get update
apt-get upgrade -y
nohup apt-get install -y vim git tree etckeeper rsync &
cat <<END >> /etc/network/interfaces
allow-hotplug eth1
iface eth1 inet dhcp
END
ifup eth1

sed -i -e 's/^.\+ssh-rsa/ssh-rsa/' /root/.ssh/authorized_keys
