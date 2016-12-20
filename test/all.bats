#!/bin/bash
#
# Unittest
# vimF12: bats all.bats

cloud_sh=../cloud.sh
source common.sh

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
  r=$(find_image $PROJECT_ID "Debian 8")
  [[ ! -z "$r" ]]
  [[ "$r" == "d0e79eb7-5dbe-4ff2-84f9-d5ce26ef074e Debian 8" ]]
}
