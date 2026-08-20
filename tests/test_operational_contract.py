from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]


def test_argocd_project_scopes_source_destination_and_resource_kinds() -> None:
    project = yaml.safe_load((ROOT / "gitops" / "platform-lab-project.yaml").read_text())
    application = yaml.safe_load((ROOT / "gitops" / "demo-service.yaml").read_text())
    spec = project["spec"]

    assert application["spec"]["project"] == project["metadata"]["name"]
    assert spec["sourceRepos"] == ["https://github.com/leonwwest/gitops-platform-lab.git"]
    assert spec["destinations"] == [
        {"namespace": "platform-lab", "server": "https://kubernetes.default.svc"}
    ]
    assert spec["clusterResourceWhitelist"] == [{"group": "", "kind": "Namespace"}]
    assert {entry["kind"] for entry in spec["namespaceResourceWhitelist"]} == {
        "Deployment",
        "HorizontalPodAutoscaler",
        "NetworkPolicy",
        "PodDisruptionBudget",
        "Service",
        "ServiceAccount",
    }
    assert spec["orphanedResources"]["warn"] is True


def test_slo_alerts_have_ownership_severity_and_runbooks() -> None:
    groups = yaml.safe_load((ROOT / "observability" / "slo-rules.yaml").read_text())["groups"]
    alerts = [rule for group in groups for rule in group["rules"] if "alert" in rule]

    assert {alert["alert"] for alert in alerts} == {
        "DemoServiceFastErrorBudgetBurn",
        "DemoServiceUnavailable",
    }
    for alert in alerts:
        assert alert["labels"]["severity"] == "page"
        assert alert["labels"]["service"] == "demo-service"
        assert alert["annotations"]["runbook_url"].startswith("docs/runbooks/")


def test_slo_budget_alert_requires_short_and_long_window_burn() -> None:
    rules = (ROOT / "observability" / "slo-rules.yaml").read_text()

    assert "burn_rate5m > 14.4" in rules
    assert "burn_rate1h > 6" in rules
    assert "ratio_rate5m / 0.005" in rules
    assert "ratio_rate1h / 0.005" in rules


def test_recovery_evidence_never_applies_a_running_state_snapshot() -> None:
    script = (ROOT / "scripts" / "recovery-evidence.sh").read_text()

    assert "kubectl get" in script
    assert "kubectl kustomize" in script
    assert "kubectl apply" not in script


def test_reconciliation_exercise_proves_self_healing_without_imperative_recovery() -> None:
    script = (ROOT / "scripts" / "reconciliation-exercise.sh").read_text()

    assert "CONFIRM_RECONCILIATION_EXERCISE" in script
    assert "kubectl scale" in script
    assert "argocd.argoproj.io/refresh=hard" in script
    assert 'if [[ "${after_revision}" != "${before_revision}" ]]' in script
    assert "kubectl apply" not in script
