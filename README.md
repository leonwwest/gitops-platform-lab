# GitOps Platform Lab

[![verify](https://github.com/leonwwest/gitops-platform-lab/actions/workflows/verify.yml/badge.svg)](https://github.com/leonwwest/gitops-platform-lab/actions/workflows/verify.yml)
[![Security](https://github.com/leonwwest/gitops-platform-lab/actions/workflows/security.yml/badge.svg)](https://github.com/leonwwest/gitops-platform-lab/actions/workflows/security.yml)

![GitOps Platform Lab overview](assets/social-preview.svg)

A hands-on portfolio and learning environment for the complete path from tested code to container, Kubernetes Desired State, Argo CD reconciliation, observability and incident recovery.

The workload is deliberately small. The value of the project is the **operating path around it**: repeatable verification, safe packaging, declarative delivery, Operational Signals and a reversible Failure Exercise.

## Recruiter quick view

| Question | Evidence in this repository |
|---|---|
| What is delivered? | A tested FastAPI service packaged as a non-root container and described with Kustomize |
| How is it deployed? | Argo CD reconciles Git Desired State; CI validates but never imperatively deploys |
| How is it operated? | Metrics, logs, traces, SLO alerts, dashboards and focused runbooks |
| How is failure handled? | Guarded fault injection, Git-based recovery and a documented rebuild exercise |
| How is it verified? | Fourteen tests, three rendered overlays, image build, CodeQL, dependency audit, Trivy and SPDX SBOM |

### Real execution evidence

This recording comes from the running FastAPI service and the repository's complete `make verify` path. The service response and verification results are observed output, not a generated product mock-up.

![GitOps service and verification run](docs/demo.gif)

## What this demonstrates

- FastAPI service with health, readiness, metrics, structured JSON logs and OpenTelemetry traces
- TDD through public HTTP and rendered-manifest seams
- Multi-stage, non-root container image with a runtime health check
- Kustomize base plus local, failure and production-like overlays
- Local Kubernetes with k3d and explicit probes, resources and security contexts
- Argo CD automated sync, pruning and self-healing from Git
- Prometheus, Grafana, Loki, Grafana Alloy and Jaeger with pinned Helm chart versions
- A guarded incident exercise and recovery by returning to Git Desired State
- Production-like NetworkPolicy, PodDisruptionBudget and CPU autoscaling contracts
- Inspectable availability SLO rules, alert ownership and operator runbooks
- A disaster-recovery exercise that rebuilds from Git instead of applying mutable snapshots
- GitHub Actions with read-only permissions and immutable action references
- A locked Python dependency graph, digest-pinned base image and documented tested toolchain

## Architecture

```mermaid
flowchart LR
    Dev["Git change"] --> CI["GitHub Actions\nverify + image build"]
    Dev --> Git["Desired State\nKustomize overlays"]
    Git --> Argo["Argo CD\nreconciliation"]
    Argo --> K8s["k3d / Kubernetes"]
    Image["Non-root\nDemo Service image"] --> K8s
    K8s --> Service["Demo Service\nhealth · work · metrics"]
    Service --> Prom["Prometheus"]
    Service --> Alloy["Grafana Alloy"]
    Alloy --> Loki["Loki"]
    Service --> Jaeger["Jaeger / OTLP"]
    Prom --> Grafana["Grafana dashboard"]
    Loki --> Grafana
    Operator["Operator"] --> Grafana
    Operator --> Jaeger
    Operator --> Argo
```

The important boundary is intentional: CI validates and builds, while Argo CD deploys by reconciling Git. See [Architecture](docs/architecture.md).

## Quick start

### Prerequisites on macOS

```bash
brew install python@3.12 docker colima k3d kubectl helm argocd
colima start --cpu 4 --memory 8
```

Exact versions used for the recorded verification are listed in [Tested toolchain](docs/tested-toolchain.md).

### 1. Verify a fresh clone

```bash
make verify
make container-verify
```

`make verify` creates the Python 3.12 virtual environment, installs the locked dependency graph, lints the code, renders every Kustomize overlay and runs the public HTTP/manifest tests.

### 2. Bootstrap the complete Platform Lab

```bash
make platform-up
```

This one command verifies the code and manifests, creates the k3d cluster, builds and imports the image, installs Argo CD, reconciles the Git Desired State, installs the observability stack and proves metrics, logs, traces and Grafana health.

### 3. Optional: compare an imperative bootstrap

```bash
make local-up
curl http://127.0.0.1:8080/api/v1/info
```

`make local-up` is a deliberately isolated teaching step that applies the local overlay directly. Use `make gitops-up` to move that cluster to the normal GitOps operating model:

```bash
make gitops-up
make gitops-status
```

Argo CD now reconciles `deploy/overlays/local` from this repository. A manual change to a managed Deployment is detected and corrected.

### 4. Verify observability separately

```bash
make observability-up
make observability-verify
```

The verification generates requests and proves all four paths:

- Prometheus returns `demo_http_requests_total`.
- Loki returns a unique structured log collected by Alloy.
- Jaeger lists `gitops-platform-lab-demo`.
- Grafana reports a healthy database and loads the provisioned dashboard.

### 5. Practise an incident

```bash
CONFIRM_FAILURE_EXERCISE=YES make failure-inject
make failure-status
make failure-recover
```

Follow the [Failure Exercise runbook](docs/runbooks/failure-exercise.md). The guard prevents accidental injection; recovery restores the version-controlled healthy state through Argo CD.

Capture recovery evidence or validate a rebuild with:

```bash
make recovery-snapshot
make recovery-verify
```

See the [SLO alert runbook](docs/runbooks/slo-alerts.md) and the [Desired State recovery exercise](docs/runbooks/disaster-recovery.md).

### Cleanup

```bash
make local-down
colima stop
```

## Local access

Run each port-forward in its own terminal:

```bash
kubectl port-forward -n argocd svc/argocd-server 8081:443
kubectl port-forward -n observability svc/grafana 3000:80
kubectl port-forward -n observability svc/prometheus-server 9090:80
kubectl port-forward -n observability svc/jaeger 16686:16686
```

- Demo Service: http://127.0.0.1:8080/docs
- Argo CD: https://127.0.0.1:8081
- Grafana: http://127.0.0.1:3000
- Prometheus: http://127.0.0.1:9090
- Jaeger: http://127.0.0.1:16686

Retrieve local credentials when needed:

```bash
make observability-password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 --decode; echo
```

## Repository map

```text
app/                    Demo Service
tests/                  Public behaviour and declarative-contract tests
deploy/base/            Reusable Kubernetes Desired State
deploy/overlays/        Local, failure and production-like variants
gitops/                 Argo CD Application
observability/          Pinned values and Grafana dashboard
scripts/                Bootstrap, verification and runbook automation
docs/                   Architecture, ADRs and interview notes
```

## Verification evidence

Verified locally on **24 July 2026** on Apple Silicon:

- `make verify`: 10 public HTTP and rendered-manifest tests, Ruff lint and format, Kustomize render
- `make container-verify`: image ran as UID 10001 and passed HTTP checks
- `make local-up`: k3d Deployment became `1/1` Available and passed runtime smoke tests
- Argo CD: Application became `Synced / Healthy`; manual replica drift was restored from 2 to 1
- `make observability-verify`: metrics, a unique Alloy log, a Jaeger service and Grafana health all confirmed
- Failure Exercise: HTTP 503 observed, then healthy Git state reconciled and smoke-tested

The matching GitHub Issues contain per-slice completion notes.

## Production caveats

This is an honest learning environment, not a production platform:

- k3d is a local Kubernetes distribution; it does not prove experience operating a production cluster.
- Loki uses single-binary filesystem storage with a test schema; Prometheus and Grafana use ephemeral storage.
- Jaeger uses the chart's local all-in-one configuration.
- There is no external secret manager, ingress TLS, SSO, image signing or vulnerability gate. The production-like overlay demonstrates namespace-scoped network isolation, but no real CNI enforcement is claimed.
- The production-like overlay is illustrative and is not deployed to a public environment.
- A real platform would add highly available storage, backups, SLOs and alerts, workload identity, policy enforcement, signed artifacts and environment-specific promotion.

These trade-offs keep the Platform Lab runnable on one laptop while preserving the important interfaces and operational reasoning.

## Learning notes

- [Architecture and data flow](docs/architecture.md)
- [Failure Exercise runbook](docs/runbooks/failure-exercise.md)
- [Interview cheat sheet](docs/interview-cheat-sheet.md)
- [Domain glossary](CONTEXT.md)
- [Tested toolchain and dependency pinning](docs/tested-toolchain.md)

## Sources

- [Argo CD documentation](https://argo-cd.readthedocs.io/)
- [Kustomize documentation](https://kubectl.docs.kubernetes.io/guides/)
- [Prometheus documentation](https://prometheus.io/docs/)
- [Grafana Alloy Kubernetes log collection](https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.kubernetes/)
- [OpenTelemetry Python documentation](https://opentelemetry.io/docs/languages/python/)
