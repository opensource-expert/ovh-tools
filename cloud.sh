#!/bin/bash
#
# OVH public cloud API wrapper
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
#  ./cloud.sh ACTION [PROJECT_ID] param ...
#  ./cloud.sh help          list action and functions
#
# See: test/all.sh for many examples


########################################################  init
[[ $0 != "$BASH_SOURCE" ]] && sourced=1 || sourced=0
if [[ $sourced -eq 0  ]]
then
  ME=$(readlink -f $0)
else
  ME=$(readlink -f "$BASH_SOURCE")
fi

# help
if [[ "$1" == "help" || "$1" == "--help" ]]
then
  # list case entries and functions
  grep -E '^([a-z_]+\(\)| +[a-z_|-]+\))' $ME | sed -e 's/() {//' -e 's/)$//'
  exit 0
fi

SCRIPTDIR=$(dirname $ME)
OVH_CLIDIR=$SCRIPTDIR/../ovh-cli

# you can "export CONFFILE=some_file" to override
# usefull for testing
if [[ -z "$CONFFILE" ]]
then
  # default value
  CONFFILE="$SCRIPTDIR/cloud.conf"
fi

# globals can be overridden in $CONFFILE
# see loadconf()

# delays in seconds
MAX_WAIT=210
SLEEP_DELAY=2

# for temporary output on ramdrive
TMP_DIR=/dev/shm

REGION=GRA1
DNS_TTL=60

###################################### functions

# ovh-cli seems to require json def of all api in its own folder,
# we need to change??
# here we find ovh-cli in fixed nearby location
ovh_cli() {
  cd $OVH_CLIDIR
  ./ovh-eu "$@"
  local r=$?
  cd - > /dev/null
  return $r
}

show_projects() {
  local clouds=$(ovh_cli --format json cloud project | jq -r .[])
  local r=$?
  for c in $clouds
  do
    project=$(ovh_cli --format json cloud project $c | jq -r .description)
    echo "$c $project"
  done
  return $r
}

last_snapshot() {
  local p=$1
  local snap=$(ovh_cli --format json cloud project $p snapshot \
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
  ovh_cli --format json cloud project $p snapshot $snap_id delete \
    | grep -E '(^|status.*)'
}

get_flavor() {
  local p=$1
  local flavor_name=$2

  if [[ -z "$flavor_name" ]]
  then
    ovh_cli --format json cloud project $p flavor --region $REGION \
      | jq -r '.[]|.id+" "+.name'
  else
    ovh_cli --format json cloud project $p flavor --region $REGION \
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

  local myflavor=$FLAVOR_NAME
  if [[ -z "$myflavor" ]]
  then
    # you can define it in cloud.conf
    myflavor=vps-ssd-1
  fi
  local flavor_id=$(get_flavor $p $myflavor)

  if [[ ! -z "$init_script" && -e "$init_script" ]]
  then
    # with an init_script, added in json so it is parsable
    ovh_cli --format json cloud project $p instance create \
      --flavorId $flavor_id \
      --imageId $snap \
      --monthlyBilling false \
      --name $hostname \
      --region $REGION \
      --sshKeyId $sshkey \
      --userData "$(cat $init_script)" \
        | jq ". + {\"init_script\" : \"$init_script\"}"
  else
    ovh_cli --format json cloud project $p instance create \
      --flavorId $flavor_id \
      --imageId $snap \
      --monthlyBilling false \
      --name $hostname \
      --region $REGION \
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
  # $3 == FULL : full json output

  if [[ -z "$i" ]]
  then
    # list all in text format (ip is not ordered,
    # so it could be the private one)
    # See list_instance
    ovh_cli --format json  cloud project $p instance \
      | jq -r '.[]|.id+" "+.ipAddresses[0].ip+" "+.name+" "+.status'
  elif [[ ! -z "$i" && -z "$3" ]]
  then
    # list summary in text
    ovh_cli --format json  cloud project $p instance $i \
      | jq -r '.id+" "+.ipAddresses[0].ip+" "+.name+" "+.status'
  elif [[ ! -z "$i" && "$3" == "FULL" ]]
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

  echo "  if needed: re-set revrses with:"
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
      --target $ip --ttl $DNS_TTL --subDomain $subdomain --fieldType A
  else
    ovh_cli --format json domain zone $domain record $record put \
      --target $ip \
      --ttl $DNS_TTL
  fi

  # flush domain modification
  ovh_cli domain zone $domain refresh post
}

# for cleanup, unused, call it manually
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
    write_conf "$CONFFILE" "PROJECT_ID=$p"
    return 0
  fi

  echo "error: '$p' seems not to be a valid project"
  return 1
}

# Usage:
#   write_conf conffile VAR=value VAR2=value2 DELETE=VAR3 ...
write_conf() {
  local conffile="$1"
  shift
  # vars $2… formate "var=val" or "DELETE=var_name"

  local v
  if [[ -e "$conffile" ]]
  then
    # keep old conf change only vars
    local tmp=$TMP_DIR/cloud_CONFFILE_$$.tmp
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
    write_conf "$CONFFILE" "FLAVOR_NAME=$flavor_name"
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
  local r
  for f in $all_func
  do
    if [[ "$func" == $f ]]
    then
      # call the matching action with command line parameter
      # warning: call somefunc "value separated space" iu not
      # transmitted as one argument, but splitted in eval
      # ex: ./cloud.sh call find_image \$PROJECT_ID "Debian 8" (2 results)
      # differe from: find_image $PROJECT_ID "Debian 8" (1 result)
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
    --osType linux --region $REGION \
    | jq -r ".[]|.id+\" \"+.name" | grep "$pattern"
}

wait_for_instance() {
  local p=$1
  local instance=$2
  local max=$3

  if [[ -z "$max" ]] ; then
    echo "no max"
    return 1
  fi

  local startt=$SECONDS
  local tmp=$TMP_DIR/wait_$instance.$$
  while true
  do
    if [[ $(( SECONDS - startt )) -gt $max ]] ; then
      echo "timeout reached: $max"
      break
    fi

    # greped on JSON output
    if get_instance_status $p $instance FULL | tee $tmp \
        | grep -q '"status": "ACTIVE"' ; then
      echo OK
      jq -r '.id+" "+.ipAddresses[0].ip+" "+.name+" "+.status' < $tmp
      break
    fi

    # wrong id ?
    if grep "Object not found" < $tmp ; then
      echo "wrong id: '$instance'"
      return 1
    fi

    echo -n '.'
    sleep $SLEEP_DELAY
  done

  if [[ $(wc -l < $tmp) -eq 0 ]] ; then
    rm -f $tmp
    return 1
  fi

  local ip=$(jq -r '(.ipAddresses[]|select(.type=="public")).ip' < $tmp)
  local sshuser=$(jq -r '.image.user' < $tmp)
  rm -f $tmp

  if [[ -z "$ip" || -z "$sshuser" ]] ; then
    echo "internal error, no ip found or no sshuser"
    return 1
  fi

  # also wait until we can ssh to it…
  while true
  do
    if [[ $(( SECONDS - startt )) -gt $max ]] ; then
      echo "ssh timeout reached: $max"
      break
    fi

    if ssh -q -o StrictHostKeyChecking=no $sshuser@$ip \
      "echo \"logged IN \$USER@$ip \$(hostname -f)\" $((SECONDS - startt ))s" \
          2> /dev/null; then
      return 0
    fi

    echo -n '.'
    sleep $SLEEP_DELAY
  done

  return 1
}

# cannot be called when sourced
fail() {
  echo "$*"
  exit 1
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

      tmp=$TMP_DIR/create_$hostname.$$
      create_instance $proj $snap $sshkey $hostname $init_script | tee $tmp
      instance=$(jq -r '.id' < $tmp)
      echo instance $instance
      echo "to wait instance: $0 wait $proj $instance"
      rm -f $tmp
    ;;
    wait)
      instance=$3
      if wait_for_instance $proj $instance $MAX_WAIT ; then
        echo "OK"
      else
        fail "timeout $MAX_WAIT or error, instance is unavailable"
      fi
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
      previous_flavor=$FLAVOR_NAME
      FLAVOR_NAME=$3
      echo "actual flavor_name $previous_flavor"
      if set_flavor $proj "$FLAVOR_NAME"
      then
        echo "new flavor '$FLAVOR_NAME' written in '$CONFFILE'"
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
      echo "free call (PROJECT_ID added): call $@"
      exit 1
      ;;
  esac
}

if [[ $sourced -eq 0 ]]
then
  loadconf "$CONFFILE"
  if [[ ! -z "$PROJECT_ID" ]]
  then
    if [[ "$1" == "call" ]]
    then
      main "$@"
    elif id_is_project "$2"
    then
      # PROJECT_ID in CONFFILE but forced on command line
      main "$@"
    else
      # skip 1 postional parameter
      main $1 $PROJECT_ID "${@:2:$#}"
    fi
  else
    # no PROJECT_ID
    main "$@"
  fi
  exit $?
fi
