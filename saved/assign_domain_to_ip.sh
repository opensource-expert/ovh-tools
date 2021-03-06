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
  echo $d
  set_forward_dns $ip $d.opensource-expert.com
  set_forward_dns $ip www.$d.opensource-expert.com
done

set_forward_dns $ip www.vim7.opensource-expert.com
