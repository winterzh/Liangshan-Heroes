#!/usr/bin/env python3
"""Install the reviewed Lu Zhishen Wild Boar Forest four-direction batch.

The source pixels are already frozen in the reviewed candidate directory.  This
installer only verifies hashes and copies complete PNG files byte-for-byte.  It
does not crop, resize, mask, clear, mirror, repaint, or otherwise edit pixels.
"""

from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
from typing import Any

from PIL import Image


REPO = Path(__file__).resolve().parents[1]
WORKSPACE = REPO.parent
CANDIDATE_DIR = REPO / "qa" / "lu_zhishen_1x4_candidate_pipeline_alpha15_exact_20260902"
CANDIDATE_OUTPUTS = CANDIDATE_DIR / "candidate_outputs"
CANDIDATE_MANIFEST = CANDIDATE_DIR / "candidate_manifest.json"
CANDIDATE_MANIFEST_SHA256 = "be0c9d6d9630a75048f5a6d57f6e3b57ab1d0650e5e917d04ce82ee0928a808e"
PREVIEW = CANDIDATE_DIR / "runtime_size_fringe_preview.png"
PREVIEW_SHA256 = "7268ad02213a026dda0f7659dff7d2c76486b5ae84a0b05c93223d51be5d7065"
WEB_VERIFICATION = REPO / "qa" / "lu_zhishen_web_exact_alpha15_20260902" / "verification.json"
WEB_VERIFICATION_SHA256 = "022065d44bb2d4e1d0cbef67720d8ee9372253e07dd0738d209534e85c0e3f6b"
PRODUCTION_MANIFEST = REPO / "assets" / "campaign" / "lu_zhishen_rescue_direction4_manifest.json"
SOURCE_GENERATION_CONVERSATION = "https://chatgpt.com/c/6a97a202-ee68-83ea-af84-947950d3c312"
EXACT_ALPHA_CONVERSATION = "https://chatgpt.com/c/6a97acd9-6240-83ea-b207-7aa4ef10b26f"
INPUT_ARCHIVE_SHA256 = "99a541680737ecbad3be9a09c0515fe97796a2375666525530edca1b82e03883"
DOWNLOAD_ARCHIVE_SHA256 = "4cd8a28bcf2c9441a8995048510b4bf6a8826e3414eab528b016b208421b9d96"
STATES = ("idle", "walk", "attack", "hurt", "down")
DIRECTIONS = ("se", "sw", "ne", "nw")

PROMPTS = {
    "idle": {
        "base": "implementation_20260902/prompt_drafts_v3/corrections/lu_zhishen_idle_isolated_4dir.txt",
        "base_sha256": "19185ac4b7c2f4262f8af4f3fe75e739dc84e96d2d844c6fcf194754c3db2f25",
    },
    "walk": {
        "base": "implementation_20260902/prompt_drafts_v3/corrections/lu_zhishen_walk_isolated_4dir.txt",
        "base_sha256": "ec6a333d822fd88ff72c058f0f4f96e60fa004f64d53ac6ef38aa0da23e12abc",
        "correction": "implementation_20260902/prompt_drafts_v3/corrections/lu_zhishen_walk_attempt2_true_alpha.txt",
        "correction_sha256": "c486c10cf382cbe8468da1f889c12c7c613285beac898ff178668151ccceb73f",
    },
    "attack": {
        "base": "implementation_20260902/prompt_drafts_v3/corrections/lu_zhishen_attack_isolated_4dir.txt",
        "base_sha256": "94fe55b9758ebbe9bdad1bcc7e175a2512f582a4f1131cde5b950fadc58c3f14",
    },
    "hurt": {
        "base": "implementation_20260902/prompt_drafts_v3/corrections/lu_zhishen_hurt_isolated_4dir.txt",
        "base_sha256": "53098d3a1f6474da78bfa730e3d12b651198a4f94708ffd1d1c962f33dbdd0c9",
    },
    "down": {
        "base": "implementation_20260902/prompt_drafts_v3/corrections/lu_zhishen_down_isolated_4dir.txt",
        "base_sha256": "2d4373ed3550d0a0b2c00888f2e6b53732d0b42afbb1134c9288e3f23b880e54",
        "correction": "implementation_20260902/prompt_drafts_v3/corrections/lu_zhishen_down_attempt2_true_alpha.txt",
        "correction_sha256": "5414fb70d5ee8b861b1df1dca9d47318a8d298293fbff5c32d378256ba300269",
    },
}
ALPHA_PROMPT = {
    "path": "implementation_20260902/prompt_drafts_v3/corrections/lu_zhishen_alpha15_zip_exact_web_python.txt",
    "sha256": "cb2e30fa6341ff244dffd819787c59e7f34a1bbbe663b1fe35b3d725cfbe044c",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_json_atomic(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def copy_bytes_atomic(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=target.name + ".", suffix=".tmp", dir=target.parent)
    os.close(fd)
    try:
        shutil.copyfile(source, temporary)
        if sha256(Path(temporary)) != sha256(source):
            raise IOError(f"temporary copy hash mismatch: {target}")
        os.replace(temporary, target)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def workspace_path(relative: str) -> Path:
    path = (WORKSPACE / relative).resolve()
    if WORKSPACE.resolve() not in path.parents:
        raise ValueError(f"path escapes workspace: {relative}")
    return path


def snapshot_tree(root: Path) -> dict[str, str]:
    if not root.exists():
        return {}
    return {
        path.relative_to(root).as_posix(): sha256(path)
        for path in sorted(item for item in root.rglob("*") if item.is_file())
    }


def png_contract(path: Path) -> dict[str, Any]:
    with Image.open(path) as image:
        image.load()
        if image.mode != "RGBA" or image.size != (256, 256):
            raise ValueError(f"invalid candidate PNG: {path} {image.mode} {image.size}")
        alpha = image.getchannel("A")
        edges = [
            alpha.crop((0, 0, 256, 1)), alpha.crop((0, 255, 256, 256)),
            alpha.crop((0, 1, 1, 255)), alpha.crop((255, 1, 256, 255)),
        ]
        border_max = max(edge.getextrema()[1] for edge in edges)
        if border_max != 0:
            raise ValueError(f"candidate has a nontransparent perimeter: {path}")
        return {"mode": image.mode, "size": list(image.size), "perimeter_max_alpha": border_max}


def steam_snapshot() -> dict[str, Any]:
    steam = Path(r"C:\Users\rsb\Documents\Steamworks\Liangshan_5088120")
    files = snapshot_tree(steam)
    aggregate = hashlib.sha256()
    for name, digest in files.items():
        aggregate.update(name.encode("utf-8"))
        aggregate.update(b"\0")
        aggregate.update(digest.encode("ascii"))
        aggregate.update(b"\n")
    return {"path": str(steam), "file_count": len(files), "aggregate_sha256": aggregate.hexdigest()}


def load_frames() -> tuple[dict[str, Any], list[dict[str, Any]]]:
    if sha256(CANDIDATE_MANIFEST) != CANDIDATE_MANIFEST_SHA256:
        raise ValueError("candidate manifest SHA-256 mismatch")
    if sha256(PREVIEW) != PREVIEW_SHA256:
        raise ValueError("candidate preview SHA-256 mismatch")
    if sha256(WEB_VERIFICATION) != WEB_VERIFICATION_SHA256:
        raise ValueError("exact-alpha verification SHA-256 mismatch")
    verification = json.loads(WEB_VERIFICATION.read_text(encoding="utf-8"))
    if not verification.get("all_pass"):
        raise ValueError("exact-alpha verification is not PASS")
    if verification.get("web_input_zip_sha256", "").lower() != INPUT_ARCHIVE_SHA256:
        raise ValueError("exact-alpha input archive mismatch")
    if verification.get("download_zip_sha256", "").lower() != DOWNLOAD_ARCHIVE_SHA256:
        raise ValueError("exact-alpha download archive mismatch")

    manifest = json.loads(CANDIDATE_MANIFEST.read_text(encoding="utf-8"))
    scope = manifest.get("scope", {})
    manual = manifest.get("fringe_review", {}).get("manual_review", {})
    if (
        manifest.get("status") != "candidate_crop_pass_not_production_approved"
        or scope.get("candidate_output_count") != 20
        or scope.get("production_assets_modified") is not False
        or manifest.get("proof", {}).get("all_outputs_same_size") is not True
        or manual.get("decision") != "visual_candidate_pass"
        or manual.get("identity_and_weapon_review", {}).get("one_piece_dark_iron_staff_with_simple_ends") is not True
    ):
        raise ValueError("candidate acceptance contract changed")
    outputs = manifest.get("outputs", [])
    selected: list[dict[str, Any]] = []
    seen: set[tuple[str, str]] = set()
    for record in outputs:
        state = str(record.get("action", ""))
        direction = str(record.get("direction", ""))
        if state not in STATES or direction not in DIRECTIONS:
            continue
        key = (state, direction)
        if key in seen:
            raise ValueError(f"duplicate candidate output: {key}")
        seen.add(key)
        candidate = CANDIDATE_OUTPUTS / f"lu_zhishen_rescue_{state}_{direction}.png"
        if not candidate.is_file() or sha256(candidate) != str(record.get("output_sha256", "")):
            raise ValueError(f"candidate output hash mismatch: {candidate}")
        contract = png_contract(candidate)
        target = REPO / "assets" / "campaign" / "anim" / candidate.name
        selected.append({
            "state": state, "direction": direction, "candidate": candidate,
            "target": target, "candidate_sha256": sha256(candidate),
            "candidate_record": record, "png_contract": contract,
        })
    if len(selected) != 20 or seen != {(state, direction) for state in STATES for direction in DIRECTIONS}:
        raise ValueError(f"expected exact 20-frame matrix, got {len(selected)}")
    return manifest, selected


def verify_prompts() -> dict[str, Any]:
    records: dict[str, Any] = {}
    for state, prompt in PROMPTS.items():
        entry = dict(prompt)
        for label in ("base", "correction"):
            if label not in prompt:
                continue
            path = workspace_path(str(prompt[label]))
            expected = str(prompt[label + "_sha256"])
            if not path.is_file() or sha256(path) != expected:
                raise ValueError(f"{state} {label} prompt mismatch: {path}")
        records[state] = entry
    alpha_path = workspace_path(ALPHA_PROMPT["path"])
    if not alpha_path.is_file() or sha256(alpha_path) != ALPHA_PROMPT["sha256"]:
        raise ValueError("exact-alpha prompt mismatch")
    return records


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--backup-dir", type=Path, required=True)
    parser.add_argument("--report", type=Path, default=REPO / "qa" / "lu_zhishen_direction4_production_20260902" / "install_report.json")
    args = parser.parse_args()
    backup = args.backup_dir.resolve()
    if backup.exists():
        raise FileExistsError(f"backup already exists: {backup}")
    if WORKSPACE.resolve() not in backup.parents or REPO.resolve() in backup.parents:
        raise ValueError("backup must be outside the repository and inside the Water Margin workspace")
    if "steamworks" in str(backup).lower():
        raise ValueError("Steamworks paths are forbidden")

    candidate_manifest, frames = load_frames()
    prompt_records = verify_prompts()
    steam_before = steam_snapshot()
    backup.mkdir(parents=True)
    mutable_code = [
        REPO / "scripts" / "campaign_art.gd",
        REPO / "tools" / "campaign_art_contract.gd",
        REPO / "docs" / "CAMPAIGN_IMPLEMENTATION.md",
        WORKSPACE / "WORKLOG.md",
    ]
    targets = [frame["target"] for frame in frames] + [
        REPO / "assets" / "campaign" / "portraits" / "lu_zhishen_rescue.png",
        PRODUCTION_MANIFEST,
        *mutable_code,
    ]
    backup_records: list[dict[str, Any]] = []
    for target in targets:
        relative = target.relative_to(WORKSPACE).as_posix()
        record = {
            "path": relative,
            "existed": target.is_file(),
            "sha256": sha256(target) if target.is_file() else None,
            "bytes": target.stat().st_size if target.is_file() else 0,
            "backup": None,
        }
        if target.is_file():
            destination = backup / "files" / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, destination)
            if sha256(destination) != record["sha256"]:
                raise IOError(f"backup hash mismatch: {target}")
            record["backup"] = destination.relative_to(backup).as_posix()
        backup_records.append(record)
    backup_manifest = {
        "schema_version": 1,
        "kind": "lu_zhishen_direction4_prewrite_backup",
        "created_at": datetime.now().astimezone().isoformat(),
        "complete_before_production_write": True,
        "candidate_manifest_sha256": CANDIDATE_MANIFEST_SHA256,
        "targets": backup_records,
        "campaign_anim_png_before": {
            name: digest for name, digest in snapshot_tree(REPO / "assets" / "campaign" / "anim").items()
            if name.lower().endswith(".png")
        },
        "campaign_portrait_png_before": {
            name: digest for name, digest in snapshot_tree(REPO / "assets" / "campaign" / "portraits").items()
            if name.lower().endswith(".png")
        },
        "steam_before": steam_before,
    }
    write_json_atomic(backup / "backup_manifest.json", backup_manifest)

    for frame in frames:
        copy_bytes_atomic(frame["candidate"], frame["target"])
        if sha256(frame["target"]) != frame["candidate_sha256"]:
            raise IOError(f"production target differs from candidate: {frame['target']}")
    portrait_source = CANDIDATE_OUTPUTS / "lu_zhishen_rescue_idle_se.png"
    portrait_target = REPO / "assets" / "campaign" / "portraits" / "lu_zhishen_rescue.png"
    copy_bytes_atomic(portrait_source, portrait_target)

    production_outputs = []
    for frame in frames:
        record = frame["candidate_record"]
        production_outputs.append({
            "variant": "lu_zhishen_rescue",
            "state": frame["state"],
            "direction": frame["direction"],
            "path": frame["target"].relative_to(REPO).as_posix(),
            "sha256": frame["candidate_sha256"],
            "copy_is_byte_identical_to_candidate": True,
            "source_file": record.get("source_file"),
            "source_sha256": record.get("source_sha256"),
            "source_cell_rect_xyxy": record.get("source_cell_rect_xyxy"),
            "source_rect_xyxy": record.get("source_rect_xyxy"),
            "source_anchor_xy": record.get("source_anchor_xy"),
            "batch_uniform_requested_scale": record.get("batch_uniform_requested_scale"),
            "actual_scale_xy_after_integer_rounding": record.get("actual_scale_xy_after_integer_rounding"),
            "resized_size": record.get("resized_size"),
            "paste_xy": record.get("paste_xy"),
            "target_anchor_xy": record.get("target_anchor_xy"),
        })
    source_records = []
    verification_by_output = {item["output"].lower(): item for item in json.loads(WEB_VERIFICATION.read_text(encoding="utf-8"))["files"]}
    for source in candidate_manifest["sources"]:
        cleaned_name = str(source["file"])
        exact = verification_by_output.get(cleaned_name.lower())
        if not exact:
            raise ValueError(f"missing exact-alpha source verification: {cleaned_name}")
        action = str(source["action"])
        source_records.append({
            "action": action,
            "raw_file": exact["source"], "raw_sha256": exact["source_sha256"].lower(),
            "cleaned_file": cleaned_name, "cleaned_sha256": source["sha256"],
            "cleaned_mode": source["mode"], "cleaned_size": source["size"],
            "source_generation_conversation": SOURCE_GENERATION_CONVERSATION,
            "exact_alpha_cleanup_conversation": EXACT_ALPHA_CONVERSATION,
            "base_prompt": prompt_records[action]["base"],
            "base_prompt_sha256": prompt_records[action]["base_sha256"],
            "correction_prompt": prompt_records[action].get("correction"),
            "correction_prompt_sha256": prompt_records[action].get("correction_sha256"),
            "exact_alpha_prompt": ALPHA_PROMPT["path"],
            "exact_alpha_prompt_sha256": ALPHA_PROMPT["sha256"],
            "exact_alpha_rule": "alpha <= 15 becomes RGBA 0,0,0,0; every alpha > 15 pixel remains byte-identical",
        })
    production_payload = {
        "schema_version": 1,
        "kind": "lu_zhishen_rescue_direction4_production_provenance",
        "created_at": datetime.now().astimezone().isoformat(),
        "variant": "lu_zhishen_rescue",
        "states": list(STATES), "directions": list(DIRECTIONS), "frame_count": 20,
        "source_generation_conversation": SOURCE_GENERATION_CONVERSATION,
        "exact_alpha_cleanup_conversation": EXACT_ALPHA_CONVERSATION,
        "web_input_archive_sha256": INPUT_ARCHIVE_SHA256,
        "web_download_archive_sha256": DOWNLOAD_ARCHIVE_SHA256,
        "exact_alpha_verification": WEB_VERIFICATION.relative_to(REPO).as_posix(),
        "exact_alpha_verification_sha256": WEB_VERIFICATION_SHA256,
        "candidate_manifest": CANDIDATE_MANIFEST.relative_to(REPO).as_posix(),
        "candidate_manifest_sha256": CANDIDATE_MANIFEST_SHA256,
        "candidate_preview": PREVIEW.relative_to(REPO).as_posix(),
        "candidate_preview_sha256": PREVIEW_SHA256,
        "allowed_operations": ["continuous source rectangle crop", "batch-uniform proportional scale", "transparent padding", "byte-identical production copy"],
        "forbidden_operations_used": [],
        "sources": source_records,
        "outputs": production_outputs,
        "portrait": {
            "path": portrait_target.relative_to(REPO).as_posix(),
            "sha256": sha256(portrait_target),
            "byte_identical_source": "assets/campaign/anim/lu_zhishen_rescue_idle_se.png",
        },
        "runtime_route": {
            "ordinary_states": "idle/walk/attack/hurt/down resolve through CampaignArt.animation_path",
            "intercept": "lu_zhishen_rescue/intercept explicitly aliases to the exact same-direction attack asset",
            "death": "not supplied and never aliases to down",
            "free_modes": "variant-empty lu_zhishen keeps generic assets and portrait",
        },
        "steam_modified_or_exported": False,
    }
    write_json_atomic(PRODUCTION_MANIFEST, production_payload)
    steam_after = steam_snapshot()
    report = {
        "schema_version": 1,
        "kind": "lu_zhishen_direction4_production_install",
        "created_at": datetime.now().astimezone().isoformat(),
        "passed": True,
        "backup_directory": str(backup),
        "backup_manifest": str(backup / "backup_manifest.json"),
        "backup_manifest_sha256": sha256(backup / "backup_manifest.json"),
        "copied_animation_pngs": 20,
        "portrait_byte_copy": True,
        "candidate_to_production_hash_match": all(sha256(frame["target"]) == frame["candidate_sha256"] for frame in frames),
        "production_manifest": PRODUCTION_MANIFEST.relative_to(REPO).as_posix(),
        "production_manifest_sha256": sha256(PRODUCTION_MANIFEST),
        "old_intercept_files_modified": False,
        "pixels_edited_during_install": 0,
        "steam_before": steam_before,
        "steam_after": steam_after,
        "steam_unchanged": steam_before == steam_after,
        "next_gate": "Apply and test the explicit intercept-to-attack runtime route; Godot import/runtime/visual/performance remain pending.",
    }
    write_json_atomic(args.report.resolve(), report)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
