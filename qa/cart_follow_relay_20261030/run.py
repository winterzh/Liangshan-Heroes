"""Run only empty-cart land following and same-cart wheel-phase relay in a frozen source project.

Uses the existing production freezer/import command, process ownership guard and
private four-root profile. Does not export, test all chapters or publish Steam.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools"))
spec = importlib.util.spec_from_file_location("transport_batch", ROOT / "qa/huangnigang_production_20261020/run_batch.py")
batch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(batch)


def sha(path):
    with Path(path).open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepared", type=Path, required=True)
    parser.add_argument("--wait-lane", type=int, default=60)
    args = parser.parse_args()
    run = args.prepared.resolve()
    preparation = batch.read(run / "preparation.json")
    assert preparation["complete"], "Unfinished freeze cannot qualify"
    generation = batch.read(run / "generation.json")
    project = Path(preparation["project"])
    output = run / ("cart_follow_relay_" + time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8])
    output.mkdir()
    receipt = {"complete": False, "steps": [], "source_head": preparation["source_head"],
               "execution_kind": "frozen_source_project", "prepared_run": str(run),
               "source_sha256": generation["identity"]["source_sha256"],
               "full_regression_run": False, "steam_updated": False, "worker": "probe.gd",
               "runner_sha256": sha(Path(__file__))}
    locked = False
    try:
        waiting_since = time.monotonic()
        while batch.running() or batch.shared.LOCK.exists():
            if time.monotonic() - waiting_since >= args.wait_lane:
                raise RuntimeError("Shared engine lane is occupied")
            time.sleep(0.5)
        receipt["lane_wait_seconds"] = round(time.monotonic() - waiting_since, 3)
        with batch.shared.LOCK.open("x", encoding="utf-8") as lock:
            lock.write(str(output))
        locked = True
        assert not batch.running()
        # Freeze the actual external driver too. Old receipts are never reused
        # as this candidate's behavior/visual pass.
        harness = output / "harness"
        harness.mkdir()
        originals = [HERE / "probe.gd", HERE / "bootstrap.gd",
                     ROOT / "qa/huangnigang_production_20261020/tests/base.gd"]
        receipt["qa_inputs"] = []
        for source in originals:
            dest = harness / source.name
            batch.copy_checked(source, dest)
            receipt["qa_inputs"].append({"path": str(source.relative_to(ROOT)), "sha256": sha(source)})
        profile, env = batch.private_env(output)
        receipt["profile"] = str(profile)
        env.update(HG_OUTPUT_ROOT=str(output), HG_REPORT=str(output / "report.json"),
                   HG_WORKER=str(harness / "probe.gd"), HG_WORKER_SHA=sha(harness / "probe.gd"))
        engine = batch.shared.resolve_godot(None)
        receipt["engine_sha256"] = sha(engine)
        # The worker obtains the actual full source identity through the
        # production provider. This is a source check, not an exported-PCK claim.
        batch.common.process_step(engine, project, env, output, "cart_follow_relay",
                                  ["--max-fps", "60", "--script", str(harness / "bootstrap.gd")],
                                  900, "gl_compatibility", batch.running, receipt["steps"])
        report = batch.read(output / "report.json")
        assert report["passed"] and not report["failures"]
        actual = report["trusted_identity"]
        assert actual["source_mode"] and actual["content_version"] == "source-v1:" + generation["identity"]["source_sha256"]
        assert batch.identity.snapshot(ROOT) == batch.read(run / "root_source.json"), "Production source changed"
        batch.identity.verify_generated(project, generation)
        assert all(sha(ROOT / row["path"]) == row["sha256"] for row in receipt["qa_inputs"])
        assert all(sha(output / row["path"]) == row["sha256"] for row in report["screenshots"])
        receipt.update(complete=True, checks=len(report["checks"]), screenshot_count=len(report["screenshots"]),
                       report_sha256=sha(output / "report.json"), source_unchanged=True,
                       original_game_saves_used=False, children_gone=not batch.running())
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        receipt["lock_released"] = bool(locked and batch.common.release_owned_lock(
            batch.shared.LOCK, output, receipt, batch.running()))
        batch.save(output / "receipt.json", receipt)
    print(json.dumps({"output": str(output), **{key: receipt.get(key) for key in
                     ["complete", "checks", "screenshot_count", "error", "lock_released"]}}, ensure_ascii=False))
    if not receipt["complete"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
