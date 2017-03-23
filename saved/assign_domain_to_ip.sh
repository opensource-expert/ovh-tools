#!/bin/bash
ip=$1

if [[ -z "$ip" ]]
then
  echo "missing ip"
  exit 1
fi

echo "assigning '$ip'"

# restore some dns to the same IP
for d in vim88 sed awk perl
do
  set_ip_domain $ip $d.opensource-expert.com
  set_ip_domain $ip www.$d.opensource-expert.com
done
