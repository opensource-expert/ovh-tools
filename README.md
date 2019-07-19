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
# install jq 1.6, not yet available in package repository
JQ_URL=https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
wget $JQ_URL -O /usr/local/bin/jq
chmod a+x /usr/local/bin/jq
apt install -y python-pip python-dev
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


Pour tous les exemples on travail toujours dans le dossier `~/ovh-tools`.

## Scritps générateur de config pour l'authentification API (experimental)

Pour l'API OVH les paramètre d'authentification sont stoqués dans le `ovh.conf`
qui est dans le dossier local.

L'API python reconnait ce fichier automatiquement :

[pyhton API](https://github.com/ovh/python-ovh).

On peut construire automatiquement le fichier de credential avec la commande suivante.

Note: Actuellement les credential sont fixés à la zone `ovh-eu` d'OVH dans le script `mk_cred.py`

~~~
cd ~/ovh-tools
./mk_cred.py new
# or if you need to update your credential
./mk_cred.py update
~~~

Le script initialise l'authentification avec l'API d'OVH et vous affiche une URL que vous dvez copier dans un navigateur pour
vous authentifier.

S'il s'agit d'une première authentification `./mk_cred.py new` : vous devevez
d'abord saisir une application, le nom et la description de l'application sont
libres. La première authentification web sert à  la création de l'application
pour obtenir les token, et une autre authentification web suivra
avec ces nouveaux tokens. `mk_cred.py` s'occupe de tout.

Il suffit donc simplement de copier coller le texte depuis la page web d'OVH, après la création de l'application, le contenu sera parsé par le script.

Sélectionnez le contenu à l'écran comme sur le screeshot ci-dessous, collez + `ctrl-D`, le tour est joué.

![doc/ovh_create_app.png](doc/ovh_create_app.png)

Recommencer le processus avec vos identiants OVH pour créer le credential avec l'application que nous venons de créer.

Partage du fichier d'authentification avec le script `ovh-cli` :

Il suffit de copier ou de faire un lien symbolique dans les 2 dossiers `ovh-tools/` `ovh-cli/`.

~~~
# after init a temp file is created, to not destroy a existing ovh.conf
mv ovh_conf.tmp ovh.conf
cd ../ovh-cli
ln -s ../ovh-tools/ovh.conf .
~~~

Pour plus de détails référez vous la documentation de l'API OVH en [pyhton API](https://github.com/ovh/python-ovh).


## Test de l'authentification

~~~
cd ~/ovh-cli
./ovh-eu  auth current-credential
~~~

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


## Débug de cloud.sh

Comme mentionné cet outil est un PoC et demeure expérimental, bien que totalement utilisable.

Parfois il y des erreurs étranges qui surviennent. Voici une liste des
messages étrange que l'on peut rencontrer.

### `parse error: Invalid numeric literal at line 1, column 8`

`cloud.sh` peut afficher ce genre de message lors que la commande `jq` n'arrive pas à parser le JSON correctement.

Le cas le plus commun est des credential invalides ou expiré, on vérifie avec :

~~~
cd ~/ovh-tools
./cloud.sh call ovh_cli auth current-credential
./cloud.sh call ovh_cli me
~~~

Solution : recommencer l'étape d'initialiation des credential d'API. Ou juste
un `./mk_cred.py update`.

## Utilisation des commandes

Lister vos environnments public-cloud :

~~~
./cloud.sh
~~~

Enregistrer un `PROJECT_ID` dans `cloud.conf` pour les commandes suivantes :

```
./cloud.sh set_project UN_DES_ID_LISTÉS_AVEC_LA_COMMANDE_PRÉCÉDANTE
```

Lister les instances qui tournent :

~~~
./cloud.sh list
~~~

etc.

Notez que si `./cloud.sh` répète `no project set, or no action` c'est que vous
n'avez pas fait le `set_project` et qu'il ne sait pas vers quel project
diriger vous actions.

De noubreuses commandes sont listées dans le fichier [usage_examples.sh](usage_examples.sh).

La commande `help` affiche une liste des commandes disponibles :

~~~
./cloud.sh help
~~~

On notera que le script permet d'appeler directement les fonctions internes
depuis la ligne de commande, y compris `ovh_cli` qui accède directement à
l'API via pyhton.

Exemple d'appel direct aux méthodes internes, on note que la variable
`$PROJECT_ID` n'est pas disponible dans le shell parent, mais sera évaluée
dans `cloud.sh` qui lui chargera les valeurs de `cloud.conf`

```
./cloud.sh call get_sshkeys \$PROJECT_ID
```

## Exemple de cas d'usage

`$proj` contient un `PROJECT_ID` et peut être sauvé grace à `set_project`.

Ici `$proj` est initialisé dans le shell parent et est évalué par bash avant
l'appel à `cloud.sh`.

```
proj=PROJECT_ID_QUI_VA_BIEN
```

### Lister les snapshot disponibles

```
./cloud.sh snap_list $proj
```

### Lister les clés ssh disponibles

Si vous ne l'avez pas encore uplodé, enregistrer vos clés ssh le via le
manager web d'OVH dans votre projet. Les clés sont par projet.

```
./cloud.sh list_ssh
```

### Création d'une instance

Il nous faut d'abord les arguments : `image_id` `sshkey_username`

Cherchons une image d'OVH de Debian (sensible à la casse):

```
./cloud.sh call find_image \$PROJECT_ID Debian
a794936f-29d7-4d7b-a1a1-f48df6f8a462 Debian 9
d0f7e0ed-b47d-4e4c-b3df-7d61e78d1bfb Debian 8 - Plesk
6938ee31-b42f-4b90-ae7c-ce85e432f328 Debian 8 - GitLab
b11d66ac-e204-4d74-a63b-16caf0dff421 Debian 8 - Docker
cc4e197d-9261-4d70-b97f-8d9299266f3e Debian 8 - Vestacp
282a460d-2f12-497f-8220-437801880803 Debian 8 - WordPress
7e0f71ea-d0e8-4d26-9983-40ee52d9fa06 Debian 8 - OpenVPN
3d8b8b0c-726e-44f3-b94d-9c843881ffb5 Debian 8
71ae7b4e-676a-4411-8e57-5076c7cb896a Debian 9 - Dataiku DSS 5.1.3
25e00721-2eed-4b5e-b282-09f1eb877d2e Debian 8 - Virtualmin
c1fc1426-9fed-4e40-9672-7cae6ccc2a86 Debian 9 - Minikube
07f5aab5-e92d-4c6d-a468-054cfb6669ad Debian 9 - RStudio
f1dd67c0-fdf2-4148-96b3-30f2f9aafe54 Debian 9 - DataScience
45ea1ad6-d147-49e5-ba53-a3104a045fa7 Debian 7
```

On prend la première qui est une image minimale Debian 9 (Stretch) qui vient
de passer à `old stable` début juillet 2019.

```
# adjust with the outputed value of course it may change
image_id=a794936f-29d7-4d7b-a1a1-f48df6f8a462
```

La clé ssh. (Voir ci-dessus pour la liste)

```
# my own key on a projet, use you own key!
sshkey_username=63336c73646d4670626a49774d54593d
```

Le nom que l'on va donner à la machine. (Note: J'utilise des noms de domaine
FQDN après je peux manipuler le DNS via l'API aussi)

```
hostname=ovh-tools.opensource-expert.com
```

On a tout, on crée l'instance:

```
./cloud.sh create $proj $image_id $hostname $sshkey_username
```

* `list_instance` `$proj` : list available runing instance
* `rename` `$proj` `$instance` `$new_name` : rename
* `status` `$proj` [`$instance`] : display json info abouts instances
* `make_snap` `$proj` `$instance` [`$name`] : take a snapshot
* `delete` `$proj` `$instance` ... : delete a runing instance
* all function are callable directly too, read the code
