# Architecture and operating model

## Delivery path

1. A change enters Git.
2. GitHub Actions runs `make verify` and constructs the container image.
3. The Kustomize overlay remains the Desired State.
4. Argo CD compares Git with the Running State and reconciles differences.
5. Kubernetes uses readiness and liveness probes to decide whether the Pod can receive traffic and whether it should be restarted.
6. The runtime emits metrics, logs and traces for diagnosis.

CI deliberately does not run `kubectl apply` for the Demo Service. A green build proves that a candidate passed its checks; it does not authorize an imperative deployment. Promotion is a reviewed change to the Desired State, and Argo CD performs reconciliation.

## Test seams

The project tests the highest practical public boundaries:

- `make verify` checks HTTP behaviour and the fully rendered Kustomize resources.
- `make container-verify` checks the running container's identity and HTTP surface.
- `scripts/smoke-test.sh` checks the externally reachable service in k3d.
- `make observability-verify` queries Prometheus, Loki, Jaeger and Grafana over their HTTP APIs.

Tests do not mock internal helpers or assert private implementation details.

## Kubernetes Desired State

The base owns the common Namespace, ServiceAccount, Deployment and Service. Overlays express only meaningful differences:

- `local`: local image, NodePort and local OTLP endpoint
- `failure`: the local state plus the controlled failure flag
- `production`: two replicas and an illustrative registry image

The Deployment runs as UID/GID 10001, drops all Linux capabilities, prevents privilege escalation, uses a read-only root filesystem and does not mount a service-account token.

## Operational Signals

### Metrics

The Demo Service exports request count and request-duration histograms. Prometheus discovers the annotated Pod. Grafana visualises request rate, 5xx rate and P95 latency.

### Logs

Each request emits one JSON log containing timestamp, level, request ID, trace ID when available, method, route, status and duration. Grafana Alloy discovers Pods through the Kubernetes API and sends logs to Loki without privileged host mounts.

### Traces

FastAPI OpenTelemetry instrumentation exports OTLP/HTTP spans to Jaeger. Export is asynchronous; an unavailable trace backend does not make the user request fail.

## Local trade-offs

The platform components use ephemeral or local filesystem storage to fit on a laptop. This makes teardown simple but intentionally sacrifices retention and high availability. The README lists the capabilities required before using the design as a production baseline.
