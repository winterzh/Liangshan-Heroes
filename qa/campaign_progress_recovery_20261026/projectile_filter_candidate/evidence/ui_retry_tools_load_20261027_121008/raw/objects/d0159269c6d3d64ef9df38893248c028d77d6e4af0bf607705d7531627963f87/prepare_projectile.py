"""Freeze one VisualGraph replacement over complete 3365; import it cold once.

Default checks named sources/metadata only. --prepare owns the shared lane and
copies the complete admitted base, without import/editor/shader cache seeds.
--import-cold RUN alone starts Godot, after a locked, immediate cache inventory.
A failed import attempt is retained and cannot be retried as a cold first import.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time
import traceback
import uuid

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
QA = HERE.parents[1]
spec = importlib.util.spec_from_file_location(
    "projectile_3365_prior", QA / "daming_continue_candidate/integration_941/prepare_daming.py")
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)
p, h, require = prior.p, prior.h, prior.require
inside, merge_pins = prior.inside, prior.merge_pins
BASE_RUN = ".godot/campaign_progress_recovery_20261026/20261027_063133_392242bc"
BASE_IDENTITY = "source-v1:3365e369ba351e9d9593d2324391c7b042a967144df85f1c35f7cb9aad932539"
BASE_MANIFEST = "940ff7d43838f6ebfbe061a795e34f401711156023b9047d2ba5e394a554fd4d"
GRAPH = "scripts/run_visual_graph.gd"
FIXED_OVERLAYS = [{
    "path": GRAPH,
    "source_path": "qa/campaign_progress_recovery_20261026/projectile_filter_candidate/scripts/run_visual_graph.gd",
    "base_sha256": "d7bc061b6ee934c3502451a76043999992029d9342ea7583be6f0c45de8e0213",
    "base_bytes": 75632,
    "candidate_sha256": "feca8481000d8edb1bab5b00ad6f7c03ffeb9802637a92c714b795eee3a64582",
    "candidate_bytes": 75835,
}]
BINDINGS = ["res://addons/godotsteam/godotsteam.gdextension",
            "res://addons/steam_stats_reader/reader.gdextension"]
REGISTRATION = ("\n".join(BINDINGS) + "\n").encode("utf-8")
FREEZE_ROOT = ROOT / ".godot/campaign_progress_recovery_20261026"
IMPORT_SCHEMA = "projectile_3365_cold_import_v1"


def read(path):
    h.identity.no_links(p.fs(path))
    return h.read(p.fs(path))


def save(path, value):
    h.identity.no_links(p.fs(path))
    h.save(p.fs(path), value)


def digest(path):
    h.identity.no_links(p.fs(path))
    return h.sha(p.fs(path))


def lightweight():
    """Named file hashes and complete identity metadata, never a project scan."""
    pins = {}
    overlay_path, sources_path = HERE / "source_manifest.json", HERE / "sources.json"
    overlay, sources = read(overlay_path), read(sources_path)
    require(overlay.get("schema") == "projectile_3365_overlay_v1"
            and overlay.get("base_run") == BASE_RUN
            and overlay.get("base_identity") == BASE_IDENTITY
            and overlay.get("base_manifest_sha256") == BASE_MANIFEST
            and overlay.get("files") == FIXED_OVERLAYS,
            "Exact one-existing-resource 3365 overlay required")
    require(sources.get("schema") == "projectile_3365_sources_v1" and sources.get("sources"),
            "Named preparation source list required")
    seen = set()
    for row in sources["sources"]:
        require(row["path"] not in seen, "Duplicate named source")
        seen.add(row["path"])
        source = inside(ROOT, row["path"])
        p.pin(source, pins, row["sha256"])
        require(p.fs(source).stat().st_size == row["bytes"], "Named source size changed")
    require([row["path"] for row in overlay["support_files"]] == ["README.md", "sources.json"],
            "Exact local support files required")
    for row in overlay["support_files"]:
        p.pin(inside(HERE, row["path"]), pins, row["sha256"])
    # Parent declarations are independently pinned in sources.json. They may
    # include model tools, but cannot claim this new complete freeze was tested.
    parent = read(HERE.parent / "source_manifest.json")
    require(parent.get("schema") == "projectile_filter_overlay_v1"
            and parent.get("base_run") == BASE_RUN
            and parent.get("base_identity") == BASE_IDENTITY
            and parent.get("files") == FIXED_OVERLAYS,
            "Parent one-file candidate declaration changed")
    base = ROOT / BASE_RUN
    p.pin(base / "candidate_manifest.json", pins, BASE_MANIFEST)
    previous = read(base / "candidate_manifest.json")
    require(previous.get("schema") == "daming_941_integrated_manifest_v1"
            and len(previous["files"]) == 25 and len(previous["native_assets"]) == 1,
            "Exact previous 25 scripts and native helper required")
    identity = read(base / "generation.json")["identity"]
    require("source-v1:" + identity["source_sha256"] == BASE_IDENTITY
            and read(base / "preimport_source.json") == identity,
            "Complete base identity metadata changed")
    full = {row["path"]: row for row in identity["files"]}
    root_rows = {row["path"]: row for row in read(base / "root_source.json")["files"]}
    rows = {row["path"]: deepcopy(row) for row in previous["files"]}
    require(len(full) == len(identity["files"]) == identity["file_count"]
            and len(rows) == 25 and GRAPH not in rows, "Unique complete base and tracking paths required")
    row = FIXED_OVERLAYS[0]
    require(full.get(GRAPH, {}).get("sha256") == row["base_sha256"]
            and full[GRAPH]["bytes"] == row["base_bytes"]
            and root_rows.get(GRAPH, {}).get("sha256") == row["base_sha256"],
            "New tracking must refer to the unchanged existing production Graph")
    p.pin(inside(base / "project", GRAPH), pins, row["base_sha256"])
    candidate = inside(ROOT, row["source_path"])
    p.pin(candidate, pins, row["candidate_sha256"])
    require(p.fs(candidate).stat().st_size == row["candidate_bytes"], "Graph candidate size changed")
    rows[GRAPH] = {"path": GRAPH, "production_base_sha256": row["base_sha256"],
                   "source_path": row["source_path"], "candidate_sha256": row["candidate_sha256"],
                   "candidate_bytes": row["candidate_bytes"]}
    require(all(rows[item["path"]] == item for item in previous["files"]) and len(rows) == 26,
            "All 25 earlier tracking entries must remain unchanged")
    for module in (prior, p, h, h.common, h.shared, h.identity):
        p.pin(Path(module.__file__), pins)
    p.pin(sources_path, pins)
    overlay_sha = p.pin(overlay_path, pins)
    p.pin(Path(__file__), pins)
    manifest = {"schema": "projectile_3365_integrated_manifest_v1",
                "previous_manifest_sha256": BASE_MANIFEST, "previous_identity": BASE_IDENTITY,
                "previous_run": BASE_RUN, "overlay_manifest_sha256": overlay_sha,
                "qualification_inherited": False, "production_integrated": False,
                "replacement_files": deepcopy(FIXED_OVERLAYS), "new_project_files": [],
                "files": [rows[name] for name in sorted(rows)],
                "native_assets": deepcopy(previous["native_assets"])}
    p.verify_pins(pins)
    return {"pins": pins, "base": base, "manifest": manifest, "previous_manifest": previous,
            "overlay": overlay, "validation_level": "metadata_and_named_sources_only",
            "full_source_verified": False, "cold_import_qualified": False}


def preflight():
    light = lightweight()
    state = prior.prepared_state(ROOT / BASE_RUN)
    require(state["run_base"] == light["base"] and state["content_version"] == BASE_IDENTITY
            and state["manifest"] == light["previous_manifest"], "Full imported 3365 provenance changed")
    merge_pins(state["pins"], light["pins"])
    p.verify_pins(state["pins"])
    return {**state, "base": state["run_base"], "manifest": light["manifest"],
            "overlay": light["overlay"], "validation_level": "full_imported_base",
            "full_source_verified": True, "cold_import_qualified": False}


def expected_files(state):
    rows = deepcopy(state["generation"]["identity"]["files"])
    matches = [row for row in rows if row["path"] == GRAPH]
    require(len(matches) == 1 and matches[0]["sha256"] == FIXED_OVERLAYS[0]["base_sha256"]
            and matches[0]["bytes"] == FIXED_OVERLAYS[0]["base_bytes"], "Original Graph changed")
    matches[0].update(sha256=FIXED_OVERLAYS[0]["candidate_sha256"],
                      bytes=FIXED_OVERLAYS[0]["candidate_bytes"])
    return rows


def check_composition(identity, state):
    original = state["generation"]["identity"]
    require(identity["files"] == expected_files(state)
            and identity["directories"] == original["directories"],
            "Complete source must differ only in the existing VisualGraph")
    before = {row["path"]: row for row in original["files"]}
    after = {row["path"]: row for row in identity["files"]}
    require(set(before) == set(after)
            and {name for name in before if before[name] != after[name]} == {GRAPH},
            "Exactly one replacement and no added/deleted source files required")
    for row in state["manifest"]["files"] + state["manifest"]["native_assets"]:
        require(after.get(row["path"], {}).get("sha256") == row["candidate_sha256"],
                "Composed tracked/native member differs")


def cold_inventory_value(project):
    return {"schema": "projectile_cold_cache_inventory_v1", "project": str(project),
            "root": ".godot", "directories": [],
            "files": [{"path": "extension_list.cfg", "bytes": len(REGISTRATION),
                       "sha256": hashlib.sha256(REGISTRATION).hexdigest()}],
            "native_extension_registration_only": True, "old_cache_seeded": False}


def assert_cold_project(project):
    """Check the entire cache namespace, including empty unexpected directories."""
    project = Path(project).absolute()
    cache = p.fs(project / ".godot")
    h.identity.no_links(cache)
    require(cache.is_dir(), "Fresh extension registration directory required")
    entries = list(cache.iterdir())
    require(len(entries) == 1 and entries[0].name == "extension_list.cfg",
            "Cold import requires no imported/editor/shader/other cached entries")
    h.identity.no_links(entries[0])
    require(entries[0].is_file() and entries[0].read_bytes() == REGISTRATION,
            "Only exact fresh native extension registration may precede cold import")
    return cold_inventory_value(project)


def assert_owned(owner):
    lock = p.fs(h.shared.LOCK)
    h.identity.no_links(lock)
    require(lock.is_file() and lock.read_text(encoding="utf-8") == owner,
            "Shared lane owner changed")


def acquire_lane(owner, wait_seconds):
    start, notice = time.monotonic(), 0.0
    lock = p.fs(h.shared.LOCK)
    while True:
        h.identity.no_links(lock)
        if not lock.exists() and not h.running():
            try:
                with lock.open("x", encoding="utf-8") as stream:
                    stream.write(owner)
                return round(time.monotonic() - start, 3)
            except FileExistsError:
                pass
        require(time.monotonic() - start < wait_seconds, "Shared engine lane occupied; no child started")
        if time.monotonic() - notice >= 25:
            print("WAIT shared engine lane; no child started", flush=True)
            notice = time.monotonic()
        time.sleep(1)


def terminal_steps(receipt):
    if not receipt.get("native_step_attempted"):
        return True
    steps = receipt.get("steps", [])
    return (len(steps) == 1 and type(steps[0].get("pid")) is int and steps[0]["pid"] > 0
            and type(steps[0].get("exit_code")) is int)


def cleanup_lane(receipt, owner, locked):
    receipt["child_terminal"] = terminal_steps(receipt)
    receipt["lock_released"] = False
    if not locked:
        return
    try:
        assert_owned(owner)
        receipt["lock_owner_verified"] = True
        receipt["engine_lane_idle"] = h.running() is False
        require(receipt["child_terminal"] and receipt["engine_lane_idle"],
                "Do not release owned lane without terminal child and idle engine")
        p.fs(h.shared.LOCK).unlink()
        receipt["lock_released"] = not p.fs(h.shared.LOCK).exists()
    except BaseException as error:
        receipt.setdefault("cleanup_errors", []).append({"step": "release_lane", "error": repr(error),
                                                        "traceback": traceback.format_exc()})


def failure(receipt, error):
    receipt["error"] = repr(error)
    receipt["traceback"] = traceback.format_exc()


def verify_post(receipt, label, action):
    try:
        action()
        receipt[label] = True
    except BaseException as error:
        receipt[label] = False
        receipt.setdefault("postcheck_errors", []).append({"step": label, "error": repr(error),
                                                          "traceback": traceback.format_exc()})


def create_output(parent, prefix=""):
    output = parent / (prefix + h.stamp())
    h.identity.no_links(p.fs(output))
    p.fs(output).mkdir(parents=True, exist_ok=False)
    return output


def prepare(wait_seconds=0):
    output = create_output(FREEZE_ROOT)
    project = output / "project"
    owner, locked, state, work_done = str(output), False, None, False
    receipt = {"schema": "projectile_3365_preparation_v1", "complete": False,
               "project": str(project), "base_run": str(ROOT / BASE_RUN), "base_identity": BASE_IDENTITY,
               "runner_sha256": digest(__file__), "engine_started": False,
               "production_modified": False, "qualification_inherited": False,
               "replacement_files": deepcopy(FIXED_OVERLAYS), "new_project_files": [],
               "cache_seed": {"files": 0, "bytes": 0, "qualification_reused": False},
               "steps": [], "native_step_attempted": False}
    try:
        receipt["lane_wait_seconds"] = acquire_lane(owner, wait_seconds)
        locked = True
        assert_owned(owner)
        require(not h.running(), "Engine appeared before preparation admission")
        state = preflight()
        receipt["pinned_candidates"] = dict(state["pins"])
        receipt["source_head"] = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        p.fs(project).mkdir(exist_ok=False)
        p.copy(state["base"] / "root_source.json", output / "root_source.json",
               state["pins"][str(state["base"] / "root_source.json")])
        save(output / "candidate_manifest.json", state["manifest"])
        receipt["candidate_manifest_sha256"] = digest(output / "candidate_manifest.json")
        source = state["generation"]["identity"]
        for name, present in source["directories"].items():
            if present and not name.startswith("@file/"):
                require(name.split("/")[0] != ".godot", "No source cache directory may be copied")
                p.fs(inside(project, name)).mkdir(parents=True, exist_ok=True)
        notice = time.monotonic()
        for index, row in enumerate(source["files"], 1):
            require(row["path"].split("/")[0] != ".godot", "No source cache file may be copied")
            p.copy(inside(state["project"], row["path"]), inside(project, row["path"]), row["sha256"])
            if time.monotonic() - notice >= 25:
                print("COPY complete 3365 %d/%d" % (index, len(source["files"])), flush=True)
                notice = time.monotonic()
        row = FIXED_OVERLAYS[0]
        p.copy(inside(ROOT, row["source_path"]), project / GRAPH, row["candidate_sha256"])
        for path, sha256 in state["pins"].items():
            source_path = Path(path)
            if source_path.suffix.lower() == ".exe":
                continue
            require(source_path.is_relative_to(ROOT), "Unexpected provenance path")
            p.copy(source_path, output / "preparation_inputs" / source_path.relative_to(ROOT), sha256)
        # Native source/DLL bytes are already part of the complete copied identity.
        # Do not call install_native or copy any excluded .godot source cache.
        require(h.shared.NATIVE_BINDINGS == BINDINGS, "Native registration contract changed")
        for binding in BINDINGS:
            require(binding[6:] in {item["path"] for item in source["files"]},
                    "Native binding must be an existing full-source member")
        cache = p.fs(project / ".godot")
        cache.mkdir(exist_ok=False)
        with (cache / "extension_list.cfg").open("xb") as stream:
            stream.write(REGISTRATION)
        receipt["identity_seed"] = h.identity.seed(project)
        cold = assert_cold_project(project)
        save(output / "cold_preparation_inventory.json", cold)
        receipt["cold_inventory_sha256"] = digest(output / "cold_preparation_inventory.json")
        receipt["overlays"], receipt["native_assets"] = state["manifest"]["files"], state["manifest"]["native_assets"]
        frozen = h.identity.snapshot(project)
        check_composition(frozen, state)
        save(output / "preimport_source.json", frozen)
        receipt.update(source_files=frozen["file_count"], source_bytes=frozen["total_bytes"],
                       preimport_sha256=digest(output / "preimport_source.json"))
        work_done = True
    except BaseException as error:
        failure(receipt, error)
    finally:
        if state is not None:
            verify_post(receipt, "final_pins_passed", lambda: p.verify_pins(state["pins"]))
            verify_post(receipt, "base_identity_passed", lambda: h.identity.verify_generated(state["project"], state["generation"]))
            verify_post(receipt, "production_identity_passed", lambda: h.assert_runtime_current(state["base"]))
        if work_done:
            verify_post(receipt, "final_identity_passed", lambda: require(
                h.identity.snapshot(project) == read(output / "preimport_source.json"), "Prepared source changed"))
            verify_post(receipt, "final_cold_inventory_passed", lambda: require(
                assert_cold_project(project) == read(output / "cold_preparation_inventory.json"), "Cold cache changed"))
        cleanup_lane(receipt, owner, locked)
        receipt["complete"] = bool(work_done and not receipt.get("error") and not receipt.get("postcheck_errors")
                                   and not receipt.get("cleanup_errors") and receipt["lock_released"])
        save(output / "preparation.json", receipt)
    print(json.dumps({"run": str(output), "complete": receipt["complete"], "error": receipt.get("error"),
                      "lock_released": receipt["lock_released"]}, ensure_ascii=False), flush=True)
    require(receipt["complete"], "Preparation failed; preserve its receipt and private directory")


def admission(base_run, state):
    """Preparation metadata binding; caller separately verifies current source bytes."""
    # Check links before resolve, so a junction cannot disappear through normalization.
    base_run = Path(base_run).absolute()
    h.identity.no_links(p.fs(base_run))
    base_run = base_run.resolve()
    require(base_run.parent == FREEZE_ROOT and base_run != state["base"], "New direct private freeze required")
    project = base_run / "project"
    manifest, receipt = read(base_run / "candidate_manifest.json"), read(base_run / "preparation.json")
    require(manifest == state["manifest"] and receipt.get("complete") is True
            and receipt.get("schema") == "projectile_3365_preparation_v1"
            and receipt.get("base_run") == str(state["base"]) and receipt.get("base_identity") == BASE_IDENTITY
            and receipt.get("project") == str(project) and receipt.get("runner_sha256") == digest(__file__)
            and receipt.get("engine_started") is False and receipt.get("production_modified") is False
            and receipt.get("qualification_inherited") is False and receipt.get("lock_released") is True
            and receipt.get("replacement_files") == FIXED_OVERLAYS and receipt.get("new_project_files") == []
            and receipt.get("cache_seed") == {"files": 0, "bytes": 0, "qualification_reused": False}
            and receipt.get("candidate_manifest_sha256") == digest(base_run / "candidate_manifest.json")
            and receipt.get("overlays") == manifest["files"] and receipt.get("native_assets") == manifest["native_assets"]
            and receipt.get("pinned_candidates") == state["pins"], "Exact complete cold preparation required")
    require(receipt.get("cold_inventory_sha256") == digest(base_run / "cold_preparation_inventory.json")
            and read(base_run / "cold_preparation_inventory.json") == cold_inventory_value(project)
            and receipt.get("preimport_sha256") == digest(base_run / "preimport_source.json"),
            "Preparation inventory binding changed")
    preimport = read(base_run / "preimport_source.json")
    check_composition(preimport, state)
    require(digest(base_run / "root_source.json") == state["pins"][str(state["base"] / "root_source.json")],
            "Original production source identity record changed")
    for name in ("candidate_manifest.json", "preparation.json", "root_source.json", "preimport_source.json",
                 "cold_preparation_inventory.json"):
        p.pin(base_run / name, state["pins"])
    return base_run, project, preimport


def import_cold(base_run, wait_seconds=0, timeout=1200):
    base_run = Path(base_run).absolute()
    h.identity.no_links(p.fs(base_run))
    base_run = base_run.resolve()
    require(base_run.parent == FREEZE_ROOT and p.fs(base_run).is_dir(), "Existing direct private freeze required")
    output = create_output(base_run, "import_cold__")
    owner, locked, state, work_done = str(output), False, None, False
    project = base_run / "project"
    receipt = {"schema": IMPORT_SCHEMA, "phase": "import", "complete": False, "project": str(project),
               "run_base": str(base_run), "runner_sha256": digest(__file__), "steps": [],
               "native_step_attempted": False, "cold_import_qualified": False,
               "qualification_inherited": False, "production_modified": False}
    try:
        receipt["lane_wait_seconds"] = acquire_lane(owner, wait_seconds)
        locked = True
        assert_owned(owner)
        require(not h.running(), "Engine appeared before cold import admission")
        state = preflight()
        base_run, project, preimport = admission(base_run, state)
        require(not p.fs(base_run / "generation.json").exists()
                and not p.fs(base_run / "expected_identity.json").exists()
                and not p.fs(base_run / "cold_import_attempt.json").exists(),
                "Cold import is first-attempt only; create a new freeze after any attempt")
        import_entries = sorted(item.name for item in p.fs(base_run).iterdir() if item.name.startswith("import"))
        require(import_entries == [output.name], "Earlier import evidence exists; no cold retry")
        require(h.assert_runtime_current(base_run) == project and h.identity.snapshot(project) == preimport,
                "Complete prepared source changed before import")
        require(p.fs(project / h.identity.DERIVED).read_bytes() == h.identity.STUB,
                "Exact unimported identity seed required")
        engine = state["engine"]
        require(digest(engine) == state["engine_sha256"], "Pinned engine changed")
        receipt.update(engine_sha256=state["engine_sha256"], engine=str(engine), initial_identity_passed=True,
                       preimport_sha256=digest(base_run / "preimport_source.json"),
                       candidate_manifest_sha256=digest(base_run / "candidate_manifest.json"))
        nonce = uuid.uuid4().hex
        profile = Path(ROOT.anchor) / "CodexQA/projectilecold" / nonce[:12]
        h.identity.no_links(profile)
        profile.mkdir(parents=True, exist_ok=False)
        env = h.common.private_environment(profile)
        for key in list(env):
            if key.startswith(("GVT_", "GT_", "GLS_", "DF_", "LT_", "LL_", "HG_", "RS_",
                               "CT_", "CB_", "CC_", "CR_", "SC_", "SP_", "DA_", "PF_")):
                env.pop(key)
        env.update(CAMPAIGN_QA="", STEAM_DISABLED="1")
        receipt.update(profile=str(profile), nonce=nonce)
        p.verify_pins(state["pins"])
        assert_owned(owner)
        require(not h.running(), "Engine appeared before cold inventory")
        # This is the actual lock-held inventory immediately before process_step.
        # Only exclusive evidence writes occur between this check and that call.
        before = assert_cold_project(project)
        save(output / "cold_before.json", before)
        before_sha = digest(output / "cold_before.json")
        attempt = {"schema": "projectile_cold_import_attempt_v1", "run_base": str(base_run),
                   "project": str(project), "output": str(output), "nonce": nonce,
                   "owner": owner, "engine_sha256": state["engine_sha256"],
                   "cold_before_sha256": before_sha, "preimport_sha256": receipt["preimport_sha256"],
                   "candidate_manifest_sha256": receipt["candidate_manifest_sha256"]}
        save(base_run / "cold_import_attempt.json", attempt)
        receipt.update(cold_before_sha256=before_sha, cold_inventory_checked_under_owned_lock=True,
                       attempt_sha256=digest(base_run / "cold_import_attempt.json"), native_step_attempted=True)
        h.common.process_step(engine, project, env, output, "import",
                              ["--headless", "--editor", "--import", "--quit"], timeout,
                              "gl_compatibility", h.running, receipt["steps"])
        require(h.identity.snapshot(project) == preimport, "Import modified canonical source")
        generated = h.identity.generate(project)
        check_composition(generated["identity"], state)
        require(generated["identity"] == preimport, "Generated identity differs from complete preimport")
        save(base_run / "generation.json", generated)
        save(base_run / "expected_identity.json", {key: value for key, value in generated["identity"].items()
                                                   if key not in ("files", "directories")})
        receipt.update(generation_sha256=digest(base_run / "generation.json"),
                       expected_identity_sha256=digest(base_run / "expected_identity.json"),
                       content_version="source-v1:" + generated["identity"]["source_sha256"])
        work_done = True
    except BaseException as error:
        failure(receipt, error)
    finally:
        if state is not None:
            receipt["pins"] = state["pins"]
            verify_post(receipt, "final_pins_passed", lambda: p.verify_pins(state["pins"]))
            verify_post(receipt, "engine_pin_passed", lambda: require(
                digest(state["engine"]) == state["engine_sha256"], "Engine changed"))
            verify_post(receipt, "production_identity_passed", lambda: h.assert_runtime_current(base_run))
            if p.fs(base_run / "preimport_source.json").is_file():
                verify_post(receipt, "final_identity_passed", lambda: require(
                    h.identity.snapshot(project) == read(base_run / "preimport_source.json"), "Source changed after import"))
        if work_done:
            verify_post(receipt, "generated_identity_passed", lambda: h.identity.verify_generated(project, read(base_run / "generation.json")))
        cleanup_lane(receipt, owner, locked)
        receipt["complete"] = bool(work_done and not receipt.get("error") and not receipt.get("postcheck_errors")
                                   and not receipt.get("cleanup_errors") and receipt["lock_released"])
        receipt["cold_import_qualified"] = receipt["complete"]
        save(output / "receipt.json", receipt)
    print(json.dumps({"output": str(output), "complete": receipt["complete"], "error": receipt.get("error"),
                      "cold_import_qualified": receipt["cold_import_qualified"],
                      "lock_released": receipt["lock_released"]}, ensure_ascii=False), flush=True)
    require(receipt["complete"], "Cold import failed; retain evidence and prepare a new freeze")


def prepared_state(base_run):
    """Full new freeze admission with its own first successful cold native import."""
    state = preflight()
    base_run, project, preimport = admission(base_run, state)
    require(h.assert_runtime_current(base_run) == project, "Prepared project path changed")
    generation = read(base_run / "generation.json")
    h.identity.verify_generated(project, generation)
    check_composition(generation["identity"], state)
    require(generation["identity"] == preimport, "New generated and preimport complete identities differ")
    require(read(base_run / "expected_identity.json") == {key: value for key, value in preimport.items()
                                                         if key not in ("files", "directories")},
            "Expected identity must be the exact generated projection")
    attempt = read(base_run / "cold_import_attempt.json")
    output = Path(attempt.get("output", "")).absolute()
    h.identity.no_links(p.fs(output))
    require(output.parent == base_run and output.name.startswith("import_cold__")
            and sorted(item.name for item in p.fs(base_run).iterdir() if item.name.startswith("import")) == [output.name],
            "Exactly one first import directory required")
    receipt = read(output / "receipt.json")
    require(attempt.get("schema") == "projectile_cold_import_attempt_v1"
            and attempt.get("run_base") == str(base_run) and attempt.get("project") == str(project)
            and attempt.get("owner") == str(output) and attempt.get("nonce") == receipt.get("nonce")
            and attempt.get("engine_sha256") == state["engine_sha256"]
            and attempt.get("preimport_sha256") == digest(base_run / "preimport_source.json")
            and attempt.get("candidate_manifest_sha256") == digest(base_run / "candidate_manifest.json")
            and attempt.get("cold_before_sha256") == digest(output / "cold_before.json")
            and read(output / "cold_before.json") == cold_inventory_value(project),
            "Actual first-import attempt and complete before-inventory binding changed")
    require(receipt.get("schema") == IMPORT_SCHEMA and receipt.get("phase") == "import"
            and receipt.get("complete") is True and receipt.get("cold_import_qualified") is True
            and receipt.get("project") == str(project) and receipt.get("run_base") == str(base_run)
            and receipt.get("runner_sha256") == digest(__file__)
            and receipt.get("engine_sha256") == state["engine_sha256"]
            and receipt.get("attempt_sha256") == digest(base_run / "cold_import_attempt.json")
            and receipt.get("cold_before_sha256") == attempt["cold_before_sha256"]
            and receipt.get("cold_inventory_checked_under_owned_lock") is True
            and receipt.get("pins") == state["pins"]
            and receipt.get("generation_sha256") == digest(base_run / "generation.json")
            and receipt.get("expected_identity_sha256") == digest(base_run / "expected_identity.json")
            and all(receipt.get(key) is True for key in ("lock_released", "lock_owner_verified", "engine_lane_idle",
                    "child_terminal", "initial_identity_passed", "final_identity_passed", "final_pins_passed",
                    "engine_pin_passed", "production_identity_passed", "generated_identity_passed"))
            and not receipt.get("error") and not receipt.get("cleanup_errors") and not receipt.get("postcheck_errors"),
            "Successful own locked first cold import and postchecks required")
    steps = receipt.get("steps", [])
    require(len(steps) == 1, "One actual import process required")
    step = steps[0]
    command = [str(state["engine"]), "--path", str(project), "--rendering-method", "gl_compatibility",
               "--headless", "--editor", "--import", "--quit"]
    require(step.get("command") == command and step.get("case") == "import"
            and step.get("passed") is True and type(step.get("pid")) is int and step["pid"] > 0
            and type(step.get("exit_code")) is int and step["exit_code"] == 0
            and step.get("errors") == [] and step.get("stopped_for") is None,
            "Actual pinned-engine headless-editor import/PID/exit required")
    pins = state["pins"]
    for row in state["manifest"]["files"] + state["manifest"]["native_assets"]:
        p.pin(project / row["path"], pins, row["candidate_sha256"])
    for path in (base_run / "cold_import_attempt.json", base_run / "generation.json",
                 base_run / "expected_identity.json", output / "receipt.json", output / "cold_before.json"):
        p.pin(path, pins)
    p.pin(output / "import.log", pins, step["log_sha256"])
    p.verify_pins(pins)
    return {**state, "run_base": base_run, "project": project, "generation": generation,
            "imports": [str(output / "receipt.json")], "content_version": "source-v1:" + preimport["source_sha256"],
            "validation_level": "full_new_freeze_and_own_import", "cold_import_qualified": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--full-preflight", action="store_true", help="Full imported 3365 admission; no copy/engine")
    modes.add_argument("--prepare", action="store_true", help="Own lane, fully verify and create a new cold freeze; no engine")
    modes.add_argument("--import-cold", type=Path, help="Own lane, admit new freeze and run its first cold headless editor import")
    modes.add_argument("--check-run", type=Path, help="Full new-freeze and own first cold-import admission; no engine")
    parser.add_argument("--wait-lane", type=float, default=0, help="Maximum lane wait seconds; default refuses busy lane")
    parser.add_argument("--timeout", type=float, default=1200, help="Cold import child timeout seconds")
    args = parser.parse_args()
    require(args.wait_lane >= 0 and args.timeout > 0, "Positive timeout and nonnegative wait required")
    if args.prepare:
        prepare(args.wait_lane)
        return
    if args.import_cold:
        import_cold(args.import_cold, args.wait_lane, args.timeout)
        return
    state = prepared_state(args.check_run) if args.check_run else preflight() if args.full_preflight else lightweight()
    print(json.dumps({"validation_level": state["validation_level"], "full_source_verified": state["full_source_verified"],
                      "cold_import_qualified": state["cold_import_qualified"], "base_identity": BASE_IDENTITY,
                      "scripts": len(state["manifest"]["files"]), "native_assets": len(state["manifest"]["native_assets"]),
                      "pins": len(state["pins"]), "engine_started": False, "created_freeze": False,
                      "checked_run": str(args.check_run) if args.check_run else None}, ensure_ascii=False))


if __name__ == "__main__":
    main()
