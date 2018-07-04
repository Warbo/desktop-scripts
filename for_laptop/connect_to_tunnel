#!/usr/bin/env bash

if ssh-add -L | grep "The agent has no identities"
then
  ssh-add "$HOME/.ssh/id_rsa"
fi

BASE=$(dirname "$(readlink -f "$0")")
D=$(cut -f1 < "$BASE/details")
U=$(cut -f2 < "$BASE/details")
P=$(cut -f3 < "$BASE/details")

ssh -A -t "$D" ssh -A -t "$U"@localhost -p "$P" screen -DR
