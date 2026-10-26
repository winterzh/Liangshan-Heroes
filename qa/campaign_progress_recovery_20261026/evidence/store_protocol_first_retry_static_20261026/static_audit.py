"""Source-only audit. Does not launch Godot or claim GDScript compilation."""
from __future__ import annotations
import ast
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def balanced(source):
    stack, quote, escaped, comment = [], "", False, False
    for char in source:
        if comment:
            comment = char != "\n"
        elif quote:
            if escaped: escaped = False
            elif char == "\\": escaped = True
            elif char == quote: quote = ""
        elif char == "#": comment = True
        elif char in "\"'": quote = char
        elif char in "([{": stack.append(char)
        elif char in ")]}":
            if not stack or stack.pop() != {")":"(", "]":"[", "}":"{"}[char]: return False
    return not stack and not quote


def main():
    checks = []
    def check(value, label):
        checks.append({"label":label,"passed":bool(value)})
        if not value: raise AssertionError(label)
    for path in (HERE / "scripts").glob("*.gd"):
        check(balanced(path.read_text(encoding="utf-8-sig")), "lexical delimiters " + path.name)
    for path in (HERE / "tests").glob("*.gd"):
        check(balanced(path.read_text(encoding="utf-8-sig")), "lexical delimiters " + path.name)
    ast.parse(Path(__file__).read_text(encoding="utf-8"))
    check(True, "Python AST")
    code = (HERE / "scripts/steam_receipt_store.gd").read_text(encoding="utf-8-sig")
    guards = {
        "legacy inspect delegated": "if not layout.barrier: return super.inspect_recovery()",
        "legacy recover delegated": "return super.recover(plan)",
        "exact plan recheck": 'if fresh != plan: return bad("RECOVERY_PLAN_CHANGED")',
        "new protocol pending refused": 'cleanup.size() > 1 or layout.pending',
        "marker head CAS": 'head.file_sha256 != source.head_sha256',
        "live PID refusal": 'OS.is_process_running(source.claim_pid)',
        "owner bytes retained by rename": 'directory.path_join(lock.name).path_join("owner.json"),directory.path_join(name)',
        "fixed writing only renamed by live release": 'directory.path_join("writing"),directory.path_join(cleanup)',
        "unique cleanup only deleted": 'DirAccess.remove_absolute(directory.path_join(marker.cleanup))',
        "commit barrier": 'if layout.barrier: return _busy_release()',
        "stale abort proposal scope retained": '_stale_abort = scope',
        "stale abort scope rechecked": 'if scope != _stale_abort:',
        "layout enumeration stability": 'if files_after != file_names or directories_after != names: return _busy_release()',
    }
    for label, text in guards.items(): check(text in code, label)
    check('remove_absolute(directory.path_join("writing"))' not in code, "new code never deletes reusable writing")
    check('remove_absolute(directory.path_join("recovering"))' not in code, "new code never deletes reusable recovering")
    check(code.count("generate_random_bytes(16)") >= 4, "acquire, cleanup, marker and recovery get fresh nonce")
    dependencies = [
        ("original_handoff_store", "qa/campaign_progress_recovery_20261026/handoff_candidate/scripts/steam_receipt_store.gd"),
        ("unchanged_shared_snapshot_store", "scripts/run_snapshot_store.gd"),
        ("current_handoff_receipt", "qa/campaign_progress_recovery_20261026/handoff_candidate/scripts/steam_run_receipt.gd"),
        ("current_handoff_ledger", "qa/campaign_progress_recovery_20261026/handoff_candidate/scripts/steam_run_ledger.gd"),
    ]
    sources = [{"role":role,"path":path,"sha256":sha(ROOT/path)} for role,path in dependencies]
    candidates = [{"path":str(path.relative_to(HERE)).replace("\\","/"),"sha256":sha(path)}
                  for path in [HERE/"scripts/steam_receipt_store.gd",HERE/"tests/protocol_model.gd",HERE/"README.md",Path(__file__)]]
    manifest = {"schema":"steam_unique_release_candidate_v1","production_adopted":False,
                "integration_files":["scripts/steam_receipt_store.gd"],"base_dependencies":sources,"candidate_files":candidates,
                "legacy_recovery_changed":False,"campaign_cfg_or_lifecycle_release_fixed":False,
                "half_pending_reconstruction":False,"max_runs_changed":False}
    (HERE/"source_manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    audit = {"schema":"steam_unique_release_static_audit_v1","passed":True,"checks":checks,
             "candidate_files":candidates,"gdscript_compiled":False,"model_tests_executed":False,
             "native_io_exercised":False,"engine_started":False,"sdk_qualified":False,
             "integration_qualified":False,"scope":"source shape and lexical guards only"}
    (HERE/"static_audit.json").write_text(json.dumps(audit,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"passed":True,"checks":len(checks),"candidate_files":candidates,"engine_started":False},ensure_ascii=False))


if __name__ == "__main__":
    main()
