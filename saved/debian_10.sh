#!/bin/bash
# cloud.sh saved session

#set -x
myhostname=$1

if [[ -z $myhostname ]]
then
  myhostname="debian10.opensource-expert.com"
fi

FLAVOR_NAME=s1-2

mytmp=$TMP_DIR/saved_debian_10.$$

myimage=$(find_image $PROJECT_ID 'Debian.10$' | awk '{print $1}')
mysshkey=$(get_sshkeys $PROJECT_ID sylvain2016)
myinit_script=$SCRIPTDIR/init/init_root_login_OK.sh

instance=$(create_instance $PROJECT_ID $myimage "$mysshkey" \
  "$myhostname" "$myinit_script" \
  | jq_or_fail -r '.id')

if [[ ! $instance =~ ^[0-9a-f-]+$ ]] ; then
  fail "instance_id invalid: '$instance'"
fi

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
  # with final dot (copy paste from DNS or something)
  ssh-keygen -f "/home/sylvain/.ssh/known_hosts" -R "${hostname}."
fi
