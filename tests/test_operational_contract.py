from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]


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


def test_recovery_evidence_never_applies_a_running_state_snapshot() -> None:
    script = (ROOT / "scripts" / "recovery-evidence.sh").read_text()

    assert "kubectl get" in script
    assert "kubectl kustomize" in script
    assert "kubectl apply" not in script
