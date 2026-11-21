# Cloud Run image for Müller Bürobedarf's vendor agent ONLY ("another company's server", PRD §2 Should #3).
# make vendor-cloudrun builds and deploys it. Secrets are never baked in (.dockerignore).
FROM python:3.13-slim
WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY backend/__init__.py backend/
COPY backend/common backend/common
COPY backend/agents/__init__.py backend/agents/prompts.py backend/agents/
COPY backend/vendor_agent backend/vendor_agent
CMD exec uvicorn backend.vendor_agent.a2a_app:app --host 0.0.0.0 --port ${PORT:-8080}
