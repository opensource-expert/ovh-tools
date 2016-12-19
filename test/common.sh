#!/bin/bash

_create_config() {
  cat << EOF > $1
REPO_BASE_DIR=$2
EOF
}

# usage: 
#   log var_name_without_$
#   log string var_name_without_$
log() {
  if [[ $# -gt 1 ]]
  then
    eval "echo \"$1 $2=\$$2\" >> log"
  else
    eval "echo \"$1=\$$1\" >> log"
  fi
}

# need to define $myconf
cleanup() {
  # nothing
  [[ -z "$myconf" ]] && return

  # ensure conf is loaded
  source $myconf
  [[ "$REPO_BASE_DIR" =~ ^\. ]] && \
    rm -rf "$REPO_BASE_DIR"
}
