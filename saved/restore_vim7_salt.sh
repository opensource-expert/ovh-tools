#!/bin/bash
# cloud.sh saved session
#
# restore a salt minion with snapshot (the last one if many)

#set -x

# force hostname
myhostname=vim7.opensource-expert.com

# restoring as flavor:
FLAVOR_NAME=eg-7

# store some output for optimizing API no-requery
mytmp=$TMP_DIR/saved_vim7_eg7.$$

# get last image by comment
myimage=$(last_snapshot $PROJECT_ID vim7)

# reforce this at the end
myinit_script=$SCRIPTDIR/init/init_root_login_OK.sh

mysshkey=$(get_sshkeys $PROJECT_ID sylvain)
instance=$(create_instance $PROJECT_ID $myimage $mysshkey \
  $myhostname $myinit_script \
  | jq -r '.id')
if wait_for_instance $PROJECT_ID $instance 210 ; then
  get_instance_status $PROJECT_ID $instance FULL > $mytmp
  ip=$(get_ip_from_json < $mytmp)
  hostname=$(jq -r '.name' < $mytmp)
  set_ip_domain $ip $hostname
fi
rm $mytmp

