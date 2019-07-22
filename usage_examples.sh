#!/bin/bash
#
# some examples of usage
#
# ovh api wrapper
#
# internal call with eval \$PROJECT_ID (sourced from cloud.conf)
#
# $PROJECT_ID is escaped because evaled but $instance_id is pasted on
# shell
#
# all line can be sent via tmux, or pasted on a working environment.

# get a OS image id, from cli directly
./cloud.sh call ovh_cli --format json cloud project \$PROJECT_ID image --osType linux --region WAW1 |jq '.[]|select(.name|test("Deb"))'
# get API help
./cloud.sh call ovh_cli --format json cloud project \$PROJECT_ID instance create -h

# get public network id
./cloud.sh call ovh_cli --format json cloud project \$PROJECT_ID network public | jq -r '.[]|.id'

# show instance status
./cloud.sh call ovh_cli cloud project \$PROJECT_ID instance
./cloud.sh call ovh_cli --format json cloud project \$PROJECT_ID instance $instance_id

# snapshot info
./cloud.sh call ovh_cli --format json cloud project \$PROJECT_ID snapshot | jq -r '.[]|.id+" "+.name+" "+.status'
./cloud.sh call ovh_cli --format json cloud project \$PROJECT_ID snapshot $snapshot_id

# set DNS record for an instance based on its hostname (instance name)
pattern=phoenix.opensource-expert.com
instance=$(./cloud.sh status | awk "/$pattern/ { print \$1}")
read ip hostname <<< $(./cloud.sh call instance_list \$PROJECT_ID $instance | awk '{ print $2,$3 }')
echo ip=$ip hostname=$hostname
./cloud.sh call set_ip_domain $ip $hostname

# list instance
./cloud.sh call ovh_cli --format json cloud project \$PROJECT_ID instance
# Test if credential is not valid
./cloud.sh call ovh_cli --format json auth current-credential
./cloud.sh call ovh_test_login && echo OK

# list instance with IP address v4 + v6
./cloud.sh call ovh_cli --format json cloud project \$PROJECT_ID instance | jq -r '.[]|.id+" "+(.ipAddresses[]|select(.type=="public")).ip+" "+.name'

# with jq
mytmp=/dev/shm/cloud_status.tmp
./cloud.sh call get_instance_status \$PROJECT_ID $instance FULL > $mytmp
ip=$(jq -r '(.ipAddresses[]|select(.type=="public" and .version == 4 )).ip' < $mytmp)
hostname=$(jq -r '.name' < $mytmp)
echo "ip=$ip hostname=$hostname"
./cloud.sh call set_ip_domain $ip $hostname

# project manipulation
./cloud.sh call find_image \$PROJECT_ID Deb
./cloud.sh call show_projects
./cloud.sh call last_snapshot \$PROJECT_ID
./cloud.sh call get_flavor \$PROJECT_ID
# just the id of small sandbox on the current REGION
./cloud.sh call get_flavor \$PROJECT_ID s1-2

# create a custom instance
snapshot_id=$(./cloud.sh call snapshot_list \$PROJECT_ID yes text | awk '/Debian10/ { print $1}')
sshkey_id=$(./cloud.sh call get_sshkeys \$PROJECT_ID sylvain2016)
hostname=deleteme.opensource-expert.com
init_script=init/init_root_login_OK.sh
echo "snapshot_id $snapshot_id sshkey_id $sshkey_id init_script $init_script"
./cloud.sh call create_instance \$PROJECT_ID $snapshot_id $sshkey_id $hostname "$init_script"

# works with image too, here debian 8 (from find_image)
sshkey=$(./cloud.sh call get_sshkeys \$PROJECT_ID sylvain2016)
# Debian9
images=a794936f-29d7-4d7b-a1a1-f48df6f8a462
./cloud.sh call create_instance \$PROJECT_ID $image_id $sshkey new_name2
./cloud.sh call create_instance \$PROJECT_ID $image_id $sshkey gdb.opensource-expert.com init/init_script_dhcp.sh
./cloud.sh call create_instance \$PROJECT_ID $image_id $sshkey ls.opensource-expert.com init/init_root_login_OK.sh
# manipulate instances
./cloud.sh call instance_list \$PROJECT_ID
# get first instance
instance_id=$(./cloud.sh instance_list \$PROJECT_ID | awk 'NR == 1 {print $1}')
# other syntaxe
instance_id=$(./cloud.sh status | awk 'NR == 1 {print $1}')
# named instance
instance_id=$(./cloud.sh status | awk '/gdb.opensource-expert.com/ {print $1}')
echo $instance_id
# rename
./cloud.sh call rename_instance $instance_id NEW_NAME
./cloud.sh call get_instance_status \$PROJECT_ID
# or
./cloud.sh call get_instance_status \$PROJECT_ID $instance_id
# in json
./cloud.sh call get_instance_status \$PROJECT_ID $instance_id FULL

# test ACTIVE grep JSON, watch the case
./cloud.sh call get_instance_status \$PROJECT_ID $instance_id FULL | grep '"status": "ACTIVE"'

# ssh keys
# JSON
./cloud.sh call list_sshkeys \$PROJECT_ID
# text parsable via awk
./cloud.sh call get_sshkeys \$PROJECT_ID
# exact match keyname (per project)
./cloud.sh call get_sshkeys \$PROJECT_ID sylvain2016

# dns func
./cloud.sh call get_domain_record_id vim.opensource-expert.com
./cloud.sh call set_ip_domain 12.34.56.78 vim.opensource-expert.com
./cloud.sh call set_forward_dns 12.34.56.78 vim.opensource-expert.com
./cloud.sh call delete_dns_record vim.opensource-expert.com

# instance
instance_id=some_id_in_list_instance
./cloud.sh call delete_instance $instance_id
snapshot_name=mysnapshot
./cloud.sh call snapshot_create \$PROJECT_ID $instance_id $snapshot_name


# STOP test: lundi 22 juillet 2019, 08:46:38 (UTC+0200)
# internal config
./cloud.sh call id_is_project A_PROJECT_ID
./cloud.sh call set_project A_PROJECT_ID
./cloud.sh call write_conf FILENAME "var=val" "var2=val" "DELETE=somevar"
./cloud.sh call loadconf FILENAME
./cloud.sh call set_flavor \$PROJECT_ID eg-7-flex
cat cloud.conf

# main commands
###############
./cloud.sh get_snap
snapshot_id=$(./cloud.sh get_snap | awk '/debian-updated-base/ {print $1; exit}')
./cloud.sh create $snapshot_id grep2.opensource-expert.com

# works with image too, here debian 8 (from find_image)
./cloud.sh call find_image \$PROJECT_ID | awk '/Debian 8$/ {print $1}'
image_id=$(./cloud.sh call find_image \$PROJECT_ID | awk '/Debian 8$/ {print $1}')

./cloud.sh create 05045d18-6035-4dc1-9d89-259272280392 ssh.opensource-expert.com
./cloud.sh create $image_id awk.opensource-expert.com init/init_root_login_OK.sh
./cloud.sh wait $instance_id
./cloud.sh get_ssh
./cloud.sh list_instance
instance_id=some_id_in_list_instance
./cloud.sh rename $instance_id new_name
./cloud.sh status
# or
./cloud.sh status $instance_id
./cloud.sh make_snap $instance_id snap_name
./cloud.sh delete $instance_id
# or
./cloud.sh delete ALL
./cloud.sh set_all_instance_dns
# write config file
PROJECT_ID=someproject_id_from_show_projects_or_no_arg
./cloud.sh set_project $PROJECT_ID
./cloud.sh set_flavor vps-ssd-1

# consumer_key
./mk_cred.py init
./mk_cred.py update

# wait
instance=$(./cloud.sh status | awk '/rm.open/ { print $1}')
echo $instance
./cloud.sh delete $instance
./cloud.sh run saved/test_wait.sh
./cloud.sh wait $instance
./cloud.sh wait wrong
./cloud.sh status $instance
