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
./cloud.sh call ovh_cli --format json cloud project \$PROJECT_ID image --osType linux --region GRA1 |jq '.[]|select(.name|test("Deb"))'
./cloud.sh call ovh_cli --format json cloud project \$PROJECT_ID instance create -h

# get public network id
./cloud.sh call ovh_cli --format json cloud project \$PROJECT_ID network public | jq -r '.[]|.id'

./cloud.sh call ovh_cli --format json cloud project \$PROJECT_ID instance unknown

#snapshot info
./cloud.sh call ovh_cli --format json cloud project \$PROJECT_ID snapshot 1a16c40a-c61a-4412-8b3e-83127c9f3132
./cloud.sh call ovh_cli --format json cloud project \$PROJECT_ID snapshot | jq -r '.[]|.id+" "+.name+" "+.status'

# domain ip info read awk
instance=$(./cloud.sh status | awk '/pattern_match_your_instance/ { print $1}')
read ip hostname <<< $(./cloud.sh call list_instance \$PROJECT_ID $instance | awk '{ print $2,$3 }')
echo ip=$ip hostname=$hostname
./cloud.sh call set_ip_domain $ip $hostname

# list instance
./cloud.sh call ovh_cli --format json cloud project \$PROJECT_ID instance
# This credential is not valid
./cloud.sh call ovh_cli --format json auth current-credential

./cloud.sh call ovh_cli --format json cloud project \$PROJECT_ID instance \
    | jq -r '.[]|.id+" "+(.ipAddresses[]|select(.type=="public")).ip+" "+.name'

# with jq
mytmp=/dev/shm/cloud_status.tmp
./cloud.sh call get_instance_status \$PROJECT_ID $instance FULL > $mytmp
ip=$(jq -r '(.ipAddresses[]|select(.type=="public")).ip' < $mytmp)
hostname=$(jq -r '.name' < $mytmp)
./cloud.sh call set_ip_domain $ip $hostname

# project manipulation
./cloud.sh call find_image \$PROJECT_ID Deb
./cloud.sh call show_projects
./cloud.sh call last_snapshot \$PROJECT_ID
./cloud.sh call get_flavor \$PROJECT_ID
# just the id of vps-ssd-1
./cloud.sh call get_flavor \$PROJECT_ID vps-ssd-1
# custom instance
./cloud.sh call create_instance \$PROJECT_ID $snapshot_id $script_sshkey $hostname $init
# works with image too, here debian 8 (from find_image)
sshkey=$(./cloud.sh call get_sshkeys \$PROJECT_ID sylvain)
./cloud.sh call create_instance \$PROJECT_ID 05045d18-6035-4dc1-9d89-259272280392 $sshkey new_name2
./cloud.sh call create_instance \$PROJECT_ID 05045d18-6035-4dc1-9d89-259272280392 $sshkey gdb.opensource-expert.com init/init_script_dhcp.sh
./cloud.sh call create_instance \$PROJECT_ID 05045d18-6035-4dc1-9d89-259272280392 $sshkey ls.opensource-expert.com init/init_root_login_OK.sh
# manipulate instances
./cloud.sh call list_instance \$PROJECT_ID
instance_id=some_id
# get first instance
instance_id=$(./cloud.sh status | awk 'NR == 1 {print $1}')
# named instance
instance_id=$(./cloud.sh status | awk '/rm.opensource-expert.com/ {print $1}')
echo $instance_id
./cloud.sh call rename_instance $instance_id NEW_NAME
./cloud.sh call get_instance_status \$PROJECT_ID
# or
./cloud.sh call get_instance_status \$PROJECT_ID $instance_id
# in json
./cloud.sh call get_instance_status \$PROJECT_ID $instance_id FULL

# test ACTIVE grep JSON
./cloud.sh call get_instance_status \$PROJECT_ID $instance_id FULL | grep '"status": "ACTIVE"'

# ssh keys
./cloud.sh call list_sshkeys \$PROJECT_ID
./cloud.sh call get_sshkeys \$PROJECT_ID
./cloud.sh call get_sshkeys \$PROJECT_ID sylvain

# dns func
./cloud.sh call get_domain_record_id vim.opensource-expert.com
./cloud.sh call set_ip_domain 12.34.56.78 vim.opensource-expert.com
./cloud.sh call set_forward_dns 12.34.56.78 vim.opensource-expert.com
./cloud.sh call delete_dns_record vim.opensource-expert.com

# instance
instance_id=some_id_in_list_instance
./cloud.sh call delete_instance $instance_id
./cloud.sh call snapshot_create \$PROJECT_ID $instance_id $snapshot_id

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
