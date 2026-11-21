"""uvicorn backend.vendor_agent.a2a_app:app --port 8002"""
from google.adk.a2a.utils.agent_to_a2a import to_a2a

from backend.vendor_agent.agent import vendor_agent

app = to_a2a(vendor_agent, port=8002)
