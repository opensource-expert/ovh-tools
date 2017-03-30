#!/bin/bash
ip=$1

if [[ -z "$ip" ]]
then
  echo "missing ip"
  exit 1
fi

echo "assigning '$ip'"

# restore some dns to the same IP
for d in rm ls less vim22
do
  echo $d
  set_forward_dns $ip $d.opensource-expert.com
  set_forward_dns $ip www.$d.opensource-expert.com
done
#set_forward_dns $ip certbot.opensource-expert.com
