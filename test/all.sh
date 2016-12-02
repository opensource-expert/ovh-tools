./cloud.sh call show_projects
./cloud.sh call last_snapshot \$project_id
./cloud.sh call get_flavor \$project_id
./cloud.sh call create_instance \$project_id SNAPSHOT_ID
./cloud.sh call list_instance \$project_id
./cloud.sh call rename_instance INSTANCE_ID NEW_NAME
./cloud.sh call get_instance_status \$project_id 
# or
./cloud.sh call get_instance_status \$project_id $instance_id
./cloud.sh call list_sshkeys \$project_id
./cloud.sh call get_sshkeys \$project_id
# dns func
./cloud.sh call get_domain_record_id vim.opensource-expert.com
./cloud.sh call set_ip_domain 12.34.56.78 vim.opensource-expert.com
./cloud.sh call set_forward_dns 12.34.56.78 vim.opensource-expert.com
./cloud.sh call delete_dns_record vim.opensource-expert.com
# instance
./cloud.sh call delete_instance INSTANCE_ID
./cloud.sh call create_snapshot \$project_id INSTANCE_ID SNAP_NAME
./cloud.sh call id_is_project A_PROJECT_ID
./cloud.sh call set_project A_PROJECT_ID
./cloud.sh call write_conf FILENAME "var=val" "var2=val" "DELETE=somevar"
./cloud.sh call loadconf FILENAME

# main command
./cloud.sh get_snap
snapshot_id=some_id_from_get_snap
./cloud.sh create $snapshot_id grep2.opensource-expert.com
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
