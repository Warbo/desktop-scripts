#!/usr/bin/env bash

echo "Stopping Hydra" 1>&2
sudo systemctl stop hydra-evaluator hydra-queue-runner hydra-server \
                    hydra-send-stats

echo "Waiting for Hydra processes to disappear"
while pgrep -f hydra
do
    sleep 10
done
