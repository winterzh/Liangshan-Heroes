"""Synthetic, temporary self-test for the skirmish action provenance gate.

The fixture redirects every pipeline root into a temporary directory.  It
proves that a complete 48-strip chain passes, while a production-byte or
source-prompt drift invalidates the entire batch.  It never writes game art,
the real production manifest, exports, or Steam state.
"""
from __future__ import annotations

import json
import tempfile
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw

import campaign_direction4_coverage_audit as audit
import skirmish_direction4_action_pipeline as pipeline
import skirmish_direction4_action_pipeline_selftest as fixture


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def build_archer_sw_revision_fixture(root: Path) -> tuple[Path, Path, dict[str, Any]]:
    """Install a synthetic committed revision without invoking the real writer."""
    production = root / "assets" / "anim"
    qa = root / "qa" / "skirmish_direction4_fix_20260905"
    source_path = root / audit.SKIRMISH_ARCHER_SW_SOURCE_REL
    prompt_path = root / audit.SKIRMISH_ARCHER_SW_PROMPT_REL
    backup = root / audit.SKIRMISH_ARCHER_SW_BACKUP_REL
    revision_path = root / audit.SKIRMISH_ARCHER_SW_REVISION_REL
    source_path.parent.mkdir(parents=True, exist_ok=True)
    backup.mkdir(parents=True, exist_ok=False)

    source = Image.new("RGBA", (1774, 887), (0, 0, 0, 0))
    draw = ImageDraw.Draw(source)
    # Deliberately use the same complete-alpha rectangles as the real source so
    # the fixture exercises both scale constraints and fit-shift metadata.
    draw.rectangle((156, 23, 848, 855), fill=(118, 72, 43, 255))
    draw.rectangle((993, 122, 1674, 828), fill=(72, 96, 118, 255))
    source.save(source_path)
    prompt_path.write_text(
        "SW archer idle and walk-step source; true transparent RGBA; no mirroring.\n",
        encoding="utf-8",
    )

    before: dict[str, str] = {}
    for target in audit.SKIRMISH_ARCHER_SW_TARGETS:
        live = production / target
        (backup / target).write_bytes(live.read_bytes())
        before[target] = audit.sha256(live)

    cells = (source.crop((0, 0, 887, 887)), source.crop((887, 0, 1774, 887)))
    bboxes = tuple(cell.getchannel("A").getbbox() for cell in cells)
    assert all(bbox is not None for bbox in bboxes)
    scale = min(198 / 653, *(248 / max(b[2] - b[0], b[3] - b[1]) for b in bboxes))
    normalized: dict[str, Image.Image] = {}
    placements: dict[str, dict[str, Any]] = {}
    for pose, cell, bbox, pivot, half_x in zip(
        ("idle", "walk_step"), cells, bboxes, ((510, 799), (463, 810)), (0, 887)
    ):
        body = cell.crop(bbox)
        resized = body.resize(
            (round(body.width * scale), round(body.height * scale)), Image.Resampling.LANCZOS
        )
        desired = (
            128 - round((pivot[0] - bbox[0]) * scale),
            210 - round((pivot[1] - bbox[1]) * scale),
        )
        xy = (
            max(4, min(desired[0], 252 - resized.width)),
            max(4, min(desired[1], 252 - resized.height)),
        )
        canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        canvas.paste(resized, xy)
        normalized[pose] = canvas
        placements[pose] = {
            "crop_in_half": list(bbox),
            "half_x": half_x,
            "virtual_ground_pivot_in_half": list(pivot),
            "scale": scale,
            "paste_xy": list(xy),
            "fit_shift_xy_px": [xy[0] - desired[0], xy[1] - desired[1]],
            "alpha_bbox": list(canvas.getchannel("A").getbbox()),
        }

    old_attack = Image.open(backup / "guan_gong_attack_sw.png")
    old_death = Image.open(backup / "guan_gong_death_sw.png")
    idle = normalized["idle"]
    recipes = {
        "idle": [idle],
        "walk": [idle, normalized["walk_step"]],
        "attack": [idle, old_attack.crop((256, 0, 512, 256)), idle],
        "death": [idle]
        + [old_death.crop((index * 256, 0, (index + 1) * 256, 256)) for index in range(1, 4)],
    }
    outputs: list[dict[str, Any]] = []
    for state, frames in recipes.items():
        target = f"guan_gong_{state}_sw.png"
        strip = Image.new("RGBA", (256 * len(frames), 256), (0, 0, 0, 0))
        for index, frame in enumerate(frames):
            strip.paste(frame, (index * 256, 0))
        strip.save(production / target)
        outputs.append({
            "target": target,
            "state": state,
            "unit": "guan_gong",
            "direction": "sw",
            "before_sha256": before[target],
            "sha256": audit.sha256(production / target),
            "frame_count": len(frames),
        })
    record = {
        "schema_version": 1,
        "kind": "skirmish_archer_sw_visual_revision",
        "status": "committed",
        "conversation": "https://chatgpt.com/c/00000000-0000-0000-0000-000000000001",
        "source": {"file": audit.SKIRMISH_ARCHER_SW_SOURCE_REL, "sha256": audit.sha256(source_path)},
        "prompt": {"file": audit.SKIRMISH_ARCHER_SW_PROMPT_REL, "sha256": audit.sha256(prompt_path)},
        "base_action_manifest_sha256": audit.sha256(root / audit.SKIRMISH_ACTION_MANIFEST_REL),
        "processing": audit.SKIRMISH_ARCHER_SW_PROCESSING,
        "placements": placements,
        "outputs": outputs,
        "visual_review": audit.SKIRMISH_ARCHER_SW_VISUAL_REVIEW,
        "retained_frames": audit.SKIRMISH_ARCHER_SW_RETAINED,
    }
    write_json(revision_path, record)
    return source_path, revision_path, record


def assert_revision_only_rejected(rows: dict[str, dict[str, Any]]) -> None:
    revised = {f"assets/anim/{target}" for target in audit.SKIRMISH_ARCHER_SW_TARGETS}
    assert len(rows) == 49
    assert all(rows[path]["provenance_compliant"] is False for path in revised)
    assert all(row["provenance_compliant"] is True for path, row in rows.items() if path not in revised)


def run() -> dict[str, Any]:
    checks: list[str] = []
    with tempfile.TemporaryDirectory(prefix="direction4_coverage_provenance_") as temporary:
        root = Path(temporary).resolve()
        pipeline.ROOT = root
        pipeline.QA_ROOT = root / "qa" / "skirmish_direction4_actions_20260905"
        pipeline.REAL_PRODUCTION_ROOT = root / "assets" / "anim"
        pipeline.REAL_COMMIT_MANIFEST = root / audit.SKIRMISH_ACTION_MANIFEST_REL
        pipeline.REAL_CLEANUP_VERIFICATION = pipeline.QA_ROOT / "source" / "alpha_cleanup_verification.json"

        base = pipeline.QA_ROOT / "fixture"
        config_path, config, _ = fixture.create_fixture(base)
        config["canvas"]["max_content_width_px"] = 248
        config["canvas"]["max_content_height_px"] = 248
        config["canvas"]["max_walk_attack_fit_shift_px"] = 20
        anchors_path = pipeline.resolve_path(config["anchors_file"])
        anchors = json.loads(anchors_path.read_text(encoding="utf-8"))
        anchors["schema_version"] = 1
        for entry in anchors["entries"]:
            x0, y0, x1, y1 = entry["manual_source_rect"]
            entry["manual_source_rect"] = {"x0": x0, "y0": y0, "x1": x1, "y1": y1}
        write_json(anchors_path, anchors)
        config["anchors_sha256"] = pipeline.sha256_file(anchors_path)
        config["scope"] = "production"
        config["paths"]["production_root"] = pipeline.relative_to_root(pipeline.REAL_PRODUCTION_ROOT)
        config["paths"]["commit_manifest"] = pipeline.relative_to_root(pipeline.REAL_COMMIT_MANIFEST)
        pipeline.REAL_PRODUCTION_ROOT.mkdir(parents=True, exist_ok=True)
        for idle in config["idle_inputs"]:
            original_idle = pipeline.resolve_path(idle["file"])
            live_idle = pipeline.REAL_PRODUCTION_ROOT / original_idle.name
            live_idle.write_bytes(original_idle.read_bytes())
            idle["file"] = pipeline.relative_to_root(live_idle)
        reviewed_source = pipeline.QA_ROOT / "source"
        canonical_source = reviewed_source / "web_upload_canonical"
        reviewed_source.mkdir(parents=True, exist_ok=True)
        canonical_source.mkdir(parents=True, exist_ok=True)
        conversation = "https://chatgpt.com/c/00000000-0000-0000-0000-000000000001"
        verification_results: list[dict[str, Any]] = []
        for source in config["sources"]:
            pose = source["pose"]
            original = pipeline.resolve_path(source["file"]).read_bytes()
            cleaned = reviewed_source / f"{pose}_cleaned.png"
            raw_generated = reviewed_source / f"{pose}_raw.png"
            canonical = canonical_source / f"{pose}_web_upload.png"
            cleaned.write_bytes(original)
            raw_generated.write_bytes(original + b"raw-browser-generation")
            canonical.write_bytes(original + b"browser-upload-reencode")
            source["file"] = pipeline.relative_to_root(cleaned)
            source["sha256"] = pipeline.sha256_file(cleaned)
            source["raw_generated_file"] = pipeline.relative_to_root(raw_generated)
            source["raw_generated_sha256"] = pipeline.sha256_file(raw_generated)
            source["conversation"] = conversation
            source["browser_cleanup"] = {
                "method": "browser_python_pillow_alpha_le_15_rgba_zero",
                "confirmed": True,
                "input_role": "web_upload_canonical",
                "browser_upload_reencoded": True,
                "exactness_basis": "web_upload_canonical",
                "input_file": pipeline.relative_to_root(canonical),
                "input_sha256": pipeline.sha256_file(canonical),
                "output_sha256": source["sha256"],
                "cleared_pixel_count": 0,
                "prompt_file": source["prompt_file"],
                "prompt_sha256": source["prompt_sha256"],
                "verification_file": pipeline.relative_to_root(pipeline.REAL_CLEANUP_VERIFICATION),
            }
            verification_results.append({
                "pose": pose,
                "raw_generated_file": raw_generated.relative_to(reviewed_source).as_posix(),
                "raw_generated_sha256": pipeline.sha256_file(raw_generated),
                "input_file": canonical.relative_to(reviewed_source).as_posix(),
                "input_sha256": pipeline.sha256_file(canonical),
                "output_file": cleaned.relative_to(reviewed_source).as_posix(),
                "output_sha256": pipeline.sha256_file(cleaned),
                "alpha_le_15_pixels": 0,
                "changed_pixels": 0,
                "alpha_gt_15_mismatch_pixels": 0,
                "alpha_le_15_output_nonzero_pixels": 0,
            })
        write_json(pipeline.REAL_CLEANUP_VERIFICATION, {
            "schema_version": 1,
            "kind": "browser_alpha_cleanup_verification",
            "method": "browser_python_pillow_alpha_le_15_rgba_zero",
            "conversation": conversation,
            "local_verification": "Synthetic hash-chain fixture only.",
            "provenance_note": "Synthetic browser upload was re-encoded; exactness is based on web_upload_canonical.",
            "results": verification_results,
            "passed": True,
        })
        verification_sha = pipeline.sha256_file(pipeline.REAL_CLEANUP_VERIFICATION)
        for source in config["sources"]:
            source["browser_cleanup"]["verification_sha256"] = verification_sha
        write_json(config_path, config)

        assert audit.skirmish_action_provenance_index(root=root) == {}
        checks.append("missing production manifest leaves no provenance rows")

        pipeline.stage(config_path)
        fixture.bind_approval(config_path)
        pipeline.commit_stage(config_path, allow_replace_approved_targets=False)

        accepted = audit.skirmish_action_provenance_index(root=root)
        assert len(accepted) == 48
        assert all(row["provenance_compliant"] is True for row in accepted.values())
        checks.append("complete chain accepts 48 strips with schema-1 object-rect semantic anchors")

        target = pipeline.REAL_PRODUCTION_ROOT / "guan_dao_attack_ne.png"
        pristine_target = target.read_bytes()
        target.write_bytes(pristine_target + b"production-drift")
        drifted = audit.skirmish_action_provenance_index(root=root)
        assert len(drifted) == 48
        assert all(row["provenance_compliant"] is False for row in drifted.values())
        target.write_bytes(pristine_target)
        checks.append("one production hash drift rejects the complete batch")

        prompt = pipeline.resolve_path(config["sources"][0]["prompt_file"])
        pristine_prompt = prompt.read_bytes()
        prompt.write_bytes(pristine_prompt + b"prompt-drift")
        drifted = audit.skirmish_action_provenance_index(root=root)
        assert len(drifted) == 48
        assert all(row["provenance_compliant"] is False for row in drifted.values())
        prompt.write_bytes(pristine_prompt)
        checks.append("one source prompt hash drift rejects the complete batch")

        restored = audit.skirmish_action_provenance_index(root=root)
        assert len(restored) == 48
        assert all(row["provenance_compliant"] is True for row in restored.values())
        checks.append("restored immutable inputs restore acceptance")

        source_path, revision_path, revision = build_archer_sw_revision_fixture(root)
        revised = audit.skirmish_action_provenance_index(root=root)
        assert len(revised) == 49
        assert all(row["provenance_compliant"] is True for row in revised.values())
        for target in audit.SKIRMISH_ARCHER_SW_TARGETS:
            row = revised[f"assets/anim/{target}"]
            assert row["manifest"] == audit.SKIRMISH_ARCHER_SW_REVISION_REL
            assert row["kind"] == "skirmish_archer_sw_visual_revision"
        checks.append("committed four-target revision preserves 48 base strips and binds idle plus three actions to revision evidence")

        pristine_source = source_path.read_bytes()
        pristine_revision = revision_path.read_bytes()
        changed_source = Image.open(source_path)
        changed_source.putpixel((200, 100), (1, 2, 3, 255))
        changed_source.save(source_path)
        source_changed_manifest = json.loads(pristine_revision.decode("utf-8"))
        source_changed_manifest["source"]["sha256"] = audit.sha256(source_path)
        write_json(revision_path, source_changed_manifest)
        assert_revision_only_rejected(audit.skirmish_action_provenance_index(root=root))
        source_path.write_bytes(pristine_source)
        revision_path.write_bytes(pristine_revision)
        checks.append("source pixel drift rejects revised idle and actions even when its manifest hash is refreshed")

        missing_backup = root / audit.SKIRMISH_ARCHER_SW_BACKUP_REL / "guan_gong_idle_sw.png"
        pristine_backup = missing_backup.read_bytes()
        missing_backup.unlink()
        missing = audit.skirmish_action_provenance_index(root=root)
        assert len(missing) == 49
        assert all(row["provenance_compliant"] is False for row in missing.values())
        missing_backup.write_bytes(pristine_backup)
        checks.append("missing original backup rejects both the old base chain and the dependent revision")

        extra_target_manifest = json.loads(pristine_revision.decode("utf-8"))
        extra_row = dict(extra_target_manifest["outputs"][0])
        extra_row["target"] = "guan_gong_hurt_sw.png"
        extra_row["state"] = "hurt"
        extra_target_manifest["outputs"].append(extra_row)
        write_json(revision_path, extra_target_manifest)
        assert_revision_only_rejected(audit.skirmish_action_provenance_index(root=root))
        revision_path.write_bytes(pristine_revision)
        checks.append("an extra revision target rejects revised idle and actions without loosening the other 45 action strips")

        changed_live = pipeline.REAL_PRODUCTION_ROOT / "guan_gong_walk_sw.png"
        pristine_live = changed_live.read_bytes()
        changed_image = Image.open(changed_live)
        alpha_bbox = changed_image.getchannel("A").getbbox()
        assert alpha_bbox is not None
        x, y = alpha_bbox[0], alpha_bbox[1]
        red, green, blue, alpha = changed_image.getpixel((x, y))
        changed_image.putpixel((x, y), ((red + 1) % 256, green, blue, alpha))
        changed_image.save(changed_live)
        assert_revision_only_rejected(audit.skirmish_action_provenance_index(root=root))
        changed_live.write_bytes(pristine_live)
        checks.append("a revised production PNG pixel drift rejects revised idle and all three dependent actions")

        final = audit.skirmish_action_provenance_index(root=root)
        assert len(final) == 49
        assert all(row["provenance_compliant"] is True for row in final.values())
        checks.append("restoring source, backups, manifest scope, and live PNG restores the full chain")

    return {
        "passed": True,
        "kind": "campaign_direction4_coverage_action_provenance_selftest",
        "checks": checks,
        "real_production_written": False,
        "steam_modified_or_exported": False,
    }


if __name__ == "__main__":
    print(json.dumps(run(), ensure_ascii=False, indent=2))
