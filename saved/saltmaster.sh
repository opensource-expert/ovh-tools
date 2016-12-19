#!/bin/bash
# cloud.sh saved session

# saltmaster
myimage=9e43258e-ff58-46cd-91b0-2636e32ce0d4
# global $flavor_name
flavor_name=vps-ssd-1
mysshkey=$(get_sshkeys $project_id sylvain)
myinit_script=$SCRIPTDIR/init/init_root_login_OK.sh
myhostname=saltmaster.opensource-expert.com
create_instance $project_id $myimage $mysshkey $myhostname $myinit_script
