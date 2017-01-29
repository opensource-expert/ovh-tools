#!/bin/bash
# cloud.sh saved session

myimage=$(find_image $PROJECT_ID "Ubuntu 16.10" | awk '{print $1}')
FLAVOR_NAME=eg-7
mysshkey=$(get_sshkeys $PROJECT_ID sylvain)
myinit_script=$SCRIPTDIR/init/init_root_vim_time.sh
myhostname=ubuntu1610.opensource-expert.com
create_instance $PROJECT_ID $myimage $mysshkey $myhostname $myinit_script
