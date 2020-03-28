#!/usr/bin/env bash
# vim: set et sts=2 ts=2 sw=2:
#
# OVH public cloud API wrapper
#
# require https://github.com/yadutaf/ovh-cli + pip requirement + auth
# require jq (c++ json parser for bash)
# See: install.sh
#
# Credential authenticatoin with:
# OVH Europe: https://eu.api.ovh.com/createApp/
# store all your OVH api credential into ovh.conf
# See: mk_cred.py
#
# Usage:
#  ./cloud.sh [show_projects]
#  ./cloud.sh -h | help
#  ./cloud.sh snap_list|get_snap|snapshot_list [-o]
#  ./cloud.sh image_list [OS_TYPE] [OUTPUT_FORMAT]
#  ./cloud.sh create IMAGE_ID SSHKEY_ID HOSTNAME [INIT_SCRIPT]
#  ./cloud.sh instance_list|list
#  ./cloud.sh wait INSTANCE_ID
#  ./cloud.sh snap_wait SNAPSHOT_ID
#  ./cloud.sh list_ssh|get_ssh
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
# All call can be prefixed with a PROJECT_ID: ./cloud.sh ACTION [PROJECT_ID] param ...
#
# Actions:
#   show_projects     list projects for the current credential
#   help              list action and functions
#   snap_list         list all snapshot availables in the current project
#   create            create an instance with the given paremters
#   wait              polling wait for an instance or a snapshot to complete
#   list_ssh          list ssh keys for the current project
#   list              list running instances in the current project
#   rename            rename an instance
#   status            same as list, give the status of an instance
#   full_status|status_full [INSTANCE_ID]
#   make_snap INSTANCE_ID [HOSTNAME]
#   del_snap SNAPSHOT_ID
#   delete INSTANCE_ID...
#   set_all_instance_dns
#   set_project PROJECT_ID
#   set_flavor FLAVOR_NAME
#   list_flavor|flavor_list
#   call FUNCTION_NAME [AGRS...]
#   run SAVED_SCRIPT
#
# Arguments:
#   INSTANCE_ID      An openstack instance_id (returned by list)

# The empty line above, must be kept empty for extract_usage()
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


############################################# functions for help

# display help from script header comment
function extract_usage()
{
   sed -n -e '/^# Usage:/,/^$/ s/^# \?//p' < $0
}
function list_callable_functions()
{
  # doesn't match functions with 'function' prefix keyword
  grep -E '^([a-z_]+\(\))' $ME | sed -e 's/()$//' -e 's/)$//' -e 's/^/   /'
}

############################################# hook_display_help
if [[ $# -ge 1 && ( "$1" == "help" || "$1" == "--help" || "$1" == '-h' ) ]]
then
  extract_usage
  echo
  echo "List of callable functions:"
  list_callable_functions
  exit 0
fi

######################################################## configuration
SCRIPTDIR=$(dirname $ME)
DEBUG=1
DEFAULT_SSH_KEY_NAME=""

# you can "export CONFFILE=some_file" to override
# usefull for testing
if [[ -z "$CONFFILE" ]]
then
  # default value
  CONFFILE="$SCRIPTDIR/cloud.conf"
fi

# globals can be overridden in $CONFFILE
# see loadconf()
# OUR_VARS list all vars that can be exported and preserved by loadconf()
OUR_VARS="REGION"

# delays in seconds
MAX_WAIT=210
SLEEP_DELAY=2

# for temporary output on ramdrive
TMP_DIR=/dev/shm

LOGFILE=./my.log
export LOGFILE

# OVH DEFAULTS
DEFAULT_REGION=WAW1
DNS_TTL=60
DEFAULT_FLAVOR=s1-2


###################################### functions

myovh_cli() {
# "ux?--d2f ?ovh_cliimyea GET /=substitute(@u, ' ', '/', 'g')
# ^vt "kxi\"\" :F\ikF"ldf-f:wi\"eea\",
  if [[ -t 0 ]] ; then
    log "ovh-cli $1 $2 '${3:-}'"
    ~/.local/bin/ovh-cli "$@" 2> /dev/null
  else
    # stdin
    local stdin=$(cat)
    log "ovh-cli $1 $2 '$stdin'"
    echo "$stdin" | ~/.local/bin/ovh-cli "$@" 2> /dev/null
  fi
}

# read data from inifile ovh.conf format for ovh api
get_ovh_conf() {
  awk -F '='  "/^$1=/ { print \$2}" $(dirname $BASH_SOURCE)/ovh.conf
}

ovh_test_credential()
{
  local credential="$1"
  local regexp="^This credential (is not valid|does not exist)"
  if [[ $credential =~ $regexp ]]
  then
    return 1
  else
    return 0
  fi
}

ovh_test_login()
{
  local r=$(myovh_cli GET /auth/currentCredential)

  if ovh_test_credential "$r" ; then
    if [[ "$(jq -r '.status' <<< "$r")" == 'expired' ]] ; then
      return 1
    fi
  else
    return 1
  fi

  return 0
}

function log()
{
  if [[ -n $LOGFILE ]]
  then
    echo "$(date "+%Y-%m-%d_%H:%M:%S"): $*" >> $LOGFILE
  fi
}


# Call: color_output "grep_pattern"
# dont filter output, only colorize the grep_pattern
function color_output()
{
  if [[ -n $1 ]]
  then
    # grep is a trick to colorize the current project in cloud.conf
    # this grep wont filter output, only colorize
    grep --color -E "(^|$1)"
  else
    cat
  fi
}

show_projects()
{
  local clouds=$(myovh_cli GET /cloud/project | jq -r .[])
  local r=$?
  local project
  local c

  for c in $clouds
  do
    project=$(myovh_cli GET /cloud/project/$c | jq -r .description)
    echo "$c $project" | color_output "$PROJECT_ID"
  done
  return $r
}

# list all: snapshot_id name in reverse order by creationDate
order_snapshots()
{
  local p=$1
  # sort_by in on some advanced jq binary, version jq-1.6, it may fail on debian version
  myovh_cli GET /cloud/project/$p/snapshot  \
    | jq -r '.|sort_by(.creationDate)|reverse|.[]|
      .id+" "+.name+" "+.region'
}

# draft snapshot ordering helper to be used in saved scripts
last_snapshot()
{
  # p as $1
  # pattern as $2
  order_snapshots $1 | grep "$2" | head -1 | awk '{print $1}'
}

# Call: snapshot_list $project_id [-o] [output_type]
#   $order if present force list to be order by creationDate decreasing
#   sorting require jq 1.6
snapshot_list()
{
  local p=$1
  local order=${2:-no}
  local output_type=${3:-text}
  local order_filter='.'

  if [[ -n $order ]] && [[ $order == '-o'  || $order == 'yes' ]]
  then
    # sort_by is not supported by all version of jq so not by default
    order_filter='.|sort_by(.creationDate)|reverse'
  fi

  # echo "order $order output_type $output_type"

  case $output_type in
    json)
      myovh_cli GET /cloud/project/$p/snapshot  \
        | jq -r "$order_filter"
      ;;
    *)
      myovh_cli GET /cloud/project/$p/snapshot  \
        | jq -r "$order_filter |.[]|
          .id
          +\" \"+.name
          +\" \"+.status
          +\" \"+.region
          +\" \"+.creationDate
          "
      ;;
  esac
}

get_snapshot_status()
{
  local p=$1
  local snapshot_id=$2

  if [[ -z $snapshot_id ]]
  then
    echo "no snapshot_id"
    return 1
  fi

  myovh_cli GET /cloud/project/$p/snapshot/$snapshot_id
  return 0
}

delete_snapshot()
{
  local p=$1
  local snap_id=$2
  myovh_cli DELETE /cloud/project/$p/snapshot/$snap_id  \
    | tee del_snap.json | grep -E '(^|status.*)'
}

snapshot_make_increment()
{
  local p=$1
  local instance_id=$2

  # read instance information
  local instance_json=$(myovh_cli GET /cloud/project/$p/instance/$instance_id)

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
  local new_snapshot_json=$(myovh_cli GET /cloud/project/$p/snapshot |
      jq -r ".[]|select(.name == \"$new_snap_name\")")
  jq . <<< "$new_snapshot_json"
  local wait_timeout=240
  if wait_for_snapshot "$p" "$(jq -r .id <<< "$new_snapshot_json")" $wait_timeout; then
    echo "OK snapshoted"
    return 0
  else
    error "timeout $wait_timeout or error, snapshot is unavailable"
    return 1
  fi
}

# Call: snapshot_restore_instance $project_id snap_pattern [FLAVOR_NAME] [<force_hostname>]
snapshot_restore_instance()
{
  set -euo pipefail

  local p=$1

  echo "args: $*"
  if [[ $# -lt 2 ]]
  then
    error "error: snapshot_restore_instance missing argument"
    return 1
  fi

  local snap_pattern=$2

  if [[ $# -ge 3 ]]
  then
    FLAVOR_NAME=$3
  fi

  local force_hostname=""
  if [[ $# -ge 4 ]]
  then
    force_hostname=$4
  fi

  echo "fetching cloud data ..."

  local myimage=$(last_snapshot $p "$snap_pattern")
  local image_json=$(get_snapshot_status $p $myimage FULL)
  local hostname=$(jq -r .name <<< "$image_json")
  local image_region=$(jq -r .region <<< "$image_json")

  local mysshkey=$(get_sshkeys $p | awk "/$DEFAULT_SSH_KEY_NAME/ {print  \$1; exit}")
  local myinit_script=${DEFAULT_RESTORE_SCRIPT:-}

  fail_if_empty myimage hostname mysshkey image_region

  # remove backup count suffix
  local myhostname=$(echo $hostname | sed -e 's/-[0-9]\+$//')
  if [[ -n $force_hostname ]] ; then
    debug "force_hostname: '$myhostname' becomes '$force_hostname'"
    myhostname=$force_hostname
  fi

  # reporting output
  cat << EOT
restoring for pattern '$snap_pattern' => myimage $myimage
flavor: $FLAVOR_NAME
image hostname '$hostname' ==> myhostname '$myhostname'
sshKeyId '$mysshkey'
region: $image_region
EOT

  if [[ $REGION != $image_region ]] ; then
    debug "REGION was set to '$REGION' image_region '$image_region' FORCED"
    # force region from image
    REGION=$image_region
  fi

  local instance
  debug "create_instance $p \"$myimage\" \"$mysshkey\"  \"$myhostname\" \"$myinit_script\""
  instance=$(create_instance $p "$myimage" "$mysshkey"  "$myhostname" "$myinit_script" \
    | jq_or_fail -r '.id')

  if [[ ! $instance =~ ^[0-9a-f-]+$ ]] ; then
    fail "instance_id invalid: '$instance'"
  fi

  local ip instance_json
  if wait_for_instance $p "$instance" 600 ; then
    instance_json=$(get_instance_status $p $instance FULL)
    ip=$(get_ip_from_json <<< "$instance_json")
    # re-read hostname from JSON
    hostname=$(jq -r '.name' <<< "$instance_json")
    echo "hostname from JSON: $hostname, using $myhostname"
    set_ip_domain $ip $myhostname
  fi

  # post setup if success
  if [[ -n "$ip" ]]
  then
    # empty my ssh/known_hosts
    ssh-keygen -f "/home/sylvain/.ssh/known_hosts" -R $myhostname
    ssh-keygen -f "/home/sylvain/.ssh/known_hosts" -R $ip
  fi
}

############################## instance manipulation

instance_snapshot_and_delete()
{
  local p=$1
  local instance_id=$2
  if snapshot_make_increment $p $instance_id; then
    echo "deleting instance_id $instance_id"
    delete_instance "$p" "$instance_id"
  fi
}

get_flavor()
{
  local p=$1
  local flavor_name=$2
  # default value $REGION
  local region=${3:-$REGION}

  if [[ -z "$flavor_name" ]]
  then
    myovh_cli GET /cloud/project/$p/flavor \
      | jq_or_fail -r '.[]|select(.osType != "windows")
          .id+" "+.name+" "+(.vcpus|tostring)+" CPU "+(.ram|tostring)+" Mo "+.region'
  else
    # must return a single flavor for a region
    myovh_cli GET /cloud/project/$p/flavor  \
      | jq_or_fail -r ".[]|select(.name == \"$flavor_name\" and .region == \"$region\").id"
  fi
}

# Call: json_append_key KEY_NAME "VALUE"
# append a JSON key value to stdin, JSON formated by line
json_append_key()
{
  local key=$1
  # escape backslashes \ and then escape / for sed itself
  local value=$(sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' <<< "$2")
  sed -e "s/\"$/\",\n  \"$key\" : \"$value\"/"
}

# Call: create_instance PROJECT_ID IMAGE_ID SSHKEY_ID HOSTNAME INIT_SCRIPT
# you can change flavor by defining FLAVOR_NAME global variable.
# outputs json
# INIT_SCRIPT is preprocessed on the instance it is found here:
#  /var/lib/cloud/instance/scripts/part-001
create_instance()
{
  local p=$1
  local image_id=$2
  local sshkey=$3
  local hostname=$4
  local init_script=${5:-}

  fail_if_empty sshkey hostname

  local myflavor=$FLAVOR_NAME

  debug "create_instance $p \"$image_id\" \"$sshkey\"  \"$hostname\" \"$init_script\""

  if [[ -z "$myflavor" ]]
  then
    # you can define it in cloud.conf
    myflavor=$DEFAULT_FLAVOR
  fi
  local flavor_id=$(get_flavor $p $myflavor)

  if [[ -z "$flavor_id" ]]
  then
    fail "'$myflavor' not found flavor_id on region $REGION"
  fi

  local create_json ret tmp_init
  tmp_init=""
  create_json="$(cat << END
    {
      "flavorId": "$flavor_id",
      "imageId": "$image_id",
      "monthlyBilling": false,
      "name": "$hostname",
      "region": "$REGION",
      "sshKeyId": "$sshkey"
    }
END
)"

  if [[ -n "$init_script" && -e "$init_script" ]]
  then
    tmp_init=$(preprocess_init --json "$init_script")
    create_json=$(json_append_key userData "$(cat $tmp_init)" <<< "$create_json")
  fi

  ## we merge the init_script in the outputed json so it becomes parsable
  myovh_cli POST "/cloud/project/$p/instance" <<< "$create_json" \
      | jq_or_fail ". + {\"init_script\" : \"$tmp_init\"}"
  ret=$?

  if [[ $ret -eq 0 && -e $tmp_init ]] ; then
    rm $tmp_init
  fi
  return $ret
}

# load a init_script and merge some content
# This helper provide inclusion mechanisme for init_script
# Call: preprocess_init [--json] FILE_NAME
#
# How does it work:
# Add a variable in your script for appending the content of other bash script:
#
#    APPEND_SCRIPTS="
#    init/init_upgrade.sh
#    /home/sylvain/code/agu3l/projet-ville-annecy/scripts/post_install
#    "
# It is extracted with sed AND MUST be double quoted AND in first column
# There's no bash variable evaluation in the file list content.
# File are searched relative to the current $PWD
#
preprocess_init()
{
  local json=0
  local init_script="$1"

  if [[ $1 == '--json' ]] ; then
    json=1
    init_script="$2"
  fi

  # extract APPEND_SCRIPTS value
  local append_scripts=$(sed -n -e '/^APPEND_SCRIPTS="/,/^"$/ p' $init_script)

  # copy to shared memory
  local tmp_dir="$(mktemp -d /dev/shm/tmp_init.XXXXX)"
  local tmp_init="$tmp_dir/$(basename $init_script)"
  local init_json="${tmp_init}.json"
  cp $init_script $tmp_init

  # compose with included files
  local s
  for s in $(sed -e '1 d' -e '$ d' <<< "$append_scripts")
  do
    echo "# included: $s" >> $tmp_init
    cat $s >> $tmp_init
  done

  if [[ $json -eq 1 ]] ; then
    # escape quote for JSON
    perl $SCRIPTDIR/utf8_to_h4.pl $tmp_init > $init_json

    if [[ $DEBUG -eq 1 ]] ; then
      cat <( echo -n '{ "v" :"') $init_json <(echo '"}') > $init_json.2.json
    fi

    echo $init_json
  else
    echo $tmp_init
  fi
}

instance_list()
{
  local p=$1
  # filter on public ip address only
  myovh_cli GET /cloud/project/$p/instance  \
    | show_json_instance many
}

rename_instance()
{
  local p=$1
  local instanceId=$2
  local new_name="$3"

  myovh_cli PUT /cloud/project/$p/instance/$instanceId "{\"instanceName\" : \"$new_name\"}"
}

# more versatile version of instance_list
get_instance_status()
{
  local p=$1
  local i=$2
  # $3 == FULL : full json output

  if [[ $# -eq 3 && "$3" == "FULL" ]]
  then
    if [[ "$i" == "ALL" ]]
    then
      myovh_cli GET /cloud/project/$p/instance
    else
      myovh_cli GET /cloud/project/$p/instance/$i
    fi
  elif [[ -z "$i" ]]
  then
    # list all in text format
    # See Also: instance_list
    # ipAddresses select IPv4 public only IP
    myovh_cli GET /cloud/project/$p/instance   \
      | show_json_instance many
  else
    # one instance list summary in text
    myovh_cli GET /cloud/project/$p/instance/$i   \
      | show_json_instance
  fi
}

# DRY: format json output
# this filter JSON ouput for bash with some fields
# Call:
#   json_input | show_json_instance many  => fister output for a list
#   json_input | show_json_instance       => fister output for a single instance
#
# field Order is important
#  id ip  name status region flavor
#
# When instant is in error the json is:
#     {
#       "created": "2020-02-16T05:46:35Z",
#       "flavorId": "30223b8d-0b3e-4a42-accb-ebc3f5b0194c",
#       "id": "e35826e2-db35-4dd9-a3a3-101ba97a7157",
#       "imageId": "d3f931aa-d4ca-40d4-ad4c-a31a2d0a5e3b",
#       "ipAddresses": [],
#       "monthlyBilling": null,
#       "name": "static.obj8.ovh",
#       "operationIds": [],
#       "planCode": "s1-2.consumption",
#       "region": "GRA7",
#       "sshKeyId": "63336c73646d4670626a49774d54593d",
#       "status": "ERROR"
#   }
show_json_instance()
{
  # filter IPv4
  # get flavor through planCode first part as present in both JSON
  # +" "+(.planCode|split(".")[0])
  local jq_filter='.id+" "+
        (
        if (.ipAddresses | length) > 0 then
          (.ipAddresses[] | select(.version == 4 and  .type == "public")).ip
				else
					"no_ip"
				end
        )
        +" "+.name
        +" "+.status
        +" "+.region
        +" "+.planCode
        +" "+.image.user
        '

  if [[ $# -eq 1 && "$1" == "many" ]]
  then
    jq -r ".[]|$jq_filter"
  else
    jq -r "$jq_filter"
  fi
}

# DRY func
# Call: get_ip_from_json < $tmp_json_input
get_ip_from_json()
{
  show_json_instance | awk '{print $2}'
}

# output json
list_sshkeys()
{
  local p=$1
  myovh_cli GET /cloud/project/$p/sshkey
}

# output text
get_sshkeys()
{
  local p=$1
  local name=${2:-}
  if [[ ! -z "$name" ]]
  then
    # only one id
    list_sshkeys $p  | jq -r ".[]|select(.name == \"$name\").id"
  else
    # list all
    list_sshkeys $p | jq -r '.[]|.id+" "+.name'
  fi
}

list_manageable_domains()
{
  myovh_cli GET /domain  | jq -r '.[]'
}

get_domain_zone()
{
  # get the full zone in txt format
  myovh_cli GET /domain/zone/$1/export  | jq -r
}

# Call: get_domain_record_id $fqdn [$fieldType]
get_domain_record_id()
{
  # remove trailing dot if any
  local fqdn=${1%.}
  local domain=$(get_domain $fqdn)
  local subdomain=${fqdn/.$domain/}
  # search for fieldType A as default
  local fieldType=${2:-A}

  local url="/domain/zone/$domain/record?subDomain=$subdomain&fieldType=$fieldType"
  myovh_cli GET "$url" | jq -r '.[0]'
}

get_domain_all_records()
{
  # remove trailing dot if any
  local domain=${1%.}

  if [[ -z $domain ]] ; then
    error "domain empty"
    return 1
  fi

  local record_ids=$(myovh_cli GET /domain/zone/$domain/record  | jq -r '.[]')
  local r
  for r in $record_ids
  do
    echo "$r $(myovh_cli GET /domain/zone/$domain/record/$r  | \
      jq -r '.subDomain
          +" "+(.ttl|tostring)
          +" IN "+.fieldType
          +" "+.target'
      )"
  done
}

set_ip_reverse()
{
  local ip=$1
  local fqdn=$2
  myovh_cli POST /ip/$ip/reverse "{\"ipReverse\" : \"$ip\", \"reverse\" : \"${fqdn#.}.\"}"
}

# set forward and reverse DNS via API
# same order as given in instance_list: ip, fqdn
# instance needs to be ACTIVE and have an IP
set_ip_domain()
{
  local ip=$1
  local fqdn=$2

  local domain=$(get_domain $fqdn)

  set_forward_dns $ip $fqdn
  local ret=$?

  # wait a bit
  sleep 1

  set_ip_reverse $ip $fqdn

  echo "  if needed: re-set reverse DNS with:"
  echo "  ./cloud.sh call set_ip_reverse $ip $fqdn"

  return $ret
}

get_domain()
{
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
set_forward_dns()
{
  local ip=$1
  local fqdn=$2
  local domain=$(get_domain $fqdn)
  local subdomain=${fqdn/.$domain/}

  local record=$(get_domain_record_id $fqdn)

  local ret
  # TODO: merge code with set_dns_record() ?
  if [[ -z "$record" || "$record" == null ]]
  then
    # must be created
    myovh_cli POST /domain/zone/$domain/record  \
      "{
      \"target\" : \"$ip\",
      \"ttl\" : \"$DNS_TTL\",
      \"subDomain\" : \"$subdomain\",
      \"fieldType\" : \"A\"
      }"
    ret=$?
  else
    if ! check_is_protected_record $fqdn ; then
      # update existing record
      myovh_cli PUT /domain/zone/$domain/record/$record \
        "{
        \"target\" : \"$ip\",
        \"ttl\" : \"$DNS_TTL\"
        }"
      ret=$?
    else
      echo "record protected '$fqdn'"
      ret=1
    fi
  fi

  if [[ $ret -eq 0 ]] ; then
    # flush domain modification
    dns_flush $domain
  fi

  return $ret
}

# update or set a free DNS record
# Call: set_dns_record [--no-flush] $fqdn $record_type "$record_value"
# no check_is_protected_record() is performed
set_dns_record()
{
  local flush=1
  if [[ $1 == '--no-flush' ]] ; then
    flush=0
    shift
  fi

  local fqdn=$1
  local record_type="$2"
  local record_value="$3"
  local domain=$(get_domain $fqdn)
  local subdomain=${fqdn/.$domain/}

  local record=$(get_domain_record_id $fqdn "$record_type")

  local ret
  if [[ -z "$record" || "$record" == null ]]
  then
    # must be created
    myovh_cli POST /domain/zone/$domain/record  \
      "{
      \"target\" : \""$record_value\","
      \"ttl\" : \"$DNS_TTL\",
      \"subDomain\" : \"$subdomain\",
      \"fieldType\" : \"$record_type\"
      }"
    ret=$?
  else
    # update existing recors
    myovh_cli PUT /domain/zone/$domain/record/$record  \
      "{
      \"target\" : \"$record_value\",
      \"ttl\" : \"$DNS_TTL\"
      }"
    ret=$?
  fi

  if [[ $ret -eq 0 ]] ; then
    if [[ $flush -eq 1 ]]; then
      # flush domain modification
      dns_flush $domain
    else
      >&2 echo "no flush: $domain"
    fi
  else
    error "ret code '$ret' no dns flush"
  fi

  return $ret
}

# PROTECTED_RECORD_LIST is empty by default set it in cloud.conf
check_is_protected_record()
{
  local ret=1
  local protected=${PROTECTED_RECORD_LIST:-}
  if [[ -e $protected ]] ; then
    grep -q --line-regexp -F "$1" $protected
    ret=$?
  fi
  return $ret
}

# for cleanup, unused, call it manually
# delete_dns_record $fqdn [$fieldType]
delete_dns_record()
{
  local fqdn=${1%.}
  local domain=$(get_domain $fqdn)
  local fieldType=${2:-A}
  local record=$(get_domain_record_id $fqdn $fieldType)

  if [[ -z "$record" || "$record" == null ]]
  then
    error "record '$fqdn' '$fieldType' not found"
  else
    myovh_cli DELETE /domain/zone/$domain/record/$record
    dns_flush $domain
  fi
}


dns_flush()
{
  local domain=${1%.}
  if [[ -z $domain ]] ; then
    error "dns_flush: domain is empty"
    return 1
  fi
  myovh_cli POST /domain/zone/$domain/refresh | jq -r .
  myovh_cli GET /domain/zone/$domain/task | jq -r .
  myovh_cli GET /domain/zone/$domain/status | jq -r .
}

# Call: delete_instance PROJECT_ID INSTANCE_ID
delete_instance()
{
  local p=$1
  local i=$2

  local instance_mode=$(get_instance_status $p $i FULL | jq -r '.planCode')

  if [[ $instance_mode =~ consumption ]] ; then
    myovh_cli DELETE /cloud/project/$p/instance/$i
  else
    echo "instance_mode $instance_mode delete protected"
    return 1
  fi
}

snapshot_create()
{
  local p=$1
  local i=$2
  local snap_name="$3"

  myovh_cli POST "/cloud/project/$p/instance/$i/snapshot" \
    "{
    \"snapshotName\": \"$snap_name\"
    }"

  ret=$?
  return $ret
}

id_is_project()
{
  # return an array of project_id, -1 if not found
  local json=$(myovh_cli GET /cloud/project)
  if ovh_test_credential "$json" ; then
    # if credential are wrong this is not a valid JSON
    jq -r '.[]' <<< "$json" | grep -q "^$1\$" && return 0
  else
    # fail
    return 1
  fi
}

set_project()
{
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

# Call:
#   write_conf conffile VAR=value VAR2=value2 DELETE=VAR3 ...
write_conf()
{
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

# Call: loadconf $conffile
# load the cloud.conf defined by $conffile is the file exists
# apply our DEFAULT_* if some values are not defined.
# preserve exported OUR_VARS if they already exists.
loadconf()
{
  local conffile="$1"
  if [[ -e "$conffile" ]]
  then
    # TODO: save used env and dont overwrite exported vars
    local defined_vars_file=$(mktemp $TMP_DIR/defined_vars_file.XXXXX)
    preserve_our_vars "$OUR_VARS" > $defined_vars_file
    source "$conffile"
    # restore $OUR_VARS
    source $defined_vars_file
    rm $defined_vars_file
  fi

  # initialize DEFAULTS
  local var val
  for var in $OUR_VARS
  do
    # fetch value or empty if unset
    eval "val=\${$var:-}"
    if [[ -z $val ]] ; then
      # set with DEFAULTS
      eval "$var=\${DEFAULT_$var}"
    fi
  done
}

# Call: preserve_our_vars "$OUR_VARS" ...
# OUR_VARS is a list of var names to preserve if they are already in the env
preserve_our_vars()
{
  local pattern="$*"
  pattern="^(${pattern// /|})"
  env | grep -E "$pattern" || true
}

set_flavor()
{
  local p=$1
  local flavor_name=$2

  local flavor_id=$(get_flavor $p $flavor_name)
  if [[ -z "$flavor_id" ]]
  then
    echo "error: '$flavor_name' seems not to be a valid flavor or doesn't exist on region $REGION"
    echo "to list all flavor use:"
    echo "  $ME call get_flavor $p"
    return 1
  else
    write_conf "$CONFFILE" "FLAVOR_NAME=$flavor_name"
    return 0
  fi
}

call_func()
{
  # auto detect functions name loop
  local func="$1"
  shift

  # only func that format are callable.
  # use: function or open brace on the same line to make it non-callable
  local all_func=$(sed -n '/^[a-zA-Z_]\+(/ s/()$// p' $(readlink -f $0))
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

# grep for an image
# use awk to get the image_id
# Example:  find_image $PROJECT_ID | awk '/Debian 8$/ {print $1}'
find_image()
{
  local p=$1
  if [[ $# -ge 2 ]] ; then
    local pattern="$2"
    list_images $p linux text | grep "$pattern"
  else
    list_images $p linux text
  fi
}

# list available images (this is not the same as snapshot)
list_images()
{
  local p=$1
  local limit_osType=""
  local output_type=json

  if [[ $# -ge 2 ]] ; then
    # you can pass an empty value to force output_type for example
    if [[ -n $2 ]] ; then
      limit_osType="&osType=$2"
    fi
  fi

  if [[ $# -eq 3 ]] ; then
    output_type=$3
  fi

  local url="/cloud/project/$p/image?$limit_osType&region=$REGION"
  case $output_type in
    json)
      myovh_cli GET "$url"
      ;;
    *)
      # format ID name
      myovh_cli GET "$url" \
        | jq -r ".[]|.id+\" \"+.name"
      ;;
  esac
}

region_list()
{
   myovh_cli GET /cloud/project/$PROJECT_ID/region  | jq -r '.[]'
}

# Call: instance_set_rescuemode $project_id $instance_id [true|false]
instance_set_rescuemode()
{
  local p=$1
  local instance_id=$2
  # true or false
  local rescue=${3:-true}
  if [[ ! $rescue =~ ^(true|false)$ ]] ; then
    error "rescue value must be 'true' or 'false'"
    return 1
  fi
  myovh_cli POST /cloud/project/$p/instance/$instance_id/rescueMode "{ \"rescue\" : $rescue}"
}

# Call: instance_reboot $project_id $instance_id [soft|hard]
instance_reboot()
{
  local p=$1
  local instance_id=$2
  # hard or soft
  local reboot_type=${3:-soft}
  if [[ ! $reboot_type =~ ^(soft|hard)$ ]] ; then
    error "reboot_type value must be 'hard' or 'soft'"
    return 1
  fi
  myovh_cli POST /cloud/project/$p/instance/$instance_id/reboot "{ \"type\" : \"$reboot_type\" }"
}

# Call: sshkey_create $project_id $sshkey_name $public_key_fname
sshkey_create()
{
  local p=$1
  local sshkey_name=$2
  local public_key_fname=$3

  if [[ ! -f $public_key_fname ]] ; then
      fail "public_key_fname file not found: '$public_key_fname'"
  fi

  local pubkey="$(cat $public_key_fname)"

  myovh_cli POST /cloud/project/$p/sshkey \
      "{
      \"name\" : \"$sshkey_name\",
      \"publicKey\" : \"$pubkey\"
      }"

  ## bug output: Invalid region parameter on OVH API side
  #if [[ $out == 'Invalid region parameter' ]] ; then
  #  local check=$(myovh_cli GET /cloud/project/$p/sshkey  | \
  #    jq -r ".[]|select(.name == \"$sshkey_name\")|.publicKey")

  #  if [[ "$pubkey" == "$check" ]] ; then
  #    echo OK
  #  else
  #    fail "key creation failure"
  #  fi
  #fi
}

wait_for()
{
  local p=$1
  local wait_for=$2
  local object_id=$3
  local max=$4

  if [[ -z "$max" ]] ; then
    error "no max"
    return 1
  fi

  local startt=$SECONDS
  local tmp=$TMP_DIR/wait_${object_id}.$$
  local wait_for_ssh=false
  local cmd=""

  case $wait_for in
    instance)
      # greped against JSON output because we are going to
      # extract many informations IPv4, sshuser
      cmd="get_instance_status $p $object_id FULL \
          | tee $tmp \
          | jq . \
          | grep -q '\"status\": \"ACTIVE\"'"
      #'" correct vim hilighting
      cmd_success="show_json_instance < $tmp"
      wait_for_ssh=true
      ;;
    snapshot)
      cmd="get_snapshot_status $p $object_id FULL \
          | tee $tmp \
          | jq . \
          | grep -q -i '\"status\": \"active\"'"
      #'" correct vim hilighting
      cmd_success="jq . < $tmp"
      wait_for_ssh=false
      ;;
    *)
      echo "don't know how to get status for '$wait_for'"
      return 1
      ;;
  esac

  debug "wait_for: cmd '$cmd' cmd_success '$cmd_success'"

  local timeout_reached=0
  while true
  do
    if [[ $(( SECONDS - startt )) -gt $max ]] ; then
      echo "timeout reached: $max"
      timeout_reached=1
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

  if [[ $(wc -l < $tmp) -eq 0 || $timeout_reached -eq 1 ]] ; then
    rm -f $tmp
    return 1
  fi

  if $wait_for_ssh ; then
    local ssh_timeout_reached=0
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
        ssh_timeout_reached=1
        break
      fi

      if timeout 3s ssh -q -o StrictHostKeyChecking=no $sshuser@$ip \
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

wait_for_instance()
{
  local p=$1
  local instance_id=$2
  local max=$3

  wait_for "$p" instance "$instance_id" "$max"
  return $?
}

wait_for_snapshot()
{
  local p=$1
  local snapshot_id=$2
  local max=$3

  wait_for "$p" snapshot "$snapshot_id" "$max"
  return $?
}

############################### helper non callable function (prefixed by function keyword)

function fail()
{
  error "${BASH_SOURCE[1]}:${FUNCNAME[1]}:${BASH_LINENO[0]}: $*"
  exit 1
}

function error()
{
  # write on stderr
  >&2 echo "error: $*"
}

# non maskable output (bats stderr kept on $output)
function debug()
{
  if [[ $DEBUG -eq 1 ]] ; then
    # write on non standar non stdout non stderr descriptor
    echo "[tty]debug: $*" > /dev/tty
  fi
}

# stop_script is the main function which kill INT (Ctrl-C) your script
# it doesn't exit because you can source it too.
# you don't have to call this function unless you extend some fail_if function
function stop_script()
{
  # test whether we are in interactive shell or not
  if [[ $- == *i* ]]
  then
    # autokill INT myself = STOP
    kill -INT $$
  else
    exit $1
  fi
}

function fail_if_dir_not_exists()
{
  local d=$1
  if [[ ! -d "$d" ]] ; then
    error "folder not found: '$d' at ${BASH_SOURCE[1]}:${FUNCNAME[1]} line ${BASH_LINENO[0]}"
    stop_script 3
  fi
}

function fail_if_file_not_exists()
{
  local f=$1
  if [[ ! -f "$f" ]] ; then
    error "file not found: '$f' at ${BASH_SOURCE[1]}:${FUNCNAME[1]} line ${BASH_LINENO[0]}"
    stop_script 3
  fi
}

function fail_if_empty()
{
  local varname
  local v
  # allow multiple check on the same line
  for varname in $*
  do
    eval "v=\$$varname"
    if [[ -z "$v" ]] ; then
      error "$varname empty or unset at ${BASH_SOURCE[1]}:${FUNCNAME[1]} line ${BASH_LINENO[0]}"
      stop_script 4
    fi
  done
}

###################################### main

# prefix with 'function' keyword to not to be greped with --help. See extract_usage
function main()
{
  action=$1
  proj=$2

  if [[ -z "$action" || -z "$proj" ]]
  then
      echo "no project set, or no action"
      show_projects
      return 1
  fi

  case $action in
    show_projects)
      show_projects
      ;;
    snap_list|get_snap|snapshot_list)
      ordering=$3
      snapshot_list $proj $ordering
    ;;
    create|create_instance)
      #image_id can also be a snapshot_id
      image_id=$3
      sshkey_id=$4
      hostname=$5
      init_script=$6

      echo "image_id $image_id"
      echo "hostname $hostname"
      echo "sshkey_id $sshkey_id"
      echo "init_script $init_script"

      tmp=$TMP_DIR/create_$hostname.$$
      echo "create_instance '$proj' '$image_id' '$sshkey_id' '$hostname' '$init_script'"
      create_instance $proj $image_id $sshkey_id $hostname $init_script | tee $tmp
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
    list_ssh|get_ssh|ssh_list)
      userkey=$3
      get_sshkeys $proj $userkey
    ;;
    instance_list|list)
      instance_list $proj
    ;;
    rename)
      instance=$3
      new_name="$4"
      rename_instance $proj $instance "$new_name"
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
    snap_wait)
      snap_id=$3
      if wait_for_snapshot $proj $snap_id $MAX_WAIT ; then
        echo "OK"
      else
        fail "timeout $MAX_WAIT or error, snapshot not found"
      fi
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
      if [[ $# -gt 2 ]] ; then
        # fix main call with automatic pass the current $PROJECT_ID
        proj=$3
      fi

      if set_project $proj
      then
        echo "project '$proj' written in '$CONFFILE'"
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
      local found=0
      local f
      for f in $src "saved/$src"
      do
        if [[ -e "$src" ]] ; then
          # argument from $4 ...
          source $src "$@"
          found=1
          break
        fi
      done
      if [[ $found -eq 0 ]] ; then
        echo "saved script not found: '$src'"
        exit 1
      fi
      ;;
    list_images|image_list)
      shift 2
      list_images $proj linux text
      ;;
    *)
      echo "error: $action not found"
      echo "free call (PROJECT_ID added): call $@"
      exit 1
      ;;
  esac
}

# parse JSON input or fail with input if not JSON
function jq_or_fail()
{
  # catch stdin
  local input
  IFS='' read -d '' -r input
  fail_if_empty input
  # don't run command on local statement exit code will be always 0
  local o r
  o=$(jq "$@" <<< "$input" 2> /dev/null)
  r=$?
  # exit code 4 == parse error: Invalid numeric literal at line 1, column 4
  if [[ $r -eq 4 ]] ; then
    error "jq parse error: '$input'"
  else
    if [[ -n $o ]] ; then
      echo "$o"
    else
      local tmp=$(mktemp)
      error "jq exit: $r, but no output, saved in '$tmp'"
      echo "echo '$input' | jq $@" > $tmp
      r=1
    fi
  fi
  return $r
}

################################################################## exec code
if [[ $sourced -eq 0 ]]
then
  # help is handled at the top See: hook_display_help

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
