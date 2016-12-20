#!/bin/bash
# cloud.sh saved session

# debian-updated-base 2
myimage=1a16c40a-c61a-4412-8b3e-83127c9f3132
FLAVOR_NAME=vps-ssd-1
mysshkey=$(get_sshkeys $PROJECT_ID sylvain)
myinit_script=$SCRIPTDIR/init/init_root_login_OK.sh
myhostname=rm.opensource-expert.com
instance=$(create_instance $PROJECT_ID $myimage $mysshkey \
  $myhostname $myinit_script \
  | jq -r '.id')
wait_for_instance $PROJECT_ID $instance 210
