PY ?= .venv/bin/python

.PHONY: fixtures seed up test reset web

fixtures:
	$(PY) -m backend.fixtures.make_invoices

seed:
	$(PY) -m backend.scripts.seed

up:
	tmux new-session -d -s iw "ollama serve" \; \
	  split-window -v "$(PY) -m backend.paygate.server" \; \
	  split-window -v "$(PY) -m uvicorn backend.vendor_agent.a2a_app:app --port 8002" \; \
	  split-window -v "$(PY) -m backend.agents.runner" \; \
	  select-layout even-vertical \; attach

test:
	$(PY) -m pytest tests/ -q

reset:
	$(PY) -m backend.scripts.reset

web:
	cd app && flutter build web
	firebase deploy --only hosting,firestore
