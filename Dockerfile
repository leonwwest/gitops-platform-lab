# syntax=docker/dockerfile:1.7
FROM python:3.12.13-slim@sha256:229a2c5bfa27522db7815ea81f9bed70af17ccb9de9fc7ad142b1877b5830d36 AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /build
COPY requirements.txt constraints.lock.txt ./
RUN python -m pip wheel --wheel-dir /wheels -c constraints.lock.txt -r requirements.txt

FROM python:3.12.13-slim@sha256:229a2c5bfa27522db7815ea81f9bed70af17ccb9de9fc7ad142b1877b5830d36 AS runtime

ENV APP_ENV=container \
    APP_VERSION=local \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

COPY --from=builder /wheels /wheels
COPY requirements.txt constraints.lock.txt /tmp/
RUN python -m pip install --no-cache-dir --no-index --find-links=/wheels \
        -c /tmp/constraints.lock.txt -r /tmp/requirements.txt \
    && rm -rf /wheels /tmp/requirements.txt /tmp/constraints.lock.txt

WORKDIR /app
COPY --chown=10001:10001 app ./app

USER 10001:10001
EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=2s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=1)"]

CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
