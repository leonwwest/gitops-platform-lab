from __future__ import annotations

import asyncio
import json
import logging
import os
import time
from datetime import UTC, datetime
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Query, Request, Response
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

SERVICE_NAME = "gitops-platform-lab-demo"

REQUESTS = Counter(
    "demo_http_requests_total",
    "Total HTTP requests handled by the Demo Service.",
    ("method", "path", "status"),
)
REQUEST_DURATION = Histogram(
    "demo_http_request_duration_seconds",
    "HTTP request duration for the Demo Service.",
    ("method", "path"),
)


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": datetime.now(UTC).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        for field in ("request_id", "trace_id", "method", "path", "status", "duration_ms"):
            value = getattr(record, field, None)
            if value is not None:
                payload[field] = value
        return json.dumps(payload, separators=(",", ":"))


def configure_logging() -> logging.Logger:
    logger = logging.getLogger("demo_service")
    logger.setLevel(os.getenv("LOG_LEVEL", "INFO").upper())
    if not logger.handlers:
        handler = logging.StreamHandler()
        handler.setFormatter(JsonFormatter())
        logger.addHandler(handler)
    logger.propagate = False
    return logger


def configure_tracing() -> None:
    endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
    if not endpoint:
        return

    provider = TracerProvider(
        resource=Resource.create(
            {
                "service.name": SERVICE_NAME,
                "deployment.environment.name": os.getenv("APP_ENV", "local"),
            }
        )
    )
    exporter = OTLPSpanExporter(endpoint=f"{endpoint.rstrip('/')}/v1/traces")
    provider.add_span_processor(BatchSpanProcessor(exporter))
    trace.set_tracer_provider(provider)


logger = configure_logging()
configure_tracing()
app = FastAPI(
    title="GitOps Platform Lab Demo Service",
    version=os.getenv("APP_VERSION", "dev"),
    docs_url="/docs",
    redoc_url=None,
)
FastAPIInstrumentor.instrument_app(app)


def route_label(request: Request) -> str:
    route = request.scope.get("route")
    return getattr(route, "path", request.url.path)


@app.middleware("http")
async def observe_request(request: Request, call_next):
    request_id = request.headers.get("x-request-id", str(uuid4()))
    started = time.perf_counter()

    try:
        response = await call_next(request)
    except Exception:
        duration = time.perf_counter() - started
        path = route_label(request)
        REQUESTS.labels(request.method, path, "500").inc()
        REQUEST_DURATION.labels(request.method, path).observe(duration)
        logger.exception(
            "request failed",
            extra={
                "request_id": request_id,
                "trace_id": current_trace_id(),
                "method": request.method,
                "path": path,
                "status": 500,
                "duration_ms": round(duration * 1000, 2),
            },
        )
        raise

    duration = time.perf_counter() - started
    path = route_label(request)
    REQUESTS.labels(request.method, path, str(response.status_code)).inc()
    REQUEST_DURATION.labels(request.method, path).observe(duration)
    response.headers["x-request-id"] = request_id
    logger.info(
        "request completed",
        extra={
            "request_id": request_id,
            "trace_id": current_trace_id(),
            "method": request.method,
            "path": path,
            "status": response.status_code,
            "duration_ms": round(duration * 1000, 2),
        },
    )
    return response


def current_trace_id() -> str | None:
    span_context = trace.get_current_span().get_span_context()
    if not span_context.is_valid:
        return None
    return format(span_context.trace_id, "032x")


@app.get("/healthz", tags=["operations"])
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/readyz", tags=["operations"])
async def readiness() -> dict[str, str]:
    return {"status": "ready"}


@app.get("/api/v1/info", tags=["demo"])
async def info() -> dict[str, str]:
    return {
        "name": SERVICE_NAME,
        "environment": os.getenv("APP_ENV", "local"),
        "version": os.getenv("APP_VERSION", "dev"),
    }


@app.get("/api/v1/work", tags=["demo"])
async def synthetic_work(
    duration_ms: int = Query(default=50, ge=0, le=2000),
    fail: bool = False,
) -> dict[str, str | int]:
    await asyncio.sleep(duration_ms / 1000)
    if fail:
        raise HTTPException(status_code=503, detail="synthetic failure requested")
    return {"status": "completed", "duration_ms": duration_ms}


@app.get("/metrics", include_in_schema=False)
async def metrics() -> Response:
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)
