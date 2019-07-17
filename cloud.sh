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
# all call can be prefixed with a PROJECT_ID: ./cloud.sh ACTION [PROJECT_ID] param ...
#
# Usage:
#  ./cloud.sh [show_projects]
#  ./cloud.sh help
#  ./cloud.sh snap_list|get_snap|snapshot_list
#  ./cloud.sh create IMAGE_ID HOSTNAME
#  ./cloud.sh wait INSTANCE_ID
#  ./cloud.sh list_ssh|get_ssh
#  ./cloud.sh instance_list|list
#  ./cloud.sh rename INSTANCE_ID NEW_NAME
#  ./cloud.sh status [INSTANCE_ID]
#  ./cloud.sh full_status|status_full [INSTANCE_ID]
#  ./cloud.sh make_snap INSTANCE_ID [HOSTNAME]
#  ./cloud.sh del_snap SNAPSHOT_ID
#  ./cloud.sh delete INSTANCE_ID...
#  ./cloud.sh set_all_instance_dns
#  ./cloud.sh set_project PROJECT_ID
#  ./cloud.sh set_flavor FLAVOR_NAME
#  ./cloud.sh list_flavor|flavor_list
#  ./cloud.sh call FUNCTION_NAME [AGRS...]
#  ./cloud.sh run SAVED_SCRIPT
#
#
# Actions:
#   show_projects  list projects for the current credential
#   help           list action and functions

# The line above, must be kept empty for extract_usage()
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
function extract_usage() {
   sed -n -e '/^# Usage:/,/^$/ s/^# \?//p' < $0
}
function list_callable_functions() {
  # doesn't match functions with 'function' prefix keyword
  grep -E '^([a-z_]+\(\))' $ME | sed -e 's/() {//' -e 's/)$//' -e 's/^/   /'
}
if [[ "$1" == "help" || "$1" == "--help" ]]
then
  extract_usage
  echo
  echo "List of callable functions:"
  list_callable_functions
  exit 0
fi

######################################################## configuration
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

LOGFILE=./my.log

# DEFAULTS
REGION=WAW1
DNS_TTL=60
DEFAULT_FLAVOR=s1-8

###################################### functions


# ovh-cli seems to require json def of all api in its own folder,
# we need to change??
# here we find ovh-cli in fixed nearby location
ovh_cli() {
  cd $OVH_CLIDIR
  ./ovh-eu "$@"
  local r=$?
  cd - > /dev/null
  log "$@ ==> $r"
  return $r
}


ovh_test_credential() {
  local credential="$1"
  local regexp="^This credential (is not valid|does not exist)"
  if [[ $credential =~ $regexp ]]
  then
    return 1
  else
    return 0
  fi
}

ovh_test_login() {
  local r=$(ovh_cli --format json auth current-credential)

  if ovh_test_credential "$r" ; then
    if [[ "$(jq -r '.status' <<< "$r")" == 'expired' ]] ; then
      return 1
    fi
  else
    return 1
  fi

  return 0
}

function log() {
  if [[ -n $LOGFILE ]]
  then
    echo "$(date "+%Y-%m-%d_%H:%M:%S"): $*" >> $LOGFILE
  fi
}


# function Usage: color_output "grep_pattern"
# dont filter output, only colorize tha grep_pattern
function color_output() {
  if [[ -n $1 ]]
  then
    # grep is a trick to colorize the current project in cloud.conf
    # this grep wont filter output, only colorize
    grep --color -E "(^|$1)"
  else
    cat
  fi
}

show_projects() {
  local clouds=$(ovh_cli --format json cloud project | jq -r .[])
  local r=$?
  local project
  local c

  for c in $clouds
  do
    project=$(ovh_cli --format json cloud project $c | jq -r .description)
    echo "$c $project" | color_output "$PROJECT_ID"
  done
  return $r
}

# list all: snapshot_id name in reverse order by creationDate
order_snapshots() {
  local p=$1
  # sort_by in on some advanced jq binary, version jq-1.6, it may fail on debian version
  ovh_cli --format json cloud project $p snapshot \
    | jq -r '.|sort_by(.creationDate)|reverse|.[]|
      .id+" "+.name+" "+.region'
}

# draft snapshot ordering helper to be used in saved scripts
last_snapshot() {
  # p as $1
  # pattern as $2
  order_snapshots $1 | grep "$2" | head -1 | awk '{print $1}'
}

# function Usage:
#   snapshot_list $project_id [-o]
#   $order if present force list to be order by creationDate decreasing
snapshot_list() {
  local p=$1
  local order=$2
  local order_filter='.[]|'

  if [[ -n $order ]]
  then
    # sort_by is not supported by all version of jq so not by default
    order_filter='.|sort_by(.creationDate)|reverse|.[]|'
  fi
  ovh_cli --format json cloud project $p snapshot \
    | jq -r "$order_filter
      .id
      +\" \"+.name
      +\" \"+.status
      +\" \"+.region
      +\" \"+.creationDate
      "
}

get_snapshot_status() {
  local p=$1
  local snapshot_id=$2

  if [[ -z $snapshot_id ]]
  then
    echo "no snapshot_id"
    return 1
  fi

  ovh_cli --format json cloud project $p snapshot $snapshot_id
  return 0
}

delete_snapshot() {
  local p=$1
  local snap_id=$2
  ovh_cli --format json cloud project $p snapshot $snap_id delete \
    | grep -E '(^|status.*)'
}

snapshot_make_increment() {
  local p=$1
  local instance_id=$2

  # read instance information
  local instance_json=$(ovh_cli --format json cloud project $p instance $instance_id)

  # read json data
  local image_visibility=$(jq -r .image.visibility <<< "$instance_json")
  local image_name=$(jq -r .image.name <<< "$instance_json")

  # compute new name for the snapshot
  local new_snap_name=""
  local old_snap_count=0
  if [[ $image_visibility == 'private' ]] ; then
    new_snap_name=${image_name%-*}
    # extract counter if any
    old_snap_count=${image_name#$new_snap_name-}
    if [[ ! $old_snap_count =~ ^[0-9]+$ ]] ; then
      # force number
      old_snap_count=0
    fi
  else
    new_snap_name=$(jq -r .name <<< "$instance_json")
  fi

  echo "old_snap_count $old_snap_count"
  new_snap_name="${new_snap_name}-$((old_snap_count + 1))"
  echo "image_name $image_name new_snap_name $new_snap_name old_snap_count $old_snap_count"

  echo "snapshot_create $p $instance_id \"$new_snap_name\""
  snapshot_create $p $instance_id "$new_snap_name"
  local new_snapshot_json=$(ovh_cli --format json cloud project $p snapshot |
      jq -r ".[]|select(.name == \"$new_snap_name\")")
  jq . <<< "$new_snapshot_json"
  local wait_timeout=120
  if wait_for_snapshot "$p" "$(jq -r .id <<< "$new_snapshot_json")" $wait_timeout; then
    echo "OK snapshoted"
    return 0
  else
    echo "error: timeout $wait_timeout or error, snapshot is unavailable"
    return 1
  fi
}

instance_snapshot_and_delete() {
  local p=$1
  local instance_id=$2
  if snapshot_make_increment $p $instance_id; then
    echo "deleting instance_id $instance_id"
    delete_instance "$p" "$instance_id"
  fi
}

get_flavor() {
  local p=$1
  local flavor_name=$2
  # default value $REGION
  local region=${3:-$REGION}

  if [[ -z "$flavor_name" ]]
  then
    ovh_cli --format json cloud project $p flavor \
      | jq -r '.[]|select(.osType != "windows")
          .id+" "+.name+" "+(.vcpus|tostring)+" CPU "+(.ram|tostring)+" Mo "+.region'
  else
    # must return a single flavor for a region
    ovh_cli --format json cloud project $p flavor \
      | jq -r ".[]|select(.name == \"$flavor_name\" and .region == \"$region\").id"
  fi
}

# outputs json
create_instance() {
  local p=$1
  local image_id=$2
  local sshkey=$3
  local hostname=$4
  local init_script=$5

  local myflavor=$FLAVOR_NAME
  if [[ -z "$myflavor" ]]
  then
    # you can define it in cloud.conf
    myflavor=$DEFAULT_FLAVOR
  fi
  local flavor_id=$(get_flavor $p $myflavor)

  if [[ ! -z "$init_script" && -e "$init_script" ]]
  then
    # with an init_script
    local tmp_init=$(preprocess_init "$init_script")

    # we merge the init_script in the outputed json so it becomes parsable
    ovh_cli --format json cloud project $p instance create \
      --flavorId $flavor_id \
      --imageId $image_id \
      --monthlyBilling false \
      --name "$hostname" \
      --region $REGION \
      --sshKeyId $sshkey \
      --userData "$(cat $tmp_init)" \
        | jq ". + {\"init_script\" : \"$tmp_init\"}"

    rm $tmp_init
  else
    # without init_script
    ovh_cli --format json cloud project $p instance create \
      --flavorId $flavor_id \
      --imageId $image_id \
      --monthlyBilling false \
      --name "$hostname" \
      --region $REGION \
      --sshKeyId $sshkey
  fi
}

# load a init_script and merge some content
preprocess_init() {
  local init_script="$1"

  # extract APPEND_SCRIPTS value
  local append_scripts=$(sed -n -e '/^APPEND_SCRIPTS="/,/^"$/ p' $init_script)

  # copy to shared memory
  local tmp_init="/dev/shm/tmp_init.$$"
  cp $init_script $tmp_init

  # compose with included files
  local s
  for s in $(sed -e '1 d' -e '$ d' <<< "$append_scripts")
  do
    echo "# included: $s" >> $tmp_init
    cat $s >> $tmp_init
  done

  echo $tmp_init
}

instance_list() {
  local p=$1
  # filter on public ip address only
  ovh_cli --format json cloud project $p instance \
    | show_json_instance many
}

rename_instance() {
  local p=$1
  local instanceId=$2
  local new_name="$3"
  ovh_cli --format json cloud project $p instance $2 put \
    --instanceName "$new_name"
}

# more versatile version of instance_list
get_instance_status() {
  local p=$1
  local i=$2
  # $3 == FULL : full json output

  if [[ $# -eq 3 && "$3" == "FULL" ]]
  then
    if [[ "$i" == "ALL" ]]
    then
      ovh_cli --format json cloud project $p instance
    else
      ovh_cli --format json cloud project $p instance $i
    fi
  elif [[ -z "$i" ]]
  then
    # list all in text format
    # See Also: instance_list
    # ipAddresses select IPv4 public only IP
    ovh_cli --format json  cloud project $p instance \
      | show_json_instance many
  else
    # one instance list summary in text
    ovh_cli --format json  cloud project $p instance $i \
      | show_json_instance
  fi
}

# DRY: format json output
# this filter JSON ouput for bash with some fields
# function Usage:
#   json_input | show_json_instance many  => fister output for a list
#   json_input | show_json_instance       => fister output for a single instance
#
# field Order is important
#  id ip  name status region flavor
show_json_instance() {
  # filter IPv4
  # get flavor through planCode first part as present in both JSON
  local jq_filter='.id+" "+
        (
        .ipAddresses[]|
          select(.version == 4 and  .type == "public")
        ).ip
        +" "+.name
        +" "+.status
        +" "+.region
        +" "+(.planCode|split(".")[0])
        '

  if [[ $# -eq 1 && "$1" == "many" ]]
  then
    jq -r ".[]|$jq_filter"
  else
    jq -r "$jq_filter"
  fi
}

# DRY func
# function Usage: get_ip_from_json < $tmp_json_input
get_ip_from_json() {
  show_json_instance | awk '{print $2}'
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
  # remove trailing dot if any
  local fqdn=${1%.}
  local domain=$(get_domain $fqdn)
  local subdomain=${fqdn/.$domain/}
  # search for fieldType A as default
  local fieldType=${2:-A}

  ovh_cli --format json domain zone $domain record \
    --subDomain $subdomain \
    --fieldType $fieldType \
    | jq -r '.[0]'
}

# set forward and reverse DNS via API
# same order as given in instance_list: ip, fqdn
# instance needs to be ACTIVE and have an IP
set_ip_domain() {
  local ip=$1
  local fqdn=$2

  local domain=$(get_domain $fqdn)

  set_forward_dns $ip $fqdn

  # wait a bit
  sleep 1

  # reverse, doesn't work in ovh_cli
  #ovh_cli ip $ip reverse --ipReverse $ip --reverse ${fqdn#.}.
  # python wrapper
  $SCRIPTDIR/ovh_reverse.py $ip ${fqdn#.}.

  echo "  if needed: re-set reverse DNS with:"
  echo "  $SCRIPTDIR/ovh_reverse.py $ip ${fqdn#.}. "
}

get_domain() {
  local regexp="\.([a-zA-Z0-9-]+\.[a-z]+)$"
  if [[ "$1" =~ $regexp ]]
  then
    echo ${BASH_REMATCH[1]}
    return 0
  else
    return 1
  fi
}


# update or set a forward DNS record
# parameter must have the same order as given in instance_list: ip fqdn
set_forward_dns() {
  local ip=$1
  local fqdn=$2
  local domain=$(get_domain $fqdn)
  local subdomain=${fqdn/.$domain/}

  local record=$(get_domain_record_id $fqdn)

  if [[ -z "$record" || "$record" == null ]]
  then
    # must be created
    ovh_cli --format json domain zone $domain record create \
      --target $ip --ttl $DNS_TTL --subDomain $subdomain --fieldType A
  else
    # update existing recors
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

snapshot_create() {
  local p=$1
  local i=$2
  local snap_name="$3"
  ovh_cli cloud project $p instance $i snapshot create \
    --snapshotName "$snap_name"
}

id_is_project() {
  # return an array of project_id, -1 if not found
  local json=$(ovh_cli --format json cloud project)
  if ovh_test_credential "$json" ; then
    # if credential are wrong this is not a valid JSON
    jq -r '.[]' <<< "$json" | grep -q "^$1\$" && return 0
  else
    # fail
    return 1
  fi
}

set_project() {
  local p=$1

  # check if the project_id exists
  if id_is_project $p
  then
    write_conf "$CONFFILE" "PROJECT_ID=$p"
    return 0
  fi

  echo "error: '$p' seems not to be a valid project"
  return 1
}

# function Usage:
#   write_conf conffile VAR=value VAR2=value2 DELETE=VAR3 ...
write_conf() {
  local conffile="$1"
  shift
  # vars $2... format "var=val" or "DELETE=var_name"

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
      # warning: call somefunc "value separated space" is not
      # transmitted as ONE argument, but splitted during eval
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

region_list() {
   ovh_cli --format json cloud project $PROJECT_ID region | jq -r '.[]'
}

wait_for() {
  local p=$1
  local wait_for=$2
  local object_id=$3
  local max=$4

  if [[ -z "$max" ]] ; then
    echo "no max"
    return 1
  fi

  local startt=$SECONDS
  local tmp=$TMP_DIR/wait_$object_id.$$
  local wait_for_ssh=false
  local cmd=""

  case $wait_for in
  instance)
    # greped against JSON output because we are going to
    # extract many informations IPv4, sshuser
    cmd="get_instance_status $p $object_id FULL | tee $tmp \
        | grep -q '\"status\": \"ACTIVE\"'"
    #'"
    cmd_success="show_json_instance < $tmp"
    wait_for_ssh=true
    ;;
  snapshot)
    cmd="get_snapshot_status $p $object_id FULL | tee $tmp \
        | grep -q -i '\"status\": \"active\"'"
    #'"
    cmd_success="jq . < $tmp"
    wait_for_ssh=false
    ;;
  *)
    echo "don't know how to get status for '$wait_for'"
    return 1
    ;;
  esac

  while true
  do
    if [[ $(( SECONDS - startt )) -gt $max ]] ; then
      echo "timeout reached: $max"
      break
    fi

    if eval "$cmd" ; then
      echo OK
      eval "$cmd_success"
      break
    fi

    # wrong id ?
    if grep "Object not found" < $tmp ; then
      echo "wrong id: '$object_id'"
      return 1
    fi

    echo -n '.'
    sleep $SLEEP_DELAY
  done

  if [[ $(wc -l < $tmp) -eq 0 ]] ; then
    rm -f $tmp
    return 1
  fi

  if $wait_for_ssh ; then
    # read IPv4
    local ip=$(get_ip_from_json < $tmp)
    local sshuser=$(jq -r '.image.user' < $tmp)
    rm -f $tmp

    if [[ -z "$ip" || -z "$sshuser" ]] ; then
      echo "internal error, no ip found or no sshuser"
      return 1
    fi

    # also wait until we can ssh to the new instance
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

    # no ssh success so we have failed
    return 1
  else
    # success
    rm -f $tmp
    return 0
  fi
}

wait_for_instance() {
  local p=$1
  local instance_id=$2
  local max=$3

  wait_for "$p" instance "$instance_id" "$max"
  return $?
}

wait_for_snapshot() {
  local p=$1
  local snapshot_id=$2
  local max=$3

  wait_for "$p" snapshot "$snapshot_id" "$max"
  return $?
}

# cannot be called when sourced
fail() {
  echo "$*"
  exit 1
}

###################################### main

# prefix with 'function' keyword to not to be greped with --help. See extract_usage
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
    snap_list|get_snap|snapshot_list)
      ordering=$3
      snapshot_list $proj $ordering
    ;;
    create)
      #image_id can also be a snapshot_id
      image_id=$3
      sshkey=$(get_sshkeys $proj sylvain)
      hostname=$4
      init_script=$5

      tmp=$TMP_DIR/create_$hostname.$$
      create_instance $proj $image_id $sshkey $hostname $init_script | tee $tmp
      instance=$(jq -r '.id' < $tmp)
      echo "instance $instance"
      echo "# to wait instance: $0 wait $proj $instance"
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
    instance_list|list)
      instance_list $proj
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
    full_status|status_full)
      instance=$3
      get_instance_status $proj "$instance" FULL
      ;;
    make_snap)
      instance=$3
      host="$4"
      if [[ -z "$host" ]]
      then
        host=$(get_instance_status $proj $instance | awk '{print $3}')
      fi
      snapshot_create $proj $instance "$host"
      ;;
    del_snap|snap_delete)
      snap_id=$3
      if [[ $# -gt 3 ]]
      then
        # array slice on $@ 3 to end
        multi_snapshot=${@:3:$#}
        for s in $multi_snapshot
        do
          delete_snapshot $proj $s
        done
      else
        # single snapshot
        delete_snapshot $proj $snap_id
      fi
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
        # fetch all instance_id and delete
        # WARNING: no confirm requiered
        if [[ "$instance" == ALL ]]
        then
          while read i ip hostname
          do
            echo "deleting $i $hostname…"
            delete_instance $proj $i
          done <<< "$(instance_list $proj)"
        else
          # single instance delete
          delete_instance $proj $instance
        fi
      fi
      ;;
    set_all_instance_dns)
      while read i ip hostname
      do
        echo "set_ip_domain for $hostname"
        set_ip_domain $ip $hostname
      done <<< "$(instance_list $proj)"
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
    list_flavor|flavor_list)
      get_flavor $proj
      exit 0
      ;;
    call)
      # free function call, careful to put args in good order
      call_function=$2
      shift 2
      call_func $call_function "$@"
      ;;
    run)
      # run the given scripts as an internal commands
      src="$3"
      shift 3
      # search code loop lookup
      for f in $src "saved/$3"
      do
        if [[ -e "$src" ]] ; then
          # argument from $4 ...
          source $src "$@"
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


################################################################## exec code
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
