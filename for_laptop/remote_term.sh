#!/usr/bin/env bash

BASE=$(dirname "$(readlink -f "$0")")

xterm -rv "$BASE/connect_to_tunnel.sh" &
