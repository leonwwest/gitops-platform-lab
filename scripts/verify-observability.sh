#!/usr/bin/env bash
set -euo pipefail

mkdir -p .local
pids=()

cleanup() {
  for pid in "${pids[@]:-}"; do
    kill "${pid}" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

forward() {
  local service="$1"
  local mapping="$2"
  local log_name="$3"
  kubectl port-forward \
    --namespace observability \
    "service/${service}" \
    "${mapping}" >".local/${log_name}.log" 2>&1 &
  pids+=("$!")
}

forward prometheus-server 19090:80 prometheus-port-forward
forward loki 13100:3100 loki-port-forward
forward jaeger 16686:16686 jaeger-port-forward
forward grafana 13000:80 grafana-port-forward

for _ in {1..30}; do
  if curl --fail --silent http://127.0.0.1:19090/-/ready >/dev/null \
    && curl --fail --silent http://127.0.0.1:13100/ready >/dev/null \
    && curl --fail --silent http://127.0.0.1:16686/ >/dev/null \
    && curl --fail --silent http://127.0.0.1:13000/api/health >/dev/null; then
    break
  fi
  sleep 1
done

for duration in 5 10 20 40 80; do
  curl --fail --silent \
    "http://127.0.0.1:8080/api/v1/work?duration_ms=${duration}" >/dev/null
done
curl --silent \
  "http://127.0.0.1:8080/api/v1/work?duration_ms=5&fail=true" >/dev/null

sleep 15

prometheus_response="$(
  curl --fail --silent --get \
    --data-urlencode 'query=sum(demo_http_requests_total)' \
    http://127.0.0.1:19090/api/v1/query
)"
loki_response="$(
  curl --fail --silent --get \
    --data-urlencode 'query={namespace="platform-lab",app="demo-service"}' \
    --data-urlencode 'limit=20' \
    http://127.0.0.1:13100/loki/api/v1/query_range
)"
jaeger_response="$(
  curl --fail --silent http://127.0.0.1:16686/api/services
)"
grafana_response="$(
  curl --fail --silent http://127.0.0.1:13000/api/health
)"

[[ "${prometheus_response}" == *'"status":"success"'* ]]
[[ "${prometheus_response}" == *'"result":['* ]]
[[ "${loki_response}" == *'"status":"success"'* ]]
[[ "${loki_response}" == *'"result":['* ]]
[[ "${jaeger_response}" == *"gitops-platform-lab-demo"* ]]
[[ "${grafana_response}" == *'"database":"ok"'* ]]

echo "observability verification passed: metrics, logs, traces and Grafana health"
