# Tested toolchain

The following versions produced the verification evidence recorded on 24 July 2026:

| Component | Tested version | Reproducibility boundary |
|---|---:|---|
| Python | 3.12.13 | Project range is declared in `pyproject.toml`; the complete dependency graph is constrained in `constraints.lock.txt`. |
| Python container | 3.12.11 slim | Both stages use image digest `sha256:47ae396f09c1303b8653019811a8498470603d7ffefc29cb07c88f1f8cb3d19f`. |
| Docker client/server | 29.6.2 / 29.5.2 | Local container runtime. |
| Colima | 0.10.3 | Local Docker VM on Apple Silicon. |
| k3d | 5.9.0 | Cluster bootstrap tool. |
| k3s | 1.35.5-k3s1 | Pinned by `scripts/bootstrap-local.sh`. |
| kubectl / Kustomize | 1.36.3 / 5.8.1 | Local client and manifest renderer. |
| Helm | 4.2.3 | Observability chart installer. |
| Argo CD CLI / controller manifests | 3.4.5 / 3.4.5 | Controller version is pinned in `scripts/install-argocd.sh`. |
| Prometheus chart | 29.19.0 | Pinned in `observability/versions.env`. |
| Grafana chart | 10.5.15 | Pinned in `observability/versions.env`. |
| Loki chart | 7.1.0 | Pinned in `observability/versions.env`. |
| Alloy chart | 1.11.0 | Pinned in `observability/versions.env`. |
| Jaeger chart | 4.11.1 | Pinned in `observability/versions.env`. |

The Homebrew command in the README installs currently available client builds; this table records the known-good set. Server-side and application dependencies used by the lab are pinned in the repository.
