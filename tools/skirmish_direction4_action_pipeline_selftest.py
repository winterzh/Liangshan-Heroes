"""Non-production self-test for skirmish_direction4_action_pipeline.py.

All generated pictures are deliberately crude synthetic QA fixtures.  They are
not game art and are deleted after a passing run.  The test snapshots the real
assets/anim tree before and after, and fails if any production byte or path was
changed.
"""
from __future__ import annotations

import copy
import json
import shutil
import sys
import uuid
from pathlib import Path
from typing import Any, Callable

from PIL import Image, ImageDraw

import skirmish_direction4_action_pipeline as pipeline


REPORT = pipeline.QA_ROOT / "pipeline_selftest_report.json"


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def file_tree(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    return {
        item.relative_to(path).as_posix(): pipeline.sha256_file(item)
        for item in sorted(path.rglob("*"))
        if item.is_file()
    }


def save_rgba(path: Path, image: Image.Image) -> None:
    assert image.mode == "RGBA"
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def make_source(path: Path, pose: str) -> list[dict[str, Any]]:
    size = 512
    cell = size // 4
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    anchors: list[dict[str, Any]] = []
    pose_index = pipeline.POSES.index(pose)
    for row, unit in enumerate(pipeline.UNITS):
        for column, direction in enumerate(pipeline.DIRECTIONS):
            x0, y0 = column * cell, row * cell
            color = (
                45 + row * 38,
                55 + column * 35,
                75 + pose_index * 39,
                255,
            )
            accent = (220 - column * 23, 120 + row * 20, 35 + pose_index * 31, 180 + column * 15)
            if pose == "death_down":
                draw.rounded_rectangle((x0 + 18, y0 + 70, x0 + 109, y0 + 101), radius=8, fill=color)
                draw.polygon((x0 + 18, y0 + 78, x0 + 9 + column, y0 + 87, x0 + 25, y0 + 94), fill=accent)
            elif pose == "death_fall":
                draw.polygon((x0 + 34, y0 + 30, x0 + 91, y0 + 48, x0 + 82, y0 + 101, x0 + 48, y0 + 101), fill=color)
                draw.rectangle((x0 + 28 + column, y0 + 56, x0 + 42, y0 + 75), fill=accent)
            elif pose == "attack_strike":
                draw.rounded_rectangle((x0 + 37, y0 + 27, x0 + 87, y0 + 101), radius=9, fill=color)
                draw.polygon((x0 + 60, y0 + 55, x0 + 108, y0 + 39 + column, x0 + 66, y0 + 67), fill=accent)
            else:
                draw.rounded_rectangle((x0 + 38, y0 + 25, x0 + 88, y0 + 101), radius=10, fill=color)
                draw.polygon((x0 + 44, y0 + 74, x0 + 24 + column, y0 + 96, x0 + 55, y0 + 91), fill=accent)
            # A direction-specific, non-mirrored marker that remains inside the cell.
            marker_x = x0 + 43 + column * 7
            marker_y = y0 + (80 if pose == "death_down" else 38 + row)
            draw.rectangle((marker_x, marker_y, marker_x + 5, marker_y + 9), fill=(255, 245, 210, 255))
            anchors.append({
                "pose": pose,
                "unit": unit,
                "direction": direction,
                "measurement_kind": pipeline.POSE_ANCHOR_KIND[pose],
                "manual_source_rect": [x0 + 4, y0 + 4, x0 + cell - 4, y0 + cell - 4],
                "source_x_px": x0 + 64,
                "source_y_px": y0 + 100,
                "review_note": "Synthetic fixture semantic contact point; not production art.",
            })
    save_rgba(path, image)
    return anchors


def make_idle(path: Path, unit_index: int, direction_index: int) -> None:
    image = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    color = (20 + unit_index * 41, 145 + direction_index * 18, 210 - unit_index * 22, 255)
    draw.rounded_rectangle((91, 65, 161, 210), radius=13, fill=color)
    draw.polygon((128, 75, 166 + direction_index, 116, 130, 128), fill=(240, 185, 45, 220))
    draw.rectangle((95 + direction_index * 3, 198, 129, 210), fill=(50, 40, 30, 255))
    save_rgba(path, image)


def create_fixture(base: Path, *, collision: bool = False) -> tuple[Path, dict[str, Any], bytes | None]:
    source_dir = base / "source"
    fake_production = base / "fake_production"
    prompt_dir = source_dir / "prompts"
    source_dir.mkdir(parents=True, exist_ok=True)
    fake_production.mkdir(parents=True, exist_ok=True)
    all_anchors: list[dict[str, Any]] = []
    source_entries: list[dict[str, Any]] = []
    verification_results: list[dict[str, Any]] = []
    cleanup_prompt = prompt_dir / "exact_alpha_cleanup.txt"
    cleanup_prompt.parent.mkdir(parents=True, exist_ok=True)
    cleanup_prompt.write_text("Synthetic provenance-chain fixture; never production art.\n", encoding="utf-8")
    for index, pose in enumerate(pipeline.POSES, 1):
        source_path = source_dir / f"{pose}.png"
        all_anchors.extend(make_source(source_path, pose))
        with Image.open(source_path) as opened:
            raw_image = opened.copy()
            canonical_image = opened.copy()
        raw_image.putpixel((0, 0), (1, 2, 3, 1))
        canonical_image.putpixel((0, 0), (4, 5, 6, 2))
        raw_path = source_dir / f"{pose}_raw.png"
        canonical_path = source_dir / "web_upload_canonical" / f"{pose}_web_upload.png"
        save_rgba(raw_path, raw_image)
        save_rgba(canonical_path, canonical_image)
        prompt = prompt_dir / f"{pose}.txt"
        prompt.parent.mkdir(parents=True, exist_ok=True)
        prompt.write_text(f"Synthetic self-test prompt for {pose}; never production art.\n", encoding="utf-8")
        source_entries.append({
            "pose": pose,
            "file": pipeline.relative_to_root(source_path),
            "sha256": pipeline.sha256_file(source_path),
            "raw_generated_file": pipeline.relative_to_root(raw_path),
            "raw_generated_sha256": pipeline.sha256_file(raw_path),
            "prompt_file": pipeline.relative_to_root(prompt),
            "prompt_sha256": pipeline.sha256_file(prompt),
            "conversation": "https://chatgpt.com/c/00000000-0000-0000-0000-000000000000",
            "rows": list(pipeline.UNITS),
            "columns": list(pipeline.DIRECTIONS),
            "browser_cleanup": {
                "method": "browser_python_pillow_alpha_le_15_rgba_zero",
                "prompt_file": pipeline.relative_to_root(cleanup_prompt),
                "prompt_sha256": pipeline.sha256_file(cleanup_prompt),
                "confirmed": True,
                "input_role": "web_upload_canonical",
                "browser_upload_reencoded": True,
                "exactness_basis": "web_upload_canonical",
                "input_file": pipeline.relative_to_root(canonical_path),
                "input_sha256": pipeline.sha256_file(canonical_path),
                "output_sha256": pipeline.sha256_file(source_path),
                "cleared_pixel_count": 0,
            },
        })
        verification_results.append({
            "pose": pose,
            "raw_generated_file": raw_path.name,
            "raw_generated_sha256": pipeline.sha256_file(raw_path),
            "input_file": f"web_upload_canonical/{canonical_path.name}",
            "input_sha256": pipeline.sha256_file(canonical_path),
            "output_file": source_path.name,
            "output_sha256": pipeline.sha256_file(source_path),
            "changed_pixels": 0,
            "alpha_gt_15_mismatch_pixels": 0,
            "alpha_le_15_output_nonzero_pixels": 0,
        })
    verification_path = source_dir / "alpha_cleanup_verification.json"
    write_json(verification_path, {
        "schema_version": 1,
        "kind": "browser_alpha_cleanup_verification",
        "method": "browser_python_pillow_alpha_le_15_rgba_zero",
        "conversation": "https://chatgpt.com/c/00000000-0000-0000-0000-000000000000",
        "provenance_note": "Synthetic browser upload was re-encoded; exactness is relative to web_upload_canonical and never claims identity with raw generation.",
        "results": verification_results,
        "passed": True,
    })
    for source_entry in source_entries:
        source_entry["browser_cleanup"]["verification_file"] = pipeline.relative_to_root(verification_path)
        source_entry["browser_cleanup"]["verification_sha256"] = pipeline.sha256_file(verification_path)
    anchors_path = source_dir / "semantic_anchors.json"
    write_json(anchors_path, {
        "schema_version": 2,
        "kind": "skirmish_direction4_semantic_anchors",
        "entries": all_anchors,
    })
    idle_inputs: list[dict[str, Any]] = []
    for unit_index, unit in enumerate(pipeline.UNITS):
        for direction_index, direction in enumerate(pipeline.DIRECTIONS):
            path = fake_production / f"{unit}_idle_{direction}.png"
            make_idle(path, unit_index, direction_index)
            idle_inputs.append({
                "unit": unit,
                "direction": direction,
                "file": pipeline.relative_to_root(path),
                "sha256": pipeline.sha256_file(path),
            })
    collision_bytes: bytes | None = None
    collision_policy: dict[str, str] = {}
    if collision:
        collision_target = fake_production / "guan_dao_attack_ne.png"
        collision_bytes = b"synthetic-preexisting-collision-baseline\n"
        collision_target.write_bytes(collision_bytes)
        collision_policy[collision_target.name] = pipeline.sha256_file(collision_target)
    config = {
        "schema_version": 2,
        "kind": "skirmish_direction4_action_batch",
        "batch_id": f"synthetic_selftest_{base.name}",
        "scope": "test",
        "units": list(pipeline.UNITS),
        "directions": list(pipeline.DIRECTIONS),
        "canvas": {
            "size_px": 256,
            "max_content_width_px": 248,
            "max_content_height_px": 248,
            "anchor_target_x_px": 128,
            "anchor_target_y_px": 210,
            "margin_px": 4,
            "max_walk_attack_fit_shift_px": 20,
        },
        "source_layout": {
            "mode": "manual_source_rects_v2",
            "minimum_source_size_px": 512,
            "rect_edge_transparent_clearance_px": 4,
            "anchor_evidence_radius_px": 2,
            "subject_group_join_gap_px": 4,
            "minimum_subject_alpha_pixels": 128,
        },
        "paths": {
            "staging_dir": pipeline.relative_to_root(base / "staging"),
            "production_root": pipeline.relative_to_root(fake_production),
            "commit_manifest": pipeline.relative_to_root(base / "production_manifest.json"),
            "checkpoint_root": pipeline.relative_to_root(base / "checkpoints"),
            "approval_receipt": pipeline.relative_to_root(base / "commit_approval.json"),
        },
        "source_approval": {"browser_cleaned_sources_confirmed": True},
        "anchors_file": pipeline.relative_to_root(anchors_path),
        "anchors_sha256": pipeline.sha256_file(anchors_path),
        "sources": source_entries,
        "idle_inputs": idle_inputs,
        "collision_policy": {"expected_existing_sha256": collision_policy},
    }
    config_path = base / "pipeline_config.json"
    write_json(config_path, config)
    return config_path, config, collision_bytes


def expect_error(label: str, function: Callable[[], Any], contains: str | None = None) -> str:
    try:
        function()
    except pipeline.PipelineError as error:
        message = str(error)
        if contains is not None and contains not in message:
            raise AssertionError(f"{label}: expected error containing {contains!r}, got {message!r}") from error
        return message
    raise AssertionError(f"{label}: expected PipelineError")


def bind_approval(config_path: Path) -> None:
    config, _ = pipeline.load_config(config_path)
    paths = pipeline.validate_paths(config)
    manifest = paths["staging_dir"] / "candidate_manifest.json"
    write_json(paths["approval_receipt"], {
        "schema_version": 1,
        "kind": "skirmish_direction4_action_commit_approval",
        "batch_id": config["batch_id"],
        "approved": True,
        "stage_manifest_sha256": pipeline.sha256_file(manifest),
        "approved_by": "automated synthetic self-test",
        "approved_at": pipeline.utc_now(),
        "visual_review_note": "Synthetic pipeline mechanics only; this is not human approval of game art.",
    })


def mutate_source_and_update_config(config_path: Path, pose: str, writer: Callable[[Path], None]) -> tuple[bytes, dict[str, Any]]:
    config = json.loads(config_path.read_text(encoding="utf-8"))
    entry = next(item for item in config["sources"] if item["pose"] == pose)
    source = pipeline.resolve_path(entry["file"])
    original = source.read_bytes()
    original_config = copy.deepcopy(config)
    writer(source)
    entry["sha256"] = pipeline.sha256_file(source)
    entry["browser_cleanup"]["output_sha256"] = entry["sha256"]
    write_json(config_path, config)
    return original, original_config


def run() -> dict[str, Any]:
    pipeline.QA_ROOT.mkdir(parents=True, exist_ok=True)
    real_before = file_tree(pipeline.REAL_PRODUCTION_ROOT)
    sandbox = pipeline.QA_ROOT / "source" / f".pipeline_selftest_{uuid.uuid4().hex}"
    sandbox.mkdir(parents=True, exist_ok=False)
    checks: list[dict[str, Any]] = []

    def check(name: str, function: Callable[[], Any]) -> Any:
        result = function()
        checks.append({"name": name, "passed": True})
        return result

    try:
        config_path, config, _ = create_fixture(sandbox / "main")
        main_base = config_path.parent

        # Exercise the production-only provenance chain without running path
        # validation or touching production.  The fixed real verification path
        # is temporarily pointed at this isolated synthetic receipt.
        strict_config = copy.deepcopy(config)
        strict_config["scope"] = "production"
        strict_anchors, _strict_anchor_record = pipeline.load_anchors(strict_config)
        original_verification_constant = pipeline.REAL_CLEANUP_VERIFICATION
        pipeline.REAL_CLEANUP_VERIFICATION = pipeline.resolve_path(strict_config["sources"][0]["browser_cleanup"]["verification_file"])
        try:
            strict_sources = check(
                "production provenance chain validates raw, re-encoded canonical, cleanup receipt, and output",
                lambda: pipeline.validate_sources(strict_config, copy.deepcopy(strict_anchors), require_browser_confirmation=True),
            )
            assert all(source["_raw_generated_file"] and source["_raw_generated_sha"] for source in strict_sources)
            wrong_input = copy.deepcopy(strict_config)
            wrong_input["sources"][0]["browser_cleanup"]["input_sha256"] = "0" * 64
            check(
                "browser-upload canonical input hash mismatch rejected",
                lambda: expect_error("canonical hash", lambda: pipeline.validate_sources(wrong_input, copy.deepcopy(strict_anchors), require_browser_confirmation=True), "hash mismatch"),
            )
            wrong_receipt = copy.deepcopy(strict_config)
            wrong_receipt["sources"][0]["browser_cleanup"]["verification_sha256"] = "0" * 64
            check(
                "browser cleanup verification hash mismatch rejected",
                lambda: expect_error("verification hash", lambda: pipeline.validate_sources(wrong_receipt, copy.deepcopy(strict_anchors), require_browser_confirmation=True), "hash mismatch"),
            )
        finally:
            pipeline.REAL_CLEANUP_VERIFICATION = original_verification_constant

        before_dry = file_tree(main_base)
        dry_result = check("dry-run validates full render", lambda: pipeline.dry_run(config_path))
        assert dry_result["writes"] == 0 and dry_result["counts"]["production_strips"] == 48
        assert file_tree(main_base) == before_dry
        checks.append({"name": "dry-run leaves zero files/directories/temporaries", "passed": True})

        shift_gate_config = copy.deepcopy(config)
        shift_gate_config["canvas"]["anchor_target_y_px"] = 251
        shift_gate_config["canvas"]["max_walk_attack_fit_shift_px"] = 1
        write_json(config_path, shift_gate_config)
        check(
            "oversized walk/attack canvas-fit shift rejected",
            lambda: expect_error("fit shift", lambda: pipeline.dry_run(config_path), "fit shift exceeds"),
        )
        write_json(config_path, config)

        # Anchor contract negatives: missing, wrong kind, and outside retained crop.
        anchors_path = pipeline.resolve_path(config["anchors_file"])
        anchor_original = json.loads(anchors_path.read_text(encoding="utf-8"))
        config_original = json.loads(config_path.read_text(encoding="utf-8"))
        for name, mutator, expected in (
            ("missing semantic anchor rejected", lambda value: value["entries"].pop(), "cover all 64"),
            ("wrong semantic anchor kind rejected", lambda value: value["entries"][0].__setitem__("measurement_kind", "lowest_contact"), "must use foot_or_hoof"),
            ("anchor outside manual source rect rejected", lambda value: value["entries"][0].__setitem__("source_x_px", 1), "outside its manual_source_rect"),
        ):
            mutated = copy.deepcopy(anchor_original)
            mutator(mutated)
            write_json(anchors_path, mutated)
            changed_config = copy.deepcopy(config_original)
            changed_config["anchors_sha256"] = pipeline.sha256_file(anchors_path)
            write_json(config_path, changed_config)
            check(name, lambda expected=expected: expect_error(name, lambda: pipeline.dry_run(config_path), expected))
        write_json(anchors_path, anchor_original)
        write_json(config_path, config_original)

        # Explicit manual rectangle negatives: wrong semantic assignment,
        # uncovered visible pixels, geometric overlap, and clipped edge art.
        def swap_first_two_rects(value: dict[str, Any]) -> None:
            first = value["entries"][0]["manual_source_rect"]
            second = value["entries"][1]["manual_source_rect"]
            value["entries"][0]["manual_source_rect"] = second
            value["entries"][1]["manual_source_rect"] = first

        def miss_visible_pixels(value: dict[str, Any]) -> None:
            value["entries"][0]["manual_source_rect"][0] = 30

        def overlap_next_rect(value: dict[str, Any]) -> None:
            value["entries"][0]["manual_source_rect"][2] = 140

        def place_art_on_rect_edge(value: dict[str, Any]) -> None:
            value["entries"][0]["manual_source_rect"][0] = 24

        for name, mutator, expected in (
            ("wrong manual rectangle assignment rejected", swap_first_two_rects, "direction order is wrong"),
            ("manual rectangle missing visible pixels rejected", miss_visible_pixels, "alpha>0 pixels outside"),
            ("overlapping manual rectangles rejected", overlap_next_rect, "manual_source_rect overlap"),
            ("manual rectangle edge clipping rejected", place_art_on_rect_edge, "alpha==0 edge clearance"),
        ):
            mutated = copy.deepcopy(anchor_original)
            mutator(mutated)
            write_json(anchors_path, mutated)
            changed_config = copy.deepcopy(config_original)
            changed_config["anchors_sha256"] = pipeline.sha256_file(anchors_path)
            write_json(config_path, changed_config)
            check(name, lambda expected=expected: expect_error(name, lambda: pipeline.dry_run(config_path), expected))
        write_json(anchors_path, anchor_original)
        write_json(config_path, config_original)

        # Native-RGBA, APNG, separated-subject, and edge-touching negatives.
        source_path = pipeline.resolve_path(config_original["sources"][0]["file"])

        def palette_writer(path: Path) -> None:
            with Image.open(path) as image:
                image.convert("P").save(path, format="PNG")

        original_source, saved_config = mutate_source_and_update_config(config_path, "walk_step", palette_writer)
        check("palette PNG rejected", lambda: expect_error("palette", lambda: pipeline.dry_run(config_path), "color type 6"))
        source_path.write_bytes(original_source)
        write_json(config_path, saved_config)

        def apng_writer(path: Path) -> None:
            with Image.open(path) as opened:
                first = opened.copy()
            second = first.copy()
            second.putpixel((10, 10), (255, 0, 0, 255))
            first.save(path, format="PNG", save_all=True, append_images=[second], duration=[100, 100], loop=0)

        original_source, saved_config = mutate_source_and_update_config(config_path, "walk_step", apng_writer)
        check("APNG rejected", lambda: expect_error("apng", lambda: pipeline.dry_run(config_path), "single-frame"))
        source_path.write_bytes(original_source)
        write_json(config_path, saved_config)

        def stray_group_writer(path: Path) -> None:
            with Image.open(path) as opened:
                image = opened.copy()
            for y in range(10, 14):
                for x in range(10, 14):
                    image.putpixel((x, y), (250, 20, 20, 255))
            save_rgba(path, image)

        original_source, saved_config = mutate_source_and_update_config(config_path, "walk_step", stray_group_writer)
        check("second separated subject group rejected", lambda: expect_error("subject group", lambda: pipeline.dry_run(config_path), "separated subject groups"))
        source_path.write_bytes(original_source)
        write_json(config_path, saved_config)

        def edge_writer(path: Path) -> None:
            with Image.open(path) as opened:
                image = opened.copy()
            image.putpixel((4, 4), (1, 2, 3, 255))
            save_rgba(path, image)

        original_source, saved_config = mutate_source_and_update_config(config_path, "walk_step", edge_writer)
        check("manual-rect edge alpha rejected", lambda: expect_error("edge", lambda: pipeline.dry_run(config_path), "alpha==0 edge clearance"))
        source_path.write_bytes(original_source)
        write_json(config_path, saved_config)

        stage_result = check("candidate stage succeeds", lambda: pipeline.stage(config_path))
        assert stage_result["counts"] == {"source_atlases": 4, "semantic_anchors": 64, "normalized_poses": 64, "production_strips": 48, "candidate_contact_sheets": 1}
        stage_dir = main_base / "staging"
        assert len(list((stage_dir / "poses").rglob("*.png"))) == 64
        assert len(list((stage_dir / "strips").glob("*.png"))) == 48
        contact_path = stage_dir / "candidate_contact_sheet.png"
        assert contact_path.is_file()
        staged_manifest = json.loads((stage_dir / "candidate_manifest.json").read_text(encoding="utf-8"))
        assert pipeline.sha256_file(contact_path) == staged_manifest["candidate_contact_sheet"]["sha256"]
        contact_image = pipeline.read_native_rgba_png(contact_path, "candidate contact sheet")
        assert list(contact_image.size) == staged_manifest["candidate_contact_sheet"]["size"]
        checks.append({"name": "QA-only candidate contact sheet generated and manifest-bound", "passed": True})
        check("staging collision rejected", lambda: expect_error("stage collision", lambda: pipeline.stage(config_path), "already exists"))

        # Exact recipes and byte-identical frame slicing.
        plan = pipeline.build_plan(config_path, require_browser_confirmation=True)
        for unit in pipeline.UNITS:
            scales = {
                record["uniform_scale_for_unit_all_actions"]
                for record in plan.manifest["normalized_poses"]
                if record["unit"] == unit
            }
            assert len(scales) == 1
            references = {record["reference_scale"] for record in plan.manifest["normalized_poses"] if record["unit"] == unit}
            fit_limits = {record["all_pose_canvas_fit_scale_limit"] for record in plan.manifest["normalized_poses"] if record["unit"] == unit}
            actual_scales = {record["fit_limited_scale"] for record in plan.manifest["normalized_poses"] if record["unit"] == unit}
            assert len(references) == len(fit_limits) == len(actual_scales) == 1
            assert next(iter(actual_scales)) == min(next(iter(references)), next(iter(fit_limits)))
        for record in plan.manifest["normalized_poses"]:
            measured = record["measured_alpha_zero_edge_clearance_px"]
            assert measured["minimum"] == min(measured["left"], measured["top"], measured["right"], measured["bottom"])
            assert measured["minimum"] >= 4
            assert record["paste_xy"] == [record["desired_paste_xy"][0] + record["fit_shift_xy_px"][0], record["desired_paste_xy"][1] + record["fit_shift_xy_px"][1]]
            assert record["placed_anchor_xy_px"] == [
                plan.manifest["canvas"]["anchor_target_x_px"] + record["fit_shift_xy_px"][0],
                plan.manifest["canvas"]["anchor_target_y_px"] + record["fit_shift_xy_px"][1],
            ]
            if record["pose"] in ("walk_step", "attack_strike"):
                assert max(abs(value) for value in record["fit_shift_xy_px"]) <= plan.manifest["canvas"]["max_walk_attack_fit_shift_px"]
        assert len(plan.manifest["idle_walk_alpha_bbox_comparison"]) == 16
        assert all(item["hard_height_ratio_passed"] for item in plan.manifest["idle_walk_alpha_bbox_comparison"])
        assert all(pipeline.WALK_IDLE_HEIGHT_HARD_MIN <= item["walk_to_idle_height_ratio"] <= pipeline.WALK_IDLE_HEIGHT_HARD_MAX for item in plan.manifest["idle_walk_alpha_bbox_comparison"])
        checks.append({"name": "idle-height reference scale, all-pose fit limit, per-frame minimum shift, clearance, and idle-walk QA", "passed": True})
        for record in plan.manifest["strips"]:
            path = stage_dir / record["staged_file"]
            strip = pipeline.read_native_rgba_png(path, "self-test strip", tuple(record["size"]))
            assert record["recipe"] == list(pipeline.ACTION_RECIPES[record["state"]])
            assert strip.size == (record["frame_count"] * 256, 256)
            for index, frame_record in enumerate(record["frames"]):
                if frame_record["kind"] == "idle":
                    frame_path = pipeline.resolve_path(frame_record["file"])
                else:
                    frame_path = stage_dir / frame_record["file"]
                frame = pipeline.read_native_rgba_png(frame_path, "self-test frame", (256, 256))
                assert strip.crop((index * 256, 0, (index + 1) * 256, 256)).tobytes() == frame.tobytes()
        checks.append({"name": "48 strip recipes and every RGBA frame slice verified", "passed": True})

        # Staging extra-file and hash tamper gates.
        extra = stage_dir / "unexpected.txt"
        extra.write_text("extra", encoding="utf-8")
        check("extra staged file rejected", lambda: expect_error("extra stage", lambda: pipeline.commit_stage(config_path, allow_replace_approved_targets=False), "Stage file set mismatch"))
        extra.unlink()
        tampered_rel = next(iter(plan.strip_files))
        tampered_path = stage_dir / tampered_rel
        pristine_staged = tampered_path.read_bytes()
        tampered_path.write_bytes(pristine_staged + b"tamper")
        check("staged output hash tamper rejected", lambda: expect_error("stage tamper", lambda: pipeline.commit_stage(config_path, allow_replace_approved_targets=False), "hash mismatch"))
        tampered_path.write_bytes(pristine_staged)
        pristine_contact = contact_path.read_bytes()
        contact_path.write_bytes(pristine_contact + b"tamper")
        check("candidate contact sheet hash tamper rejected", lambda: expect_error("contact sheet tamper", lambda: pipeline.commit_stage(config_path, allow_replace_approved_targets=False), "hash mismatch"))
        contact_path.write_bytes(pristine_contact)

        # Input source and idle hashes are rechecked at commit.
        pristine_source = source_path.read_bytes()
        source_path.write_bytes(pristine_source + b"tamper")
        check("source hash tamper rejected at commit", lambda: expect_error("source tamper", lambda: pipeline.commit_stage(config_path, allow_replace_approved_targets=False), "hash mismatch"))
        source_path.write_bytes(pristine_source)
        idle_path = pipeline.resolve_path(config_original["idle_inputs"][0]["file"])
        pristine_idle = idle_path.read_bytes()
        idle_path.write_bytes(pristine_idle + b"tamper")
        check("idle hash tamper rejected at commit", lambda: expect_error("idle tamper", lambda: pipeline.commit_stage(config_path, allow_replace_approved_targets=False), "hash mismatch"))
        idle_path.write_bytes(pristine_idle)

        bind_approval(config_path)
        unexpected_target = main_base / "fake_production" / "guan_dao_walk_se.png"
        unexpected_target.write_bytes(b"unexpected-new-target")
        check("post-stage production collision rejected", lambda: expect_error("production drift", lambda: pipeline.commit_stage(config_path, allow_replace_approved_targets=False), "Collision at"))
        unexpected_target.unlink()

        commit_result = check("fake production commit succeeds", lambda: pipeline.commit_stage(config_path, allow_replace_approved_targets=False))
        assert commit_result["outputs"] == 48
        assert len(list((main_base / "fake_production").glob("*_walk_*.png"))) == 16
        assert len(list((main_base / "fake_production").glob("*_attack_*.png"))) == 16
        assert len(list((main_base / "fake_production").glob("*_death_*.png"))) == 16
        check("idempotent re-commit succeeds", lambda: pipeline.commit_stage(config_path, allow_replace_approved_targets=False))

        # A second fixture proves approved collision replacement and injected rollback.
        rollback_config_path, rollback_config, collision_bytes = create_fixture(sandbox / "rollback", collision=True)
        rollback_base = rollback_config_path.parent
        rollback_before = file_tree(rollback_base / "fake_production")
        pipeline.stage(rollback_config_path)
        bind_approval(rollback_config_path)
        check(
            "approved replacement still needs explicit CLI-equivalent gate",
            lambda: expect_error("replacement gate", lambda: pipeline.commit_stage(rollback_config_path, allow_replace_approved_targets=False), "--replace-approved-targets"),
        )
        check(
            "injected mid-commit failure rolls back",
            lambda: expect_error(
                "injected rollback",
                lambda: pipeline.commit_stage(rollback_config_path, allow_replace_approved_targets=True, _failure_after=2),
                "was rolled back",
            ),
        )
        assert file_tree(rollback_base / "fake_production") == rollback_before
        collision_target = rollback_base / "fake_production" / "guan_dao_attack_ne.png"
        assert collision_target.read_bytes() == collision_bytes
        assert not (rollback_base / "production_manifest.json").exists()
        assert pipeline.pending_journals(rollback_base / "checkpoints") == []
        checks.append({"name": "rollback restores old file, removes new files, and leaves no pending journal", "passed": True})

        real_after = file_tree(pipeline.REAL_PRODUCTION_ROOT)
        assert real_after == real_before
        checks.append({"name": "real assets/anim path-and-byte snapshot unchanged", "passed": True, "files": len(real_before)})
        result = {
            "passed": True,
            "kind": "skirmish_direction4_action_pipeline_selftest",
            "fixture": "synthetic_non_art_fixture",
            "checks": checks,
            "summary": {"passed": len(checks), "failed": 0},
            "real_assets_anim_files_unchanged": len(real_before),
            "production_art_written": False,
            "steam_modified_or_exported": False,
        }
        shutil.rmtree(sandbox)
        return result
    except Exception as error:
        result = {
            "passed": False,
            "kind": "skirmish_direction4_action_pipeline_selftest",
            "fixture": "synthetic_non_art_fixture",
            "checks": checks,
            "error": f"{type(error).__name__}: {error}",
            "sandbox_preserved_for_debug": pipeline.relative_to_root(sandbox),
            "production_art_written": False,
            "steam_modified_or_exported": False,
        }
        raise AssertionError(json.dumps(result, ensure_ascii=False, indent=2)) from error


def main() -> int:
    try:
        result = run()
    except AssertionError as error:
        try:
            parsed = json.loads(str(error))
        except json.JSONDecodeError:
            parsed = {"passed": False, "error": str(error)}
        write_json(REPORT, parsed)
        print(json.dumps(parsed, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1
    write_json(REPORT, result)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
