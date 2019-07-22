# ovh-tools

Ce dépôt contient un code pour Sysadmin ou DevOps qui utilise l'[API
OVH](https://eu.api.ovh.com/console/) pour manipuler des instances sur le
public-cloud. Le script est écrit en bash plus un peu de python pour les
appels d'API.

Comme c'est destiné à fonctionner sur OVH, j'ai réécrit cette documentation en
Français, un peu de chauvinisme quoi !
Le code et les commentaires eux resteront en anglais.

English speaker: ask for translation by creating an issue.

## License

Tout le code de ce repository est distristribué sous [GPL v3](LICENSE)

## Statut : PoC prototye qui fonctionne

Il y a plusieurs scripts. Le code principale est `cloud.sh`.

* `cloud.sh` - manipule le public cloud d'OVH : instances, snapshot et domaines
* `mk_cred.py` -  initialize  ou met à jour, l'authentification pour l'API OVH avec python
* `ovh_reverse.py` - active le reverse DNS pour une IP d'instance chez OVH

La documentation manque encore de nombreux détails, et des compétences en
programmation bash, JSON, python sont fortement recommandées pour utiliser ces
outils.

## Installation

Nous montrons une installation sous une VM public-cloud. (testé avec Debian 9 Stretch et Ubuntu 18.04)

On suppose que l'installation se fait à la racine d'une VM en root, on travaile dans `~/` (`/root`).

Voir [install.sh](install.sh)

```
apt update
apt install -y git
git clone https://github.com/opensource-expert/ovh-tools.git
# install jq 1.6, not yet available in package repository
JQ_URL=https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
wget $JQ_URL -O /usr/local/bin/jq
chmod a+x /usr/local/bin/jq
apt install -y python-pip python-dev
cd ~/ovh-tools
pip install -r requirements.txt
```

Installation de [ovh-cli](https://github.com/yadutaf/ovh-cli) en python :

```
cd ~
git clone https://github.com/yadutaf/ovh-cli.git
cd ovh-cli/
pip install wheel
pip install setuptools
pip install -r requirements.txt
# downloads json for API
./ovh-eu
```

### La structure des dossiers attendue

```
.
├── ovh-cli
│   ├── ovhcli
│   │   └── formater
│   └── schemas
└── ovh-tools
    ├── templates
    └── test
```

Pour tous les exemples on travaille toujours dans le dossier `~/ovh-tools`.

## Scritp générateur de config pour l'authentification API (experimental)

Pour l'API OVH, les paramètres d'authentification sont stoqués dans le `ovh.conf`
qui est dans le dossier local. C'est un fichier `ini` décrit
[ici](https://github.com/ovh/python-ovh#2-configure-your-application).

L'API OVH python reconnait ce fichier automatiquement.

On peut construire automatiquement le fichier de credential avec la commande suivante.

Note: Actuellement les credential sont fixés à la zone `ovh-eu` d'OVH dans le script `mk_cred.py`

```
cd ~/ovh-tools
./mk_cred.py new

# or if you need to update your credential
./mk_cred.py update
```

Le script initialise l'authentification avec l'API d'OVH et vous affiche une
URL que vous devez copier dans un navigateur pour vous authentifier.

S'il s'agit d'une première authentification `./mk_cred.py new` : vous devevez
d'abord saisir une application, le nom et la description de l'application sont
libres. La première authentification web sert à  la création de l'application
pour obtenir les tokens, et une autre authentification web suivra
avec ces nouveaux tokens. `mk_cred.py` s'occupe de tout.

Il suffit donc simplement de copier coller le texte depuis la page web d'OVH,
après la création de l'application, le contenu sera parsé par le script.

Sélectionnez le contenu à l'écran comme sur le screeshot ci-dessous, collez +
`ctrl-D`, le tour est joué.

![doc/ovh_create_app.png](doc/ovh_create_app.png)

Recommencer le processus avec vos identiants OVH pour créer le credential avec
l'application que nous venons de créer.

Partage du fichier d'authentification avec le script `ovh-cli` :

Il suffit de copier ou de faire un lien symbolique dans les 2 dossiers
`ovh-tools/` `ovh-cli/`.

```
# after init a temp file is created, to not destroy any existing ovh.conf
mv ovh_conf.tmp ovh.conf
cd ../ovh-cli
ln -s ../ovh-tools/ovh.conf .
```

Pour plus de détails référez vous la documentation de l'API OVH en
[pyhton API](https://github.com/ovh/python-ovh).


## Test de l'authentification

```
cd ~/ovh-cli
./ovh-eu  auth current-credential
```

Si tout s'est bien passé on obtient:

```
--------------  -------------------------------------------------------------------------------------------
Status          validated
Last use        None
Ovh support     False
Creation        2019-07-19T07:24:08+02:00
Credential id   484630013
Rules           {u'path': u'/*', u'method': u'GET'}, {u'path': u'/*', u'method': u'POST'}, {u'path': u'/*',
                u'method': u'PUT'}, {u'path': u'/*', u'method': u'DELETE'}
Expiration      2019-07-20T07:24:32+02:00
Application id  85898
--------------  -------------------------------------------------------------------------------------------
```

Avec `Status validated`.

Et quand ça ne marche pas:

```
Invalid ApplicationSecret 'None'
```

ou des infos avec `status expired`

## Debug de cloud.sh

Comme mentionné, cet outil est un PoC et demeure expérimental, bien que totalement utilisable.

Parfois, il y a des erreurs étranges qui surviennent. Voici une liste des
messages d'erreur que l'on peut rencontrer.

### `parse error: Invalid numeric literal at line 1, column 8`

`cloud.sh` peut afficher ce genre de message lors que la commande `jq` n'arrive pas à parser le JSON correctement.

Le cas le plus commun est des credential invalides ou expirés, on vérifie avec :

```
cd ~/ovh-tools
./cloud.sh call ovh_cli auth current-credential
./cloud.sh call ovh_cli me
```

Solution : recommencer l'étape d'initialiation des credential d'API. Ou juste
un `./mk_cred.py update` si le token est expiré.

## Utilisation des commandes

L'interface de ligne de commande peut changer. Généralement les différentes
syntaxes d'une même commande sont supportées.

Notez que si `./cloud.sh` répète `no project set, or no action` c'est que vous
n'avez pas fait le `set_project` et qu'il ne sait pas vers quel projet
diriger vos actions.

De nombreuses commandes sont listées dans le fichier [usage_examples.sh](usage_examples.sh).

### afficher l'aide

La commande `help` affiche une liste des commandes disponibles :

```
./cloud.sh help
```

Nous verrons à la fin ce que sont les `callable functions`.

### Lister vos environnments public-cloud

```
./cloud.sh

# or

./cloud.sh show_projects
```

### Enregistrer un `PROJECT_ID` dans `cloud.conf`

`cloud.sh` utilise un fichier de configuration `cloud.conf` dans lequel des
valeur sont enregistrées les valeurs à utiliser.

Le `PROJECT_ID` sera passé pour les commandes suivantes :

```
# this identifier is one of the listed via show_projects command
./cloud.sh set_project 3554d1c5d638452f94854da78af239c2
```

### Lister les image disponbles

Ça ne liste que les images Linux :

```
./cloud.sh image_list
```

Pour avoir toutes les images, il faut passer par un appel interne, voir plus
bas.

### Lister les clés ssh disponibles

Si vous ne l'avez pas encore uplodé, enregistrer vos clés ssh le via le
manager web d'OVH dans votre projet. Les clés sont par projet.

```
./cloud.sh list_ssh
```

### Création d'une instance

Il nous faut d'abord les arguments : `image_id` `sshkey_id`

On prend la première qui est une image minimale Debian 9 (Stretch) qui vient
de passer à `old stable` début juillet 2019.

```
./cloud.sh image_list | grep 'Debian 9$'
```

```
# adjust with the outputed value of course it may change
image_id=a794936f-29d7-4d7b-a1a1-f48df6f8a462
```

La clé ssh (les clés sont par projet, même si c'est ma même clé) :

```
./cloud.sh list_ssh
# my own key on a projet, use you own key!
sshkey_id=63336c73646d4670626a49774d54593d
```

Le nom que l'on va donner à la machine. (Note: J'utilise des noms de domaine
FQDN après je peux manipuler le DNS via l'API aussi)

```
hostname=ovh-tools.opensource-expert.com
```

On a tout, on crée l'instance :

```
./cloud.sh create $image_id $hostname $sshkey_id
```

### Attendre de l'instance soit prête

La commande avec les valeur du `PROJECT_ID` de l'`instance_id` sont affichées
par `create`:

```
# list instance_id to get you instance_id
./cloud.sh list

# here take the first one
instance_id=$(./cloud.sh list | awk '{print $1; exit}')
echo "instance_id $instance_id"

# wait
./cloud.sh wait $instance_id
```

La commande `wait` va tester la connexion ssh à l'instance et peut faire
apparaître l'agent ssh pour identifier votre clé ssh.

### Lister les instances qui tournent

```
./cloud.sh list
```

### renommer une instance

Si le nom de l'instance qui s'affiche ne vous convient pas, pas de soucis :

```
new_name=changeme.opensource-expert.com
./cloud.sh rename $instance_id $new_name
```

### afficher le status d'une instance

une ligne en mode texte :

```
./cloud.sh status $instance_id
```

Les informations affiché sont :

```
bdb4a905-e2e8-483f-b135-dac609b3d49b   ==> instance_id
54.37.131.187                          ==> l'IP v4 de l'instance
changeme.opensource-expert.com         ==> le nom de l'instance
ACTIVE                                 ==> son status
WAW1                                   ==> la région OVH où elle tourne
s1-2                                   ==> le type de machine FLAVOR
debian                                 ==> le user de connexion
```

Pour avoir plus d'info on peut avoir le JSON (parsable directement avec jq)

```
./cloud.sh status_full $instance_id
```

### faire un snapshot

```
snapshot_name=snapshot.opensource-expert.com
./cloud.sh make_snap $instance_id $snapshot_name
```

### Attendre que le snapshot soit fait

```
snapshot_id=$(./cloud.sh snap_list | awk "\$2 == \"$snapshot_name\" { print \$1}")
./cloud.sh snap_wait $snapshot_id
```

### Lister les snapshot disponibles

```
./cloud.sh snap_list
```

### supprimer un snapshot

```
./cloud.sh snap_delete $snapshot_id
```

### supprimer une instance

```
./cloud.sh delete $instance_id
```

Et si vous êtes pressé et sûr de ce que vous faîtes...

```
# WARNING: will distroy all running instances without confirm
# cannot really be canceled... you may try CTRL-C
# With Great Power Comes Great Responsibility!
./cloud.sh delete ALL
```

### recréer une instance à partir d'un snapshot

Comme pour la création à partir d'une image, il faudra réunir des paramètres
pour lancer la création de l'instance :


```
# get my sshkey_id
sshkey_id=$(./cloud.sh ssh_list | awk '$2 == "sylvain2016" { print $1 }')
hostname=phoenix.opensource-expert.com

# one of the snapshot_name available on my project
snapshot_name=Debian10
snapshot_id=$(./cloud.sh snap_list | awk "\$2 == \"$snapshot_name\" { print \$1}")
```

La suite est identique, sauf que c'est un `snapshot_id` et pas une `image_id`

```
./cloud.sh create $snapshot_id $hostname $sshkey_id
```

## Appel direct à l'API

Alors vous êtes un utilisateur confirmé de bash et vous en voulez plus. Ce PoC
réserve encore quelques joyeusetés.

Le script permet en effet d'appeler directement les fonctions internes
depuis la ligne de commande, y compris `ovh_cli` qui accède directement à
l'API OVH via pyhton.

Dans les exemples d'appel direct aux fonctions internes, on notera que la variable
`$PROJECT_ID` n'est pas disponible dans le shell parent, mais le sera évaluée
dans `cloud.sh` qui, lui, chargera les valeurs de `cloud.conf`. Lors de l'appel
un backslash passe le signe `$` au script parent.

Lors des appels avec `call` il n'y a plus de passage automatique de
`$PROJECT_ID` il doit être passé explicitement.

### lister les clés SSH

```
./cloud.sh call get_sshkeys \$PROJECT_ID
```

### Lister l'image avec filtre

Remplacer les espaces par des . dans les pattern pour grep, car `call` fait un
`eval` qui mange les espaces.

```
./cloud.sh call find_image \$PROJECT_ID Debian.9$
```

