#!/bin/bash
#
# Unittest
# vimF12: bats all.bats

cloud_sh=$BATS_TEST_DIRNAME/../cloud.sh
source $BATS_TEST_DIRNAME/common.sh

ipV4_regexp="[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"
hex_dash_regexp="[0-9a-f-]+"
hex_regexp="[0-9a-f]+"

# _load_if_OK test should be moved to there own .bats file
_load_if_OK() {
  source cred_OK.sh
  source $cloud_sh
  loadconf $CONFFILE
}

@test "CONFFILE as defaut value" {
  source $cloud_sh
  [[ ! -z "$CONFFILE" ]]
}

@test "FLAVOR_NAME" {
  source $cloud_sh
  # before loadconf no FLAVOR_NAME
  [[ -z "$FLAVOR_NAME" ]]
  loadconf $CONFFILE
  [[ ! -z "$FLAVOR_NAME" ]]
}

@test "same dir after ovh_cli" {
  oldPWD=$PWD
  source $cloud_sh
  run ovh_cli -h
  [[ "$oldPWD" == "$PWD" ]]
}

@test "show_projects" {
  rm -f cred_OK.sh
  source $cloud_sh
  loadconf $CONFFILE
  [[ ! -z "$PROJECT_ID" ]]
  # can't pipe with bats run, this will fail if invalid credential
  res=$(ovh_cli --format json cloud project | jq -r .[])
  rr=$?
  [[ ! -z "$res" ]]
  [[ "$rr" -eq 0 ]]
  echo OK_TEST=1 > cred_OK.sh
}

@test "test credential valids" {
  _load_if_OK
  [[ ! -z "$FLAVOR_NAME" ]]
}

@test "find_image with grep" {
  _load_if_OK
  run find_image $PROJECT_ID "Debian 8"
  echo "'$output'"
  echo "$output" | grep -E "^$hex_dash_regexp Debian 8"
}

@test "get_sshkeys" {
  _load_if_OK
  run get_sshkeys $PROJECT_ID sylvain
  echo "'$output'"
  echo "$output" | grep -E "^$hex_regexp$"
}

@test "create_instance" {
  _load_if_OK
  image_id=$(find_image $PROJECT_ID "Debian 8" | awk '{print $1}')
  [[ -n "$image_id" ]]
  sshkey=$(get_sshkeys $PROJECT_ID sylvain)
  [[ -n "$sshkey" ]]
  hostname="dummy$$.opensource-expert.com"
  init_script=""

  run create_instance $PROJECT_ID $image_id $sshkey $hostname $init_script
  echo create_instance $PROJECT_ID $image_id $sshkey $hostname $init_script
  [[ -n "$output" ]]

  tmp=$BATS_TEST_DIRNAME/instance.json
  echo "$output" > $tmp
  run jq -r '.id' < $tmp
  [[ -n "$output" ]]
  
  # TODO: destroy instance at the end
}

@test "get_instance_status" {
  _load_if_OK
  #run create_instance $PROJECT_ID 
  
  # all instance text format
  run get_instance_status $PROJECT_ID
  [[ -n "$output" ]]
  instanceId=$(echo "$output" | head -1 | awk '{print $1}')
  echo "instanceId='$instanceId'"
  echo "$instanceId" | grep -E "^$hex_dash_regexp$"
  
  # single instance text format
  run get_instance_status $PROJECT_ID $instanceId

  echo "output='$output'"
  echo "$output" | grep -E "^$hex_dash_regexp $ipV4_regexp [^ ]+"
  [[ ${#lines[@]} -eq 1 ]]

  # single instance JSON format
  run get_instance_status $PROJECT_ID $instanceId FULL
  id=$(echo "$output" | jq -r '.id')
  [[ $instanceId == $id ]]

  # all instance JSON format
  run get_instance_status $PROJECT_ID "" FULL
  ids=$(echo "$output" | jq -r '.[]|.id')
  echo "$ids" | grep -E "^$hex_dash_regexp$"
}
