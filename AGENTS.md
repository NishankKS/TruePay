# Rules for coding agents (Antigravity, Claude Code, ...)

Same rules as CLAUDE.md. The build spec is `docs/PRD.md`; read the relevant section before changing code.

- Contracts are **frozen**: tool names/arguments/descriptions/error codes (§6), event schema, Firestore paths and
  rules (§8), `InvoiceFields` (§5), scenario keys (§3), `policy/paygate.yaml` (§6). Change only with the whole team.
- Agents get exactly six MCP tools. Never add a tool that changes bank details or executes payments.
- Money is integer cents. IBANs are masked (`DE39…5678`) in events and logs.
- Security paths fail closed. Temperature 0 for every model call.
- Secrets only in `.env` / `sa.json`, never committed.
- If a library API differs from a PRD snippet: adapt, keep the contract, add one line to `docs/DEVIATIONS.md`.
- Run `make test` before every commit.
