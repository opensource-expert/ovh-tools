#!/bin/bash

show_project() {
    clouds=$(./ovh-eu --format json cloud project | jq -r .[])
    for c in $clouds
    do
        project=$(./ovh-eu --format json cloud project $c | jq -r .description)
        echo "$c = $project"
    done
}

last_snapshot() {
  local p=$1
	snap=$(./ovh-eu --format json cloud project $p snapshot | jq -r '.|sort_by(.creationDate)|reverse|.[0].id')

	echo $snap
}

list_snapshot() {
  local p=$1
	./ovh-eu --format json cloud project $p snapshot | jq -r '.[]|.id +" "+.name'
}

get_snapshot() {
  local p=$1
	./ovh-eu --format json cloud project $p snapshot | jq -r '.[]|.id +" "+.name'
}

get_flavor() {
	local p=$1
	local flavor_name=$2
	./ovh-eu --format json cloud project $p flavor --region GRA1 \
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
  ./ovh-eu --format json cloud project $p instance create \
    --flavorId $flavor_id \
    --imageId $snap \
    --monthlyBilling false \
    --name server_cmd \
    --region GRA1 \
    --sshKeyId $sshkey
}

get_instance_status() {
	local p=$1
	local i=$2
  if [[ -z "$i" ]]
  then
      . ovh-eu --format json  cloud project $p instance | jq .
  else
      ./ovh-eu --format json  cloud project $p instance $i
  fi
	#status: "ACTIVE"
}

list_sshkeys() {
	local p=$1
  ./ovh-eu --format json cloud project $p sshkey
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
	get_instance)
		instance=$3
		get_instance_status $proj $instance | jq .
	;;
esac

