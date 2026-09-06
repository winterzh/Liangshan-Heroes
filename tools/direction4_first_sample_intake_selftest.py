"""Read-only/temporary negative tests for the first Web direction4 intake gate."""
from __future__ import annotations

import copy
import dataclasses
import hashlib
import importlib.util
import json
import sys
import tempfile
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools/direction4_first_sample_intake.py"
SLICER_MODULE_PATH = ROOT / "tools/direction4_web_state_slice.py"


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load intake module")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


M = load_module("direction4_first_sample_intake_under_test", MODULE_PATH)
S = load_module("direction4_web_state_slice_under_test", SLICER_MODULE_PATH)
CHECKS: list[dict[str, object]] = []
NEGATIVE_CHECKS = 0


def check(condition: bool, label: str) -> None:
    CHECKS.append({"label": label, "passed": bool(condition)})
    if not condition:
        raise AssertionError(label)


def expect_failure(label: str, needle: str, action) -> None:
    global NEGATIVE_CHECKS
    NEGATIVE_CHECKS += 1
    try:
        action()
    except M.IntakeError as error:
        check(needle in str(error), label + " -> " + str(error))
    else:
        raise AssertionError(label + " did not fail")


def fake_sha(label: str) -> str:
    return hashlib.sha256(label.encode("utf-8")).hexdigest()


def tree_digest(roots: tuple[Path, ...]) -> str:
    digest = hashlib.sha256()
    for root in roots:
        for path in sorted((item for item in root.rglob("*") if item.is_file()), key=lambda item: str(item).lower()):
            digest.update(path.relative_to(M.ROOT).as_posix().encode("utf-8"))
            digest.update(b"\0")
            digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def measurements(batch, cell_height: int = 100) -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    for row, identity in enumerate(batch.rows):
        for direction in M.DIRECTIONS:
            result.append(
                {
                    "art_identity": identity,
                    "direction": direction,
                    "measurement_kind": batch.anchor_kind,
                    "source_y_px": row * cell_height + round(cell_height * M.ANCHOR_FRACTION),
                    "note": "逐格人工像素测量",
                }
            )
    return result


def source_manifest(temp: Path, batches) -> tuple[Path, dict[str, object], dict[str, str]]:
    roots = [temp / name for name in ("downloads", "accepted", "rejected")]
    for root in roots:
        root.mkdir(parents=True)
    selected_ids: dict[str, str] = {}
    selected_shas: dict[str, str] = {}
    entries: list[dict[str, object]] = []
    idle_shas: dict[str, str] = {}
    urls = {
        "heroes": "https://chatgpt.com/c/11111111-1111-1111-1111-111111111111",
        "troops": "https://chatgpt.com/c/22222222-2222-2222-2222-222222222222",
    }
    for batch in batches:
        source_sha = fake_sha("adopt:" + batch.atlas_id)
        selected_shas[batch.atlas_id] = source_sha
        if batch.design_state == "idle":
            idle_shas[batch.group] = source_sha
        attempt_id = f"{batch.atlas_id}:{source_sha}"
        selected_ids[batch.atlas_id] = attempt_id
        review = {flag: True for flag in M.REQUIRED_REVIEW_FLAGS}
        entries.append(
            {
                "attempt_id": attempt_id,
                "atlas_id": batch.atlas_id,
                "source_png": str(roots[1] / f"{batch.atlas_id}.png"),
                "source_sha256": source_sha,
                "size": [400, 400],
                "conversation_url": urls[batch.group],
                "prompt_sha256": batch.prompt_sha256,
                "group": batch.group,
                "design_state": batch.design_state,
                "directions": list(M.DIRECTIONS),
                "rows": list(batch.rows),
                "decision": "adopt",
                "reason": "逐项复核身份方向透明与装备均符合本批合同",
                "human_review": review,
                "anchor_measurements": measurements(batch),
                "reference_idle_sha256": "" if batch.design_state == "idle" else idle_shas[batch.group],
                "attached_reference_sha256s": [item["sha256"] for item in batch.local_references],
            }
        )

    rejected_sha = fake_sha("rejected:sample_heroes_idle")
    rejected_review = {flag: True for flag in M.REQUIRED_REVIEW_FLAGS}
    rejected_review["no_text_or_watermark_confirmed"] = False
    entries.append(
        {
            **copy.deepcopy(entries[0]),
            "attempt_id": f"sample_heroes_idle:{rejected_sha}",
            "source_png": str(roots[2] / "sample_heroes_idle_rejected.png"),
            "source_sha256": rejected_sha,
            "decision": "reject",
            "reason": "右上单元带网页水印且背景并非真正透明",
            "human_review": rejected_review,
            "anchor_measurements": [],
        }
    )
    payload: dict[str, object] = {
        "schema_version": 2,
        "kind": "web_chatgpt_direction4_first_sample_sources_v2",
        "frozen_batch_manifest_sha256": M.load_frozen_registry()["canonical_batch_manifest"]["sha256"],
        "attempt_sidecar_dir": "attempts",
        "attempt_roots": ["downloads", "accepted", "rejected"],
        "selected_attempt_ids": selected_ids,
        "entries": entries,
    }
    path = temp / "source_manifest.json"
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return path, payload, selected_shas


def fake_slicer_plan(batch) -> dict[str, object]:
    seams = {
        "vertical": [{"gap": 24, "max_alpha": 0} for _ in range(3)],
        "horizontal": [{"gap": 24, "max_alpha": 0} for _ in range(3)],
    }
    outputs: list[dict[str, object]] = []
    for row, identity in enumerate(batch.rows):
        for column, direction in enumerate(M.DIRECTIONS):
            outputs.append(
                {
                    "unit": identity,
                    "state": batch.runtime_state,
                    "direction": direction,
                    "layout": "grid",
                    "excluded_foreign_pixels": 0,
                    "isolation": (
                        "Audited transparent-seam grid cell; one rectangular alpha-content crop is copied whole, "
                        "including detached props, with no in-crop pixel masking."
                    ),
                    "selected_seams": seams,
                    "source_cell": [column * 100, row * 100, 100, 100],
                    "source_region": [column * 100, row * 100, 100, 100],
                    "row_scale": 0.5,
                    "output_size": [50, 50],
                    "paste_xy": [103, 169],
                    "canvas_size": [256, 256],
                    "placement_reference": {
                        "kind": "manual_source_pixel_semantic_anchor",
                        "measurement_kind": batch.anchor_kind,
                        "source_y_px": row * 100 + 82,
                        "source_offset_y_px": 82,
                        "target_fraction": 0.82,
                        "target_output_y_px": 210,
                        "placed_output_y_px": 210,
                        "tolerance_px": 3,
                        "semantic_anchor_evidence": True,
                    },
                    "alpha_bbox_bottom_reference": {
                        "kind": "source_alpha_bbox_bottom_only",
                        "output_y_px": 219,
                        "semantic_anchor_evidence": False,
                    },
                }
            )
    return {"outputs": outputs}


def exercise_commit_case(root: Path, batch, base_entry, fail_result: bool) -> None:
    input_dir = root / "input"
    input_dir.mkdir(parents=True)
    source_payload = b"temporary-source-atlas-bytes"
    prompt_payload = b"temporary prompt bytes"
    source_path = input_dir / "source.png"
    prompt_path = input_dir / "prompt.txt"
    source_manifest_path = input_dir / "source_manifest.json"
    batch_manifest_path = M.DEFAULT_BATCH_MANIFEST
    source_path.write_bytes(source_payload)
    prompt_path.write_bytes(prompt_payload)
    source_manifest_path.write_text("{\"schema_version\":2}\n", encoding="utf-8")
    source_sha = hashlib.sha256(source_payload).hexdigest()
    prompt_sha = hashlib.sha256(prompt_payload).hexdigest()
    test_batch = dataclasses.replace(
        batch,
        prompt_path=prompt_path,
        prompt_sha256=prompt_sha,
        local_references=(),
    )
    test_entry = dataclasses.replace(
        base_entry,
        attempt_id=f"{batch.atlas_id}:{source_sha}",
        source_path=source_path,
        source_sha256=source_sha,
        prompt_sha256=prompt_sha,
        attached_reference_sha256s=(),
    )
    output_dir = root / "production" / "anim"
    source_archive_root = root / "production" / "source"
    prompt_archive_root = root / "production" / "prompts"
    reference_archive_root = root / "production" / "references"
    production_manifest = root / "production" / "direction4_manifest.json"
    checkpoint_root = root / "checkpoints"
    initial_manifest_payload = b'{"schema_version":1,"sources":{},"outputs":[]}\n'
    production_manifest.parent.mkdir(parents=True)
    production_manifest.write_bytes(initial_manifest_payload)
    first_name = f"{batch.rows[0]}_{batch.runtime_state}_{M.DIRECTIONS[0]}.png"
    first_target = output_dir / first_name
    initial_first_payload = b"preexisting-output"
    if fail_result:
        first_target.parent.mkdir(parents=True)
        first_target.write_bytes(initial_first_payload)

    source_archive = source_archive_root / "source.png"
    prompt_archive = prompt_archive_root / "prompt.txt"
    payloads = {
        f"{identity}_{batch.runtime_state}_{direction}.png":
            f"temporary:{identity}:{batch.runtime_state}:{direction}".encode("utf-8")
        for identity in batch.rows
        for direction in M.DIRECTIONS
    }
    normalized_outputs = [
        {"unit": identity, "state": batch.runtime_state, "direction": direction}
        for identity in batch.rows
        for direction in M.DIRECTIONS
    ]
    plan = {
        "source_manifest_sha256": M.sha256_file(source_manifest_path),
        "batch_manifest_sha256": M.sha256_file(batch_manifest_path),
        "_source_hashes": {batch.atlas_id: source_sha},
        "_prompt_hashes": {batch.atlas_id: prompt_sha},
        "_attempt_hashes": {str(source_path): source_sha},
        "_sidecar_hashes": {},
        "_prestate": {},
        "_production_manifest": {"schema_version": 1, "sources": {}, "outputs": []},
        "_generated": {
            batch.atlas_id: {
                "source_id": "temporary-source",
                "source_archive": source_archive,
                "prompt_archive": prompt_archive,
                "reference_archives": [],
                "source_payload": source_payload,
                "prompt_payload": prompt_payload,
                "reference_payloads": [],
                "source_record": {},
                "normalized_outputs": normalized_outputs,
                "payloads": payloads,
            }
        },
    }
    patched = {
        "DEFAULT_OUTPUT_DIR": output_dir,
        "DEFAULT_SOURCE_ARCHIVE": source_archive_root,
        "DEFAULT_PROMPT_ARCHIVE": prompt_archive_root,
        "DEFAULT_REFERENCE_ARCHIVE": reference_archive_root,
        "DEFAULT_PRODUCTION_MANIFEST": production_manifest,
        "DEFAULT_CHECKPOINT_ROOT": checkpoint_root,
        "post_commit_coverage_check": M.post_commit_coverage_check,
        "atomic_write": M.atomic_write,
    }
    original_atomic_write = M.atomic_write
    try:
        M.DEFAULT_OUTPUT_DIR = output_dir
        M.DEFAULT_SOURCE_ARCHIVE = source_archive_root
        M.DEFAULT_PROMPT_ARCHIVE = prompt_archive_root
        M.DEFAULT_REFERENCE_ARCHIVE = reference_archive_root
        M.DEFAULT_PRODUCTION_MANIFEST = production_manifest
        M.DEFAULT_CHECKPOINT_ROOT = checkpoint_root
        M.post_commit_coverage_check = lambda: {
            "accepted_identity_state_rows": 4,
            "expected_identity_state_rows": 4,
            "coverage_audit_payload_sha256": fake_sha("temporary coverage"),
        }
        if fail_result:
            def fail_commit_result(path: Path, payload: bytes) -> None:
                if Path(path).name == "commit_result.json":
                    raise OSError("simulated durable commit-result failure")
                original_atomic_write(path, payload)

            M.atomic_write = fail_commit_result
            expect_failure(
                "durable commit-result failure rolls production back",
                "production was restored from checkpoint",
                lambda: M.commit_plan(
                    plan,
                    [test_batch],
                    {batch.atlas_id: test_entry},
                    source_manifest_path,
                    batch_manifest_path,
                ),
            )
            check(first_target.read_bytes() == initial_first_payload, "rollback restores a preexisting output byte-for-byte")
            check(production_manifest.read_bytes() == initial_manifest_payload, "rollback restores the preexisting manifest byte-for-byte")
            second_name = f"{batch.rows[0]}_{batch.runtime_state}_{M.DIRECTIONS[1]}.png"
            check(not (output_dir / second_name).exists(), "rollback removes newly created outputs")
            check(not source_archive.exists(), "rollback removes newly created source archives")
        else:
            checkpoint, result = M.commit_plan(
                plan,
                [test_batch],
                {batch.atlas_id: test_entry},
                source_manifest_path,
                batch_manifest_path,
            )
            check(result["output_pngs_written"] == 16, "temporary commit writes all 16 planned outputs")
            check((checkpoint / "commit_result.json").is_file(), "successful commit has durable commit-result evidence")
            check(all((output_dir / name).read_bytes() == payload for name, payload in payloads.items()),
                  "temporary commit output payloads are exact")
    finally:
        M.DEFAULT_OUTPUT_DIR = patched["DEFAULT_OUTPUT_DIR"]
        M.DEFAULT_SOURCE_ARCHIVE = patched["DEFAULT_SOURCE_ARCHIVE"]
        M.DEFAULT_PROMPT_ARCHIVE = patched["DEFAULT_PROMPT_ARCHIVE"]
        M.DEFAULT_REFERENCE_ARCHIVE = patched["DEFAULT_REFERENCE_ARCHIVE"]
        M.DEFAULT_PRODUCTION_MANIFEST = patched["DEFAULT_PRODUCTION_MANIFEST"]
        M.DEFAULT_CHECKPOINT_ROOT = patched["DEFAULT_CHECKPOINT_ROOT"]
        M.post_commit_coverage_check = patched["post_commit_coverage_check"]
        M.atomic_write = patched["atomic_write"]


def main() -> int:
    production_roots = (M.ROOT / "assets/anim", M.ROOT / "assets/direction4")
    production_before = tree_digest(production_roots)
    _batch_data, batches = M.load_batches(M.DEFAULT_BATCH_MANIFEST)
    check(len(batches) == 10, "schema 2 batch manifest loads ten reviewed prompts")
    check(all(batch.anchor_kind == ("lowest_contact" if batch.design_state == "down" else "foot_or_hoof") for batch in batches),
          "down and upright anchor kinds are separated")
    check(len(batches[1].local_references) == 1, "troop idle reference SHA is verified by load_batches")

    prompt_dir = M.DEFAULT_BATCH_MANIFEST.parent
    for batch in batches:
        text = batch.prompt_path.read_text(encoding="utf-8")
        check("正负 3 像素以内" in text, batch.atlas_id + " prompt uses hard plus-or-minus 3px language")
        check(hashlib.sha256(batch.prompt_path.read_bytes()).hexdigest() == batch.prompt_sha256,
              batch.atlas_id + " prompt hash matches")
    check("快活林" in json.loads(M.DEFAULT_BATCH_MANIFEST.read_text(encoding="utf-8"))["scope"]["coverage_boundary"],
          "generic Wu Song boundary is explicit")

    qa_temp_root = M.ROOT / "qa"
    qa_temp_root.mkdir(parents=True, exist_ok=True)
    original_ledger_root = M.DEFAULT_ATTEMPT_LEDGER_ROOT
    with tempfile.TemporaryDirectory(prefix="direction4_intake_selftest_", dir=qa_temp_root) as temp_name:
        temp = Path(temp_name)
        M.DEFAULT_ATTEMPT_LEDGER_ROOT = temp
        batch_copy_dir = temp / "prompt_pack"
        batch_copy_dir.mkdir()
        batch_copy = json.loads(M.DEFAULT_BATCH_MANIFEST.read_text(encoding="utf-8"))
        for batch in batches:
            (batch_copy_dir / batch.filename).write_bytes(batch.prompt_path.read_bytes())

        alternate_manifest = batch_copy_dir / "alternate_batch_manifest.json"
        alternate_manifest.write_text(json.dumps(batch_copy, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        _candidate_data, candidate_batches = M.load_batches(alternate_manifest, require_frozen=False)
        check(len(candidate_batches) == 10, "explicit development validation may read a structurally valid unfrozen pack")
        expect_failure(
            "an unfrozen self-rebased manifest cannot enter the commit/record path",
            "requires the exact frozen prompt-pack manifest path and SHA",
            lambda: M.load_batches(alternate_manifest, require_frozen=True),
        )

        empty_prompt = copy.deepcopy(batch_copy)
        empty_prompt_path = batch_copy_dir / empty_prompt["batches"][0]["filename"]
        original_prompt_payload = empty_prompt_path.read_bytes()
        empty_prompt_path.write_bytes(b"")
        empty_prompt["batches"][0]["prompt_sha256"] = hashlib.sha256(b"").hexdigest()
        empty_prompt_manifest = batch_copy_dir / "empty_prompt_manifest.json"
        empty_prompt_manifest.write_text(json.dumps(empty_prompt, ensure_ascii=False), encoding="utf-8")
        expect_failure(
            "empty prompt plus a self-rebased SHA is rejected in development validation",
            "prompt is empty/truncated",
            lambda: M.load_batches(empty_prompt_manifest, require_frozen=False),
        )
        empty_prompt_path.write_bytes(original_prompt_payload)

        empty_checks = copy.deepcopy(batch_copy)
        empty_checks["batches"][0]["acceptance_checks"] = []
        empty_checks_manifest = batch_copy_dir / "empty_checks_manifest.json"
        empty_checks_manifest.write_text(json.dumps(empty_checks, ensure_ascii=False), encoding="utf-8")
        expect_failure(
            "empty acceptance checks cannot be self-rebased",
            "acceptance_checks must contain the complete nonempty reviewed set",
            lambda: M.load_batches(empty_checks_manifest, require_frozen=False),
        )

        audit_drift = copy.deepcopy(batch_copy)
        audit_drift["audit_source"]["sha256"] = fake_sha("drifted audit")
        audit_drift_manifest = batch_copy_dir / "audit_drift_manifest.json"
        audit_drift_manifest.write_text(json.dumps(audit_drift, ensure_ascii=False), encoding="utf-8")
        expect_failure(
            "campaign audit path/SHA drift is rejected",
            "audit_source path/SHA differs from the frozen registry",
            lambda: M.load_batches(audit_drift_manifest, require_frozen=False),
        )

        audit_fixture = temp / "audit_fixture.json"
        audit_fixture.write_bytes(b"reviewed audit fixture\n")
        frozen_registry_copy = copy.deepcopy(M.load_frozen_registry())
        audit_fixture_sha = hashlib.sha256(audit_fixture.read_bytes()).hexdigest()
        frozen_registry_copy["audit_source"] = {
            "path": audit_fixture.relative_to(M.ROOT.parent).as_posix(),
            "sha256": audit_fixture_sha,
        }
        temporary_registry = temp / "temporary_frozen_registry.json"
        temporary_registry.write_text(
            json.dumps(frozen_registry_copy, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        actual_audit_drift = copy.deepcopy(batch_copy)
        actual_audit_drift["audit_source"] = copy.deepcopy(frozen_registry_copy["audit_source"])
        actual_audit_drift_manifest = batch_copy_dir / "actual_audit_drift_manifest.json"
        actual_audit_drift_manifest.write_text(json.dumps(actual_audit_drift, ensure_ascii=False), encoding="utf-8")
        original_registry_path = M.FROZEN_REGISTRY
        original_registry_sha = M.FROZEN_REGISTRY_SHA256
        try:
            M.FROZEN_REGISTRY = temporary_registry
            M.FROZEN_REGISTRY_SHA256 = hashlib.sha256(temporary_registry.read_bytes()).hexdigest()
            audit_fixture.write_bytes(b"drifted audit fixture\n")
            expect_failure(
                "actual frozen campaign audit bytes cannot drift behind an unchanged declaration",
                "frozen campaign audit source is missing or its SHA has drifted",
                lambda: M.load_batches(actual_audit_drift_manifest, require_frozen=False),
            )
        finally:
            M.FROZEN_REGISTRY = original_registry_path
            M.FROZEN_REGISTRY_SHA256 = original_registry_sha

        batch_copy["batches"][1]["required_reference"][0]["sha256"] = "0" * 64
        bad_reference_manifest = batch_copy_dir / "bad_reference_manifest.json"
        bad_reference_manifest.write_text(json.dumps(batch_copy, ensure_ascii=False), encoding="utf-8")
        expect_failure(
            "troop idle local reference SHA mismatch is rejected",
            "required local reference SHA mismatch",
            lambda: M.load_batches(bad_reference_manifest, require_frozen=False),
        )

        manifest_path, payload, selected_shas = source_manifest(temp, batches)
        _source_data, selected, attempts, sidecar_dir, roots = M.load_source_entries(manifest_path, batches)
        check(len(selected) == 10 and len(attempts) == 11, "selection keeps ten candidates and one rejected attempt")
        check(selected["sample_heroes_attack"].reference_idle_sha256 == selected_shas["sample_heroes_idle"],
              "later hero state binds exact adopted idle SHA")

        bad_review = copy.deepcopy(payload)
        bad_review["entries"][0]["human_review"]["no_text_or_watermark_confirmed"] = False
        bad_review_path = temp / "bad_review.json"
        bad_review_path.write_text(json.dumps(bad_review, ensure_ascii=False), encoding="utf-8")
        expect_failure(
            "adopted art cannot bypass no-text/no-watermark gate",
            "failed required human gates",
            lambda: M.load_source_entries(bad_review_path, batches),
        )

        stale_idle = copy.deepcopy(payload)
        for raw in stale_idle["entries"]:
            if raw["atlas_id"] == "sample_heroes_attack" and raw["decision"] == "adopt":
                raw["reference_idle_sha256"] = fake_sha("stale idle")
        stale_path = temp / "stale_idle.json"
        stale_path.write_text(json.dumps(stale_idle, ensure_ascii=False), encoding="utf-8")
        expect_failure(
            "later state cannot bind stale idle bytes from the same conversation",
            "must bind an adopted sample_heroes_idle",
            lambda: M.load_source_entries(stale_path, batches),
        )

        rejected_later = copy.deepcopy(payload)
        rejected_attack = next(
            copy.deepcopy(raw)
            for raw in rejected_later["entries"]
            if raw["atlas_id"] == "sample_heroes_attack" and raw["decision"] == "adopt"
        )
        rejected_attack_sha = fake_sha("rejected later attack")
        rejected_attack.update(
            {
                "attempt_id": f"sample_heroes_attack:{rejected_attack_sha}",
                "source_png": str(temp / "rejected" / "sample_heroes_attack_rejected.png"),
                "source_sha256": rejected_attack_sha,
                "decision": "reject",
                "reason": "动作格方向正确但人物身份漂移，明确淘汰并保留来源",
                "reference_idle_sha256": fake_sha("arbitrary unadopted idle"),
            }
        )
        rejected_later["entries"].append(rejected_attack)
        rejected_later_path = temp / "rejected_later_bad_idle.json"
        rejected_later_path.write_text(json.dumps(rejected_later, ensure_ascii=False), encoding="utf-8")
        expect_failure(
            "rejected later-state attempts also bind the adopted idle SHA",
            "every later-state attempt must bind an adopted sample_heroes_idle",
            lambda: M.load_source_entries(rejected_later_path, batches),
        )

        generic_reason = copy.deepcopy(payload)
        generic_reason["entries"][0]["reason"] = "全部通过"
        generic_reason_path = temp / "generic_reason.json"
        generic_reason_path.write_text(json.dumps(generic_reason, ensure_ascii=False), encoding="utf-8")
        expect_failure(
            "generic adoption reason is rejected",
            "concrete adoption/rejection finding",
            lambda: M.load_source_entries(generic_reason_path, batches),
        )

        hero_idle_batch = batches[0]
        normalized = M.verify_plan_outputs(
            hero_idle_batch, selected[hero_idle_batch.atlas_id], fake_slicer_plan(hero_idle_batch)
        )
        check(len(normalized) == 16, "all 16 manual anchor coordinates pass at exact 82 percent")
        check(all(item["placement_reference"]["semantic_anchor_evidence"] is True for item in normalized),
              "final placement is tied to the reviewed semantic foot coordinate")
        check(all(item["placement_reference"]["placed_output_y_px"] == 210 for item in normalized),
              "all final PNG semantic anchors land at 82 percent of the target canvas")
        check(all(item["alpha_bbox_bottom_reference"]["semantic_anchor_evidence"] is False for item in normalized),
              "alpha-bounds bottom remains a separate non-semantic reference")
        check(all(item["manual_anchor_measurement"]["within_tolerance"] is True for item in normalized),
              "manual anchor evidence is attached to every planned output")

        alpha_only_plan = fake_slicer_plan(hero_idle_batch)
        alpha_only_plan["outputs"][0]["placement_reference"] = {
            "kind": "source_alpha_bbox_bottom_only",
            "normalized_y": 0.82,
            "pixel_y": 210,
            "semantic_anchor_evidence": False,
        }
        expect_failure(
            "alpha-bottom placement cannot replace the semantic foot anchor",
            "final PNG placement must use the exact reviewed manual",
            lambda: M.verify_plan_outputs(
                hero_idle_batch, selected[hero_idle_batch.atlas_id], alpha_only_plan
            ),
        )

        false_geometry_plan = fake_slicer_plan(hero_idle_batch)
        false_geometry_plan["outputs"][0]["paste_xy"][1] += 1
        expect_failure(
            "semantic placement metadata must reproduce final pixel geometry",
            "semantic-placement geometry does not reproduce",
            lambda: M.verify_plan_outputs(
                hero_idle_batch, selected[hero_idle_batch.atlas_id], false_geometry_plan
            ),
        )

        body = Image.new("RGBA", (30, 60), (64, 96, 128, 255))
        semantic_target_y = round(256 * M.ANCHOR_FRACTION)
        _frame, output_size, paste_xy, placed_semantic_y = S.render_frame(
            body,
            1.0,
            256,
            semantic_target_y,
            semantic_anchor_offset_y=35,
        )
        check(placed_semantic_y == semantic_target_y, "slicer places the supplied semantic source coordinate at target Y")
        check(paste_xy[1] + output_size[1] != semantic_target_y,
              "slicer does not substitute alpha-bounds bottom for a higher semantic foot coordinate")

        shifted = list(selected[hero_idle_batch.atlas_id].anchor_measurements)
        shifted[0] = {**shifted[0], "source_y_px": shifted[0]["source_y_px"] + 4}
        shifted_entry = dataclasses.replace(selected[hero_idle_batch.atlas_id], anchor_measurements=tuple(shifted))
        expect_failure(
            "four-pixel anchor error is rejected",
            "misses target",
            lambda: M.verify_plan_outputs(hero_idle_batch, shifted_entry, fake_slicer_plan(hero_idle_batch)),
        )

        sidecar_result = M.record_or_verify_attempt_sidecars(attempts, sidecar_dir, record=True)
        check(sidecar_result[0]["status"] == "created", "first attempt sidecar is created once")
        replay = M.record_or_verify_attempt_sidecars(attempts, sidecar_dir, record=True)
        check(replay[0]["status"] == "verified_existing", "identical sidecar replay is accepted")
        expect_failure(
            "previously recorded attempt cannot be omitted from a later manifest",
            "omitted previously recorded",
            lambda: M.record_or_verify_attempt_sidecars([], sidecar_dir, record=False),
        )
        changed_entry = dataclasses.replace(attempts[0], reason="同一源图被人为改写成另一条采用理由")
        expect_failure(
            "attempt sidecar cannot be overwritten",
            "already exists with different bytes",
            lambda: M.record_or_verify_attempt_sidecars([changed_entry, *attempts[1:]], sidecar_dir, record=True),
        )

        switched_ledger = copy.deepcopy(payload)
        switched_ledger["entries"] = [entry for entry in switched_ledger["entries"] if entry["decision"] != "reject"]
        switched_ledger["attempt_sidecar_dir"] = "alternate_attempts"
        switched_ledger["attempt_roots"] = ["alternate_downloads", "alternate_accepted", "alternate_rejected"]
        switched_ledger_path = temp / "switched_ledger_dropped_reject.json"
        switched_ledger_path.write_text(json.dumps(switched_ledger, ensure_ascii=False), encoding="utf-8")
        expect_failure(
            "switching ledger directories cannot hide a historical rejected attempt",
            "may not be overridden by the source manifest",
            lambda: M.load_source_entries(switched_ledger_path, batches),
        )

        canonical_omission = copy.deepcopy(payload)
        canonical_omission["entries"] = [entry for entry in canonical_omission["entries"] if entry["decision"] != "reject"]
        canonical_omission_path = temp / "canonical_ledger_dropped_reject.json"
        canonical_omission_path.write_text(json.dumps(canonical_omission, ensure_ascii=False), encoding="utf-8")
        _omitted_data, _omitted_selected, omitted_attempts, omitted_sidecar, _omitted_roots = M.load_source_entries(
            canonical_omission_path, batches
        )
        expect_failure(
            "fixed ledger completeness scan detects a dropped rejected sidecar",
            "omitted previously recorded",
            lambda: M.record_or_verify_attempt_sidecars(omitted_attempts, omitted_sidecar, record=False),
        )

        exercise_commit_case(temp / "commit_success", hero_idle_batch, selected[hero_idle_batch.atlas_id], False)
        exercise_commit_case(temp / "commit_result_failure", hero_idle_batch, selected[hero_idle_batch.atlas_id], True)
        unremovable_lock = temp / "unremovable_lock"
        unremovable_lock.mkdir()
        lock_warning = M.release_lock(unremovable_lock)
        check(
            isinstance(lock_warning, dict)
            and lock_warning.get("kind") == "direction4_first_sample_intake_lock_cleanup_warning"
            and lock_warning.get("committed_state_unchanged") is True,
            "lock cleanup failure returns a warning instead of raising over commit state",
        )

    M.DEFAULT_ATTEMPT_LEDGER_ROOT = original_ledger_root
    production_after = tree_digest(production_roots)
    production_art_modified = production_before != production_after
    check(not production_art_modified, "selftest leaves production animation and direction4 assets byte-identical")
    report = {
        "schema_version": 1,
        "kind": "direction4_first_sample_intake_selftest",
        "passed": all(item["passed"] for item in CHECKS),
        "checks": len(CHECKS),
        "negative_checks": NEGATIVE_CHECKS,
        "production_art_modified": production_art_modified,
        "production_tree_sha256_before": production_before,
        "production_tree_sha256_after": production_after,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
