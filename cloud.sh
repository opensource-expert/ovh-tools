#!/bin/bash
#
# some public cloud wrapper
#
# require https://github.com/yadutaf/ovh-cli + pip requirement + auth
# auth with: 
# OVH Europe: https://eu.api.ovh.com/createApp/
# and create a consumer_key with ../ovh-cli/create-consumer-key.py
# store all in ovh.conf

me=$(readlink -f $0)
mydir=$(dirname $me)
ovh_clidir=$mydir/../ovh-cli

# ovh-cli seems to require json def of all api in its own folder, we need to change??
# here fixed nearby
ovh_cli() {
  cd $ovh_clidir
  ./ovh-eu "$@"
  cd - > /dev/null
}

show_project() {
    clouds=$(ovh_cli --format json cloud project | jq -r .[])
    for c in $clouds
    do
        project=$(ovh_cli --format json cloud project $c | jq -r .description)
        echo "$c = $project"
    done
}

last_snapshot() {
  local p=$1
	snap=$(ovh_cli --format json cloud project $p snapshot | jq -r '.|sort_by(.creationDate)|reverse|.[0].id')

	echo $snap
}

list_snapshot() {
  local p=$1
	ovh_cli --format json cloud project $p snapshot | jq -r '.[]|.id +" "+.name'
}

get_snapshot() {
  local p=$1
	ovh_cli --format json cloud project $p snapshot | jq -r '.[]|.id +" "+.name'
}

get_flavor() {
	local p=$1
	local flavor_name=$2
	ovh_cli --format json cloud project $p flavor --region GRA1 \
		| jq -r ".[]|select(.name == \"$flavor_name\").id"
}

create_instance() {
	local p=$1
  local snap=$2
  local sshkey=$3
	flavor_name=sp-30-ssd
	flavor_id=$(get_flavor $p $flavor_name)
	echo "create_instance $flavor_name $flavor_id with snap $snap"

  set -x
  ovh_cli --format json cloud project $p instance create \
    --flavorId $flavor_id \
    --imageId $snap \
    --monthlyBilling false \
    --name server_cmd \
    --region GRA1 \
    --sshKeyId $sshkey
}

list_instance() {
  local p=$1
  ovh_cli --format json cloud project $p instance \
    | jq -r '.[]|.id+" "+.ipAddresses[0].ip+" "+.name'
}

rename_instance() {
  local p=$1
  local instanceId=$2
  local new_name=$3
  ovh_cli --format json cloud project $p instance $2 put \
    --instanceName $new_name
}

get_instance_status() {
	local p=$1
	local i=$2
  if [[ -z "$i" ]]
  then
      ovh_cli --format json  cloud project $p instance | jq .
  else
      ovh_cli --format json  cloud project $p instance $i
  fi
	#status: "ACTIVE"
}

list_sshkeys() {
	local p=$1
  ovh_cli --format json cloud project $p sshkey
}

get_sshkeys() {
  local p=$1
  local name=$2
  if [[ ! -z "$name" ]]
  then
    list_sshkeys $p  | jq -r ".[]|select(.name == \"$name\").id"
  else
    list_sshkeys $p | jq -r '.[]|.id+" "+.name'
  fi
}


####################################### main

proj=$2

if [[ -z "$1" || -z "$proj" ]]
then
    show_project
    exit
fi

case $1 in
	get_snap)
    list_snapshot $proj
	;;
  create)
    snap=$3
    sshkey=$(get_sshkeys $proj sylvain)
    create_instance $proj $snap $sshkey
  ;;
  get_ssh)
    name=$3
    get_sshkeys $proj $name
  ;;
  list_instance)
    list_instance $proj
  ;;
  rename)
    instanceId=$3
    new_name=$4
    rename_instance $proj $instanceId $new_name
    ;;
	status)
		instance=$3
		get_instance_status $proj $instance | jq .
	;;
esac
