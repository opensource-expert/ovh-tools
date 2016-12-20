#!/bin/bash
# cloud.sh saved session

myimage=$(find_image $PROJECT_ID "Debian 8" | awk '{print $1}')
FLAVOR_NAME=eg-7
mysshkey=$(get_sshkeys $PROJECT_ID sylvain)
myinit_script=$SCRIPTDIR/init/init_root_login_OK.sh
myhostname=vim7.opensource-expert.com
instance=$(create_instance $PROJECT_ID $myimage $mysshkey \
  $myhostname $myinit_script \
  | jq -r '.id')
wait_for_instance $PROJECT_ID $instance 210
