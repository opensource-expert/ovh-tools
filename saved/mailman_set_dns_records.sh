#!/usr/bin/env bash

set -euo pipefail

MYDOMAIN=opensource-expert.com

machine_name=$1
myhostname=$2
ip=$3

echo "set DNS A record: $myhostname $ip"
set_ip_domain $ip $myhostname

# update DNS MX recorde (must exists first)
domain=$MYDOMAIN
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
