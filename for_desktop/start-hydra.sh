#!/usr/bin/env bash

echo "Starting Hydra" 1>&2
sudo systemctl start hydra-evaluator hydra-queue-runner hydra-server \
                     hydra-send-stats
