#!/bin/bash
#
# some public cloud wrapper
#
# require https://github.com/yadutaf/ovh-cli + pip requirement + auth
# require jq (c++ json parser for bash)
# auth with:
# OVH Europe: https://eu.api.ovh.com/createApp/
# and create a consumer_key with ../ovh-cli/create-consumer-key.py
# store all OVH api credential in ovh.conf
#
# Usage:
#  ./cloud.sh               list projects
#  ./cloud.sh ACTION [project_id] param ...
#  ./cloud.sh help          list action and functions
#


########################################################  init
[[ $0 != "$BASH_SOURCE" ]] && sourced=1 || sourced=0
if [[ $sourced -eq 0  ]]
then
  ME=$(readlink -f $0)
else
  ME=$(readlink -f "$BASH_SOURCE")
fi

if [[ "$1" == "help" || "$1" == "--help" ]]
then
  # list case entries and functions
  grep -E '^([a-z_]+\(\)| +[a-z_|-]+\))' $ME | sed -e 's/() {//' -e 's/)$//'
  exit 0
fi

SCRIPTDIR=$(dirname $ME)
ovh_clidir=$SCRIPTDIR/../ovh-cli

# you can "export CONFFILE=some_file" to override
if [[ -z "$CONFFILE" ]]
then
  CONFFILE="$SCRIPTDIR/cloud.conf"
fi

###################################### functions

# ovh-cli seems to require json def of all api in its own folder,
# we need to change??
# here fixed nearby
ovh_cli() {
  cd $ovh_clidir
  ./ovh-eu "$@"
  cd - > /dev/null
}

show_projects() {
    clouds=$(ovh_cli --format json cloud project | jq -r .[])
    for c in $clouds
    do
        project=$(ovh_cli --format json cloud project $c | jq -r .description)
        echo "$c $project"
    done
}

last_snapshot() {
  local p=$1
  snap=$(ovh_cli --format json cloud project $p snapshot \
    | jq -r '.|sort_by(.creationDate)|reverse|.[0].id')
  echo $snap
}

list_snapshot() {
  local p=$1
  ovh_cli --format json cloud project $p snapshot \
    | jq -r '.[]|.id +" "+.name'
}

delete_snapshot() {
  local p=$1
  local snap_id=$2
  ovh_cli --format json cloud project $p snapshot $snap_id delete | grep -E '(^|status.*)'
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

# output json
create_instance() {
  local p=$1
  local snap=$2
  local sshkey=$3
  local hostname=$4
  local init_script=$5

  if [[ -z "$flavor_name" ]]
  then
    # you can define it in cloud.conf
    flavor_name=vps-ssd-1
  fi
  flavor_id=$(get_flavor $p $flavor_name)

  if [[ ! -z "$init_script" && -e "$init_script" ]]
  then
    # with an init_script, added in json so it is parsable
    ovh_cli --format json cloud project $p instance create \
      --flavorId $flavor_id \
      --imageId $snap \
      --monthlyBilling false \
      --name $hostname \
      --region GRA1 \
      --sshKeyId $sshkey \
      --userData "$(cat $init_script)" \
        | jq ". + {\"init_script\" : \"$init_script\"}"
  else
    ovh_cli --format json cloud project $p instance create \
      --flavorId $flavor_id \
      --imageId $snap \
      --monthlyBilling false \
      --name $hostname \
      --region GRA1 \
      --sshKeyId $sshkey
  fi
}

list_instance() {
  local p=$1
  # filter on public ip address only
  ovh_cli --format json cloud project $p instance \
    | jq -r '.[]|.id+" "+(.ipAddresses[]|select(.type=="public")).ip+" "+.name'
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
  # $3 == full : full json output

  if [[ -z "$i" ]]
  then
    # list all in text format (ip is not ordered, so it could be the private one)
    # See list_instance
    ovh_cli --format json  cloud project $p instance \
      | jq -r '.[]|.id+" "+.ipAddresses[0].ip+" "+.name+" "+.status'
  elif [[ ! -z "$i" && -z "$3" ]]
  then
    # list summary in text
    ovh_cli --format json  cloud project $p instance $i \
      | jq -r '.id+" "+.ipAddresses[0].ip+" "+.name+" "+.status'
  elif [[ ! -z "$i" && "$3" == full ]]
  then
    # full summary in json for the given instance
    ovh_cli --format json cloud project $p instance $i
  fi
}

# output json
list_sshkeys() {
  local p=$1
  ovh_cli --format json cloud project $p sshkey
}

# output text
get_sshkeys() {
  local p=$1
  local name=$2
  if [[ ! -z "$name" ]]
  then
    # only one id
    list_sshkeys $p  | jq -r ".[]|select(.name == \"$name\").id"
  else
    # list all
    list_sshkeys $p | jq -r '.[]|.id+" "+.name'
  fi
}

get_domain_record_id() {
  local fqdn=$1
  local domain=${1#*.}
  local subdomain=${1%%.*}
  ovh_cli --format json domain zone $domain record \
    --subDomain $subdomain \
    | jq -r '.[0]'
}

# same order as given in list_instance ip, fqdn
# instance needs to be ACTIVE and have an IP
set_ip_domain() {
  local ip=$1
  local fqdn=$2

  local domain=${fqdn#*.}

  set_forward_dns $ip $fqdn

  # wait a bit
  sleep 1

  # reverse, doesn't work
  #ovh_cli ip $ip reverse --ipReverse $ip --reverse ${fqdn#.}.
  # python wrapper
  $SCRIPTDIR/ovh_reverse.py $ip ${fqdn#.}.

  echo "if forward DNS not yet available for $fqdn"
  echo "  $SCRIPTDIR/ovh_reverse.py $ip ${fqdn#.}. "
}

# same order as given in list_instance ip, fqdn
set_forward_dns() {
  local ip=$1
  local fqdn=$2

  local domain=${fqdn#*.}
  local subdomain=${fqdn%%.*}
  local record=$(get_domain_record_id $fqdn)

  if [[ -z "$record" || "$record" == null ]]
  then
    # must be created
    ovh_cli --format json domain zone $domain record create \
      --target $ip --ttl 60 --subDomain $subdomain --fieldType A
  else
    ovh_cli --format json domain zone $domain record $record put \
      --target $ip \
      --ttl 60
  fi

  ovh_cli domain zone $domain refresh post
}

# for cleanup, unused call it manually
delete_dns_record() {
  local fqdn=$1
  local domain=${fqdn#*.}
  local record=$(get_domain_record_id $fqdn)

  if [[ -z "$record" || "$record" == null ]]
  then
    echo "not found"
  else
    ovh_cli domain zone $domain record $record delete
    ovh_cli domain zone $domain refresh post
  fi
}

delete_instance() {
  local p=$1
  local i=$2
  ovh_cli cloud project $p instance $i delete
}

create_snapshot() {
  local p=$1
  local i=$2
  local snap_name="$3"
  ovh_cli cloud project $p instance $i snapshot create \
    --snapshotName "$snap_name"
}

id_is_project() {
  # return a array of project_id, -1 if not found
  ovh_cli --format json cloud project | jq -r . | grep -q "^$1\$" && return 0
  # fail
  return 1
}


set_project() {
  local p=$1

  if id_is_project $p
  then
    write_conf "$CONFFILE" "project_id=$p"
    return 0
  fi

  echo "error: '$p' seems not to be a valid project"
  return 1
}

write_conf() {
  local conffile="$1"
  shift
  # vars $2… formate "var=val" or "DELETE=var_name"

  if [[ -e "$conffile" ]]
  then
    # keep old conf change only vars
    tmp=/dev/shm/cloud_CONFFILE_$$.tmp
    cp "$conffile" $tmp
    for v in "$@"
    do
      var_name=${v%=*}
      if [[ "$var_name" == DELETE ]]
      then
        # delete the var
        var_name=${v#*=}
        sed -i -e "/^$var_name=/ d" $tmp
        continue
      fi

      if grep -q "^$var_name=" $tmp
      then
        # update
        sed -i -e "/^$var_name=/ s/.*/$v/" $tmp
      else
        # new
        echo "$v" >> $tmp
      fi
    done
    #diff -u "$conffile" $tmp
    # overwrite config
    cp $tmp "$conffile"
    rm -f $tmp
  else
    # create a new file
    echo "#!/bin/bash" > "$conffile"
    for v in "$@"
    do
      echo "$v" >> "$conffile"
    done
  fi
}

loadconf() {
    local conffile="$1"
    if [[ -e "$conffile" ]]
    then
        source "$conffile"
        return 0
    fi
    return 1
}

set_flavor() {
  local p=$1
  local flavor_name=$2

  local flavor_id=$(get_flavor $p $flavor_name)
  if [[ -z "$flavor_id" ]]
  then
    echo "error: '$flavor_name' seems not to be a valid flavor"
    echo "to list all flavor use:"
    echo "  $ME call get_flavor $p"
    return 1
  else
    write_conf "$CONFFILE" "flavor_name=$flavor_name"
    return 0
  fi
}

call_func() {
  # auto detect functions name loop
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
      r=$?
      found=1
      break
    fi
  done

  if [[ $found -eq 0 ]]
  then
    echo "unknown func: '$func'"
    return 1
  fi

  return $r
}

find_image() {
  local p=$1
  local pattern="$2"
  ovh_cli --format json cloud project $p image \
    --osType linux --region GRA1 \
    | jq -r ".[]|.id+\" \"+.name" | grep "$pattern"
}

###################################### main

# prefix 'function' not to be greped with --help
function main() {
  action=$1
  proj=$2

  if [[ -z "$action" || -z "$proj" ]]
  then
      echo "no project set, or no action"
      show_projects
      return 1
  fi

  case $action in
    list_snap|get_snap)
      list_snapshot $proj
    ;;
    create)
      snap=$3
      sshkey=$(get_sshkeys $proj sylvain)
      hostname=$4
      init_script=$5

      tmp=/dev/shm/create_$hostname.$$
      create_instance $proj $snap $sshkey $hostname $init_script | tee $tmp
      instance=$(jq -r '.id' < $tmp)
      echo instance $instance
      echo "to wait instance: $0 wait $proj $instance"
      rm -f $tmp
    ;;
    wait)
      instance=$3
      sleep_delay=2
      max=20
      i=0
      tmp=/dev/shm/wait_$instance.$$
      while true
      do
        i=$((i + 1))
        if [[ $i -gt $max ]]
        then
          echo "max count reach: $max"
          break
        fi

        if get_instance_status $proj $instance | tee $tmp | grep -q ACTIVE
        then
          echo OK
          cat $tmp
          break
        fi

        echo -n '.'
        sleep $sleep_delay
      done
      rm -f $tmp
    ;;
    list_ssh|get_ssh)
      userkey=$3
      get_sshkeys $proj $userkey
    ;;
    list_instance|list)
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
      get_instance_status $proj $instance
    ;;
    make_snap)
      instance=$3
      host="$4"
      if [[ -z "$host" ]]
      then
        host=$(get_instance_status $proj $instance | awk '{print $3}')
      fi
      create_snapshot $proj $instance "$host"
      ;;
    del_snap)
      snap_id=$3
      delete_snapshot $proj $snap_id
      ;;
    delete)
      instance=$3
      if [[ $# -gt 3 ]]
      then
        # array slice on $@ 3 to end
        multi_instance=${@:3:$#}
        for i in $multi_instance
        do
          delete_instance $proj $i
        done
      else
        if [[ "$instance" == ALL ]]
        then
          while read i ip hostname
          do
            echo "deleting $i $hostname…"
            delete_instance $proj $i
          done <<< "$(list_instance $proj)"
        else
          delete_instance $proj $instance
        fi
      fi
      ;;
    set_all_instance_dns)
      while read i ip hostname
      do
        echo "set_ip_domain for $hostname"
        set_ip_domain $ip $hostname
      done <<< "$(list_instance $proj)"
      ;;
    set_project)
      if set_project $proj
      then
        echo "project '$proj'written in '$CONFFILE'"
        exit 0
      else
        exit 1
      fi
      ;;
    set_flavor)
      previous_flavor=$flavor_name
      flavor_name=$3
      echo "actual flavor_name $previous_flavor"
      if set_flavor $proj "$flavor_name"
      then
        echo "new flavor '$flavor_name' written in '$CONFFILE'"
        exit 0
      else
        exit 1
      fi
      ;;
    call)
      # free function call, careful to put args in good order
      call_function=$2
      shift 2
      call_func $call_function "$@"
      ;;
    run)
      src="$3"
      # search code loop
      for f in $src "saved/$3"
      do
        if [[ -e "$src" ]] ; then
          source $src
          break
        fi
      done
      ;;
    *)
      echo "error: $action not found"
      echo "free call (project_id added): call $@"
      exit 1
      ;;
  esac
}

if [[ $sourced -eq 0 ]]
then
  loadconf "$CONFFILE"
  if [[ ! -z "$project_id" ]]
  then
    if [[ "$1" == "call" ]]
    then
      main "$@"
    elif id_is_project "$2"
    then
      # project_id in CONFFILE but forced on command line
      main "$@"
    else
      # skip 1 postional parameter
      main $1 $project_id "${@:2:$#}"
    fi
  else
    # no project_id
    main "$@"
  fi
  exit $?
fi
