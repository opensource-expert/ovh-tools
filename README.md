# ovh-tools

Ce dépôt contient un code pour Sysadmin qui utilise l'[API OVH](https://eu.api.ovh.com/console/ pour manipuler des instances sur le public-cloud. Le script est écrit en bash plus un peut de python pour les appels d'API.

Comme c'est destiné à fonctionné sur OVH, j'ai réécrit cette documentation en Français.

English speaker: ask for translation.

## Statut : PoC prototye qui fonctionne

Il y a plusieurs scripts. Le code principale est `cloud.sh`.

* `cloud.sh` - manipule le public cloud d'OVH instances, snapshot et domaines
* `mk_cred.py` -  initialize l'authentification pour l'API OVH avec python
* `ovh_reverse.py` - actice le reverse DNS pour une IP d'instance chez OVH

La documentation manque encore de nombreux détails, et des compétences en programmation bash, JSON, python est fortement recommandées pour utiliser ces outils.

## Installation

Nous montrons une installation sous une VM public-cloud. (testé avec debian 9 Stretch et Ubuntu 18.04)

On suppose que l'installation se fait à la racine d'une VM en roott, on travaile dans `~/`.

```
apt update
apt install -y git
git clone https://github.com/opensource-expert/ovh-tools.git
# TODO: install jq 1.6
apt install -y jq python-pip python-dev
cd ~/ovh-tools
pip install -r requirements.txt
```

~~~
cd ~
git clone https://github.com/yadutaf/ovh-cli.git
cd ovh-cli/
pip install wheel
pip install setuptools
pip install -r requirements.txt
# downloads json for API
./ovh-eu
~~~

### La structure des dossiers attendue
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
cd ~/ovh-cli
./ovh-eu  auth current-credential
~~~

### `parse error: Invalid numeric literal at line 1, column 8`
During `cloud.sh` usage if you get a similar error message.

`jq` is reporting a parse error, credential are probaly invalid, check with:

~~~
cd ~/ovh-tools
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
