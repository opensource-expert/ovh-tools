#!/bin/bash
# cloud.sh saved session

myimage=$(find_image $PROJECT_ID "Ubuntu 14.04" | awk '{print $1}')
FLAVOR_NAME=eg-7
mysshkey=$(get_sshkeys $PROJECT_ID sylvain)
myinit_script=$SCRIPTDIR/init/init_root_login_OK.sh
myhostname=ubuntu1404.opensource-expert.com
create_instance $PROJECT_ID $myimage $mysshkey $myhostname $myinit_script
