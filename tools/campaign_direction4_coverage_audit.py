#!/usr/bin/env python3
"""Static, read-only audit for the eight campaign levels' four-direction art.

This deliberately does not use ArtDB's fallbacks: a directional idle, a legacy
single-view strip, a programmatic rope overlay, or a component-masked atlas is
reported for diagnosis but never counted as exact accepted coverage.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
from collections import Counter, defaultdict
from pathlib import Path, PurePosixPath
from typing import Any


DIRECTIONS = ("se", "sw", "ne", "nw")
COMBAT_STATES = ("idle", "walk", "attack", "hurt", "down")
ROOT = Path(__file__).resolve().parents[1]


def combat(key: str, variant: str = "", *, down_lookup: str = "death", extra: tuple[str, ...] = ()) -> dict[str, Any]:
    return {
        "key": key,
        "variant": variant,
        "role_class": "combat_person",
        "states": list(COMBAT_STATES + extra),
        "down_lookup": down_lookup,
    }


def narrative(key: str, variant: str, states: tuple[str, ...], lifecycle: str) -> dict[str, Any]:
    return {
        "key": key,
        "variant": variant,
        "role_class": "narrative_person",
        "states": list(states),
        "lifecycle": lifecycle,
    }


def vessel(key: str, art_variant: str, states: tuple[str, ...], lifecycle: str) -> dict[str, Any]:
    return {
        "key": key,
        "variant": art_variant,
        "role_class": "vessel_object",
        "states": list(states),
        "lifecycle": lifecycle,
    }


# Curated from the actual deployment and transition functions in the level
# scripts.  Repeated art identities remain repeated per level/key here; the
# web-generation plan is deduplicated later by (domain, identity, state).
LEVEL_SPECS: dict[str, dict[str, Any]] = {
    "level6": {
        "title": "大闹野猪林",
        "script": "scripts/levels/level6_yezhulin.gd",
        "profiles": [
            narrative("lin_chong", "lin_chong_prisoner", ("idle", "walk"), "prisoner_march"),
            narrative("lin_chong_bound", "lin_chong_bound", ("idle",), "bound_under_tree"),
            narrative("lin_chong", "lin_chong_escort", ("idle", "walk", "assisted"), "wounded_escort"),
            combat("lu_zhishen", "lu_zhishen_rescue", extra=("intercept",)),
            combat("dong_chao", "dong_chao_escort", down_lookup="down"),
            combat("xue_ba", "xue_ba_escort", down_lookup="down"),
        ],
        "excluded_non_person_props": [],
    },
    "level1": {
        "title": "智取生辰纲",
        "script": "scripts/levels/level1_huangnigang.gd",
        "profiles": [
            combat("chao_gai", "hn_chao_gai"), combat("wu_yong", "hn_wu_yong"),
            combat("gongsun_sheng", "hn_gongsun_sheng"), combat("liu_tang", "hn_liu_tang"),
            combat("ruan_xiaoer", "hn_ruan_xiaoer"), combat("ruan_xiaowu", "hn_ruan_xiaowu"),
            combat("ruan_xiaoqi", "hn_ruan_xiaoqi"),
            combat("bai_sheng", "hn_bai_sheng", extra=("carry_idle", "carry_walk")),
            combat("yang_zhi", down_lookup="down"), combat("yu_hou", down_lookup="down"),
            combat("jun_han", down_lookup="down"),
            narrative("lao_duguan", "", ("idle", "walk", "down"), "noncombat_convoy_and_unconscious"),
        ],
        "excluded_non_person_props": ["treasure_cart", "tribute_load", "jujube_cart", "wine_buckets", "wine_bowls"],
    },
    "level7": {
        "title": "醉打蒋门神",
        "script": "scripts/levels/level7_kuaihuolin.gd",
        "profiles": [
            combat("wu_song", "wu_song_mengzhou"),
            combat("jiang_menshen", "jiang_menshen_fists", down_lookup="down"),
            narrative("shi_en", "", ("idle", "walk"), "guide_and_shop_handover"),
        ],
        "excluded_non_person_props": ["tavern", "roadside_tavern", "signboard", "heyang_tavern"],
    },
    "level2": {
        "title": "江州劫法场",
        "script": "scripts/levels/level2_jiangzhou.gd",
        "profiles": [
            narrative("song_jiang_bound", "song_jiang_bound", ("idle",), "bound_on_scaffold"),
            narrative("dai_zong_bound", "dai_zong_bound", ("idle",), "bound_on_scaffold"),
            narrative("song_jiang", "song_jiang_rescued", ("idle", "walk"), "rescued_to_embark"),
            narrative("dai_zong", "dai_zong_rescued", ("idle", "walk"), "rescued_to_embark"),
            combat("chao_gai"), combat("li_kui", "li_kui_jiangzhou"), combat("hua_rong"), combat("yan_shun"),
            combat("liang_dao"), combat("liang_gong"), combat("guan_zhanzi"),
            combat("guan_laozi"), combat("cai_jiu"), combat("guan_dao"), combat("guan_gong"),
            combat("zhang_shun"), combat("zhang_heng"),
        ],
        "excluded_non_person_props": ["scaffold", "jiangzhou_scaffold", "tavern", "bailong_temple"],
    },
    "level3": {
        "title": "三打祝家庄",
        "script": "scripts/levels/level3_zhujiazhuang.gd",
        "profiles": [
            combat("shi_xiu"), combat("song_jiang"), combat("liang_dao"), combat("zhu_keke"),
            combat("lin_chong"), combat("hua_rong"), combat("liang_qiang"),
            combat("hu_sanniang", down_lookup="down"), combat("liang_gong"), combat("mu_hong"),
            combat("sun_li"), combat("gu_dasao"), combat("shi_qian"), combat("qin_ming"),
            combat("yang_lin"), combat("huang_xin"), combat("wang_ying"), combat("deng_fei"),
            combat("zhu_long"), combat("zhu_hu"), combat("zhu_biao"), combat("luan_tingyu"),
            narrative("shi_xiu", "bound_shi_xiu", ("idle",), "third_day_bound"),
            narrative("shi_qian", "bound_shi_qian", ("idle",), "third_day_bound"),
            narrative("qin_ming", "bound_qin_ming", ("idle",), "third_day_bound"),
            narrative("yang_lin", "bound_yang_lin", ("idle",), "third_day_bound"),
            narrative("huang_xin", "bound_huang_xin", ("idle",), "third_day_bound"),
            narrative("wang_ying", "bound_wang_ying", ("idle",), "third_day_bound"),
            narrative("deng_fei", "bound_deng_fei", ("idle",), "third_day_bound"),
        ],
        "excluded_non_person_props": ["zhu_gate"],
    },
    "level4": {
        "title": "大破连环马",
        "script": "scripts/levels/level4_lianhuanma.gd",
        "profiles": [
            combat("xu_ning"), combat("tang_long"), combat("gou_lian"), combat("song_jiang"),
            combat("wu_yong"), combat("lin_chong"), combat("hua_rong"),
            combat("han_tao", down_lookup="down"), combat("hu_yanzhuo", down_lookup="down"),
            combat("lian_huan_ma"),
        ],
        "excluded_non_person_props": ["hook_training_dummy", "jiangtai", "hook_spear_team", "broken_cavalry", "linked_cavalry"],
    },
    "level8": {
        "title": "智取大名府",
        "script": "scripts/levels/level8_dongchangfu.gd",
        "profiles": [
            narrative("shi_qian", "shi_qian_lantern", ("idle", "walk"), "infiltration_and_fire_signal"),
            narrative("chai_jin", "chai_jin_officer", ("idle", "walk"), "officer_disguise"),
            narrative("yue_he", "yue_he_officer", ("idle", "walk"), "officer_disguise"),
            narrative("lu_junyi", "daming_bound_lu_junyi", ("idle",), "bound_prisoner"),
            narrative("shi_xiu", "daming_bound_shi_xiu", ("idle",), "bound_prisoner"),
            narrative("lu_junyi", "daming_rescued_lu_junyi", ("idle", "walk"), "rescued_extraction"),
            narrative("shi_xiu", "daming_rescued_shi_xiu", ("idle", "walk"), "rescued_extraction"),
            narrative("lou_luo", "", ("idle", "walk"), "lantern_festival_civilians"),
            combat("wu_yong"), combat("lu_zhishen"), combat("wu_song"), combat("liang_qiang"),
            combat("liang_gong"), combat("guan_dao"), combat("guan_gong"),
        ],
        "excluded_non_person_props": ["zhu_gate", "daming_south_gate", "cuiyun_tower", "prison_gate"],
    },
    "level5": {
        "title": "三败高太尉",
        "script": "scripts/levels/level5_liangshan.gd",
        "profiles": [
            combat("song_jiang"), combat("wu_yong"), combat("liang_gong"), combat("guan_qi"),
            combat("guan_dao"), combat("liang_qiang"), combat("lin_chong"), combat("hua_rong"),
            narrative("gongsun_sheng", "", ("idle", "walk"), "wind_ritual_leader"),
            narrative("liu_tang", "", ("idle", "walk"), "fireboat_leader"),
            narrative("zhang_shun", "", ("idle", "walk"), "prisoner_handover"),
            narrative("gao_qiu", "gao_qiu_captured", ("idle", "down"), "captured_prisoner"),
            vessel("ruan_xiaoqi_boat", "liangshan_boat", ("default",), "lure_boat"),
            vessel("liu_tang_fireboat", "liangshan_boat", ("default",), "fireboat_hidden_after_retreat"),
            vessel("ruan_xiaoer_boat", "liangshan_boat", ("default",), "water_combat"),
            vessel("ruan_xiaowu_boat", "liangshan_boat", ("default",), "water_combat"),
            vessel("zhang_shun_boat", "liangshan_boat", ("default",), "scuttle_and_prisoner_transfer"),
            vessel("liangshan_warship", "liangshan_boat", ("default",), "water_combat"),
            vessel("imperial_warship", "official_warship", ("default", "disabled"), "combat_and_fire_disabled"),
            vessel("official_vanguard", "official_vanguard", ("default", "damaged", "disabled"), "third_battle_vanguard"),
            vessel("gao_flagship", "gao_flagship", ("default", "damaged", "flooding", "disabled"), "scuttle_sequence"),
        ],
        "excluded_non_person_props": ["hall"],
    },
}

STORY_ORDER = ("level6", "level1", "level7", "level2", "level3", "level4", "level8", "level5")

FIRST_SAMPLE = (
    ("person", "lin_chong"), ("person", "lu_zhishen"),
    ("person", "wu_song"), ("person", "li_kui"),
    ("person", "liang_dao"), ("person", "guan_dao"),
    ("person", "gou_lian"), ("person", "lian_huan_ma"),
)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def png_dimensions(path: Path) -> tuple[int, int] | None:
    try:
        with path.open("rb") as handle:
            if handle.read(8) != b"\x89PNG\r\n\x1a\n":
                return None
            length = struct.unpack(">I", handle.read(4))[0]
            if handle.read(4) != b"IHDR" or length < 8:
                return None
            return struct.unpack(">II", handle.read(8))
    except OSError:
        return None


def _manifest_output_path(base: str, value: str) -> str:
    value = value.replace("\\", "/")
    return value if value.startswith("assets/") else f"{base.rstrip('/')}/{value.lstrip('/')}"


SKIRMISH_ACTION_MANIFEST_REL = "assets/direction4/skirmish_top4_actions_direction4_manifest.json"
SKIRMISH_ACTION_UNITS = ("guan_dao", "guan_gong", "guan_jingqi", "guan_qi")
SKIRMISH_ACTION_POSES = ("walk_step", "attack_strike", "death_fall", "death_down")
SKIRMISH_ACTION_ANCHOR_KIND = {
    "walk_step": "foot_or_hoof",
    "attack_strike": "foot_or_hoof",
    "death_fall": "foot_or_hoof",
    "death_down": "lowest_contact",
}
SKIRMISH_ACTION_RECIPES = {
    "walk": ("idle", "walk_step"),
    "attack": ("idle", "attack_strike", "idle"),
    "death": ("idle", "death_fall", "death_down", "death_down"),
}
SKIRMISH_ARCHER_SW_REVISION_REL = "assets/direction4/skirmish_archer_sw_revision_20260905.json"
SKIRMISH_ARCHER_SW_SOURCE_REL = "qa/skirmish_direction4_fix_20260905/source/archer_sw_idle_step_raw.png"
SKIRMISH_ARCHER_SW_PROMPT_REL = "qa/skirmish_direction4_fix_20260905/source/01_archer_sw_prompt.txt"
SKIRMISH_ARCHER_SW_BACKUP_REL = "qa/skirmish_direction4_fix_20260905/archer_before"
SKIRMISH_ARCHER_SW_TARGETS = tuple(
    f"guan_gong_{state}_sw.png" for state in ("idle", "walk", "attack", "death")
)
SKIRMISH_ARCHER_SW_ACTION_TARGETS = frozenset(SKIRMISH_ARCHER_SW_TARGETS[1:])
SKIRMISH_ARCHER_SW_PROCESSING = (
    "two equal source halves; complete alpha bounding crop; shared scale; virtual ground pivot; "
    "unmasked RGBA placement; exact strip assembly; no reflection, alpha clearing, repaint or color correction"
)
SKIRMISH_ARCHER_SW_VISUAL_REVIEW = (
    "Assistant reviewed left-facing nose/chest/boots in both poses; not user visual approval"
)
SKIRMISH_ARCHER_SW_RETAINED = (
    "attack strike and death fall/down remain byte-identical RGBA to original strips"
)
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _is_sha256(value: Any) -> bool:
    return isinstance(value, str) and SHA256_RE.fullmatch(value) is not None


def _canonical_json_sha256(value: Any) -> str:
    payload = (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def _json_object(path: Path) -> dict[str, Any] | None:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError, UnicodeError):
        return None
    return value if isinstance(value, dict) else None


def _relative_parts(value: Any) -> tuple[str, ...] | None:
    """Accept canonical project/stage-relative POSIX paths only."""
    if not isinstance(value, str) or not value or "\\" in value or re.match(r"^[A-Za-z]:", value):
        return None
    pure = PurePosixPath(value)
    if pure.is_absolute() or any(part in ("", ".", "..") for part in pure.parts):
        return None
    return pure.parts


def _safe_relative_path(root: Path, value: Any, *, base: Path | None = None) -> Path | None:
    parts = _relative_parts(value)
    if parts is None:
        return None
    root_resolved = root.resolve()
    base_resolved = (base or root).resolve()
    try:
        base_resolved.relative_to(root_resolved)
        candidate = base_resolved.joinpath(*parts).resolve()
        candidate.relative_to(base_resolved)
        candidate.relative_to(root_resolved)
    except (OSError, ValueError):
        return None
    return candidate


def _verified_relative_file(
    root: Path,
    value: Any,
    expected_sha256: Any,
    *,
    base: Path | None = None,
) -> Path | None:
    if not _is_sha256(expected_sha256):
        return None
    path = _safe_relative_path(root, value, base=base)
    if path is None or not path.is_file() or path.is_symlink():
        return None
    try:
        return path if sha256(path) == expected_sha256 else None
    except OSError:
        return None


def _verified_override_file(root: Path, path: Any, expected_sha256: Any) -> Path | None:
    """Verify a fixed local historical copy without accepting a redirected path."""
    if not isinstance(path, Path) or not _is_sha256(expected_sha256):
        return None
    try:
        path.resolve().relative_to(root.resolve())
    except (OSError, ValueError):
        return None
    if not path.is_file() or path.is_symlink():
        return None
    try:
        return path if sha256(path) == expected_sha256 else None
    except OSError:
        return None


def _config_path(root: Path, value: Any) -> Path | None:
    """Resolve a config path while still requiring it to remain in the project."""
    if not isinstance(value, str) or not value:
        return None
    raw = Path(value)
    try:
        candidate = raw.resolve() if raw.is_absolute() else (root / raw).resolve()
        candidate.relative_to(root.resolve())
    except (OSError, ValueError):
        return None
    return candidate


def _native_rgba_png_dimensions(path: Path) -> tuple[int, int] | None:
    """Read only the PNG contract fields needed by this static audit."""
    try:
        header = path.read_bytes()[:33]
    except OSError:
        return None
    if (
        len(header) < 33
        or header[:8] != b"\x89PNG\r\n\x1a\n"
        or struct.unpack(">I", header[8:12])[0] != 13
        or header[12:16] != b"IHDR"
        or header[24] != 8
        or header[25] != 6
        or header[26:29] != b"\x00\x00\x00"
    ):
        return None
    width, height = struct.unpack(">II", header[16:24])
    return (width, height) if width > 0 and height > 0 else None


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _rect(value: Any) -> tuple[int, int, int, int] | None:
    if isinstance(value, dict) and set(value) == {"x0", "y0", "x1", "y1"}:
        value = [value["x0"], value["y0"], value["x1"], value["y1"]]
    if not isinstance(value, list) or len(value) != 4 or any(not _nonnegative_int(part) for part in value):
        return None
    x0, y0, x1, y1 = value
    return (x0, y0, x1, y1) if x0 < x1 and y0 < y1 else None


def _int_pair(value: Any) -> tuple[int, int] | None:
    if not isinstance(value, list) or len(value) != 2 or any(not isinstance(part, int) or isinstance(part, bool) for part in value):
        return None
    return value[0], value[1]


def _rectangles_overlap(first: tuple[int, int, int, int], second: tuple[int, int, int, int]) -> bool:
    return max(first[0], second[0]) < min(first[2], second[2]) and max(first[1], second[1]) < min(first[3], second[3])


def _exact_keyed_records(
    value: Any,
    expected: set[tuple[str, ...]],
    fields: tuple[str, ...],
) -> dict[tuple[str, ...], dict[str, Any]] | None:
    if not isinstance(value, list) or len(value) != len(expected):
        return None
    result: dict[tuple[str, ...], dict[str, Any]] = {}
    for row in value:
        if not isinstance(row, dict):
            return None
        key = tuple(str(row.get(field, "")) for field in fields)
        if key not in expected or key in result:
            return None
        result[key] = row
    return result if set(result) == expected else None


def _valid_skirmish_action_chain(
    root: Path,
    manifest_path: Path,
    production: dict[str, Any],
    *,
    production_file_overrides: dict[str, Path] | None = None,
) -> bool:
    """Verify the complete reviewed-source-to-production chain for all 48 strips.

    This intentionally has no partial-success mode.  A batch with one missing or
    drifting source, prompt, anchor, approval, staged strip, or production strip
    is provenance-incomplete as a whole.
    """
    overrides = production_file_overrides or {}
    if set(overrides) - set(SKIRMISH_ARCHER_SW_TARGETS):
        return False
    units = SKIRMISH_ACTION_UNITS
    directions = DIRECTIONS
    poses = SKIRMISH_ACTION_POSES
    recipes = SKIRMISH_ACTION_RECIPES
    expected_outputs = {(unit, state, direction) for unit in units for direction in directions for state in recipes}
    expected_anchors = {(pose, unit, direction) for pose in poses for unit in units for direction in directions}
    expected_idles = {(unit, direction) for unit in units for direction in directions}

    if (
        production.get("schema_version") != 2
        or production.get("kind") != "skirmish_direction4_action_production_manifest"
        or not isinstance(production.get("batch_id"), str)
        or not production["batch_id"].strip()
        or not isinstance(production.get("committed_at"), str)
        or not production["committed_at"].strip()
        or not isinstance(production.get("transaction_id"), str)
        or not production["transaction_id"].strip()
        or production.get("steam_modified_or_exported") is not False
    ):
        return False
    batch_id = production["batch_id"]

    production_outputs = _exact_keyed_records(production.get("outputs"), expected_outputs, ("unit", "state", "direction"))
    if production_outputs is None:
        return False
    for (unit, state, direction), row in production_outputs.items():
        target = f"{unit}_{state}_{direction}.png"
        if row.get("target") != target or row.get("recipe") != list(recipes[state]) or not _is_sha256(row.get("sha256")):
            return False

    candidate_ref = production.get("candidate_manifest")
    if not isinstance(candidate_ref, dict):
        return False
    candidate_path = _verified_relative_file(root, candidate_ref.get("file"), candidate_ref.get("sha256"))
    candidate = _json_object(candidate_path) if candidate_path is not None else None
    if candidate is None:
        return False
    candidate_file_sha = candidate_ref["sha256"]
    self_hash = candidate.get("stage_manifest_sha256")
    candidate_without_self = {key: value for key, value in candidate.items() if key != "stage_manifest_sha256"}
    if (
        candidate.get("schema_version") != 2
        or candidate.get("kind") != "skirmish_direction4_action_candidate_manifest"
        or candidate.get("batch_id") != batch_id
        or candidate.get("scope") != "production"
        or candidate.get("steam_modified_or_exported") is not False
        or candidate.get("production_written") is not False
        or not isinstance(candidate.get("staged_at"), str)
        or not candidate["staged_at"].strip()
        or not _is_sha256(self_hash)
        or _canonical_json_sha256(candidate_without_self) != self_hash
    ):
        return False
    stage_root = candidate_path.parent

    config_ref = candidate.get("config")
    if not isinstance(config_ref, dict):
        return False
    config_path = _verified_relative_file(root, config_ref.get("file"), config_ref.get("sha256"))
    config = _json_object(config_path) if config_path is not None else None
    if (
        config is None
        or config.get("schema_version") != 2
        or config.get("kind") != "skirmish_direction4_action_batch"
        or config.get("batch_id") != batch_id
        or config.get("scope") != "production"
        or config.get("units") != list(units)
        or config.get("directions") != list(directions)
    ):
        return False
    config_paths = config.get("paths")
    if not isinstance(config_paths, dict):
        return False

    approval_ref = production.get("approval_receipt")
    if not isinstance(approval_ref, dict):
        return False
    approval_path = _verified_relative_file(root, approval_ref.get("file"), approval_ref.get("sha256"))
    approval = _json_object(approval_path) if approval_path is not None else None
    if (
        approval is None
        or approval.get("schema_version") != 1
        or approval.get("kind") != "skirmish_direction4_action_commit_approval"
        or approval.get("batch_id") != batch_id
        or approval.get("approved") is not True
        or approval.get("stage_manifest_sha256") != candidate_file_sha
        or not isinstance(approval.get("approved_by"), str)
        or not approval["approved_by"].strip()
        or not isinstance(approval.get("approved_at"), str)
        or not approval["approved_at"].strip()
        or not isinstance(approval.get("visual_review_note"), str)
        or not approval["visual_review_note"].strip()
        or approval_ref.get("approved_by") != approval.get("approved_by")
        or approval_ref.get("approved_at") != approval.get("approved_at")
    ):
        return False

    if (
        _config_path(root, config_paths.get("staging_dir")) != stage_root.resolve()
        or _config_path(root, config_paths.get("production_root")) != (root / "assets/anim").resolve()
        or _config_path(root, config_paths.get("commit_manifest")) != manifest_path.resolve()
        or _config_path(root, config_paths.get("approval_receipt")) != approval_path.resolve()
        or config.get("source_approval", {}).get("browser_cleaned_sources_confirmed") is not True
    ):
        return False

    anchors_ref = candidate.get("semantic_anchors")
    if not isinstance(anchors_ref, dict):
        return False
    anchors_path = _verified_relative_file(root, anchors_ref.get("file"), anchors_ref.get("sha256"))
    anchors_document = _json_object(anchors_path) if anchors_path is not None else None
    if (
        anchors_document is None
        or anchors_document.get("schema_version") not in (1, 2)
        or anchors_document.get("kind") != "skirmish_direction4_semantic_anchors"
        or anchors_ref.get("schema_version") != anchors_document.get("schema_version")
        or anchors_ref.get("count") != 64
        or anchors_ref.get("fallback_used") is not False
        or _config_path(root, config.get("anchors_file")) != anchors_path.resolve()
        or config.get("anchors_sha256") != anchors_ref.get("sha256")
        or production.get("semantic_anchors") != anchors_ref
    ):
        return False
    anchor_rows = _exact_keyed_records(anchors_document.get("entries"), expected_anchors, ("pose", "unit", "direction"))
    if anchor_rows is None:
        return False

    canvas = candidate.get("canvas")
    layout = candidate.get("source_layout")
    canvas_keys = (
        "size_px", "max_content_width_px", "max_content_height_px",
        "anchor_target_x_px", "anchor_target_y_px", "margin_px",
        "max_walk_attack_fit_shift_px",
    )
    layout_keys = (
        "minimum_source_size_px", "rect_edge_transparent_clearance_px",
        "anchor_evidence_radius_px", "subject_group_join_gap_px",
        "minimum_subject_alpha_pixels",
    )
    if (
        not isinstance(canvas, dict)
        or canvas.get("size_px") != 256
        or any(not _positive_int(canvas.get(key)) for key in canvas_keys)
        or canvas.get("margin_px") != 4
        or canvas.get("anchor_target_x_px") != 128
        or canvas.get("anchor_target_y_px") != 210
        or canvas.get("max_walk_attack_fit_shift_px") != 20
        or canvas.get("max_content_width_px") != canvas["size_px"] - 2 * canvas["margin_px"]
        or canvas.get("max_content_height_px") != canvas["size_px"] - 2 * canvas["margin_px"]
        or canvas.get("max_walk_attack_fit_shift_px") > canvas["max_content_width_px"]
        or not isinstance(config.get("canvas"), dict)
        or any(config["canvas"].get(key) != canvas.get(key) for key in canvas_keys)
        or not isinstance(layout, dict)
        or layout.get("mode") != "manual_source_rects_v2"
        or any(not _nonnegative_int(layout.get(key)) for key in layout_keys)
        or layout.get("rect_edge_transparent_clearance_px", 0) < 1
        or layout.get("minimum_subject_alpha_pixels", 0) < 1
        or not isinstance(config.get("source_layout"), dict)
        or config["source_layout"].get("mode") != layout.get("mode")
        or any(config["source_layout"].get(key) != layout.get(key) for key in layout_keys)
    ):
        return False

    candidate_sources = _exact_keyed_records(candidate.get("sources"), {(pose,) for pose in poses}, ("pose",))
    config_sources = _exact_keyed_records(config.get("sources"), {(pose,) for pose in poses}, ("pose",))
    if candidate_sources is None or config_sources is None or production.get("source_chain") != candidate.get("sources"):
        return False
    source_dimensions: dict[str, tuple[int, int]] = {}
    cleanup_verification_documents: dict[Path, dict[str, Any]] = {}
    for pose in poses:
        source = candidate_sources[(pose,)]
        configured = config_sources[(pose,)]
        source_path = _verified_relative_file(root, source.get("file"), source.get("sha256"))
        raw_generated_path = _verified_relative_file(root, source.get("raw_generated_file"), source.get("raw_generated_sha256"))
        source_size = _native_rgba_png_dimensions(source_path) if source_path is not None else None
        raw_generated_size = _native_rgba_png_dimensions(raw_generated_path) if raw_generated_path is not None else None
        prompt = source.get("prompt")
        cleanup = source.get("browser_cleanup")
        configured_cleanup = configured.get("browser_cleanup")
        if not isinstance(prompt, dict) or not isinstance(cleanup, dict) or not isinstance(configured_cleanup, dict):
            return False
        prompt_path = _verified_relative_file(root, prompt.get("file"), prompt.get("sha256"))
        cleanup_input_path = _verified_relative_file(root, cleanup.get("input_file"), cleanup.get("input_sha256"))
        cleanup_input_size = _native_rgba_png_dimensions(cleanup_input_path) if cleanup_input_path is not None else None
        cleanup_prompt_path = _verified_relative_file(root, cleanup.get("prompt_file"), cleanup.get("prompt_sha256"))
        cleanup_verification_path = _verified_relative_file(root, cleanup.get("verification_file"), cleanup.get("verification_sha256"))
        configured_source_path = _config_path(root, configured.get("file"))
        configured_raw_path = _config_path(root, configured.get("raw_generated_file"))
        configured_prompt_path = _config_path(root, configured.get("prompt_file"))
        configured_cleanup_input_path = _config_path(root, configured_cleanup.get("input_file"))
        configured_cleanup_prompt_path = _config_path(root, configured_cleanup.get("prompt_file"))
        configured_cleanup_verification_path = _config_path(root, configured_cleanup.get("verification_file"))
        reviewed_source_root = (root / "qa/skirmish_direction4_actions_20260905/source").resolve()
        canonical_input_root = (reviewed_source_root / "web_upload_canonical").resolve()
        expected_verification_path = (reviewed_source_root / "alpha_cleanup_verification.json").resolve()
        try:
            raw_generated_path.relative_to(reviewed_source_root) if raw_generated_path is not None else None
            cleanup_input_path.relative_to(canonical_input_root) if cleanup_input_path is not None else None
        except ValueError:
            return False
        if (
            source_path is None
            or raw_generated_path is None
            or cleanup_input_path is None
            or source_size is None
            or raw_generated_size != source_size
            or cleanup_input_size != source_size
            or prompt_path is None
            or cleanup_prompt_path is None
            or cleanup_verification_path is None
            or cleanup_verification_path.resolve() != expected_verification_path
            or len({source_path.resolve(), raw_generated_path.resolve(), cleanup_input_path.resolve()}) != 3
            or source.get("raw_generated_sha256") == cleanup.get("input_sha256")
            or source.get("width") != source_size[0]
            or source.get("height") != source_size[1]
            or source_size[0] != source_size[1]
            or source_size[0] < layout["minimum_source_size_px"]
            or source.get("png_contract") != "single-frame native 8-bit PNG color type 6 RGBA"
            or source.get("rows") != list(units)
            or source.get("columns") != list(directions)
            or not isinstance(source.get("layout"), str)
            or "manual_source_rect" not in source["layout"]
            or not isinstance(source.get("visible_pixel_ownership"), str)
            or "Every source alpha>0 pixel" not in source["visible_pixel_ownership"]
            or not isinstance(source.get("conversation"), str)
            or not source["conversation"].startswith("https://chatgpt.com/c/")
            or "?" in source["conversation"]
            or cleanup.get("method") != "browser_python_pillow_alpha_le_15_rgba_zero"
            or cleanup.get("confirmed") is not True
            or cleanup.get("input_role") != "web_upload_canonical"
            or cleanup.get("browser_upload_reencoded") is not True
            or cleanup.get("exactness_basis") != "web_upload_canonical"
            or cleanup.get("output_sha256") != source.get("sha256")
            or not _nonnegative_int(cleanup.get("cleared_pixel_count"))
            or configured_source_path != source_path.resolve()
            or configured.get("sha256") != source.get("sha256")
            or configured_raw_path != raw_generated_path.resolve()
            or configured.get("raw_generated_sha256") != source.get("raw_generated_sha256")
            or configured_prompt_path != prompt_path.resolve()
            or configured.get("prompt_sha256") != prompt.get("sha256")
            or configured.get("conversation") != source.get("conversation")
            or configured.get("rows") != source.get("rows")
            or configured.get("columns") != source.get("columns")
            or configured_cleanup.get("method") != cleanup.get("method")
            or configured_cleanup.get("confirmed") is not True
            or configured_cleanup.get("input_role") != cleanup.get("input_role")
            or configured_cleanup.get("browser_upload_reencoded") is not True
            or configured_cleanup.get("exactness_basis") != cleanup.get("exactness_basis")
            or configured_cleanup_input_path != cleanup_input_path.resolve()
            or configured_cleanup.get("input_sha256") != cleanup.get("input_sha256")
            or configured_cleanup.get("output_sha256") != cleanup.get("output_sha256")
            or configured_cleanup.get("cleared_pixel_count") != cleanup.get("cleared_pixel_count")
            or configured_cleanup_prompt_path != cleanup_prompt_path.resolve()
            or configured_cleanup.get("prompt_sha256") != cleanup.get("prompt_sha256")
            or configured_cleanup_verification_path != cleanup_verification_path.resolve()
            or configured_cleanup.get("verification_sha256") != cleanup.get("verification_sha256")
        ):
            return False

        verification = cleanup_verification_documents.get(cleanup_verification_path)
        if verification is None:
            verification = _json_object(cleanup_verification_path)
            if verification is None:
                return False
            cleanup_verification_documents[cleanup_verification_path] = verification
        provenance_note = verification.get("provenance_note")
        verification_results = _exact_keyed_records(verification.get("results"), {(item,) for item in poses}, ("pose",))
        if (
            verification.get("schema_version") != 1
            or verification.get("kind") != "browser_alpha_cleanup_verification"
            or verification.get("passed") is not True
            or verification.get("method") != cleanup.get("method")
            or verification.get("conversation") != source.get("conversation")
            or not isinstance(provenance_note, str)
            or "re-encoded" not in provenance_note
            or "web_upload_canonical" not in provenance_note
            or verification_results is None
        ):
            return False
        verified = verification_results[(pose,)]
        verified_raw = _verified_relative_file(
            root,
            verified.get("raw_generated_file"),
            verified.get("raw_generated_sha256"),
            base=cleanup_verification_path.parent,
        )
        verified_input = _verified_relative_file(
            root,
            verified.get("input_file"),
            verified.get("input_sha256"),
            base=cleanup_verification_path.parent,
        )
        verified_output = _verified_relative_file(
            root,
            verified.get("output_file"),
            verified.get("output_sha256"),
            base=cleanup_verification_path.parent,
        )
        if (
            verified_raw != raw_generated_path
            or verified_input != cleanup_input_path
            or verified_output != source_path
            or verified.get("changed_pixels") != cleanup.get("cleared_pixel_count")
            or verified.get("alpha_gt_15_mismatch_pixels") != 0
            or verified.get("alpha_le_15_output_nonzero_pixels") != 0
        ):
            return False
        source_dimensions[pose] = source_size

    rectangles_by_pose: dict[str, list[tuple[int, int, int, int]]] = {pose: [] for pose in poses}
    anchor_map: dict[tuple[str, str, str], dict[str, Any]] = {}
    for key, row in anchor_rows.items():
        pose, _unit, _direction = key
        manual = _rect(row.get("manual_source_rect"))
        width, height = source_dimensions[pose]
        x = row.get("source_x_px")
        y = row.get("source_y_px")
        if (
            row.get("measurement_kind") != SKIRMISH_ACTION_ANCHOR_KIND[pose]
            or manual is None
            or not _nonnegative_int(x)
            or not _nonnegative_int(y)
            or not isinstance(row.get("review_note"), str)
            or not row["review_note"].strip()
            or manual[2] > width
            or manual[3] > height
            or not (manual[0] <= x < manual[2] and manual[1] <= y < manual[3])
            or any(_rectangles_overlap(manual, prior) for prior in rectangles_by_pose[pose])
        ):
            return False
        rectangles_by_pose[pose].append(manual)
        anchor_map[key] = row

    config_idles = _exact_keyed_records(config.get("idle_inputs"), expected_idles, ("unit", "direction"))
    candidate_idles = _exact_keyed_records(candidate.get("idle_inputs"), expected_idles, ("unit", "direction"))
    if config_idles is None or candidate_idles is None:
        return False
    idle_map: dict[tuple[str, str], dict[str, Any]] = {}
    for key, row in candidate_idles.items():
        configured = config_idles[key]
        unit, direction = key
        target = f"{unit}_idle_{direction}.png"
        declared_path = _safe_relative_path(root, row.get("file"))
        override_path = overrides.get(target)
        path = (
            _verified_override_file(root, override_path, row.get("sha256"))
            if override_path is not None
            else _verified_relative_file(root, row.get("file"), row.get("sha256"))
        )
        configured_path = _config_path(root, configured.get("file"))
        if (
            path is None
            or _native_rgba_png_dimensions(path) != (256, 256)
            or not _is_sha256(row.get("pixel_sha256"))
            or (
                override_path is None
                and configured_path != path.resolve()
            )
            or (
                override_path is not None
                and (
                    declared_path != (root / "assets" / "anim" / target).resolve()
                    or configured_path != declared_path
                )
            )
            or configured.get("sha256") != row.get("sha256")
        ):
            return False
        idle_map[key] = row

    normalized = _exact_keyed_records(candidate.get("normalized_poses"), expected_anchors, ("pose", "unit", "direction"))
    if normalized is None:
        return False
    pose_map: dict[tuple[str, str, str], dict[str, Any]] = {}
    unit_scales: dict[str, float] = {}
    unit_scale_metadata: dict[str, tuple[float, float, float]] = {}
    for key, row in normalized.items():
        pose, unit, _direction = key
        anchor = anchor_map[key]
        staged_expected = f"poses/{pose}/{unit}_{pose}_{key[2]}.png"
        path = _verified_relative_file(root, row.get("staged_file"), row.get("sha256"), base=stage_root)
        manual = _rect(row.get("manual_source_rect"))
        source_rect = _rect(row.get("source_rect"))
        semantic = row.get("semantic_anchor")
        scale = row.get("uniform_scale_for_unit_all_actions")
        reference_scale = row.get("reference_scale")
        fit_limit = row.get("all_pose_canvas_fit_scale_limit")
        fit_limited_scale = row.get("fit_limited_scale")
        resized_size = _int_pair(row.get("resized_size"))
        desired_paste = _int_pair(row.get("desired_paste_xy"))
        paste = _int_pair(row.get("paste_xy"))
        fit_shift = _int_pair(row.get("fit_shift_xy_px"))
        placed_anchor = _int_pair(row.get("placed_anchor_xy_px"))
        semantic_fit_shift = _int_pair(semantic.get("fit_shift_xy_px")) if isinstance(semantic, dict) else None
        semantic_placed = _int_pair(semantic.get("placed_xy_px")) if isinstance(semantic, dict) else None
        target_xy = (canvas["anchor_target_x_px"], canvas["anchor_target_y_px"])
        scale_values = (reference_scale, fit_limit, fit_limited_scale, scale)
        if (
            path is None
            or row.get("staged_file") != staged_expected
            or _native_rgba_png_dimensions(path) != (256, 256)
            or not _is_sha256(row.get("pixel_sha256"))
            or not _is_sha256(row.get("source_crop_pixel_sha256"))
            or manual != _rect(anchor.get("manual_source_rect"))
            or source_rect is None
            or not (manual[0] <= source_rect[0] < source_rect[2] <= manual[2])
            or not (manual[1] <= source_rect[1] < source_rect[3] <= manual[3])
            or not _positive_int(row.get("owned_alpha_pixels"))
            or row.get("subject_group_count") != 1
            or not isinstance(scale, (int, float))
            or isinstance(scale, bool)
            or scale <= 0
            or any(not isinstance(value, (int, float)) or isinstance(value, bool) or value <= 0 for value in scale_values)
            or fit_limited_scale != min(reference_scale, fit_limit)
            or scale != fit_limited_scale
            or row.get("reference_scale_basis") != "median of four same-direction existing-idle alpha-bbox heights divided by walk_step source alpha-bbox heights"
            or row.get("resize_filter") != "Pillow.Image.Resampling.LANCZOS"
            or resized_size is None
            or resized_size[0] <= 0
            or resized_size[1] <= 0
            or resized_size[0] > canvas["max_content_width_px"]
            or resized_size[1] > canvas["max_content_height_px"]
            or desired_paste is None
            or paste is None
            or fit_shift is None
            or placed_anchor is None
            or fit_shift != (paste[0] - desired_paste[0], paste[1] - desired_paste[1])
            or not (canvas["margin_px"] <= paste[0] <= canvas["size_px"] - canvas["margin_px"] - resized_size[0])
            or not (canvas["margin_px"] <= paste[1] <= canvas["size_px"] - canvas["margin_px"] - resized_size[1])
            or placed_anchor != (target_xy[0] + fit_shift[0], target_xy[1] + fit_shift[1])
            or (pose in ("walk_step", "attack_strike") and max(abs(fit_shift[0]), abs(fit_shift[1])) > canvas["max_walk_attack_fit_shift_px"])
            or not isinstance(semantic, dict)
            or semantic.get("measurement_kind") != anchor.get("measurement_kind")
            or semantic.get("source_xy_px") != [anchor.get("source_x_px"), anchor.get("source_y_px")]
            or semantic.get("review_note") != anchor.get("review_note")
            or semantic.get("target_xy_px") != [canvas["anchor_target_x_px"], canvas["anchor_target_y_px"]]
            or semantic_fit_shift != fit_shift
            or semantic_placed != placed_anchor
        ):
            return False
        if unit in unit_scales and unit_scales[unit] != scale:
            return False
        unit_scales[unit] = float(scale)
        metadata = (float(reference_scale), float(fit_limit), float(fit_limited_scale))
        if unit in unit_scale_metadata and unit_scale_metadata[unit] != metadata:
            return False
        unit_scale_metadata[unit] = metadata
        pose_map[key] = row

    candidate_strips = _exact_keyed_records(candidate.get("strips"), expected_outputs, ("unit", "state", "direction"))
    if candidate_strips is None:
        return False
    for key, strip in candidate_strips.items():
        unit, state, direction = key
        recipe = recipes[state]
        target = f"{unit}_{state}_{direction}.png"
        staged_expected = f"strips/{target}"
        staged_path = _verified_relative_file(root, strip.get("staged_file"), strip.get("sha256"), base=stage_root)
        production_row = production_outputs[key]
        production_path = overrides.get(target, root / "assets" / "anim" / target)
        frames = strip.get("frames")
        if (
            staged_path is None
            or strip.get("staged_file") != staged_expected
            or strip.get("target_file") != target
            or strip.get("recipe") != list(recipe)
            or strip.get("frame_count") != len(recipe)
            or strip.get("size") != [256 * len(recipe), 256]
            or _native_rgba_png_dimensions(staged_path) != (256 * len(recipe), 256)
            or not _is_sha256(strip.get("pixel_sha256"))
            or not isinstance(frames, list)
            or len(frames) != len(recipe)
            or production_row.get("sha256") != strip.get("sha256")
            or _verified_override_file(root, production_path, strip.get("sha256")) is None
            or _native_rgba_png_dimensions(production_path) != (256 * len(recipe), 256)
        ):
            return False
        for frame_name, frame in zip(recipe, frames):
            if not isinstance(frame, dict) or frame.get("kind") != frame_name:
                return False
            expected_frame = idle_map[(unit, direction)] if frame_name == "idle" else pose_map[(frame_name, unit, direction)]
            expected_file = expected_frame["file"] if frame_name == "idle" else expected_frame["staged_file"]
            if (
                frame.get("file") != expected_file
                or frame.get("sha256") != expected_frame.get("sha256")
                or frame.get("pixel_sha256") != expected_frame.get("pixel_sha256")
            ):
                return False

    counts = candidate.get("counts")
    if not isinstance(counts, dict) or any(counts.get(key) != value for key, value in {
        "source_atlases": 4,
        "semantic_anchors": 64,
        "normalized_poses": 64,
        "production_strips": 48,
        "candidate_contact_sheets": 1,
    }.items()):
        return False
    contact = candidate.get("candidate_contact_sheet")
    if not isinstance(contact, dict):
        return False
    contact_path = _verified_relative_file(root, contact.get("file"), contact.get("sha256"), base=stage_root)
    if (
        contact_path is None
        or contact.get("qa_only") is not True
        or not _is_sha256(contact.get("pixel_sha256"))
        or not isinstance(contact.get("size"), list)
        or len(contact["size"]) != 2
        or tuple(contact["size"]) != _native_rgba_png_dimensions(contact_path)
        or not isinstance(contact.get("coverage"), str)
        or not contact["coverage"].strip()
    ):
        return False

    snapshot = candidate.get("target_snapshot")
    expected_targets = {f"{unit}_{state}_{direction}.png" for unit, state, direction in expected_outputs}
    if not isinstance(snapshot, dict) or set(snapshot) != expected_targets:
        return False
    for target, row in snapshot.items():
        if not isinstance(row, dict) or not isinstance(row.get("exists"), bool) or not isinstance(row.get("already_identical"), bool):
            return False
        if row["exists"]:
            if not _is_sha256(row.get("sha256")):
                return False
        elif row.get("sha256") is not None or row["already_identical"]:
            return False

    comparisons = _exact_keyed_records(candidate.get("idle_walk_alpha_bbox_comparison"), expected_idles, ("unit", "direction"))
    if comparisons is None:
        return False
    for key, row in comparisons.items():
        idle = row.get("idle")
        walk = row.get("walk_step")
        idle_size = _int_pair(idle.get("size")) if isinstance(idle, dict) else None
        walk_size = _int_pair(walk.get("size")) if isinstance(walk, dict) else None
        height_ratio = row.get("walk_to_idle_height_ratio")
        width_ratio = row.get("walk_to_idle_width_ratio")
        reference_scale, fit_limit, fit_limited_scale = unit_scale_metadata[key[0]]
        if (
            idle_size is None
            or walk_size is None
            or min(*idle_size, *walk_size) <= 0
            or not isinstance(height_ratio, (int, float))
            or not isinstance(width_ratio, (int, float))
            or not math.isclose(height_ratio, walk_size[1] / idle_size[1], rel_tol=0.0, abs_tol=1e-12)
            or not math.isclose(width_ratio, walk_size[0] / idle_size[0], rel_tol=0.0, abs_tol=1e-12)
            or row.get("preferred_height_ratio_range") != [0.9, 1.1]
            or row.get("hard_height_ratio_range") != [0.85, 1.15]
            or row.get("preferred_height_ratio_passed") is not (0.9 <= height_ratio <= 1.1)
            or row.get("hard_height_ratio_passed") is not True
            or not 0.85 <= height_ratio <= 1.15
            or row.get("reference_scale") != reference_scale
            or row.get("all_pose_canvas_fit_scale_limit") != fit_limit
            or row.get("fit_limited_scale") != fit_limited_scale
            or row.get("uniform_scale_for_unit_all_actions") != unit_scales[key[0]]
            or not isinstance(row.get("gate"), str)
            or "Hard 0.85-1.15" not in row["gate"]
        ):
            return False

    tool = candidate.get("tool")
    contract = candidate.get("processing_contract")
    contract_text = "\n".join(contract) if isinstance(contract, list) and all(isinstance(item, str) for item in contract) else ""
    if (
        not isinstance(tool, dict)
        or not isinstance(tool.get("file"), str)
        or not _is_sha256(tool.get("sha256"))
        or not isinstance(tool.get("python"), str)
        or not tool["python"]
        or not isinstance(tool.get("pillow"), str)
        or not tool["pillow"]
        or production.get("processing_contract") != contract
        or "never converted, mirrored, rotated, masked, threshold-cropped, cleared, repainted, or supplemented" not in contract_text
        or "manual_source_rect" not in contract_text
        or "complete alpha>0 bbox" not in contract_text
        or "reference scale is the median" not in contract_text
        or "fit-limited world scale" not in contract_text
        or "canvas.max_walk_attack_fit_shift_px" not in contract_text
        or "walk=idle+walk_step; attack=idle+attack_strike+idle; death=idle+death_fall+death_down+death_down" not in contract_text
    ):
        return False
    return True


def _archer_sw_backup_overrides(root: Path) -> dict[str, Path]:
    backup_root = root / SKIRMISH_ARCHER_SW_BACKUP_REL
    return {target: backup_root / target for target in SKIRMISH_ARCHER_SW_TARGETS}


def _base_archer_sw_hashes(root: Path, production: dict[str, Any]) -> dict[str, str] | None:
    """Read the four pre-revision hashes from the already-validated base chain."""
    expected_outputs = {
        (unit, state, direction)
        for unit in SKIRMISH_ACTION_UNITS
        for direction in DIRECTIONS
        for state in SKIRMISH_ACTION_RECIPES
    }
    production_outputs = _exact_keyed_records(
        production.get("outputs"), expected_outputs, ("unit", "state", "direction")
    )
    candidate_ref = production.get("candidate_manifest")
    if production_outputs is None or not isinstance(candidate_ref, dict):
        return None
    candidate_path = _verified_relative_file(root, candidate_ref.get("file"), candidate_ref.get("sha256"))
    candidate = _json_object(candidate_path) if candidate_path is not None else None
    expected_idles = {(unit, direction) for unit in SKIRMISH_ACTION_UNITS for direction in DIRECTIONS}
    candidate_idles = (
        _exact_keyed_records(candidate.get("idle_inputs"), expected_idles, ("unit", "direction"))
        if candidate is not None
        else None
    )
    if candidate_idles is None:
        return None
    hashes = {
        "guan_gong_idle_sw.png": candidate_idles[("guan_gong", "sw")].get("sha256"),
    }
    for state in ("walk", "attack", "death"):
        hashes[f"guan_gong_{state}_sw.png"] = production_outputs[("guan_gong", state, "sw")].get("sha256")
    return hashes if all(_is_sha256(value) for value in hashes.values()) else None


def _load_rgba_png(path: Path, expected_size: tuple[int, int]) -> Any | None:
    """Decode a PNG read-only, retaining exact RGBA samples for strip checks."""
    if _native_rgba_png_dimensions(path) != expected_size:
        return None
    try:
        from PIL import Image

        with Image.open(path) as opened:
            if opened.format != "PNG" or opened.mode != "RGBA" or opened.size != expected_size:
                return None
            opened.load()
            return opened.copy()
    except (ImportError, OSError, ValueError):
        return None


def _valid_skirmish_archer_sw_revision(
    root: Path,
    revision_path: Path,
    base_manifest_path: Path,
    production: dict[str, Any],
) -> bool:
    """Verify the four-file SW archer patch and reconstruct every output pixel.

    The old 48-strip chain is verified separately against immutable backups.
    This gate then proves the new two-pose source, prompt, exact target scope,
    before hashes, placement math, retained old frames, and live output pixels.
    """
    if not revision_path.is_file() or revision_path.is_symlink():
        return False
    revision = _json_object(revision_path)
    expected_top_keys = {
        "schema_version",
        "kind",
        "status",
        "conversation",
        "source",
        "prompt",
        "base_action_manifest_sha256",
        "processing",
        "placements",
        "outputs",
        "visual_review",
        "retained_frames",
    }
    if (
        revision is None
        or set(revision) != expected_top_keys
        or revision.get("schema_version") != 1
        or revision.get("kind") != "skirmish_archer_sw_visual_revision"
        or revision.get("status") != "committed"
        or not isinstance(revision.get("conversation"), str)
        or re.fullmatch(r"https://chatgpt\.com/c/[0-9a-f-]{36}", revision["conversation"]) is None
        or revision.get("processing") != SKIRMISH_ARCHER_SW_PROCESSING
        or revision.get("visual_review") != SKIRMISH_ARCHER_SW_VISUAL_REVIEW
        or revision.get("retained_frames") != SKIRMISH_ARCHER_SW_RETAINED
        or revision.get("base_action_manifest_sha256") != sha256(base_manifest_path)
    ):
        return False

    source_ref = revision.get("source")
    prompt_ref = revision.get("prompt")
    if (
        not isinstance(source_ref, dict)
        or set(source_ref) != {"file", "sha256"}
        or source_ref.get("file") != SKIRMISH_ARCHER_SW_SOURCE_REL
        or not isinstance(prompt_ref, dict)
        or set(prompt_ref) != {"file", "sha256"}
        or prompt_ref.get("file") != SKIRMISH_ARCHER_SW_PROMPT_REL
    ):
        return False
    source_path = _verified_relative_file(root, source_ref.get("file"), source_ref.get("sha256"))
    prompt_path = _verified_relative_file(root, prompt_ref.get("file"), prompt_ref.get("sha256"))
    if source_path is None or prompt_path is None:
        return False
    try:
        prompt_text = prompt_path.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        return False
    if not prompt_text.strip() or "SW" not in prompt_text or "RGBA" not in prompt_text:
        return False

    expected_before = _base_archer_sw_hashes(root, production)
    backup_root = root / SKIRMISH_ARCHER_SW_BACKUP_REL
    if expected_before is None or not backup_root.is_dir() or backup_root.is_symlink():
        return False
    try:
        backup_entries = list(backup_root.iterdir())
    except OSError:
        return False
    if {entry.name for entry in backup_entries} != set(SKIRMISH_ARCHER_SW_TARGETS):
        return False
    backups = _archer_sw_backup_overrides(root)
    for target, backup in backups.items():
        if _verified_override_file(root, backup, expected_before[target]) is None:
            return False

    output_rows = _exact_keyed_records(
        revision.get("outputs"), {(target,) for target in SKIRMISH_ARCHER_SW_TARGETS}, ("target",)
    )
    if output_rows is None:
        return False
    state_frames = {"idle": 1, "walk": 2, "attack": 3, "death": 4}
    for target in SKIRMISH_ARCHER_SW_TARGETS:
        state = target.removeprefix("guan_gong_").removesuffix("_sw.png")
        row = output_rows[(target,)]
        if (
            set(row) != {
                "target", "state", "unit", "direction", "before_sha256", "sha256", "frame_count"
            }
            or row.get("state") != state
            or row.get("unit") != "guan_gong"
            or row.get("direction") != "sw"
            or row.get("before_sha256") != expected_before[target]
            or not _is_sha256(row.get("sha256"))
            or row.get("frame_count") != state_frames[state]
        ):
            return False

    source = _load_rgba_png(source_path, (1774, 887))
    old_attack = _load_rgba_png(backups["guan_gong_attack_sw.png"], (768, 256))
    old_death = _load_rgba_png(backups["guan_gong_death_sw.png"], (1024, 256))
    if source is None or old_attack is None or old_death is None:
        return False
    try:
        from PIL import Image

        cells = (source.crop((0, 0, 887, 887)), source.crop((887, 0, 1774, 887)))
        bboxes = tuple(cell.getchannel("A").getbbox() for cell in cells)
        if any(bbox is None for bbox in bboxes):
            return False
        scale = min(
            198 / 653,
            *(248 / max(bbox[2] - bbox[0], bbox[3] - bbox[1]) for bbox in bboxes),
        )
        normalized: dict[str, Any] = {}
        expected_placements: dict[str, dict[str, Any]] = {}
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
            paste_xy = (
                max(4, min(desired[0], 252 - resized.width)),
                max(4, min(desired[1], 252 - resized.height)),
            )
            canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
            canvas.paste(resized, paste_xy)
            alpha_bbox = canvas.getchannel("A").getbbox()
            if alpha_bbox is None:
                return False
            normalized[pose] = canvas
            expected_placements[pose] = {
                "crop_in_half": list(bbox),
                "half_x": half_x,
                "virtual_ground_pivot_in_half": list(pivot),
                "scale": scale,
                "paste_xy": list(paste_xy),
                "fit_shift_xy_px": [paste_xy[0] - desired[0], paste_xy[1] - desired[1]],
                "alpha_bbox": list(alpha_bbox),
            }
        if revision.get("placements") != expected_placements:
            return False

        idle = normalized["idle"]
        expected_frames = {
            "idle": [idle],
            "walk": [idle, normalized["walk_step"]],
            "attack": [idle, old_attack.crop((256, 0, 512, 256)), idle],
            "death": [idle]
            + [old_death.crop((index * 256, 0, (index + 1) * 256, 256)) for index in range(1, 4)],
        }
        for state, frames in expected_frames.items():
            target = f"guan_gong_{state}_sw.png"
            expected_strip = Image.new("RGBA", (256 * len(frames), 256), (0, 0, 0, 0))
            for index, frame in enumerate(frames):
                expected_strip.paste(frame, (index * 256, 0))
            live_path = root / "assets" / "anim" / target
            row = output_rows[(target,)]
            actual_strip = _load_rgba_png(live_path, expected_strip.size)
            if (
                actual_strip is None
                or sha256(live_path) != row.get("sha256")
                or actual_strip.tobytes() != expected_strip.tobytes()
            ):
                return False
    except (OSError, ValueError, TypeError):
        return False
    return True


def skirmish_action_provenance_index(
    root: Path = ROOT,
    rel: str = SKIRMISH_ACTION_MANIFEST_REL,
) -> dict[str, dict[str, Any]]:
    """Return action-strip provenance, never accepting files without their chain."""
    manifest_path = root / rel
    if not manifest_path.is_file() or manifest_path.is_symlink():
        return {}
    production = _json_object(manifest_path)
    if production is None:
        return {}
    expected = {
        (unit, state, direction)
        for unit in SKIRMISH_ACTION_UNITS
        for direction in DIRECTIONS
        for state in SKIRMISH_ACTION_RECIPES
    }
    declared: dict[str, dict[str, Any]] = {}
    outputs = production.get("outputs")
    if isinstance(outputs, list):
        for row in outputs:
            if not isinstance(row, dict):
                continue
            key = (str(row.get("unit", "")), str(row.get("state", "")), str(row.get("direction", "")))
            if key not in expected:
                continue
            unit, state, direction = key
            target = f"{unit}_{state}_{direction}.png"
            if row.get("target") == target:
                declared[f"assets/anim/{target}"] = row
    if not declared:
        return {}
    revision_path = root / SKIRMISH_ARCHER_SW_REVISION_REL
    revision_present = revision_path.exists() or revision_path.is_symlink()
    overrides = _archer_sw_backup_overrides(root) if revision_present else None
    try:
        complete = _valid_skirmish_action_chain(
            root,
            manifest_path,
            production,
            production_file_overrides=overrides,
        )
        revision_complete = (
            complete
            and revision_present
            and _valid_skirmish_archer_sw_revision(root, revision_path, manifest_path, production)
        )
    except (OSError, ValueError, TypeError, KeyError, json.JSONDecodeError, struct.error):
        complete = False
        revision_complete = False
    source_id = str(production.get("batch_id", ""))
    result: dict[str, dict[str, Any]] = {}
    for out_path in declared:
        target = out_path.removeprefix("assets/anim/")
        is_revised_action = revision_present and target in SKIRMISH_ARCHER_SW_ACTION_TARGETS
        compliant = revision_complete if is_revised_action else complete
        result[out_path] = {
            "tracked": True,
            "manifest": SKIRMISH_ARCHER_SW_REVISION_REL if is_revised_action else rel,
            "kind": "skirmish_archer_sw_visual_revision"
            if is_revised_action
            else "skirmish_direction4_action_production_manifest",
            "source_id": "skirmish_archer_sw_revision_20260905" if is_revised_action else source_id,
            "provenance_compliant": compliant,
            "reason": (
                "archer_sw_source_prompt_backup_base_chain_and_exact_strip_pixels_verified"
                if is_revised_action and compliant
                else "base_action_chain_or_archer_sw_revision_incomplete"
                if is_revised_action
                else "browser_generated_alpha_cleaned_manual_rect_uniform_scale_transparent_padding_chain_verified"
                if compliant
                else "source_provenance_or_production_hash_incomplete"
            ),
        }
    if revision_present:
        # Idle is not one of the base action manifest's 48 strips, but the same
        # four-target revision replaces it and every revised strip starts from
        # this exact frame.  Publish it only through the already-strict revision
        # gate so it cannot fall back to the now-stale original idle manifest.
        result["assets/anim/guan_gong_idle_sw.png"] = {
            "tracked": True,
            "manifest": SKIRMISH_ARCHER_SW_REVISION_REL,
            "kind": "skirmish_archer_sw_visual_revision",
            "source_id": "skirmish_archer_sw_revision_20260905",
            "provenance_compliant": revision_complete,
            "reason": (
                "archer_sw_source_prompt_backup_base_chain_and_exact_strip_pixels_verified"
                if revision_complete
                else "base_action_chain_or_archer_sw_revision_incomplete"
            ),
        }
    return result


def provenance_index() -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}

    def direction_manifest(rel: str, kind: str) -> None:
        path = ROOT / rel
        if not path.exists():
            return
        data = json.loads(path.read_text(encoding="utf-8"))
        sources = data.get("sources", {})
        for output in data.get("outputs", []):
            out_path = str(output.get("output", "")).replace("\\", "/")
            source_id = str(output.get("source", output.get("source_id", "")))
            if not source_id:
                # Current manifests keep source identity on the output only in
                # some generations.  Resolve by matching key/unit to source rows.
                row_key = str(output.get("unit", output.get("key", "")))
                row_state = str(output.get("state", ""))
                for sid, source in sources.items():
                    rows = source.get("row_mapping", source.get("layout", {}).get("rows", []) if isinstance(source.get("layout"), dict) else [])
                    row_units = source.get("row_units", [])
                    if row_key in row_units or any(
                        (isinstance(row, dict) and str(row.get("unit", row.get("key", ""))) == row_key and str(row.get("state", row_state)) == row_state)
                        for row in rows
                    ):
                        source_id = sid
                        break
            source = sources.get(source_id, {})
            isolation = json.dumps(output.get("isolation", ""), ensure_ascii=False).lower()
            retained = str(output.get("retained_pixels", source.get("retained_pixels", "")))
            layout = output.get("layout", source.get("layout"))
            bad_component = any(token in isolation for token in ("foreign figures are zeroed", "component ownership", "connected-component", "component_id"))
            whole_cell = ("whole" in retained.lower() and "source cell" in retained.lower()) or (
                "whole audited transparent-seam grid cell" in isolation and "all original in-cell rgba" in isolation
            ) or (
                "rectangular alpha-content crop is copied whole" in isolation
                and int(output.get("excluded_foreign_pixels", -1)) == 0
            )
            grid = layout == "grid" or (isinstance(layout, dict) and bool(layout.get("directions")))
            compliant = bool(grid and whole_cell and not bad_component)
            result[out_path] = {
                "tracked": True,
                "manifest": rel,
                "kind": kind,
                "source_id": source_id,
                "provenance_compliant": compliant,
                "reason": "audited_grid_whole_source_cell" if compliant else ("component_masking_or_foreign_pixel_zeroing" if bad_component else "not_audited_as_grid_whole_source_cell"),
            }

    direction_manifest("assets/direction4/manifest.json", "ordinary_direction_manifest")
    direction_manifest("assets/direction4/campaign_object_manifest.json", "campaign_object_direction_manifest")

    web_path = ROOT / "assets/campaign/web_art_manifest.json"
    if web_path.exists():
        data = json.loads(web_path.read_text(encoding="utf-8"))
        sources = data.get("sources", {})
        for artifact in data.get("artifacts", []):
            out_path = _manifest_output_path("assets/campaign", str(artifact.get("output", "")))
            frames = artifact.get("frames", [])
            bad_component = False
            source_ids: list[str] = []
            for frame in frames:
                source_ids.append(str(frame.get("source", "")))
                payload = json.dumps(frame, ensure_ascii=False).lower()
                if any(token in payload for token in ("isolation_runs", "connected-component", "component ownership", "component_id", "foreign figures")):
                    bad_component = True
            source_ok = True
            for source_id in source_ids:
                source = sources.get(source_id, {})
                retained = str(source.get("retained_rgba", source.get("retained_pixels", ""))).lower()
                if not retained or any(token in retained for token in ("repaint", "mirror")) and "no repaint" not in retained and "no direction mirroring" not in retained:
                    source_ok = False
            compliant = bool(frames and not bad_component and source_ok)
            result[out_path] = {
                "tracked": True,
                "manifest": "assets/campaign/web_art_manifest.json",
                "kind": "campaign_web_art_manifest",
                "source_id": sorted(set(source_ids)),
                "provenance_compliant": compliant,
                "reason": "rectangular_source_crop_without_pixel_deletion" if compliant else ("component_masking_or_foreign_pixel_zeroing" if bad_component else "source_provenance_incomplete"),
            }

    def fixed_rect_manifest(rel: str, kind: str) -> None:
        path = ROOT / rel
        if not path.exists():
            return
        data = json.loads(path.read_text(encoding="utf-8"))
        source_sessions = data.get("source_generation_conversations") or [data.get("source_generation_conversation")]
        source_sessions = [str(value) for value in source_sessions if value]
        top_level_complete = bool(
            source_sessions
            and data.get("exact_alpha_cleanup_conversation")
            and data.get("web_input_archive_sha256")
            and data.get("web_download_archive_sha256")
            and data.get("candidate_manifest_sha256")
            and data.get("candidate_preview_sha256")
            and data.get("exact_alpha_verification_sha256")
            and data.get("forbidden_operations_used") == []
            and data.get("frame_count") == 20
        )
        sources = data.get("sources", [])
        sources_complete = bool(len(sources) == 5 and all(
            source.get("raw_sha256")
            and source.get("cleaned_sha256")
            and (source.get("base_prompt_sha256") or source.get("prompt_sha256"))
            and source.get("exact_alpha_prompt_sha256")
            and str(source.get("source_generation_conversation", "")) in source_sessions
            and source.get("exact_alpha_cleanup_conversation") == data.get("exact_alpha_cleanup_conversation")
            for source in sources
        ))
        outputs = data.get("outputs", [])
        outputs_complete = len(outputs) == 20
        for output in outputs:
            out_path = str(output.get("path", "")).replace("\\", "/")
            output_complete = bool(
                outputs_complete
                and out_path
                and output.get("copy_is_byte_identical_to_candidate") is True
                and output.get("sha256")
                and output.get("source_sha256")
                and output.get("source_cell_rect_xyxy")
                and output.get("source_rect_xyxy")
                and output.get("batch_uniform_requested_scale") is not None
                and output.get("paste_xy")
                and output.get("target_anchor_xy")
            )
            compliant = bool(top_level_complete and sources_complete and output_complete)
            result[out_path] = {
                "tracked": True,
                "manifest": rel,
                "kind": kind,
                "source_id": str(output.get("source_file", "")),
                "provenance_compliant": compliant,
                "reason": "continuous_source_rect_uniform_scale_transparent_padding_byte_copy" if compliant else "source_provenance_incomplete",
            }

    fixed_rect_manifest(
        "assets/campaign/lu_zhishen_rescue_direction4_manifest.json",
        "lu_zhishen_exact_alpha_fixed_rect_manifest",
    )
    fixed_rect_manifest(
        "assets/campaign/wu_song_mengzhou_direction4_manifest.json",
        "wu_song_mengzhou_exact_alpha_fixed_rect_manifest",
    )
    fixed_rect_manifest(
        "assets/campaign/jiang_menshen_fists_direction4_manifest.json",
        "jiang_menshen_exact_alpha_fixed_rect_manifest",
    )

    def native_alpha_fixed_rect_manifest(rel: str, kind: str) -> None:
        path = ROOT / rel
        if not path.exists():
            return
        data = json.loads(path.read_text(encoding="utf-8"))

        def workspace_path(value: str) -> Path:
            candidate = Path(value)
            if candidate.is_absolute():
                return candidate
            in_project = ROOT / candidate
            return in_project if in_project.exists() else ROOT.parent / candidate

        candidate_manifest = workspace_path(str(data.get("candidate_manifest", "")))
        candidate_preview = workspace_path(str(data.get("candidate_preview", "")))
        manual_review = workspace_path(str(data.get("manual_visual_review", "")))
        backup_path = workspace_path(str(data.get("backup_path", "")))
        backup_manifest = workspace_path(str(data.get("backup_manifest", "")))
        states = tuple(str(value) for value in data.get("states", []))
        directions = tuple(str(value) for value in data.get("directions", []))
        expected_pairs = {(state, direction) for state in states for direction in directions}
        expected_frame_count = len(expected_pairs)
        top_level_complete = bool(
            data.get("schema_version") == 1
            and data.get("source_generation_conversation")
            and data.get("web_native_alpha") is True
            and data.get("alpha_cleanup_performed") is False
            and data.get("forbidden_operations_used") == []
            and states
            and directions == DIRECTIONS
            and data.get("frame_count") == expected_frame_count
            and data.get("manual_visual_review_passed") is True
            and data.get("steam_modified_or_exported") is False
            and candidate_manifest.is_file()
            and sha256(candidate_manifest).lower() == str(data.get("candidate_manifest_sha256", "")).lower()
            and candidate_preview.is_file()
            and sha256(candidate_preview).lower() == str(data.get("candidate_preview_sha256", "")).lower()
            and manual_review.is_file()
            and sha256(manual_review).lower() == str(data.get("manual_visual_review_sha256", "")).lower()
            and backup_path.is_dir()
            and backup_manifest.is_file()
            and sha256(backup_manifest).lower() == str(data.get("backup_manifest_sha256", "")).lower()
        )
        sources = data.get("sources", [])
        sources_complete = bool(len(sources) == len(states) and all(
            source.get("source_sha256")
            and source.get("source_mode") == "RGBA"
            and source.get("prompt_sha256")
            and source.get("fixed_cell_x_boundaries")
            and workspace_path(str(source.get("source_path", ""))).is_file()
            and sha256(workspace_path(str(source.get("source_path", "")))).lower() == str(source.get("source_sha256", "")).lower()
            and workspace_path(str(source.get("prompt_path", ""))).is_file()
            and sha256(workspace_path(str(source.get("prompt_path", "")))).lower() == str(source.get("prompt_sha256", "")).lower()
            for source in sources
        ))
        outputs = data.get("outputs", [])
        actual_pairs = {
            (str(output.get("state", "")), str(output.get("direction", "")))
            for output in outputs
        }
        outputs_complete = len(outputs) == expected_frame_count and actual_pairs == expected_pairs
        protected_groups = [
            value for key, value in data.items()
            if key.startswith("protected_generic_") and key.endswith("_sha256") and isinstance(value, dict)
        ]
        protected_generic_complete = all(group and all(
            (ROOT / rel_path).is_file()
            and sha256(ROOT / rel_path).lower() == str(expected_hash).lower()
            for rel_path, expected_hash in group.items()
        ) for group in protected_groups)
        for output in outputs:
            out_path = str(output.get("path", "")).replace("\\", "/")
            production_path = ROOT / out_path
            candidate_path = workspace_path(str(output.get("candidate_path", "")))
            output_complete = bool(
                top_level_complete
                and sources_complete
                and outputs_complete
                and protected_generic_complete
                and out_path
                and output.get("copy_is_byte_identical_to_candidate") is True
                and production_path.is_file()
                and candidate_path.is_file()
                and sha256(production_path).lower() == str(output.get("sha256", "")).lower()
                and sha256(candidate_path).lower() == str(output.get("candidate_sha256", "")).lower()
                and sha256(production_path) == sha256(candidate_path)
            )
            result[out_path] = {
                "tracked": True,
                "manifest": rel,
                "kind": kind,
                "source_id": "web_native_alpha_rgba_sources",
                "provenance_compliant": output_complete,
                "reason": "native_alpha_continuous_source_rect_uniform_scale_transparent_padding_byte_copy" if output_complete else "source_provenance_or_production_hash_incomplete",
            }

    native_alpha_fixed_rect_manifest(
        "assets/campaign/li_kui_jiangzhou_direction4_manifest.json",
        "li_kui_jiangzhou_native_alpha_fixed_rect_manifest",
    )
    native_alpha_fixed_rect_manifest(
        "assets/campaign/gao_flagship_direction4_manifest.json",
        "gao_flagship_native_alpha_transparent_gutter_manifest",
    )
    native_alpha_fixed_rect_manifest(
        "assets/campaign/gao_qiu_captured_direction4_manifest.json",
        "gao_qiu_captured_native_alpha_fixed_rect_manifest",
    )

    def lin_chong_p0_manifest(rel: str) -> None:
        path = ROOT / rel
        if not path.exists():
            return
        data = json.loads(path.read_text(encoding="utf-8"))

        def manifest_path(value: str) -> Path:
            candidate = Path(value)
            return candidate if candidate.is_absolute() else ROOT / candidate

        top_level_complete = bool(
            data.get("schema_version") == 1
            and data.get("source_generation_conversation")
            and data.get("allowed_local_operations")
            and data.get("web_exact_operations")
            and data.get("forbidden_operations_used") == []
            and data.get("steam_modified") is False
        )
        for group in data.get("groups", []):
            states = [str(value) for value in group.get("adopted_states", [])]
            outputs = group.get("outputs", [])
            expected_pairs = {(state, direction) for state in states for direction in DIRECTIONS}
            actual_pairs = {
                (str(output.get("state", "")), str(output.get("direction", "")))
                for output in outputs
            }
            source_path = manifest_path(str(group.get("source_path", "")))
            candidate_manifest = manifest_path(str(group.get("candidate_manifest", "")))
            candidate_preview = manifest_path(str(group.get("candidate_preview", "")))
            backup_path = manifest_path(str(group.get("backup_path", "")))
            group_complete = bool(
                top_level_complete
                and states
                and actual_pairs == expected_pairs
                and len(outputs) == len(expected_pairs)
                and group.get("web_exact_verification_passed") is True
                and group.get("manual_visual_review_passed") is True
                and source_path.is_file()
                and sha256(source_path).lower() == str(group.get("source_sha256", "")).lower()
                and candidate_manifest.is_file()
                and sha256(candidate_manifest).lower() == str(group.get("candidate_manifest_sha256", "")).lower()
                and candidate_preview.is_file()
                and sha256(candidate_preview).lower() == str(group.get("candidate_preview_sha256", "")).lower()
                and backup_path.is_dir()
            )
            for output in outputs:
                out_path = str(output.get("path", "")).replace("\\", "/")
                production_path = ROOT / out_path
                output_complete = bool(
                    group_complete
                    and out_path
                    and output.get("copy_is_byte_identical_to_candidate") is True
                    and production_path.is_file()
                    and sha256(production_path).lower() == str(output.get("sha256", "")).lower()
                )
                result[out_path] = {
                    "tracked": True,
                    "manifest": rel,
                    "kind": "lin_chong_p0_exact_web_manifest",
                    "source_id": str(group.get("source_path", "")),
                    "provenance_compliant": output_complete,
                    "reason": "web_exact_then_allowed_crop_scale_padding_byte_copy" if output_complete else "source_provenance_or_production_hash_incomplete",
                }

    lin_chong_p0_manifest("assets/campaign/lin_chong_p0_direction4_manifest.json")

    def huangnigang_p0_manifest(rel: str) -> None:
        path = ROOT / rel
        if not path.exists():
            return
        data = json.loads(path.read_text(encoding="utf-8"))

        def workspace_path(value: str) -> Path:
            candidate = Path(value)
            if candidate.is_absolute():
                return candidate
            in_project = ROOT / candidate
            return in_project if in_project.exists() else ROOT.parent / candidate

        candidate_manifest = workspace_path(str(data.get("candidate_manifest", "")))
        manual_review = workspace_path(str(data.get("manual_visual_review", "")))
        backup_manifest = workspace_path(str(data.get("backup_manifest", "")))
        cleanup_verification = workspace_path(str(data.get("cleanup_verification", "")))
        top_level_complete = bool(
            data.get("schema_version") == 1
            and data.get("campaign_level") == 1
            and data.get("scene_context") == "huangnigang"
            and data.get("source_generation_conversations")
            and data.get("cleanup_conversations")
            and data.get("web_alpha_cleanup_performed") is True
            and data.get("local_alpha_cleanup_performed") is False
            and data.get("fixed_grid_continuous_rect_crop") is True
            and data.get("mirroring_or_repainting_performed") is False
            and data.get("production_file_count") == 80
            and data.get("steam_modified_or_exported") is False
            and candidate_manifest.is_file()
            and sha256(candidate_manifest).lower() == str(data.get("candidate_manifest_sha256", "")).lower()
            and manual_review.is_file()
            and sha256(manual_review).lower() == str(data.get("manual_visual_review_sha256", "")).lower()
            and backup_manifest.is_file()
            and sha256(backup_manifest).lower() == str(data.get("backup_manifest_sha256", "")).lower()
            and cleanup_verification.is_file()
            and sha256(cleanup_verification).lower() == str(data.get("cleanup_verification_sha256", "")).lower()
        )
        sources = data.get("sources", [])
        sources_complete = bool(len(sources) == 9 and all(
            source.get("source_sha256")
            and source.get("source_mode") == "RGBA"
            and source.get("prompt_sha256")
            and source.get("raw_source_sha256")
            and source.get("web_cleanup_conversation_url")
            and source.get("exact_cleanup_rule_verified") is True
            and workspace_path(str(source.get("source_path", ""))).is_file()
            and sha256(workspace_path(str(source.get("source_path", "")))).lower()
                == str(source.get("source_sha256", "")).lower()
            and workspace_path(str(source.get("prompt_path", ""))).is_file()
            and sha256(workspace_path(str(source.get("prompt_path", "")))).lower()
                == str(source.get("prompt_sha256", "")).lower()
            and workspace_path(str(source.get("raw_source_path", ""))).is_file()
            and sha256(workspace_path(str(source.get("raw_source_path", "")))).lower()
                == str(source.get("raw_source_sha256", "")).lower()
            for source in sources
        ))
        outputs = data.get("outputs", [])
        outputs_complete = len(outputs) == 80
        for output in outputs:
            out_path = str(output.get("production_path", "")).replace("\\", "/")
            production_path = ROOT / out_path
            candidate_path = workspace_path(str(output.get("candidate_path", "")))
            output_complete = bool(
                top_level_complete
                and sources_complete
                and outputs_complete
                and out_path
                and production_path.is_file()
                and candidate_path.is_file()
                and sha256(production_path).lower() == str(output.get("production_sha256", "")).lower()
                and sha256(candidate_path).lower() == str(output.get("candidate_sha256", "")).lower()
                and sha256(production_path) == sha256(candidate_path)
            )
            result[out_path] = {
                "tracked": True,
                "manifest": rel,
                "kind": "huangnigang_p0_exact_web_cleanup_fixed_grid_manifest",
                "source_id": str(output.get("variant", "")),
                "provenance_compliant": output_complete,
                "reason": "web_exact_then_fixed_grid_continuous_rect_uniform_scale_transparent_padding_byte_copy"
                if output_complete else "source_provenance_or_production_hash_incomplete",
            }

    huangnigang_p0_manifest("assets/campaign/huangnigang_p0_direction4_manifest.json")

    def lianhuanma_p0_manifest(rel: str) -> None:
        path = ROOT / rel
        if not path.exists():
            return
        data = json.loads(path.read_text(encoding="utf-8"))

        def workspace_path(value: str) -> Path:
            candidate = Path(value)
            if candidate.is_absolute():
                return candidate
            in_project = ROOT / candidate
            return in_project if in_project.exists() else ROOT.parent / candidate

        candidate_manifest = workspace_path(str(data.get("candidate_manifest", "")))
        manual_review = workspace_path(str(data.get("manual_visual_review", "")))
        backup_manifest = workspace_path(str(data.get("backup_manifest", "")))
        cleanup_verification = workspace_path(str(data.get("cleanup_verification", "")))
        top_level_complete = bool(
            data.get("schema_version") == 1
            and data.get("campaign_level") == 4
            and data.get("scene_context") == "lianhuanma_battle"
            and data.get("source_generation_includes_codex_imagegen") is True
            and data.get("cleanup_conversations")
            and data.get("web_alpha_cleanup_performed") is True
            and data.get("local_alpha_cleanup_performed") is False
            and data.get("fixed_grid_continuous_rect_crop") is True
            and data.get("mirroring_or_repainting_performed") is False
            and data.get("production_file_count") == 20
            and data.get("steam_modified_or_exported") is False
            and candidate_manifest.is_file()
            and sha256(candidate_manifest).lower() == str(data.get("candidate_manifest_sha256", "")).lower()
            and manual_review.is_file()
            and sha256(manual_review).lower() == str(data.get("manual_visual_review_sha256", "")).lower()
            and backup_manifest.is_file()
            and sha256(backup_manifest).lower() == str(data.get("backup_manifest_sha256", "")).lower()
            and cleanup_verification.is_file()
            and sha256(cleanup_verification).lower() == str(data.get("cleanup_verification_sha256", "")).lower()
        )
        sources = data.get("sources", [])
        sources_complete = bool(len(sources) == 4 and all(
            source.get("source_sha256")
            and source.get("source_mode") == "RGBA"
            and source.get("prompt_sha256")
            and source.get("raw_source_sha256")
            and source.get("web_cleanup_conversation_url")
            and source.get("exact_cleanup_rule_verified") is True
            and source.get("generation_origin", {}).get("kind") == "codex_imagegen_generated"
            and workspace_path(str(source.get("source_path", ""))).is_file()
            and sha256(workspace_path(str(source.get("source_path", "")))).lower()
                == str(source.get("source_sha256", "")).lower()
            and workspace_path(str(source.get("prompt_path", ""))).is_file()
            and sha256(workspace_path(str(source.get("prompt_path", "")))).lower()
                == str(source.get("prompt_sha256", "")).lower()
            and workspace_path(str(source.get("raw_source_path", ""))).is_file()
            and sha256(workspace_path(str(source.get("raw_source_path", "")))).lower()
                == str(source.get("raw_source_sha256", "")).lower()
            and Path(str(source.get("generation_origin", {}).get("generated_image_path", ""))).is_file()
            and sha256(Path(str(source.get("generation_origin", {}).get("generated_image_path", "")))).lower()
                == str(source.get("raw_source_sha256", "")).lower()
            for source in sources
        ))
        outputs = data.get("outputs", [])
        expected_pairs = {
            (state, direction)
            for state in ("idle", "walk", "attack", "hurt", "death")
            for direction in DIRECTIONS
        }
        actual_pairs = {
            (str(output.get("state", "")), str(output.get("direction", "")))
            for output in outputs
        }
        outputs_complete = len(outputs) == 20 and actual_pairs == expected_pairs
        for output in outputs:
            out_path = str(output.get("production_path", "")).replace("\\", "/")
            production_path = ROOT / out_path
            candidate_path = workspace_path(str(output.get("candidate_path", "")))
            output_complete = bool(
                top_level_complete
                and sources_complete
                and outputs_complete
                and out_path
                and production_path.is_file()
                and candidate_path.is_file()
                and sha256(production_path).lower() == str(output.get("production_sha256", "")).lower()
                and sha256(candidate_path).lower() == str(output.get("candidate_sha256", "")).lower()
                and sha256(production_path) == sha256(candidate_path)
            )
            result[out_path] = {
                "tracked": True,
                "manifest": rel,
                "kind": "lianhuanma_p0_exact_web_cleanup_fixed_grid_manifest",
                "source_id": "lian_huan_ma",
                "provenance_compliant": output_complete,
                "reason": "web_exact_then_fixed_grid_continuous_rect_uniform_scale_transparent_padding_byte_copy"
                if output_complete else "source_provenance_or_production_hash_incomplete",
            }

    lianhuanma_p0_manifest("assets/direction4/lianhuanma_p0_direction4_manifest.json")

    def daming_prisoners_rect_manifest(rel: str) -> None:
        path = ROOT / rel
        if not path.exists():
            return
        data = json.loads(path.read_text(encoding="utf-8"))

        def workspace_path(value: str) -> Path:
            candidate = Path(value)
            if candidate.is_absolute():
                return candidate
            in_project = ROOT / candidate
            return in_project if in_project.exists() else ROOT.parent / candidate

        candidate_manifest = workspace_path(str(data.get("candidate_manifest", "")))
        manual_review = workspace_path(str(data.get("manual_visual_review", "")))
        backup_manifest = workspace_path(str(data.get("backup_manifest", "")))
        source_audit = workspace_path(str(data.get("source_audit", "")))
        historical_web_manifest = workspace_path(str(data.get("historical_web_manifest", "")))
        historical_web_qa = workspace_path(str(data.get("historical_web_qa", "")))
        top_level_complete = bool(
            data.get("schema_version") == 1
            and data.get("campaign_level") == 8
            and data.get("scene_context") == "daming_prisoners_and_rescue"
            and data.get("local_alpha_cleanup_performed") is False
            and data.get("continuous_rect_crop") is True
            and data.get("transparent_padding") is True
            and data.get("masking_or_connected_component_isolation_performed") is False
            and data.get("mirroring_or_repainting_performed") is False
            and data.get("production_file_count") == 16
            and data.get("steam_modified_or_exported") is False
            and candidate_manifest.is_file()
            and sha256(candidate_manifest).lower() == str(data.get("candidate_manifest_sha256", "")).lower()
            and manual_review.is_file()
            and sha256(manual_review).lower() == str(data.get("manual_visual_review_sha256", "")).lower()
            and backup_manifest.is_file()
            and sha256(backup_manifest).lower() == str(data.get("backup_manifest_sha256", "")).lower()
            and source_audit.is_file()
            and sha256(source_audit).lower() == str(data.get("source_audit_sha256", "")).lower()
            and historical_web_manifest.is_file()
            and sha256(historical_web_manifest).lower() == str(data.get("historical_web_manifest_sha256", "")).lower()
            and historical_web_qa.is_file()
            and sha256(historical_web_qa).lower() == str(data.get("historical_web_qa_sha256", "")).lower()
        )
        sources = data.get("sources", [])
        sources_complete = bool(len(sources) == 3 and all(
            source.get("source_id")
            and source.get("source_sha256")
            and source.get("source_mode") == "RGBA"
            and source.get("generation_mode") == "web ChatGPT"
            and source.get("conversation_url")
            and source.get("prompt_sha256")
            and workspace_path(str(source.get("source_path", ""))).is_file()
            and sha256(workspace_path(str(source.get("source_path", "")))).lower()
                == str(source.get("source_sha256", "")).lower()
            and workspace_path(str(source.get("prompt_path", ""))).is_file()
            and sha256(workspace_path(str(source.get("prompt_path", "")))).lower()
                == str(source.get("prompt_sha256", "")).lower()
            for source in sources
        ))
        outputs = data.get("outputs", [])
        expected = {
            *(f"daming_bound_lu_junyi_idle_{direction}" for direction in DIRECTIONS),
            *(f"daming_bound_shi_xiu_idle_{direction}" for direction in DIRECTIONS),
            *(f"daming_rescued_shi_xiu_idle_{direction}" for direction in DIRECTIONS),
            *(f"daming_rescued_shi_xiu_walk_{direction}" for direction in DIRECTIONS),
        }
        outputs_complete = len(outputs) == 16 and {str(row.get("id", "")) for row in outputs} == expected
        for output in outputs:
            out_path = str(output.get("production_path", "")).replace("\\", "/")
            production_path = ROOT / out_path
            candidate_path = workspace_path(str(output.get("candidate_path", "")))
            output_complete = bool(
                top_level_complete
                and sources_complete
                and outputs_complete
                and output.get("copy_is_byte_identical_to_candidate") is True
                and production_path.is_file()
                and candidate_path.is_file()
                and sha256(production_path).lower() == str(output.get("production_sha256", "")).lower()
                and sha256(candidate_path).lower() == str(output.get("candidate_sha256", "")).lower()
                and sha256(production_path) == sha256(candidate_path)
            )
            result[out_path] = {
                "tracked": True,
                "manifest": rel,
                "kind": "daming_prisoners_rectangle_only_manifest",
                "source_id": str(output.get("variant", "")),
                "provenance_compliant": output_complete,
                "reason": "web_source_then_continuous_rect_scale_transparent_padding_byte_copy"
                if output_complete else "source_provenance_or_production_hash_incomplete",
            }

    daming_prisoners_rect_manifest("assets/campaign/daming_prisoners_rect_rebuild_direction4_manifest.json")

    def ordinary_officials_p0_manifest(rel: str) -> None:
        path = ROOT / rel
        if not path.exists():
            return
        data = json.loads(path.read_text(encoding="utf-8"))

        def workspace_path(value: str) -> Path:
            candidate = Path(value)
            if candidate.is_absolute():
                return candidate
            in_project = ROOT / candidate
            return in_project if in_project.exists() else ROOT.parent / candidate

        candidate_manifest = workspace_path(str(data.get("candidate_manifest", "")))
        manual_review = workspace_path(str(data.get("manual_visual_review", "")))
        backup_manifest = workspace_path(str(data.get("backup_manifest", "")))
        cleanup_verification = workspace_path(str(data.get("cleanup_verification", "")))
        top_level_complete = bool(
            data.get("schema_version") == 1
            and data.get("campaign_levels") == [1, 2, 3, 5, 8]
            and data.get("web_alpha_cleanup_performed") is True
            and data.get("local_alpha_cleanup_performed") is False
            and data.get("fixed_cells_and_continuous_rect_crop") is True
            and data.get("uniform_proportional_scale_per_variant") is True
            and data.get("transparent_padding") is True
            and data.get("masking_or_connected_component_isolation_performed") is False
            and data.get("mirroring_or_repainting_performed") is False
            and data.get("animation_file_count") == 36
            and data.get("portrait_file_count") == 2
            and data.get("production_file_count") == 38
            and data.get("steam_modified_or_exported") is False
            and candidate_manifest.is_file()
            and sha256(candidate_manifest).lower() == str(data.get("candidate_manifest_sha256", "")).lower()
            and manual_review.is_file()
            and sha256(manual_review).lower() == str(data.get("manual_visual_review_sha256", "")).lower()
            and backup_manifest.is_file()
            and sha256(backup_manifest).lower() == str(data.get("backup_manifest_sha256", "")).lower()
            and cleanup_verification.is_file()
            and sha256(cleanup_verification).lower() == str(data.get("cleanup_verification_sha256", "")).lower()
        )
        sources = data.get("sources", [])
        sources_complete = bool(len(sources) == 4 and all(
            source.get("cleaned_sha256")
            and source.get("raw_sha256")
            and source.get("prompt_sha256")
            and source.get("mode") == "RGBA"
            and source.get("web_cleanup_conversation_url")
            and source.get("exact_alpha_cleanup_verified") is True
            and workspace_path(str(source.get("cleaned_path", ""))).is_file()
            and sha256(workspace_path(str(source.get("cleaned_path", "")))).lower()
                == str(source.get("cleaned_sha256", "")).lower()
            and workspace_path(str(source.get("raw_path", ""))).is_file()
            and sha256(workspace_path(str(source.get("raw_path", "")))).lower()
                == str(source.get("raw_sha256", "")).lower()
            and workspace_path(str(source.get("prompt_path", ""))).is_file()
            and sha256(workspace_path(str(source.get("prompt_path", "")))).lower()
                == str(source.get("prompt_sha256", "")).lower()
            and Path(str(source.get("codex_imagegen_original", ""))).is_file()
            and sha256(Path(str(source.get("codex_imagegen_original", "")))).lower()
                == str(source.get("raw_sha256", "")).lower()
            for source in sources
        ))
        outputs = data.get("outputs", [])
        animation_outputs = [row for row in outputs if row.get("kind") == "animation"]
        portrait_outputs = [row for row in outputs if row.get("kind") == "portrait"]
        expected_variants = {
            "chai_jin_officer", "yue_he_officer", "guan_dao", "guan_gong", "guan_qi",
            "guan_zhanzi", "guan_laozi", "jun_han", "zhu_keke",
        }
        expected_pairs = {(variant, direction) for variant in expected_variants for direction in DIRECTIONS}
        actual_pairs = {(str(row.get("variant", "")), str(row.get("direction", ""))) for row in animation_outputs}
        outputs_complete = bool(
            len(outputs) == 38
            and len(animation_outputs) == 36
            and len(portrait_outputs) == 2
            and actual_pairs == expected_pairs
            and {str(row.get("variant", "")) for row in portrait_outputs} == {"chai_jin_officer", "yue_he_officer"}
        )
        for output in outputs:
            out_path = str(output.get("production_path", "")).replace("\\", "/")
            production_path = ROOT / out_path
            candidate_path = workspace_path(str(output.get("candidate_path", "")))
            output_complete = bool(
                top_level_complete
                and sources_complete
                and outputs_complete
                and output.get("copy_is_byte_identical_to_candidate") is True
                and production_path.is_file()
                and candidate_path.is_file()
                and sha256(production_path).lower() == str(output.get("production_sha256", "")).lower()
                and sha256(candidate_path).lower() == str(output.get("candidate_sha256", "")).lower()
                and sha256(production_path) == sha256(candidate_path)
            )
            if output.get("kind") != "animation":
                continue
            result[out_path] = {
                "tracked": True,
                "manifest": rel,
                "kind": "ordinary_officials_p0_exact_web_cleanup_fixed_rect_manifest",
                "source_id": str(output.get("variant", "")),
                "provenance_compliant": output_complete,
                "reason": "imagegen_web_exact_then_fixed_cell_continuous_rect_uniform_scale_transparent_padding_byte_copy"
                if output_complete else "source_provenance_or_production_hash_incomplete",
            }

    def daming_lu_rescued_p0_manifest(rel: str) -> None:
        path = ROOT / rel
        if not path.exists():
            return
        data = json.loads(path.read_text(encoding="utf-8"))

        def workspace_path(value: str) -> Path:
            candidate = Path(value)
            if candidate.is_absolute():
                return candidate
            in_project = ROOT / candidate
            return in_project if in_project.exists() else ROOT.parent / candidate

        candidate_manifest = workspace_path(str(data.get("candidate_manifest", "")))
        manual_review = workspace_path(str(data.get("manual_visual_review", "")))
        backup_manifest = workspace_path(str(data.get("backup_manifest", "")))
        cleanup_verification = workspace_path(str(data.get("cleanup_verification", "")))
        source_audit = workspace_path(str(data.get("source_audit", "")))
        top_level_complete = bool(
            data.get("schema_version") == 1
            and data.get("campaign_level") == 8
            and data.get("web_alpha_cleanup_performed") is True
            and data.get("local_alpha_cleanup_performed") is False
            and data.get("fixed_grid_and_continuous_rect_crop") is True
            and data.get("shared_uniform_proportional_scale") is True
            and data.get("transparent_padding") is True
            and data.get("masking_or_connected_component_isolation_performed") is False
            and data.get("mirroring_or_repainting_performed") is False
            and data.get("animation_file_count") == 8
            and data.get("portrait_file_count") == 1
            and data.get("production_file_count") == 9
            and data.get("steam_modified_or_exported") is False
            and candidate_manifest.is_file()
            and sha256(candidate_manifest).lower() == str(data.get("candidate_manifest_sha256", "")).lower()
            and manual_review.is_file()
            and sha256(manual_review).lower() == str(data.get("manual_visual_review_sha256", "")).lower()
            and backup_manifest.is_file()
            and sha256(backup_manifest).lower() == str(data.get("backup_manifest_sha256", "")).lower()
            and cleanup_verification.is_file()
            and sha256(cleanup_verification).lower() == str(data.get("cleanup_verification_sha256", "")).lower()
            and source_audit.is_file()
            and sha256(source_audit).lower() == str(data.get("source_audit_sha256", "")).lower()
        )
        source = data.get("source", {})
        cleaned_path = workspace_path(str(source.get("cleaned_path", "")))
        raw_path = workspace_path(str(source.get("raw_path", "")))
        prompt_path = workspace_path(str(source.get("prompt_path", "")))
        original_path = Path(str(source.get("codex_imagegen_original", "")))
        source_complete = bool(
            source.get("mode") == "RGBA"
            and source.get("size") == [1224, 1285]
            and source.get("web_cleanup_conversation_url")
            and source.get("exact_alpha_cleanup_verified") is True
            and cleaned_path.is_file()
            and sha256(cleaned_path).lower() == str(source.get("cleaned_sha256", "")).lower()
            and raw_path.is_file()
            and sha256(raw_path).lower() == str(source.get("raw_sha256", "")).lower()
            and prompt_path.is_file()
            and sha256(prompt_path).lower() == str(source.get("prompt_sha256", "")).lower()
            and original_path.is_file()
            and sha256(original_path).lower() == str(source.get("raw_sha256", "")).lower()
        )
        outputs = data.get("outputs", [])
        animations = [row for row in outputs if row.get("kind") == "animation"]
        portraits = [row for row in outputs if row.get("kind") == "portrait"]
        expected_pairs = {(state, direction) for state in ("idle", "walk") for direction in DIRECTIONS}
        actual_pairs = {(str(row.get("state", "")), str(row.get("direction", ""))) for row in animations}
        outputs_complete = bool(
            len(outputs) == 9
            and len(animations) == 8
            and len(portraits) == 1
            and actual_pairs == expected_pairs
            and portraits[0].get("variant") == "daming_rescued_lu_junyi"
        )
        for output in outputs:
            out_path = str(output.get("production_path", "")).replace("\\", "/")
            production_path = ROOT / out_path
            candidate_path = workspace_path(str(output.get("candidate_path", "")))
            output_complete = bool(
                top_level_complete
                and source_complete
                and outputs_complete
                and output.get("variant") == "daming_rescued_lu_junyi"
                and output.get("copy_is_byte_identical_to_candidate") is True
                and production_path.is_file()
                and candidate_path.is_file()
                and sha256(production_path).lower() == str(output.get("production_sha256", "")).lower()
                and sha256(candidate_path).lower() == str(output.get("candidate_sha256", "")).lower()
                and sha256(production_path) == sha256(candidate_path)
            )
            if output.get("kind") != "animation":
                continue
            result[out_path] = {
                "tracked": True,
                "manifest": rel,
                "kind": "daming_lu_rescued_exact_web_cleanup_fixed_grid_manifest",
                "source_id": "daming_rescued_lu_junyi",
                "provenance_compliant": output_complete,
                "reason": "imagegen_web_exact_then_fixed_cell_continuous_rect_shared_uniform_scale_transparent_padding_byte_copy"
                if output_complete else "source_provenance_or_production_hash_incomplete",
            }

    def jiangzhou_prisoners_p0_manifest(rel: str) -> None:
        path = ROOT / rel
        if not path.exists():
            return
        data = json.loads(path.read_text(encoding="utf-8"))

        def workspace_path(value: str) -> Path:
            candidate = Path(value)
            if candidate.is_absolute():
                return candidate
            in_project = ROOT / candidate
            return in_project if in_project.exists() else ROOT.parent / candidate

        def hashed_file(path_value: object, hash_value: object) -> bool:
            file_path = workspace_path(str(path_value or ""))
            return bool(
                file_path.is_file()
                and hash_value
                and sha256(file_path).lower() == str(hash_value).lower()
            )

        candidate_manifest = workspace_path(str(data.get("candidate_manifest", "")))
        manual_review = workspace_path(str(data.get("manual_visual_review", "")))
        backup_manifest = workspace_path(str(data.get("backup_manifest", "")))
        source_audit = workspace_path(str(data.get("source_audit", "")))
        base_cleanup = workspace_path(str(data.get("base_cleanup_verification", "")))
        walk_cleanup = workspace_path(str(data.get("walk_cleanup_verification", "")))
        cleanup_reports_complete = False
        if base_cleanup.is_file() and walk_cleanup.is_file():
            base_report = json.loads(base_cleanup.read_text(encoding="utf-8"))
            walk_report = json.loads(walk_cleanup.read_text(encoding="utf-8"))
            cleanup_reports_complete = all(
                report.get("passed") is True
                and report.get("alpha_gt_15_mismatch_count") == 0
                and report.get("web_cleanup_performed") is True
                and report.get("local_pixel_editing_performed") is False
                and report.get("steam_modified_or_exported") is False
                for report in (base_report, walk_report)
            )

        top_level_complete = bool(
            data.get("schema_version") == 2
            and data.get("campaign_level") == 2
            and data.get("novel_context_url")
            and data.get("web_alpha_cleanup_performed") is True
            and data.get("web_alpha_cleanup_rule") == "alpha<=15 -> RGBA(0,0,0,0); alpha>15 -> byte-identical RGBA"
            and len(data.get("web_cleanup_conversation_urls", [])) == 2
            and data.get("local_alpha_cleanup_performed") is False
            and data.get("fixed_grid_and_continuous_rect_crop") is True
            and data.get("shared_uniform_proportional_scale_per_character_across_sources") is True
            and data.get("transparent_padding") is True
            and data.get("masking_or_connected_component_isolation_performed") is False
            and data.get("mirroring_or_repainting_performed") is False
            and data.get("rescued_walk_frames_per_direction") == 4
            and data.get("animation_file_count") == 24
            and data.get("portrait_file_count") == 4
            and data.get("production_file_count") == 28
            and data.get("steam_modified_or_exported") is False
            and candidate_manifest.is_file()
            and sha256(candidate_manifest).lower() == str(data.get("candidate_manifest_sha256", "")).lower()
            and manual_review.is_file()
            and sha256(manual_review).lower() == str(data.get("manual_visual_review_sha256", "")).lower()
            and backup_manifest.is_file()
            and sha256(backup_manifest).lower() == str(data.get("backup_manifest_sha256", "")).lower()
            and source_audit.is_file()
            and sha256(source_audit).lower() == str(data.get("source_audit_sha256", "")).lower()
            and base_cleanup.is_file()
            and sha256(base_cleanup).lower() == str(data.get("base_cleanup_verification_sha256", "")).lower()
            and walk_cleanup.is_file()
            and sha256(walk_cleanup).lower() == str(data.get("walk_cleanup_verification_sha256", "")).lower()
            and cleanup_reports_complete
        )

        expected_characters = {
            "song_jiang": ("song_jiang_bound", "song_jiang_rescued"),
            "dai_zong": ("dai_zong_bound", "dai_zong_rescued"),
        }
        sources = data.get("sources", [])
        source_complete = len(sources) == 2
        for source in sources:
            character = str(source.get("character", ""))
            expected_variants = expected_characters.get(character)
            base = source.get("base", {})
            walk = source.get("walk", {})
            source_complete = bool(
                source_complete
                and expected_variants
                and (source.get("bound_variant"), source.get("rescued_variant")) == expected_variants
                and float(source.get("shared_uniform_scale_across_base_and_walk_sources", 0.0)) > 0.0
                and base.get("source_mode") == "RGBA"
                and len(base.get("fixed_x_boundaries", [])) == 5
                and len(base.get("fixed_y_boundaries", [])) == 5
                and hashed_file(base.get("prompt_path"), base.get("prompt_sha256"))
                and hashed_file(base.get("raw_path"), base.get("raw_sha256"))
                and hashed_file(base.get("cleaned_path"), base.get("cleaned_sha256"))
                and Path(str(base.get("codex_imagegen_original", ""))).is_file()
                and sha256(Path(str(base.get("codex_imagegen_original", "")))).lower() == str(base.get("raw_sha256", "")).lower()
                and walk.get("source_mode") == "RGBA"
                and len(walk.get("fixed_x_boundaries", [])) == 5
                and len(walk.get("continuous_y_ranges", [])) == 4
                and hashed_file(walk.get("prompt_path"), walk.get("prompt_sha256"))
                and hashed_file(walk.get("raw_path"), walk.get("raw_sha256"))
                and hashed_file(walk.get("cleaned_path"), walk.get("cleaned_sha256"))
                and Path(str(walk.get("codex_imagegen_original", ""))).is_file()
                and sha256(Path(str(walk.get("codex_imagegen_original", "")))).lower() == str(walk.get("raw_sha256", "")).lower()
            )

        outputs = data.get("outputs", [])
        animations = [row for row in outputs if row.get("kind") == "animation"]
        portraits = [row for row in outputs if row.get("kind") == "portrait"]
        expected_animation_pairs = {
            (variant, state, direction)
            for variant, states in {
                "song_jiang_bound": ("idle",),
                "song_jiang_rescued": ("idle", "walk"),
                "dai_zong_bound": ("idle",),
                "dai_zong_rescued": ("idle", "walk"),
            }.items()
            for state in states
            for direction in DIRECTIONS
        }
        actual_animation_pairs = {
            (str(row.get("variant", "")), str(row.get("state", "")), str(row.get("direction", "")))
            for row in animations
        }
        outputs_complete = bool(
            len(outputs) == 28
            and len(animations) == 24
            and len(portraits) == 4
            and actual_animation_pairs == expected_animation_pairs
            and {str(row.get("variant", "")) for row in portraits}
            == {"song_jiang_bound", "song_jiang_rescued", "dai_zong_bound", "dai_zong_rescued"}
            and all(
                row.get("frame_count") == (4 if row.get("state") == "walk" else 1)
                for row in animations
            )
        )
        all_output_hashes_complete = True
        for output in outputs:
            out_path = str(output.get("production_path", "")).replace("\\", "/")
            production_path = ROOT / out_path
            candidate_path = workspace_path(str(output.get("candidate_path", "")))
            row_complete = bool(
                out_path
                and output.get("copy_is_byte_identical_to_candidate") is True
                and production_path.is_file()
                and candidate_path.is_file()
                and sha256(production_path).lower() == str(output.get("production_sha256", "")).lower()
                and sha256(candidate_path).lower() == str(output.get("candidate_sha256", "")).lower()
                and sha256(production_path) == sha256(candidate_path)
            )
            all_output_hashes_complete = all_output_hashes_complete and row_complete

        manifest_complete = bool(
            top_level_complete and source_complete and outputs_complete and all_output_hashes_complete
        )
        for output in animations:
            out_path = str(output.get("production_path", "")).replace("\\", "/")
            result[out_path] = {
                "tracked": True,
                "manifest": rel,
                "kind": "jiangzhou_prisoners_exact_web_cleanup_fixed_grid_four_frame_manifest",
                "source_id": str(output.get("variant", "")),
                "provenance_compliant": manifest_complete,
                "reason": "imagegen_web_exact_alpha_cleanup_then_continuous_rect_shared_uniform_scale_transparent_padding_byte_copy"
                if manifest_complete else "source_provenance_or_production_hash_incomplete",
            }

    def yezhulin_remaining_p0_manifest(rel: str) -> None:
        path = ROOT / rel
        if not path.exists():
            return
        data = json.loads(path.read_text(encoding="utf-8"))

        def workspace_path(value: str) -> Path:
            candidate = Path(value)
            if candidate.is_absolute():
                return candidate
            in_project = ROOT / candidate
            return in_project if in_project.exists() else ROOT.parent / candidate

        def hashed_file(path_value: object, hash_value: object) -> bool:
            file_path = workspace_path(str(path_value or ""))
            return bool(
                file_path.is_file()
                and hash_value
                and sha256(file_path).lower() == str(hash_value).lower()
            )

        candidate_manifest = workspace_path(str(data.get("candidate_manifest", "")))
        manual_review = workspace_path(str(data.get("manual_visual_review", "")))
        backup_manifest = workspace_path(str(data.get("backup_manifest", "")))
        source_audit = workspace_path(str(data.get("source_audit", "")))
        web_manifest = workspace_path(str(data.get("web_manifest", "")))
        cleanup_refs = data.get("cleanup_verifications", [])
        cleanup_paths = [workspace_path(str(row.get("path", ""))) for row in cleanup_refs]

        linked_files_complete = all(
            (
                hashed_file(data.get("candidate_manifest"), data.get("candidate_manifest_sha256")),
                hashed_file(data.get("manual_visual_review"), data.get("manual_visual_review_sha256")),
                hashed_file(data.get("backup_manifest"), data.get("backup_manifest_sha256")),
                hashed_file(data.get("source_audit"), data.get("source_audit_sha256")),
                hashed_file(data.get("web_manifest"), data.get("web_manifest_sha256")),
                len(cleanup_refs) == 2,
                all(hashed_file(row.get("path"), row.get("sha256")) for row in cleanup_refs),
            )
        )
        candidate_data = json.loads(candidate_manifest.read_text(encoding="utf-8")) if candidate_manifest.is_file() else {}
        manual_data = json.loads(manual_review.read_text(encoding="utf-8")) if manual_review.is_file() else {}
        backup_data = json.loads(backup_manifest.read_text(encoding="utf-8")) if backup_manifest.is_file() else {}
        cleanup_data = [
            json.loads(cleanup_path.read_text(encoding="utf-8")) if cleanup_path.is_file() else {}
            for cleanup_path in cleanup_paths
        ]
        base_cleanup = next(
            (row for row in cleanup_data if row.get("kind") == "yezhulin_remaining_p0_web_python_pillow_alpha15_exact_verification"),
            {},
        )
        xue_v2_cleanup = next(
            (row for row in cleanup_data if row.get("kind") == "xue_ba_v2_web_python_pillow_alpha15_exact_verification"),
            {},
        )
        web_data = json.loads(web_manifest.read_text(encoding="utf-8")) if web_manifest.is_file() else {}
        cleanup_complete = bool(
            base_cleanup.get("passed") is True
            and base_cleanup.get("alpha_gt_15_mismatch_count") == 0
            and base_cleanup.get("web_cleanup_performed") is True
            and base_cleanup.get("local_pixel_editing_performed") is False
            and base_cleanup.get("steam_modified_or_exported") is False
            and len(base_cleanup.get("files", [])) == 5
            and xue_v2_cleanup.get("passed") is True
            and xue_v2_cleanup.get("alpha_gt_15_byte_mismatch_count") == 0
            and xue_v2_cleanup.get("illegal_alpha_le_15_output_pixel_count") == 0
            and xue_v2_cleanup.get("web_cleanup_performed") is True
            and xue_v2_cleanup.get("local_pixel_editing_performed") is False
            and xue_v2_cleanup.get("steam_modified_or_exported") is False
        )

        top_level_complete = bool(
            data.get("schema_version") == 1
            and data.get("kind") == "yezhulin_remaining_p0_exact_web_cleanup_fixed_grid_production_provenance"
            and data.get("campaign_levels") == [3, 6, 8]
            and len(data.get("novel_context_urls", [])) == 3
            and data.get("web_alpha_cleanup_performed") is True
            and data.get("web_alpha_cleanup_rule") == "alpha<=15 -> RGBA(0,0,0,0); alpha>15 -> byte-identical RGBA"
            and len(data.get("web_cleanup_conversation_urls", [])) == 2
            and data.get("local_alpha_cleanup_performed") is False
            and data.get("fixed_grid_and_continuous_rect_crop") is True
            and data.get("shared_uniform_proportional_scale_per_source") is True
            and data.get("transparent_padding") is True
            and data.get("masking_or_connected_component_isolation_performed") is False
            and data.get("mirroring_or_repainting_performed") is False
            and data.get("escort_walk_frames_per_direction") == 4
            and data.get("animation_file_count") == 28
            and data.get("portrait_file_count") == 5
            and data.get("production_file_count") == 33
            and data.get("steam_modified_or_exported") is False
            and linked_files_complete
            and candidate_data.get("kind") == "yezhulin_remaining_p0_fixed_grid_continuous_rect_candidate"
            and candidate_data.get("production_file_count") == 33
            and candidate_data.get("steam_modified_or_exported") is False
            and manual_data.get("passed") is True
            and manual_data.get("adoption_decision") == "redraw_and_adopt"
            and manual_data.get("candidate_manifest_sha256") == str(data.get("candidate_manifest_sha256", "")).upper()
            and manual_data.get("continuous_rectangle_crop_only") is True
            and manual_data.get("directions_visually_distinct") is True
            and manual_data.get("novel_constraints_visually_met") is True
            and manual_data.get("steam_modified_or_exported") is False
            and backup_data.get("file_count") == 33
            and backup_data.get("steam_modified_or_exported") is False
            and all(row.get("byte_identical") is True for row in backup_data.get("files", []))
            and cleanup_complete
            and web_data.get("all_dimensions_unchanged") is True
            and web_data.get("all_alpha_gt_15_byte_mismatch_count_zero") is True
            and web_data.get("all_actual_changes_only_from_alpha_le_15") is True
            and len(web_data.get("files", [])) == 5
        )

        expected_sources = {
            "lin_chong": ("lin_chong_escort", ["idle"], 5, 2),
            "dong_chao": ("dong_chao_escort", ["idle", "walk_0", "walk_1", "walk_2", "walk_3"], 5, 6),
            "xue_ba": ("xue_ba_escort", ["idle", "walk_0", "walk_1", "walk_2", "walk_3"], 5, 6),
            "shi_qian": ("shi_qian_lantern", ["idle"], 5, 2),
            "shi_xiu": ("bound_shi_xiu", ["idle"], 5, 2),
        }
        verified_cleanup_rows = list(base_cleanup.get("files", []))
        if xue_v2_cleanup:
            verified_cleanup_rows.append(xue_v2_cleanup)
        verified_source_pairs = {
            (
                Path(str(row.get("raw_path", ""))).name,
                str(row.get("raw_sha256", "")).upper(),
                Path(str(row.get("cleaned_path", ""))).name,
                str(row.get("cleaned_sha256", "")).upper(),
            )
            for row in verified_cleanup_rows
        }
        sources = data.get("sources", [])
        source_complete = len(sources) == 5
        for source in sources:
            expected = expected_sources.get(str(source.get("character", "")))
            source_complete = bool(
                source_complete
                and expected
                and source.get("variant") == expected[0]
                and source.get("row_states") == expected[1]
                and len(source.get("fixed_x_boundaries", [])) == expected[2]
                and len(source.get("fixed_y_boundaries", [])) == expected[3]
                and source.get("source_mode") == "RGBA"
                and len(source.get("source_size", [])) == 2
                and float(source.get("shared_uniform_scale", 0.0)) > 0.0
                and source.get("generation_conversation_url")
                and source.get("novel_context_url")
                and source.get("novel_basis")
                and hashed_file(source.get("prompt_path"), source.get("prompt_sha256"))
                and hashed_file(source.get("raw_path"), source.get("raw_sha256"))
                and hashed_file(source.get("cleaned_path"), source.get("cleaned_sha256"))
                and (
                    Path(str(source.get("raw_path", ""))).name,
                    str(source.get("raw_sha256", "")).upper(),
                    Path(str(source.get("cleaned_path", ""))).name,
                    str(source.get("cleaned_sha256", "")).upper(),
                ) in verified_source_pairs
            )

        outputs = data.get("outputs", [])
        animations = [row for row in outputs if row.get("kind") == "animation"]
        portraits = [row for row in outputs if row.get("kind") == "portrait"]
        idle_variants = {
            "lin_chong_escort",
            "dong_chao_escort",
            "xue_ba_escort",
            "shi_qian_lantern",
            "bound_shi_xiu",
        }
        walk_variants = {"dong_chao_escort", "xue_ba_escort"}
        expected_animation_pairs = {
            *((variant, "idle", direction) for variant in idle_variants for direction in DIRECTIONS),
            *((variant, "walk", direction) for variant in walk_variants for direction in DIRECTIONS),
        }
        actual_animation_pairs = {
            (str(row.get("variant", "")), str(row.get("state", "")), str(row.get("direction", "")))
            for row in animations
        }
        outputs_complete = bool(
            len(outputs) == 33
            and len(animations) == 28
            and len(portraits) == 5
            and actual_animation_pairs == expected_animation_pairs
            and {str(row.get("variant", "")) for row in portraits} == idle_variants
            and all(row.get("frame_count") == (4 if row.get("state") == "walk" else 1) for row in animations)
        )
        all_output_hashes_complete = True
        for output in outputs:
            out_path = str(output.get("production_path", "")).replace("\\", "/")
            production_path = ROOT / out_path
            candidate_path = workspace_path(str(output.get("candidate_path", "")))
            row_complete = bool(
                out_path
                and output.get("copy_is_byte_identical_to_candidate") is True
                and production_path.is_file()
                and candidate_path.is_file()
                and sha256(production_path).lower() == str(output.get("production_sha256", "")).lower()
                and sha256(candidate_path).lower() == str(output.get("candidate_sha256", "")).lower()
                and sha256(production_path) == sha256(candidate_path)
            )
            all_output_hashes_complete = all_output_hashes_complete and row_complete

        manifest_complete = bool(
            top_level_complete and source_complete and outputs_complete and all_output_hashes_complete
        )
        for output in animations:
            out_path = str(output.get("production_path", "")).replace("\\", "/")
            result[out_path] = {
                "tracked": True,
                "manifest": rel,
                "kind": "yezhulin_remaining_p0_exact_web_cleanup_fixed_grid_manifest",
                "source_id": str(output.get("variant", "")),
                "provenance_compliant": manifest_complete,
                "reason": "chatgpt_web_generation_exact_alpha_cleanup_then_continuous_rect_shared_uniform_scale_transparent_padding_byte_copy"
                if manifest_complete else "source_provenance_or_production_hash_incomplete",
            }

    ordinary_officials_p0_manifest("assets/campaign/ordinary_officials_p0_direction4_manifest.json")
    daming_lu_rescued_p0_manifest("assets/campaign/daming_lu_rescued_p0_direction4_manifest.json")
    jiangzhou_prisoners_p0_manifest("assets/campaign/jiangzhou_prisoners_p0_direction4_manifest.json")
    yezhulin_remaining_p0_manifest("assets/campaign/yezhulin_remaining_p0_direction4_manifest.json")
    result.update(skirmish_action_provenance_index())
    return result


def expected_paths(profile: dict[str, Any], state: str) -> tuple[list[str], list[str]]:
    variant = profile["variant"]
    role = profile["role_class"]
    if role == "vessel_object":
        return ([f"assets/campaign/objects/{variant}_{state}_{d}.png" for d in DIRECTIONS], [state])
    if variant:
        if variant == "lu_zhishen_rescue" and state == "intercept":
            # CampaignArt explicitly aliases the Wild Boar Forest interception
            # pose to the same-direction, exact attack frame.
            return ([f"assets/campaign/anim/{variant}_attack_{d}.png" for d in DIRECTIONS], ["attack"])
        # CampaignArt maps runtime death to the variant's down file.
        return ([f"assets/campaign/anim/{variant}_{state}_{d}.png" for d in DIRECTIONS], [state])
    lookup = profile.get("down_lookup", "down" if role == "narrative_person" else "death") if state == "down" else state
    return ([f"assets/anim/{profile['key']}_{lookup}_{d}.png" for d in DIRECTIONS], [lookup])


def existing_undirected_references(profile: dict[str, Any], runtime_lookup: list[str]) -> list[dict[str, Any]]:
    """Find art already shown by the codex/runtime before requesting new directions.

    These strips remain references only: one-view animation frames do not satisfy
    the four-direction contract.  Campaign variants may also use the base unit's
    codex strip as an appearance/pose reference, but never as proof that the
    plot-specific costume is already complete.
    """
    candidates: list[tuple[str, str]] = []
    role = profile["role_class"]
    variant = profile["variant"]
    key = profile["key"]
    if role == "vessel_object":
        for lookup in runtime_lookup:
            candidates.append((f"assets/campaign/objects/{variant}_{lookup}.png", "exact_campaign_object"))
    elif variant:
        for lookup in runtime_lookup:
            candidates.append((f"assets/campaign/anim/{variant}_{lookup}.png", "exact_campaign_variant"))
            candidates.append((f"assets/anim/{key}_{lookup}.png", "base_unit_codex_reference"))
    else:
        for lookup in runtime_lookup:
            candidates.append((f"assets/anim/{key}_{lookup}.png", "same_unit_codex_reference"))

    found: list[dict[str, Any]] = []
    seen: set[str] = set()
    for rel_path, scope in candidates:
        if rel_path in seen:
            continue
        seen.add(rel_path)
        path = ROOT / rel_path
        if not path.exists():
            continue
        dims = png_dimensions(path)
        found.append({
            "path": rel_path,
            "scope": scope,
            "sha256": sha256(path),
            "png_dimensions": list(dims) if dims else None,
            "reuse_policy": "web_reference_or_allowed_rectangular_source_crop_only; never counts as a missing true direction",
        })
    return found


def line_evidence(script_rel: str, key: str, variant: str) -> list[dict[str, Any]]:
    lines = (ROOT / script_rel).read_text(encoding="utf-8").splitlines()
    terms = [term for term in (variant, key) if term]
    found: list[dict[str, Any]] = []
    for number, line in enumerate(lines, 1):
        if any(term in line for term in terms):
            found.append({"line": number, "text": line.strip()})
    return found[:8]


def fallback_diagnosis(profile: dict[str, Any], state: str) -> dict[str, Any]:
    key = profile["key"]
    variant = profile["variant"]
    role = profile["role_class"]
    if role == "vessel_object":
        legacy = ROOT / f"assets/campaign/objects/{variant}_{state}.png"
        return {"kind": "legacy_directionless_object" if legacy.exists() else "none", "path": str(legacy.relative_to(ROOT)).replace("\\", "/") if legacy.exists() else ""}
    if variant:
        if variant == "lu_zhishen_rescue" and state == "intercept":
            return {"kind": "explicit_campaign_state_alias", "path": "scripts/campaign_art.gd:ANIMATION_STATE_ALIASES"}
        idle = [ROOT / f"assets/campaign/anim/{variant}_idle_{d}.png" for d in DIRECTIONS]
        art_text = (ROOT / "scripts/campaign_art.gd").read_text(encoding="utf-8")
        programmatic = f'"{variant}": "{key}"' in art_text
        if programmatic:
            return {"kind": "programmatic_base_plus_rope_overlay", "path": "scripts/campaign_art.gd:PROGRAMMATIC_BOUND_VARIANTS"}
        if state != "idle" and all(p.exists() for p in idle):
            return {"kind": "campaign_variant_idle_fallback", "path": "four directional idle files"}
        return {"kind": "campaign_portrait_or_generic_unit_fallback", "path": f"assets/campaign/portraits/{variant}.png"}
    lookup = profile.get("down_lookup", "down" if role == "narrative_person" else "death") if state == "down" else state
    legacy = ROOT / f"assets/anim/{key}_{lookup}.png"
    directional_idle = [ROOT / f"assets/anim/{key}_idle_{d}.png" for d in DIRECTIONS]
    if legacy.exists():
        return {"kind": "ordinary_full_mode_legacy_single_view", "path": str(legacy.relative_to(ROOT)).replace("\\", "/")}
    if state not in ("idle", "down") and all(p.exists() for p in directional_idle):
        return {"kind": "ordinary_full_mode_directional_idle_fallback", "path": "four directional idle files"}
    if state == "down":
        return {"kind": "programmatic_down_or_death_pose", "path": "scripts/unit.gd:_draw"}
    return {"kind": "static_unit_sheet_or_missing", "path": ""}


def route_status(profile: dict[str, Any], state: str) -> str:
    if profile["role_class"] == "vessel_object":
        return "campaign_object_direction_path"
    if profile["variant"]:
        if profile["variant"] == "lu_zhishen_rescue" and state == "intercept":
            return "campaign_variant_explicit_same_direction_attack_alias"
        text = (ROOT / "scripts/campaign_art.gd").read_text(encoding="utf-8")
        if f'"{profile["variant"]}": "{profile["key"]}"' in text:
            return "programmatic_overlay_route_requires_future_exact_variant_registration"
        return "campaign_variant_animation_path" if f'"{profile["variant"]}"' in text else "variant_not_registered"
    return "generic_directional_animation_path"


def build_report() -> dict[str, Any]:
    provenance = provenance_index()
    per_level: list[dict[str, Any]] = []
    flat: list[dict[str, Any]] = []
    input_hashes: dict[str, str] = {}

    for rel in ["scripts/campaign.gd", "scripts/campaign_art.gd", "scripts/art_db.gd", "scripts/unit.gd", "assets/direction4/manifest.json", "assets/direction4/campaign_object_manifest.json", SKIRMISH_ACTION_MANIFEST_REL, "assets/campaign/web_art_manifest.json", "assets/campaign/lu_zhishen_rescue_direction4_manifest.json", "assets/campaign/wu_song_mengzhou_direction4_manifest.json", "assets/campaign/jiang_menshen_fists_direction4_manifest.json", "assets/campaign/lin_chong_p0_direction4_manifest.json", "assets/campaign/li_kui_jiangzhou_direction4_manifest.json", "assets/campaign/gao_flagship_direction4_manifest.json", "assets/campaign/gao_qiu_captured_direction4_manifest.json", "assets/campaign/huangnigang_p0_direction4_manifest.json", "assets/direction4/lianhuanma_p0_direction4_manifest.json", "assets/campaign/daming_prisoners_rect_rebuild_direction4_manifest.json", "assets/campaign/ordinary_officials_p0_direction4_manifest.json", "assets/campaign/daming_lu_rescued_p0_direction4_manifest.json", "assets/campaign/jiangzhou_prisoners_p0_direction4_manifest.json", "assets/campaign/yezhulin_remaining_p0_direction4_manifest.json"]:
        path = ROOT / rel
        if path.exists():
            input_hashes[rel] = sha256(path)

    for level_id in STORY_ORDER:
        spec = LEVEL_SPECS[level_id]
        script_rel = spec["script"]
        script_path = ROOT / script_rel
        input_hashes[script_rel] = sha256(script_path)
        level_rows: list[dict[str, Any]] = []
        for profile in spec["profiles"]:
            for state in profile["states"]:
                paths, runtime_lookup = expected_paths(profile, state)
                direction_records: list[dict[str, Any]] = []
                for direction, rel_path in zip(DIRECTIONS, paths):
                    file_path = ROOT / rel_path
                    dims = png_dimensions(file_path) if file_path.exists() else None
                    provenance_record = provenance.get(rel_path, {
                        "tracked": False,
                        "manifest": "",
                        "kind": "untracked",
                        "source_id": "",
                        "provenance_compliant": False,
                        "reason": "no_current_web_source_manifest_record",
                    })
                    direction_records.append({
                        "direction": direction,
                        "path": rel_path,
                        "exists": file_path.exists(),
                        "sha256": sha256(file_path) if file_path.exists() else "",
                        "png_dimensions": list(dims) if dims else None,
                        "valid_strip_geometry": bool(dims and dims[1] > 0 and dims[0] % dims[1] == 0),
                        **provenance_record,
                    })
                files_exact = all(item["exists"] and item["valid_strip_geometry"] for item in direction_records)
                provenance_compliant = all(item["provenance_compliant"] for item in direction_records)
                accepted = bool(files_exact and provenance_compliant)
                if accepted:
                    status = "exact_provenance_compliant"
                elif files_exact:
                    status = "exact_files_noncompliant_provenance"
                else:
                    status = "missing_exact_direction_files"
                row = {
                    "level_id": level_id,
                    "level_title": spec["title"],
                    "script": script_rel,
                    "key": profile["key"],
                    "variant": profile["variant"],
                    "art_identity": profile["variant"] or profile["key"],
                    "role_class": profile["role_class"],
                    "lifecycle": profile.get("lifecycle", "combat"),
                    "design_state": state,
                    "runtime_lookup_states": runtime_lookup,
                    "directions": direction_records,
                    "exact_files_four_direction": files_exact,
                    "provenance_compliant": provenance_compliant,
                    "accepted_exact_four_direction": accepted,
                    "coverage_status": status,
                    "existing_undirected_references": existing_undirected_references(profile, runtime_lookup),
                    "fallback_diagnosis": fallback_diagnosis(profile, state),
                    "route_status": route_status(profile, state),
                    "source_evidence": line_evidence(script_rel, profile["key"], profile["variant"]),
                    "not_required_states": [s for s in COMBAT_STATES if s not in profile["states"]] if profile["role_class"] == "narrative_person" else [],
                    "not_required_fallback_policy": "idle fallback is allowed only for these non-required narrative states; it never satisfies a listed required state" if profile["role_class"] == "narrative_person" else "",
                }
                level_rows.append(row)
                flat.append(row)
        counts = Counter(row["coverage_status"] for row in level_rows)
        per_level.append({
            "level_id": level_id,
            "title": spec["title"],
            "script": script_rel,
            "required_state_rows": len(level_rows),
            "accepted_state_rows": sum(row["accepted_exact_four_direction"] for row in level_rows),
            "coverage_percent": round(100.0 * sum(row["accepted_exact_four_direction"] for row in level_rows) / max(1, len(level_rows)), 3),
            "status_counts": dict(sorted(counts.items())),
            "excluded_non_person_props": spec["excluded_non_person_props"],
            "requirements": level_rows,
        })

    # Deduplicate repeated identities shared by several levels.  A unique row is
    # accepted only if every deployment reference agrees on the direct files.
    unique_map: dict[tuple[str, str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in flat:
        domain = "vessel" if row["role_class"] == "vessel_object" else "person"
        unique_map[(domain, row["art_identity"], row["design_state"])].append(row)
    unique_rows: list[dict[str, Any]] = []
    for (domain, identity, state), rows in sorted(unique_map.items()):
        representative = rows[0]
        unique_rows.append({
            "domain": domain,
            "art_identity": identity,
            "design_state": state,
            "key_variant_pairs": sorted({f"{row['key']}|{row['variant']}" for row in rows}),
            "levels": [level_id for level_id in STORY_ORDER if any(row["level_id"] == level_id for row in rows)],
            "accepted_exact_four_direction": all(row["accepted_exact_four_direction"] for row in rows),
            "coverage_status": representative["coverage_status"],
            "expected_paths": [item["path"] for item in representative["directions"]],
            "existing_reference_paths": [item["path"] for item in representative["directions"] if item["exists"]],
            "existing_undirected_references": representative["existing_undirected_references"],
            "provenance_compliant": representative["provenance_compliant"],
            "route_status": representative["route_status"],
        })

    # Existing true-direction files enter a review queue first.  Missing rows
    # alone enter the web-generation pack; this avoids redrawing finished art
    # merely because an older source record needs review.
    missing = [row for row in unique_rows if row["coverage_status"] == "missing_exact_direction_files"]
    exact_review = [row for row in unique_rows if row["coverage_status"] == "exact_files_noncompliant_provenance"]
    missing_with_reference = [row for row in missing if row["existing_undirected_references"]]
    missing_from_scratch = [row for row in missing if not row["existing_undirected_references"]]
    for row in unique_rows:
        if row["coverage_status"] == "exact_provenance_compliant":
            row["art_work_status"] = "complete_exact"
        elif row["coverage_status"] == "exact_files_noncompliant_provenance":
            row["art_work_status"] = "existing_exact_visual_and_source_review_first"
        elif row["existing_undirected_references"]:
            row["art_work_status"] = "four_direction_upgrade_from_existing_codex_reference"
        else:
            row["art_work_status"] = "new_state_from_scratch"
    first_identities = set(FIRST_SAMPLE)
    sample_rows = [row for row in missing if (row["domain"], row["art_identity"]) in first_identities]
    # Exactly five design states for each of the first eight sample identities.
    state_rank = {state: i for i, state in enumerate(COMBAT_STATES)}
    sample_rows.sort(key=lambda row: (state_rank.get(row["design_state"], 99), FIRST_SAMPLE.index((row["domain"], row["art_identity"]))))
    sample_atlases: list[dict[str, Any]] = []
    for state in COMBAT_STATES:
        heroes = [row for row in sample_rows if row["design_state"] == state and row["art_identity"] in ("lin_chong", "lu_zhishen", "wu_song", "li_kui")]
        units = [row for row in sample_rows if row["design_state"] == state and row["art_identity"] in ("liang_dao", "guan_dao", "gou_lian", "lian_huan_ma")]
        for label, rows in (("heroes", heroes), ("troops", units)):
            if rows:
                sample_atlases.append({
                    "atlas_id": f"sample_{label}_{state}",
                    "phase": "first_eight_sample",
                    "layout": "4_rows_x_4_directions",
                    "rows": [{"art_identity": row["art_identity"], "state": state, "domain": row["domain"]} for row in rows],
                    "directions": list(DIRECTIONS),
                    "production_prompt": None,
                    "prompt_review_required": True,
                })

    sample_keys = {(row["domain"], row["art_identity"], row["design_state"]) for row in sample_rows}
    remainder = [row for row in missing if (row["domain"], row["art_identity"], row["design_state"]) not in sample_keys]
    remainder.sort(key=lambda row: (row["domain"], state_rank.get(row["design_state"], 50), row["design_state"], row["art_identity"]))
    remainder_atlases: list[dict[str, Any]] = []
    for index in range(0, len(remainder), 4):
        chunk = remainder[index:index + 4]
        remainder_atlases.append({
            "atlas_id": f"remaining_{index // 4 + 1:03d}",
            "phase": "remaining_campaign_coverage",
            "layout": "up_to_4_rows_x_4_directions",
            "rows": [{"art_identity": row["art_identity"], "state": row["design_state"], "domain": row["domain"], "levels": row["levels"]} for row in chunk],
            "directions": list(DIRECTIONS),
            "production_prompt": None,
            "prompt_review_required": True,
        })

    status_counts = Counter(row["coverage_status"] for row in unique_rows)
    exact_file_rows = sum(row["coverage_status"] in ("exact_provenance_compliant", "exact_files_noncompliant_provenance") for row in unique_rows)
    noncompliant_regeneration = len(exact_review)
    accepted_rows = sum(row["accepted_exact_four_direction"] for row in unique_rows)
    report = {
        "schema_version": 1,
        "audit_kind": "static_read_only_campaign_direction4_exact_coverage",
        "root": str(ROOT),
        "rules": {
            "directions": list(DIRECTIONS),
            "combat_design_states": list(COMBAT_STATES),
            "fallback_never_counts_as_exact": True,
            "component_masking_or_zeroing_foreign_pixels_is_provenance_noncompliant": True,
            "accepted_local_operations": ["rectangular_crop", "uniform_scale", "transparent_padding"],
            "ordinary_down_runtime_note": "Design state down maps to the current runtime lookup shown per row: death for lethal combat, down for non-lethal story outcomes; campaign variants map death to down internally.",
            "generic_hurt_runtime_note": "Current unit.gd resolves exact four-direction hurt frames for both campaign variants and generic units, with legacy fallback retained by ArtDb.",
        },
        "story_order": list(STORY_ORDER),
        "input_sha256": dict(sorted(input_hashes.items())),
        "summary": {
            "per_level_requirement_rows": len(flat),
            "unique_art_state_rows": len(unique_rows),
            "accepted_exact_unique_rows": accepted_rows,
            "exact_file_unique_rows_before_provenance_filter": exact_file_rows,
            "coverage_percent_unique_rows": round(100.0 * accepted_rows / max(1, len(unique_rows)), 3),
            "existing_four_direction_rows_requiring_web_regeneration_for_provenance": noncompliant_regeneration,
            "existing_four_direction_rows_visual_review_first": len(exact_review),
            "missing_or_partial_exact_rows_requiring_web_generation": sum(row["coverage_status"] == "missing_exact_direction_files" for row in unique_rows),
            "missing_rows_with_existing_codex_animation_reference": len(missing_with_reference),
            "missing_rows_without_same_state_art_reference": len(missing_from_scratch),
            "status_counts": dict(sorted(status_counts.items())),
            "minimum_web_source_atlases_at_four_rows_each": math.ceil(len(missing) / 4),
            "first_eight_sample_atlases": len(sample_atlases),
            "remaining_atlases": len(remainder_atlases),
        },
        "levels": per_level,
        "unique_art_state_contract": unique_rows,
        "web_generation_batches": {
            "assumption": "Existing exact four-direction files are reviewed before redraw. Missing rows reuse matching codex animations as web references where available. One reviewed web source atlas may contain up to four complete source rows and four true directions. Local processing retains every source-cell RGBA pixel; no component deletion, mirroring, repainting, or direction synthesis.",
            "existing_exact_review_queue": exact_review,
            "first_eight_sample_identities": [{"domain": domain, "art_identity": identity} for domain, identity in FIRST_SAMPLE],
            "first_eight_sample": sample_atlases,
            "remaining_minimum_pack": remainder_atlases,
        },
    }
    canonical = json.dumps(report, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    report["deterministic_payload_sha256"] = hashlib.sha256(canonical).hexdigest()
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="qa/campaign_direction4_coverage_20260902/report.json")
    parser.add_argument("--check", action="store_true", help="fail if required source evidence is absent")
    args = parser.parse_args()
    report = build_report()
    if args.check:
        missing_evidence = [
            (row["level_id"], row["key"], row["variant"], row["design_state"])
            for level in report["levels"] for row in level["requirements"] if not row["source_evidence"]
        ]
        if missing_evidence:
            print(json.dumps({"error": "missing_source_evidence", "rows": missing_evidence}, ensure_ascii=False, indent=2))
            return 2
    output = ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(output), **report["summary"], "deterministic_payload_sha256": report["deterministic_payload_sha256"]}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
