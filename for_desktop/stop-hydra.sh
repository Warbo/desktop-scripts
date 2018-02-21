#!/usr/bin/env bash

echo "Stopping Hydra" 1>&2
sudo systemctl stop hydra-evaluator hydra-queue-runner hydra-server \
                    hydra-send-stats

echo "Waiting for Hydra processes to disappear"
while true
do
    # Look for any processes including 'hydra', except for us!
    FOUND=$(ps auxww | grep hydra | grep -v grep | grep -v 'stop-hydra')
    [[ -n "$FOUND" ]] || break
done
