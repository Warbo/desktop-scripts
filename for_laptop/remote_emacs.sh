#!/usr/bin/env bash
set -e

if ssh-add -L | grep "The agent has no identities"
then
    ssh-add "$HOME/.ssh/id_rsa"
fi

BASE=$(dirname "$(readlink -f "$0")")
U=$(cut -f2 < "$BASE/details")
P=$(cut -f3 < "$BASE/details")

PAT="ssh.*$P:localhost:$P"
if pgrep -f "$PAT"
then
    echo "Found desktop bind, connecting..." 1>&2
    if ssh -A "$U"@localhost -p "$P" -f pgrep emacs
    then
        echo "Found emacs process" 1>&2
    else
        echo "No emacs process, starting one..."
        ssh -A "$U"@localhost -p "$P" -f emacs --daemon
    fi
    echo "Connecting emacsclient" 1>&2
    ssh -Y -A "$U"@localhost -p "$P" -f ALTERNATE_EDITOR= emacsclient -c
else
    echo "Can't find anything bound to localhost:$P" 1>&2
    exit 1
fi
