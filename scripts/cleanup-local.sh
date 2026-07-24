#!/usr/bin/env bash
set -euo pipefail

cluster="${CLUSTER_NAME:-gitops-platform-lab}"

if k3d cluster get "${cluster}" >/dev/null 2>&1; then
  k3d cluster delete "${cluster}"
else
  echo "cluster ${cluster} does not exist"
fi
