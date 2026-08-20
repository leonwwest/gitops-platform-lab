#!/usr/bin/env bash
set -euo pipefail

argocd_version="${ARGOCD_VERSION:-v3.4.5}"
manifest_url="https://raw.githubusercontent.com/argoproj/argo-cd/${argocd_version}/manifests/install.yaml"

for command in kubectl curl; do
  command -v "${command}" >/dev/null 2>&1 || {
    echo "${command} is required" >&2
    exit 1
  }
done

curl --fail --silent --head "${manifest_url}" >/dev/null

kubectl create namespace argocd \
  --dry-run=client \
  --output=yaml |
  kubectl apply --server-side --field-manager=platform-lab-bootstrap --filename=-

kubectl apply \
  --server-side \
  --field-manager=platform-lab-bootstrap \
  --namespace=argocd \
  --filename="${manifest_url}"

kubectl wait \
  --for=condition=Established \
  customresourcedefinition/applications.argoproj.io \
  --timeout=180s
kubectl rollout status deployment/argocd-server --namespace argocd --timeout=300s
kubectl rollout status deployment/argocd-repo-server --namespace argocd --timeout=300s
kubectl rollout status statefulset/argocd-application-controller \
  --namespace argocd \
  --timeout=300s

kubectl apply --filename gitops/platform-lab-project.yaml
kubectl apply --filename gitops/demo-service.yaml

deadline=$((SECONDS + 300))
while ((SECONDS < deadline)); do
  sync_status="$(
    kubectl get application/demo-service \
      --namespace argocd \
      --output=jsonpath='{.status.sync.status}' 2>/dev/null || true
  )"
  health_status="$(
    kubectl get application/demo-service \
      --namespace argocd \
      --output=jsonpath='{.status.health.status}' 2>/dev/null || true
  )"
  if [[ "${sync_status}" == "Synced" && "${health_status}" == "Healthy" ]]; then
    echo "Argo CD application is Synced and Healthy"
    exit 0
  fi
  sleep 5
done

kubectl get application/demo-service --namespace argocd --output=yaml
kubectl get pods --all-namespaces
echo "Argo CD application did not become Synced and Healthy" >&2
exit 1
