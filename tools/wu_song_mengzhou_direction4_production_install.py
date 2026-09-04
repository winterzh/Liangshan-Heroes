#!/usr/bin/env python3
"""Install the reviewed Mengzhou Wu Song four-direction bitmap batch.

The reviewed candidate PNGs are frozen.  This installer verifies their complete
provenance chain and copies whole PNG files byte-for-byte.  It never crops,
rescales, masks, clears, mirrors, repaints, or otherwise changes pixels.
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
CANDIDATE_DIR = REPO / "qa" / "wu_song_mengzhou_1x4_candidate_pipeline_alpha15_exact_20260902"
CANDIDATE_OUTPUTS = CANDIDATE_DIR / "candidate_outputs"
CANDIDATE_MANIFEST = CANDIDATE_DIR / "candidate_manifest.json"
CANDIDATE_MANIFEST_SHA256 = "7ec6e4b75b047645fcad96064bd567c741800596bc579b841e6b4e77560b0096"
PREVIEW = CANDIDATE_DIR / "runtime_size_fringe_preview.png"
PREVIEW_SHA256 = "9ad3fae2d2ae228e3487c55d99720973c14b32ea2cadf92413f64b99bd6c78d6"
WEB_VERIFICATION = REPO / "qa" / "wu_song_mengzhou_alpha_audit_20260902" / "web_exact_verification.json"
WEB_VERIFICATION_SHA256 = "8696b63007454993b701dcf86a1c350f1c153f0f39194e1663f0babe22da2874"
PRODUCTION_MANIFEST = REPO / "assets" / "campaign" / "wu_song_mengzhou_direction4_manifest.json"
SOURCE_CONVERSATION = "https://chatgpt.com/c/6a97b18d-1254-83ea-83d1-9082e8c3d727"
HURT_CONVERSATION = "https://chatgpt.com/c/6a97b5fe-34cc-83e9-bcc3-bec983a80629"
ALPHA_CONVERSATION = "https://chatgpt.com/c/6a97b8bb-b8a8-83ea-bb53-31da6a87b4ce"
INPUT_ARCHIVE_SHA256 = "29d2e519e35520b338176b4f07b2d8517f4d7904b9cb78a3adb29026254001cb"
DOWNLOAD_ARCHIVE_SHA256 = "37f43b22191575f9fdf3fdcd2acf8b5c72edd58dfe4364bbc2fa7f37cad7ffc6"
STATES = ("idle", "walk", "attack", "hurt", "down")
DIRECTIONS = ("se", "sw", "ne", "nw")

PROMPTS = {
    "idle": ("implementation_20260902/prompt_drafts_v4/corrections/wu_song_idle_attempt5_fresh_reference.txt", "2d5aebc1c00d18fd060834b97794c04dcd751493f379d643d6763507d7f2a93e"),
    "walk": ("implementation_20260902/prompt_drafts_v4/corrections/wu_song_walk_attempt4_original_knee_alpha.txt", "8590a8d47055f4abfc5227c8f958a8426e3b0848c91181c3b9813705fc391369"),
    "attack": ("implementation_20260902/prompt_drafts_v4/corrections/wu_song_attack_attempt1_fresh_reference.txt", "83c473bec2edd1ef55d05befdbc11ed07bac0075c02b54fdeb070d27f660b0e2"),
    "hurt": ("implementation_20260902/prompt_drafts_v4/corrections/wu_song_hurt_attempt3_new_session_reference.txt", "f3ef9f6b4cea92f4655f3218da6a8a0d00224ce31424b728671ef8d8f4745865"),
    "down": ("implementation_20260902/prompt_drafts_v4/corrections/wu_song_down_attempt1_fresh_reference.txt", "fe71471299fd93627a42f2aee43f2238e3d752c461d7e7b2f70d508f22274df7"),
}
ALPHA_PROMPT = ("implementation_20260902/prompt_drafts_v4/corrections/wu_song_alpha15_exact_web_cleanup.txt", "95ae5fe6fada692f6a378017360c9f15ed46b497da10a081590748d0554bd854")

ORIGINAL_EVIDENCE = {
    "chapter_28": "https://zh.wikisource.org/zh-hans/水滸傳_(70回本)/第28回",
    "chapter_29": "https://zh.wikisource.org/zh-hans/水滸傳_(120回本)/第029回",
    "dabo_definition": "https://www.zdic.net/hans/褡膊",
    "attire": "万字头巾、土色布衫、红绢褡膊只系腰间、脸上小膏药遮金印、腿絣护膝、八搭麻鞋；赤手空拳",
    "signature_action": "玉环步接鸳鸯脚；本批 attack 取转身后的第二脚高踢",
    "adaptation_boundary": "hurt/down 是玩法所需非致死状态，不声称是原著中蒋门神击倒武松的情节",
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
    if WORKSPACE.resolve() != path and WORKSPACE.resolve() not in path.parents:
        raise ValueError(f"path escapes workspace: {relative}")
    return path


def snapshot_tree(root: Path) -> dict[str, str]:
    if not root.exists():
        return {}
    return {
        item.relative_to(root).as_posix(): sha256(item)
        for item in sorted(root.rglob("*")) if item.is_file()
    }


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


def verify_prompts() -> dict[str, Any]:
    records: dict[str, Any] = {}
    for state, (relative, expected) in PROMPTS.items():
        path = workspace_path(relative)
        if not path.is_file() or sha256(path) != expected:
            raise ValueError(f"{state} prompt mismatch: {path}")
        records[state] = {"path": relative, "sha256": expected}
    relative, expected = ALPHA_PROMPT
    alpha_path = workspace_path(relative)
    if not alpha_path.is_file() or sha256(alpha_path) != expected:
        raise ValueError(f"alpha prompt mismatch: {alpha_path}")
    return records


def load_verified() -> tuple[dict[str, Any], dict[str, Any], list[dict[str, Any]]]:
    expected_hashes = {
        CANDIDATE_MANIFEST: CANDIDATE_MANIFEST_SHA256,
        PREVIEW: PREVIEW_SHA256,
        WEB_VERIFICATION: WEB_VERIFICATION_SHA256,
    }
    for path, expected in expected_hashes.items():
        if not path.is_file() or sha256(path) != expected:
            raise ValueError(f"frozen evidence hash mismatch: {path}")
    manifest = json.loads(CANDIDATE_MANIFEST.read_text(encoding="utf-8"))
    verification = json.loads(WEB_VERIFICATION.read_text(encoding="utf-8"))
    identity = manifest.get("fringe_review", {}).get("manual_review", {}).get("identity_and_action_review", {})
    if not (
        manifest.get("status") == "candidate_crop_pass_not_production_approved"
        and manifest.get("scope", {}).get("candidate_output_count") == 20
        and manifest.get("scope", {}).get("production_assets_modified") is False
        and manifest.get("proof", {}).get("all_source_alpha_owned_exactly_once") is True
        and manifest.get("proof", {}).get("all_source_rect_perimeters_transparent") is True
        and manifest.get("proof", {}).get("all_output_anchor_y_within_3px") is True
        and manifest.get("proof", {}).get("all_output_perimeters_transparent") is True
        and manifest.get("fringe_review", {}).get("manual_review", {}).get("decision") == "visual_candidate_pass"
        and all(identity.get(key) is True for key in [
            "same_mengzhou_identity_all_actions_and_directions",
            "four_real_isometric_directions",
            "wan_pattern_headscarf_and_plain_face_plaster_present",
            "red_dabo_only_at_waist",
            "soft_cloth_leg_wraps_and_eight_strap_hemp_shoes",
            "later_pilgrim_outfit_and_weapons_absent",
            "attack_is_single_high_kick_after_turn",
        ])
    ):
        raise ValueError("candidate acceptance or original-identity contract changed")
    if not verification.get("all_pass") or not verification.get("verification_json_from_web_present"):
        raise ValueError("web exact-alpha verification is not PASS")
    if str(verification.get("zip_sha256", "")).lower() != DOWNLOAD_ARCHIVE_SHA256:
        raise ValueError("download archive hash mismatch")
    if str(manifest.get("web_source_provenance", {}).get("input_archive_sha256", "")).lower() != INPUT_ARCHIVE_SHA256:
        raise ValueError("input archive hash mismatch")
    exact_by_output = {str(record["output"]).lower(): record for record in verification.get("records", [])}
    for source in manifest.get("sources", []):
        exact = exact_by_output.get(str(source.get("file", "")).lower())
        if not exact or not exact.get("pass") or str(exact.get("output_sha256", "")).lower() != str(source.get("sha256", "")).lower():
            raise ValueError(f"missing exact-alpha record for {source.get('file')}")
    selected: list[dict[str, Any]] = []
    seen: set[tuple[str, str]] = set()
    for record in manifest.get("outputs", []):
        state = str(record.get("action", ""))
        direction = str(record.get("direction", ""))
        if state not in STATES or direction not in DIRECTIONS:
            continue
        key = (state, direction)
        if key in seen:
            raise ValueError(f"duplicate output {key}")
        seen.add(key)
        candidate = CANDIDATE_OUTPUTS / f"wu_song_mengzhou_{state}_{direction}.png"
        digest = sha256(candidate) if candidate.is_file() else ""
        if digest != str(record.get("output_sha256", "")).lower():
            raise ValueError(f"candidate output hash mismatch: {candidate}")
        selected.append({
            "state": state, "direction": direction, "candidate": candidate,
            "candidate_sha256": digest, "candidate_record": record,
            "png_contract": png_contract(candidate),
            "target": REPO / "assets" / "campaign" / "anim" / candidate.name,
        })
    expected_matrix = {(state, direction) for state in STATES for direction in DIRECTIONS}
    if len(selected) != 20 or seen != expected_matrix:
        raise ValueError(f"expected exact 20-output matrix, got {len(selected)}")
    return manifest, verification, selected


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--backup-dir", type=Path, required=True)
    parser.add_argument("--report", type=Path, default=REPO / "qa" / "wu_song_mengzhou_direction4_production_20260902" / "install_report.json")
    args = parser.parse_args()
    backup = args.backup_dir.resolve()
    if backup.exists():
        raise FileExistsError(f"backup already exists: {backup}")
    if WORKSPACE.resolve() not in backup.parents or REPO.resolve() in backup.parents:
        raise ValueError("backup must be outside repository and inside Water Margin workspace")
    if "steamworks" in str(backup).lower():
        raise ValueError("Steamworks paths are forbidden")

    manifest, verification, frames = load_verified()
    prompt_records = verify_prompts()
    steam_before = steam_snapshot()
    backup.mkdir(parents=True)
    portrait_target = REPO / "assets" / "campaign" / "portraits" / "wu_song_mengzhou.png"
    mutable_files = [
        REPO / "scripts" / "battle.gd",
        REPO / "scripts" / "levels" / "level7_kuaihuolin.gd",
        REPO / "docs" / "CAMPAIGN_IMPLEMENTATION.md",
        WORKSPACE / "WORKLOG.md",
    ]
    targets = [frame["target"] for frame in frames] + [portrait_target, PRODUCTION_MANIFEST, *mutable_files]
    backup_records: list[dict[str, Any]] = []
    for target in targets:
        relative = target.relative_to(WORKSPACE).as_posix()
        record = {"path": relative, "existed": target.is_file(), "sha256": sha256(target) if target.is_file() else None, "backup": None}
        if target.is_file():
            destination = backup / "files" / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, destination)
            if sha256(destination) != record["sha256"]:
                raise IOError(f"backup mismatch: {target}")
            record["backup"] = destination.relative_to(backup).as_posix()
        backup_records.append(record)
    backup_manifest = {
        "schema_version": 1,
        "kind": "wu_song_mengzhou_direction4_prewrite_backup",
        "created_at": datetime.now().astimezone().isoformat(),
        "complete_before_production_write": True,
        "candidate_manifest_sha256": CANDIDATE_MANIFEST_SHA256,
        "targets": backup_records,
        "steam_before": steam_before,
    }
    write_json_atomic(backup / "backup_manifest.json", backup_manifest)

    for frame in frames:
        copy_bytes_atomic(frame["candidate"], frame["target"])
        if sha256(frame["target"]) != frame["candidate_sha256"]:
            raise IOError(f"production differs from candidate: {frame['target']}")
    portrait_source = CANDIDATE_OUTPUTS / "wu_song_mengzhou_idle_se.png"
    copy_bytes_atomic(portrait_source, portrait_target)

    exact_by_output = {str(record["output"]).lower(): record for record in verification["records"]}
    source_records: list[dict[str, Any]] = []
    for source in manifest["sources"]:
        action = str(source["action"])
        exact = exact_by_output[str(source["file"]).lower()]
        source_records.append({
            "action": action,
            "raw_file": exact["source"], "raw_sha256": str(exact["source_sha256"]).lower(),
            "cleaned_file": source["file"], "cleaned_sha256": str(source["sha256"]).lower(),
            "mode": source["mode"], "size": source["size"],
            "source_generation_conversation": HURT_CONVERSATION if action == "hurt" else SOURCE_CONVERSATION,
            "prompt": prompt_records[action]["path"], "prompt_sha256": prompt_records[action]["sha256"],
            "exact_alpha_cleanup_conversation": ALPHA_CONVERSATION,
            "exact_alpha_prompt": ALPHA_PROMPT[0], "exact_alpha_prompt_sha256": ALPHA_PROMPT[1],
            "exact_alpha_rule": "alpha <= 15 becomes RGBA 0,0,0,0; every alpha > 15 pixel remains byte-identical",
        })
    output_records = []
    for frame in frames:
        record = frame["candidate_record"]
        output_records.append({
            "variant": "wu_song_mengzhou", "state": frame["state"], "direction": frame["direction"],
            "path": frame["target"].relative_to(REPO).as_posix(), "sha256": frame["candidate_sha256"],
            "copy_is_byte_identical_to_candidate": True,
            "source_file": record.get("source_file"), "source_sha256": record.get("source_sha256"),
            "source_cell_rect_xyxy": record.get("source_cell_rect_xyxy"), "source_rect_xyxy": record.get("source_rect_xyxy"),
            "source_anchor_xy": record.get("source_anchor_xy"), "batch_uniform_requested_scale": record.get("batch_uniform_requested_scale"),
            "actual_scale_xy_after_integer_rounding": record.get("actual_scale_xy_after_integer_rounding"),
            "resized_size": record.get("resized_size"), "paste_xy": record.get("paste_xy"), "target_anchor_xy": record.get("target_anchor_xy"),
        })
    production_payload = {
        "schema_version": 1,
        "kind": "wu_song_mengzhou_direction4_production_provenance",
        "created_at": datetime.now().astimezone().isoformat(),
        "variant": "wu_song_mengzhou", "states": list(STATES), "directions": list(DIRECTIONS), "frame_count": 20,
        "source_generation_conversations": [SOURCE_CONVERSATION, HURT_CONVERSATION],
        "exact_alpha_cleanup_conversation": ALPHA_CONVERSATION,
        "web_input_archive_sha256": INPUT_ARCHIVE_SHA256, "web_download_archive_sha256": DOWNLOAD_ARCHIVE_SHA256,
        "exact_alpha_verification": WEB_VERIFICATION.relative_to(REPO).as_posix(), "exact_alpha_verification_sha256": WEB_VERIFICATION_SHA256,
        "candidate_manifest": CANDIDATE_MANIFEST.relative_to(REPO).as_posix(), "candidate_manifest_sha256": CANDIDATE_MANIFEST_SHA256,
        "candidate_preview": PREVIEW.relative_to(REPO).as_posix(), "candidate_preview_sha256": PREVIEW_SHA256,
        "allowed_operations": ["continuous source rectangle crop", "batch-uniform proportional scale", "transparent padding", "byte-identical production copy"],
        "forbidden_operations_used": [], "original_evidence": ORIGINAL_EVIDENCE,
        "sources": source_records, "outputs": output_records,
        "portrait": {"path": portrait_target.relative_to(REPO).as_posix(), "sha256": sha256(portrait_target), "byte_identical_source": "assets/campaign/anim/wu_song_mengzhou_idle_se.png"},
        "runtime_route": {
            "ordinary_states": "idle/walk/attack/hurt/down resolve by variant, state, and exact direction",
            "signature_kick": "cast windup faces the nearest in-range foe and uses same-direction attack high-kick art",
            "death": "not supplied and never aliases to down",
            "free_modes": "variant-empty wu_song keeps generic art, portrait, and arena abilities",
        },
        "steam_modified_or_exported": False,
    }
    write_json_atomic(PRODUCTION_MANIFEST, production_payload)
    steam_after = steam_snapshot()
    report = {
        "schema_version": 1, "kind": "wu_song_mengzhou_direction4_production_install",
        "created_at": datetime.now().astimezone().isoformat(), "passed": True,
        "backup_directory": str(backup), "backup_manifest": str(backup / "backup_manifest.json"),
        "backup_manifest_sha256": sha256(backup / "backup_manifest.json"),
        "copied_animation_pngs": 20, "portrait_byte_copy": True,
        "candidate_to_production_hash_match": all(sha256(frame["target"]) == frame["candidate_sha256"] for frame in frames),
        "production_manifest": PRODUCTION_MANIFEST.relative_to(REPO).as_posix(), "production_manifest_sha256": sha256(PRODUCTION_MANIFEST),
        "pixels_edited_during_install": 0, "steam_before": steam_before, "steam_after": steam_after,
        "steam_unchanged": steam_before == steam_after,
        "next_gate": "Implement and test signature-kick facing; Godot runtime, Vulkan visual, performance, and documentation remain pending.",
    }
    write_json_atomic(args.report.resolve(), report)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
