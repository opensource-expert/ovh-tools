#!/usr/bin/env bash
#
# configuration for the tests

# must exactly match ssh key in the project
# after setting the project you cat list sshkeys with:
# run: ./cloud.sh list_ssh
SSHKEY_NAME=sylvain2016

# some domain name managed on OVH
# this domain name will be used to name instance
DOMAIN_NAME=opensource-expert.com

# the kind of VM we could create during test
TEST_FLAVOR_NAME=s1-2