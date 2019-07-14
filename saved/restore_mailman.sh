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

  # post setup if success
  if [[ -n "$ip" ]]
  then
    # empty my ssh/known_hosts
    ssh-keygen -f "/home/sylvain/.ssh/known_hosts" -R $myhostname
    ssh-keygen -f "/home/sylvain/.ssh/known_hosts" -R $ip
  fi
fi

echo "set DNS A record: $myhostname $ip"
set_ip_domain $ip $myhostname

# update DNS MX recorde (must exists first)
domain=opensource-expert.com
mx_record="mailman.$domain"
record=$(get_domain_record_id $mx_record MX)
mx_target="10 ${machine_name}."
echo "set DNS A record: $machine_name $ip"
set_ip_domain $ip $machine_name
echo "updating MX: $mx_record => $mx_target"
ovh_cli --format json domain zone $domain record $record put --target "$mx_target" --ttl $DNS_TTL

# check MX record
subdomain=mailman
cmd="ovh_cli --format json domain zone $domain record --subDomain $subdomain --fieldType MX | jq -r '.[]'"
eval "$cmd"
nb_record=$(eval "$cmd" | wc -l)
if [[ $nb_record -gt 1 ]] ; then
  echo "ERROR DNS: $nb_record for $subdomain.$domain"
  cat << END
# check with
./cloud.sh call ovh_cli domain zone $domain record RECORD_ID above
END
fi

# flush DNS changes
ovh_cli domain zone $domain refresh post

echo
echo "READY! ssh -o StrictHostKeyChecking=no debian@$ip"
echo
