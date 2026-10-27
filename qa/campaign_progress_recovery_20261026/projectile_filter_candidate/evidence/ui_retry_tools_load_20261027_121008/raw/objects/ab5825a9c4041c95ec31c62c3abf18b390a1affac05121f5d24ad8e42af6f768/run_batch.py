"""Run scoped Huangnigang acceptance against an immutable private production copy.

All engine work owns the existing shared lock. Cache, exports and raw run
evidence stay under .godot; isolated saves use the same-drive CodexQA short path.
This file never publishes or touches player saves.
Every command creates a distinct receipt, including failures.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools"))
import run_character_art_qa as common

shared, running = common.load_helpers(ROOT)
spec = importlib.util.spec_from_file_location(
    "hng_build_identity", ROOT / "tools/contracts/run_content_identity_20260907/build_identity.py"
)
identity = importlib.util.module_from_spec(spec)
spec.loader.exec_module(identity)


def sha(path):
    with Path(path).open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def save(path, value):
    with Path(path).open("x", encoding="utf-8") as handle:
        handle.write(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def stamp():
    return time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8]


def copy_checked(source, destination, expected=None):
    source, destination = Path(source), Path(destination)
    identity.no_links(source)
    identity.no_links(destination)
    expected = expected or sha(source)
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)
    if sha(destination) != expected or sha(source) != expected:
        raise RuntimeError("Copy changed: " + str(source))


def prepare(args):
    run = ROOT / ".godot/huangnigang_production_20261020" / stamp()
    run.mkdir(parents=True)
    project = run / "project"
    project.mkdir()
    receipt = {"complete": False, "project": str(project), "steps": [],
               "runner_sha256": sha(__file__), "source_head": subprocess.check_output(
                   ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()}
    try:
        source = identity.snapshot(ROOT)
        save(run / "root_source.json", source)
        for name, present in source["directories"].items():
            if present and not name.startswith("@file/"):
                (project / name).mkdir(parents=True, exist_ok=True)
        for row in source["files"]:
            copy_checked(ROOT / row["path"], project / row["path"], row["sha256"])
        if args.legacy:
            allowed = {"scripts/levels/level1_huangnigang.gd",
                       "scripts/levels/level1_huangnigang_short.gd",
                       "scripts/huangnigang_transport.gd",
                       "scripts/run_campaign_level_state.gd",
                       "scripts/run_official_restore_profile.gd",
                       "scripts/run_level1_world_factory.gd",
                       "scripts/run_unit_graph.gd", "scripts/run_unit_state.gd",
                       "scripts/run_battle_world_core.gd",
                       "scripts/localization.gd",
                       "scripts/hud.gd", "scripts/battle.gd",
                       "assets/localization/catalog.json"}
            changed = subprocess.check_output(
                ["git", "diff", "--name-only", "-z", receipt["source_head"]], cwd=ROOT).decode("utf-8").split("\0")
            canonical = {row["path"] for row in source["files"]}
            overlays = []
            for name in sorted(set(changed) & canonical):
                if name not in allowed:
                    raise RuntimeError("Unreviewed legacy runtime overlay: " + name)
                raw = subprocess.check_output(["git", "show", receipt["source_head"] + ":" + name], cwd=ROOT)
                (project / name).write_bytes(raw)
                overlays.append({"path": name, "sha256": sha(project / name)})
            if not overlays:
                raise RuntimeError("Legacy fixture requires actual changed production inputs")
            receipt["legacy_overlays_from_head"] = overlays
        receipt["native_dependencies"] = shared.install_native(project)
        receipt["identity_seed"] = identity.seed(project)
        # Cache-only copies; no prior runtime, source or pass result is reused.
        seed = ROOT / ".godot/imported"
        cache = project / ".godot/imported"
        cache.mkdir(parents=True, exist_ok=True)
        copied, size = 0, 0
        for source_cache in sorted(seed.iterdir()):
            if source_cache.is_file():
                copy_checked(source_cache, cache / source_cache.name)
                copied += 1
                size += source_cache.stat().st_size
        receipt["cache_seed"] = {"path": str(seed), "files": copied, "bytes": size,
                                 "qualification_reused": False}
        if identity.snapshot(ROOT) != source:
            raise RuntimeError("Production changed during source freeze")
        save(run / "preimport_source.json", identity.snapshot(project))
        receipt.update(complete=True, source_files=len(source["files"]),
                       source_bytes=source["total_bytes"])
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        save(run / "preparation.json", receipt)
    print(json.dumps({"run": str(run), **{k: receipt.get(k) for k in
          ("complete", "error", "source_files", "source_bytes", "cache_seed")}}, ensure_ascii=False))
    if not receipt["complete"]:
        raise SystemExit(1)


def private_env(output):
    # A slot's lifecycle journal adds several nested directories. Keep the
    # isolated user-data root short on Windows without changing system policy.
    profile = Path(ROOT.anchor) / "CodexQA/hngp" / uuid.uuid4().hex[:12]
    identity.no_links(profile)
    profile.mkdir(parents=True, exist_ok=False)
    env = common.private_environment(profile)
    for key in list(env):
        if key.startswith("HG_"):
            env.pop(key)
    return profile, env


def assert_runtime_current(run):
    preparation = read(run / "preparation.json")
    if not preparation["complete"]:
        raise RuntimeError("Preparation did not complete")
    # A genuine baseline fixture remains useful after the current feature is
    # repaired. Its own pre-import/generated manifest remains strictly pinned.
    if not preparation.get("legacy_overlays_from_head") and identity.snapshot(ROOT) != read(run / "root_source.json"):
        raise RuntimeError("Production source changed: freeze a new candidate")
    return Path(preparation["project"])


def qa_copy(output):
    target = output / "qa"
    target.mkdir()
    bindings = {}
    for path in sorted((HERE / "tests").glob("*.gd")):
        copy_checked(path, target / path.name)
        if path.name != "bootstrap.gd":
            bindings[path.name] = sha(path)
    save(target / "bindings.json", bindings)
    return target


def restore_fixture(profile, fixture, producer, namespace, fixture_kind):
    report = read(producer)
    rows = report.get("empty_fixture_files", []) if fixture_kind == "empty" else report.get(
        "carried_fixture_files", report.get("copied_fixture_files", []))
    if len(rows) < 2:
        raise RuntimeError("Committed slot journal and lifecycle files required")
    if namespace not in ("hg_transport_world", "hg_legacy3"):
        raise RuntimeError("Unknown private fixture namespace")
    target = profile / "appdata/Godot/app_userdata/水浒英雄传：八幕战役" / namespace
    if not target.resolve().is_relative_to(profile.resolve()):
        raise RuntimeError("Fixture target escapes private profile")
    seen = set()
    for row in rows:
        name = Path(row["path"])
        if (name.is_absolute() or ".." in name.parts or name.suffix != ".json"
                or str(name).lower() in seen):
            raise RuntimeError("Unsafe fixture name")
        seen.add(str(name).lower())
        source = fixture / name
        if not source.resolve().is_relative_to(fixture.resolve()):
            raise RuntimeError("Fixture escapes source")
        copy_checked(source, target / name, row["sha256"])
    return rows


def checked_export(args, project, run, receipt):
    exported = read(args.export_receipt)
    if (not exported["complete"] or exported.get("phase") != "export"
            or Path(exported["project"]).resolve() != project.resolve()
            or exported.get("source_sha256") !=
            read(run / "generation.json")["identity"]["source_sha256"]):
        raise RuntimeError("Export is incomplete or belongs to another frozen source")
    receipt["export_receipt"] = {"path": str(args.export_receipt.resolve()),
                                 "sha256": sha(args.export_receipt)}
    runtime = Path(exported["runtime"])
    for row in exported["runtime_files"]:
        if sha(runtime / row["path"]) != row["sha256"]:
            raise RuntimeError("Export runtime changed")
    return exported, runtime


def compiled_loader(run, engine, exported, runtime):
    # The stock release template ignores --script. Use the unchanged editor
    # binary only for compiled-PCK instrumentation, never as release-EXE proof.
    folder = run / "compiled_loader"
    identity.no_links(folder)
    folder.mkdir(exist_ok=True)
    rows = [{"path": "GodotCompiledLoader.exe", "sha256": sha(engine)}]
    rows += [row for row in exported["runtime_files"]
             if Path(row["path"]).suffix.lower() not in (".exe", ".pck")]
    for row in rows:
        target = folder / row["path"]
        if target.exists():
            if sha(target) != row["sha256"]:
                raise RuntimeError("Compiled-PCK loader changed: " + str(target))
        else:
            source = engine if row["path"] == "GodotCompiledLoader.exe" else runtime / row["path"]
            copy_checked(source, target, row["sha256"])
    return folder / "GodotCompiledLoader.exe", rows


def execute(args):
    run = args.run.resolve()
    identity.no_links(run)
    output = run / (args.command + "_" + (args.phase or "") + "_" + stamp())
    output.mkdir()
    receipt = {"complete": False, "phase": args.command, "worker": args.phase,
               "steps": [], "runner_sha256": sha(__file__)}
    owner = str(output)
    locked = False
    try:
        waiting_since = time.monotonic()
        last_wait_notice = waiting_since - 25
        while not locked:
            if not shared.LOCK.exists() and not running():
                try:
                    with shared.LOCK.open("x", encoding="utf-8") as lock:
                        lock.write(owner)
                    locked = True
                    break
                except FileExistsError:
                    pass
            if time.monotonic() - waiting_since >= args.wait_lane:
                raise RuntimeError("Shared engine lane occupied; no child started")
            if time.monotonic() - last_wait_notice >= 25:
                print("WAIT shared engine lane; no child started", flush=True)
                last_wait_notice = time.monotonic()
            time.sleep(1)
        receipt["lane_wait_seconds"] = round(time.monotonic() - waiting_since, 3)
        if running():
            raise RuntimeError("Engine appeared before child launch")
        # Reserve the idle lane before hashing the large source tree, so another
        # cooperating task cannot start between preflight and our child launch.
        project = assert_runtime_current(run)
        receipt["project"] = str(project)
        engine = shared.resolve_godot(None)
        receipt["engine_sha256"] = sha(engine)
        profile, env = private_env(output)
        receipt["profile"] = str(profile)
        if args.command == "import":
            if (run / "generation.json").exists():
                raise RuntimeError("Already imported/generated; do not repeat")
            if identity.snapshot(project) != read(run / "preimport_source.json"):
                raise RuntimeError("Private source changed before import")
            common.process_step(engine, project, env, output, "import",
                                ["--headless", "--editor", "--import", "--quit"],
                                900, "gl_compatibility", running, receipt["steps"])
            generated = identity.generate(project)
            save(run / "generation.json", generated)
            save(run / "expected_identity.json", {k: v for k, v in generated["identity"].items()
                                                   if k not in ("files", "directories")})
        elif args.command == "export":
            generation = read(run / "generation.json")
            identity.verify_generated(project, generation)
            receipt["source_sha256"] = generation["identity"]["source_sha256"]
            runtime = output / "runtime"
            runtime.mkdir()
            pck = runtime / "LiangshanHeroes.pck"
            common.process_step(engine, project, env, output, "export",
                                ["--headless", "--editor", "--export-pack", "Windows Steam", str(pck)],
                                900, "gl_compatibility", running, receipt["steps"])
            template = Path(os.environ["APPDATA"]) / "Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe"
            copy_checked(template, runtime / "LiangshanHeroes.exe")
            shared.install_native(runtime)
            for name, manifest in shared.native_dependencies().items():
                for row in manifest["files"]:
                    source = ROOT / "vendor" / name / row["path"]
                    if source.suffix.lower() == ".dll":
                        copy_checked(source, runtime / source.name, row["sha256"])
            receipt["runtime"] = str(runtime)
            receipt["runtime_files"] = [{"path": str(path.relative_to(runtime)), "sha256": sha(path),
                                         "bytes": path.stat().st_size}
                                        for path in sorted(runtime.rglob("*")) if path.is_file()]
        elif args.command == "release":
            identity.verify_generated(project, read(run / "generation.json"))
            _, runtime = checked_export(args, project, run, receipt)
            exe = runtime / "LiangshanHeroes.exe"
            env["LEVEL"] = "1"
            receipt["execution_kind"] = "original_release_gui"
            receipt["release_exe_sha256"] = sha(exe)
            spec_release = importlib.util.spec_from_file_location(
                "hng_release_step", ROOT / "qa/wu_yong_layered_full_pack_20261019/release_step.py")
            release = importlib.util.module_from_spec(spec_release)
            spec_release.loader.exec_module(release)
            release.run_release_step(exe, runtime, env, output, "release_gui",
                                     ["--resolution", "1280x720", "--position", "80,80"],
                                     args.timeout, common, running, receipt["steps"])
            receipt["ui_acceptance_recorded_separately"] = True
        elif args.command in ("source", "packed"):
            identity.verify_generated(project, read(run / "generation.json"))
            qa = qa_copy(output)
            env.update(HG_WORKER=str(qa / (args.phase + ".gd")), HG_WORKER_ROOT=str(qa),
                       HG_QA_BINDINGS=str(qa / "bindings.json"), HG_REPORT=str(output / "report.json"),
                       HG_OUTPUT_ROOT=str(output), HG_ROUTE_OUT=str(output),
                       HG_CARRIED_COPY=str(output / "carried_fixture"), HNS_VISUAL="1",
                       HG_EMPTY_COPY=str(output / "empty_fixture"),
                       HG_LEGACY_COPY=str(output / "carried_fixture"),
                       HNS_SIZE=f"{args.width}x720", LSH_LANGUAGE=args.language,
                       HG_EXPECTED_IDENTITY=str(run / "expected_identity.json"))
            if args.producer:
                producer = args.producer.resolve()
                data = read(producer)
                if not data.get("passed") or data.get("failures"):
                    raise RuntimeError("Fixture producer is not a successful report")
                producer_receipt_path = producer.parent / "receipt.json"
                producer_receipt = read(producer_receipt_path)
                if (not producer_receipt.get("complete")
                        or producer_receipt.get("report_sha256") != sha(producer)
                        or not producer_receipt.get("steps")
                        or any(not row.get("passed") or row.get("exit_code") != 0
                               for row in producer_receipt["steps"])):
                    raise RuntimeError("Producer lacks a successful terminal receipt")
                if args.namespace == "hg_transport_world":
                    expected_content = "source-v1:" + read(run / "generation.json")["identity"]["source_sha256"]
                    trusted = data.get("trusted_identity", {})
                    if trusted.get("content_version") != expected_content:
                        raise RuntimeError("Checkpoint belongs to another frozen runtime")
                    if trusted.get("source_mode") != (args.command == "source"):
                        raise RuntimeError("Checkpoint source/package mode differs")
                receipt["producer_receipt"] = {"path": str(producer_receipt_path),
                                               "sha256": sha(producer_receipt_path)}
                fixture = args.fixture.resolve() if args.fixture else producer.parent / (
                    "empty_fixture" if args.fixture_kind == "empty" else "carried_fixture")
                receipt["fixture_copies"] = restore_fixture(
                    profile, fixture, producer, args.namespace, args.fixture_kind)
                env["HG_COLD_EXPECTED"] = str(producer)
                env["HG_LEGACY_EXPECTED"] = str(producer)
            arguments = ["--resolution", f"{args.width}x720", "--position", "30000,30000",
                         "--script", str(qa / "bootstrap.gd")]
            if args.command == "source":
                env["HG_SOURCE_MODE"] = "1"
                env["HG_EXECUTION_KIND"] = "source_project"
                common.process_step(engine, project, env, output, args.phase, arguments,
                                    args.timeout, "gl_compatibility", running, receipt["steps"])
            else:
                exported, runtime = checked_export(args, project, run, receipt)
                env["HG_SOURCE_MODE"] = "0"
                env["HG_EXECUTION_KIND"] = "compiled_pck_editor_loader"
                loader, files = compiled_loader(run, engine, exported, runtime)
                env["HG_EXPECTED_EXE_SHA"] = sha(loader)
                receipt["execution_kind"] = env["HG_EXECUTION_KIND"]
                receipt["loader_files"] = files
                receipt["native_release_tested"] = False
                common.process_step(loader, loader.parent, env, output, args.phase,
                                    ["--main-pack", str(runtime / "LiangshanHeroes.pck"), *arguments],
                                    args.timeout, "gl_compatibility", running, receipt["steps"])
            report = read(output / "report.json")
            if not report.get("passed") or report.get("failures"):
                raise RuntimeError("Worker report failed")
            receipt.update(report=str(output / "report.json"), report_sha256=sha(output / "report.json"),
                           checks=len(report["checks"]) if isinstance(report["checks"], list) else report["checks"])
        assert_runtime_current(run)
        if (run / "generation.json").exists():
            identity.verify_generated(project, read(run / "generation.json"))
        receipt["complete"] = True
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        # Only our exact lock can be released; every process helper waits for its
        # own child before returning. Never remove a foreign marker.
        if locked and shared.LOCK.exists() and shared.LOCK.read_text(encoding="utf-8") == owner:
            shared.LOCK.unlink()
        receipt["lock_released"] = locked and not shared.LOCK.exists()
        save(output / "receipt.json", receipt)
    print(json.dumps({"output": str(output), **{k: receipt.get(k) for k in
          ("complete", "checks", "error", "lock_released")}}, ensure_ascii=False))
    if not receipt["complete"]:
        raise SystemExit(1)


SUITE_PHASES = ("model", "cold_carried", "cold_empty", "faults", "empty_faults",
                "legacy_reject", "ui", "force_departure", "controls")
SUITE_FIXTURES = {"cold_carried": "carried", "cold_empty": "empty",
                  "faults": "carried", "empty_faults": "empty", "ui": "carried"}


def suite_verify_files(folder, rows):
    """Hash the complete runtime/loader file set, including unexpected files."""
    identity.no_links(folder)
    expected = {}
    for row in rows:
        name = Path(row["path"])
        if name.is_absolute() or ".." in name.parts or str(name).lower() in expected:
            raise RuntimeError("Invalid pinned runtime path")
        expected[str(name).lower()] = row["sha256"]
    actual = {}
    for path in sorted(folder.rglob("*")):
        identity.no_links(path)
        if path.is_file():
            name = str(path.relative_to(folder)).lower()
            if name in actual:
                raise RuntimeError("Duplicate runtime path")
            actual[name] = sha(path)
    if actual != expected:
        raise RuntimeError("Runtime file set or SHA changed: " + str(folder))


def suite_verify_pins(pins):
    for name, digest in pins.items():
        path = Path(name)
        identity.no_links(path)
        if sha(path) != digest:
            raise RuntimeError("Pinned evidence changed: " + name)


def suite_qa_copy(output, seed, rows):
    target = output / "qa"
    target.mkdir()
    for row in rows:
        copy_checked(seed / row["path"], target / row["path"], row["sha256"])
    return target


def suite_producer(path, legacy, content_version, loader_sha, export_pin):
    """Accept only a terminal original producer, never an in-progress report."""
    path = path.resolve()
    identity.no_links(path)
    receipt_path = path.parent / "receipt.json"
    identity.no_links(receipt_path)
    pins = {str(path): sha(path), str(receipt_path): sha(receipt_path)}
    data, receipt = read(path), read(receipt_path)
    steps = receipt.get("steps", [])
    if (not data.get("passed") or data.get("failures")
            or not receipt.get("complete") or receipt.get("report_sha256") != pins[str(path)]
            or not steps or any(not step.get("passed") or step.get("exit_code") != 0
                               or step.get("stopped_for") is not None for step in steps)
            or data.get("pid") != steps[-1].get("pid")):
        raise RuntimeError("Fixture producer lacks a successful terminal report/receipt")
    trusted = data.get("trusted_identity", {})
    if legacy:
        if (receipt.get("worker") != "legacy" or receipt.get("phase") != "source"
                or trusted.get("source_mode") is not True
                or data.get("profile") != "campaign_level1_v1"
                or len(data.get("load_ids", [])) != 3):
            raise RuntimeError("Legacy producer is not the genuine original three-target source fixture")
    elif (receipt.get("worker") != "live" or receipt.get("phase") != "packed"
            or data.get("execution_kind") != "compiled_pck_editor_loader"
            or receipt.get("execution_kind") != "compiled_pck_editor_loader"
            or data.get("native_release_tested") is not False
            or not trusted.get("ok") or not trusted.get("save_eligible")
            or trusted.get("source_mode") is not False
            or trusted.get("content_version") != content_version
            or trusted.get("engine_binary_sha256") != loader_sha
            or receipt.get("export_receipt") != export_pin):
        raise RuntimeError("Transport producer is not a successful live run of this exact compiled PCK and loader")
    suite_verify_pins(pins)
    return {"report": path, "pins": pins, "receipt": str(receipt_path),
            "pid": data["pid"], "legacy": legacy}


def suite_audit(project, root_source, generation, runtime, runtime_rows, pins,
                engine, engine_sha, loader=None, loader_rows=None, qa_seed=None, qa_rows=None):
    """Always attempt every boundary check, even if a different check fails."""
    checks = []
    def perform(label, operation):
        row = {"check": label, "passed": False}
        try:
            operation()
            row["passed"] = True
        except BaseException as error:
            row["error"] = repr(error)
        checks.append(row)
    def root_check():
        if identity.snapshot(ROOT) != root_source:
            raise RuntimeError("Production source changed: freeze a new candidate")
    perform("current_root_complete_sha", root_check)
    perform("frozen_source_and_generated_identity_complete_sha",
            lambda: identity.verify_generated(project, generation))
    perform("export_runtime_complete_sha", lambda: suite_verify_files(runtime, runtime_rows))
    perform("original_editor_binary_sha", lambda: suite_verify_pins({str(engine): engine_sha}))
    perform("pinned_manifests_and_producers_sha", lambda: suite_verify_pins(pins))
    if loader is not None:
        perform("compiled_loader_complete_sha", lambda: suite_verify_files(loader.parent, loader_rows))
    if qa_seed is not None:
        perform("frozen_external_qa_complete_sha", lambda: suite_verify_files(qa_seed, qa_rows))
    return {"passed": all(row["passed"] for row in checks), "checks": checks}


def suite_stage(args, phase, output, suite_output, project, run, loader, loader_rows,
                loader_sha, runtime, export_pin, qa_seed, qa_rows, producer):
    """One fresh OS process and profile; the caller retains the batch lock."""
    receipt = {"complete": False, "phase": "packed", "worker": phase, "steps": [],
               "runner_sha256": sha(__file__), "project": str(project),
               "suite_receipt": str(suite_output / "receipt.json"),
               "boundary_identity_checks": "suite_start_and_end",
               "execution_kind": "compiled_pck_editor_loader", "native_release_tested": False,
               "export_receipt": export_pin, "loader_files": loader_rows,
               "engine_sha256": loader_sha, "lock_owner": str(suite_output)}
    try:
        if not shared.LOCK.exists() or shared.LOCK.read_text(encoding="utf-8") != str(suite_output):
            raise RuntimeError("Suite lost its owned engine lock")
        if running():
            raise RuntimeError("Engine appeared before suite child launch")
        profile, env = private_env(output)
        receipt["profile"] = str(profile)
        qa = suite_qa_copy(output, qa_seed, qa_rows)
        receipt["qa_files"] = qa_rows
        env.update(HG_WORKER=str(qa / (phase + ".gd")), HG_WORKER_ROOT=str(qa),
                   HG_QA_BINDINGS=str(qa / "bindings.json"), HG_REPORT=str(output / "report.json"),
                   HG_OUTPUT_ROOT=str(output), HG_ROUTE_OUT=str(output), HNS_VISUAL="1",
                   HG_CARRIED_COPY=str(output / "carried_fixture"),
                   HG_EMPTY_COPY=str(output / "empty_fixture"),
                   HG_LEGACY_COPY=str(output / "carried_fixture"),
                   HNS_SIZE=f"{args.width}x720", LSH_LANGUAGE=args.language,
                   HG_EXPECTED_IDENTITY=str(run / "expected_identity.json"),
                   HG_EXPECTED_EXE_SHA=loader_sha, HG_SOURCE_MODE="0",
                   HG_EXECUTION_KIND="compiled_pck_editor_loader")
        if producer is not None:
            suite_verify_pins(producer["pins"])
            legacy = producer["legacy"]
            kind = "carried" if legacy else SUITE_FIXTURES[phase]
            namespace = "hg_legacy3" if legacy else "hg_transport_world"
            fixture = producer["report"].parent / ("empty_fixture" if kind == "empty" else "carried_fixture")
            receipt["producer_receipt"] = {"path": producer["receipt"],
                                           "sha256": producer["pins"][producer["receipt"]]}
            receipt["producer_report_sha256"] = producer["pins"][str(producer["report"])]
            receipt["fixture_kind"] = kind
            receipt["fixture_namespace"] = namespace
            receipt["fixture_copies"] = restore_fixture(profile, fixture, producer["report"], namespace, kind)
            env["HG_LEGACY_EXPECTED" if legacy else "HG_COLD_EXPECTED"] = str(producer["report"])
        common.process_step(loader, loader.parent, env, output, phase,
                            ["--main-pack", str(runtime / "LiangshanHeroes.pck"),
                             "--resolution", f"{args.width}x720", "--position", "30000,30000",
                             "--script", str(qa / "bootstrap.gd")],
                            args.timeout, "gl_compatibility", running, receipt["steps"])
        report = read(output / "report.json")
        trusted = report.get("trusted_identity", {})
        if (not report.get("passed") or report.get("failures")
                or report.get("execution_kind") != "compiled_pck_editor_loader"
                or report.get("native_release_tested") is not False
                or not trusted.get("ok") or not trusted.get("save_eligible")
                or trusted.get("source_mode") is not False
                or trusted.get("engine_binary_sha256") != loader_sha
                or report.get("pid") != receipt["steps"][-1].get("pid")
                or (producer is not None and report.get("pid") == producer["pid"])):
            raise RuntimeError("Suite worker report or actual process identity failed")
        if trusted.get("content_version") != "source-v1:" + read(run / "expected_identity.json")["source_sha256"]:
            raise RuntimeError("Suite worker executed another compiled content identity")
        suite_verify_files(qa, qa_rows)
        if producer is not None:
            suite_verify_pins(producer["pins"])
        receipt.update(complete=True, checks=len(report["checks"]) if isinstance(report["checks"], list) else report["checks"])
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        # process_step waits its exact child, including timeout/error teardown.
        receipt["child_process_terminal"] = bool(receipt["steps"]) and all(step.get("exit_code") is not None for step in receipt["steps"])
        report_path = output / "report.json"
        if report_path.is_file():
            receipt.update(report=str(report_path), report_sha256=sha(report_path))
        receipt["lock_retained_by_suite"] = shared.LOCK.exists() and shared.LOCK.read_text(encoding="utf-8") == str(suite_output)
        save(output / "receipt.json", receipt)
    return receipt


def execute_suite(args):
    run = args.run.resolve()
    identity.no_links(run)
    output = run / ("packed_suite_" + stamp())
    output.mkdir()
    receipt = {"complete": False, "phase": "packed-suite", "requested_phases": args.phases,
               "stages": [], "runner_sha256": sha(__file__),
               "execution_kind": "compiled_pck_editor_loader", "native_release_tested": False}
    owner, locked = str(output), False
    audit_args = None
    try:
        waiting_since = time.monotonic()
        last_notice = waiting_since - 25
        while not locked:
            if not shared.LOCK.exists() and not running():
                try:
                    with shared.LOCK.open("x", encoding="utf-8") as lock:
                        lock.write(owner)
                    locked = True
                    break
                except FileExistsError:
                    pass
            if time.monotonic() - waiting_since >= args.wait_lane:
                raise RuntimeError("Shared engine lane occupied; no suite child started")
            if time.monotonic() - last_notice >= 25:
                print("WAIT shared engine lane; no suite child started", flush=True)
                last_notice = time.monotonic()
            time.sleep(1)
        receipt["lane_wait_seconds"] = round(time.monotonic() - waiting_since, 3)
        if running():
            raise RuntimeError("Engine appeared before suite preflight")
        evidence = [run / name for name in ("preparation.json", "root_source.json", "generation.json", "expected_identity.json")]
        evidence.extend([args.export_receipt.resolve(), Path(__file__).resolve()])
        pins = {str(path): sha(path) for path in evidence}
        suite_verify_pins(pins)
        if pins[str(Path(__file__).resolve())] != receipt["runner_sha256"]:
            raise RuntimeError("Runner changed while waiting for suite lane")
        preparation = read(run / "preparation.json")
        if not preparation.get("complete") or preparation.get("legacy_overlays_from_head"):
            raise RuntimeError("Suite requires the current complete production freeze")
        project = Path(preparation["project"]).resolve()
        generation = read(run / "generation.json")
        root_source = read(run / "root_source.json")
        expected = {key: value for key, value in generation["identity"].items() if key not in ("files", "directories")}
        if read(run / "expected_identity.json") != expected:
            raise RuntimeError("Expected runtime identity differs from generated identity")
        exported = read(args.export_receipt)
        if (not exported.get("complete") or exported.get("phase") != "export"
                or Path(exported["project"]).resolve() != project
                or exported.get("source_sha256") != generation["identity"]["source_sha256"]):
            raise RuntimeError("Suite export belongs to another or incomplete frozen source")
        runtime = Path(exported["runtime"]).resolve()
        export_pin = {"path": str(args.export_receipt.resolve()), "sha256": pins[str(args.export_receipt.resolve())]}
        engine = shared.resolve_godot(None)
        engine_sha = sha(engine)
        audit_args = dict(project=project, root_source=root_source, generation=generation,
                          runtime=runtime, runtime_rows=exported["runtime_files"], pins=pins,
                          engine=engine, engine_sha=engine_sha)
        receipt.update(project=str(project), source_sha256=generation["identity"]["source_sha256"],
                       export_receipt=export_pin, engine_sha256=engine_sha)
        receipt["initial_identity_check"] = suite_audit(**audit_args)
        if not receipt["initial_identity_check"]["passed"]:
            raise RuntimeError("Suite initial full identity check failed")
        loader, loader_rows = compiled_loader(run, engine, exported, runtime)
        suite_verify_files(loader.parent, loader_rows)
        qa_seed = qa_copy(output)
        qa_rows = [{"path": path.name, "sha256": sha(path)} for path in sorted(qa_seed.iterdir()) if path.is_file()]
        audit_args.update(loader=loader, loader_rows=loader_rows, qa_seed=qa_seed, qa_rows=qa_rows)
        receipt.update(loader_files=loader_rows, frozen_qa_files=qa_rows)
        content_version = "source-v1:" + generation["identity"]["source_sha256"]
        transport = suite_producer(args.producer, False, content_version, engine_sha, export_pin) if any(phase in SUITE_FIXTURES for phase in args.phases) else None
        legacy = suite_producer(args.legacy_producer, True, content_version, engine_sha, export_pin) if "legacy_reject" in args.phases else None
        for producer in (transport, legacy):
            if producer is not None:
                pins.update(producer["pins"])
        receipt["pinned_evidence"] = pins.copy()
        for phase in args.phases:
            stage_output = output / (phase + "_" + stamp())
            stage_output.mkdir()
            producer = legacy if phase == "legacy_reject" else transport if phase in SUITE_FIXTURES else None
            stage = suite_stage(args, phase, stage_output, output, project, run, loader,
                                loader_rows, engine_sha, runtime, export_pin, qa_seed, qa_rows, producer)
            stage_receipt = stage_output / "receipt.json"
            pins[str(stage_receipt)] = sha(stage_receipt)
            receipt["stages"].append({"worker": phase, "complete": stage["complete"],
                                      "receipt": str(stage_receipt),
                                      "receipt_sha256": pins[str(stage_receipt)]})
            if stage.get("report_sha256"):
                pins[stage["report"]] = stage["report_sha256"]
            log = stage_output / (phase + ".log")
            if log.is_file():
                pins[str(log)] = sha(log)
            if not stage["complete"]:
                raise RuntimeError("Suite stopped at first failing phase: " + phase)
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        if audit_args is not None:
            receipt["final_identity_check"] = suite_audit(**audit_args)
        else:
            receipt["final_identity_check"] = {"passed": False, "not_run": "Preflight did not establish trusted audit inputs"}
        if audit_args is not None:
            receipt["pinned_evidence"] = audit_args["pins"].copy()
        receipt["unstarted_phases"] = args.phases[len(receipt["stages"]):]
        receipt["lock_ownership_confirmed"] = locked and shared.LOCK.exists() and shared.LOCK.read_text(encoding="utf-8") == owner
        if locked and not receipt["lock_ownership_confirmed"] and "error" not in receipt:
            receipt["error"] = "Suite lost its owned engine lock"
        all_stages = len(receipt["stages"]) == len(args.phases) and all(stage["complete"] for stage in receipt["stages"])
        receipt["complete"] = all_stages and "error" not in receipt and receipt["final_identity_check"]["passed"] and receipt["lock_ownership_confirmed"]
        if not receipt["final_identity_check"]["passed"] and "error" not in receipt:
            receipt["error"] = "Suite final full identity check failed"
        if locked and shared.LOCK.exists() and shared.LOCK.read_text(encoding="utf-8") == owner:
            shared.LOCK.unlink()
        receipt["lock_released"] = locked and not shared.LOCK.exists()
        save(output / "receipt.json", receipt)
    print(json.dumps({"output": str(output), "complete": receipt["complete"],
                      "stages": len(receipt["stages"]), "error": receipt.get("error"),
                      "lock_released": receipt["lock_released"]}, ensure_ascii=False))
    if not receipt["complete"]:
        raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["prepare", "import", "source", "export", "packed", "release", "packed-suite"])
    parser.add_argument("--run", type=Path)
    parser.add_argument("--phase")
    parser.add_argument("--phases", nargs="+", choices=SUITE_PHASES,
                        help="Explicit ordered packed-suite workers; first failure stops the batch")
    parser.add_argument("--legacy-producer", type=Path,
                        help="Successful genuine three-target legacy report for packed-suite")
    parser.add_argument("--producer", type=Path)
    parser.add_argument("--fixture", type=Path)
    parser.add_argument("--namespace", default="hg_transport_world")
    parser.add_argument("--fixture-kind", choices=["carried", "empty"], default="carried")
    parser.add_argument("--legacy", action="store_true",
                        help="Prepare the real current Git HEAD runtime for a legacy save fixture")
    parser.add_argument("--export-receipt", type=Path)
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--language", default="zh_CN", choices=["zh_CN", "zh_TW", "en", "ja"])
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--wait-lane", type=int, default=0,
                        help="Bounded wait for the shared engine lane; never stops a peer")
    args = parser.parse_args()
    if args.command == "prepare":
        prepare(args)
    elif args.command == "packed-suite":
        if args.run is None or args.export_receipt is None or not args.phases:
            parser.error("packed-suite requires --run, --export-receipt and explicit --phases")
        if len(args.phases) != len(set(args.phases)):
            parser.error("packed-suite phases must be unique")
        if any(phase in SUITE_FIXTURES for phase in args.phases) and args.producer is None:
            parser.error("transport cold/fault/ui phases require a successful compiled live --producer")
        if "legacy_reject" in args.phases and args.legacy_producer is None:
            parser.error("legacy_reject requires explicit --legacy-producer")
        if args.phase is not None or args.fixture is not None or args.legacy or args.namespace != "hg_transport_world" or args.fixture_kind != "carried":
            parser.error("packed-suite fixes per-phase namespaces/fixtures; use only --phases and producer reports")
        execute_suite(args)
    else:
        if args.run is None or (args.command in ("source", "packed") and args.phase is None):
            parser.error("--run and worker --phase are required")
        if args.command in ("packed", "release") and args.export_receipt is None:
            parser.error("--export-receipt is required")
        execute(args)


if __name__ == "__main__":
    main()
