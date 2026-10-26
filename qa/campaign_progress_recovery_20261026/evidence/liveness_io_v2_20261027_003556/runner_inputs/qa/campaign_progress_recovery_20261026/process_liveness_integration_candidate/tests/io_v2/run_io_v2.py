"""23-script liveness candidate: original 23-process I/O and two delayed-writer cases.

Default is read-only preflight. --execute is the sole engine-starting action.
Legacy stage controllers are imported unchanged; this owns explicit binding,
worker selection, the lane, and final source/native/report verification.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import time
import uuid

import binding as b

io, delayed, h, require = b.io, b.delayed, b.helper, b.require


def freeze_inputs(config, output):
    pins = dict(config["pins"])
    workers = output / "workers"
    workers.mkdir()
    for name, source in (("bootstrap.gd", b.OLD / "bootstrap.gd"),
                         ("delayed_bootstrap.gd", b.OLD / "delayed_bootstrap.gd"),
                         ("worker.gd", b.HERE / "worker.gd"),
                         ("delayed_worker.gd", b.HERE / "delayed_worker.gd")):
        target = workers / name
        h.copy_checked(io.fs_path(source), io.fs_path(target), pins[str(source)])
        b.pin(target, pins, pins[str(source)])
    # Keep the exact imported source bytes in this run, not just their hashes.
    for source_text, digest in list(pins.items()):
        source = Path(source_text)
        if source.is_relative_to(b.ROOT / "qa") or source.is_relative_to(b.ROOT / "tools"):
            if source.suffix.lower() in (".py", ".gd", ".json", ".md", ".diff", ".cs"):
                target = output / "runner_inputs" / source.relative_to(b.ROOT)
                h.copy_checked(io.fs_path(source), io.fs_path(target), digest)
                b.pin(target, pins, digest)
    return workers, pins


def profile(prefix):
    path = Path(b.ROOT.anchor) / ("CodexQA/" + prefix) / uuid.uuid4().hex[:12]
    h.identity.no_links(path)
    path.mkdir(parents=True, exist_ok=False)
    return path


def check_process_document(document, row, nonce, private, identity, mode):
    require(document.get("identity") == identity and document.get("pid") == row["pid"]
            and document.get("nonce") == nonce and document.get("profile") == str(private)
            and document.get("mode") == mode, "Actual process/candidate/engine/profile mismatch")


def run_io(config, output, workers, pins, receipt, timeout):
    pids = set()
    for mode in io.MODES:
        b.verify_pins(pins)
        nonce, private = uuid.uuid4().hex, profile("lhmio2")
        env = h.common.private_environment(private)
        stage = output / mode
        print("RUN native I/O " + mode, flush=True)
        row = io.run_stage(config["engine"], config["project"], workers, private, env, nonce, mode, stage,
                           config["points"], timeout)
        require(row["pid"] not in pids, "Independent I/O process PID reused")
        actual = h.read(stage / "prepared.json") if io.is_crash(mode) else row["report"]
        check_process_document(actual, row, nonce, private, config["identity"], mode)
        b.validate_liveness_rows(actual, private, pins)
        io.pin_stage(stage, pins)
        pids.add(row["pid"])
        receipt["stages"].append(row)
        if io.is_crash(mode):
            prepared = stage / "prepared.json"
            origin = actual
            if mode in io.TRIPLE:
                second = output / (mode + "_recover_claim_crash")
                row = io.run_stage(config["engine"], config["project"], workers, private, env, nonce,
                                   "recover_claim_crash", second, config["points"], timeout, prepared)
                require(row["pid"] not in pids, "Recrashed recovery needs an independent PID")
                actual = h.read(second / "prepared.json")
                check_process_document(actual, row, nonce, private, config["identity"], "recover_claim_crash")
                require(actual.get("origin_writer_pid") == origin["pid"]
                        and actual.get("predecessor_pid") == origin["pid"], "Second crash lineage mismatch")
                require(b.validate_liveness_rows(actual, private, pins) == 2, "Both predecessor and writer death observations required")
                io.pin_stage(second, pins)
                pids.add(row["pid"])
                receipt["stages"].append(row)
                h.save(output / ("checkpoint_%02d.json" % len(receipt["stages"])), receipt)
                prepared = second / "prepared.json"
            last = output / (mode + "_recover")
            row = io.run_stage(config["engine"], config["project"], workers, private, env, nonce,
                               "recover", last, config["points"], timeout, prepared)
            require(row["pid"] not in pids, "Recovery needs an independent PID")
            check_process_document(row["report"], row, nonce, private, config["identity"], "recover")
            require(b.validate_liveness_rows(row["report"], private, pins) == 2, "Both predecessor and writer death observations required")
            io.pin_stage(last, pins)
            pids.add(row["pid"])
            receipt["stages"].append(row)
        h.save(output / ("checkpoint_%02d.json" % len(receipt["stages"])), receipt)
    require(len(receipt["stages"]) == 23 and len(pids) == 23, "All original twenty-three processes required")
    receipt["io_passed"] = True


def run_delayed(config, output, workers, pins, receipt, timeout):
    pids = set()
    for case in ("first_after_clear", "retry_under_barrier"):
        b.verify_pins(pins)
        folder = output / case
        folder.mkdir()
        nonce, private = uuid.uuid4().hex, profile("lhmdelay2")
        print("RUN delayed writer " + case, flush=True)
        row = delayed.execute_case(config["engine"], config["project"], workers, private, nonce, case,
                                   "fixed", folder, timeout, config["delayed_points"], config["identity"])
        receipt["cases"].append(row)
        # Never call an expectation failure success; save its original controller first.
        require(row.get("complete") is True and not row.get("post_errors"), "Delayed case failed: " + case)
        for role in ("A", "B"):
            report = h.read(folder / role / "report.json")
            require(report["pid"] not in pids, "Independent delayed stage PID reused")
            pids.add(report["pid"])
            count = b.validate_liveness_rows(report, private, pins)
            require(count == (2 if role == "B" else 0), "B must prove live A before and after the stale-lock attempt")
            if role == "B":
                a_report = h.read(folder / "A/report.json")
                observations = report["liveness_observations"]
                raw = [item["result"]["liveness_detail"]["evidence"] for item in observations]
                require(all(item["target_pid"] == a_report["pid"] for item in observations)
                        and raw[0]["creation_filetime"] and raw[0]["creation_filetime"] == raw[1]["creation_filetime"],
                        "Both native observations must bind the same actual live A process identity")
        b.pin_tree(folder, pins)
        h.save(output / ("delayed_checkpoint_%02d.json" % len(receipt["cases"])), receipt)
    require(len(receipt["cases"]) == 2 and len(pids) == 4, "Both original delayed interleavings required")
    receipt["delayed_passed"] = True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-run", required=True, type=Path)
    parser.add_argument("--suite", choices=("io", "delayed", "all"), default="all")
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--wait-lane", type=int, default=0)
    args = parser.parse_args()
    require(60 <= args.timeout <= 600 and 0 <= args.wait_lane <= 86400, "Bounded timeouts required")
    config = b.preflight(args.base_run)
    count = {"io": 23, "delayed": 4, "all": 27}[args.suite]
    if not args.execute:
        print(json.dumps({"source_preflight": True, "native_started": False, "lane_acquired": False,
                          "suite": args.suite, "expected_processes": count, "scripts": 23,
                          "native_assets": len(config["manifest"]["native_assets"]), "identity": config["identity"],
                          "manifest_sha256": config["manifest_sha256"], "pinned_files": len(config["pins"])}, indent=2))
        return
    output = b.ROOT / ".godot/campaign_liveness_io_v2_20261027" / h.stamp()
    output.mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "campaign_liveness_io_v2_runner", "complete": False, "base_run": str(config["base"]),
               "suite": args.suite, "expected_processes": count, "identity": config["identity"],
               "manifest_sha256": config["manifest_sha256"], "native_assets": config["manifest"]["native_assets"],
               "source_points": config["points"], "delayed_points": config["delayed_points"], "stages": [], "cases": [],
               "synthetic_account_and_token": True, "production_qualified": False, "sdk_qualified": False,
               "production_method_overrides": 0, "gameplay_qualified": False, "power_loss_qualified": False,
               "two_ledger_concurrency_qualified": False,
               "known_gaps": ["Half-pending remains expected ENVELOPE_JSON refusal", "Legacy ownerless/recovering crash windows unchanged",
                              "Delayed B uses Store+Receipt, not a second Ledger", "No full mutation/foreign-owner refusal matrix"]}
    locked, pins = False, dict(config["pins"])
    try:
        start = notice = time.monotonic()
        while not locked:
            if not h.shared.LOCK.exists() and not io.engines():
                try:
                    with h.shared.LOCK.open("x", encoding="utf-8") as stream:
                        stream.write(str(output))
                    locked = True
                    break
                except FileExistsError:
                    pass
            require(time.monotonic() - start < args.wait_lane, "Shared engine occupied; no child started")
            if time.monotonic() - notice > 25:
                print("WAIT shared engine; no child started", flush=True)
                notice = time.monotonic()
            time.sleep(1)
        require(b.preflight(config["base"]) == config, "Frozen bindings changed while waiting for lane")
        workers, pins = freeze_inputs(config, output)
        if args.suite in ("io", "all"):
            run_io(config, output, workers, pins, receipt, args.timeout)
        if args.suite in ("delayed", "all"):
            run_delayed(config, output, workers, pins, receipt, args.timeout)
        verified_pids = [row["pid"] for row in receipt["stages"]]
        verified_pids += [row["pid"] for case in receipt["cases"] for row in case["reports"]]
        require(len(verified_pids) == count and len(set(verified_pids)) == count, "Actual selected process receipts are incomplete or reused")
        receipt["verified_processes"] = len(verified_pids)
        receipt["verified_pids"] = verified_pids
        receipt["all_selected_passed"] = True
    except BaseException as error:
        receipt["error"], receipt["traceback"] = repr(error), io.traceback.format_exc()
    finally:
        def final_identity():
            require(b.preflight(config["base"]) == config, "Final candidate/source/native bindings differ")
            b.verify_pins(pins)
        receipt["final_identity_passed"], _ = io.post_step(receipt, "final identity", final_identity)
        def lane_state():
            own = locked and h.shared.LOCK.exists() and h.shared.LOCK.read_text(encoding="utf-8") == str(output)
            return own, not io.engines()
        okay, lane = io.post_step(receipt, "read final lane ownership", lane_state)
        own, idle = lane if okay else (False, False)
        receipt["lock_ownership_confirmed"] = own
        if own and idle:
            io.post_step(receipt, "release own shared lock", h.shared.LOCK.unlink)
        okay, released = io.post_step(receipt, "confirm shared lock release", lambda: locked and not h.shared.LOCK.exists())
        receipt["lock_released"] = bool(okay and released)
        receipt["complete"] = bool(receipt.get("all_selected_passed") and receipt["final_identity_passed"]
                                   and own and idle and receipt["lock_released"] and "error" not in receipt and not receipt.get("post_errors"))
        receipt["pinned_files"] = pins
        io.persist_result(output / "receipt.json", receipt)
    print(json.dumps({"output": str(output), "complete": receipt["complete"], "error": receipt.get("error")}, ensure_ascii=False), flush=True)
    if not receipt["complete"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
