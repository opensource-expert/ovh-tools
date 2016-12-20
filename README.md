# ovh-tools
Sysadmin tools which works with [OVH API](https://eu.api.ovh.com/console/),
written in bash and python.


## Status : working draft

There's multiple scripts. The main code is `cloud.sh`.

* `cloud.sh` - manipulate OVH public cloud instances and snapshot
* `mk_cred.py` - intiate credential for python OVH API
* `ovh_reverse.py` - set a reverse DNS entry on OVH
* `ovh_snapshot.py` - take a snapshot of an instance

Documentation is still lacking a lot of details and programming skill
is strongly requiered.

## Install

pickup what is needed for your environment: (Tested on Debian 8 Jessie and
ubuntu 16.10)

I assume `~/` as base dir.

~~~
apt install -y git
git clone https://github.com/opensource-expert/ovh-tools.git
apt install -y jq python-pip python-dev
cd ~/ovh-tools
pip install -r requirements.txt
~~~

~~~
git clone https://github.com/yadutaf/ovh-cli.git
cd ovh-cli/
pip install -r requirements.txt
# downloads json for API
./ovh-eu
~~~

### supposed folder structure
~~~
.
├── ovh-cli
│   ├── ovhcli
│   │   └── formater
│   └── schemas
└── ovh-tools
    ├── templates
    └── test
~~~

## Credential generator script (experimental)
Credential are stored in `ovh.conf` in the local folder.
This is the python OVH API way of storing the credential. See
[pyhton API](https://github.com/ovh/python-ovh).

make your credential with: (currently fixed credential for ovh-eu
in `mk_cred.py`)

~~~
cd ~/ovh-tools
./mk_cred.py new
# or if you need to update your credential
./mk_cred.py update
~~~

Paste it!
Select on screen info and paste it as is + hit ctrl-D.
You will need to authenticate twice on OVH URL.

![doc/ovh_create_app.png](doc/ovh_create_app.png)

Sharing credential with ovh-cli

copy credential file: (here we symlink in both dir `ovh-tools/` `ovh-cli/`)
~~~
mv ovh_conf.tmp ovh.conf
cd ../ovh-cli
ln -s ../ovh-tools/ovh.conf .
~~~

See Python OVH API doc for more details.

Test credential:

~~~
./ovh-eu  auth current-credential
~~~

### `parse error: Invalid numeric literal at line 1, column 8`
During `cloud.sh` usage if you get a similar error message.

`jq` is reporting a parse, credential are probaly invalid, check with:

~~~
./cloud.sh call ovh_cli auth current-credential
./cloud.sh call ovh_cli me
~~~

## Run

list your cloud environment
~~~
./cloud.sh
~~~

Store your working `PROJECT_ID` in `cloud.conf` for easier command:

~~~
./cloud.sh set_project PROJECT_ID
~~~

After all command are run against this `PROJECT_ID`. You can also
force it on command line.

list runing instances:
~~~
./cloud.sh list
~~~

etc… read the code, some param are fixed or globals.

Many working command line usage are listed in
[usage_examples.sh](usage_examples.sh).


`help` only grep functions and case entries.
~~~
./cloud.sh help
~~~

## main case execution

Not exhaustive.

`$proj` is a `PROJECT_ID` can be saved in cloud.conf via `set_project`.

* `list_snap` `$proj` : list available snapshot
* `create` `$proj` `$snap_id` `$hostname` (`sshkey` fixed) `name`
* `get_ssh` `$proj` [`$name`] : list available sshkeys id
* `list_instance` `$proj` : list available runing instance
* `rename` `$proj` `$instance` `$new_name` : rename
* `status` `$proj` [`$instance`] : display json info abouts instances
* `make_snap` `$proj` `$instance` [`$name`] : take a snapshot
* `delete` `$proj` `$instance` ... : delete a runing instance
* all function are callable directly too, read the code
