#!/usr/bin/env bash
#
# Usage: saved/mailman_set_dns_records.sh MACHINE_NAME MYHOSTNAME IP

set -euo pipefail

machine_name=$1
myhostname=$2
ip=$3

fail_if_empty machine_name myhostname ip

echo "set forward DNS A record: $myhostname $ip"
set_forward_dns $ip $myhostname

echo "set DNS A record: $machine_name $ip"
set_ip_domain $ip $machine_name

echo "update DNS MX record "
domain=$(get_domain "$myhostname")
mx_target="10 ${machine_name}."

echo "updating MX: $myhostname => $mx_target"
set_dns_record --no-flush $myhostname MX "$mx_target"

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

spf="v=spf1 mx:$myhostname -all"
echo "update SPF record: '$spf"

set_dns_record --no-flush $myhostname SPF "$spf"

dns_flush $domain
