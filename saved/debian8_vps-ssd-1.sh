#!/bin/bash
# cloud.sh saved session

# doesn't work
myimage=$(find_image $PROJECT_ID "Debian 8" | awk '{print $1}')
FLAVOR_NAME=vps-ssd-1
mysshkey=$(get_sshkeys $PROJECT_ID sylvain)
myinit_script=$SCRIPTDIR/init/init_root_login_OK.sh
myhostname=grep.opensource-expert.com
create_instance $PROJECT_ID $myimage $mysshkey $myhostname $myinit_script
