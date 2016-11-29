# ovh-tools
some sysadmin tools which works with OVH API, bash and python

## Install

pickup what is needed for your environment

~~~
git clone https://github.com/opensource-expert/ovh-tools.git
apt install jq python-pip python-dev
pip install ovh
pip install jinja2

git clone https://github.com/yadutaf/ovh-cli.git
cd ovh-cli/
pip install -r requirements.txt
# downloads json for API
./ovh-eu
~~~

make your credential with: (fixed credential for ovh-eu in mk_cred.py)

~~~
cd ovh-tools
./mk_cred.py
~~~

copy credential file: (or copy in both dir ~/ovh-tools/ ~/ovh-cli/)
~~~
cp ovh_conf.tmp ~/.ovh.conf
~~~


## Run

list your cloud environment
~~~
./cloud.sh
~~~

~~~
./cloud.sh list_instance YOUR_ENV_ID_HERE
~~~

etc… read the code, some param are fixed.

## features

* get_snap $proj : list available snapshot
* list_snapshot $proj : idem
* create $proj $snap_id $hostname (sshkey fixed)
* get_ssh $proj [$name] : list available sshkeys id
* list_instance $proj : list available runing instance
* rename $proj $instance $new_name : rename
* status $prot [$instance] : display json info abouts instances
* make_snap $proj $instance [$name] : take a snapshot
* delete $proj $instance ... : delete a runing instance
* all function are callable directly too, read the code
