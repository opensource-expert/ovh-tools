#!/bin/bash
# cloud.sh saved session

# doesn't work
myimage=$(find_image $project_id "Debian 8" | awk '{print $1}')
# global $flavor_name
flavor_name=vps-ssd-1
mysshkey=$(get_sshkeys $project_id sylvain)
myinit_script=$SCRIPTDIR/init/init_root_login_OK.sh
myhostname=grep.opensource-expert.com
create_instance $project_id $myimage $mysshkey $myhostname $myinit_script
