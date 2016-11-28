#!/bin/bash
#
# some public cloud wrapper
#
# require https://github.com/yadutaf/ovh-cli + pip requirement + auth
# require jq (c++ json parser for bash)
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

  if [[ -z "$flavor_name" ]]
  then
    ovh_cli --format json cloud project $p flavor --region GRA1 \
      | jq -r '.[]|.id+" "+.name'
  else
    ovh_cli --format json cloud project $p flavor --region GRA1 \
      | jq -r ".[]|select(.name == \"$flavor_name\").id"
  fi
}

create_instance() {
	local p=$1
  local snap=$2
  local sshkey=$3
  local hostname=$4

	flavor_name=sp-30-ssd
	#flavor_name=vps-ssd-1
	flavor_id=$(get_flavor $p $flavor_name)
	#echo "create_instance $flavor_name $flavor_id with snap $snap"

  ovh_cli --format json cloud project $p instance create \
    --flavorId $flavor_id \
    --imageId $snap \
    --monthlyBilling false \
    --name $hostname \
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
  elif [[ ! -z "$i" && -z "$3" ]]
  then
      ovh_cli --format json  cloud project $p instance $i \
        | jq -r '.id+" "+.ipAddresses[0].ip+" "+.name+" "+.status'
  elif [[ ! -z "$i" && "$3" == full ]]
  then
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

get_domain_record() {
  local fqdn=$1
  local domain=${1#*.}
  local subdomain=${1%%.*}
  ovh_cli --format json domain zone $domain record \
    --subDomain $subdomain \
    | jq -r '.[0]'
}

# same order as given in list_instance ip, fqdn
set_ip_domain() {
  local ip=$1
  local fqdn=$2

  local domain=${fqdn#*.}

  set_forward_dns $ip $fqdn

  # reverse, doesn't work
  ovh_cli ip $ip reverse --ipReverse $ip --reverse ${fqdn#.}.
}

# same order as given in list_instance ip, fqdn
set_forward_dns() {
  local ip=$1
  local fqdn=$2

  local domain=${fqdn#*.}
  local subdomain=${fqdn%%.*}
  local record=$(get_domain_record $fqdn)
  if [[ -z "$record" || "$record" == null ]]
  then
    # must be created
    record=$(
      ovh_cli --format json domain zone $domain record create \
        --target $ip --ttl 60 --subDomain $subdomain --fieldType A \
        | jq -r '.id'
    )
  else
    ovh_cli --format json domain zone $domain record $record put --target $ip --ttl 60
  fi

  ovh_cli domain zone $domain refresh post
}

delete_instance() {
  local p=$1
  local i=$2
  ovh_cli cloud project $p instance $i delete
}


####################################### main

call_func() {
	# auto detect action loop
	local func="$1"
	shift
	local all_func=$(sed -n '/^[a-zA-Z_]\+(/ s/() {// p' $(readlink -f $0))
	local found=0
  local f
	for f in $all_func
	do
		if [[ "$func" == $f ]]
		then
			# call the matching action with command line parameter
			eval "$f $@"
			found=1
			break
		fi
	done

	if [[ $found -eq 0 ]]
	then
		echo "unknown func: '$func'"
		exit 1
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
    hostname=$4
    tmp=/tmp/create_$hostname
    create_instance $proj $snap $sshkey $hostname | tee $tmp
    instance=$(jq -r '.id' < $tmp)
    echo instance $instance
    #while true
    #do
    #  sleep 2
    #  if get_instance_status $proj $instance | tee $tmp | grep ACTIVE
    #  then
    #    set_forward_dns
    #  fi
  ;;
  get_ssh)
    name=$3
    get_sshkeys $proj $name
  ;;
  list_instance)
    list_instance $proj
  ;;
  rename)
    instance=$3
    new_name=$4
    rename_instance $proj $instance $new_name
    get_instance_status $proj $instance
    ;;
	status)
		instance=$3
		get_instance_status $proj $instance | jq .
	;;
  *)
    # free function call, careful to put args in good order
    call_func "$@"
  ;;
esac
