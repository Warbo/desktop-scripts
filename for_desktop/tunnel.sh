#!/usr/bin/env bash
#echo "Checking for SSH identity" 1>&2
#if ssh-add -l | grep 'no identities'
#then
#  ssh-add
#fi

echo "Connecting" 1>&2
autossh -M 0 -NR 22222:localhost:22 cw
