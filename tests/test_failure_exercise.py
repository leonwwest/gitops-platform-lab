from __future__ import annotations

from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]


def test_failure_overlay_enables_only_the_controlled_work_failure() -> None:
    patch = yaml.safe_load(
        (ROOT / "deploy" / "overlays" / "failure" / "deployment-patch.yaml").read_text()
    )
    environment = {
        entry["name"]: entry["value"]
        for entry in patch["spec"]["template"]["spec"]["containers"][0]["env"]
    }

    assert environment == {"APP_ENV": "failure"}


def test_failure_script_requires_confirmation_and_recovers_from_git() -> None:
    script = (ROOT / "scripts" / "failure-exercise.sh").read_text()

    assert "CONFIRM_FAILURE_EXERCISE:-" in script
    assert '!= "YES"' in script
    assert "kubectl apply --filename gitops/demo-service.yaml" in script
    assert "deploy/overlays/failure" in script
    assert "Synced" in script
    assert "Healthy" in script


def test_portfolio_documentation_covers_operation_and_production_caveats() -> None:
    readme = (ROOT / "README.md").read_text()
    runbook = (ROOT / "docs" / "runbooks" / "failure-exercise.md").read_text()
    interview = (ROOT / "docs" / "interview-cheat-sheet.md").read_text()

    for section in (
        "## Architecture",
        "## Quick start",
        "## Verification evidence",
        "## Production caveats",
    ):
        assert section in readme
    assert "make failure-inject" in runbook
    assert "make failure-recover" in runbook
    assert "CI is not GitOps" in interview
