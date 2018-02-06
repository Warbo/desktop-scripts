#!/usr/bin/env bash
set -e
set -x

BASE=$(dirname "$(readlink -f "$0")")
D=$(cut -f1 < "$BASE/details")
U=$(cut -f2 < "$BASE/details")
P=$(cut -f3 < "$BASE/details")

ssh -A -L5900:127.0.0.1:5900 "$U"@localhost -p "$P" \
    "DISPLAY=:0.0 nix-shell -p x11vnc --run 'x11vnc -listen 127.0.0.1'" &

sleep 10

vncviewer -encodings 'copyrect tight zrle hextile' 127.0.0.1:5900
