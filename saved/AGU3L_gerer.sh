#!/bin/bash
# cloud.sh saved session

#set -x
# hostname can be read as first argument
myhostname=$1

if [[ -z $myhostname ]]
then
  myhostname="mailman.opensource-expert.com"
fi

FLAVOR_NAME=s1-2
#FLAVOR_NAME=s1-8

mytmp=$TMP_DIR/saved_debian9_gerer.$$

myimage=$(find_image $PROJECT_ID 'Debian.9$' | awk '{print $1}')
mysshkey=$(get_sshkeys $PROJECT_ID sylvain2016)
myinit_script=$SCRIPTDIR/init/gerer_post_install.sh

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

# init_script seems not to work: workarround
myinit_script=$SCRIPTDIR/init/gerer_post_install.sh
mytmp_init=$(preprocess_init "$myinit_script")
cat $mytmp_init | ssh -o StrictHostKeyChecking=no debian@$ip "sudo bash -"
