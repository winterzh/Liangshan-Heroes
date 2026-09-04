#!/usr/bin/env python3
"""Install the reviewed Li Kui and hook-sickle four-direction batch.

This is deliberately narrower than the general candidate tools.  It accepts
only the ten frozen fixed-cell manifests produced on 2026-09-02 and installs
exactly two identities x five runtime states x four directions.  Candidate
``death`` labels from the two source manifests are renamed to the distinct
runtime ``down`` state; no death asset is created.

The image bytes have already been produced by a fixed rectangular crop,
row-uniform resize, and transparent padding.  This installer only verifies and
copies those complete PNGs.  It never masks, clears, mirrors, repaints, or
otherwise edits pixels.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
from typing import Any

from PIL import Image


REPO = Path(__file__).resolve().parents[1]
WORKSPACE = REPO.parent
ANIM_DIR = REPO / "assets" / "anim"
PRODUCTION_MANIFEST = REPO / "assets" / "direction4" / "manifest.json"
CANDIDATE_ROOT = REPO / "qa" / "direction4_fixed_crop_20260902"
FROZEN_REGISTRY = WORKSPACE / "implementation_20260902" / "web_sample_sources_20260902" / "fixed_cell_rect_candidates.json"
DIRECTIONS = ("se", "sw", "ne", "nw")

# unit, runtime state, candidate manifest, candidate directory, candidate state
BATCH = (
    ("li_kui", "idle", "heroes_manifest.json", "heroes", "idle"),
    ("li_kui", "walk", "heroes_walk_manifest.json", "heroes_walk", "walk"),
    ("li_kui", "attack", "heroes_attack_manifest.json", "heroes_attack", "attack"),
    ("li_kui", "hurt", "heroes_hurt_manifest.json", "heroes_hurt", "hurt"),
    ("li_kui", "down", "heroes_down_manifest.json", "heroes_down", "death"),
    ("gou_lian", "idle", "troops_manifest.json", "troops", "idle"),
    ("gou_lian", "walk", "troops_walk_manifest.json", "troops_walk", "walk"),
    ("gou_lian", "attack", "troops_attack_manifest.json", "troops_attack", "attack"),
    ("gou_lian", "hurt", "troops_hurt_manifest.json", "troops_hurt", "hurt"),
    ("gou_lian", "down", "troops_down_manifest.json", "troops_down", "death"),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical(path: Path) -> Path:
    return path.resolve(strict=False)


def relative_to_workspace(path: Path) -> str:
    return canonical(path).relative_to(canonical(WORKSPACE)).as_posix()


def ensure_external_backup(path: Path) -> None:
    resolved = canonical(path)
    if resolved == canonical(REPO) or canonical(REPO) in resolved.parents:
        raise ValueError(f"backup must be outside the repository: {resolved}")
    # Keep the backup in the explicitly scoped Water Margin workspace.  This
    # also prevents an accidental Steamworks path from ever being accepted.
    if resolved == canonical(WORKSPACE) or canonical(WORKSPACE) not in resolved.parents:
        raise ValueError(f"backup must stay inside the Water Margin workspace: {resolved}")
    lowered = str(resolved).lower()
    if "steamworks" in lowered or "liangshan_5088120" in lowered:
        raise ValueError(f"Steam paths are forbidden: {resolved}")


def json_read(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def json_write_atomic(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_name, path)
    except BaseException:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass
        raise


def directory_hashes(root: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    if not root.exists():
        return result
    for path in sorted(p for p in root.rglob("*") if p.is_file() and p.suffix.lower() == ".png"):
        result[path.relative_to(REPO).as_posix()] = sha256(path)
    return result


def png_contract(path: Path) -> dict[str, Any]:
    with Image.open(path) as image:
        image.load()
        if image.mode != "RGBA" or image.size != (256, 256):
            raise ValueError(f"unexpected PNG contract for {path}: {image.mode} {image.size}")
        alpha = image.getchannel("A")
        edges = (
            alpha.crop((0, 0, 256, 1)),
            alpha.crop((0, 255, 256, 256)),
            alpha.crop((0, 1, 1, 255)),
            alpha.crop((255, 1, 256, 255)),
        )
        border_max = max(edge.getextrema()[1] for edge in edges)
        if border_max != 0:
            raise ValueError(f"non-transparent output border for {path}: {border_max}")
        return {"mode": image.mode, "size": list(image.size), "border_max_alpha": border_max}


def resolve_ledger_path(value: str) -> Path:
    path = canonical(WORKSPACE / value)
    if path == canonical(WORKSPACE) or canonical(WORKSPACE) not in path.parents:
        raise ValueError(f"ledger path escapes workspace: {value}")
    return path


def load_batch() -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]]]:
    frames: list[dict[str, Any]] = []
    sources: dict[str, dict[str, Any]] = {}
    seen_targets: set[str] = set()
    registry = json_read(FROZEN_REGISTRY)
    if (
        registry.get("kind") != "web_chatgpt_direction4_fixed_cell_rect_candidates_v1"
        or registry.get("active_source_rule") != "fixed_cell_rect_v1"
        or not bool(registry.get("candidate_only"))
    ):
        raise ValueError("frozen fixed-rect candidate registry contract changed")
    registry_by_manifest = {
        str(entry.get("candidate_manifest", {}).get("path", "")): entry
        for entry in registry.get("entries", [])
    }
    for unit, runtime_state, manifest_name, candidate_dir, candidate_state in BATCH:
        manifest_path = CANDIDATE_ROOT / manifest_name
        data = json_read(manifest_path)
        if data.get("source_rule") != "fixed_cell_rect_v1":
            raise ValueError(f"{manifest_name}: source rule is not fixed_cell_rect_v1")
        if not bool(data.get("candidate_only")) or bool(data.get("production_assets_modified")):
            raise ValueError(f"{manifest_name}: frozen candidate flags changed")
        if data.get("policy", {}).get("forbidden") is None:
            raise ValueError(f"{manifest_name}: missing forbidden-operation policy")
        registry_key = f"Liangshan-Heroes/qa/direction4_fixed_crop_20260902/{manifest_name}"
        registry_entry = registry_by_manifest.get(registry_key)
        if not registry_entry:
            raise ValueError(f"{manifest_name}: not present in the frozen candidate registry")
        if sha256(manifest_path) != registry_entry.get("candidate_manifest", {}).get("sha256"):
            raise ValueError(f"{manifest_name}: candidate manifest hash differs from frozen registry")
        if (
            registry_entry.get("source_rule") != "fixed_cell_rect_v1"
            or tuple(registry_entry.get("directions", [])) != DIRECTIONS
            or unit not in registry_entry.get("rows", [])
            or registry_entry.get("group") != ("heroes" if unit == "li_kui" else "troops")
        ):
            raise ValueError(f"{manifest_name}: frozen registry identity/direction contract changed")
        source = data.get("source", {})
        raw_path = resolve_ledger_path(str(source.get("source_file", "")))
        if not raw_path.is_file() or sha256(raw_path) != source.get("raw_sha256"):
            raise ValueError(f"{manifest_name}: raw source hash mismatch")
        spec_path = resolve_ledger_path(str(data.get("spec_file", "")))
        if not spec_path.is_file() or sha256(spec_path) != data.get("spec_sha256"):
            raise ValueError(f"{manifest_name}: crop spec hash mismatch")
        for prompt_key in ("base_prompt", "correction_prompt"):
            prompt = source.get(prompt_key)
            if prompt:
                prompt_path = resolve_ledger_path(str(prompt.get("file", "")))
                if not prompt_path.is_file() or sha256(prompt_path) != prompt.get("sha256"):
                    raise ValueError(f"{manifest_name}: {prompt_key} hash mismatch")

        source_id = f"web_fixed_rect_{Path(manifest_name).stem}_20260902"
        sources[source_id] = {
            "file": source["source_file"],
            "sha256": source["raw_sha256"],
            "size": source["size"],
            "mode": source["mode"],
            "generation": "Web ChatGPT",
            "conversation_url": source["conversation_url"],
            "base_prompt": source["base_prompt"],
            "correction_prompt": source.get("correction_prompt"),
            "crop_spec_file": data["spec_file"],
            "crop_spec_sha256": data["spec_sha256"],
            "candidate_manifest": f"qa/direction4_fixed_crop_20260902/{manifest_name}",
            "candidate_manifest_sha256": sha256(manifest_path),
            "frozen_candidate_registry": relative_to_workspace(FROZEN_REGISTRY),
            "frozen_candidate_registry_sha256": sha256(FROZEN_REGISTRY),
            "frozen_registry_atlas_id": registry_entry["atlas_id"],
            "source_rule": "fixed_cell_rect_v1",
            "layout": {"kind": "fixed_cell_rect_v1", "directions": list(DIRECTIONS)},
            "retained_pixels": (
                "Every RGBA pixel inside each recorded fixed rectangular source cell is retained. "
                "Only row-uniform whole-cell scaling and transparent padding are used; no masking, "
                "pixel clearing, mirroring, repainting, or local direction editing."
            ),
        }

        selected = [
            output for output in data.get("outputs", [])
            if output.get("unit") == unit and output.get("state") == candidate_state
        ]
        by_direction = {str(output.get("direction")): output for output in selected}
        if set(by_direction) != set(DIRECTIONS) or len(selected) != 4:
            raise ValueError(f"{manifest_name}: expected exactly four {unit}/{candidate_state} outputs")
        scales = {float(output.get("scale", -1.0)) for output in selected}
        if len(scales) != 1 or next(iter(scales)) <= 0.0:
            raise ValueError(f"{manifest_name}: selected row does not use one uniform scale")

        for direction in DIRECTIONS:
            output = by_direction[direction]
            if output.get("source_rule") != "fixed_cell_rect_v1":
                raise ValueError(f"{manifest_name}/{direction}: wrong source rule")
            if output.get("forbidden_operations_used") != []:
                raise ValueError(f"{manifest_name}/{direction}: forbidden operation recorded")
            component = output.get("read_only_component_qa", {})
            if not bool(component.get("visible_component_complete")):
                raise ValueError(f"{manifest_name}/{direction}: incomplete visible component")
            if int(component.get("foreign_large_visible_pixels", -1)) != 0:
                raise ValueError(f"{manifest_name}/{direction}: foreign visible pixels")
            if output.get("scale_scope") != "uniform_across_identity_row":
                raise ValueError(f"{manifest_name}/{direction}: scale scope is not row-uniform")
            operation = str(output.get("source_to_crop_operation", "")).lower()
            if "every rgba pixel in the rectangle is retained" not in operation:
                raise ValueError(f"{manifest_name}/{direction}: whole-rectangle retention proof missing")

            candidate_path = CANDIDATE_ROOT / candidate_dir / f"{unit}_{candidate_state}_{direction}.png"
            if not candidate_path.is_file() or sha256(candidate_path) != output.get("output_sha256"):
                raise ValueError(f"{manifest_name}/{direction}: candidate output hash mismatch")
            contract = png_contract(candidate_path)
            target_rel = f"assets/anim/{unit}_{runtime_state}_{direction}.png"
            if target_rel in seen_targets:
                raise ValueError(f"duplicate production target: {target_rel}")
            seen_targets.add(target_rel)
            frames.append({
                "unit": unit,
                "state": runtime_state,
                "candidate_state": candidate_state,
                "direction": direction,
                "candidate": candidate_path,
                "candidate_rel": candidate_path.relative_to(REPO).as_posix(),
                "candidate_manifest": manifest_path,
                "candidate_manifest_rel": manifest_path.relative_to(REPO).as_posix(),
                "target": REPO / target_rel,
                "target_rel": target_rel,
                "source_id": source_id,
                "record": output,
                "png_contract": contract,
            })
    if len(frames) != 40:
        raise ValueError(f"batch cardinality changed: {len(frames)}")
    return frames, sources


def backup_before_write(backup_dir: Path, frames: list[dict[str, Any]], anim_snapshot: dict[str, str]) -> dict[str, Any]:
    ensure_external_backup(backup_dir)
    if backup_dir.exists():
        raise FileExistsError(f"backup directory already exists: {backup_dir}")
    backup_dir.mkdir(parents=True)
    records: list[dict[str, Any]] = []
    for frame in frames:
        target: Path = frame["target"]
        record = {
            "path": frame["target_rel"],
            "existed": target.is_file(),
            "sha256": sha256(target) if target.is_file() else None,
            "bytes": target.stat().st_size if target.is_file() else 0,
            "backup": None,
        }
        if target.is_file():
            backup_path = backup_dir / "files" / frame["target_rel"]
            backup_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, backup_path)
            if sha256(backup_path) != record["sha256"]:
                raise IOError(f"backup hash mismatch: {target}")
            record["backup"] = backup_path.relative_to(backup_dir).as_posix()
        records.append(record)

    manifest_backup = backup_dir / "files" / "assets" / "direction4" / "manifest.json"
    manifest_backup.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(PRODUCTION_MANIFEST, manifest_backup)
    manifest_hash = sha256(PRODUCTION_MANIFEST)
    if sha256(manifest_backup) != manifest_hash:
        raise IOError("production manifest backup hash mismatch")
    payload = {
        "schema_version": 1,
        "kind": "direction4_minimal_production_prewrite_backup",
        "backup_complete_before_production_write": True,
        "repository": str(REPO),
        "backup_directory": str(backup_dir),
        "scope": "li_kui and gou_lian; idle/walk/attack/hurt/down; four directions",
        "target_count": len(records),
        "targets": records,
        "production_manifest": {
            "path": "assets/direction4/manifest.json",
            "sha256": manifest_hash,
            "backup": manifest_backup.relative_to(backup_dir).as_posix(),
        },
        "assets_anim_png_snapshot": anim_snapshot,
    }
    backup_manifest = backup_dir / "backup_manifest.json"
    json_write_atomic(backup_manifest, payload)
    payload["backup_manifest_sha256"] = sha256(backup_manifest)
    return payload


def restore_backup(backup_dir: Path, backup: dict[str, Any]) -> None:
    for record in backup["targets"]:
        target = REPO / record["path"]
        if record["existed"]:
            saved = backup_dir / record["backup"]
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(saved, target)
        elif target.exists():
            target.unlink()
    saved_manifest = backup_dir / backup["production_manifest"]["backup"]
    shutil.copy2(saved_manifest, PRODUCTION_MANIFEST)


def production_output(frame: dict[str, Any]) -> dict[str, Any]:
    record = frame["record"]
    state_note = (
        "The source sheet used the candidate label death; this independent production file is mapped only "
        "to runtime down for a non-death story outcome. No death alias was created."
        if frame["state"] == "down" else "Candidate and runtime state names match."
    )
    return {
        "unit": frame["unit"],
        "state": frame["state"],
        "candidate_state": frame["candidate_state"],
        "direction": frame["direction"],
        "output": frame["target_rel"],
        "sha256": sha256(frame["candidate"]),
        "source": frame["source_id"],
        "source_rule": "fixed_cell_rect_v1",
        "layout": {"kind": "fixed_cell_rect_v1", "directions": list(DIRECTIONS)},
        "crop_rect": record["crop_rect"],
        "raw_crop_rgba_sha256": record["raw_crop_rgba_sha256"],
        "source_to_crop_operation": record["source_to_crop_operation"],
        "pre_scale_transparent_padding": record["pre_scale_transparent_padding"],
        "scale": record["scale"],
        "scale_scope": record["scale_scope"],
        "resampling": record["resampling"],
        "output_size": record["output_size"],
        "paste_xy": record["paste_xy"],
        "final_transparent_padding": record["final_transparent_padding"],
        "semantic_anchor": record["semantic_anchor"],
        "retained_pixels": (
            "The rectangular alpha-content crop is copied whole, then uniformly scaled as a complete unit "
            "and placed on transparent padding."
        ),
        "isolation": (
            "The rectangular alpha-content crop is copied whole; every in-rectangle RGBA pixel is retained. "
            "No mask, pixel clearing, mirroring, repainting, or local direction editing is used."
        ),
        "excluded_foreign_pixels": 0,
        "visible_component_complete": True,
        "forbidden_operations_used": [],
        "state_mapping_note": state_note,
    }


def install(frames: list[dict[str, Any]], sources: dict[str, dict[str, Any]]) -> None:
    for frame in frames:
        target: Path = frame["target"]
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(frame["candidate"], target)
        if sha256(target) != sha256(frame["candidate"]):
            raise IOError(f"production copy hash mismatch: {target}")

    manifest = json_read(PRODUCTION_MANIFEST)
    manifest_sources = manifest.setdefault("sources", {})
    manifest_sources.update(sources)
    target_units = {"li_kui", "gou_lian"}
    target_states = {"idle", "walk", "attack", "hurt", "down"}
    retained_outputs = [
        output for output in manifest.get("outputs", [])
        if not (output.get("unit") in target_units and output.get("state") in target_states)
    ]
    retained_outputs.extend(production_output(frame) for frame in frames)
    manifest["outputs"] = retained_outputs
    manifest["last_minimal_fixed_rect_batch"] = {
        "date": "2026-09-02",
        "units": ["li_kui", "gou_lian"],
        "runtime_states": ["idle", "walk", "attack", "hurt", "down"],
        "directions": list(DIRECTIONS),
        "frame_count": 40,
        "death_aliases_created": False,
        "allowed_operations": [
            "fixed continuous rectangular crop",
            "row-uniform whole-unit scaling",
            "transparent padding",
            "byte-identical candidate import",
        ],
        "forbidden_operations_used": [],
    }
    json_write_atomic(PRODUCTION_MANIFEST, manifest)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="write the verified 40-frame production batch")
    parser.add_argument("--backup-dir", type=Path, help="new external directory required with --apply")
    parser.add_argument("--report", type=Path, help="optional validation/install report")
    args = parser.parse_args()

    frames, sources = load_batch()
    death_paths = [ANIM_DIR / f"{unit}_death_{direction}.png" for unit in ("li_kui", "gou_lian") for direction in DIRECTIONS]
    existing_death = [str(path) for path in death_paths if path.exists()]
    if existing_death:
        raise ValueError(f"pre-existing death aliases would make the batch ambiguous: {existing_death}")

    pre_anim = directory_hashes(ANIM_DIR)
    result: dict[str, Any] = {
        "schema_version": 1,
        "kind": "direction4_minimal_production_install",
        "validated": True,
        "applied": False,
        "scope": {"units": ["li_kui", "gou_lian"], "states": ["idle", "walk", "attack", "hurt", "down"], "directions": list(DIRECTIONS)},
        "frame_count": len(frames),
        "source_manifest_count": len(sources),
        "death_aliases_before": existing_death,
        "candidate_frames": [
            {
                "target": frame["target_rel"],
                "candidate": frame["candidate_rel"],
                "sha256": sha256(frame["candidate"]),
                "candidate_manifest": frame["candidate_manifest_rel"],
                "crop_rect": frame["record"]["crop_rect"],
                "scale": frame["record"]["scale"],
                "pad": frame["record"]["final_transparent_padding"],
            }
            for frame in frames
        ],
    }

    if args.apply:
        if args.backup_dir is None:
            parser.error("--backup-dir is required with --apply")
        backup_dir = canonical(args.backup_dir)
        backup = backup_before_write(backup_dir, frames, pre_anim)
        result["backup"] = {
            "directory": str(backup_dir),
            "manifest": str(backup_dir / "backup_manifest.json"),
            "manifest_sha256": backup["backup_manifest_sha256"],
            "recorded_target_count": backup["target_count"],
            "completed_before_write": backup["backup_complete_before_production_write"],
        }
        try:
            install(frames, sources)
            post_anim = directory_hashes(ANIM_DIR)
            changed = sorted(
                path for path in set(pre_anim) | set(post_anim)
                if pre_anim.get(path) != post_anim.get(path)
            )
            expected_changed = sorted(frame["target_rel"] for frame in frames)
            if changed != expected_changed:
                raise RuntimeError({"unexpected_assets_anim_diff": changed, "expected": expected_changed})
            death_after = [str(path.relative_to(REPO)).replace("\\", "/") for path in death_paths if path.exists()]
            if death_after:
                raise RuntimeError(f"death aliases were created: {death_after}")
            result.update({
                "applied": True,
                "changed_assets_anim_files": changed,
                "changed_assets_anim_file_count": len(changed),
                "death_aliases_after": death_after,
                "production_manifest_sha256": sha256(PRODUCTION_MANIFEST),
                "rollback_performed": False,
            })
        except BaseException:
            restore_backup(backup_dir, backup)
            result["rollback_performed"] = True
            if args.report:
                json_write_atomic(canonical(args.report), result)
            raise

    if args.report:
        json_write_atomic(canonical(args.report), result)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
