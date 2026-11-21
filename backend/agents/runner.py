"""Runner: one command at a time from Firestore `commands` (NEW -> RUNNING -> DONE/ERROR). python -m backend.agents.runner"""
import asyncio
import tempfile
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path

from google.cloud import firestore

from backend.agents import callbacks, compromised_onboarding, controller
from backend.common import config
from backend.common.events import emit
from backend.common.firestore import db
from backend.fixtures.make_invoices import OUT, build
from backend.intake.pipeline import run_intake

TITLES = {"baseline": "Act 0: today, without IBAN-Wächter", "clean": "Act 1: a clean invoice",
          "poisoned": "Act 2: a poisoned invoice", "swap": "Act 3: the same invoice, now with IBAN-Wächter",
          "insider": "Act 4: a compromised insider component", "judge": "Judge mode: your attack"}


def vendor_a2a_url() -> str | None:
    """A2A address from the vendor master (Sheets), never from invoice text. None -> INCONCLUSIVE -> HOLD."""
    try:
        import gspread
        rows = gspread.service_account(filename=config.env("GOOGLE_APPLICATION_CREDENTIALS", "sa.json")) \
            .open_by_key(config.SHEET_ID).worksheet("vendors").get_all_records()
        return next(r["a2a_url"] for r in rows if r["vendor_id"] == config.VENDOR_ID)
    except Exception as e:
        print(f"runner: vendor master unreadable ({e.__class__.__name__}); vendor callback disabled")
        return None


def new_run(scenario: str) -> tuple[str, int]:
    ref = db().document("config/runtime")

    @firestore.transactional
    def bump(tx):
        seq = ((ref.get(transaction=tx).to_dict() or {}).get("run_seq") or 0) + 1
        tx.set(ref, {"run_seq": seq, "current_run_id": f"run-{seq:04d}", "current_scenario": scenario}, merge=True)
        return seq

    seq = bump(db().transaction())
    return f"run-{seq:04d}", seq


def layers_for(scenario: str) -> dict:
    stored = (db().document("config/layers").get().to_dict()) or {}
    return {**config.DEFAULT_LAYERS, **stored}


async def handle(cmd: dict, a2a_url: str | None):
    scenario = cmd["scenario"]
    run_id, seq = new_run(scenario)
    callbacks.RUN.update(run_id=run_id, invoice_id=None)
    emit(run_id, "intake" if scenario != "baseline" else "baseline", "STEP", "INFO", TITLES[scenario], f"Run {run_id}")

    if scenario == "insider":
        await compromised_onboarding.attack(run_id)
        return
    fixture = config.FIXTURE_BY_KEY[scenario]
    if scenario == "baseline":
        from backend.baseline import automation
        await asyncio.to_thread(automation.run, run_id, OUT / f"{fixture}.pdf", fixture)
        return

    layers = layers_for(scenario)
    pdf = OUT / f"{fixture}.pdf"
    if scenario == "judge":
        pdf = build(fixture, note=cmd.get("note") or "", out_dir=Path(tempfile.mkdtemp()))
    elif not pdf.exists():
        pdf = build(fixture)
    doc, text = await asyncio.to_thread(run_intake, run_id, seq, fixture, pdf, layers, cmd.get("note"))
    callbacks.RUN["invoice_id"] = doc["invoice_id"]

    l3_off = not layers["quarantine"]
    final = await controller.run(doc["invoice_no"], a2a_url=a2a_url, raw_text=text if l3_off else None,
                                 jailbroken=layers["jailbreak_controller"])
    inv = db().document(f"invoices/{doc['invoice_id']}").get().to_dict() or {}
    status = inv.get("status", "?")
    verdict = {"HOLD": "BLOCK", "PENDING_APPROVAL": "ALLOW", "PAID": "ALLOW"}.get(status, "INFO")
    emit(run_id, "controller", "DECISION", verdict, f"Decision: {'PAY' if verdict == 'ALLOW' else status}",
         final.splitlines()[0][:200] if final else "No reply", invoice_id=doc["invoice_id"],
         amount_cents=inv.get("amount_cents"))


def main():
    a2a_url = vendor_a2a_url()
    print(f"runner: listening on commands (vendor agent: {a2a_url})")
    col = db().collection("commands")
    while True:
        new = sorted(col.where("status", "==", "NEW").stream(), key=lambda s: str(s.to_dict().get("created_at")))
        for snap in new[:1]:
            cmd = snap.to_dict()
            snap.reference.update({"status": "RUNNING"})
            try:
                if cmd.get("scenario") not in config.SCENARIO_KEYS:
                    raise ValueError(f"unknown scenario {cmd.get('scenario')!r}")
                asyncio.run(handle(cmd, a2a_url))
                snap.reference.update({"status": "DONE"})
            except Exception:
                traceback.print_exc()
                snap.reference.update({"status": "ERROR"})
        time.sleep(0.5)


if __name__ == "__main__":
    main()
