#!/bin/bash
# cloud.sh saved session

myimage=$(find_image $PROJECT_ID "Debian 8" | awk '{print $1}')
FLAVOR_NAME=eg-7
mysshkey=$(get_sshkeys $PROJECT_ID sylvain)
myinit_script=$SCRIPTDIR/init/init_root_vim_time.sh
myhostname=nova.opensource-expert.com
mytmp=$TMP_DIR/saved_debian8_nova.$$
create_instance $PROJECT_ID $myimage $mysshkey $myhostname $myinit_script \
  > $mytmp
instance=$(jq -r '.id' < $mytmp)
if wait_for_instance $PROJECT_ID $instance 210 ; then
  get_instance_status $PROJECT_ID $instance FULL > $mytmp
  ip=$(jq -r '(.ipAddresses[]|select(.type=="public")).ip' < $mytmp)
  hostname=$(jq -r '.name' < $mytmp)
  set_ip_domain $ip $hostname
fi

rm $mytmp
