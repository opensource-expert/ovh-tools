#!/bin/bash
#
# Unittest
# vimF12: bats all.bats

# this instance_id will be deleted
INSTANCE_TO_DELETE=$BATS_TEST_DIRNAME/delete_instance

# our code source
CLOUD_SH=$BATS_TEST_DIRNAME/../cloud.sh

load common
load test_config

ipV4_regexp="[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"
hex_dash_regexp="[0-9a-f-]+"
hex_regexp="[0-9a-f]+"

# TODO: _load_if_OK test should be moved to there own .bats file
# some early test are loading source $CLOUD_SH explicitly, other test must load _load_if_OK
_load_if_OK() {
  source cred_OK.sh
  source $CLOUD_SH
  # CONFFILE is defined by cloud.sh
  loadconf $CONFFILE
}

_register_delete()
{
  local instance_id=$1
  echo $instance_id >> $INSTANCE_TO_DELETE
}

_check_before_run() {
  if [[ -z $INSTANCE_TO_DELETE ]] ; then
      echo "INSTANCE_TO_DELETE empty" > $BATS_TEST_DIRNAME/init_failure
  fi

  if [[ -f $INSTANCE_TO_DELETE && $(wc -l < $INSTANCE_TO_DELETE) -gt 0 ]] ; then
      msg="
####################### Inititalisation FAILURE #######################
some instance_id id left in '$INSTANCE_TO_DELETE'
cleanup before testing, please.
../cloud.sh delete $(tr -d $'\n' < $INSTANCE_TO_DELETE)
rm $INSTANCE_TO_DELETE
"
      echo "$msg" > $BATS_TEST_DIRNAME/init_failure
  fi
}

_check_failure()
{
  if [[ -f $BATS_TEST_DIRNAME/init_failure ]] ; then
    echo "init_failure, exiting" >&2
    cat $BATS_TEST_DIRNAME/init_failure >&2
    echo "then remove $BATS_TEST_DIRNAME/init_failure" >&2
    exit 1
  fi
}

create_some_instance()
{
  local image_id=$(find_image $PROJECT_ID "$DISTRIB_IMAGE" | awk '{print $1; exit}')
  local sshkey=$(get_sshkeys $PROJECT_ID $SSHKEY_NAME)
  local hostname="dummy$$.$DOMAIN_NAME"
  local init_script=""
  export FLAVOR_NAME=$TEST_FLAVOR_NAME
  create_instance $PROJECT_ID $image_id $sshkey $hostname $init_script
}

setup() {
  # special check before_all : https://github.com/bats-core/bats-core/issues/39
	# echo "BATS_TEST_NUMBER $BATS_TEST_NUMBER $BATS_TEST_NAME $BATS_TEST_DESCRIPTION" >> log
  if [[ "$BATS_TEST_NUMBER" -eq 1 && $BATS_TEST_DESCRIPTION == '_check_failure once' ]]; then
		echo _check_before_run >> log
    _check_before_run
  fi
	_check_failure
}

#teardown() {
#  if [[ "${#BATS_TEST_NAMES[@]}" -eq "$BATS_TEST_NUMBER" ]]; then
#		:
#  fi
#}

@test "_check_failure once" {
  # empty test for testing _check_before_run
  return 0
}

@test "CONFFILE as defaut value" {
  source $CLOUD_SH
  [[ -n "$CONFFILE" ]]
}

@test "FLAVOR_NAME" {
  source $CLOUD_SH
  # before loadconf no FLAVOR_NAME
  [[ -z "$PROJECT_ID" ]]
  [[ -z "$FLAVOR_NAME" ]]
  loadconf $CONFFILE
  [[ -n "$FLAVOR_NAME" ]]
  [[ -n "$PROJECT_ID" ]]
}

@test "same dir after ovh_cli" {
  oldPWD=$PWD
  source $CLOUD_SH
  run ovh_cli -h
  [[ "$oldPWD" == "$PWD" ]]
}

@test "show_projects" {
  rm -f cred_OK.sh
  source $CLOUD_SH
  loadconf $CONFFILE
  [[ -n "$PROJECT_ID" ]]
  # can't pipe with bats run, this will fail if invalid credential
  res=$(ovh_cli --format json cloud project | jq -r .[])
  rr=$?
  [[ -n "$res" ]]
  [[ "$rr" -eq 0 ]]
  echo OK_TEST=1 > cred_OK.sh
}

@test "test credential valids" {
  _load_if_OK
  [[ -n "$FLAVOR_NAME" ]]
}

@test "find_image with grep" {
  _load_if_OK
  run find_image $PROJECT_ID "$DISTRIB_IMAGE"
  echo "'$output'"
  echo "$output" | grep -E "^$hex_dash_regexp $DISTRIB_IMAGE"
}

@test "get_sshkeys" {
  _load_if_OK
  run get_sshkeys $PROJECT_ID $SSHKEY_NAME
  echo "'$output'"
  echo "$output" | grep -E "^$hex_regexp$"
}

_assert_json_valid() {
  [[ -n "$1" ]]
  echo "$1" > tmp_validate.json
  jq . <<< "$1"
}

@test "json_append_key" {
  _load_if_OK
  val="single quote ''"
  run json_append_key pipo "$val" < t.json
  _assert_json_valid "$output"

  val='escaped double quote \"'
  run json_append_key pipo "$val" < t.json
  _assert_json_valid "$output"

  val='slash /'
  run json_append_key pipo "$val" < t.json
  _assert_json_valid "$output"

  val='newline  \nici\nla'
  run json_append_key pipo "$val" < t.json
  _assert_json_valid "$output"
  fetch=$(jq .pipo <<< "$output")
  # non raw value are quoted JSON
  [[ $fetch == "\"$val\"" ]]

  # with a script
  run preprocess_init --json script.sh
  [[ -n $output ]]
  # file exists and size > 0
  [[ -s $output ]]
  escaped_file=$output
  echo "{ \"k\": \"$(cat $escaped_file)\" }" > o_escaped_file.json
  _assert_json_valid "$(cat o_escaped_file.json)"
  run json_append_key script "$(cat $escaped_file)" < t.json
  _assert_json_valid "$output"
}

@test "create_instance (take ~ 50 seconds)" {
  _load_if_OK
  image_id=$(find_image $PROJECT_ID "$DISTRIB_IMAGE" | awk '{print $1; exit}')
  [[ -n "$image_id" ]]
  # only one image id
  [[ $(wc -l <<< "$image_id") -eq 1 ]]
  sshkey=$(get_sshkeys $PROJECT_ID $SSHKEY_NAME)
  [[ -n "$sshkey" ]]
  hostname="dummy$$.$DOMAIN_NAME"
  init_script=""

  export FLAVOR_NAME=$TEST_FLAVOR_NAME
  echo create_instance $PROJECT_ID $image_id $sshkey $hostname $init_script
  run create_instance $PROJECT_ID $image_id $sshkey $hostname $init_script
  [[ -n "$output" ]]
  _assert_json_valid "$output"

  tmp=$BATS_TEST_DIRNAME/instance.json
  echo "$output" > $tmp
  run jq -r '.id' < $tmp
  [[ -n "$output" ]]

  # TODO: destroy instance at the end
  _register_delete $output
}

@test "wait_for_instance" {
  _load_if_OK
  instance_id=$(tail -1 $INSTANCE_TO_DELETE)
  echo "$instance_id" | grep -E "^$hex_dash_regexp$"
  run wait_for_instance $PROJECT_ID $instance_id 120
  [[ $status -eq 0 ]]
}

@test "get_instance_status" {
  _load_if_OK
  #run create_instance $PROJECT_ID

  # all instance text format
  run get_instance_status $PROJECT_ID
	echo "output $output"
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

@test "delete registed instance created during tests" {
  _load_if_OK
  [[ -f $INSTANCE_TO_DELETE ]]
  [[ $(wc -l < $INSTANCE_TO_DELETE) -gt 0 ]]
  for i in $(cat $INSTANCE_TO_DELETE)
  do
    run delete_instance $PROJECT_ID $i
		echo "deleting $i output '$output'"
		[[ $output == "Success" ]]
		sed -i -e "/$i/ d" $INSTANCE_TO_DELETE
  done
  [[ $(wc -l < $INSTANCE_TO_DELETE) -eq 0 ]]
}

@test "create_instance fail if flavor is not found" {
  _load_if_OK
  TEST_FLAVOR_NAME=pipo
  run create_some_instance
  echo "create_some_instance $output"
  [[ $status -ne 0 ]]
}

@test "set_project (slow ~ 16s)" {
  _load_if_OK
  # invalid
  run set_project 123455
  [[ $status -ne 0 ]]

  some_project=$(show_projects | awk '{print $1; exit}')
  ret=$?
  [[ $ret -eq 0 ]]
  echo "project_id: $some_project"
  [[ $some_project =~ $hex_regexp ]]
  # check we are using a local test of cloud.conf
  [[ -n $CONFFILE ]]
  [[ -n $SCRIPTDIR ]]
  [[ $CONFFILE != $SCRIPTDIR/cloud.conf ]]
  run set_project $some_project
}
