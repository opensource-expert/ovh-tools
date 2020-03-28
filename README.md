# ovh-tools

English speaker: ask for translation by creating an issue.

Ce dépôt contient un cli pour Sysadmin ou DevOps qui utilise l'[API
OVH](https://eu.api.ovh.com/console/) pour manipuler des instances sur le
public-cloud. Le script est écrit en bash. Les appels d'API sont fait via le
wrapper [ovh-cli](https://github.com/opensource-expert/ovh-cli-go) écrit en Go.

Comme c'est destiné à fonctionner sur OVH, j'ai réécrit cette documentation en
Français. Le code et les commentaires eux resteront en anglais.


## Licence

Tout le code de ce repository est distristribué sous [GPL v3](LICENSE)

## Statut : PoC prototype

Ce code est une "Proof of Concept" un prototype qui sert à démonter l'usage de l'API via bash et nécessite un wrapper
sur l'API.

EDIT: mardi 17 mars 2020, 07:37:52 (UTC+0100)

Actuellement, le code est en transition et la procédure d'installation n'est pas revalidée.

## Description des fichiers du projet

Il y a plusieurs scripts. Le code principale est `cloud.sh`.

* `cloud.sh` - manipule le public cloud d'OVH : instances, snapshot et nom de domaines
* `mk_cred.py` -  initialize  ou met à jour, l'authentification pour l'API OVH avec python
* `ovh_reverse.py` - -active le reverse DNS pour une IP d'instance chez OVH- (n'est plus nécessaire)

La documentation manque encore de nombreux détails, et des compétences en
programmation bash, JSON sont fortement recommandées pour utiliser ces
outils.

## Installation

Nous montrons une installation sous une VM public-cloud.

* testé Debian 10
* xubuntu 18.04

On suppose que l'installation est testée dans une VM.

Voir les commandes dans [install.sh](install.sh)

### Installation ovh-cli

Installation de [ovh-cli](https://github.com/opensource-expert/ovh-cli-go)

```
OVH_CLI=https://github.com/opensource-expert/ovh-cli-go/releases/download/v0.3/ovh-cli_linux_amd64
sudo wget $OVH_CLI -O /usr/local/bin/ovh-cli
sudo chmod a+x /usr/local/bin/ovh-cli
ovh-cli --version
```

Voir aussi les commandes dans [install.sh](install.sh)

### La structure des dossiers attendue

```
.
└── ovh-tools
    ├── templates
    └── test
```

Pour tous les exemples on travaille toujours dans le dossier `~/ovh-tools`.

## Script générateur de config pour l'authentification API (experimental)

Pour `cloud.sh` utilise les paramètres d'authentification qui sont stoqués dans le `ovh.conf`
qui est dans le dossier local. C'est un fichier `ini` décrit
[ici](https://github.com/ovh/python-ovh#2-configure-your-application).

L'API OVH python ou Go reconnait ce fichier automatiquement.

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

Le résultat se trouve dans `ovh_conf.tmp`.

```
# after init a temp file is created, in order to prevent overwriting any existing ovh.conf
mv ovh_conf.tmp ovh.conf
```

Partage du fichier d'authentification avec `ovh-cli` :

Il suffit de copier (ou de faire un lien symbolique):

```
ln -s ~/ovh-tools/ovh.conf ~/.ovh.conf
```

Pour plus de détails référez vous la documentation de l'API OVH en
[pyhton API](https://github.com/ovh/python-ovh).


## Test de l'authentification

```
ovh-cli GET /auth/currentCredential | jq .
```

Si tout s'est bien passé on obtient:

```json
{
  "lastUse": null,
  "creation": "2020-03-28T08:07:14+01:00",
  "ovhSupport": false,
  "credentialId": 498601349,
  "applicationId": 105668,
  "expiration": "2020-03-29T09:07:39+02:00",
  "rules": [
    {
      "path": "/*",
      "method": "GET"
    },
    {
      "path": "/*",
      "method": "POST"
    },
    {
      "path": "/*",
      "method": "PUT"
    },
    {
      "path": "/*",
      "method": "DELETE"
    }
  ],
  "allowedIPs": null,
  "status": "validated"
}
```

Avec `status:` **`validated`**.


Quand ça ne fonctionne pas il y a des messages d'erreur.
Ou des infos avec `status expired`

Peut-être qu'il n'y a pas de crédential dans le dossier `~/ovh-cli` ?
On peut utiliser celui généré par `mk_cred.py`

```
ln -s ~/ovh-tools/ovh.conf  ~/.ovh.conf
```

## Debug de cloud.sh

Comme mentionné, cet outil est un PoC et demeure expérimental, bien que totalement utilisable.

Parfois, il y a des erreurs étranges qui surviennent. Voici une liste des
messages d'erreur que l'on peut rencontrer.

### `parse error: Invalid numeric literal at line 1, column 8`

`cloud.sh` peut afficher ce genre de message lors que la commande `jq` n'arrive pas à parser le JSON correctement.

Le cas le plus commun est des credential invalides ou expirés, on vérifie avec :

```
cd ~/ovh-tools
./cloud.sh call myovh_cli GET /auth/currentCredential
./cloud.sh call myovh_cli GET /me
```

Solution : recommencer l'étape d'initialisation des credential d'API. Ou juste
un `./mk_cred.py update` si le token est expiré.

### `no project set, or no action`no project set, or no action

Si `./cloud.sh` répète `no project set, or no action` c'est que vous
n'avez pas fait le `set_project` et qu'il ne sait pas vers quel projet
diriger vos actions.

Ou qu'il n'y a pas de cloud.conf encore.

```
cp cloud.conf.example cloud.conf
```
Et éditez le fichier.

La command `./cloud.sh` sans argument devrait lister vos projets associés au credential

```
./cloud.sh
no project set, or no action
33333333333333333333333333333333 Super_project
66666666666666666666666666666666 Mega_cloud
00000000000000000000000000000000 Pilot-de-formule-1
35353535353535353535353535353535 public-cloud-sylvain
cc88cc88cc88c88cc888c888c888c888 production_awsome_client
```

## configuration dans `cloud.conf`

Regardez le fichier [`cloud.conf.example`](cloud.conf.example)

Le valeurs sont celles d'OVH.

* `DEFAULT_SSH_KEY_NAME`  (le nom pas l'id) `./cloud.sh list_ssh | awk '{print $2}'`
* `REGION` la région openstack `./cloud.sh call region_list \$PROJECT_ID`
* etc.

## Utilisation des commandes

L'interface de ligne de commande peut changer. Généralement les différentes
syntaxes d'une même commande sont supportées.


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
./cloud.sh set_project 355456781234567889cafe88cafe8888
```

### Lister les images disponbles

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

On prend une image minimale Debian 10 (Buster).

```
./cloud.sh image_list | grep 'Debian 10$'
```

```
# adjust with the outputed value of course it may change
image_id=b543fb62-56a8-47ba-9548-9f80e8fd8e0d
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
./cloud.sh create $image_id $sshkey_id $hostname
```

Il faut attendre que l'instance se crée.

### Attendre de l'instance soit prête

La commande avec les valeur du `PROJECT_ID` de l'`instance_id` sont affichées
par `create`:

On peut retrouver ces valeurs avec les commandes suivantes :

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

Affiche une seul ligne en mode texte :

```
./cloud.sh status $instance_id
```

Les informations affichées sont :

```
bdb4a905-e2e8-483f-b135-dac609b3d49b   ==> instance_id
54.37.131.187                          ==> l'IP v4 de l'instance
changeme.opensource-expert.com         ==> le nom de l'instance
ACTIVE                                 ==> son status
WAW1                                   ==> la région OVH où elle tourne
s1-2.consumption                       ==> le type de machine FLAVOR
debian                                 ==> le user de connexion
```

Pour avoir plus d'info on peut avoir le JSON (parsable directement avec `jq`)

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

### recréer une instance à partir d'un snapshot

Comme pour la création à partir d'une image, il faudra réunir des paramètres
pour lancer la création de l'instance :


```
# get my sshkey_id
sshkey_id=$(./cloud.sh ssh_list | awk '$2 == "sylvain2016" { print $1 }')
hostname=phoenix.opensource-expert.com

# one of the snapshot_name available on my project
snapshot_name=snapshot.opensource-expert.com
snapshot_id=$(./cloud.sh snap_list | awk "\$2 == \"$snapshot_name\" { print \$1}")
```

La suite est identique au `create`, sauf que c'est un `snapshot_id` et pas une `image_id`

```
./cloud.sh create $snapshot_id $sshkey_id $hostname
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
####################### WARNING !!! #########################
#
# WARNING: will distroy all running instances without confirm
# cannot really be canceled... you may try CTRL-C
# With Great Power Comes Great Responsibility!
#
####################### WARNING !!! #########################
#
# you've been warned
#
####################### WARNING !!! #########################
./cloud.sh delete ALL
```

## Appel direct à l'API

Alors vous êtes un utilisateur confirmé de bash et vous en voulez plus. Ce PoC
réserve encore quelques joyeusetés.

Le script permet en effet d'appeler directement les fonctions internes
depuis la ligne de commande, y compris `myovh_cli` qui accède directement à
l'API OVH. Mais c'est encore plus simple de l'appeler directement.

Dans les exemples d'appel direct aux fonctions internes, on notera que la variable
`$PROJECT_ID` n'est pas disponible dans le shell parent, mais elle sera évaluée
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
./cloud.sh call find_image \$PROJECT_ID 'Debian.9$'
```

## saved

Encore un peu plus de hacking. Ce PoC permet d'étendre les fonctionnalité de `cloud.sh` en enregistrant des commandes
dans un `.sh` et en les faisant jouer par `cloud.sh` dans le même environnement de code que `cloud.sh` lui même.

```
./cloud.sh run saved/debian_10.sh "new-vm.opensource-expert.com"
```

Quand vous avez une suite de commande qui fonctionne, mettez les dans un `saved/script.sh` et lancer ça automatiquement.

## encore plus

Oui il y en a encore, mais je vais devoir fragmenter cette doc qui devient trop longue.

Il ne reste plus qu'à :

```
vim cloud.sh
```

Joyeux hacking !

## Références

* [ovh-cli](https://github.com/yadutaf/ovh-cli) CLI OVH en python (deprecated)
