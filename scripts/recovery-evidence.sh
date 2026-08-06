#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-snapshot}"
NAMESPACE="${NAMESPACE:-platform-lab}"
EVIDENCE_DIR="${EVIDENCE_DIR:-reports/recovery}"

case "$ACTION" in
  snapshot)
    mkdir -p "$EVIDENCE_DIR"
    kubectl get application/demo-service --namespace argocd --output=yaml \
      >"$EVIDENCE_DIR/argocd-application.yaml"
    kubectl get deployment,pod,service --namespace "$NAMESPACE" --output=yaml \
      >"$EVIDENCE_DIR/running-state.yaml"
    kubectl kustomize deploy/overlays/local \
      >"$EVIDENCE_DIR/desired-state.yaml"
    echo "Recovery evidence written to $EVIDENCE_DIR"
    ;;
  verify)
    kubectl wait --for=condition=Healthy application/demo-service \
      --namespace argocd --timeout=180s
    kubectl wait --for=condition=available deployment/demo-service \
      --namespace "$NAMESPACE" --timeout=180s
    ./scripts/smoke-test.sh
    ;;
  *)
    echo "Usage: $0 {snapshot|verify}" >&2
    exit 2
    ;;
esac
