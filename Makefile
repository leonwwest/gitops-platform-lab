PYTHON ?= .venv/bin/python
PIP ?= .venv/bin/pip
IMAGE ?= gitops-platform-lab-demo:local

.PHONY: setup test lint format-check verify run

setup:
	python3 -m venv .venv
	$(PIP) install --disable-pip-version-check -r requirements-dev.txt

test:
	$(PYTHON) -m pytest

lint:
	$(PYTHON) -m ruff check .

format-check:
	$(PYTHON) -m ruff format --check .

verify: lint format-check test

run:
	$(PYTHON) -m uvicorn app.main:app --host 0.0.0.0 --port 8080
