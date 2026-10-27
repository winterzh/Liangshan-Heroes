"""Isolated real-filesystem model of the host hook. Never starts Godot.

All reports/PIDs/payloads here are synthetic. These cases test rejection and
copy boundaries only; they cannot qualify a real A, native Slot decoding,
gameplay, the eight Flow processes, the 52 negatives, or the original 19 faults.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import uuid

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("daming_fixture_model_host", HERE.parents[1] / "run_daming_flow.py")
host = importlib.util.module_from_spec(spec)
spec.loader.exec_module(host)
f, p = host.fixture, host.p


def encoded(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode("utf-8")


def wrap(document, magic):
    payload = encoded(document)
    return encoded({"magic": magic, "version": "1", "app": f.APP, "owner": "1", "revision": "1",
                    "previous_sha256": f.ZERO, "payload_bytes": str(len(payload)),
                    "payload_sha256": f.digest(payload), "payload": payload.decode("utf-8")})


def setup(root, name, role="lu"):
    case = root / name
    profile, output = case / "private_profile", case / "run"
    scope = profile / "appdata/Godot/app_userdata/SYNTHETIC_DAMING_MODEL/continue/v1"
    token = "d" * 32
    slot_path = scope / f"{f.APP}/1/{f.RECORD}"
    life_path = scope / f"local_runs/{token}/{f.APP}/1/{f.RECORD}"
    stage = output / role / "save_single"
    for folder in (slot_path.parent, life_path.parent, stage):
        p.fs(folder).mkdir(parents=True, exist_ok=False)
    expected = {"batch_nonce": "a" * 32, "role_nonce": "b" * 32, "process_nonce": "c" * 32,
                "content_version": "source-v1:" + "e" * 64, "engine_sha256": "f" * 64,
                "candidate_manifest_sha256": "1" * 64, "sources_sha256": "2" * 64}
    lc = {"schema": "local_campaign_continue_lifecycle_v3", "generation": 1, "token": token,
          "context": dict(f.CONTEXT), "scope": {"owner": "", "content_version": expected["content_version"],
          "engine_sha256": expected["engine_sha256"]}, "state": "active", "victory": False,
          "progress_state": "none", "intent": {}, "progress_receipt": {}}
    life_raw = wrap(lc, "LH_LOCAL_CONTINUE_LIFECYCLE")
    binding = {"kind": "uncredited", "token": token, "receipt_sha256": f.digest(life_raw)}
    slot = {"schema": "official_continue_slot_v1", "generation": 1, "context": dict(f.CONTEXT),
            "binding": binding, "resume_paused": True, "options": {}, "session_settings": {}, "root_node": {},
            "world": {"schema": "official_world_core_preparation_v1", "content_version": expected["content_version"],
                      "engine_sha256": expected["engine_sha256"], "profile": {"schema": "official_restore_profile_v1",
                      "id": "campaign_level8_v1", "context": dict(f.CONTEXT)}, "sections": {}}}
    slot_raw = wrap(slot, "LH_CLASSIC_CONTINUE_SLOT")
    p.fs(slot_path).write_bytes(slot_raw)
    p.fs(life_path).write_bytes(life_raw)
    report = {"schema": "campaign_daming_flow_v1", "mode": "save_single", "first_role": role,
        "passed": True, "stage_completed": True, "failures": [], "checks": [{"passed": True, "label": "SYNTHETIC"}],
        "save_exit_observed": True, "exit_reason": "continue_saved", **expected,
        "identity": {"content_version": expected["content_version"], "engine_sha256": expected["engine_sha256"],
                     "source_mode": True}, "profile": str(profile), "slot_root": "user://continue/v1", "pid": 123456,
        "checkpoint": {"slot_root": "user://continue/v1", "directory": str(slot_path.parent), "generation": 1,
            "file_sha256": f.digest(slot_raw), "binding": binding, "context": dict(f.CONTEXT),
            "lifecycle": {"directory": str(life_path.parent), "token": token, "generation": 1,
                          "file_sha256": f.digest(life_raw), "document": lc}}}
    log = b"SYNTHETIC filesystem model; no Godot or actual PID.\n"
    report_path, log_path = stage / "report.json", stage / "save_single.log"
    p.fs(report_path).write_bytes(encoded(report))
    p.fs(log_path).write_bytes(log)
    step = {"pid": 123456, "exit_code": 0, "passed": True, "errors": [], "stopped_for": None,
            "case": "save_single", "first_role": role, "mode": "save_single", "process_nonce": expected["process_nonce"],
            "log_sha256": f.digest(log), "command": ["SYNTHETIC_NOT_EXECUTED"]}
    pins = {str(report_path): f.digest(encoded(report)), str(log_path): f.digest(log)}
    return dict(p=p, output=output, profile=profile, role=role, report_path=report_path, log_path=log_path,
                step=step, expected=expected, pins=pins, evidence_kind="synthetic_filesystem_model"), {
                    "scope": scope, "slot": slot_path, "life": life_path, "report": report, "slot_doc": slot, "lc_doc": lc}


def rewrite_report(args, data):
    raw = encoded(data["report"])
    p.fs(args["report_path"]).write_bytes(raw)
    args["pins"][str(args["report_path"])] = f.digest(raw)


def replace_slot(args, data, raw):
    p.fs(data["slot"]).write_bytes(raw)
    data["report"]["checkpoint"]["file_sha256"] = f.digest(raw)
    rewrite_report(args, data)


def run(root):
    p.h.identity.no_links(p.fs(root))
    p.fs(root).mkdir(parents=True, exist_ok=False)
    checks, skipped = [], []
    sources, copies = {}, []
    for source in (Path(__file__).resolve(), HERE / "fixture_freeze.py", Path(host.__file__).resolve(), Path(p.__file__).resolve()):
        raw = p.fs(source).read_bytes()
        target = root / "source_inputs" / source.relative_to(host.ROOT)
        p.fs(target.parent).mkdir(parents=True, exist_ok=True)
        with p.fs(target).open("xb") as stream:
            stream.write(raw)
        sources[str(source)] = f.digest(raw)
        copies.append({"source":str(source), "copy":str(target), "sha256":f.digest(raw), "bytes":len(raw)})
    p.h.save(p.fs(root / "source_manifest.json"), {"schema":"python_model_original_inputs_v1", "files":copies})

    def check(ok, label, detail=None):
        checks.append({"passed": bool(ok), "label": label, "detail": detail})
        if not ok:
            raise AssertionError(label)

    for role in ("lu", "shi"):
        args, data = setup(root, "valid_" + role, role)
        before = f.inventory(data["scope"], p)
        result = f.freeze(**args)
        descriptor = p.h.read(p.fs(result["path"]))
        check(descriptor["evidence_kind"] == "synthetic_filesystem_model"
              and descriptor["source_inventory_before"] == descriptor["source_inventory_after"]
              == descriptor["frozen_inventory"] == before and result["file_count"] == 2
              and result["directory_count"] == 6, role + " exact closed raw copies")
        check(not any(Path(path).is_relative_to(args["profile"]) for path in args["pins"]),
              role + " live profile not added to persistent pins")
        p.fs(data["slot"].parent / "record_0000000002.json").write_bytes(b"authorized later synthetic B")
        p.verify_pins(args["pins"])
        f.verify_frozen(p=p, output=args["output"], reference=result, pins=args["pins"])
        check(True, role + " later source gen2 cannot invalidate frozen A pins")
        try:
            f.freeze(**args)
        except RuntimeError:
            check(True, role + " later generation refuses a second A freeze")
        else:
            check(False, "second freeze must fail")

    def reject(name, mutate, wanted):
        args, data = setup(root, name)
        mutate(args, data)
        before = f.inventory(data["scope"], p)
        try:
            f.freeze(**args)
        except (RuntimeError, ValueError, UnicodeError) as error:
            check(wanted in str(error), name, str(error))
        else:
            check(False, name + " unexpectedly accepted")
        check(f.inventory(data["scope"], p) == before, name + " source remains untouched")

    reject("failed_actual_step", lambda a, d: a["step"].update(exit_code=1), "actual terminal A step")
    reject("stopped_process", lambda a, d: a["step"].update(stopped_for="timeout"), "actual terminal A step")
    reject("pid_mismatch", lambda a, d: a["step"].update(pid=123457), "actual terminal A step")
    reject("nonce_mismatch", lambda a, d: a["expected"].update(process_nonce="9" * 32), "exact process_nonce")
    reject("source_mismatch", lambda a, d: a["expected"].update(content_version="source-v1:" + "8" * 64), "exact source")
    reject("report_byte_change", lambda a, d: p.fs(a["report_path"]).write_bytes(b"{}"), "pinned original A")
    reject("extra_record", lambda a, d: p.fs(d["slot"].parent / "record_0000000002.json").write_bytes(b"extra"), "exactly two")
    reject("extra_owner", lambda a, d: p.fs(d["scope"] / f"{f.APP}/2").mkdir(), "exactly two")
    reject("empty_writing", lambda a, d: p.fs(d["slot"].parent / "writing").mkdir(), "exactly two")
    reject("pending_file", lambda a, d: p.fs(d["slot"].parent / "pending.json").write_bytes(b"pending"), "exactly two")
    reject("unknown_root", lambda a, d: p.fs(d["scope"] / "extra.json").write_bytes(b"unknown"), "exactly two")
    reject("output_collision", lambda a, d: p.fs(a["output"] / "closed_a" / a["role"]).mkdir(parents=True), "already exists")

    def changed_slot(args, data, key, value):
        data["slot_doc"][key] = value
        replace_slot(args, data, wrap(data["slot_doc"], "LH_CLASSIC_CONTINUE_SLOT"))
    reject("slot_payload_gen2", lambda a, d: changed_slot(a, d, "generation", 2), "slot header")
    reject("slot_bool_gen", lambda a, d: changed_slot(a, d, "generation", True), "slot header")
    reject("slot_wrong_context", lambda a, d: changed_slot(a, d, "context", {"mode":"campaign", "level_id":"level5", "waves":0}), "slot header")

    def bad_payload(args, data):
        value = f.strict_json(p.fs(data["slot"]).read_bytes())
        value["payload"] += " "
        replace_slot(args, data, encoded(value))
    reject("payload_hash_mismatch", bad_payload, "payload bytes/hash")

    def escaped(args, data):
        data["report"]["checkpoint"]["directory"] = str(args["output"] / "continue/v1/5088120/1")
        rewrite_report(args, data)
    reject("profile_escape", escaped, "escaped its exact private root")

    def wrong_lc(args, data):
        data["lc_doc"]["generation"] = 2
        raw = wrap(data["lc_doc"], "LH_LOCAL_CONTINUE_LIFECYCLE")
        p.fs(data["life"]).write_bytes(raw)
        cp = data["report"]["checkpoint"]
        cp["binding"]["receipt_sha256"] = cp["lifecycle"]["file_sha256"] = f.digest(raw)
        replace_slot(args, data, wrap(data["slot_doc"], "LH_CLASSIC_CONTINUE_SLOT"))
    reject("lc_gen2_disguised_as_A", wrong_lc, "actual LC3 genesis")

    args, data = setup(root, "frozen_directory_change")
    reference = f.freeze(**args)
    p.fs(args["output"] / "closed_a/lu/slot_scope/5088120/1/writing").mkdir()
    p.verify_pins(args["pins"])
    try:
        f.verify_frozen(p=p, output=args["output"], reference=reference, pins=args["pins"])
    except RuntimeError as error:
        check("exactly two" in str(error), "later empty directory addition is detected beyond file pins", str(error))
    else:
        check(False, "changed frozen directory accepted")

    args, data = setup(root, "mutation_during_copy")
    initial = f.inventory(data["scope"], p)
    original_fsync = f.os.fsync
    mutated = False
    def changed_during_flush(fd):
        nonlocal mutated
        original_fsync(fd)
        if not mutated:
            mutated = True
            p.fs(data["slot"]).write_bytes(p.fs(data["slot"]).read_bytes() + b" ")
    try:
        f.os.fsync = changed_during_flush
        try:
            f.freeze(**args)
        except RuntimeError as error:
            check("remain byte-identical" in str(error), "source mutation between reads is rejected", str(error))
        else:
            check(False, "changed source accepted")
    finally:
        f.os.fsync = original_fsync
    check(not p.fs(args["output"] / "closed_a/lu/descriptor.json").exists()
          and f.inventory(data["scope"], p) != initial, "failed copy retained without a complete descriptor")

    args, data = setup(root, "symlink_scope_entry")
    link = data["scope"] / "linked_owner"
    try:
        os.symlink(str(data["slot"].parent), str(link), target_is_directory=True)
    except OSError as error:
        skipped.append({"case":"symlink_scope_entry", "reason":repr(error)})
    else:
        try:
            f.freeze(**args)
        except (RuntimeError, ValueError) as error:
            check(True, "actual directory symlink is rejected", str(error))
        else:
            check(False, "linked scope accepted")

    if os.name == "nt":
        args, data = setup(root, "junction_scope_entry")
        link = data["scope"] / "junction_owner"
        command = ["cmd.exe", "/d", "/c", "mklink", "/J", str(link), str(data["slot"].parent)]
        completed = subprocess.run(command, capture_output=True, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        detail = {"command":command, "returncode":completed.returncode,
                  "stdout_hex":completed.stdout.hex(), "stderr_hex":completed.stderr.hex()}
        check(completed.returncode == 0 and p.fs(link).is_dir(), "actual private junction created", detail)
        try:
            f.freeze(**args)
        except (RuntimeError, ValueError) as error:
            check("reparse" in str(error).lower() or "link" in str(error).lower(),
                  "actual directory junction/reparse is rejected", str(error))
        else:
            check(False, "junction scope accepted")

    receipt = {"schema":"daming_closed_a_python_model_v1", "complete":True, "passed":all(row["passed"] for row in checks),
        "checks":checks, "actual_checks":len(checks), "skipped":skipped, "output":str(root),
        "synthetic_reports_and_pids":True, "engine_started":False, "actual_a_qualified":False,
        "native_slot_decode_qualified":False, "source_flow_chain_passed":False, "full_61_qualified":False,
        "original_19_faults_qualified":False, "sources":sources, "source_copies":copies}
    for source, sha in sources.items():
        check(p.h.sha(p.fs(source)) == sha, "executed model source unchanged", source)
    receipt["actual_checks"] = len(checks)
    p.h.save(p.fs(root / "receipt.json"), receipt)
    print(json.dumps({"output":str(root), "passed":receipt["passed"], "checks":len(checks), "skipped":skipped,
                      "receipt_sha256":p.h.sha(p.fs(root / "receipt.json")), "engine_started":False}, ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="New isolated model directory; existing output is refused")
    args = parser.parse_args()
    destination = args.output or Path(host.ROOT.anchor) / "CodexQA/daming_fixture_model" / uuid.uuid4().hex
    run(destination.absolute())
