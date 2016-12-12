#!/bin/bash
# cloud.sh saved session

myimage=$(find_image $project_id "Ubuntu 14.04" | awk '{print $1}')
# global $flavor_name
flavor_name=eg-7
mysshkey=$(get_sshkeys $project_id sylvain)
mytmp=/tmp/saved_cloud.tmp
myinit_script=$SCRIPTDIR/init/init_root_login_OK.sh
myhostname=ubuntu1404.opensource-expert.com
create_instance $project_id $myimage $mysshkey $myhostname $myinit_script
