# ovh api wrapper
# internal call with eval \$project_id (sourced from cloud.conf)
# $project_id is escaped because evaled bu $instance_id is pasted on shell via tmux

# get a OS image id, from cli directly
./cloud.sh call ovh_cli --format json cloud project \$project_id image --osType linux --region GRA1 |jq '.[]|select(.name|test("Deb"))'
./cloud.sh call ovh_cli --format json cloud project \$project_id instance create -h

# project manipulation
./cloud.sh call find_image \$project_id Deb
./cloud.sh call show_projects
./cloud.sh call last_snapshot \$project_id
./cloud.sh call get_flavor \$project_id
# just the id of vps-ssd-1
./cloud.sh call get_flavor \$project_id vps-ssd-1
# custom instance
./cloud.sh call create_instance \$project_id $snapshot_id $script_sshkey $hostname $init
# works with image too, here debian 8 (from find_image)
sshkey=$(./cloud.sh call get_sshkeys \$project_id sylvain)
./cloud.sh call create_instance \$project_id 05045d18-6035-4dc1-9d89-259272280392 $sshkey new_name2
./cloud.sh call create_instance \$project_id 05045d18-6035-4dc1-9d89-259272280392 $sshkey gdb.opensource-expert.com init_script_dhcp.sh
# manipulate instances
./cloud.sh call list_instance \$project_id
instance_id=some_id
./cloud.sh call rename_instance $instance_id NEW_NAME
./cloud.sh call get_instance_status \$project_id
# or
./cloud.sh call get_instance_status \$project_id $instance_id

# ssh keys
./cloud.sh call list_sshkeys \$project_id
./cloud.sh call get_sshkeys \$project_id
./cloud.sh call get_sshkeys \$project_id sylvain

# dns func
./cloud.sh call get_domain_record_id vim.opensource-expert.com
./cloud.sh call set_ip_domain 12.34.56.78 vim.opensource-expert.com
./cloud.sh call set_forward_dns 12.34.56.78 vim.opensource-expert.com
./cloud.sh call delete_dns_record vim.opensource-expert.com

# instance
instance_id=some_id_in_list_instance
./cloud.sh call delete_instance $instance_id
./cloud.sh call create_snapshot \$project_id $instance_id $snapshot_id

# internal config
./cloud.sh call id_is_project A_PROJECT_ID
./cloud.sh call set_project A_PROJECT_ID
./cloud.sh call write_conf FILENAME "var=val" "var2=val" "DELETE=somevar"
./cloud.sh call loadconf FILENAME

# main commands
###############
./cloud.sh get_snap
snapshot_id=some_id_from_get_snap
./cloud.sh create $snapshot_id grep2.opensource-expert.com
# works with image too, here debian 8 (from find_image)
./cloud.sh create 05045d18-6035-4dc1-9d89-259272280392 ssh.opensource-expert.com
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
project_id=someproject_id_from_show_projects_or_no_arg
./cloud.sh set_project $project_id
