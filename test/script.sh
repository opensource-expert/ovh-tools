#!/bin/bash
# enable root login
sed -i -e 's/^.\+ssh-rsa/ssh-rsa/' /root/.ssh/authorized_keys

# set timezone and clock
echo Europe/Paris > /etc/timezone 
dpkg-reconfigure -f noninteractive tzdata

# leave a trace
echo "$(date) $(hostname)" > /root/myhostname

echo "some accent é €"
