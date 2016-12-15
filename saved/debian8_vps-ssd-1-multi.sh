#!/bin/bash
# cloud.sh saved session
# multiple create loop
# ./cloud.sh run saved/debian8_vps-ssd-1-multi.sh

myimage=$(find_image $project_id "Debian 8" | awk '{print $1}')
# global $flavor_name
flavor_name=vps-ssd-1
mysshkey=$(get_sshkeys $project_id sylvain)
myinit_script=$SCRIPTDIR/init/init_root_login_OK.sh

myhost="vim"
for num in $(seq -w 01 05)
do
  h=${myhost}-${num}.opensource-expert.com
  echo $h
  create_instance $project_id $myimage $mysshkey $h $myinit_script
done
