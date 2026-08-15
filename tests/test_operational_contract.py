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
