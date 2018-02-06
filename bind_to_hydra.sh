#!/usr/bin/env bash
set -e

BASE=$(dirname "$(readlink -f "$0")")

[[ -e "$BASE/details" ]] || {
    echo "No 'details' file found, aborting" 1>&2
    exit 1
}

DOMAIN=$(cut -f1 < "$BASE/details")
     U=$(cut -f2 < "$BASE/details")

if ssh-add -L | grep "The agent has no identities"
then
  ssh-add "$HOME/.ssh/id_rsa"
fi

function dom {
  echo "Connecting $DOMAIN:22222 to localhost:22222" 1>&2
  ssh -N -A -L 22222:localhost:22222 "$DOMAIN" &
  PID1="$!"
}

function dsk {
  echo "Connecting remote port 3000 to localhost:3000" 1>&2
  ssh -N -A -L 3000:localhost:3000  "$U"@localhost -p 22222 &
  PID2="$!"
}

function finish {
    kill "$PID1"
    kill "$PID2"
}
trap finish EXIT

function redo {
  if [[ -z "$PID1" ]] || ! kill -0 "$PID1"
  then
    dom
    sleep 2
  fi

  if [[ -z "$PID2" ]] || ! kill -0 "$PID2"
  then
    dsk
  fi
}

while true
do
  redo
  sleep 10
done
