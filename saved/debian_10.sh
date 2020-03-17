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

instance_id=$(create_instance $PROJECT_ID $myimage "$mysshkey" \
  "$myhostname" "$myinit_script" \
  | jq_or_fail -r '.id')

if [[ ! $instance_id =~ ^[0-9a-f-]+$ ]] ; then
  fail "instance_id invalid: '$instance_id'"
fi

try_create_vm=0
ip=""
while [[ $try_create_vm -le 2 && -z $ip ]]
do
  try_create_vm=$((try_create_vm + 1))
  echo "try: $try_create_vm"
  if wait_for_instance $PROJECT_ID "$instance_id" 210 ; then
    instance_json=$(get_instance_status $PROJECT_ID $instance_id FULL)
    ip=$(get_ip_from_json <<< "$instance_json")
    hostname=$(jq -r '.name' <<< "$instance_json")
    set_ip_domain $ip $hostname
  else
    error "failure: or timeout creating the VM"
    echo "deleting instance: $instance_id"
    delete_instance $PROJECT_ID $instance_id
  fi
done

# post setup if success
if [[ -n "$ip" ]]
then
  # empty my ssh/known_hosts
  ssh-keygen -f "/home/sylvain/.ssh/known_hosts" -R $myhostname
  ssh-keygen -f "/home/sylvain/.ssh/known_hosts" -R $ip
  # with final dot (copy paste from DNS or something)
  ssh-keygen -f "/home/sylvain/.ssh/known_hosts" -R "${hostname}."
else
  error "no ip, creation failure"
fi
