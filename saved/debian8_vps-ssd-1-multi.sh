#!/bin/bash
# cloud.sh saved session
# multiple create loop
# ./cloud.sh run saved/debian8_vps-ssd-1-multi.sh

myimage=$(find_image $PROJECT_ID "Debian 8" | awk '{print $1}')
FLAVOR_NAME=vps-ssd-1
mysshkey=$(get_sshkeys $PROJECT_ID sylvain)
myinit_script=$SCRIPTDIR/init/init_root_login_OK.sh

myhost="vim"
for num in $(seq -w 01 05)
do
  h=${myhost}-${num}.opensource-expert.com
  echo $h
  create_instance $PROJECT_ID $myimage $mysshkey $h $myinit_script
done
