#!/usr/bin/env bash

echo "Stopping Hydra" 1>&2
sudo systemctl stop hydra-evaluator hydra-queue-runner hydra-server
