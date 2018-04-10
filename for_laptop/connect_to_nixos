#!/usr/bin/env bash
set -e

BASE=$(dirname "$(readlink -f "$0")")
D=$(cut -f1 < "$BASE/details")
U=$(cut -f2 < "$BASE/details")
P=$(cut -f3 < "$BASE/details")

# FIXME: The latter part looks very brittle
ssh -A -t "$D" ssh -A -t "$U"@localhost -p "$P" ssh -A -t nix@192.168.57.101 screen -DR
