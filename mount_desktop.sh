#!/usr/bin/env bash
set -e

BASE=$(dirname "$(readlink -f "$0")")
D=$(cut -f1 < "$BASE/details")
U=$(cut -f2 < "$BASE/details")
P=$(cut -f3 < "$BASE/details")
M=$(cut -f4 < "$BASE/details")

sudo umount "$HOME/$M"
sshfs "$U"@localhost:/ -p "$P" "$HOME/$M"
