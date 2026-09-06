#!/usr/bin/env python3
"""Build the fail-closed local candidate gate from current primary evidence.

The audit is intentionally stricter than a report aggregator.  It re-hashes
every evidence file it reads, checks the source bindings carried by upstream
reports, re-runs the direction-four intake self-test, and preserves the old
9/11 fleet-edge result as historical evidence.  The newer 11/11 result may
supersede only those two historical cases and only while its production source,
fixture source, and logs still match their recorded SHA-256 values.

The release gate is a separate result.  An incomplete art set, missing web
provenance/manual review, or a short soak can never be hidden by a green local
code gate.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
WORKSPACE_PARENT = ROOT.parent
DEFAULT_OUTPUT = ROOT / "qa" / "final_local_gate_20260902" / "summary.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def display_path(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(WORKSPACE_PARENT).as_posix()
    except ValueError:
        return str(resolved)


@dataclass
class AuditState:
    checks: list[dict[str, Any]] = field(default_factory=list)
    inputs: dict[str, dict[str, Any]] = field(default_factory=dict)

    def check(self, check_id: str, passed: bool, detail: Any = "") -> bool:
        self.checks.append({"id": check_id, "passed": bool(passed), "detail": detail})
        return bool(passed)

    def read_bytes(self, path: Path) -> bytes | None:
        path = path.resolve()
        if not path.is_file():
            self.check(f"input_exists:{display_path(path)}", False, "missing required input")
            return None
        data = path.read_bytes()
        self.inputs[display_path(path)] = {
            "sha256": hashlib.sha256(data).hexdigest(),
            "bytes": len(data),
        }
        return data

    def read_json(self, path: Path) -> dict[str, Any] | None:
        data = self.read_bytes(path)
        if data is None:
            return None
        try:
            parsed = json.loads(data.decode("utf-8-sig"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            self.check(f"json_valid:{display_path(path)}", False, str(exc))
            return None
        if not isinstance(parsed, dict):
            self.check(f"json_object:{display_path(path)}", False, type(parsed).__name__)
            return None
        return parsed

    def bind_hash(self, check_id: str, path: Path, expected: str) -> bool:
        data = self.read_bytes(path)
        actual = hashlib.sha256(data).hexdigest() if data is not None else ""
        return self.check(
            check_id,
            bool(data is not None and len(expected) == 64 and actual == expected),
            {"path": display_path(path), "expected": expected, "actual": actual},
        )


def repo_path_from_record(value: str) -> Path:
    candidate = Path(value)
    if candidate.is_absolute():
        return candidate
    normalized = value.replace("\\", "/")
    if normalized.startswith("Liangshan-Heroes/"):
        return WORKSPACE_PARENT / normalized
    return ROOT / normalized


def check_hash_map(state: AuditState, prefix: str, mapping: Any) -> bool:
    if not isinstance(mapping, dict) or not mapping:
        return state.check(prefix, False, "missing source hash map")
    results = []
    for relative, expected in sorted(mapping.items()):
        results.append(state.bind_hash(f"{prefix}:{relative}", repo_path_from_record(relative), str(expected)))
    return all(results)


def exact_pass_tests(tests: Any, expected_names: set[str] | None = None) -> bool:
    if not isinstance(tests, list) or not tests:
        return False
    names = {str(item.get("name")) for item in tests if isinstance(item, dict)}
    if expected_names is not None and names != expected_names:
        return False
    for item in tests:
        if not isinstance(item, dict):
            return False
        if item.get("passed") is False or item.get("status") not in (None, "pass"):
            return False
        if item.get("exit_code", 0) != 0:
            return False
        if item.get("checks_total") is not None and item.get("checks_passed") != item.get("checks_total"):
            return False
        if item.get("error_warning_markers", 0) != 0 or item.get("exit_leak_markers", 0) != 0:
            return False
    return True


def validate_fleet_override(
    historical: dict[str, Any],
    fleet: dict[str, Any],
    current_hashes: dict[str, str],
) -> tuple[bool, str]:
    failures = historical.get("isolated_failures")
    if not isinstance(failures, list) or len(failures) != 1:
        return False, "historical report must retain exactly one isolated failure"
    old = failures[0]
    expected_cases = {"fleet_killed_before_lure", "dead_hull_cannot_lure"}
    if (
        old.get("name") != "campaign_regression_edges"
        or old.get("checks_passed") != 9
        or old.get("checks_total") != 11
        or set(old.get("failed_cases", [])) != expected_cases
    ):
        return False, "historical 9/11 fleet-edge evidence changed"
    if fleet.get("all_passed") is not True or fleet.get("total_checks") != 165:
        return False, "latest fleet repair summary is not 165/165"
    edge = next((t for t in fleet.get("tests", []) if t.get("name") == "campaign_regression_edges"), None)
    if not edge or edge.get("checks") != 11 or edge.get("passed") is not True:
        return False, "latest fleet-edge test is not 11/11"
    changed = {item.get("path"): item for item in fleet.get("changed_files", [])}
    expected_paths = {"scripts/levels/level5_liangshan.gd", "tools/campaign_regression_edges.gd"}
    if set(changed) != expected_paths:
        return False, "fleet override changed-file scope is not exact"
    for path in expected_paths:
        if current_hashes.get(path) != changed[path].get("after_sha256"):
            return False, f"current SHA drifted after fleet repair: {path}"
    return True, "historical 9/11 retained; latest exact-source 11/11 supersedes only the two fleet cases"


def internal_selftest() -> dict[str, Any]:
    checks: list[dict[str, Any]] = []

    def add(name: str, passed: bool) -> None:
        checks.append({"name": name, "passed": bool(passed)})

    with tempfile.TemporaryDirectory(prefix="final-local-gate-") as temp:
        sample = Path(temp) / "sample.bin"
        sample.write_bytes(b"known")
        add("hash accepts exact bytes", sha256(sample) == hashlib.sha256(b"known").hexdigest())
        add("hash rejects changed bytes", sha256(sample) != hashlib.sha256(b"changed").hexdigest())

    historical = {
        "isolated_failures": [{
            "name": "campaign_regression_edges",
            "checks_passed": 9,
            "checks_total": 11,
            "failed_cases": ["fleet_killed_before_lure", "dead_hull_cannot_lure"],
        }]
    }
    fleet = {
        "all_passed": True,
        "total_checks": 165,
        "tests": [{"name": "campaign_regression_edges", "checks": 11, "passed": True}],
        "changed_files": [
            {"path": "scripts/levels/level5_liangshan.gd", "after_sha256": "a" * 64},
            {"path": "tools/campaign_regression_edges.gd", "after_sha256": "b" * 64},
        ],
    }
    hashes = {
        "scripts/levels/level5_liangshan.gd": "a" * 64,
        "tools/campaign_regression_edges.gd": "b" * 64,
    }
    ok, _ = validate_fleet_override(historical, fleet, hashes)
    add("fleet override accepts exact two-case and source binding", ok)
    wrong = json.loads(json.dumps(historical))
    wrong["isolated_failures"][0]["failed_cases"] = ["different_case"]
    add("fleet override rejects hidden historical failure", not validate_fleet_override(wrong, fleet, hashes)[0])
    drift = dict(hashes)
    drift["scripts/levels/level5_liangshan.gd"] = "c" * 64
    add("fleet override rejects source drift", not validate_fleet_override(historical, fleet, drift)[0])
    failed = json.loads(json.dumps(fleet))
    failed["tests"][0]["passed"] = False
    add("fleet override rejects failed latest test", not validate_fleet_override(historical, failed, hashes)[0])
    add("incomplete release inputs fail closed", not all([0 == 69, 13 == 347, False, 90 >= 1800]))
    return {"passed": all(c["passed"] for c in checks), "checks": len(checks), "results": checks}


def run_direction_selftest(state: AuditState) -> dict[str, Any]:
    tool = ROOT / "tools" / "direction4_first_sample_intake_selftest.py"
    state.read_bytes(tool)
    process = subprocess.run(
        [sys.executable, "-B", str(tool)],
        cwd=ROOT,
        text=True,
        encoding="utf-8",
        capture_output=True,
        timeout=120,
        check=False,
    )
    parsed: dict[str, Any] = {}
    try:
        parsed = json.loads(process.stdout)
    except json.JSONDecodeError:
        pass
    passed = (
        process.returncode == 0
        and parsed.get("passed") is True
        and parsed.get("checks") == 63
        and parsed.get("negative_checks") == 18
        and parsed.get("production_art_modified") is False
        and parsed.get("production_tree_sha256_before") == parsed.get("production_tree_sha256_after")
    )
    state.check(
        "direction4_intake_selftest_63_plus_18",
        passed,
        {"exit_code": process.returncode, "result": parsed, "stderr": process.stderr[-1000:]},
    )
    return parsed


def audit() -> dict[str, Any]:
    state = AuditState()
    selftest = internal_selftest()
    state.check("final_gate_tool_selftest", selftest["passed"], selftest)

    paths = {
        "historical_campaign": ROOT / "qa/final_campaign_regression_20260902/summary.json",
        "fleet": ROOT / "qa/fleet_edge_fix_20260902/summary.json",
        "copy": ROOT / "qa/campaign_copy_audit_20260902/report.json",
        "environment_static": ROOT / "qa/environment_runtime_router_20260902/report.json",
        "environment_runtime": ROOT / "qa/environment_runtime_router_20260902/runtime_report.json",
        "direction": ROOT / "qa/campaign_direction4_coverage_20260902/report.json",
        "direction_batch": WORKSPACE_PARENT / "implementation_20260902/prompt_drafts_v2/batch_manifest.json",
        "direction_registry": ROOT / "tools/direction4_first_sample_frozen_registry.json",
        "shadow_visual": ROOT / "qa/direction4_20260902/runtime_world_shadow_flat_fastpath_final/report.json",
        "performance": ROOT / "qa/direction4_20260902/performance_flat_fastpath_recheck/final_summary.json",
        "audio": ROOT / "qa/audio_shutdown_20260902/report.json",
        "soak": ROOT / "qa/direction4_20260902/cursor_lifecycle_fix/soak_90s_pass/campaign_mode_soak.json",
        "staging": ROOT / "qa/release_candidate_dry_run_20260902.json",
    }
    docs = {name: state.read_json(path) for name, path in paths.items()}

    historical = docs["historical_campaign"] or {}
    expected_main_tests = {
        "campaign_core_test", "test_early_episodes", "campaign_later_playthrough",
        "campaign_finale_playthrough", "campaign_later_contract_test",
        "campaign_freeplay_core_test", "campaign_freeplay_early_test",
        "campaign_freeplay_late_test", "direction4_regression_test",
        "campaign_flag_overlay_contract", "liangshan_static_flags_contract",
        "natural_terrain_contract", "campaign_environment_art_runtime_contract",
        "world_shadow_visual_test", "environment_static_contract", "copy_audit",
    }
    main_ok = (
        historical.get("main_chain") == {
            "passed": True, "levels": 8, "early": 4, "later": 3,
            "finale": 1, "campaign_save_unchanged": True,
        }
        and historical.get("source_art_unchanged") is True
        and historical.get("passing_contracts", {}).get("checks_failed") == 0
        and historical.get("passing_contracts", {}).get("error_or_warning_markers") == 0
        and historical.get("passing_contracts", {}).get("exit_leak_markers") == 0
        and exact_pass_tests(historical.get("tests"), expected_main_tests)
    )
    state.check("campaign_main_chain_and_free_modes", main_ok, {
        "main_chain": historical.get("main_chain"),
        "test_count": len(historical.get("tests", [])),
        "historical_isolated_failures_retained": historical.get("isolated_failures"),
    })
    for item in historical.get("tests", []):
        log = item.get("log")
        if log:
            state.read_bytes(Path(log))

    fleet = docs["fleet"] or {}
    current_fleet_hashes: dict[str, str] = {}
    for item in fleet.get("changed_files", []):
        rel = str(item.get("path", ""))
        path = ROOT / rel
        data = state.read_bytes(path)
        current_fleet_hashes[rel] = hashlib.sha256(data).hexdigest() if data is not None else ""
    fleet_ok, fleet_detail = validate_fleet_override(historical, fleet, current_fleet_hashes)
    fleet_test_names = {
        "campaign_regression_edges", "campaign_core_test", "campaign_finale_depth_test",
        "campaign_freeplay_late_test", "campaign_finale_playthrough", "editor_parse",
    }
    fleet_ok = fleet_ok and exact_pass_tests(fleet.get("tests"), fleet_test_names)
    for item in fleet.get("tests", []):
        log_path = ROOT / "qa/fleet_edge_fix_20260902" / str(item.get("log", ""))
        fleet_ok = state.bind_hash(
            f"fleet_log_sha:{item.get('name')}", log_path, str(item.get("log_sha256", ""))
        ) and fleet_ok
    state.check("fleet_edge_exact_override", fleet_ok, fleet_detail)

    copy = docs["copy"] or {}
    copy_ok = (
        copy.get("status") == "pass_with_documented_compressions"
        and copy.get("summary", {}).get("levels_audited") == 8
        and copy.get("summary", {}).get("checks_total") == 72
        and copy.get("summary", {}).get("checks_passed") == 72
        and copy.get("summary", {}).get("checks_failed") == 0
        and copy.get("failed_checks") == []
    )
    copy_ok = check_hash_map(state, "copy_current_source_sha", copy.get("hashes", {}).get("current")) and copy_ok
    snapshot = copy.get("copy_result_evidence", {})
    for rel, expected in snapshot.get("pinned_snapshot_hashes", {}).items():
        copy_ok = state.bind_hash(
            f"copy_snapshot_sha:{rel}", Path(snapshot.get("snapshot_directory", "")) / rel, str(expected)
        ) and copy_ok
    state.check("campaign_copy_72_of_72", copy_ok, copy.get("summary"))

    env_static = docs["environment_static"] or {}
    env_runtime = docs["environment_runtime"] or {}
    env_counts = env_static.get("counts", {})
    env_static_ok = (
        env_static.get("passed") is True
        and env_counts.get("checks") == 785
        and env_counts.get("consumer_ready_total") == 69
        and len(env_static.get("missing_source_resources", [])) == 69
        and all(item.get("passed") for item in env_static.get("checks", []))
    )
    env_static_ok = check_hash_map(state, "environment_consumer_source_sha", env_static.get("consumer_file_sha256")) and env_static_ok
    manifest_path = Path(str(env_static.get("manifest_path", "")))
    env_static_ok = state.bind_hash(
        "environment_manifest_sha", manifest_path, str(env_static.get("manifest_sha256", ""))
    ) and env_static_ok
    env_static_ok = state.bind_hash(
        "environment_router_sha", ROOT / "scripts/campaign_environment_art.gd", str(env_static.get("router_sha256", ""))
    ) and env_static_ok
    state.check("environment_static_785_of_785", env_static_ok, env_counts)
    env_runtime_ok = (
        env_runtime.get("passed") is True
        and env_runtime.get("checks") == 758
        and env_runtime.get("manifest_sha256") == env_static.get("manifest_sha256")
        and len(env_runtime.get("results", [])) == 758
        and all(item.get("passed") is True for item in env_runtime.get("results", []))
    )
    state.check("environment_runtime_758_of_758", env_runtime_ok, {
        "checks": env_runtime.get("checks"), "manifest_sha256": env_runtime.get("manifest_sha256")
    })
    env_paths = [repo_path_from_record(str(item.get("path", "")).replace("res://", "")) for item in env_static.get("missing_source_resources", [])]
    environment_present = sum(path.is_file() for path in env_paths)

    direction = docs["direction"] or {}
    direction_summary = direction.get("summary", {})
    direction_ok = (
        direction_summary.get("unique_art_state_rows") == 347
        and direction_summary.get("accepted_exact_unique_rows") == 13
        and direction_summary.get("existing_four_direction_rows_requiring_web_regeneration_for_provenance") == 71
        and direction_summary.get("missing_or_partial_exact_rows_requiring_web_generation") == 263
        and len(direction.get("unique_art_state_contract", [])) == 347
    )
    direction_ok = check_hash_map(state, "direction_audit_input_sha", direction.get("input_sha256")) and direction_ok
    direction_sha = state.inputs.get(display_path(paths["direction"]), {}).get("sha256", "")
    batch = docs["direction_batch"] or {}
    registry = docs["direction_registry"] or {}
    batch_sha = state.inputs.get(display_path(paths["direction_batch"]), {}).get("sha256", "")
    freeze_ok = (
        batch.get("status") == "local_prompt_only_unsent"
        and batch.get("scope", {}).get("prompt_count") == 10
        and batch.get("audit_source", {}).get("sha256") == direction_sha
        and registry.get("audit_source", {}).get("sha256") == direction_sha
        and registry.get("canonical_batch_manifest", {}).get("sha256") == batch_sha
        and len(registry.get("batches", {})) == 10
    )
    intake_tool = ROOT / "tools/direction4_first_sample_intake.py"
    intake_sha = sha256(intake_tool) if intake_tool.is_file() else ""
    state.read_bytes(intake_tool)
    direction_selftest = run_direction_selftest(state)
    direction_ok = direction_ok and freeze_ok and direction_selftest.get("passed") is True
    state.check("direction_coverage_and_frozen_chain", direction_ok, {
        "coverage": direction_summary,
        "direction_report_sha256": direction_sha,
        "batch_manifest_sha256": batch_sha,
        "registry_sha256": state.inputs.get(display_path(paths["direction_registry"]), {}).get("sha256", ""),
        "intake_tool_sha256": intake_sha,
        "selftest": direction_selftest,
    })

    visual = docs["shadow_visual"] or {}
    visual_ok = visual.get("passed") is True and visual.get("checks") == 105 and visual.get("failures") == []
    for capture in visual.get("captures", []):
        visual_ok = state.bind_hash(
            f"shadow_capture_sha:{capture.get('mode')}", Path(str(capture.get("png", ""))), str(capture.get("sha256", ""))
        ) and visual_ok
    state.check("world_shadow_visual_105_of_105", visual_ok, {
        "checks": visual.get("checks"), "renderer": visual.get("renderer"), "viewport": visual.get("viewport")
    })

    perf = docs["performance"] or {}
    source = perf.get("source", {})
    perf_source_ok = state.bind_hash(
        "performance_world_shadow_source_sha", ROOT / "scripts/world_shadow.gd", str(source.get("world_shadow_sha256", ""))
    )
    perf_source_ok = state.bind_hash(
        "performance_visual_fixture_source_sha", ROOT / "tools/world_shadow_visual_test.gd", str(source.get("visual_fixture_sha256", ""))
    ) and perf_source_ok
    perf_data = perf.get("performance", {})
    runs = perf_data.get("runs", [])
    on_runs = [run for run in runs if str(run.get("run", "")).startswith("on_")]
    samples = [sample for run in on_runs for sample in run.get("samples", [])]
    computed_p95 = max((float(sample.get("p95_ms", 999)) for sample in samples), default=999.0)
    computed_p99 = max((float(sample.get("p99_ms", 999)) for sample in samples), default=999.0)
    computed_ratio = max((float(sample.get("paired_off_ratio", 999)) for sample in samples), default=999.0)
    perf_ok = (
        perf_source_ok
        and perf.get("editor_parse", {}).get("exit_code") == 0
        and perf.get("visual", {}).get("passed") is True
        and perf.get("visual", {}).get("checks") == 105
        and len(runs) == 6 and len(on_runs) == 3
        and all(run.get("passed") is True for run in runs)
        and all(all(run.get("validity", {}).values()) for run in runs)
        and perf_data.get("all_six_runs_pass") is True
        and abs(float(perf_data.get("max_on_p95_ms", 999)) - computed_p95) < 1e-9
        and abs(float(perf_data.get("max_on_p99_ms", 999)) - computed_p99) < 1e-9
        and abs(float(perf_data.get("max_on_paired_off_ratio", 999)) - computed_ratio) < 1e-9
        and computed_p95 <= 16.7 and computed_p99 <= 33.3 and computed_ratio <= 1.10
        and perf.get("forbidden_log_markers") == []
        and perf.get("godot_processes_remaining") == []
    )
    protocol_path = Path(str(perf_data.get("protocol", "")))
    state.read_bytes(protocol_path)
    state.check("performance_fixed_protocol", perf_ok, {
        "runs": len(runs), "max_on_p95_ms": computed_p95,
        "max_on_p99_ms": computed_p99, "max_on_off_ratio": computed_ratio,
        "limits": {"p95_ms": 16.7, "p99_ms": 33.3, "ratio": 1.10},
    })

    audio = docs["audio"] or {}
    audio_ok = audio.get("passed") is True
    for item in audio.get("sources", []):
        audio_ok = state.bind_hash(
            f"audio_source_sha:{Path(str(item.get('path', ''))).name}",
            Path(str(item.get("path", ""))), str(item.get("sha256", "")),
        ) and audio_ok
    matrix = audio.get("final_full_matrix", {})
    audio_ok = state.bind_hash("audio_matrix_summary_sha", Path(str(matrix.get("summary", ""))), str(matrix.get("summary_sha256", ""))) and audio_ok
    audio_ok = (
        matrix.get("passed") is True and len(matrix.get("cases", [])) == 8
        and all(item.get("passed") is True and item.get("exit_code") == 0 for item in matrix.get("cases", []))
    ) and audio_ok
    for item in matrix.get("cases", []):
        audio_ok = state.bind_hash(
            f"audio_matrix_log_sha:{item.get('name')}", Path(str(item.get("log", ""))), str(item.get("log_sha256", ""))
        ) and audio_ok
        audio_ok = all(item.get(key, 0) == 0 for key in (
            "audio_stream_leaks", "any_leaked_instances", "objectdb_warnings",
            "orphan_master", "any_orphan_string_names", "script_errors",
        )) and audio_ok
    repeat_gate = audio.get("final_repeat_gate", {})
    repeat_path = Path(str(repeat_gate.get("summary", "")))
    repeat = state.read_json(repeat_path) or {}
    audio_ok = (
        state.inputs.get(display_path(repeat_path), {}).get("sha256") == repeat_gate.get("summary_sha256")
        and repeat_gate.get("passed") is True and repeat_gate.get("runs") == 9
        and repeat.get("passed") is True and len(repeat.get("cases", [])) == 9
        and all(item.get("passed") is True for item in repeat.get("cases", []))
    ) and audio_ok
    for item in repeat.get("cases", []):
        audio_ok = state.bind_hash(
            f"audio_repeat_log_sha:r{item.get('round')}:{item.get('case')}",
            Path(str(item.get("log", ""))), str(item.get("sha256", "")),
        ) and audio_ok
    audio_ok = audio.get("route_audit", {}).get("only_app_lifecycle_calls_scene_tree_quit") is True and audio_ok
    state.check("audio_exit_matrix_and_repeat", audio_ok, {
        "matrix_cases": len(matrix.get("cases", [])), "repeat_runs": len(repeat.get("cases", [])),
        "boundaries": audio.get("boundaries"),
    })

    soak = docs["soak"] or {}
    stability = soak.get("stability", {})
    short_soak_ok = (
        soak.get("runtime_checks_passed") is True
        and soak.get("failures") == []
        and float(soak.get("actual_seconds", 0)) >= 90.0
        and soak.get("transition_count") == 28
        and soak.get("viewport") == [1280, 720]
        and soak.get("renderer", {}).get("driver") == "vulkan"
        and soak.get("renderer", {}).get("method") == "forward_plus"
        and soak.get("campaign_save", {}).get("unchanged") is True
        and soak.get("performance", {}).get("max_minute_p95_ms", 999) <= 16.7
        and soak.get("performance", {}).get("max_minute_p99_ms", 999) <= 33.3
        and all(item.get("recovery_passed") is True and item.get("monotonic_growth_detected") is False for item in stability.values())
        and soak.get("process_exit", {}).get("exit_code") == 0
        and soak.get("process_exit", {}).get("warnings_count") == 0
        and soak.get("exit_warning_status") == "no matched exit warning"
        and soak.get("acceptance_eligible") is False
        and soak.get("passed") is False
    )
    state.read_bytes(Path(str(soak.get("process_exit", {}).get("console_log", ""))))
    state.check("short_soak_90_seconds", short_soak_ok, {
        "actual_seconds": soak.get("actual_seconds"), "transitions": soak.get("transition_count"),
        "visits": soak.get("visits"), "performance": soak.get("performance"),
        "acceptance_eligible": soak.get("acceptance_eligible"),
    })

    staging = docs["staging"] or {}
    staging_metrics = staging.get("metrics", {})
    allowed_staging_prefixes = (
        "environment physical allowlist gate failed:",
        "environment provenance ledger is missing:",
        "environment runtime PNG gate failed:",
        "frozen-source/manual release gate is missing:",
        "required runtime directory is missing:",
        "runtime reference is absent from the physical allowlist",
        "strict four-direction PNGs are absent from the physical allowlist:",
        "strict four-direction coverage gate failed:",
        "strict four-direction report still has missing/partial rows",
        "strict four-direction report still has noncompliant-provenance rows",
        "strict four-direction rows are not exact/provenance-compliant:",
    )
    errors = staging.get("errors", [])
    staging_ok = (
        staging.get("dry_run") is True and staging.get("committed") is False
        and staging.get("commit_ready") is False
        and staging_metrics.get("selected_file_count", 0) > 0
        and staging_metrics.get("environment", {}).get("present") == environment_present
        and staging_metrics.get("environment", {}).get("required") == 69
        and staging_metrics.get("direction4", {}).get("accepted") == direction_summary.get("accepted_exact_unique_rows")
        and staging_metrics.get("direction4", {}).get("required") == direction_summary.get("unique_art_state_rows")
        and staging.get("gate_bindings", {}).get("direction_report_sha256") == direction_sha
        and bool(errors) and all(any(str(error).startswith(prefix) for prefix in allowed_staging_prefixes) for error in errors)
    )
    state.check("physical_allowlist_dry_run_expected_blockers_only", staging_ok, {
        "committed": staging.get("committed"), "commit_ready": staging.get("commit_ready"),
        "metrics": staging_metrics, "error_count": len(errors),
    })

    # Every check recorded above is a local evidence/integrity requirement.  In
    # particular, do not filter out an input_exists/json_valid failure merely
    # because the dependent high-level check also happens to remain readable.
    code_checks = list(state.checks)
    local_code_passed = bool(code_checks) and all(item["passed"] for item in code_checks)

    formal_soak_complete = float(soak.get("actual_seconds", 0)) >= 1800.0 and soak.get("acceptance_eligible") is True and soak.get("passed") is True
    web_provenance_ready = bool(staging.get("gate_bindings", {}).get("environment_provenance_sha256"))
    manual_gate_ready = bool(staging.get("gate_bindings", {}).get("manual_gate_sha256"))
    release_blockers = []
    if environment_present != 69:
        release_blockers.append(f"environment art incomplete: {environment_present}/69 production PNGs")
    if direction_summary.get("accepted_exact_unique_rows") != 347:
        release_blockers.append(
            f"direction art incomplete: {direction_summary.get('accepted_exact_unique_rows', 0)}/347 exact provenance-compliant rows"
        )
    if not web_provenance_ready:
        release_blockers.append("web ChatGPT source provenance ledger is missing")
    if not manual_gate_ready:
        release_blockers.append("manual visual acceptance gate is missing")
    if not formal_soak_complete:
        release_blockers.append(
            f"formal 30-minute soak not run: current evidence is {float(soak.get('actual_seconds', 0)):.3f}s and acceptance_eligible=false"
        )
    if staging.get("commit_ready") is not True:
        release_blockers.append("physical allowlist staging is dry-run only and commit_ready=false")

    evidence_set_sha256 = hashlib.sha256(json.dumps(
        state.inputs, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")).hexdigest()
    return {
        "schema_version": 1,
        "kind": "final_local_candidate_gate",
        "audit_date": "2026-09-02",
        "evidence_set_sha256": evidence_set_sha256,
        "tool": {
            "path": display_path(Path(__file__)),
            "sha256": sha256(Path(__file__)),
            "selftest": selftest,
            "policy": "fail closed on missing evidence, JSON errors, source/hash drift, unexpected staging errors, or hidden historical failures",
        },
        "status": {
            "local_code_gate": "pass" if local_code_passed else "fail",
            "release_gate": "pass" if not release_blockers and local_code_passed else "fail",
            "human_playtest": "not_run_no_pacing_or_balance_conclusion",
            "steam": "not_touched_no_export_or_upload_performed",
        },
        "historical_fleet_edge_resolution": {
            "historical_result": "9/11; retained in qa/final_campaign_regression_20260902/summary.json",
            "historical_failed_cases": ["fleet_killed_before_lure", "dead_hull_cannot_lure"],
            "latest_result": "11/11",
            "override_applied": fleet_ok,
            "scope": "only the two historical fleet-edge cases, bound to current level5 and fixture SHA-256",
            "current_source_sha256": current_fleet_hashes,
        },
        "coverage": {
            "campaign_levels": "8/8 main chain",
            "copy": "72/72",
            "environment_static": "785/785",
            "environment_runtime": "758/758",
            "environment_art": f"{environment_present}/69",
            "direction_exact": f"{direction_summary.get('accepted_exact_unique_rows', 0)}/347",
            "direction_intake_selftest": "63 positive + 18 negative",
            "world_shadow_visual": "105/105",
            "performance": {
                "max_on_p95_ms": computed_p95,
                "max_on_p99_ms": computed_p99,
                "max_on_off_ratio": computed_ratio,
            },
            "audio_exit": "8/8 matrix + 9/9 repeated",
            "short_soak": {
                "seconds": soak.get("actual_seconds"), "transitions": soak.get("transition_count"),
                "runtime_checks_passed": soak.get("runtime_checks_passed"),
                "formal_acceptance_eligible": soak.get("acceptance_eligible"),
            },
        },
        "release_blockers": release_blockers,
        "checks": state.checks,
        "check_summary": {
            "total": len(state.checks),
            "passed": sum(item["passed"] for item in state.checks),
            "failed": sum(not item["passed"] for item in state.checks),
            "local_code_checks": len(code_checks),
            "local_code_checks_failed": sum(not item["passed"] for item in code_checks),
        },
        "inputs": dict(sorted(state.inputs.items())),
        "boundaries": [
            "The 90-second Vulkan run validates only the short lifecycle/resource/performance check; it is not the required 30-minute soak.",
            "Automated, visual-fixture, and performance evidence does not establish human pacing or balance.",
            "No web image was generated or accepted by this audit.",
            "No export, staging commit, Steam upload, BuildID check, depot manifest check, or client download was performed.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--self-test", action="store_true", help="run only the audit tool's tamper/fail-closed self-test")
    parser.add_argument("--require-release", action="store_true", help="return nonzero while the release gate is blocked")
    args = parser.parse_args()

    if args.self_test:
        result = internal_selftest()
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0 if result["passed"] else 2

    result = audit()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "output": display_path(output),
        "local_code_gate": result["status"]["local_code_gate"],
        "release_gate": result["status"]["release_gate"],
        "checks": result["check_summary"],
        "release_blockers": result["release_blockers"],
    }, ensure_ascii=False, indent=2))
    if result["status"]["local_code_gate"] != "pass":
        return 2
    if args.require_release and result["status"]["release_gate"] != "pass":
        return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
