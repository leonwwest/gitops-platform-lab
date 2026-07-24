# Interview cheat sheet

## 30-second explanation

> I built a local GitOps Platform Lab around a small FastAPI service. Every change is tested, packaged as a non-root container and represented as Kustomize Desired State. Argo CD reconciles that state into k3d and self-heals drift. Prometheus and Grafana expose metrics, Alloy and Loki centralise structured logs, and OpenTelemetry sends traces to Jaeger. I also built a guarded failure exercise that I can diagnose and recover through Git reconciliation.

## CI is not GitOps

CI answers: **Is this candidate build valid?** It runs tests, validates manifests and builds the image.

GitOps answers: **Should the cluster converge to this reviewed state?** Git holds Desired State and Argo CD continuously reconciles it. CI does not need direct cluster credentials for application deployment.

## Concepts to explain

### Desired State and reconciliation

Kustomize renders the declared target configuration. Argo CD compares it with the cluster, applies missing changes, prunes removed resources and self-heals drift.

### Liveness versus readiness

- Liveness answers whether Kubernetes should restart the container.
- Readiness answers whether the Pod should receive traffic.
- A business-function failure does not automatically mean the process is dead; the Failure Exercise keeps probes healthy so diagnosis stays possible.

### Metrics, logs and traces

- Metrics show trend and impact: rate, errors and latency.
- Logs show discrete events with request context.
- Traces show the path and timing of a request.
- A request ID supports correlation even when a tracing backend is unavailable.

### Safe changes

Define scope, dependencies, test criteria and rollback before the change. Use a small reviewable Desired State change, observe rollout and signals, verify the user-facing result and document what happened.

### Why k3d?

It creates a reproducible local Kubernetes environment quickly and cheaply. It is suitable for learning APIs and operational workflows, but it is not evidence of production cluster operations.

## Strong evidence from the project

- TDD began with failing public-behaviour tests.
- The container was verified as UID 10001.
- The same local bootstrap ran repeatedly.
- Argo CD restored a manually changed replica count from 2 to the Git value 1.
- The observability verifier found a real metric, a unique Alloy log and a Jaeger service.
- A real installation bug placed Argo resources in `default`; logs and resource inspection identified the missing namespace flag, and the bootstrap was fixed and rerun.
- Loki initially failed on a read-only filesystem; container logs revealed the missing ephemeral data mount, which was then represented in pinned values.

## Honest boundaries

> This lab demonstrates concepts, reproducibility and operational reasoning. It does not mean I have operated a production Kubernetes platform. The next production steps would include persistent HA backends, SLO-based alerts, external secrets, policy enforcement, signed images, backups, TLS/SSO and controlled environment promotion.

## Questions this project helps answer

- What is the difference between CI/CD and GitOps?
- How do you troubleshoot a Kubernetes rollout?
- Why can a Pod be alive but not ready?
- How do you correlate a 5xx spike with logs and traces?
- What does Argo CD self-healing do?
- How would you make a local observability stack production-ready?
- How do you test Kubernetes manifests without coupling tests to file layout?
