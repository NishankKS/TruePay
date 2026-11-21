PY ?= .venv/bin/python
# Tools installed in user space by the setup (docs/SETUP.md step 1)
export PATH := $(HOME)/tools/flutter/bin:$(HOME)/tools/google-cloud-sdk/bin:$(HOME)/tools/tmuxenv/bin:$(PATH)

.PHONY: fixtures seed up test reset web check-env install emu

# Local dev without any keys: Firestore + Auth emulators (project demo-iw) with the real security rules.
emu:
	firebase emulators:start --only firestore,auth --project demo-iw

install:
	python3 -m venv .venv && $(PY) -m pip install -q -r requirements.txt

check-env:
	@$(PY) scripts/check_env.py

fixtures:
	$(PY) -m backend.fixtures.make_invoices

seed:
	$(PY) -m backend.scripts.seed

# Panes stay open on exit so a crash stays readable. Stage: runner (agents) on top, paygate below.
KEEP = ; echo; echo "[exited - press enter]"; read _
up:
	tmux kill-session -t iw 2>/dev/null || true
	tmux new-session -d -s iw -x 200 -y 50 "$(PY) -m backend.agents.runner $(KEEP)" \; \
	  split-window -v "$(PY) -m backend.paygate.server $(KEEP)" \; \
	  split-window -h "$(PY) -m uvicorn backend.vendor_agent.a2a_app:app --port 8002 $(KEEP)" \; \
	  split-window -h "(curl -sf localhost:11434 >/dev/null && echo 'ollama already running' || ollama serve) $(KEEP)" \; \
	  select-pane -t 0 \; attach

test:
	$(PY) -m pytest tests/ -q

reset:
	$(PY) -m backend.scripts.reset

web: app/firebase.web.json
	cd app && ([ -d web ] || flutter create --platforms=web,android --project-name iban_waechter .) && \
	  flutter pub get && flutter build web --dart-define-from-file=firebase.web.json
	firebase deploy --only hosting,firestore

# Firebase web config (public values) for the Flutter app.
app/firebase.web.json:
	firebase apps:sdkconfig web --json | $(PY) -c "import json,sys; print(json.dumps(json.load(sys.stdin)['result']['sdkConfig']))" > $@
