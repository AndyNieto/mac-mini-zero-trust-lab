#!/bin/bash

# Script to stop, delete, and start the k3s-master Lima VM remotely

HOST="homelab@192.168.1.118"
LIMACTL="/opt/homebrew/bin/limactl"
VM_NAME="k3s-master"
CONFIG="~/k3s-master.yaml"

echo "Recreating $VM_NAME on $HOST..."

ssh -t "$HOST" "echo 'Stopping $VM_NAME...' && ($LIMACTL stop $VM_NAME || echo 'VM not running') && \
                echo 'Deleting $VM_NAME...' && ($LIMACTL delete $VM_NAME || echo 'VM not found') && \
                echo 'Starting $VM_NAME...' && $LIMACTL start --name=$VM_NAME $CONFIG"
