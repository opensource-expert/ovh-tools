# cloud.sh truc en cours


## ajouter init

Initialisation des credentials et de la config de l'outil (voire installation de ovh-cli ?)

## ajouter docopts


## write_conf avec support de commentaires?

comment on fait les mises à jour du commentaire au dessu de VAR1 ?

```
write_conf -c "mon commentaire sur VAR1" VAR1=valeur
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
