#!/bin/bash
# cloud.sh saved session

myimage=$(find_image $project_id "Debian 8" | awk '{print $1}')
flavor_name=eg-7
mysshkey=$(get_sshkeys $project_id sylvain)
myinit_script=$SCRIPTDIR/init/init_root_vim_time.sh
myhostname=nova.opensource-expert.com
mytmp=$TMP_DIR/saved_debian8_nova.$$
create_instance $project_id $myimage $mysshkey $myhostname $myinit_script \
  > $mytmp
instance=$(jq -r '.id' < $mytmp)
if wait_for_instance $project_id $instance 210 ; then
  get_instance_status $project_id $instance FULL > $mytmp
  ip=$(jq -r '(.ipAddresses[]|select(.type=="public")).ip' < $mytmp)
  hostname=$(jq -r '.name' < $mytmp)
  set_ip_domain $ip $hostname
fi

rm $mytmp
