#!/usr/bin/env bash
set -euo pipefail

cluster="${CLUSTER_NAME:-gitops-platform-lab}"
image="${IMAGE:-gitops-platform-lab-demo:local}"
k3s_image="${K3S_IMAGE:-rancher/k3s:v1.35.5-k3s1}"
apply_mode="${APPLY_MODE:-direct}"
context="k3d-${cluster}"

for command in docker k3d kubectl curl; do
  command -v "${command}" >/dev/null 2>&1 || {
    echo "${command} is required" >&2
    exit 1
  }
done

docker info >/dev/null 2>&1 || {
  echo "Docker is not reachable. Start Docker Desktop or run: colima start" >&2
  exit 1
}

if ! k3d cluster get "${cluster}" >/dev/null 2>&1; then
  k3d cluster create "${cluster}" \
    --servers 1 \
    --agents 1 \
    --image "${k3s_image}" \
    --port "127.0.0.1:8080:30080@server:0" \
    --wait
fi

docker build --tag "${image}" .
k3d image import "${image}" --cluster "${cluster}"

kubectl config use-context "${context}" >/dev/null

if [[ "${apply_mode}" == "direct" ]]; then
  kubectl apply --server-side --field-manager=platform-lab-bootstrap \
    --kustomize deploy/overlays/local
  kubectl rollout restart deployment/demo-service --namespace platform-lab
  kubectl rollout status deployment/demo-service \
    --namespace platform-lab \
    --timeout=180s
  BASE_URL="${BASE_URL:-http://127.0.0.1:8080}" ./scripts/smoke-test.sh
elif [[ "${apply_mode}" != "none" ]]; then
  echo "APPLY_MODE must be 'direct' or 'none'" >&2
  exit 1
fi

echo "Platform Lab is running in context ${context}"
if [[ "${apply_mode}" == "direct" ]]; then
  echo "Demo Service: http://127.0.0.1:8080"
fi
