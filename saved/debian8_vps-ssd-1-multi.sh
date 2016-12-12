#!/bin/bash
# cloud.sh saved session
# multiple create loop

myimage=$(find_image $project_id "Debian 8" | awk '{print $1}')
# global $flavor_name
flavor_name=vps-ssd-1
mysshkey=$(get_sshkeys $project_id sylvain)
myinit_script=$SCRIPTDIR/init/init_root_login_OK.sh

myhosts="grep vim zim sed awk"
for h in $myhosts
do
  h=$h.opensource-expert.com
  echo $h
  create_instance $project_id $myimage $mysshkey $h $myinit_script
done
