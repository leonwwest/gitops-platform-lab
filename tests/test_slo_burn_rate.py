import json
from pathlib import Path

import pytest

from tools.slo_burn_rate import evaluate_scenario, evaluate_window, render_evidence

ROOT = Path(__file__).resolve().parents[1]
CONFIG = json.loads((ROOT / "fixtures" / "slo-burn-rate.json").read_text())


def test_scenario_breaches_then_recovers() -> None:
    states = [evaluate_scenario(scenario, CONFIG)["breached"] for scenario in CONFIG["scenarios"]]
    assert states == [False, True, False]


def test_window_rejects_impossible_request_counts() -> None:
    with pytest.raises(ValueError, match="requests must be positive"):
        evaluate_window({"requests": 10, "errors": 11}, 0.005)


def test_evidence_contains_both_windows_and_recovery() -> None:
    evidence = render_evidence(CONFIG)
    assert "5m burn" in evidence
    assert "1h burn" in evidence
    assert "controlled breach" in evidence
    assert "recovered desired state" in evidence
    assert evidence.count("**PAGE**") == 1
