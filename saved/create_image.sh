#!/bin/bash
# cloud.sh saved session
#
# Create a instance with the given image_id
#
# Usage: ./cloud.sh run saved/create_image.sh $image_id

set -euo pipefail
#set -x

if [[ $# -eq 1 ]] ; then
  image_id=$1
  myhostname=tmp-$$.opensource-expert.com
else
  fail "error: \$1 must be a valid image id"
fi

mytmp=$TMP_DIR/saved_create_image.$$

check_for_snapshot=0

# check image validity
image_data=$(find_image $PROJECT_ID | awk "\$1 == \"$image_id\" {print}")
if [[ -z $image_data ]] ; then
  echo "no image found for '$image_id'"
  check_for_snapshot=1
else
  # d0f7e0ed-b47d-4e4c-b3df-7d61e78d1bfb
  # remove image_id from awk output
  image_name=${image_data#$image_id }
  # lowercase
  image_name=${image_name,,}
  # remove blank
  image_name=${image_name// /}
  # replace dot
  image_name=${image_name//\./-}

  myhostname=$image_name.opensource-expert.com
fi

if [[ $check_for_snapshot -eq 1 ]] ; then
  # check for snapshot instead
  snapshot_data=$(snapshot_list $PROJECT_ID no_order json | jq ".[]|select(.id == \"$image_id\")")
  if [[ -z $snapshot_data ]] ; then
    fail "'$image_id' not snapshot found"
  else
    image_name=$(jq -r .name <<< "$snapshot_data")
    echo "snapshot found $image_name"
    # lowercase
    image_name=${image_name,,}
    # remove blank
    image_name=${image_name// /}

    fqdn_regexp='\.opensource-expert\.com$'
    if [[ $image_name =~ $fqdn_regexp ]] ; then
      myhostname=$image_name
    else
      # replace dot
      image_name=${image_name//\./-}
      myhostname=$image_name.opensource-expert.com
    fi
  fi
fi

echo "image_name found $image_name => myhostname $myhostname"

myimage=$image_id
mysshkey=$(get_sshkeys $PROJECT_ID sylvain2016)
myinit_script=$SCRIPTDIR/init/init_root_vim_time.sh

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

  # TODO: fix hostname on remote machine if created from snapshot
fi
