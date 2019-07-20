#!/bin/bash
# projet AGU3L Gérez!

# the content of this script will be merged by cloud.sh
# See: preprocess_init()
APPEND_SCRIPTS="
init/init_upgrade.sh
/home/sylvain/code/agu3l/projet-ville-annecy/scripts/post_install
"

# enable root login
sed -i -e 's/^.\+ssh-rsa/ssh-rsa/' /root/.ssh/authorized_keys
# set timezone and clock
echo Europe/Paris > /etc/timezone 
dpkg-reconfigure -f noninteractive tzdata

# fix locale
sed -i '/fr_FR.UTF-8/ s/^# //' /etc/locale.gen
locale-gen en_US.UTF-8
