# cloud.sh truc en cours

## fix le script could-init qui ne fonctionne plus

## bloquer une suppression de VM ou snapshot

via cloud.conf ou un autre fichier de config ?

protected.conf

```
SNAP_PROTECTED=(
SNAP_ID
SNAP_ID2
...
)

INSTANCE_PROTECTED=(
INSTANCE_ID
INSTANCE_ID2
...
)

# ou en Assoc
declare -A A_INSTANCE_PROTECTED
A_INSTANCE_PROTECTED=(
[molo]="mercredi 17 juillet 2019, 09:39:58 (UTC+0200)"
[molo2]="mercredi 17 juillet 2019, 09:41:59 (UTC+0200)"
)

```

exemple d'API

```
./cloud.sh snap_protect SNAP_ID
./cloud.sh instance_protect INSTANCE_ID

# list
./cloud.sh protected
```

dans les commandes d'API pas dans la commande main seulement

## create et check region ou force région

lors du create, si la valeur REGION ne match pas celle de l'image:

* forcer à celle de l'image
* stopper et afficher un warning

## ajouter init

Initialisation des credentials et de la config de l'outil (voire installation de ovh-cli ?)
Génération du cloud.conf avec un template

## ajouter docopts


## ajouter les tests fonctionnels avec bats-core

Dans test/all.sh à convertir

## ajouter le `create_saved_script`

récupère les informations sur une VM qui tourne et génère un script de restart.

Usage:

```
# dump
./cloud.sh create_saved_script $instance_id saved/restore_ansible.sh

# restore

./cloud.sr run saved/restore_ansible.sh
```

récupère (sauve le json de l'instance dans le .sh généré?)

* la flavor
* le hostname
* les clés ssh
* les domaines à reset à la fin sur l'IP
* fait un snapshot ?

```bash
# force hostname
myhostname=vim7.opensource-expert.com

# restoring as flavor:
FLAVOR_NAME=eg-7

# store some output for optimizing API no-requery (internal)
mytmp=$TMP_DIR/saved_vim7_eg7.$$

# get last image by comment
#myimage=$(last_snapshot $PROJECT_ID vim7)
# get first image
myimage=$(order_snapshots $PROJECT_ID \
  | grep "vim7" | tail -1 | awk '{print $1}')

# reforce this at the end
myinit_script=$SCRIPTDIR/init/init_root_login_OK.sh

mysshkey=$(get_sshkeys $PROJECT_ID sylvain)
instance=$(create_instance $PROJECT_ID $myimage $mysshkey \
  $myhostname $myinit_script \
  | jq -r '.id')
if wait_for_instance $PROJECT_ID $instance 210 ; then
  get_instance_status $PROJECT_ID $instance FULL > $mytmp
  ip=$(get_ip_from_json < $mytmp)
  hostname=$(jq -r '.name' < $mytmp)
  set_ip_domain $ip $hostname
fi
rm $mytmp

# post setup
if [[ -n "$ip" ]]
then
  # empty my ssh/known_hosts
  ssh-keygen -f "/home/sylvain/.ssh/known_hosts" -R $myhostname
  ssh-keygen -f "/home/sylvain/.ssh/known_hosts" -R $ip
  source $SCRIPTDIR/saved/assign_domain_to_ip.sh $ip
  #cat init/cleanup_vim7.sh | ssh -y
fi
```

## `write_conf` avec support de commentaires?

comment on fait les mises à jour du commentaire au dessu de VAR1 ?

```
write_conf -c "VAR1: mon commentaire blabla" VAR1=valeur
```

prototype

```bash
# write_conf avec comentaires optionnel dans le parsing
func() {
  i=1
  comment=''
  while [[ $i -le $# ]]
  do
    v=${@:$i:1}
    if [[ $v == '-c' ]]
    then
      comment=${@:$((i+1)):1}
      i=$((i+2))
      continue
    fi

    var_name=${v%=*}
    echo "VAR=$var_name => $v comment '$comment'"
    comment=""
    i=$((i+1))
  done
}


func "$@"
```
