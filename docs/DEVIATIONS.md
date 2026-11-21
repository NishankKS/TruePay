# Deviations from PRD snippets (contract unchanged)

- PRD file lived at repo root as `IBAN-Wächter — PRD (DevFest Münster 2026) (2).md`; moved to `docs/PRD.md`.
- FastMCP 4.2.4: server runs with `mcp.run(transport="http", host, port=8001, path="/mcp")` (streamable HTTP).
- `get_invoice` returns the full invoice IBAN (Controller prompt §5 must pass it to `request_payment`); history, approvals, events and logs stay masked (§7 point 2 applies to those).
