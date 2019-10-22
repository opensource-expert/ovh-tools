#!/bin/bash
# cloud.sh saved session

set -euo pipefail
#set -x

if [[ $# -ge 1 ]]
then
  myhostname=${1:-}
else
  myhostname="gitlab.opj8.ovh"
fi

# 1vcpu 4G RAM
FLAVOR_NAME=s1-4

mytmp=$TMP_DIR/saved_gitlab.$$

myimage=$(find_image $PROJECT_ID 'Debian.10$' | awk '{print $1}')
mysshkey=$(get_sshkeys $PROJECT_ID sylvain2016)
myinit_script=$SCRIPTDIR/init/init_root_login_OK.sh

instance=$(create_instance $PROJECT_ID $myimage "$mysshkey" \
  "$myhostname" "$myinit_script" \
  | jq -r '.id')
if wait_for_instance $PROJECT_ID "$instance" 210 ; then
  get_instance_status $PROJECT_ID $instance FULL > $mytmp
  ip=$(get_ip_from_json < $mytmp)
  hostname=$(jq -r '.name' < $mytmp)
  set_ip_domain $ip $hostname
fi
rm $mytmp

# post setup if success
if [[ -n "$ip" ]]
then
  # empty my ssh/known_hosts
  ssh-keygen -f "/home/sylvain/.ssh/known_hosts" -R $myhostname
  ssh-keygen -f "/home/sylvain/.ssh/known_hosts" -R $ip
fi
