#!/usr/bin/env bash
set -e

BASE=$(dirname "$(readlink -f "$0")")
D=$(cut -f1 < "$BASE/details")
P=$(cut -f3 < "$BASE/details")

while true
do
    PID=$(ps auxww | grep ssh | grep "$P" | sed -e 's/ [ ]*/ /g' |
                     cut -d ' ' -f 2)
    if [[ -z "$PID" ]]
    then
        echo "Not running"
    else
        if ssh "$D" true
        then
            echo "Connected"
        else
            echo "Disconnected, killing"
            kill "$PID"
        fi
    fi
    sleep 10
done
