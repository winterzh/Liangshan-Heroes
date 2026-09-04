"""Validate reviewed Web ChatGPT atlases under two non-masking source rules.

The batch contract is ``../implementation_20260902/prompt_drafts_v2/``.  This
The production-capable rule delegates all image slicing to
``direction4_web_state_slice.py --layout grid`` and keeps the existing exact
transparent-seam contract unchanged.  ``--fixed-candidate-manifest`` validates
the parallel ``fixed_cell_rect_v1`` rule: 16 explicit source rectangles,
whole-unit uniform scaling and transparent padding.  That path is candidate
only and can never commit production files.

``--record-attempts`` creates immutable per-source-SHA QA sidecars and never
touches production art.  The ordinary command is a dry run: it requires those
sidecars, validates every declared source, asks the grid slicer for the exact
output plan, and reports production collisions.  ``--commit`` is all-or-nothing.  It requires ten adopted sources,
creates a SHA-256 checkpoint, stages every output, performs per-file atomic
replacement, and rolls production back if the post-write coverage audit does
not recognize all 40 identity/state rows.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BATCH_MANIFEST = (
    ROOT.parent / "implementation_20260902" / "prompt_drafts_v2" / "batch_manifest.json"
)
DEFAULT_ATTEMPT_LEDGER_ROOT = (
    DEFAULT_BATCH_MANIFEST.parent.parent / "web_sample_sources_20260902"
)
FROZEN_REGISTRY = ROOT / "tools/direction4_first_sample_frozen_registry.json"
FROZEN_REGISTRY_SHA256 = "e2b37a4062d275b5a7b7b4084cf61491d4b179a611372bc5f3cdcd0ab4761bb2"
DEFAULT_PRODUCTION_MANIFEST = ROOT / "assets/direction4/manifest.json"
DEFAULT_OUTPUT_DIR = ROOT / "assets/anim"
DEFAULT_SOURCE_ARCHIVE = ROOT / "assets/direction4/source/web_first_sample_20260902"
DEFAULT_PROMPT_ARCHIVE = ROOT / "assets/direction4/web_prompts_20260902"
DEFAULT_REFERENCE_ARCHIVE = ROOT / "assets/direction4/references/web_first_sample_20260902"
DEFAULT_CHECKPOINT_ROOT = ROOT / "qa/direction4_first_sample_intake/checkpoints"
DEFAULT_LOCK = ROOT / "assets/direction4/.first_sample_intake.lock"
SLICER = ROOT / "tools/direction4_web_state_slice.py"
FIXED_RECT_NORMALIZER = ROOT / "tools/direction4_fixed_crop_normalize.py"
COVERAGE_AUDIT = ROOT / "tools/campaign_direction4_coverage_audit.py"

DIRECTIONS = ("se", "sw", "ne", "nw")
STATES = ("idle", "walk", "attack", "hurt", "down")
GROUP_ROWS = {
    "heroes": ("lin_chong", "lu_zhishen", "wu_song", "li_kui"),
    "troops": ("liang_dao", "guan_dao", "gou_lian", "lian_huan_ma"),
}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
REQUIRED_REVIEW_FLAGS = (
    "rows_and_identities_confirmed",
    "directions_se_sw_ne_nw_confirmed",
    "not_mirrored_confirmed",
    "equipment_and_action_confirmed",
    "visual_true_transparency_confirmed",
    "no_ground_or_baked_shadow_confirmed",
    "no_text_or_watermark_confirmed",
    "no_cross_cell_content_confirmed",
    "anchor_measurements_confirmed",
    "state_identity_consistent_confirmed",
    "required_references_confirmed",
)
GENERIC_REASONS = {
    "ok", "pass", "passed", "adopt", "adopted", "reject", "rejected",
    "通过", "采用", "淘汰", "全部通过", "检查通过", "符合要求",
}
ANCHOR_FRACTION = 0.82
ANCHOR_TOLERANCE_PX = 3
CANONICAL_SIDECAR_FIELD = "attempts"
CANONICAL_ATTEMPT_ROOT_FIELDS = ("downloads", "accepted", "rejected")
CANONICAL_LEDGER_RELATIVE = "implementation_20260902/web_sample_sources_20260902"
PROMPT_REQUIRED_TERMS = (
    "4 行×4 列",
    "SE",
    "SW",
    "NE",
    "NW",
    "镜像",
    "真透明",
    "82%",
    "正负 3 像素以内",
    "24 像素",
    "阴影",
    "水印",
)
STATE_PROMPT_TERM = {
    "idle": "待机",
    "walk": "行走",
    "attack": "攻击",
    "hurt": "受伤",
    "down": "倒地",
}
PROMPT_IDENTITY_TERMS = {
    "heroes": ("林冲", "鲁智深", "武松", "李逵"),
    "troops": ("梁山朴刀手", "官军刀盾兵", "梁山钩镰枪手", "呼延灼连环甲马"),
}
SOURCE_RULE_TRANSPARENT_GRID = "transparent_grid_v1"
SOURCE_RULE_FIXED_CELL_RECT = "fixed_cell_rect_v1"
SOURCE_RULE_FIXED_DIRECTION_ROW_RECT = "fixed_direction_row_rect_v1"
SUPPORTED_SOURCE_RULES = (SOURCE_RULE_TRANSPARENT_GRID, SOURCE_RULE_FIXED_CELL_RECT)
FIXED_CANDIDATE_ATLAS_IDS = (
    "sample_heroes_idle",
    "sample_troops_idle",
    "sample_heroes_walk",
    "sample_troops_walk",
    "sample_heroes_attack",
    "sample_troops_attack",
    "sample_heroes_hurt",
    "sample_troops_hurt",
    "sample_heroes_down",
    "sample_troops_down",
)
FIXED_BLOCKED_ATTEMPT_IDS = (
    "sample_heroes_attack_attempt1",
    "sample_heroes_attack_attempt2",
    "sample_heroes_hurt_attempt1",
    "sample_troops_hurt_attempt1",
)
FIXED_BLOCKED_GEOMETRY_CELLS = {
    "sample_heroes_attack_attempt2": ((2, 0, "wu_song", "se"), (3, 0, "li_kui", "se")),
    "sample_heroes_hurt_attempt1": ((0, 0, "lin_chong", "se"), (0, 1, "lin_chong", "sw")),
    "sample_troops_hurt_attempt1": ((2, 2, "gou_lian", "ne"), (3, 2, "lian_huan_ma", "ne")),
}
FIXED_ROW_REPLACEMENT_IDS = ("sample_wu_song_attack_double_blades",)
FIXED_ROW_REPLACEMENT_TARGET = {
    "atlas_id": "sample_heroes_attack",
    "unit": "wu_song",
    "state": "attack",
    "directions": list(DIRECTIONS),
}
FIXED_ROW_REPLACEMENT_CAMPAIGN_SCOPE = {
    "generic_unit": "wu_song",
    "allowed_use": "late_traveller_generic_only",
    "excluded_variants": ["wu_song_mengzhou"],
}
FIXED_CANDIDATE_REVIEW_FLAGS = (
    "rows_and_identities_confirmed",
    "directions_se_sw_ne_nw_confirmed",
    "not_mirrored_confirmed",
    "complete_body_and_weapon_confirmed",
    "no_cross_cell_content_confirmed",
    "equipment_and_action_confirmed",
    "state_identity_consistent_confirmed",
    "historical_equipment_and_original_text_approved",
    "fringe_review_completed",
)
FRINGE_POLICY = {
    "low_alpha_max": 64,
    "high_chroma_min": 48,
    "review_count_per_frame": 64,
    "review_ratio_of_semitransparent": 0.08,
    "threshold_result": "manual_visual_review_required_only",
    "automatic_pixel_clearing": False,
    "automatic_adoption": False,
}
FIXED_CAMPAIGN_VARIANT_SCOPE_GATE = {
    "whole_hero_atlas_production_adoption_allowed": False,
    "row_variant_exclusions": {
        "wu_song": ["wu_song_mengzhou"],
        "lin_chong": ["lin_chong_bound", "lin_chong_prisoner", "lin_chong_escort"],
    },
    "reason": (
        "本批武松为后期行者装并佩双戒刀，不能覆盖醉打蒋门神时期的 wu_song_mengzhou；"
        "本批武装林冲也不能覆盖野猪林的被缚、带枷或搀扶剧情变体。"
    ),
}
FIXED_RUNTIME_MAPPING_GATE = {
    "production_blocking": True,
    "issues": [
        {
            "candidate_atlases": ["sample_heroes_down", "sample_troops_down"],
            "candidate_runtime_state": "death",
            "candidate_filename_pattern": "*_death_{direction}.png",
            "runtime_state_without_candidate": "down",
            "reason": "通用方向素材按原状态名直查，down 与 death 不互转；当前 death 命名不能满足 down 查询。",
        },
        {
            "candidate_atlases": ["sample_heroes_hurt", "sample_troops_hurt"],
            "candidate_runtime_state": "hurt",
            "runtime_selector_status": "generic_unit_hurt_not_requested",
            "reason": "Unit 当前只在 art_variant 非空时进入受伤方向帧分支，通用单位不会选择这批 hurt 候选。",
        },
    ],
}


class IntakeError(RuntimeError):
    pass


@dataclass(frozen=True)
class Batch:
    send_order: int
    atlas_id: str
    filename: str
    prompt_path: Path
    prompt_sha256: str
    group: str
    design_state: str
    runtime_state: str
    rows: tuple[str, ...]
    anchor_kind: str
    local_references: tuple[dict[str, Any], ...]
    idle_reference_atlas: str


@dataclass(frozen=True)
class SourceEntry:
    attempt_id: str
    atlas_id: str
    source_path: Path
    source_sha256: str
    size: tuple[int, int]
    conversation_url: str
    prompt_sha256: str
    group: str
    design_state: str
    directions: tuple[str, ...]
    rows: tuple[str, ...]
    decision: str
    reason: str
    human_review: dict[str, Any]
    anchor_measurements: tuple[dict[str, Any], ...]
    reference_idle_sha256: str
    attached_reference_sha256s: tuple[str, ...]


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError:
        return str(path.resolve())


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise IntakeError(f"{label} does not exist: {path}") from error
    except json.JSONDecodeError as error:
        raise IntakeError(f"{label} is invalid JSON: {path}: {error}") from error
    if not isinstance(value, dict):
        raise IntakeError(f"{label} must contain one JSON object: {path}")
    return value


def canonical_value_sha256(value: Any) -> str:
    return sha256_bytes(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8"))


def load_frozen_registry() -> dict[str, Any]:
    registry = load_json(FROZEN_REGISTRY, "frozen first-sample registry")
    actual_sha = sha256_file(FROZEN_REGISTRY)
    if actual_sha != FROZEN_REGISTRY_SHA256:
        raise IntakeError(
            "frozen first-sample registry SHA mismatch; a reviewed code/registry update is required "
            f"(expected {FROZEN_REGISTRY_SHA256}, actual {actual_sha})"
        )
    if (
        registry.get("schema_version") != 1
        or registry.get("kind") != "direction4_first_sample_frozen_registry"
        or not isinstance(registry.get("canonical_batch_manifest"), dict)
        or not isinstance(registry.get("audit_source"), dict)
        or not isinstance(registry.get("batches"), dict)
    ):
        raise IntakeError("frozen first-sample registry has an unsupported schema")
    return registry


def expect_sha(value: Any, label: str) -> str:
    text = str(value).lower()
    if not SHA256_RE.fullmatch(text):
        raise IntakeError(f"{label} must be a lowercase SHA-256 hex digest")
    return text


def stable_conversation_url(value: Any, label: str) -> str:
    text = str(value).strip()
    parsed = urlsplit(text)
    parts = [part for part in parsed.path.split("/") if part]
    if (
        parsed.scheme != "https"
        or parsed.netloc.lower() != "chatgpt.com"
        or len(parts) != 2
        or parts[0] != "c"
        or re.fullmatch(r"[0-9A-Za-z-]{20,}", parts[1]) is None
        or parsed.query
        or parsed.fragment
        or parsed.username
        or parsed.password
        or parsed.port is not None
    ):
        raise IntakeError(
            f"{label} must be a stable https://chatgpt.com/c/... URL without query or fragment"
        )
    return text


def parse_string_tuple(value: Any, length: int, label: str) -> tuple[str, ...]:
    if not isinstance(value, list) or len(value) != length or not all(isinstance(item, str) for item in value):
        raise IntakeError(f"{label} must contain exactly {length} strings")
    return tuple(value)


def load_batches(path: Path, require_frozen: bool = True) -> tuple[dict[str, Any], list[Batch]]:
    registry = load_frozen_registry()
    frozen_manifest = registry["canonical_batch_manifest"]
    canonical_manifest_path = (ROOT.parent / str(frozen_manifest.get("path", ""))).resolve()
    frozen_manifest_sha = expect_sha(
        frozen_manifest.get("sha256"), "frozen_registry.canonical_batch_manifest.sha256"
    )
    if require_frozen and (
        path.resolve() != canonical_manifest_path
        or not path.is_file()
        or sha256_file(path) != frozen_manifest_sha
    ):
        raise IntakeError(
            "commit/record requires the exact frozen prompt-pack manifest path and SHA; "
            "use --allow-unfrozen-batch-dry-run only for explicit development validation"
        )
    data = load_json(path, "batch manifest")
    raw_batches = data.get("batches")
    if (
        data.get("schema_version") != 2
        or data.get("kind") != "web_chatgpt_direction4_first_eight_identity_sample_prompt_pack_v2"
        or not isinstance(raw_batches, list)
        or len(raw_batches) != 10
    ):
        raise IntakeError("batch manifest must use the reviewed schema 2 prompt pack with exactly ten batches")
    scope = data.get("scope")
    if not isinstance(scope, dict):
        raise IntakeError("batch manifest scope is missing")
    anchor_contract = scope.get("anchor_contract")
    if not isinstance(anchor_contract, dict) or (
        anchor_contract.get("target_fraction") != ANCHOR_FRACTION
        or anchor_contract.get("tolerance_pixels") != ANCHOR_TOLERANCE_PX
        or anchor_contract.get("measure_every_cell") is not True
        or anchor_contract.get("alpha_bbox_bottom_is_reference_only") is not True
    ):
        raise IntakeError("batch manifest does not contain the hard 82 percent plus-or-minus 3px anchor contract")
    if tuple(scope.get("required_human_review_flags", [])) != REQUIRED_REVIEW_FLAGS:
        raise IntakeError("batch manifest human-review flags differ from the reviewed contract")
    attempt_contract = scope.get("attempt_provenance_contract")
    if not isinstance(attempt_contract, dict) or (
        attempt_contract.get("all_attempts_listed") is not True
        or attempt_contract.get("append_only_sha_sidecar_required") is not True
        or attempt_contract.get("all_later_state_attempts_bind_adopted_idle_source_sha256") is not True
        or attempt_contract.get("fixed_ledger_root") != CANONICAL_LEDGER_RELATIVE
        or attempt_contract.get("fixed_sidecar_dir") != f"{CANONICAL_LEDGER_RELATIVE}/{CANONICAL_SIDECAR_FIELD}"
        or tuple(attempt_contract.get("fixed_attempt_roots", []))
        != tuple(f"{CANONICAL_LEDGER_RELATIVE}/{name}" for name in CANONICAL_ATTEMPT_ROOT_FIELDS)
        or attempt_contract.get("source_manifest_may_override_ledger_paths") is not False
    ):
        raise IntakeError("batch manifest does not contain the fixed append-only attempt ledger contract")
    audit_source = data.get("audit_source")
    frozen_audit = registry["audit_source"]
    if not isinstance(audit_source, dict) or (
        audit_source.get("path") != frozen_audit.get("path")
        or audit_source.get("sha256") != frozen_audit.get("sha256")
    ):
        raise IntakeError("batch manifest audit_source path/SHA differs from the frozen registry")
    audit_path = (ROOT.parent / str(frozen_audit.get("path", ""))).resolve()
    audit_sha = expect_sha(frozen_audit.get("sha256"), "frozen_registry.audit_source.sha256")
    if not audit_path.is_file() or sha256_file(audit_path) != audit_sha:
        raise IntakeError("frozen campaign audit source is missing or its SHA has drifted")

    batches: list[Batch] = []
    seen: set[str] = set()
    frozen_batches = registry["batches"]
    for expected_order, raw in enumerate(raw_batches, 1):
        if not isinstance(raw, dict):
            raise IntakeError(f"batch {expected_order} must be an object")
        atlas_id = str(raw.get("atlas_id", ""))
        group = str(raw.get("group", ""))
        state = str(raw.get("state", ""))
        filename = str(raw.get("filename", ""))
        frozen_batch = frozen_batches.get(atlas_id)
        if not isinstance(frozen_batch, dict) or frozen_batch.get("filename") != filename:
            raise IntakeError(f"{atlas_id}: filename differs from the frozen batch registry")
        if raw.get("send_order") != expected_order:
            raise IntakeError(f"{atlas_id or expected_order}: send_order must be {expected_order}")
        if atlas_id != f"sample_{group}_{state}" or atlas_id in seen:
            raise IntakeError(f"invalid or repeated atlas_id: {atlas_id}")
        if group not in GROUP_ROWS or state not in STATES:
            raise IntakeError(f"{atlas_id}: unsupported group/state")
        if raw.get("layout") != "4_rows_x_4_columns":
            raise IntakeError(f"{atlas_id}: layout must be 4_rows_x_4_columns")
        if tuple(raw.get("directions", [])) != DIRECTIONS:
            raise IntakeError(f"{atlas_id}: direction columns must be se,sw,ne,nw")
        raw_rows = raw.get("rows", [])
        rows = tuple(str(item.get("art_identity", "")) for item in raw_rows if isinstance(item, dict))
        if rows != GROUP_ROWS[group]:
            raise IntakeError(f"{atlas_id}: row identities do not match the approved {group} order")
        prompt_path = path.parent / filename
        declared_prompt_sha = expect_sha(raw.get("prompt_sha256"), f"{atlas_id}.prompt_sha256")
        frozen_prompt_sha = expect_sha(
            frozen_batch.get("prompt_sha256"), f"frozen_registry.{atlas_id}.prompt_sha256"
        )
        if require_frozen and declared_prompt_sha != frozen_prompt_sha:
            raise IntakeError(f"{atlas_id}: prompt SHA differs from the frozen reviewed pack")
        if not prompt_path.is_file():
            raise IntakeError(f"{atlas_id}: prompt file is missing: {prompt_path}")
        actual_prompt_sha = sha256_file(prompt_path)
        if actual_prompt_sha != declared_prompt_sha:
            raise IntakeError(
                f"{atlas_id}: prompt SHA mismatch; declared {declared_prompt_sha}, actual {actual_prompt_sha}"
            )
        prompt_text = prompt_path.read_text(encoding="utf-8").strip()
        missing_prompt_terms = [term for term in PROMPT_REQUIRED_TERMS if term not in prompt_text]
        state_term = STATE_PROMPT_TERM.get(state, "")
        if (
            len(prompt_text) < 500
            or missing_prompt_terms
            or state_term not in prompt_text
            or any(identity not in prompt_text for identity in PROMPT_IDENTITY_TERMS[group])
        ):
            raise IntakeError(
                f"{atlas_id}: prompt is empty/truncated or lacks required 4x4, direction, alpha, anchor, "
                f"state, identity, seam, shadow, mirror, or watermark terms; missing={missing_prompt_terms}"
            )
        acceptance_checks = raw.get("acceptance_checks")
        if (
            not isinstance(acceptance_checks, list)
            or len(acceptance_checks) < 10
            or not all(isinstance(item, str) and item.strip() for item in acceptance_checks)
            or len(set(acceptance_checks)) != len(acceptance_checks)
        ):
            raise IntakeError(f"{atlas_id}: acceptance_checks must contain the complete nonempty reviewed set")
        expected_checks_sha = expect_sha(
            frozen_batch.get("acceptance_checks_sha256"),
            f"frozen_registry.{atlas_id}.acceptance_checks_sha256",
        )
        if canonical_value_sha256(acceptance_checks) != expected_checks_sha:
            raise IntakeError(f"{atlas_id}: acceptance_checks differ from the frozen reviewed set")
        anchor = raw.get("anchor_measurement")
        expected_anchor_kind = "lowest_contact" if state == "down" else "foot_or_hoof"
        if not isinstance(anchor, dict) or (
            anchor.get("kind") != expected_anchor_kind
            or anchor.get("target_fraction") != ANCHOR_FRACTION
            or anchor.get("tolerance_pixels") != ANCHOR_TOLERANCE_PX
            or anchor.get("required_cell_count") != 16
            or anchor.get("alpha_bbox_bottom_is_reference_only") is not True
        ):
            raise IntakeError(f"{atlas_id}: hard per-cell anchor measurement contract is missing")

        local_references: list[dict[str, Any]] = []
        idle_reference_atlas = ""
        references = raw.get("required_reference", [])
        if not isinstance(references, list):
            raise IntakeError(f"{atlas_id}: required_reference must be a list")
        for ref_index, reference in enumerate(references, 1):
            if not isinstance(reference, dict):
                raise IntakeError(f"{atlas_id}: required reference {ref_index} must be an object")
            kind = str(reference.get("kind", ""))
            if kind == "local_file":
                reference_path = Path(str(reference.get("path", "")))
                reference_path = (
                    reference_path.resolve()
                    if reference_path.is_absolute()
                    else (ROOT.parent / reference_path).resolve()
                )
                reference_sha = expect_sha(reference.get("sha256"), f"{atlas_id}.required_reference.sha256")
                if not reference_path.is_file():
                    raise IntakeError(f"{atlas_id}: required local reference is missing: {reference_path}")
                actual_reference_sha = sha256_file(reference_path)
                if actual_reference_sha != reference_sha:
                    raise IntakeError(
                        f"{atlas_id}: required local reference SHA mismatch; declared {reference_sha}, actual {actual_reference_sha}"
                    )
                local_references.append(
                    {
                        "path": reference_path,
                        "sha256": reference_sha,
                        "purpose": str(reference.get("purpose", "")).strip(),
                    }
                )
            elif kind == "same_conversation_accepted_output":
                candidate = str(reference.get("atlas_id", ""))
                if candidate not in ("sample_heroes_idle", "sample_troops_idle"):
                    raise IntakeError(f"{atlas_id}: unsupported accepted-idle reference {candidate}")
                if reference.get("binding") != "conversation_url_and_adopted_source_sha256":
                    raise IntakeError(f"{atlas_id}: accepted-idle reference must bind both URL and source SHA")
                idle_reference_atlas = candidate
            else:
                raise IntakeError(f"{atlas_id}: unsupported required reference kind {kind!r}")
        if state == "idle" and idle_reference_atlas:
            raise IntakeError(f"{atlas_id}: idle may not depend on another idle atlas")
        if state != "idle" and idle_reference_atlas != f"sample_{group}_idle":
            raise IntakeError(f"{atlas_id}: later states must require their own group's accepted idle atlas")
        runtime_state = "death" if state == "down" else state
        batches.append(
            Batch(
                send_order=expected_order,
                atlas_id=atlas_id,
                filename=filename,
                prompt_path=prompt_path,
                prompt_sha256=declared_prompt_sha,
                group=group,
                design_state=state,
                runtime_state=runtime_state,
                rows=rows,
                anchor_kind=expected_anchor_kind,
                local_references=tuple(local_references),
                idle_reference_atlas=idle_reference_atlas,
            )
        )
        seen.add(atlas_id)

    expected_ids = [f"sample_{group}_{state}" for state in STATES for group in ("heroes", "troops")]
    if [batch.atlas_id for batch in batches] != expected_ids:
        raise IntakeError("the ten batches are not in the approved idle/walk/attack/hurt/down order")
    return data, batches


def source_path_from(value: Any, source_manifest: Path, atlas_id: str) -> Path:
    raw = str(value).strip()
    if not raw:
        raise IntakeError(f"{atlas_id}.source_png is empty")
    path = Path(raw)
    return path.resolve() if path.is_absolute() else (source_manifest.parent / path).resolve()


def parse_anchor_measurements(
    value: Any,
    batch: Batch,
    decision: str,
    label: str,
) -> tuple[dict[str, Any], ...]:
    if not isinstance(value, list):
        raise IntakeError(f"{label}.anchor_measurements must be a list")
    if decision == "adopt" and len(value) != 16:
        raise IntakeError(f"{label}: an adopted atlas must record all 16 manual anchor coordinates")
    if decision == "reject" and len(value) not in (0, 16):
        raise IntakeError(f"{label}: a rejected atlas records either zero or all 16 anchor coordinates")
    expected = {(identity, direction) for identity in batch.rows for direction in DIRECTIONS}
    result: dict[tuple[str, str], dict[str, Any]] = {}
    for index, raw in enumerate(value, 1):
        if not isinstance(raw, dict):
            raise IntakeError(f"{label}.anchor_measurements[{index}] must be an object")
        identity = str(raw.get("art_identity", ""))
        direction = str(raw.get("direction", "")).lower()
        key = (identity, direction)
        if key not in expected or key in result:
            raise IntakeError(f"{label}: unknown or repeated anchor cell {identity}:{direction}")
        if raw.get("measurement_kind") != batch.anchor_kind:
            raise IntakeError(f"{label}: {identity}:{direction} must use anchor kind {batch.anchor_kind}")
        source_y = raw.get("source_y_px")
        if not isinstance(source_y, int) or isinstance(source_y, bool) or source_y < 0:
            raise IntakeError(f"{label}: {identity}:{direction}.source_y_px must be a nonnegative integer")
        result[key] = {
            "art_identity": identity,
            "direction": direction,
            "measurement_kind": batch.anchor_kind,
            "source_y_px": source_y,
            "method": "manual_source_pixel_measurement",
            "note": str(raw.get("note", "")).strip(),
        }
    if result and set(result) != expected:
        raise IntakeError(f"{label}: anchor measurements do not cover the exact 4x4 identity/direction grid")
    return tuple(result[(identity, direction)] for identity in batch.rows for direction in DIRECTIONS) if result else ()


def concrete_reason(value: Any, label: str) -> str:
    reason = str(value).strip()
    if len(reason) < 8 or reason.casefold() in GENERIC_REASONS:
        raise IntakeError(f"{label}.reason must give a concrete adoption/rejection finding, not a generic verdict")
    return reason


def fixed_attempt_locations(data: dict[str, Any]) -> tuple[Path, tuple[Path, ...]]:
    """Return the batch-owned ledger paths; the source manifest cannot redirect them."""
    if data.get("attempt_sidecar_dir") != CANONICAL_SIDECAR_FIELD:
        raise IntakeError(
            f"attempt_sidecar_dir is fixed by the batch contract as {CANONICAL_SIDECAR_FIELD!r} "
            "and may not be overridden by the source manifest"
        )
    raw_roots = data.get("attempt_roots")
    if not isinstance(raw_roots, list) or tuple(raw_roots) != CANONICAL_ATTEMPT_ROOT_FIELDS:
        raise IntakeError(
            "attempt_roots are fixed by the batch contract as downloads/accepted/rejected "
            "and may not be overridden by the source manifest"
        )
    ledger_root = DEFAULT_ATTEMPT_LEDGER_ROOT.resolve()
    return (
        ledger_root / CANONICAL_SIDECAR_FIELD,
        tuple(ledger_root / name for name in CANONICAL_ATTEMPT_ROOT_FIELDS),
    )


def load_source_entries(
    path: Path,
    batches: list[Batch],
    require_selection: bool = True,
) -> tuple[dict[str, Any], dict[str, SourceEntry], list[SourceEntry], Path, tuple[Path, ...]]:
    data = load_json(path, "source manifest")
    raw_entries = data.get("entries")
    if data.get("schema_version") != 2 or data.get("kind") != "web_chatgpt_direction4_first_sample_sources_v2":
        raise IntakeError("source manifest must use schema 2 and kind web_chatgpt_direction4_first_sample_sources_v2")
    frozen_batch_sha = expect_sha(
        load_frozen_registry()["canonical_batch_manifest"].get("sha256"),
        "frozen_registry.canonical_batch_manifest.sha256",
    )
    if data.get("frozen_batch_manifest_sha256") != frozen_batch_sha:
        raise IntakeError("source manifest must bind the exact frozen batch-manifest SHA")
    if not isinstance(raw_entries, list) or not raw_entries:
        raise IntakeError("source manifest must contain every generated Web ChatGPT attempt")
    raw_selection = data.get("selected_attempt_ids", {})
    if not isinstance(raw_selection, dict):
        raise IntakeError("selected_attempt_ids must be an object")
    sidecar_dir, attempt_roots = fixed_attempt_locations(data)

    expected = {batch.atlas_id: batch for batch in batches}
    attempts_by_id: dict[str, SourceEntry] = {}
    source_hashes: set[str] = set()
    source_paths: set[Path] = set()
    for index, raw in enumerate(raw_entries, 1):
        if not isinstance(raw, dict):
            raise IntakeError(f"source entry {index} must be an object")
        atlas_id = str(raw.get("atlas_id", ""))
        if atlas_id not in expected:
            raise IntakeError(f"source entry {index} has an unknown atlas_id: {atlas_id}")
        batch = expected[atlas_id]
        size_raw = raw.get("size")
        if (
            not isinstance(size_raw, list)
            or len(size_raw) != 2
            or not all(isinstance(item, int) and not isinstance(item, bool) and item > 0 for item in size_raw)
        ):
            raise IntakeError(f"{atlas_id}.size must be [positive_width, positive_height]")
        decision = str(raw.get("decision", "")).strip().lower()
        if decision not in ("adopt", "reject"):
            raise IntakeError(f"{atlas_id}.decision must be adopt or reject")
        reason = concrete_reason(raw.get("reason"), atlas_id)
        review = raw.get("human_review")
        if not isinstance(review, dict):
            raise IntakeError(f"{atlas_id}.human_review must be an object")
        if any(not isinstance(review.get(flag), bool) for flag in REQUIRED_REVIEW_FLAGS):
            raise IntakeError(
                f"{atlas_id}.human_review must contain all {len(REQUIRED_REVIEW_FLAGS)} explicit boolean gates"
            )
        if decision == "adopt" and any(review[flag] is not True for flag in REQUIRED_REVIEW_FLAGS):
            failed = [flag for flag in REQUIRED_REVIEW_FLAGS if review[flag] is not True]
            raise IntakeError(f"{atlas_id}: adopted source failed required human gates: {failed}")

        source_sha = expect_sha(raw.get("source_sha256"), f"{atlas_id}.source_sha256")
        attempt_id = str(raw.get("attempt_id", ""))
        expected_attempt_id = f"{atlas_id}:{source_sha}"
        if attempt_id != expected_attempt_id or attempt_id in attempts_by_id:
            raise IntakeError(f"{atlas_id}: attempt_id must be the unique value {expected_attempt_id}")
        source_path = source_path_from(raw.get("source_png"), path, atlas_id)
        if source_sha in source_hashes or source_path in source_paths:
            raise IntakeError(f"{atlas_id}: attempt source SHA and source path must each be unique")
        source_hashes.add(source_sha)
        source_paths.add(source_path)
        reference_idle_sha = str(raw.get("reference_idle_sha256", "")).strip().lower()
        if batch.design_state == "idle":
            if reference_idle_sha:
                raise IntakeError(f"{atlas_id}: idle attempt may not declare reference_idle_sha256")
        else:
            reference_idle_sha = expect_sha(reference_idle_sha, f"{atlas_id}.reference_idle_sha256")
        attached_reference_sha256s = parse_string_tuple(
            raw.get("attached_reference_sha256s", []),
            len(batch.local_references),
            f"{atlas_id}.attached_reference_sha256s",
        )
        expected_reference_shas = tuple(str(item["sha256"]) for item in batch.local_references)
        if attached_reference_sha256s != expected_reference_shas:
            raise IntakeError(f"{atlas_id}: attached local reference SHA list does not match the batch contract")
        anchor_measurements = parse_anchor_measurements(
            raw.get("anchor_measurements", []), batch, decision, attempt_id
        )
        entry = SourceEntry(
            attempt_id=attempt_id,
            atlas_id=atlas_id,
            source_path=source_path,
            source_sha256=source_sha,
            size=(size_raw[0], size_raw[1]),
            conversation_url=stable_conversation_url(raw.get("conversation_url"), f"{atlas_id}.conversation_url"),
            prompt_sha256=expect_sha(raw.get("prompt_sha256"), f"{atlas_id}.prompt_sha256"),
            group=str(raw.get("group", "")),
            design_state=str(raw.get("design_state", "")),
            directions=parse_string_tuple(raw.get("directions"), 4, f"{atlas_id}.directions"),
            rows=parse_string_tuple(raw.get("rows"), 4, f"{atlas_id}.rows"),
            decision=decision,
            reason=reason,
            human_review={flag: review[flag] for flag in REQUIRED_REVIEW_FLAGS},
            anchor_measurements=anchor_measurements,
            reference_idle_sha256=reference_idle_sha,
            attached_reference_sha256s=attached_reference_sha256s,
        )
        if entry.group != batch.group or entry.design_state != batch.design_state:
            raise IntakeError(f"{atlas_id}: declared group/design_state does not match the prompt batch")
        if entry.directions != DIRECTIONS or entry.rows != batch.rows:
            raise IntakeError(f"{atlas_id}: declared direction columns or row identities do not match the prompt batch")
        if entry.prompt_sha256 != batch.prompt_sha256:
            raise IntakeError(f"{atlas_id}: source manifest prompt SHA does not match the reviewed prompt")
        attempts_by_id[attempt_id] = entry

    attempts_by_sha = {entry.source_sha256: entry for entry in attempts_by_id.values()}
    for entry in attempts_by_id.values():
        if entry.design_state == "idle":
            continue
        referenced_idle = attempts_by_sha.get(entry.reference_idle_sha256)
        expected_idle_id = f"sample_{entry.group}_idle"
        if (
            referenced_idle is None
            or referenced_idle.atlas_id != expected_idle_id
            or referenced_idle.decision != "adopt"
            or referenced_idle.conversation_url != entry.conversation_url
        ):
            raise IntakeError(
                f"{entry.attempt_id}: every later-state attempt must bind an adopted {expected_idle_id} attempt "
                "with the same conversation URL and exact source SHA"
            )

    selected: dict[str, SourceEntry] = {}
    if require_selection:
        if set(raw_selection) != set(expected):
            raise IntakeError("selected_attempt_ids must select one attempt for each exact approved atlas ID")
        for atlas_id, attempt_id_value in raw_selection.items():
            attempt_id = str(attempt_id_value)
            entry = attempts_by_id.get(attempt_id)
            if entry is None or entry.atlas_id != atlas_id:
                raise IntakeError(f"{atlas_id}: selected attempt is missing or belongs to another atlas")
            selected[atlas_id] = entry
        if len({entry.source_sha256 for entry in selected.values()}) != 10:
            raise IntakeError("the ten selected source PNGs must have distinct SHA-256 values")

        # URL alone is insufficient: every later state must bind the exact
        # adopted idle bytes that the same conversation could see.
        for group in GROUP_ROWS:
            idle = selected[f"sample_{group}_idle"]
            if idle.decision != "adopt":
                raise IntakeError(f"sample_{group}_idle: the selected identity reference must be adopted")
            for state in STATES[1:]:
                atlas_id = f"sample_{group}_{state}"
                entry = selected[atlas_id]
                if entry.conversation_url != idle.conversation_url:
                    raise IntakeError(f"{atlas_id}: later state must use the selected {group} idle conversation URL")
                if entry.reference_idle_sha256 != idle.source_sha256:
                    raise IntakeError(f"{atlas_id}: reference_idle_sha256 does not bind the selected adopted idle bytes")

    return data, selected, list(attempts_by_id.values()), sidecar_dir, attempt_roots


def png_alpha_facts(entry: SourceEntry) -> dict[str, Any]:
    path = entry.source_path
    if not path.is_file():
        raise IntakeError(f"{entry.atlas_id}: source PNG does not exist: {path}")
    payload = path.read_bytes()
    if len(payload) < 29 or payload[:8] != b"\x89PNG\r\n\x1a\n" or payload[12:16] != b"IHDR":
        raise IntakeError(f"{entry.atlas_id}: source is not a valid PNG with a normal IHDR")
    color_type = payload[25]
    if color_type not in (4, 6):
        raise IntakeError(
            f"{entry.atlas_id}: PNG color type {color_type} has no native alpha channel; palette tRNS is not accepted"
        )
    actual_sha = sha256_bytes(payload)
    if actual_sha != entry.source_sha256:
        raise IntakeError(
            f"{entry.atlas_id}: source SHA mismatch; declared {entry.source_sha256}, actual {actual_sha}"
        )
    try:
        with Image.open(io.BytesIO(payload)) as opened:
            actual_size = opened.size
            if min(actual_size) < 512 or max(actual_size) > 8192:
                raise IntakeError(f"{entry.atlas_id}: source dimensions must stay between 512 and 8192 pixels")
            opened.load()
            rgba = opened.convert("RGBA")
    except OSError as error:
        raise IntakeError(f"{entry.atlas_id}: PNG cannot be decoded: {error}") from error
    if actual_size != entry.size:
        raise IntakeError(f"{entry.atlas_id}: declared size {entry.size} does not match PNG {actual_size}")
    alpha_min, alpha_max = rgba.getchannel("A").getextrema()
    if alpha_min != 0 or alpha_max == 0:
        raise IntakeError(f"{entry.atlas_id}: source must contain both exact zero-alpha and visible pixels")
    return {
        "file": str(path),
        "sha256": actual_sha,
        "size": list(actual_size),
        "png_color_type": color_type,
        "alpha_min": alpha_min,
        "alpha_max": alpha_max,
    }


def png_attempt_facts(entry: SourceEntry) -> dict[str, Any]:
    """Validate immutable source bytes without requiring a rejected image to have alpha."""
    path = entry.source_path
    if not path.is_file():
        raise IntakeError(f"{entry.attempt_id}: source PNG does not exist: {path}")
    payload = path.read_bytes()
    if len(payload) < 29 or payload[:8] != b"\x89PNG\r\n\x1a\n" or payload[12:16] != b"IHDR":
        raise IntakeError(f"{entry.attempt_id}: source attempt is not a valid PNG with a normal IHDR")
    actual_sha = sha256_bytes(payload)
    if actual_sha != entry.source_sha256:
        raise IntakeError(
            f"{entry.attempt_id}: source SHA mismatch; declared {entry.source_sha256}, actual {actual_sha}"
        )
    try:
        with Image.open(io.BytesIO(payload)) as opened:
            actual_size = opened.size
            opened.verify()
    except OSError as error:
        raise IntakeError(f"{entry.attempt_id}: source PNG cannot be decoded: {error}") from error
    if actual_size != entry.size:
        raise IntakeError(f"{entry.attempt_id}: declared size {entry.size} does not match PNG {actual_size}")
    return {
        "file": str(path),
        "sha256": actual_sha,
        "size": list(actual_size),
        "png_color_type": payload[25],
    }


def attempt_sidecar_record(entry: SourceEntry) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "kind": "web_chatgpt_direction4_attempt",
        "attempt_id": entry.attempt_id,
        "atlas_id": entry.atlas_id,
        "source_file_name": entry.source_path.name,
        "source_sha256": entry.source_sha256,
        "size": list(entry.size),
        "conversation_url": entry.conversation_url,
        "prompt_sha256": entry.prompt_sha256,
        "group": entry.group,
        "design_state": entry.design_state,
        "directions": list(entry.directions),
        "rows": list(entry.rows),
        "decision": entry.decision,
        "reason": entry.reason,
        "human_review": entry.human_review,
        "anchor_measurements": list(entry.anchor_measurements),
        "reference_idle_sha256": entry.reference_idle_sha256,
        "attached_reference_sha256s": list(entry.attached_reference_sha256s),
    }


def attempt_sidecar_payload(entry: SourceEntry) -> bytes:
    return (json.dumps(attempt_sidecar_record(entry), ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode("utf-8")


def attempt_sidecar_path(sidecar_dir: Path, entry: SourceEntry) -> Path:
    return sidecar_dir / f"{entry.source_sha256}.attempt.json"


def inside_any(path: Path, roots: tuple[Path, ...]) -> bool:
    resolved = path.resolve()
    for root in roots:
        try:
            resolved.relative_to(root.resolve())
            return True
        except ValueError:
            continue
    return False


def validate_attempt_inventory(attempts: list[SourceEntry], roots: tuple[Path, ...]) -> list[dict[str, Any]]:
    _fixed_sidecar, fixed_roots = fixed_attempt_locations(
        {
            "attempt_sidecar_dir": CANONICAL_SIDECAR_FIELD,
            "attempt_roots": list(CANONICAL_ATTEMPT_ROOT_FIELDS),
        }
    )
    if tuple(path.resolve() for path in roots) != tuple(path.resolve() for path in fixed_roots):
        raise IntakeError("attempt inventory roots are fixed by the frozen batch ledger and cannot be redirected")
    for root in roots:
        if not root.is_dir():
            raise IntakeError(f"attempt root does not exist: {root}")
    facts: list[dict[str, Any]] = []
    declared_paths: set[Path] = set()
    for entry in attempts:
        if not inside_any(entry.source_path, roots):
            raise IntakeError(f"{entry.attempt_id}: source PNG must stay inside a declared attempt root")
        facts.append({"attempt_id": entry.attempt_id, **png_attempt_facts(entry)})
        declared_paths.add(entry.source_path.resolve())
    discovered = {
        candidate.resolve()
        for root in roots
        for candidate in root.rglob("*.png")
        if candidate.is_file()
    }
    missing_records = sorted(str(path) for path in discovered - declared_paths)
    missing_files = sorted(str(path) for path in declared_paths - discovered)
    if missing_records or missing_files:
        raise IntakeError(
            "attempt inventory is incomplete; unrecorded_pngs=%s, missing_declared_pngs=%s"
            % (missing_records, missing_files)
        )
    return facts


def write_once(path: Path, payload: bytes) -> str:
    """Create immutable evidence once; identical replay is allowed, replacement is not."""
    if path.exists():
        if not path.is_file() or path.read_bytes() != payload:
            raise IntakeError(f"append-only attempt sidecar already exists with different bytes: {path}")
        return "verified_existing"
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor: int | None = None
    created = False
    try:
        descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        created = True
        with os.fdopen(descriptor, "wb", closefd=True) as handle:
            descriptor = None
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
    except Exception:
        if descriptor is not None:
            os.close(descriptor)
        if created and path.exists():
            try:
                path.unlink()
            except OSError:
                pass
        raise
    return "created"


def record_or_verify_attempt_sidecars(
    attempts: list[SourceEntry],
    sidecar_dir: Path,
    record: bool,
) -> list[dict[str, str]]:
    fixed_sidecar, _fixed_roots = fixed_attempt_locations(
        {
            "attempt_sidecar_dir": CANONICAL_SIDECAR_FIELD,
            "attempt_roots": list(CANONICAL_ATTEMPT_ROOT_FIELDS),
        }
    )
    if sidecar_dir.resolve() != fixed_sidecar.resolve():
        raise IntakeError("attempt sidecar ledger is fixed by the frozen batch contract and cannot be redirected")
    try:
        sidecar_dir.resolve().relative_to((ROOT / "assets").resolve())
    except ValueError:
        pass
    else:
        raise IntakeError("attempt sidecars are QA provenance and may not be written inside production assets")
    results: list[dict[str, str]] = []
    expected_paths: set[Path] = set()
    for entry in attempts:
        path = attempt_sidecar_path(sidecar_dir, entry)
        expected_paths.add(path.resolve())
        payload = attempt_sidecar_payload(entry)
        if record:
            status = write_once(path, payload)
        else:
            if not path.is_file():
                raise IntakeError(
                    f"{entry.attempt_id}: immutable attempt sidecar is missing; run --record-attempts first"
                )
            if path.read_bytes() != payload:
                raise IntakeError(f"{entry.attempt_id}: immutable attempt sidecar does not match the source manifest")
            status = "verified_existing"
        results.append({"attempt_id": entry.attempt_id, "sidecar": str(path), "status": status})
    discovered_paths = {
        path.resolve() for path in sidecar_dir.rglob("*.attempt.json") if path.is_file()
    } if sidecar_dir.is_dir() else set()
    omitted = sorted(str(path) for path in discovered_paths - expected_paths)
    if omitted:
        raise IntakeError(
            "source manifest omitted previously recorded append-only attempts: " + ", ".join(omitted)
        )
    return results


def production_output(batch: Batch, direction: str) -> Path:
    return DEFAULT_OUTPUT_DIR / f"{batch.rows[0]}_{batch.runtime_state}_{direction}.png"


def run_grid_slicer(
    batch: Batch,
    entry: SourceEntry,
    temporary: Path,
    generate: bool,
) -> tuple[dict[str, Any], dict[str, Any] | None, Path]:
    """Run only the reviewed transparent-grid path in an isolated directory."""
    source_id = f"web_first_sample_{batch.atlas_id}_{entry.source_sha256[:12]}"
    input_dir = temporary / "inputs"
    output_dir = temporary / "outputs" / batch.atlas_id
    prompt_dir = temporary / "prompts"
    anchor_dir = temporary / "anchors"
    input_dir.mkdir(parents=True, exist_ok=True)
    prompt_dir.mkdir(parents=True, exist_ok=True)
    anchor_dir.mkdir(parents=True, exist_ok=True)
    source_copy = input_dir / f"{source_id}.png"
    prompt_copy = prompt_dir / f"{batch.atlas_id}_{batch.prompt_sha256[:12]}.txt"
    anchor_copy = anchor_dir / f"{batch.atlas_id}_manual_semantic_anchors.json"
    shutil.copyfile(entry.source_path, source_copy)
    shutil.copyfile(batch.prompt_path, prompt_copy)
    anchor_copy.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "kind": "direction4_manual_semantic_anchor_measurements",
                "target_fraction": ANCHOR_FRACTION,
                "tolerance_px": ANCHOR_TOLERANCE_PX,
                "entries": list(entry.anchor_measurements),
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    temp_manifest = temporary / "manifests" / f"{batch.atlas_id}.json"
    temp_manifest.parent.mkdir(parents=True, exist_ok=True)
    rows_arg = ",".join(f"{identity}:{batch.runtime_state}" for identity in batch.rows)
    command = [
        sys.executable,
        str(SLICER),
        "--source",
        str(source_copy),
        "--rows",
        rows_arg,
        "--prompt",
        str(prompt_copy),
        "--conversation",
        entry.conversation_url,
        "--review",
        entry.reason,
        "--semantic-anchor-measurements",
        str(anchor_copy),
        "--manifest",
        str(temp_manifest),
        "--output-dir",
        str(output_dir),
        "--layout",
        "grid",
        "--seam-alpha-threshold",
        "0",
        "--minimum-seam-gap",
        "24",
        "--canvas-size",
        "256",
        "--target-width",
        "226",
        "--target-height",
        "198",
        "--alpha-bottom-reference",
        "0.82",
    ]
    if not generate:
        command.append("--dry-run")
    process = subprocess.run(command, text=True, encoding="utf-8", capture_output=True, check=False)
    if process.returncode != 0:
        detail = (process.stderr or process.stdout).strip()
        raise IntakeError(f"{batch.atlas_id}: grid slicer rejected the source: {detail}")
    if generate:
        generated_manifest = load_json(temp_manifest, f"{batch.atlas_id} staging manifest")
        source_record = generated_manifest.get("sources", {}).get(source_id)
        outputs = generated_manifest.get("outputs")
        if not isinstance(source_record, dict) or not isinstance(outputs, list) or len(outputs) != 16:
            raise IntakeError(f"{batch.atlas_id}: staging slicer did not create one source and 16 outputs")
        return {"source": source_id, "outputs": outputs}, source_record, output_dir
    try:
        plan = json.loads(process.stdout)
    except json.JSONDecodeError as error:
        raise IntakeError(f"{batch.atlas_id}: grid slicer returned invalid dry-run JSON") from error
    outputs = plan.get("outputs")
    if plan.get("dry_run") is not True or not isinstance(outputs, list) or len(outputs) != 16:
        raise IntakeError(f"{batch.atlas_id}: grid slicer dry run did not return 16 outputs")
    return plan, None, output_dir


def expected_output_paths(batch: Batch) -> list[Path]:
    return [DEFAULT_OUTPUT_DIR / f"{identity}_{batch.runtime_state}_{direction}.png" for identity in batch.rows for direction in DIRECTIONS]


def collision_record(path: Path) -> dict[str, Any]:
    return {
        "path": rel(path),
        "exists": path.is_file(),
        "sha256": sha256_file(path) if path.is_file() else "",
    }


def load_production_manifest() -> dict[str, Any]:
    if not DEFAULT_PRODUCTION_MANIFEST.exists():
        return {"schema_version": 1, "sources": {}, "outputs": []}
    data = load_json(DEFAULT_PRODUCTION_MANIFEST, "production direction manifest")
    if not isinstance(data.get("sources"), dict) or not isinstance(data.get("outputs"), list):
        raise IntakeError("production direction manifest has an incompatible schema")
    return data


def manifest_key_collisions(manifest: dict[str, Any], batches: list[Batch]) -> list[dict[str, str]]:
    keys = {
        (identity, batch.runtime_state, direction)
        for batch in batches
        for identity in batch.rows
        for direction in DIRECTIONS
    }
    return [
        {
            "unit": str(output.get("unit", "")),
            "state": str(output.get("state", "")),
            "direction": str(output.get("direction", "")),
            "source": str(output.get("source", output.get("source_id", ""))),
        }
        for output in manifest["outputs"]
        if (str(output.get("unit", "")), str(output.get("state", "")), str(output.get("direction", ""))) in keys
    ]


def verify_plan_outputs(batch: Batch, entry: SourceEntry, plan: dict[str, Any]) -> list[dict[str, Any]]:
    outputs = plan["outputs"]
    by_key = {
        (str(item.get("unit")), str(item.get("state")), str(item.get("direction"))): item
        for item in outputs
    }
    expected = {(identity, batch.runtime_state, direction) for identity in batch.rows for direction in DIRECTIONS}
    if set(by_key) != expected:
        raise IntakeError(f"{batch.atlas_id}: slicer output mapping differs from the approved rows/directions")
    normalized: list[dict[str, Any]] = []
    measurements = {
        (str(item["art_identity"]), str(item["direction"])): item
        for item in entry.anchor_measurements
    }
    for identity in batch.rows:
        for direction in DIRECTIONS:
            item = dict(by_key[(identity, batch.runtime_state, direction)])
            if item.get("layout") != "grid" or int(item.get("excluded_foreign_pixels", -1)) != 0:
                raise IntakeError(f"{batch.atlas_id}: output is not an unmasked grid crop")
            isolation = str(item.get("isolation", "")).lower()
            if "rectangular alpha-content crop is copied whole" not in isolation or any(
                token in isolation for token in ("component ownership", "connected-component", "foreign figures are zeroed")
            ):
                raise IntakeError(f"{batch.atlas_id}: output provenance does not prove whole rectangular crop retention")
            seams = item.get("selected_seams")
            if not isinstance(seams, dict):
                raise IntakeError(f"{batch.atlas_id}: output lacks audited grid seams")
            for axis in ("vertical", "horizontal"):
                records = seams.get(axis)
                if not isinstance(records, list) or len(records) != 3:
                    raise IntakeError(f"{batch.atlas_id}: output does not record three {axis} seams")
                if any(int(seam.get("gap", 0)) < 24 or int(seam.get("max_alpha", 255)) != 0 for seam in records):
                    raise IntakeError(f"{batch.atlas_id}: {axis} seams are not at least 24 px of exact alpha zero")
            source_cell = item.get("source_cell")
            if (
                not isinstance(source_cell, list)
                or len(source_cell) != 4
                or not all(isinstance(value, int) and not isinstance(value, bool) for value in source_cell)
            ):
                raise IntakeError(f"{batch.atlas_id}: output lacks a concrete source-cell rectangle")
            measurement = measurements.get((identity, direction))
            if measurement is None:
                raise IntakeError(f"{batch.atlas_id}: missing manual anchor coordinate for {identity}:{direction}")
            _x0, y0, _width, height = source_cell
            if height <= 0:
                raise IntakeError(f"{batch.atlas_id}: invalid source-cell height for {identity}:{direction}")
            source_y = int(measurement["source_y_px"])
            target_y = y0 + round(height * ANCHOR_FRACTION)
            error_px = source_y - target_y
            if source_y < y0 or source_y >= y0 + height:
                raise IntakeError(f"{batch.atlas_id}: manual anchor coordinate leaves its cell for {identity}:{direction}")
            if abs(error_px) > ANCHOR_TOLERANCE_PX:
                raise IntakeError(
                    f"{batch.atlas_id}: {identity}:{direction} manual {batch.anchor_kind} Y={source_y} "
                    f"misses target Y={target_y} by {error_px}px"
                )
            canvas_size = item.get("canvas_size")
            if (
                not isinstance(canvas_size, list)
                or len(canvas_size) != 2
                or not all(isinstance(value, int) and not isinstance(value, bool) and value > 0 for value in canvas_size)
                or canvas_size[0] != canvas_size[1]
            ):
                raise IntakeError(f"{batch.atlas_id}: output lacks a square target canvas size")
            expected_output_y = round(canvas_size[1] * ANCHOR_FRACTION)
            placement = item.get("placement_reference")
            if not isinstance(placement, dict) or (
                placement.get("kind") != "manual_source_pixel_semantic_anchor"
                or placement.get("semantic_anchor_evidence") is not True
                or placement.get("measurement_kind") != batch.anchor_kind
                or placement.get("source_y_px") != source_y
                or placement.get("target_fraction") != ANCHOR_FRACTION
                or placement.get("target_output_y_px") != expected_output_y
                or placement.get("placed_output_y_px") != expected_output_y
                or placement.get("tolerance_px") != ANCHOR_TOLERANCE_PX
            ):
                raise IntakeError(
                    f"{batch.atlas_id}: final PNG placement must use the exact reviewed manual "
                    f"{batch.anchor_kind} coordinate at 82 percent"
                )
            source_region = item.get("source_region")
            output_size = item.get("output_size")
            paste_xy = item.get("paste_xy")
            row_scale = item.get("row_scale")
            if (
                not isinstance(source_region, list)
                or len(source_region) != 4
                or not all(isinstance(value, int) and not isinstance(value, bool) for value in source_region)
                or source_region[2] <= 0
                or source_region[3] <= 0
                or not isinstance(output_size, list)
                or len(output_size) != 2
                or not all(isinstance(value, int) and not isinstance(value, bool) and value > 0 for value in output_size)
                or not isinstance(paste_xy, list)
                or len(paste_xy) != 2
                or not all(isinstance(value, int) and not isinstance(value, bool) for value in paste_xy)
                or not isinstance(row_scale, (int, float))
                or isinstance(row_scale, bool)
                or row_scale <= 0
            ):
                raise IntakeError(f"{batch.atlas_id}: output lacks auditable semantic-placement geometry")
            expected_source_offset_y = source_y - source_region[1]
            calculated_output_y = paste_xy[1] + round(expected_source_offset_y * float(row_scale))
            if (
                expected_source_offset_y < 0
                or expected_source_offset_y >= source_region[3]
                or placement.get("source_offset_y_px") != expected_source_offset_y
                or calculated_output_y != expected_output_y
                or paste_xy[0] < 0
                or paste_xy[1] < 0
                or paste_xy[0] + output_size[0] > canvas_size[0]
                or paste_xy[1] + output_size[1] > canvas_size[1]
            ):
                raise IntakeError(
                    f"{batch.atlas_id}: semantic-placement geometry does not reproduce the final 82 percent anchor"
                )
            alpha_reference = item.get("alpha_bbox_bottom_reference")
            if not isinstance(alpha_reference, dict) or (
                alpha_reference.get("kind") != "source_alpha_bbox_bottom_only"
                or alpha_reference.get("output_y_px") != paste_xy[1] + output_size[1]
                or alpha_reference.get("semantic_anchor_evidence") is not False
            ):
                raise IntakeError(
                    f"{batch.atlas_id}: alpha-bounds bottom must remain a separate non-semantic reference"
                )
            item["output"] = rel(DEFAULT_OUTPUT_DIR / f"{identity}_{batch.runtime_state}_{direction}.png")
            item["design_state"] = batch.design_state
            item["runtime_state"] = batch.runtime_state
            item["atlas_id"] = batch.atlas_id
            item["manual_anchor_measurement"] = {
                **measurement,
                "cell_y_px": y0,
                "cell_height_px": height,
                "target_fraction": ANCHOR_FRACTION,
                "target_source_y_px": target_y,
                "error_px": error_px,
                "tolerance_px": ANCHOR_TOLERANCE_PX,
                "within_tolerance": True,
                "alpha_bbox_bottom_was_not_used_as_measurement": True,
            }
            normalized.append(item)
    return normalized


def build_plan(
    source_manifest_path: Path,
    batch_manifest_path: Path,
    require_adopted: bool,
    generate: bool,
    require_frozen_batch: bool = True,
) -> tuple[dict[str, Any], list[Batch], dict[str, SourceEntry], dict[str, Any]]:
    batch_manifest_sha = sha256_file(batch_manifest_path)
    source_manifest_sha = sha256_file(source_manifest_path)
    batch_data, batches = load_batches(batch_manifest_path, require_frozen=require_frozen_batch)
    source_data, entries, attempts, sidecar_dir, attempt_roots = load_source_entries(
        source_manifest_path, batches, require_selection=True
    )
    if sha256_file(batch_manifest_path) != batch_manifest_sha:
        raise IntakeError("prompt batch manifest changed while it was being read")
    if sha256_file(source_manifest_path) != source_manifest_sha:
        raise IntakeError("source manifest changed while it was being read")
    attempt_inventory = validate_attempt_inventory(attempts, attempt_roots)
    attempt_sidecars = record_or_verify_attempt_sidecars(attempts, sidecar_dir, record=False)
    production_manifest = load_production_manifest()
    manifest_collisions = manifest_key_collisions(production_manifest, batches)
    source_hashes: dict[str, str] = {}
    prompt_hashes: dict[str, str] = {}
    atlas_reports: list[dict[str, Any]] = []
    generated: dict[str, Any] = {}

    with tempfile.TemporaryDirectory(prefix="liangshan_first_sample_intake_") as temp_name:
        temporary = Path(temp_name)
        for batch in batches:
            entry = entries[batch.atlas_id]
            facts = png_alpha_facts(entry)
            source_hashes[batch.atlas_id] = facts["sha256"]
            prompt_hashes[batch.atlas_id] = sha256_file(batch.prompt_path)
            slicer_plan, source_record, staging_output_dir = run_grid_slicer(
                batch, entry, temporary / batch.atlas_id, generate
            )
            slicer_source_sha = (
                str(source_record.get("sha256", "")) if source_record is not None else str(slicer_plan.get("source_sha256", ""))
            )
            if slicer_source_sha != entry.source_sha256:
                raise IntakeError(f"{batch.atlas_id}: source changed before or during grid slicing")
            if sha256_file(batch.prompt_path) != batch.prompt_sha256:
                raise IntakeError(f"{batch.atlas_id}: prompt changed before or during grid slicing")
            normalized_outputs = verify_plan_outputs(batch, entry, slicer_plan)
            destination_source = DEFAULT_SOURCE_ARCHIVE / f"{slicer_plan['source']}.png"
            destination_prompt = DEFAULT_PROMPT_ARCHIVE / f"{batch.atlas_id}_{batch.prompt_sha256[:12]}.txt"
            destination_references = [
                DEFAULT_REFERENCE_ARCHIVE
                / f"{str(reference['sha256'])[:12]}_{Path(reference['path']).name}"
                for reference in batch.local_references
            ]
            collisions = [collision_record(path) for path in expected_output_paths(batch)]
            collisions += [collision_record(destination_source), collision_record(destination_prompt)]
            collisions += [collision_record(path) for path in destination_references]
            atlas_reports.append(
                {
                    "send_order": batch.send_order,
                    "atlas_id": batch.atlas_id,
                    "source_rule": SOURCE_RULE_TRANSPARENT_GRID,
                    "group": batch.group,
                    "design_state": batch.design_state,
                    "runtime_state": batch.runtime_state,
                    "decision": entry.decision,
                    "reason": entry.reason,
                    "attempt_id": entry.attempt_id,
                    "human_review": entry.human_review,
                    "source": facts,
                    "conversation_url": entry.conversation_url,
                    "reference_idle_sha256": entry.reference_idle_sha256,
                    "attached_reference_sha256s": list(entry.attached_reference_sha256s),
                    "local_references": [
                        {
                            "source": str(reference["path"]),
                            "sha256": reference["sha256"],
                            "purpose": reference["purpose"],
                            "archive": rel(destination),
                        }
                        for reference, destination in zip(batch.local_references, destination_references)
                    ],
                    "prompt_file": str(batch.prompt_path),
                    "prompt_sha256": batch.prompt_sha256,
                    "row_mapping": [
                        {"art_identity": identity, "design_state": batch.design_state, "runtime_state": batch.runtime_state}
                        for identity in batch.rows
                    ],
                    "directions": list(DIRECTIONS),
                    "grid_contract": {
                        "source_rule": SOURCE_RULE_TRANSPARENT_GRID,
                        "layout": "grid",
                        "seam_alpha_threshold": 0,
                        "minimum_seam_gap": 24,
                        "pixel_operations": ["rectangular_crop", "uniform_scale", "transparent_padding"],
                        "forbidden": ["components", "mirroring", "pixel_clearing", "masking", "repainting"],
                        "semantic_anchor": {
                            "kind": batch.anchor_kind,
                            "target_fraction": ANCHOR_FRACTION,
                            "tolerance_px": ANCHOR_TOLERANCE_PX,
                            "manual_measurements": 16,
                            "alpha_bbox_bottom_is_reference_only": True,
                        },
                    },
                    "planned_outputs": normalized_outputs,
                    "production_files": collisions,
                    "source_archive": rel(destination_source),
                    "prompt_archive": rel(destination_prompt),
                    "reference_archives": [rel(path) for path in destination_references],
                }
            )
            if generate:
                if source_record is None:
                    raise IntakeError(f"{batch.atlas_id}: missing staging provenance")
                generated[batch.atlas_id] = {
                    "source_record": source_record,
                    "staging_output_dir": staging_output_dir,
                    "source_archive": destination_source,
                    "prompt_archive": destination_prompt,
                    "reference_archives": destination_references,
                    "source_id": slicer_plan["source"],
                    "normalized_outputs": normalized_outputs,
                }

        if generate:
            # TemporaryDirectory would remove the generated frames.  Preserve
            # their exact bytes in memory; the largest approved batch remains
            # comfortably bounded (160 x 256px PNGs).
            for batch in batches:
                item = generated[batch.atlas_id]
                payloads: dict[str, bytes] = {}
                for identity in batch.rows:
                    for direction in DIRECTIONS:
                        name = f"{identity}_{batch.runtime_state}_{direction}.png"
                        path = Path(item["staging_output_dir"]) / name
                        if not path.is_file():
                            raise IntakeError(f"{batch.atlas_id}: staging output is missing: {name}")
                        payloads[name] = path.read_bytes()
                item["payloads"] = payloads
                source_payload = entries[batch.atlas_id].source_path.read_bytes()
                prompt_payload = batch.prompt_path.read_bytes()
                if sha256_bytes(source_payload) != entries[batch.atlas_id].source_sha256:
                    raise IntakeError(f"{batch.atlas_id}: source changed before staging completed")
                if sha256_bytes(prompt_payload) != batch.prompt_sha256:
                    raise IntakeError(f"{batch.atlas_id}: prompt changed before staging completed")
                item["source_payload"] = source_payload
                item["prompt_payload"] = prompt_payload
                reference_payloads: list[bytes] = []
                for reference in batch.local_references:
                    reference_path = Path(reference["path"])
                    payload = reference_path.read_bytes()
                    if sha256_bytes(payload) != reference["sha256"]:
                        raise IntakeError(f"{batch.atlas_id}: local reference changed before staging completed")
                    reference_payloads.append(payload)
                item["reference_payloads"] = reference_payloads

    if require_adopted:
        rejected = [entry.atlas_id for entry in entries.values() if entry.decision != "adopt"]
        if rejected:
            raise IntakeError("--commit requires all ten sources to be adopted; rejected: " + ", ".join(rejected))

    plan_core = {
        "schema_version": 1,
        "kind": "direction4_first_sample_intake_plan",
        "supported_source_rules": list(SUPPORTED_SOURCE_RULES),
        "active_source_rule": SOURCE_RULE_TRANSPARENT_GRID,
        "commit_requested": require_adopted,
        "source_manifest": str(source_manifest_path),
        "source_manifest_sha256": source_manifest_sha,
        "batch_manifest": str(batch_manifest_path),
        "batch_manifest_sha256": batch_manifest_sha,
        "production_manifest": rel(DEFAULT_PRODUCTION_MANIFEST),
        "production_manifest_before_sha256": sha256_file(DEFAULT_PRODUCTION_MANIFEST) if DEFAULT_PRODUCTION_MANIFEST.exists() else "",
        "summary": {
            "atlases": len(batches),
            "adopted": sum(entry.decision == "adopt" for entry in entries.values()),
            "rejected": sum(entry.decision == "reject" for entry in entries.values()),
            "planned_outputs": len(batches) * 16,
            "design_identity_state_rows": len(batches) * 4,
            "existing_output_file_collisions": sum(
                record["exists"]
                for atlas in atlas_reports
                for record in atlas["production_files"][:16]
            ),
            "existing_manifest_key_collisions": len(manifest_collisions),
            "recorded_attempts": len(attempts),
            "recorded_rejections": sum(entry.decision == "reject" for entry in attempts),
            "verified_append_only_sidecars": len(attempt_sidecars),
        },
        "attempt_inventory": attempt_inventory,
        "attempt_sidecars": attempt_sidecars,
        "coverage_boundary": (
            "Generic wu_song covers the later itinerant hero only. It does not satisfy "
            "level7 wu_song_mengzhou, which requires a separate prompt batch and provenance."
        ),
        "manifest_key_collisions": manifest_collisions,
        "atlases": atlas_reports,
    }
    canonical = json.dumps(plan_core, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    plan_core["deterministic_plan_sha256"] = sha256_bytes(canonical)
    plan_core["_generated"] = generated
    plan_core["_production_manifest"] = production_manifest
    plan_core["_batch_data"] = batch_data
    plan_core["_source_data"] = source_data
    plan_core["_attempts"] = attempts
    plan_core["_source_hashes"] = source_hashes
    plan_core["_prompt_hashes"] = prompt_hashes
    plan_core["_attempt_hashes"] = {
        str(entry.source_path): entry.source_sha256 for entry in attempts
    }
    plan_core["_sidecar_hashes"] = {
        str(attempt_sidecar_path(sidecar_dir, entry)): sha256_file(attempt_sidecar_path(sidecar_dir, entry))
        for entry in attempts
    }
    prestate: dict[Path, dict[str, Any]] = {
        DEFAULT_PRODUCTION_MANIFEST: collision_record(DEFAULT_PRODUCTION_MANIFEST)
    }
    for atlas in atlas_reports:
        for record in atlas["production_files"]:
            target = ROOT / record["path"]
            prestate[target] = record
    plan_core["_prestate"] = prestate
    return plan_core, batches, entries, production_manifest


def public_plan(plan: dict[str, Any], committed: bool = False, checkpoint: Path | None = None) -> dict[str, Any]:
    result = {key: value for key, value in plan.items() if not key.startswith("_")}
    result["dry_run"] = not committed
    result["committed"] = committed
    if checkpoint is not None:
        result["checkpoint"] = rel(checkpoint)
    return result


def record_attempts(
    source_manifest_path: Path,
    batch_manifest_path: Path,
) -> dict[str, Any]:
    """Record immutable per-SHA sidecars without slicing or touching production art."""
    batch_sha = sha256_file(batch_manifest_path)
    source_sha = sha256_file(source_manifest_path)
    _batch_data, batches = load_batches(batch_manifest_path, require_frozen=True)
    _source_data, _selected, attempts, sidecar_dir, attempt_roots = load_source_entries(
        source_manifest_path, batches, require_selection=False
    )
    if sha256_file(batch_manifest_path) != batch_sha or sha256_file(source_manifest_path) != source_sha:
        raise IntakeError("an input manifest changed while attempt evidence was being prepared")
    inventory = validate_attempt_inventory(attempts, attempt_roots)
    sidecars = record_or_verify_attempt_sidecars(attempts, sidecar_dir, record=True)
    return {
        "schema_version": 2,
        "kind": "direction4_first_sample_attempt_record_result",
        "production_art_modified": False,
        "source_manifest": str(source_manifest_path),
        "source_manifest_sha256": source_sha,
        "batch_manifest": str(batch_manifest_path),
        "batch_manifest_sha256": batch_sha,
        "attempts": len(attempts),
        "adopted": sum(entry.decision == "adopt" for entry in attempts),
        "rejected": sum(entry.decision == "reject" for entry in attempts),
        "inventory": inventory,
        "sidecars": sidecars,
        "append_only": True,
    }


def atomic_write(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    try:
        temp.write_bytes(payload)
        os.replace(temp, path)
    finally:
        if temp.exists():
            temp.unlink()


def acquire_lock(path: Path) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as error:
        raise IntakeError(f"another intake commit may be active; lock exists: {path}") from error
    os.write(descriptor, f"pid={os.getpid()}\ntime={time.time()}\n".encode("ascii"))
    os.close(descriptor)
    return 1


def release_lock(path: Path) -> dict[str, Any] | None:
    """Best-effort cleanup that can never turn a completed commit into failure."""
    try:
        if path.exists():
            path.unlink()
    except OSError as error:
        return {
            "schema_version": 1,
            "kind": "direction4_first_sample_intake_lock_cleanup_warning",
            "committed_state_unchanged": True,
            "lock": str(path),
            "error": str(error),
        }
    return None


def checkpoint_targets(targets: list[Path], checkpoint: Path) -> dict[str, dict[str, Any]]:
    records: dict[str, dict[str, Any]] = {}
    files_root = checkpoint / "files"
    for target in targets:
        key = rel(target)
        exists = target.is_file()
        record = {"path": key, "existed": exists, "sha256": sha256_file(target) if exists else "", "backup": ""}
        if exists:
            backup = files_root / key
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, backup)
            if sha256_file(backup) != record["sha256"]:
                raise IntakeError(f"checkpoint hash mismatch while copying {key}")
            record["backup"] = rel(backup)
        records[key] = record
    checkpoint.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": 1,
        "kind": "direction4_first_sample_precommit_checkpoint",
        "created_epoch": time.time(),
        "targets": list(records.values()),
    }
    (checkpoint / "checkpoint_manifest.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return records


def verify_unchanged(records: dict[str, dict[str, Any]], targets: dict[str, Path]) -> None:
    for key, record in records.items():
        target = targets[key]
        if record["existed"]:
            if not target.is_file() or sha256_file(target) != record["sha256"]:
                raise IntakeError(f"production changed between validation and commit: {key}")
        elif target.exists():
            raise IntakeError(f"a new production collision appeared between validation and commit: {key}")


def restore_checkpoint(records: dict[str, dict[str, Any]], targets: dict[str, Path], checkpoint: Path) -> None:
    failures: list[str] = []
    for key, record in records.items():
        target = targets[key]
        try:
            if record["existed"]:
                backup = checkpoint / "files" / key
                atomic_write(target, backup.read_bytes())
                if sha256_file(target) != record["sha256"]:
                    raise IntakeError("restored hash differs")
            elif target.exists():
                target.unlink()
        except Exception as error:  # best-effort rollback must report every failure
            failures.append(f"{key}: {error}")
    if failures:
        raise IntakeError("rollback was incomplete: " + "; ".join(failures))


def post_commit_coverage_check() -> dict[str, Any]:
    spec = importlib.util.spec_from_file_location("campaign_direction4_coverage_audit", COVERAGE_AUDIT)
    if spec is None or spec.loader is None:
        raise IntakeError("cannot load campaign_direction4_coverage_audit.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    report = module.build_report()
    wanted = set(GROUP_ROWS["heroes"] + GROUP_ROWS["troops"])
    rows = [
        row
        for row in report.get("unique_art_state_contract", [])
        if row.get("art_identity") in wanted and row.get("design_state") in STATES
    ]
    expected = {(identity, state) for identity in wanted for state in STATES}
    actual = {(str(row.get("art_identity")), str(row.get("design_state"))) for row in rows}
    rejected = [
        f"{row.get('art_identity')}:{row.get('design_state')}:{row.get('coverage_status')}"
        for row in rows
        if not row.get("accepted_exact_four_direction")
    ]
    if actual != expected or rejected:
        missing = sorted(expected - actual)
        raise IntakeError(f"post-commit strict coverage rejected the sample; missing={missing}, rejected={rejected}")
    return {
        "accepted_identity_state_rows": len(rows),
        "expected_identity_state_rows": len(expected),
        "coverage_audit_payload_sha256": report.get("deterministic_payload_sha256", ""),
    }


def commit_plan(
    plan: dict[str, Any],
    batches: list[Batch],
    entries: dict[str, SourceEntry],
    source_manifest_path: Path,
    batch_manifest_path: Path,
) -> tuple[Path, dict[str, Any]]:
    # Commit is fail-closed even when this function is called directly rather
    # than through the CLI's development-only dry-run switch.
    load_batches(batch_manifest_path, require_frozen=True)
    if sha256_file(source_manifest_path) != plan["source_manifest_sha256"]:
        raise IntakeError("source manifest changed after validation")
    if sha256_file(batch_manifest_path) != plan["batch_manifest_sha256"]:
        raise IntakeError("prompt batch manifest changed after validation")
    for batch in batches:
        entry = entries[batch.atlas_id]
        if sha256_file(entry.source_path) != plan["_source_hashes"][batch.atlas_id]:
            raise IntakeError(f"{batch.atlas_id}: source PNG changed after validation")
        if sha256_file(batch.prompt_path) != plan["_prompt_hashes"][batch.atlas_id]:
            raise IntakeError(f"{batch.atlas_id}: prompt changed after validation")
    for raw_path, expected_sha in plan["_attempt_hashes"].items():
        path = Path(raw_path)
        if not path.is_file() or sha256_file(path) != expected_sha:
            raise IntakeError(f"attempt source changed after validation: {path}")
    for raw_path, expected_sha in plan["_sidecar_hashes"].items():
        path = Path(raw_path)
        if not path.is_file() or sha256_file(path) != expected_sha:
            raise IntakeError(f"append-only attempt sidecar changed after validation: {path}")
    for target, record in plan["_prestate"].items():
        if bool(record["exists"]) != target.is_file():
            raise IntakeError(f"production collision state changed after validation: {rel(target)}")
        if record["exists"] and sha256_file(target) != record["sha256"]:
            raise IntakeError(f"production file changed after validation: {rel(target)}")

    generated = plan["_generated"]
    production_manifest = plan["_production_manifest"]
    output_keys = {
        (identity, batch.runtime_state, direction)
        for batch in batches
        for identity in batch.rows
        for direction in DIRECTIONS
    }
    new_outputs: list[dict[str, Any]] = []
    new_sources: dict[str, dict[str, Any]] = {}
    writes: dict[Path, bytes] = {}

    for batch in batches:
        entry = entries[batch.atlas_id]
        item = generated[batch.atlas_id]
        source_id = item["source_id"]
        source_archive: Path = item["source_archive"]
        prompt_archive: Path = item["prompt_archive"]
        writes[source_archive] = item["source_payload"]
        writes[prompt_archive] = item["prompt_payload"]
        for reference_archive, reference_payload in zip(
            item["reference_archives"], item["reference_payloads"]
        ):
            writes[reference_archive] = reference_payload
        source_record = dict(item["source_record"])
        source_record.update(
            {
                "file": rel(source_archive),
                "sha256": entry.source_sha256,
                "prompt_file": rel(prompt_archive),
                "prompt_sha256": batch.prompt_sha256,
                "atlas_id": batch.atlas_id,
                "attempt_id": entry.attempt_id,
                "design_state": batch.design_state,
                "runtime_state": batch.runtime_state,
                "decision": entry.decision,
                "review": entry.reason,
                "human_review": entry.human_review,
                "manual_anchor_measurements": list(entry.anchor_measurements),
                "reference_idle_sha256": entry.reference_idle_sha256,
                "references": [
                    {
                        "file": rel(reference_archive),
                        "sha256": reference["sha256"],
                        "purpose": reference["purpose"],
                    }
                    for reference, reference_archive in zip(
                        batch.local_references, item["reference_archives"]
                    )
                ],
                "source_manifest": str(source_manifest_path),
                "source_manifest_sha256": plan["source_manifest_sha256"],
                "batch_manifest": str(batch_manifest_path),
                "batch_manifest_sha256": plan["batch_manifest_sha256"],
                "retained_pixels": (
                    "Whole source cell rectangular crop, uniform scale and transparent padding only; "
                    "no components, mirroring, repainting, masking, foreign-pixel clearing, or pixel invention."
                ),
                "layout": "grid",
                "grid_seam_policy": {"alpha_threshold": 0, "minimum_gap": 24, "search_fraction": 0.22},
            }
        )
        new_sources[source_id] = source_record
        staged_by_key = {
            (str(output.get("unit")), str(output.get("state")), str(output.get("direction"))): output
            for output in item["normalized_outputs"]
        }
        for identity in batch.rows:
            for direction in DIRECTIONS:
                name = f"{identity}_{batch.runtime_state}_{direction}.png"
                target = DEFAULT_OUTPUT_DIR / name
                payload = item["payloads"][name]
                writes[target] = payload
                record = dict(staged_by_key[(identity, batch.runtime_state, direction)])
                record.update(
                    {
                        "output": rel(target),
                        "source": source_id,
                        "sha256": sha256_bytes(payload),
                        "atlas_id": batch.atlas_id,
                        "design_state": batch.design_state,
                        "runtime_state": batch.runtime_state,
                        "retained_pixels": (
                            "Whole source cell rectangular crop copied without in-cell masking; "
                            "uniform scale and transparent padding only."
                        ),
                    }
                )
                new_outputs.append(record)

    updated_manifest = dict(production_manifest)
    updated_manifest["schema_version"] = int(updated_manifest.get("schema_version", 1))
    updated_manifest["sources"] = dict(production_manifest["sources"])
    updated_manifest["sources"].update(new_sources)
    updated_manifest["outputs"] = [
        output
        for output in production_manifest["outputs"]
        if (str(output.get("unit", "")), str(output.get("state", "")), str(output.get("direction", ""))) not in output_keys
    ] + new_outputs
    manifest_payload = (json.dumps(updated_manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    writes[DEFAULT_PRODUCTION_MANIFEST] = manifest_payload

    timestamp = time.strftime("%Y%m%d_%H%M%S", time.localtime()) + f"_{time.time_ns() % 1_000_000_000:09d}"
    checkpoint = DEFAULT_CHECKPOINT_ROOT / timestamp
    target_list = sorted(writes, key=lambda path: str(path).lower())
    target_map = {rel(path): path for path in target_list}
    records = checkpoint_targets(target_list, checkpoint)
    verify_unchanged(records, target_map)
    try:
        for target in target_list:
            atomic_write(target, writes[target])
            if sha256_file(target) != sha256_bytes(writes[target]):
                raise IntakeError(f"post-write hash mismatch: {rel(target)}")
        coverage = post_commit_coverage_check()
        result = {
            "checkpoint_manifest": rel(checkpoint / "checkpoint_manifest.json"),
            "files_written": len(writes),
            "output_pngs_written": len(new_outputs),
            "sources_archived": len(new_sources),
            "production_manifest_sha256": sha256_file(DEFAULT_PRODUCTION_MANIFEST),
            "coverage": coverage,
        }
        atomic_write(
            checkpoint / "commit_result.json",
            (json.dumps(result, ensure_ascii=False, indent=2) + "\n").encode("utf-8"),
        )
    except Exception as error:
        try:
            restore_checkpoint(records, target_map, checkpoint)
        except Exception as rollback_error:
            raise IntakeError(f"commit failed ({error}); rollback also failed ({rollback_error})") from rollback_error
        raise IntakeError(f"commit failed and production was restored from checkpoint: {error}") from error

    return checkpoint, result


_FIXED_NORMALIZER_MODULE: Any | None = None


def load_fixed_normalizer() -> Any:
    """Load the candidate normalizer without making it a production dependency."""
    global _FIXED_NORMALIZER_MODULE
    if _FIXED_NORMALIZER_MODULE is not None:
        return _FIXED_NORMALIZER_MODULE
    spec = importlib.util.spec_from_file_location(
        "direction4_fixed_crop_normalize_for_intake", FIXED_RECT_NORMALIZER
    )
    if spec is None or spec.loader is None:
        raise IntakeError(f"cannot load fixed-cell normalizer: {FIXED_RECT_NORMALIZER}")
    module = importlib.util.module_from_spec(spec)
    # dataclasses resolves the defining module through sys.modules.
    sys.modules[spec.name] = module
    try:
        spec.loader.exec_module(module)
    except (OSError, ImportError, RuntimeError) as error:
        raise IntakeError(f"cannot load fixed-cell normalizer: {error}") from error
    _FIXED_NORMALIZER_MODULE = module
    return module


def candidate_record_path(value: Any, manifest_path: Path, label: str) -> Path:
    raw = str(value).strip()
    if not raw:
        raise IntakeError(f"{label}.path is empty")
    path = Path(raw)
    if path.is_absolute():
        return path.resolve()
    candidates = (
        (ROOT.parent / path).resolve(),
        (ROOT / path).resolve(),
        (manifest_path.parent / path).resolve(),
    )
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    return candidates[0]


def verified_file_record(
    value: Any,
    manifest_path: Path,
    label: str,
    *,
    required: bool,
) -> dict[str, Any] | None:
    if value is None and not required:
        return None
    if not isinstance(value, dict):
        raise IntakeError(f"{label} must be an object" + ("" if required else " or null"))
    path = candidate_record_path(value.get("path", ""), manifest_path, label)
    expected = expect_sha(value.get("sha256"), f"{label}.sha256")
    if not path.is_file():
        raise IntakeError(f"{label} does not exist: {path}")
    actual = sha256_file(path)
    if actual != expected:
        raise IntakeError(f"{label} SHA mismatch: expected {expected}, actual {actual}")
    return {"path": path, "sha256": actual}


def production_candidate_snapshot() -> str:
    """Hash the two direction-art production trees without following outside state."""
    digest = hashlib.sha256()
    roots = (ROOT / "assets/anim", ROOT / "assets/direction4")
    for tree in roots:
        digest.update(tree.relative_to(ROOT).as_posix().encode("utf-8"))
        digest.update(b"\0")
        if not tree.exists():
            digest.update(b"missing\0")
            continue
        for path in sorted(
            (item for item in tree.rglob("*") if item.is_file()),
            key=lambda item: item.relative_to(ROOT).as_posix().casefold(),
        ):
            digest.update(path.relative_to(ROOT).as_posix().encode("utf-8"))
            digest.update(b"\0")
            digest.update(bytes.fromhex(sha256_file(path)))
    return digest.hexdigest()


def colored_fringe_stats(payload: bytes, label: str) -> dict[str, Any]:
    try:
        with Image.open(io.BytesIO(payload)) as opened:
            if opened.format != "PNG" or opened.mode != "RGBA":
                raise IntakeError(f"{label} must remain an RGBA PNG")
            pixels = np.asarray(opened, dtype=np.uint8)
    except OSError as error:
        raise IntakeError(f"cannot inspect {label}: {error}") from error
    rgb = pixels[:, :, :3].astype(np.int16)
    alpha = pixels[:, :, 3]
    border = np.concatenate((alpha[0], alpha[-1], alpha[:, 0], alpha[:, -1]))
    semitransparent = (alpha > 0) & (alpha < 255)
    low_alpha = (alpha > 0) & (alpha <= int(FRINGE_POLICY["low_alpha_max"]))
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    suspect = low_alpha & (chroma >= int(FRINGE_POLICY["high_chroma_min"]))
    semitransparent_count = int(np.count_nonzero(semitransparent))
    suspect_count = int(np.count_nonzero(suspect))
    ratio = suspect_count / semitransparent_count if semitransparent_count else 0.0
    suspect_rgb = rgb[suspect]
    dominant = {"red": 0, "green": 0, "blue": 0, "tied": 0}
    if suspect_rgb.size:
        maximum = suspect_rgb.max(axis=1, keepdims=True)
        is_maximum = suspect_rgb == maximum
        unique = is_maximum.sum(axis=1) == 1
        dominant["red"] = int(np.count_nonzero(unique & is_maximum[:, 0]))
        dominant["green"] = int(np.count_nonzero(unique & is_maximum[:, 1]))
        dominant["blue"] = int(np.count_nonzero(unique & is_maximum[:, 2]))
        dominant["tied"] = int(np.count_nonzero(~unique))
    threshold_exceeded = bool(
        suspect_count > int(FRINGE_POLICY["review_count_per_frame"])
        or ratio > float(FRINGE_POLICY["review_ratio_of_semitransparent"])
    )
    return {
        "semitransparent_pixels": semitransparent_count,
        "low_alpha_pixels": int(np.count_nonzero(low_alpha)),
        "low_alpha_high_chroma_pixels": suspect_count,
        "low_alpha_high_chroma_ratio_of_semitransparent": round(ratio, 8),
        "suspect_dominant_channel_counts": dominant,
        "canvas_border_max_alpha": int(border.max()) if border.size else 0,
        "threshold_exceeded": threshold_exceeded,
        "result": "manual_visual_review_required" if threshold_exceeded else "no_threshold_trigger",
        "automatic_pixel_clearing_performed": False,
        "automatic_adoption_granted": False,
    }


def validate_fixed_row_replacements(
    data: dict[str, Any],
    provenance_path: Path,
    fixed: Any,
) -> list[dict[str, Any]]:
    """Validate candidate-only four-direction rows that override one base-atlas row."""
    raw_rows = data.get("row_replacements")
    if not isinstance(raw_rows, list) or len(raw_rows) != len(FIXED_ROW_REPLACEMENT_IDS):
        raise IntakeError(
            f"fixed-cell provenance must contain exactly {len(FIXED_ROW_REPLACEMENT_IDS)} reviewed row replacement"
        )
    if tuple(str(item.get("replacement_id", "")) for item in raw_rows if isinstance(item, dict)) != FIXED_ROW_REPLACEMENT_IDS:
        raise IntakeError("fixed-cell row replacements are missing or out of reviewed order")
    if not all(isinstance(item, dict) for item in raw_rows):
        raise IntakeError("every fixed-cell row replacement must be an object")

    reports: list[dict[str, Any]] = []
    for raw in raw_rows:
        replacement_id = str(raw.get("replacement_id", ""))
        label = f"fixed_row_replacement.{replacement_id}"
        if (
            raw.get("source_rule") != SOURCE_RULE_FIXED_DIRECTION_ROW_RECT
            or raw.get("status") != "adoption_candidate_pending_manual_visual_review"
            or raw.get("adoption_approved") is not False
            or raw.get("replaces") != FIXED_ROW_REPLACEMENT_TARGET
            or raw.get("campaign_scope") != FIXED_ROW_REPLACEMENT_CAMPAIGN_SCOPE
        ):
            raise IntakeError(f"{label}: source rule, target row, campaign scope, or status differs from the reviewed contract")

        source_path = source_path_from(raw.get("source_png"), provenance_path, replacement_id)
        expected_raw_sha = expect_sha(raw.get("raw_sha256"), f"{label}.raw_sha256")
        if not source_path.is_file() or sha256_file(source_path) != expected_raw_sha:
            raise IntakeError(f"{label}: raw source is missing or its SHA has drifted")
        declared_size = raw.get("size")
        if (
            not isinstance(declared_size, list)
            or len(declared_size) != 2
            or not all(isinstance(item, int) and not isinstance(item, bool) and item > 0 for item in declared_size)
        ):
            raise IntakeError(f"{label}.size must be [positive_width, positive_height]")
        try:
            with Image.open(source_path) as opened:
                source_format, source_mode, source_size = opened.format, opened.mode, list(opened.size)
                raw_rgba = opened.copy()
        except OSError as error:
            raise IntakeError(f"{label}: cannot read raw source: {error}") from error
        if source_format != "PNG" or source_mode != "RGBA" or source_size != declared_size:
            raise IntakeError(f"{label}: raw source must be the declared-size true RGBA PNG")

        conversation_url = stable_conversation_url(raw.get("conversation_url"), f"{label}.conversation_url")
        base_prompt = verified_file_record(raw.get("base_prompt"), provenance_path, f"{label}.base_prompt", required=True)
        correction_prompt = verified_file_record(
            raw.get("correction_prompt"), provenance_path, f"{label}.correction_prompt", required=True
        )
        crop_spec = verified_file_record(raw.get("crop_spec"), provenance_path, f"{label}.crop_spec", required=True)
        candidate_record = verified_file_record(
            raw.get("candidate_manifest"), provenance_path, f"{label}.candidate_manifest", required=True
        )
        assert base_prompt is not None and correction_prompt is not None and crop_spec is not None and candidate_record is not None

        review = raw.get("human_review")
        if not isinstance(review, dict) or set(review) != set(FIXED_CANDIDATE_REVIEW_FLAGS):
            raise IntakeError(f"{label}.human_review must contain the exact fixed-candidate review flags")
        required_truth = (
            "rows_and_identities_confirmed",
            "directions_se_sw_ne_nw_confirmed",
            "not_mirrored_confirmed",
            "complete_body_and_weapon_confirmed",
            "no_cross_cell_content_confirmed",
            "equipment_and_action_confirmed",
            "state_identity_consistent_confirmed",
        )
        if any(review.get(flag) is not True for flag in required_truth):
            raise IntakeError(f"{label}: direction, equipment, action, identity, or crop review is incomplete")
        if any(not isinstance(review.get(flag), bool) for flag in FIXED_CANDIDATE_REVIEW_FLAGS):
            raise IntakeError(f"{label}.human_review flags must be explicit booleans")
        review_note = concrete_reason(raw.get("review_note"), label)
        if "wu_song_mengzhou" not in review_note:
            raise IntakeError(f"{label}: review note must preserve the Mengzhou variant exclusion")

        manifest_path = candidate_record["path"]
        manifest = load_json(manifest_path, f"{label}.candidate_manifest")
        if (
            manifest.get("schema_version") != 1
            or manifest.get("kind") != "direction4_fixed_rect_candidate_manifest"
            or manifest.get("source_rule") != SOURCE_RULE_FIXED_DIRECTION_ROW_RECT
            or manifest.get("candidate_only") is not True
            or manifest.get("production_commit_allowed") is not False
            or manifest.get("adoption_status") != "pending_manual_visual_review"
            or manifest.get("production_assets_modified") is not False
        ):
            raise IntakeError(f"{label}: row manifest is not a candidate-only fixed-direction row artifact")
        outputs = manifest.get("outputs")
        if not isinstance(outputs, list) or len(outputs) != 4:
            raise IntakeError(f"{label}: row manifest must contain exactly four outputs")
        expected_keys = [("wu_song", "attack", direction) for direction in DIRECTIONS]
        actual_keys = [
            (str(item.get("unit", "")), str(item.get("state", "")), str(item.get("direction", "")))
            for item in outputs
            if isinstance(item, dict)
        ]
        if actual_keys != expected_keys:
            raise IntakeError(f"{label}: row outputs do not match generic Wu Song attack SE/SW/NE/NW")
        output_paths = [
            candidate_record_path(item.get("output", ""), manifest_path, f"{label}.output")
            for item in outputs
        ]
        if len(set(output_paths)) != 4 or len({path.parent for path in output_paths}) != 1:
            raise IntakeError(f"{label}: row outputs must be four unique PNGs in one candidate directory")
        output_dir = output_paths[0].parent
        try:
            fixed.candidate_path_guard(output_dir, f"{label}.output_dir")
            fixed.candidate_path_guard(manifest_path, f"{label}.candidate_manifest")
            reproduced_manifest, reproduced_writes = fixed.prepare_candidate(
                source_path, crop_spec["path"], output_dir, manifest_path
            )
        except fixed.NormalizeError as error:
            raise IntakeError(f"{label}: fixed-row reproduction failed: {error}") from error
        if reproduced_manifest != manifest:
            raise IntakeError(f"{label}: saved row manifest is not the deterministic normalization result")
        reproduced_by_path = {path.resolve(): payload for path, payload in reproduced_writes}
        if set(reproduced_by_path) != {path.resolve() for path in output_paths}:
            raise IntakeError(f"{label}: deterministic row output set differs from the declared set")
        actual_pngs = {path.resolve() for path in output_dir.glob("*.png") if path.is_file()}
        if actual_pngs != set(reproduced_by_path):
            raise IntakeError(f"{label}: row candidate directory contains missing or unlisted PNG outputs")

        frame_reports: list[dict[str, Any]] = []
        scales: set[float] = set()
        for output, output_path in zip(outputs, output_paths):
            payload = reproduced_by_path[output_path.resolve()]
            if not output_path.is_file() or output_path.read_bytes() != payload:
                raise IntakeError(f"{label}: row candidate PNG differs from deterministic reproduction")
            if output.get("output_sha256") != sha256_bytes(payload):
                raise IntakeError(f"{label}: output SHA mismatch for {output_path.name}")
            rect = output.get("crop_rect")
            if not isinstance(rect, list) or len(rect) != 4 or not all(isinstance(value, int) for value in rect):
                raise IntakeError(f"{label}: invalid crop rectangle for {output_path.name}")
            x, y, width, height = rect
            if output.get("raw_crop_rgba_sha256") != fixed.rgba_sha256(
                raw_rgba.crop((x, y, x + width, y + height))
            ):
                raise IntakeError(f"{label}: raw crop pixel proof drifted for {output_path.name}")
            component_qa = output.get("read_only_component_qa")
            anchor = output.get("semantic_anchor")
            if (
                not isinstance(component_qa, dict)
                or component_qa.get("visible_component_complete") is not True
                or component_qa.get("foreign_large_visible_pixels") != 0
                or output.get("forbidden_operations_used") != []
                or not isinstance(anchor, dict)
                or anchor.get("placed_output_y_px") != 210
            ):
                raise IntakeError(f"{label}: completeness, isolation, operation, or anchor proof failed")
            scale = output.get("scale")
            if not isinstance(scale, (int, float)) or isinstance(scale, bool) or scale <= 0:
                raise IntakeError(f"{label}: row scale is invalid")
            scales.add(float(scale))
            fringe = colored_fringe_stats(payload, f"{label}:{output_path.name}")
            if fringe["canvas_border_max_alpha"] != 0:
                raise IntakeError(f"{label}: output canvas border is not transparent")
            frame_reports.append(
                {
                    "unit": output["unit"],
                    "state": output["state"],
                    "direction": output["direction"],
                    "source_slot": output["source_slot"],
                    "crop_rect": rect,
                    "raw_crop_rgba_sha256": output["raw_crop_rgba_sha256"],
                    "scale": scale,
                    "pre_scale_transparent_padding": output["pre_scale_transparent_padding"],
                    "final_transparent_padding": output["final_transparent_padding"],
                    "output_sha256": output["output_sha256"],
                    "complete_visible_body_retained": True,
                    "foreign_large_visible_pixels": 0,
                    "fringe": fringe,
                }
            )
        if len(scales) != 1:
            raise IntakeError(f"{label}: four directions must use one whole-row uniform scale")
        reproduction_sha = canonical_value_sha256(
            [
                {
                    "raw_crop_rgba_sha256": item["raw_crop_rgba_sha256"],
                    "scale": item["scale"],
                    "pre_scale_transparent_padding": item["pre_scale_transparent_padding"],
                    "final_transparent_padding": item["final_transparent_padding"],
                    "output_sha256": item["output_sha256"],
                }
                for item in frame_reports
            ]
        )
        threshold_frames = sum(1 for item in frame_reports if item["fringe"]["threshold_exceeded"])
        reports.append(
            {
                "replacement_id": replacement_id,
                "source_rule": SOURCE_RULE_FIXED_DIRECTION_ROW_RECT,
                "status": "adoption_candidate_pending_manual_visual_review",
                "replaces": raw["replaces"],
                "campaign_scope": raw["campaign_scope"],
                "raw_source": rel(source_path),
                "raw_sha256": expected_raw_sha,
                "conversation_url": conversation_url,
                "base_prompt": {"file": rel(base_prompt["path"]), "sha256": base_prompt["sha256"]},
                "correction_prompt": {"file": rel(correction_prompt["path"]), "sha256": correction_prompt["sha256"]},
                "crop_spec": {"file": rel(crop_spec["path"]), "sha256": crop_spec["sha256"]},
                "candidate_manifest": {"file": rel(manifest_path), "sha256": candidate_record["sha256"]},
                "review_note": review_note,
                "human_review": review,
                "deterministic_output_reproduction": True,
                "output_pixel_source_proof_sha256": reproduction_sha,
                "fringe_threshold_frames": threshold_frames,
                "manual_visual_review_required": bool(
                    threshold_frames
                    or review["historical_equipment_and_original_text_approved"] is not True
                    or review["fringe_review_completed"] is not True
                ),
                "adoption_approved": False,
                "production_commit_eligible": False,
                "frames": frame_reports,
            }
        )
    return reports


def validate_fixed_blocked_attempts(
    data: dict[str, Any],
    provenance_path: Path,
    batch_by_id: dict[str, Batch],
    fixed: Any,
) -> list[dict[str, Any]]:
    """Retain rejected/blocked attack provenance without treating it as art."""
    attempts = data.get("blocked_attempts")
    if not isinstance(attempts, list) or len(attempts) != len(FIXED_BLOCKED_ATTEMPT_IDS):
        raise IntakeError(
            f"fixed-cell provenance must retain exactly {len(FIXED_BLOCKED_ATTEMPT_IDS)} reviewed blocked attempts"
        )
    if tuple(str(item.get("attempt_id", "")) for item in attempts if isinstance(item, dict)) != FIXED_BLOCKED_ATTEMPT_IDS:
        raise IntakeError("fixed-cell blocked attempts are missing or out of reviewed order")
    if not all(isinstance(item, dict) for item in attempts):
        raise IntakeError("every fixed-cell blocked attempt must be an object")
    reports: list[dict[str, Any]] = []
    for attempt in attempts:
        attempt_id = str(attempt["attempt_id"])
        label = f"fixed_blocked.{attempt_id}"
        atlas_id = str(attempt.get("atlas_id", ""))
        batch = batch_by_id.get(atlas_id)
        if (
            batch is None
            or attempt.get("source_rule") != SOURCE_RULE_FIXED_CELL_RECT
            or attempt.get("candidate_generated") is not False
            or attempt.get("adoption_approved") is not False
        ):
            raise IntakeError(f"{label}: blocked attempt may not be represented as a candidate")
        source_path = source_path_from(attempt.get("source_png"), provenance_path, attempt_id)
        source_sha = expect_sha(attempt.get("raw_sha256"), f"{label}.raw_sha256")
        if not source_path.is_file() or sha256_file(source_path) != source_sha:
            raise IntakeError(f"{label}: raw source is missing or its SHA has drifted")
        conversation_url = stable_conversation_url(attempt.get("conversation_url"), f"{label}.conversation_url")
        base_prompt = verified_file_record(
            attempt.get("base_prompt"), provenance_path, f"{label}.base_prompt", required=True
        )
        correction_prompt = verified_file_record(
            attempt.get("correction_prompt"), provenance_path, f"{label}.correction_prompt", required=False
        )
        assert base_prompt is not None
        if base_prompt["path"].resolve() != batch.prompt_path.resolve() or base_prompt["sha256"] != batch.prompt_sha256:
            raise IntakeError(f"{label}: base prompt is not the frozen prompt for {atlas_id}")
        reason = concrete_reason(attempt.get("reason"), label)
        try:
            with Image.open(source_path) as opened:
                if opened.format != "PNG" or opened.mode != "RGBA" or list(opened.size) != attempt.get("size"):
                    raise IntakeError(f"{label}: blocked raw source must remain the declared-size RGBA PNG")
                rgba = np.asarray(opened.copy())
        except OSError as error:
            raise IntakeError(f"{label}: cannot read blocked raw source: {error}") from error

        if attempt_id == "sample_heroes_attack_attempt1":
            blocked_review = attempt.get("human_review")
            if (
                attempt.get("decision") != "rejected_human_action_mismatch"
                or not isinstance(blocked_review, dict)
                or blocked_review.get("wu_song_unarmed_four_directions_confirmed") is not False
                or blocked_review.get("review_completed") is not True
            ):
                raise IntakeError(f"{label}: attempt 1 must preserve the reviewed Wu Song drawn-blades rejection")
            geometry_report = None
            content_review = blocked_review
        else:
            if attempt.get("decision") != "blocked_fixed_rect_cross_cell_overlap":
                raise IntakeError(f"{label}: attempt must preserve the fixed-rectangle cross-cell blocker")
            try:
                labels, rows = fixed.visible_components(rgba[:, :, 3], 6, 500)
            except fixed.NormalizeError as error:
                raise IntakeError(f"{label}: cannot reproduce blocker geometry: {error}") from error
            pair = FIXED_BLOCKED_GEOMETRY_CELLS.get(attempt_id)
            if pair is None:
                raise IntakeError(f"{label}: no reviewed cross-cell pair is registered")
            (first_row, first_column, first_unit, first_direction), (
                second_row,
                second_column,
                second_unit,
                second_direction,
            ) = pair
            first = rows[first_row][first_column]
            second = rows[second_row][second_column]
            fx0, fy0, fx1, fy1 = first.bbox
            sx0, sy0, sx1, sy1 = second.bbox
            foreign_in_first = int(np.count_nonzero(labels[fy0:fy1, fx0:fx1] == second.component_id))
            foreign_in_second = int(np.count_nonzero(labels[sy0:sy1, sx0:sx1] == first.component_id))
            overlap = [max(fx0, sx0), max(fy0, sy0), min(fx1, sx1), min(fy1, sy1)]
            geometry_report = {
                "visible_alpha_threshold": 6,
                "minimum_component_pixels": 500,
                "first_cell": {
                    "unit": first_unit,
                    "direction": first_direction,
                    "source_slot": [first_row, first_column],
                    "complete_component_bbox_xyxy": list(first.bbox),
                    "component_pixels": first.pixels,
                    "second_cell_visible_pixels_inside_required_rect": foreign_in_first,
                },
                "second_cell": {
                    "unit": second_unit,
                    "direction": second_direction,
                    "source_slot": [second_row, second_column],
                    "complete_component_bbox_xyxy": list(second.bbox),
                    "component_pixels": second.pixels,
                    "first_cell_visible_pixels_inside_required_rect": foreign_in_second,
                },
                "bbox_overlap_xyxy": overlap,
                "complete_fixed_rect_isolation_possible": False,
                "only_possible_workaround": "mask_or_clear_foreign_source_pixels",
                "workaround_forbidden": True,
            }
            if attempt.get("geometry_evidence") != geometry_report:
                raise IntakeError(f"{label}: declared blocker bbox/pixel evidence differs from the raw source")
            if not foreign_in_first or not foreign_in_second:
                raise IntakeError(f"{label}: expected cross-cell visible-pixel overlap is absent")
            content_review = attempt.get("content_review")
            if (
                not isinstance(content_review, dict)
                or not content_review
                or any(not isinstance(value, bool) for value in content_review.values())
            ):
                raise IntakeError(f"{label}: blocked source must retain explicit semantic/equipment review booleans")
        reports.append(
            {
                "attempt_id": attempt_id,
                "atlas_id": batch.atlas_id,
                "decision": attempt["decision"],
                "reason": reason,
                "raw_source": rel(source_path),
                "raw_sha256": source_sha,
                "conversation_url": conversation_url,
                "base_prompt": {"file": rel(base_prompt["path"]), "sha256": base_prompt["sha256"]},
                "correction_prompt": None
                if correction_prompt is None
                else {"file": rel(correction_prompt["path"]), "sha256": correction_prompt["sha256"]},
                "geometry_evidence": geometry_report,
                "content_review": content_review,
                "candidate_generated": False,
                "adoption_approved": False,
                "production_assets_modified": False,
            }
        )
    return reports


def validate_fixed_candidate_manifest(
    provenance_path: Path,
    batch_manifest_path: Path,
) -> dict[str, Any]:
    """Validate reproducible fixed-cell candidates; never expose a commit path."""
    production_before = production_candidate_snapshot()
    data = load_json(provenance_path, "fixed-cell candidate provenance manifest")
    if (
        data.get("schema_version") != 1
        or data.get("kind") != "web_chatgpt_direction4_fixed_cell_rect_candidates_v1"
        or data.get("candidate_only") is not True
        or data.get("production_commit_allowed") is not False
        or tuple(data.get("supported_source_rules", [])) != SUPPORTED_SOURCE_RULES
        or data.get("active_source_rule") != SOURCE_RULE_FIXED_CELL_RECT
    ):
        raise IntakeError("fixed-cell candidate provenance manifest uses an unsupported or production-capable schema")
    if data.get("fringe_policy") != FRINGE_POLICY:
        raise IntakeError("fixed-cell candidate fringe policy differs from the reviewed manual-review-only contract")
    if data.get("campaign_variant_scope_gate") != FIXED_CAMPAIGN_VARIANT_SCOPE_GATE:
        raise IntakeError("fixed-cell candidates must retain the reviewed campaign-variant scope exclusions")
    if data.get("runtime_mapping_gate") != FIXED_RUNTIME_MAPPING_GATE:
        raise IntakeError("fixed-cell candidates must retain the reviewed runtime-mapping production blockers")

    _, batches = load_batches(batch_manifest_path, require_frozen=True)
    batch_sha = sha256_file(batch_manifest_path)
    frozen_batch_sha = expect_sha(
        load_frozen_registry()["canonical_batch_manifest"].get("sha256"),
        "frozen_registry.canonical_batch_manifest.sha256",
    )
    if batch_sha != frozen_batch_sha or data.get("frozen_batch_manifest_sha256") != frozen_batch_sha:
        raise IntakeError("fixed-cell candidate provenance must bind the exact frozen batch-manifest SHA")
    batch_by_id = {batch.atlas_id: batch for batch in batches}
    raw_entries = data.get("entries")
    if not isinstance(raw_entries, list) or len(raw_entries) != len(FIXED_CANDIDATE_ATLAS_IDS):
        raise IntakeError(
            f"fixed-cell candidate provenance must contain exactly {len(FIXED_CANDIDATE_ATLAS_IDS)} reviewed entries"
        )
    if tuple(str(item.get("atlas_id", "")) for item in raw_entries if isinstance(item, dict)) != FIXED_CANDIDATE_ATLAS_IDS:
        raise IntakeError("fixed-cell candidate entries must follow the reviewed idle-then-walk atlas order")
    if not all(isinstance(item, dict) for item in raw_entries):
        raise IntakeError("every fixed-cell candidate entry must be an object")

    fixed = load_fixed_normalizer()
    row_replacement_reports = validate_fixed_row_replacements(data, provenance_path, fixed)
    blocked_reports = validate_fixed_blocked_attempts(data, provenance_path, batch_by_id, fixed)
    raw_by_id = {str(item["atlas_id"]): item for item in raw_entries}
    atlas_reports: list[dict[str, Any]] = []
    for raw_entry in raw_entries:
        atlas_id = str(raw_entry.get("atlas_id", ""))
        batch = batch_by_id.get(atlas_id)
        if batch is None:
            raise IntakeError(f"{atlas_id}: atlas is absent from the frozen prompt pack")
        label = f"fixed_candidate.{atlas_id}"
        if (
            raw_entry.get("source_rule") != SOURCE_RULE_FIXED_CELL_RECT
            or raw_entry.get("status") != "adoption_candidate_pending_manual_visual_review"
            or raw_entry.get("adoption_approved") is not False
            or raw_entry.get("group") != batch.group
            or raw_entry.get("design_state") != batch.design_state
            or raw_entry.get("runtime_state") != batch.runtime_state
            or tuple(raw_entry.get("rows", [])) != batch.rows
            or tuple(raw_entry.get("directions", [])) != DIRECTIONS
        ):
            raise IntakeError(f"{label}: source rule, status, batch identity, rows, or directions differ from the reviewed contract")
        source_path = source_path_from(raw_entry.get("source_png"), provenance_path, atlas_id)
        expected_raw_sha = expect_sha(raw_entry.get("raw_sha256"), f"{label}.raw_sha256")
        if not source_path.is_file() or sha256_file(source_path) != expected_raw_sha:
            raise IntakeError(f"{label}: raw source is missing or its SHA has drifted")
        declared_size = raw_entry.get("size")
        if (
            not isinstance(declared_size, list)
            or len(declared_size) != 2
            or not all(isinstance(item, int) and not isinstance(item, bool) and item > 0 for item in declared_size)
        ):
            raise IntakeError(f"{label}.size must be [positive_width, positive_height]")
        try:
            with Image.open(source_path) as opened:
                source_format, source_mode, source_size = opened.format, opened.mode, list(opened.size)
        except OSError as error:
            raise IntakeError(f"{label}: cannot read raw source: {error}") from error
        if source_format != "PNG" or source_mode != "RGBA" or source_size != declared_size:
            raise IntakeError(f"{label}: raw source must be the declared-size true RGBA PNG")
        conversation_url = stable_conversation_url(raw_entry.get("conversation_url"), f"{label}.conversation_url")

        base_prompt = verified_file_record(
            raw_entry.get("base_prompt"), provenance_path, f"{label}.base_prompt", required=True
        )
        correction_prompt = verified_file_record(
            raw_entry.get("correction_prompt"), provenance_path, f"{label}.correction_prompt", required=False
        )
        assert base_prompt is not None
        if base_prompt["path"].resolve() != batch.prompt_path.resolve() or base_prompt["sha256"] != batch.prompt_sha256:
            raise IntakeError(f"{label}: base prompt is not the frozen prompt for this atlas")
        crop_spec = verified_file_record(
            raw_entry.get("crop_spec"), provenance_path, f"{label}.crop_spec", required=True
        )
        candidate_manifest_record = verified_file_record(
            raw_entry.get("candidate_manifest"), provenance_path, f"{label}.candidate_manifest", required=True
        )
        assert crop_spec is not None and candidate_manifest_record is not None

        review = raw_entry.get("human_review")
        if not isinstance(review, dict) or set(review) != set(FIXED_CANDIDATE_REVIEW_FLAGS):
            raise IntakeError(f"{label}.human_review must contain the exact fixed-candidate review flags")
        if any(not isinstance(review.get(flag), bool) for flag in FIXED_CANDIDATE_REVIEW_FLAGS):
            raise IntakeError(f"{label}.human_review flags must be explicit booleans")
        required_candidate_truth = (
            "rows_and_identities_confirmed",
            "directions_se_sw_ne_nw_confirmed",
            "not_mirrored_confirmed",
            "complete_body_and_weapon_confirmed",
            "no_cross_cell_content_confirmed",
            "equipment_and_action_confirmed",
            "state_identity_consistent_confirmed",
        )
        if any(review[flag] is not True for flag in required_candidate_truth):
            raise IntakeError(f"{label}: geometry, direction, action, or identity review is not complete enough for a candidate")
        review_note = concrete_reason(raw_entry.get("review_note"), label)

        reference_idle_sha = str(raw_entry.get("reference_idle_sha256", "")).lower()
        if batch.design_state == "idle":
            if reference_idle_sha:
                raise IntakeError(f"{label}: idle candidates may not bind another idle source")
        else:
            idle_id = batch.idle_reference_atlas
            idle_entry = raw_by_id.get(idle_id)
            if idle_entry is None:
                raise IntakeError(f"{label}: required idle candidate {idle_id} is missing")
            expected_idle_sha = expect_sha(idle_entry.get("raw_sha256"), f"{idle_id}.raw_sha256")
            if reference_idle_sha != expected_idle_sha:
                raise IntakeError(f"{label}: later-state candidate does not bind the selected idle raw SHA")
            idle_url = stable_conversation_url(idle_entry.get("conversation_url"), f"{idle_id}.conversation_url")
            if conversation_url != idle_url:
                raise IntakeError(f"{label}: later-state candidate must come from the selected idle conversation")

        candidate_manifest_path = candidate_manifest_record["path"]
        candidate_manifest = load_json(candidate_manifest_path, f"{label}.candidate_manifest")
        if (
            candidate_manifest.get("schema_version") != 1
            or candidate_manifest.get("kind") != "direction4_fixed_rect_candidate_manifest"
            or candidate_manifest.get("source_rule") != SOURCE_RULE_FIXED_CELL_RECT
            or candidate_manifest.get("candidate_only") is not True
            or candidate_manifest.get("production_commit_allowed") is not False
            or candidate_manifest.get("adoption_status") != "pending_manual_visual_review"
            or candidate_manifest.get("production_assets_modified") is not False
        ):
            raise IntakeError(f"{label}: normalization manifest is not a fixed-cell, candidate-only artifact")
        outputs = candidate_manifest.get("outputs")
        if not isinstance(outputs, list) or len(outputs) != 16:
            raise IntakeError(f"{label}: normalization manifest must contain 16 outputs")
        expected_keys = [
            (identity, batch.runtime_state, direction)
            for identity in batch.rows
            for direction in DIRECTIONS
        ]
        actual_keys = [
            (str(output.get("unit", "")), str(output.get("state", "")), str(output.get("direction", "")))
            for output in outputs
            if isinstance(output, dict)
        ]
        if actual_keys != expected_keys:
            raise IntakeError(f"{label}: candidate outputs do not match the exact 4x4 batch grid")
        output_paths = [
            candidate_record_path(output.get("output", ""), candidate_manifest_path, f"{label}.output")
            for output in outputs
        ]
        if len({path.parent for path in output_paths}) != 1 or len(set(output_paths)) != 16:
            raise IntakeError(f"{label}: candidate outputs must be 16 unique PNGs in one candidate directory")
        output_dir = output_paths[0].parent
        try:
            fixed.candidate_path_guard(output_dir, f"{label}.output_dir")
            fixed.candidate_path_guard(candidate_manifest_path, f"{label}.candidate_manifest")
            reproduced_manifest, reproduced_writes = fixed.prepare_candidate(
                source_path, crop_spec["path"], output_dir, candidate_manifest_path
            )
        except fixed.NormalizeError as error:
            raise IntakeError(f"{label}: fixed-cell reproduction failed: {error}") from error
        if reproduced_manifest != candidate_manifest:
            raise IntakeError(f"{label}: saved candidate manifest is not the deterministic normalization result")
        reproduced_by_path = {path.resolve(): payload for path, payload in reproduced_writes}
        if set(reproduced_by_path) != {path.resolve() for path in output_paths}:
            raise IntakeError(f"{label}: deterministic reproduction output set differs from the declared set")
        actual_pngs = {path.resolve() for path in output_dir.glob("*.png") if path.is_file()}
        if actual_pngs != set(reproduced_by_path):
            raise IntakeError(f"{label}: candidate directory contains missing or unlisted PNG outputs")

        with Image.open(source_path) as raw_image:
            raw_rgba = raw_image.copy()
        frame_reports: list[dict[str, Any]] = []
        row_scales: dict[int, set[float]] = {row: set() for row in range(4)}
        for output, output_path in zip(outputs, output_paths):
            payload = reproduced_by_path[output_path.resolve()]
            if not output_path.is_file() or output_path.read_bytes() != payload:
                raise IntakeError(f"{label}: candidate PNG differs from deterministic whole-crop reproduction: {output_path}")
            if output.get("output_sha256") != sha256_bytes(payload):
                raise IntakeError(f"{label}: output SHA mismatch for {output_path.name}")
            rect = output.get("crop_rect")
            if not isinstance(rect, list) or len(rect) != 4 or not all(isinstance(value, int) for value in rect):
                raise IntakeError(f"{label}: invalid crop rectangle for {output_path.name}")
            x, y, width, height = rect
            raw_crop_hash = fixed.rgba_sha256(raw_rgba.crop((x, y, x + width, y + height)))
            qa = output.get("read_only_component_qa")
            anchor = output.get("semantic_anchor")
            if (
                output.get("source_rule") != SOURCE_RULE_FIXED_CELL_RECT
                or output.get("raw_crop_rgba_sha256") != raw_crop_hash
                or output.get("source_to_crop_operation")
                != "one fixed rectangular crop; every RGBA pixel in the rectangle is retained"
                or output.get("scale_scope") != "uniform_across_identity_row"
                or output.get("forbidden_operations_used") != []
                or not isinstance(qa, dict)
                or qa.get("visible_component_complete") is not True
                or qa.get("visible_component_pixels") != qa.get("visible_component_pixels_retained")
                or qa.get("foreign_large_visible_pixels") != 0
                or not isinstance(anchor, dict)
                or anchor.get("placed_output_y_px") != 210
            ):
                raise IntakeError(f"{label}: pixel-source, whole-body, cross-cell, scale, or anchor proof failed for {output_path.name}")
            slot = output.get("source_slot")
            if not isinstance(slot, list) or len(slot) != 2 or slot[0] not in row_scales:
                raise IntakeError(f"{label}: invalid source slot for {output_path.name}")
            row_scales[int(slot[0])].add(float(output.get("scale")))
            fringe = colored_fringe_stats(payload, f"{label}:{output_path.name}")
            if fringe["canvas_border_max_alpha"] != 0:
                raise IntakeError(f"{label}: final transparent padding is not transparent for {output_path.name}")
            frame_reports.append(
                {
                    "unit": output["unit"],
                    "state": output["state"],
                    "direction": output["direction"],
                    "source_slot": output["source_slot"],
                    "crop_rect": rect,
                    "raw_crop_rgba_sha256": raw_crop_hash,
                    "scale": output["scale"],
                    "pre_scale_transparent_padding": output["pre_scale_transparent_padding"],
                    "final_transparent_padding": output["final_transparent_padding"],
                    "output_sha256": output["output_sha256"],
                    "complete_visible_body_retained": True,
                    "foreign_large_visible_pixels": 0,
                    "fringe": fringe,
                }
            )
        if any(len(scales) != 1 for scales in row_scales.values()):
            raise IntakeError(f"{label}: normalization does not use one uniform whole-unit scale per identity row")
        candidate_reproduction_sha = canonical_value_sha256(
            [
                {
                    "raw_crop_rgba_sha256": item["raw_crop_rgba_sha256"],
                    "scale": item["scale"],
                    "pre_scale_transparent_padding": item["pre_scale_transparent_padding"],
                    "final_transparent_padding": item["final_transparent_padding"],
                    "output_sha256": item["output_sha256"],
                }
                for item in frame_reports
            ]
        )
        threshold_frames = sum(1 for item in frame_reports if item["fringe"]["threshold_exceeded"])
        atlas_reports.append(
            {
                "atlas_id": atlas_id,
                "source_rule": SOURCE_RULE_FIXED_CELL_RECT,
                "status": "adoption_candidate_pending_manual_visual_review",
                "raw_source": rel(source_path),
                "raw_sha256": expected_raw_sha,
                "conversation_url": conversation_url,
                "base_prompt": {"file": rel(base_prompt["path"]), "sha256": base_prompt["sha256"]},
                "correction_prompt": None
                if correction_prompt is None
                else {"file": rel(correction_prompt["path"]), "sha256": correction_prompt["sha256"]},
                "crop_spec": {"file": rel(crop_spec["path"]), "sha256": crop_spec["sha256"]},
                "candidate_manifest": {
                    "file": rel(candidate_manifest_path),
                    "sha256": candidate_manifest_record["sha256"],
                },
                "reference_idle_sha256": reference_idle_sha,
                "review_note": review_note,
                "human_review": review,
                "deterministic_output_reproduction": True,
                "output_pixel_source_proof_sha256": candidate_reproduction_sha,
                "fringe_threshold_frames": threshold_frames,
                "manual_visual_review_required": bool(
                    threshold_frames
                    or review["historical_equipment_and_original_text_approved"] is not True
                    or review["fringe_review_completed"] is not True
                ),
                "adoption_approved": False,
                "production_commit_eligible": False,
                "frames": frame_reports,
            }
        )

    production_after = production_candidate_snapshot()
    if production_after != production_before:
        raise IntakeError("fixed-cell candidate validation changed production direction-art assets")
    report = {
        "schema_version": 1,
        "kind": "direction4_fixed_cell_rect_candidate_intake_report",
        "source_rule": SOURCE_RULE_FIXED_CELL_RECT,
        "supported_source_rules": list(SUPPORTED_SOURCE_RULES),
        "provenance_validation_passed": True,
        "normalization_reproducible": True,
        "candidate_only": True,
        "adoption_approved": False,
        "adoption_decision": "pending_manual_visual_review",
        "production_commit_eligible": False,
        "production_assets_modified": False,
        "production_assets_snapshot_before": production_before,
        "production_assets_snapshot_after": production_after,
        "frozen_batch_manifest_sha256": frozen_batch_sha,
        "provenance_manifest": rel(provenance_path),
        "provenance_manifest_sha256": sha256_file(provenance_path),
        "fringe_policy": FRINGE_POLICY,
        "campaign_variant_scope_gate": FIXED_CAMPAIGN_VARIANT_SCOPE_GATE,
        "runtime_mapping_gate": FIXED_RUNTIME_MAPPING_GATE,
        "row_replacements": row_replacement_reports,
        "blocked_attempts": blocked_reports,
        "atlases": atlas_reports,
    }
    report["report_content_sha256"] = canonical_value_sha256(report)
    return report


def write_report(path: Path, report: dict[str, Any]) -> None:
    payload = (json.dumps(report, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    atomic_write(path.resolve(), payload)


def validate_report_path(path: Path | None, protected: tuple[Path, ...]) -> Path | None:
    if path is None:
        return None
    resolved = path.resolve()
    if resolved.suffix.lower() != ".json":
        raise IntakeError("--report must name a .json file")
    if resolved in {item.resolve() for item in protected}:
        raise IntakeError("--report may not overwrite an input manifest")
    try:
        resolved.relative_to((ROOT / "assets").resolve())
    except ValueError:
        pass
    else:
        raise IntakeError("--report may not be written inside production assets")
    lowered = str(resolved).lower()
    if "steamworks" in lowered or "liangshan_5088120" in lowered:
        raise IntakeError("--report may not be written inside a Steam/Steamworks directory")
    return resolved


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source_group = parser.add_mutually_exclusive_group(required=True)
    source_group.add_argument("--source-manifest", type=Path)
    source_group.add_argument(
        "--fixed-candidate-manifest",
        type=Path,
        help="validate fixed_cell_rect_v1 adoption candidates; this path can never commit production art",
    )
    parser.add_argument("--batch-manifest", default=DEFAULT_BATCH_MANIFEST, type=Path)
    parser.add_argument("--report", type=Path, help="optional JSON report path; stdout always receives the report")
    parser.add_argument("--commit", action="store_true", help="create a hash checkpoint and atomically replace production files")
    parser.add_argument(
        "--record-attempts",
        action="store_true",
        help="append immutable per-SHA attempt sidecars only; do not slice or touch production art",
    )
    parser.add_argument(
        "--allow-unfrozen-batch-dry-run",
        action="store_true",
        help="development-only: validate an alternate prompt pack without allowing attempt recording or commit",
    )
    args = parser.parse_args()
    if args.commit and args.record_attempts:
        parser.error("--commit and --record-attempts are mutually exclusive")
    if args.allow_unfrozen_batch_dry_run and (args.commit or args.record_attempts):
        parser.error("--allow-unfrozen-batch-dry-run cannot be combined with --commit or --record-attempts")
    if args.fixed_candidate_manifest and (args.commit or args.record_attempts or args.allow_unfrozen_batch_dry_run):
        parser.error(
            "--fixed-candidate-manifest is a frozen-batch, candidate-only validation path; "
            "it cannot commit, record attempts, or allow an unfrozen batch"
        )
    input_manifest_path = (
        args.fixed_candidate_manifest.resolve()
        if args.fixed_candidate_manifest
        else args.source_manifest.resolve()
    )
    batch_manifest_path = args.batch_manifest.resolve()
    report_path: Path | None = None
    lock_acquired = False
    try:
        report_path = validate_report_path(args.report, (input_manifest_path, batch_manifest_path))
        if args.fixed_candidate_manifest:
            report = validate_fixed_candidate_manifest(input_manifest_path, batch_manifest_path)
            if report_path:
                write_report(report_path, report)
            print(json.dumps(report, ensure_ascii=False, indent=2))
            return 0
        source_manifest_path = input_manifest_path
        if args.record_attempts:
            report = record_attempts(source_manifest_path, batch_manifest_path)
            if report_path:
                write_report(report_path, report)
            print(json.dumps(report, ensure_ascii=False, indent=2))
            return 0
        if args.commit:
            acquire_lock(DEFAULT_LOCK)
            lock_acquired = True
        plan, batches, entries, _ = build_plan(
            source_manifest_path,
            batch_manifest_path,
            require_adopted=args.commit,
            generate=args.commit,
            require_frozen_batch=not args.allow_unfrozen_batch_dry_run,
        )
        if args.commit:
            checkpoint, commit_result = commit_plan(
                plan, batches, entries, source_manifest_path, batch_manifest_path
            )
            report = public_plan(plan, committed=True, checkpoint=checkpoint)
            report["commit_result"] = commit_result
        else:
            report = public_plan(plan)
        if report_path:
            try:
                write_report(report_path, report)
            except OSError as error:
                # The production commit has already completed and, if needed,
                # passed its coverage check.  Never misreport that state merely
                # because an optional evidence destination became unavailable.
                report["report_write_error"] = str(error)
                print(json.dumps(report, ensure_ascii=False, indent=2))
                return 3
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0
    except (IntakeError, OSError, ValueError) as error:
        failure = {
            "schema_version": 1,
            "kind": "direction4_first_sample_intake_failure",
            "committed": False,
            "error": str(error),
        }
        if report_path:
            try:
                write_report(report_path, failure)
            except OSError:
                pass
        print(json.dumps(failure, ensure_ascii=False, indent=2), file=sys.stderr)
        return 2
    finally:
        if lock_acquired:
            warning = release_lock(DEFAULT_LOCK)
            if warning is not None:
                print(json.dumps(warning, ensure_ascii=False), file=sys.stderr)


if __name__ == "__main__":
    raise SystemExit(main())
