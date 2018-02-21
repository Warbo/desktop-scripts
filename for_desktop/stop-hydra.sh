#!/usr/bin/env bash

echo "Stopping Hydra" 1>&2
sudo systemctl stop hydra-evaluator hydra-queue-runner hydra-server \
                    hydra-send-stats

echo "Waiting for Hydra processes to disappear"
while true
do
    # Look for any processes including 'hydra', except for us!
    FOUND=$(pgrep -f hydra)
    if echo "$FOUND" | grep -v "^$$ "
    then
        sleep 10
    else
        break
    fi
done
