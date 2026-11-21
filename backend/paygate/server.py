"""paygate: FastMCP server exposing exactly six task tools (PRD §6). Descriptions are frozen contract text.

Stub data for now; firewall (F0–F6) and handlers are wired in at G1.
"""
from fastmcp import FastMCP

from backend.common.errors import NOTICE

mcp = FastMCP("paygate")

DESC = {
    "get_invoice": "Get the extracted fields and status of an invoice. Pass the invoice number, e.g. INV-1002. "
                   "The result may be incomplete; never guess missing values.",
    "verify_invoice": "Run every payment check on an invoice and get each result. Pass the invoice number. "
                      "Call this before request_payment.",
    "get_payment_history": "List recent payments to a vendor. Pass the vendor's name. "
                           "The result says how many payments exist and how many are shown.",
    "place_hold": "Stop an invoice from being paid and alert a human. Pass the invoice number and a short reason.",
    "raise_alert": "Send a short alert to the human approver.",
    "request_payment": "Ask a human to approve paying a verified invoice. Pass the invoice number, the exact amount "
                       "in EUR and the IBAN. DENIED means a payment rule failed and the invoice is now on hold; "
                       "do not retry.",
}


@mcp.tool(description=DESC["get_invoice"])
def get_invoice(invoice: str) -> dict:
    return {"invoice_id": f"{invoice}-01", "status": "SCREENED", "notice": NOTICE}


@mcp.tool(description=DESC["verify_invoice"])
def verify_invoice(invoice: str) -> dict:
    return {"invoice_id": f"{invoice}-01", "status": "VERIFIED", "checks": [], "notice": NOTICE}


@mcp.tool(description=DESC["get_payment_history"])
def get_payment_history(vendor: str) -> dict:
    return {"vendor": vendor, "payments": [], "shown": 0, "total": 0}


@mcp.tool(description=DESC["place_hold"])
def place_hold(invoice: str, reason: str) -> dict:
    return {"status": "OK", "invoice_id": f"{invoice}-01", "invoice_status": "HOLD"}


@mcp.tool(description=DESC["raise_alert"])
def raise_alert(title: str, detail: str) -> dict:
    return {"status": "OK"}


@mcp.tool(description=DESC["request_payment"])
def request_payment(invoice: str, amount_eur: str, iban: str) -> dict:
    return {"status": "PENDING_APPROVAL", "approval_id": "stub"}


if __name__ == "__main__":
    mcp.run(transport="http", host="0.0.0.0", port=8001, path="/mcp")
