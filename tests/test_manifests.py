from __future__ import annotations

import subprocess
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
OVERLAY = ROOT / "deploy" / "overlays" / "local"


def rendered_resources() -> list[dict]:
    result = subprocess.run(
        ["kubectl", "kustomize", str(OVERLAY)],
        check=True,
        capture_output=True,
        text=True,
    )
    return [document for document in yaml.safe_load_all(result.stdout) if document]


def resource(resources: list[dict], kind: str, name: str) -> dict:
    return next(
        item for item in resources if item["kind"] == kind and item["metadata"]["name"] == name
    )


def test_local_overlay_renders_a_deployable_public_service() -> None:
    resources = rendered_resources()

    namespace = resource(resources, "Namespace", "platform-lab")
    deployment = resource(resources, "Deployment", "demo-service")
    service = resource(resources, "Service", "demo-service")
    service_account = resource(resources, "ServiceAccount", "demo-service")

    assert namespace["metadata"]["name"] == "platform-lab"
    assert service_account["metadata"]["namespace"] == "platform-lab"
    assert deployment["metadata"]["namespace"] == "platform-lab"
    assert service["spec"]["type"] == "NodePort"
    assert service["spec"]["ports"][0]["nodePort"] == 30080


def test_deployment_has_runtime_safety_and_operability_controls() -> None:
    deployment = resource(rendered_resources(), "Deployment", "demo-service")
    pod_spec = deployment["spec"]["template"]["spec"]
    container = pod_spec["containers"][0]

    assert pod_spec["serviceAccountName"] == "demo-service"
    assert pod_spec["securityContext"]["runAsNonRoot"] is True
    assert pod_spec["securityContext"]["seccompProfile"]["type"] == "RuntimeDefault"
    assert container["securityContext"] == {
        "allowPrivilegeEscalation": False,
        "capabilities": {"drop": ["ALL"]},
        "readOnlyRootFilesystem": True,
    }
    assert container["livenessProbe"]["httpGet"]["path"] == "/healthz"
    assert container["readinessProbe"]["httpGet"]["path"] == "/readyz"
    assert container["resources"] == {
        "requests": {"cpu": "50m", "memory": "64Mi"},
        "limits": {"cpu": "500m", "memory": "256Mi"},
    }


def test_local_overlay_declares_environment_and_image_version() -> None:
    deployment = resource(rendered_resources(), "Deployment", "demo-service")
    container = deployment["spec"]["template"]["spec"]["containers"][0]
    environment = {entry["name"]: entry["value"] for entry in container["env"]}

    assert container["image"] == "gitops-platform-lab-demo:local"
    assert container["imagePullPolicy"] == "IfNotPresent"
    assert environment["APP_ENV"] == "local"
    assert environment["APP_VERSION"] == "local"
