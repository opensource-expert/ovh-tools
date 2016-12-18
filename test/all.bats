#!/bin/bash
#
# Unittest
# vimF12: bats all.bats

cloud_sh=../cloud.sh

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
  oldPWD=$PWP
  source $cloud_sh
  run ovh_cli -h
  [[ "$oldPWD" == "$PWD" ]]
}
