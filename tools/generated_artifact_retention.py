"""Retire superseded generated game copies after a verified newer batch.

The watcher observes existing completion receipts. Frozen SHA-bound producers
and game sources stay byte-identical; no engine, publication or player I/O.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager, ExitStack
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time
import uuid

from artifact_retirement_windows import NativeFiles, normal, freeze_tree

ROOT = Path(__file__).resolve().parents[1]
FAMILIES = ("huangnigang_production_20261020", "campaign_progress_recovery_20261026",
            "campaign_resume_rebase_20261031", "steam_candidates", "steam_integration_qa")
STAMP = re.compile(r"[0-9]{8}_[0-9]{6}_[0-9a-f]{8}\Z")


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def digest(path):
    with normal(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def member(root, name):
    if not isinstance(name, str) or not name or "\\" in name or ":" in name or any(p in ("", ".", "..") for p in name.split("/")):
        raise ValueError("Invalid manifest member")
    target = Path(os.path.abspath(root / name))
    if not target.is_relative_to(root):
        raise ValueError("Manifest path escapes root")
    return normal(target)


@contextmanager
def exclusive_lock(path):
    import msvcrt
    normal(path.parent)
    if path.exists():
        normal(path)
    with path.open("a+b") as stream:
        stream.seek(0, 2)
        if stream.tell() == 0:
            stream.write(b"0")
            stream.flush()
        stream.seek(0)
        msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
        try:
            yield
        finally:
            stream.seek(0)
            msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, 1)


@contextmanager
def native_lease(root):
    """Reserve the lane only for mutation, after the read-only inventory."""
    path = root / ".godot/redraw_rejection_source.lock"
    owner = "artifact-retention:" + str(os.getpid()) + ":" + uuid.uuid4().hex
    with path.open("x", encoding="utf-8") as stream:
        stream.write(owner)
    try:
        yield owner
    finally:
        if path.exists() and path.read_text(encoding="utf-8") == owner:
            path.unlink()


def successful_receipt(run, family):
    """Cheap selection only. Full keeper verification precedes any deletion."""
    try:
        if family.startswith("steam_"):
            receipt_path = run / "receipt.json"
            receipt = read(receipt_path)
            if receipt.get("complete") is True:
                if family == "steam_candidates" and not receipt.get("archive", {}).get("passed"):
                    return None
                return receipt_path
            return None
        preparation = read(run / "preparation.json")
        if preparation.get("complete") is not True or preparation.get("legacy_overlays_from_head"):
            return None
        if not (run / "generation.json").is_file():
            return None
        for path in sorted(run.glob("import*/receipt.json"), reverse=True):
            proof = read(path)
            import_passed = (proof.get("phase") == "import" or
                             (proof.get("cold_import_qualified") is True
                              and proof.get("source_and_generated_postchecks") is True
                              and proof.get("children_gone") is True))
            if (proof.get("complete") is True and import_passed
                    and proof.get("lock_released") is True
                    and Path(proof.get("project", "")) == run / "project"):
                return path
    except (OSError, ValueError, TypeError):
        return None
    return None


def choose_current(root, family):
    base = root / ".godot" / family
    if not base.exists():
        return None
    normal(base)
    for run in sorted(base.iterdir(), reverse=True):
        if STAMP.fullmatch(run.name) and run.is_dir():
            normal(run)
            receipt = successful_receipt(run, family)
            if receipt is not None:
                return run, receipt
    return None


def verify_rows(base, rows):
    seen = set()
    for row in rows:
        name = row["path"]
        if name.casefold() in seen:
            raise ValueError("Duplicate manifest member")
        seen.add(name.casefold())
        path = member(base, name)
        if (("bytes" in row and path.stat().st_size != row["bytes"])
                or digest(path) != row["sha256"]):
            raise ValueError("Keeper content changed: " + str(path))


def verify_keeper(run, family, receipt_path, verify=True):
    if successful_receipt(run, family) != receipt_path:
        raise ValueError("Successful completion changed")
    proof = read(receipt_path)
    if family == "steam_candidates":
        archive = proof["archive"]
        if verify and digest(member(run, archive["path"])) != archive["sha256"]:
            raise ValueError("Current Steam candidate ZIP changed")
        # An earlier approved cleanup may already have removed expanded binaries.
        # The unchanged ZIP is the complete keeper; validate every remaining copy.
        members = {row["path"]: row for row in archive["members"]}
        if any(members.get(row["path"], {}).get("sha256") != row["sha256"] for row in proof["outputs"]):
            raise ValueError("ZIP receipt does not cover the runtime outputs")
        existing = [row for row in proof["outputs"] if (run / "windows" / row["path"]).exists()]
        if verify:
            verify_rows(run / "windows", existing)
        return [receipt_path, member(run, archive["path"]),
                *[member(run / "windows", row["path"]) for row in existing]]
    project = normal(run / "project")
    if family == "steam_integration_qa":
        if verify:
            verify_rows(project, proof["source_files"])
        return [receipt_path]
    preparation = read(run / "preparation.json")
    if Path(preparation["project"]) != project:
        raise ValueError("Keeper preparation points elsewhere")
    generation = read(run / "generation.json")
    if verify:
        verify_rows(project, generation["identity"]["files"])
        verify_rows(project, [generation["derived"]])
    return [receipt_path, run / "preparation.json", run / "generation.json"]


def dependency_pins(root):
    """The paused resume candidate still needs its own baseline and UID source."""
    pins = set()
    path = root / "qa/campaign_resume_rebase_20261031/overlay.json"
    if path.is_file():
        contract = read(normal(path))
        for key in ("baseline_run", "legacy_run"):
            value = contract.get(key)
            if value:
                pinned = member(root, value)
                if pinned.parent.parent != root / ".godot" or pinned.parent.name not in FAMILIES:
                    raise ValueError("Invalid current development dependency pin")
                pins.add(pinned)
    extra = root / ".godot/artifact_retention/pins.json"
    if extra.exists():
        for value in read(normal(extra)).get("runs", []):
            pinned = member(root, value)
            if pinned.parent.parent != root / ".godot" or pinned.parent.name not in FAMILIES:
                raise ValueError("Comparison pin must be an owned generated run")
            pins.add(pinned)
    return pins


def payloads(run, family):
    targets = []
    for name in ("project", "windows", "probe_host", "profile"):
        path = run / name
        if path.exists():
            targets.append(path)
    if family == "steam_candidates":
        archive = run / "LiangshanHeroes_Steam_candidate.zip"
        if archive.exists():
            targets.append(archive)
    # Retire whole old runtime copies, retaining their reports, logs and PNGs.
    for child in run.iterdir():
        if child.is_dir() and child.name.startswith("export__"):
            runtime = child / "runtime"
            if runtime.exists():
                targets.append(runtime)
    return targets


def candidates(root, family, current, pins):
    result = []
    for run in sorted(current.parent.iterdir()):
        if (not STAMP.fullmatch(run.name) or run.name >= current.name
                or run in pins or not run.is_dir()):
            continue
        normal(run)
        try:
            marker = read(run / ("receipt.json" if family.startswith("steam_") else "preparation.json"))
        except (OSError, ValueError):
            continue
        # Do not retire a partially prepared or still-writing project.
        if marker.get("complete") is not True:
            continue
        result.extend(payloads(run, family))
    return result


def safe_target(root, target, keepers, pins):
    target = normal(target)
    relative = target.relative_to(root / ".godot")
    if (len(relative.parts) < 3 or relative.parts[0] not in FAMILIES
            or not STAMP.fullmatch(relative.parts[1])):
        raise ValueError("Outside the explicit generated-copy allowlist")
    run = root / ".godot" / relative.parts[0] / relative.parts[1]
    if run in keepers or run in pins or target not in payloads(run, relative.parts[0]):
        raise ValueError("Current/dependency/non-payload target refused")
    return target


def retire(root=ROOT, apply=False):
    root = normal(root)
    state = root / ".godot/artifact_retention"
    if not state.exists():
        normal(state.parent)
        state.mkdir()
    normal(state)
    with exclusive_lock(state / "cleanup.lock"), ExitStack() as keep_open:
        if (root / ".godot/redraw_rejection_source.lock").exists():
            raise RuntimeError("Shared native lane busy; no peer is stopped")
        pins = dependency_pins(root)
        native = NativeFiles()
        selected, targets = {}, []
        for family in FAMILIES:
            choice = choose_current(root, family)
            if choice is None:
                continue
            run, receipt = choice
            files = verify_keeper(run, family, receipt, verify=False)
            for path in files:
                keep_open.enter_context(native.handle(normal(path), pin=True))
            # Verify after acquiring immutable keeper handles as well.
            verify_keeper(run, family, receipt)
            selected[family] = (run, receipt)
            targets.extend(candidates(root, family, run, pins))
        keepers = {run for run, _ in selected.values()}
        plan, issues = [], []
        for target in targets:
            target = safe_target(root, target, keepers, pins)
            try:
                if target.is_dir():
                    files, directories = freeze_tree(target, native)
                else:
                    files, directories = [(target, native.snapshot(target))], []
                plan.append((target, files, directories))
            except (OSError, ValueError) as exc:
                issues.append({"target": str(target), "error": str(exc)})
        result = {"schema": "generated_artifact_retention_v1", "time": time.time(), "applied": apply,
                  "keepers": {family: str(run) for family, (run, _) in selected.items()},
                  "dependency_pins": sorted(map(str, pins)), "planned_targets": len(plan),
                  "planned_files": sum(len(files) for _, files, _ in plan),
                  "planned_bytes": sum(identity[3] for _, files, _ in plan for _, identity in files),
                  "deleted_files": 0, "deleted_bytes": 0, "freed_allocation_bytes": 0,
                  "issues": issues, "targets": [], "engines_started": 0}
        if not apply:
            result["targets"] = [str(target) for target, _, _ in plan]
            return result
        if not plan:
            result["keepers_verified_after"] = True
            return result  # Preserve the previous nonempty deletion receipt.
        # Freeze the exact reviewed targets and file identities before mutation.
        plan_path = state / "plan.jsonl"
        with plan_path.open("w", encoding="utf-8") as stream:
            for target, files, _ in plan:
                for path, identity in files:
                    stream.write(json.dumps({"target": str(target), "path": str(path), "identity": identity}) + "\n")
        save(state / "receipt.json", result)
        with native_lease(root) as owner, (state / "deleted.jsonl").open("w", encoding="utf-8", buffering=1) as journal:
            for target, files, directories in plan:
                safe_target(root, target, keepers, dependency_pins(root))
                if (root / ".godot/redraw_rejection_source.lock").read_text(encoding="utf-8") != owner:
                    result["issues"].append({"target": str(target), "error": "owned cleanup lease lost"})
                    break
                for path, identity in files:
                    if result["deleted_files"] % 128 == 0 and (root / ".godot/redraw_rejection_source.lock").read_text(encoding="utf-8") != owner:
                        raise RuntimeError("Owned cleanup lease lost; no peer is stopped")
                    try:
                        size, allocation = native.delete(path, identity)
                        result["deleted_files"] += 1
                        result["deleted_bytes"] += size
                        result["freed_allocation_bytes"] += allocation
                        journal.write(json.dumps({"path": str(path), "bytes": size, "allocation": allocation}) + "\n")
                    except (OSError, ValueError) as exc:
                        result["issues"].append({"path": str(path), "error": str(exc)})
                for directory in directories:
                    try:
                        normal(directory)
                        directory.rmdir()
                    except OSError:
                        pass
                result["targets"].append({"path": str(target), "removed": not target.exists()})
                save(state / "receipt.json", result)
                print(json.dumps({"retired": str(target), "freed_GiB": round(result["freed_allocation_bytes"] / 2**30, 2)}), flush=True)
        for family, (run, receipt) in selected.items():
            verify_keeper(run, family, receipt)
        result["keepers_verified_after"] = True
        result["journal"] = str(state / "deleted.jsonl")
        save(state / "receipt.json", result)
        save(state / "completion_signature.json", completion_signature(root))
        return result


def completion_signature(root=ROOT):
    result = []
    for family in FAMILIES:
        choice = choose_current(root, family)
        if choice is not None:
            run, receipt = choice
            result.append([family, run.name, receipt.stat().st_mtime_ns])
    return result


def watch(root=ROOT, interval=60):
    """Per-user background watcher; quiet while no successful version changes."""
    state = root / ".godot/artifact_retention"
    state.mkdir(exist_ok=True)
    with exclusive_lock(state / "watcher.lock"):
        save(state / "watcher.json", {"pid": os.getpid(), "started": time.time(), "interval": interval,
                                       "script": str(Path(__file__)), "python": sys.executable})
        signature_path = state / "completion_signature.json"
        signature = read(signature_path) if signature_path.exists() else None
        save(state / "watcher_status.json", {"time": time.time(), "status": "watching", "signature": signature})
        while True:
            try:
                latest = completion_signature(root)
                if latest != signature and not (root / ".godot/redraw_rejection_source.lock").exists():
                    # One bounded pass per changed completed family; errors retry later.
                    result = retire(root, apply=True)
                    signature = latest if not result["issues"] else None
                    save(state / "watcher_status.json", {"time": time.time(), "signature": latest,
                         "deleted_files": result["deleted_files"], "issues": result["issues"]})
            except (OSError, ValueError, RuntimeError, KeyError) as exc:
                save(state / "watcher_status.json", {"time": time.time(), "error": str(exc)})
            time.sleep(interval)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--watch", action="store_true")
    args = parser.parse_args()
    if args.watch:
        watch()
    else:
        print(json.dumps(retire(apply=args.apply), ensure_ascii=False, indent=2))
