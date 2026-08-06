from __future__ import annotations

import subprocess
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
OVERLAY = ROOT / "deploy" / "overlays" / "local"
PRODUCTION_OVERLAY = ROOT / "deploy" / "overlays" / "production"


def rendered_resources() -> list[dict]:
    result = subprocess.run(
        ["kubectl", "kustomize", str(OVERLAY)],
        check=True,
        capture_output=True,
        text=True,
    )
    return [document for document in yaml.safe_load_all(result.stdout) if document]


def rendered_production_resources() -> list[dict]:
    result = subprocess.run(
        ["kubectl", "kustomize", str(PRODUCTION_OVERLAY)],
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
    assert environment["APP_VERSION"] == "v0.1.0"


def test_production_overlay_declares_availability_controls() -> None:
    resources = rendered_production_resources()
    disruption_budget = resource(resources, "PodDisruptionBudget", "demo-service")
    autoscaler = resource(resources, "HorizontalPodAutoscaler", "demo-service")

    assert disruption_budget["spec"]["minAvailable"] == 1
    assert autoscaler["spec"]["minReplicas"] == 2
    assert autoscaler["spec"]["maxReplicas"] == 6
    assert autoscaler["spec"]["metrics"][0]["resource"]["target"]["averageUtilization"] == 70


def test_production_overlay_defaults_to_network_isolation() -> None:
    policy = resource(rendered_production_resources(), "NetworkPolicy", "demo-service")

    assert policy["spec"]["policyTypes"] == ["Ingress", "Egress"]
    ingress_namespaces = policy["spec"]["ingress"][0]["from"]
    assert {"podSelector": {}} in ingress_namespaces
    assert policy["spec"]["egress"][0]["ports"][0] == {"protocol": "UDP", "port": 53}
