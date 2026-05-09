#!/bin/bash

# Configuration
CONFIG_FILE="cluster-config.yaml"
CLUSTER_NAME="my-cluster"

# 1. Create the cluster
echo "Creating Kind cluster using $CONFIG_FILE..."
kind create cluster --name "$CLUSTER_NAME" --config "$CONFIG_FILE"

# 2. Disable auto-restart for all nodes in this cluster
echo "Disabling Docker auto-restart for Kind nodes..."
# Filter containers by the cluster label to ensure we only target the specific cluster
docker update --restart=no $(docker ps -a -q --filter label=io.x-k8s.kind.cluster="$CLUSTER_NAME")

echo "Done! The Kind cluster is ready and node containers will NOT start automatically when Docker starts."
