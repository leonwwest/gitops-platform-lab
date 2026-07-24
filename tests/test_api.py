from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_and_readiness_are_observable() -> None:
    health = client.get("/healthz")
    readiness = client.get("/readyz")

    assert health.status_code == 200
    assert health.json() == {"status": "ok"}
    assert readiness.status_code == 200
    assert readiness.json() == {"status": "ready"}


def test_info_describes_the_demo_service(monkeypatch) -> None:
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv("APP_VERSION", "test-version")

    response = client.get("/api/v1/info")

    assert response.status_code == 200
    assert response.json() == {
        "name": "gitops-platform-lab-demo",
        "environment": "test",
        "version": "test-version",
    }


def test_synthetic_work_exposes_success_and_controlled_failure() -> None:
    success = client.get("/api/v1/work?duration_ms=1")
    failure = client.get("/api/v1/work?duration_ms=1&fail=true")

    assert success.status_code == 200
    assert success.json() == {"status": "completed", "duration_ms": 1}
    assert failure.status_code == 503
    assert failure.json() == {"detail": "synthetic failure requested"}


def test_environment_can_enable_the_reversible_failure_exercise(monkeypatch) -> None:
    monkeypatch.setenv("FAILURE_MODE", "true")

    response = client.get("/api/v1/work?duration_ms=1")

    assert response.status_code == 503
    assert response.json() == {"detail": "failure exercise is active"}


def test_work_rejects_values_outside_the_safe_range() -> None:
    too_slow = client.get("/api/v1/work?duration_ms=2001")

    assert too_slow.status_code == 422


def test_metrics_are_exposed_through_prometheus_format() -> None:
    client.get("/healthz")
    client.get("/api/v1/work?duration_ms=1")

    response = client.get("/metrics")

    assert response.status_code == 200
    assert "text/plain" in response.headers["content-type"]
    assert "demo_http_requests_total" in response.text
    assert "demo_http_request_duration_seconds" in response.text


def test_request_id_is_returned_to_the_caller() -> None:
    response = client.get("/healthz", headers={"x-request-id": "interview-demo"})

    assert response.headers["x-request-id"] == "interview-demo"
