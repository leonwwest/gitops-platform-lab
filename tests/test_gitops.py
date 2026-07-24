from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]


def test_argocd_application_reconciles_the_local_overlay_from_git() -> None:
    application = yaml.safe_load((ROOT / "gitops" / "demo-service.yaml").read_text())
    spec = application["spec"]

    assert application["apiVersion"] == "argoproj.io/v1alpha1"
    assert application["kind"] == "Application"
    assert application["metadata"] == {
        "name": "demo-service",
        "namespace": "argocd",
        "finalizers": ["resources-finalizer.argocd.argoproj.io"],
    }
    assert spec["source"] == {
        "repoURL": "https://github.com/leonwwest/gitops-platform-lab.git",
        "targetRevision": "main",
        "path": "deploy/overlays/local",
    }
    assert spec["destination"] == {
        "server": "https://kubernetes.default.svc",
        "namespace": "platform-lab",
    }
    assert spec["syncPolicy"]["automated"] == {
        "prune": True,
        "selfHeal": True,
        "allowEmpty": False,
    }
    assert "CreateNamespace=true" in spec["syncPolicy"]["syncOptions"]
