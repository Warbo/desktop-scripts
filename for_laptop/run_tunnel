#!/usr/bin/env bash
set -e

BASE=$(dirname "$(readlink -f "$0")")
D=$(cut -f1 < "$BASE/details")
P=$(cut -f3 < "$BASE/details")

while true
do
    ssh -N -T -R"$P":localhost:22 "$D"
    echo "Disconnected"
    sleep 10
done
