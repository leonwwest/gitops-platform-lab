#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=observability/versions.env
source observability/versions.env

for command in helm kubectl openssl; do
  command -v "${command}" >/dev/null 2>&1 || {
    echo "${command} is required" >&2
    exit 1
  }
done

kubectl create namespace observability \
  --dry-run=client \
  --output=yaml |
  kubectl apply --server-side --field-manager=platform-lab-bootstrap --filename=-

if ! kubectl get secret/grafana-admin --namespace observability >/dev/null 2>&1; then
  grafana_password="$(openssl rand -hex 12)"
  kubectl create secret generic grafana-admin \
    --namespace observability \
    --from-literal=admin-user=admin \
    --from-literal="admin-password=${grafana_password}"
fi

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts \
  --force-update
helm repo add grafana https://grafana.github.io/helm-charts --force-update
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts --force-update
helm repo update

helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace observability \
  --version "${PROMETHEUS_CHART_VERSION}" \
  --values observability/prometheus-values.yaml \
  --wait \
  --timeout 10m

helm upgrade --install loki grafana/loki \
  --namespace observability \
  --version "${LOKI_CHART_VERSION}" \
  --values observability/loki-values.yaml \
  --wait \
  --timeout 10m

helm upgrade --install alloy grafana/alloy \
  --namespace observability \
  --version "${ALLOY_CHART_VERSION}" \
  --values observability/alloy-values.yaml \
  --wait \
  --timeout 10m

if helm status promtail --namespace observability >/dev/null 2>&1; then
  helm uninstall promtail --namespace observability
fi

helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace observability \
  --version "${JAEGER_CHART_VERSION}" \
  --values observability/jaeger-values.yaml \
  --wait \
  --timeout 10m

helm upgrade --install grafana grafana/grafana \
  --namespace observability \
  --version "${GRAFANA_CHART_VERSION}" \
  --values observability/grafana-values.yaml \
  --wait \
  --timeout 10m

kubectl apply --filename observability/grafana-dashboard.yaml

echo "Observability stack is ready."
echo "Run 'make observability-verify' to verify metrics, logs and traces."
