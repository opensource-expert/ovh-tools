#!/bin/bash
# cloud.sh saved snapshot

#set -x
myhostname=noalyss.opensource-expert.com
FLAVOR_NAME=eg-7

mytmp=$TMP_DIR/saved_noalys.$$

myimage=$(list_snapshot $PROJECT_ID | awk '/noalyss.opensource-expert.com/ {print $1}')
mysshkey=$(get_sshkeys $PROJECT_ID sylvain)
myinit_script=$SCRIPTDIR/init/init_root_login_OK.sh

instance=$(create_instance $PROJECT_ID $myimage $mysshkey \
  $myhostname $myinit_script \
  | jq -r '.id')

if wait_for_instance $PROJECT_ID $instance 210 ; then
  get_instance_status $PROJECT_ID $instance FULL > $mytmp
  ip=$(jq -r '(.ipAddresses[]|select(.type=="public")).ip' < $mytmp)
  hostname=$(jq -r '.name' < $mytmp)
  set_ip_domain $ip $hostname
fi
rm $mytmp
