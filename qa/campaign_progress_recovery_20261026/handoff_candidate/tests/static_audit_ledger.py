"""Source-only audit for the three owned ledger candidates; never launches Godot."""
from __future__ import annotations

import ast
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
CANDIDATE = Path(__file__).resolve().parents[1]
NAMES = ("steam_run_receipt.gd", "steam_receipt_store.gd", "steam_run_ledger.gd")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def method(source: str, name: str) -> str:
    start = re.search(rf"^func {re.escape(name)}\(", source, re.M)
    if start is None:
        raise AssertionError(name)
    following = re.search(r"^func ", source[start.end():], re.M)
    return source[start.start():start.end() + following.start()] if following else source[start.start():]


def delimiters(source: str) -> bool:
    stack: list[str] = []
    quote = ""
    escaped = False
    comment = False
    for char in source:
        if comment:
            comment = char != "\n"
            continue
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = ""
            continue
        if char == "#":
            comment = True
        elif char in "\"'":
            quote = char
        elif char in "([{":
            stack.append(char)
        elif char in ")]}":
            if not stack or stack.pop() != {')': '(', ']': '[', '}': '{'}[char]:
                return False
    return not stack and not quote


def main() -> None:
    checks: list[dict] = []

    def check(ok: bool, label: str) -> None:
        checks.append({"label": label, "passed": bool(ok)})
        if not ok:
            raise AssertionError(label)

    manifest = json.loads((CANDIDATE / "source_manifest_steam_ledger.json").read_text(encoding="utf-8"))
    for row in manifest["files"]:
        check(digest(ROOT / row["production_base"]) == row["production_base_sha256"], "production unchanged " + row["runtime_path"])
        check(digest(ROOT / row["candidate_path"]) == row["candidate_sha256"], "candidate pin " + row["runtime_path"])
    for name in NAMES:
        text = (CANDIDATE / "scripts" / name).read_text(encoding="utf-8-sig")
        check(delimiters(text), "balanced lexical delimiters " + name)
        functions = re.findall(r"^func (\w+)\(", text, re.M)
        check(len(functions) == len(set(functions)), "unique top-level methods " + name)
    model = (CANDIDATE / "scripts/steam_run_receipt.gd").read_text(encoding="utf-8-sig")
    ledger = (CANDIDATE / "scripts/steam_run_ledger.gd").read_text(encoding="utf-8-sig")
    store = (CANDIDATE / "scripts/steam_receipt_store.gd").read_text(encoding="utf-8-sig")
    check('const VERSION := 3' in model and 'const LEGACY_VERSION := 2' in model, "separate v2/v3 model versions")
    check('normalized.version = int(value.version)' in method(model, '_validate'), "reader preserves input version")
    check('prepare_upgrade' not in method(store, '_validate_document'), "store validator never upgrades")
    check('legacy_unknown' in method(model, 'prepare_upgrade'), "explicit upgrade never guesses terminal source")
    handoff = method(model, 'prepare_campaign_handoff')
    check(handoff.count('_propose(next)') == 1 and handoff.count('evaluator.settle(') == 1, "single handoff proposal and settlement reduction")
    check('return campaign_handoff_proof(handoff)' in handoff, "terminal path uses precise proof")
    check('terminal_reason != "settled"' in method(model, 'campaign_handoff_proof'), "proof rejects invalidated and legacy terminal")
    check('next.correction_epoch += 1' in method(model, 'prepare_server_invalidation'), "invalidation advances persistent epoch")
    check('next.correction_epoch' not in method(model, 'prepare_server_correction'), "correction never resets epoch")
    fields = ast.literal_eval(re.search(r'^const HANDOFF_FIELDS := (\[.*\])$', model, re.M).group(1))
    check(len(fields) == 12 and len(set(fields)) == 12, "twelve fixed handoff fields")
    check('retry_owned_commit' in method(ledger, '_drive_pending'), "retained retry uses original store proposal")
    check('prepare_campaign_handoff' not in method(ledger, '_drive_pending'), "retry does not reprepare reward")
    check('generate_random_bytes' not in method(ledger, '_drive_pending'), "retry cannot replace token")
    check('_pending.model_committed' in method(ledger, '_drive_pending'), "model commit is stage guarded")
    check('OWNED_RELEASE_HEAD_CHANGED' in store and 'OWNED_RELEASE_DIRECTORY_CHANGED' in store, "partial release verifies retained ownership")
    check('CAMPAIGN_LEDGER_MISSING' in method(ledger, 'retry_open'), "required existing ledger cannot seed after recovery")
    check('_open_scope.initial_stats' in method(ledger, 'retry_open'), "open retry preserves original seed")
    check('_pending.kind != "handoff"' in method(ledger, 'retry_campaign_handoff'), "handoff retry refuses other pending")
    check('checked.handoff != _pending.handoff' in method(ledger, 'retry_campaign_handoff'), "handoff retry refuses changed descriptor")
    proof = method(ledger, 'campaign_handoff_proof')
    expected = ['schema', 'owner', 'token', 'context', 'intent_sha256', 'descriptor_sha256', 'correction_epoch', 'ledger_document_generation', 'ledger_file_sha256']
    body = proof.split('var proof :=', 1)[1].split('\n\treturn', 1)[0]
    check(re.findall(r'"([a-z_0-9]+)"\s*:', body) == expected, "nine exact proof fields in declared order")
    report = {"schema": "steam_ledger_source_audit_v1", "passed": True, "checks": checks,
              "source_manifest_sha256": digest(CANDIDATE / "source_manifest_steam_ledger.json"),
              "gdscript_compiled": False, "pure_model_tests_executed": False,
              "native_store_exercised": False, "sdk_exercised": False}
    (CANDIDATE / "static_audit_steam_ledger.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": True, "checks": len(checks), "engine_started": False}))


if __name__ == "__main__":
    main()
