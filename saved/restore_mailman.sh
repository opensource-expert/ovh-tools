#!/bin/bash
# cloud.sh saved session

#set -x
set -euo pipefail
# hostname can be read as first argument
myhostname="mailman.opensource-expert.com"
machine_name="mailman-host.opensource-expert.com"

FLAVOR_NAME=s1-2
myinit_script=$SCRIPTDIR/init/init_root_login_OK.sh

ip_regexp='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
if [[ $# -ge 1 && $1 =~ $ip_regexp ]] ; then
  echo "IP $1"
  create=false
  ip=$1
else
  echo "\$1 = ${1:-empty}"
  create=true
fi

if $create ; then
  # fetch the most recent image_id given the pattern
  myimage=$(last_snapshot $PROJECT_ID "mailman3-stretch")
  mysshkey=$(get_sshkeys $PROJECT_ID sylvain2016)
  mytmp=$TMP_DIR/saved_debian9_mailman.$$
  instance=$(create_instance $PROJECT_ID $myimage "$mysshkey" \
    "$myhostname" "$myinit_script" \
    | jq -r '.id')
  if wait_for_instance $PROJECT_ID "$instance" 310 ; then
    get_instance_status $PROJECT_ID $instance FULL > $mytmp
    ip=$(get_ip_from_json < $mytmp)
    hostname=$(jq -r '.name' < $mytmp)
  fi
  rm $mytmp

  echo "instance_id $instance"

  set +x
  # post setup if success
  if [[ -n "$ip" ]]
  then
    # empty my ssh/known_hosts
    ssh-keygen -f "/home/sylvain/.ssh/known_hosts" -R $myhostname
    ssh-keygen -f "/home/sylvain/.ssh/known_hosts" -R $ip
  fi
fi

saved/mailman_set_dns_records.sh "$machine_name" "$myhostname" "$ip"

echo
echo "READY! ssh -o StrictHostKeyChecking=no debian@$ip"
echo
