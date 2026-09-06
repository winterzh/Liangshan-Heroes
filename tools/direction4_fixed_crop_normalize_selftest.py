"""Self-test for the fixed-rectangle direction4 candidate normalizer."""
from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools/direction4_fixed_crop_normalize.py"
SPEC = importlib.util.spec_from_file_location("direction4_fixed_crop_normalize", TOOL)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("cannot import direction4_fixed_crop_normalize.py")
M = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = M
SPEC.loader.exec_module(M)


CHECKS: list[dict[str, object]] = []
NEGATIVE_CHECKS = 0


def check(condition: bool, label: str) -> None:
    CHECKS.append({"label": label, "passed": bool(condition)})
    if not condition:
        raise AssertionError(label)


def expect_failure(label: str, contains: str, callback) -> None:
    global NEGATIVE_CHECKS
    NEGATIVE_CHECKS += 1
    try:
        callback()
    except M.NormalizeError as error:
        check(contains in str(error), label)
        return
    raise AssertionError(f"{label}: expected NormalizeError containing {contains!r}")


def tree_digest(path: Path) -> str:
    digest = hashlib.sha256()
    for item in sorted(path.rglob("*"), key=lambda value: value.as_posix()):
        if not item.is_file():
            continue
        digest.update(item.relative_to(path).as_posix().encode("utf-8"))
        digest.update(b"\0")
        digest.update(hashlib.sha256(item.read_bytes()).digest())
    return digest.hexdigest()


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build_fixture(temp: Path) -> tuple[Path, Path, dict]:
    atlas = Image.new("RGBA", (400, 400), (0, 0, 0, 0))
    draw = ImageDraw.Draw(atlas)
    centers_x = (45, 145, 255, 355)
    centers_y = (95, 155, 255, 355)
    frames = []
    directions = ("se", "sw", "ne", "nw")
    for row, center_y in enumerate(centers_y):
        for column, center_x in enumerate(centers_x):
            left, top = center_x - 10, center_y - 15
            right, bottom = center_x + 10, center_y + 15
            color = (40 + row * 45, 60 + column * 35, 180, 255)
            draw.rectangle((left, top, right - 1, bottom - 1), fill=color)
            # Connected asymmetric marker proves direction pixels are not mirrored.
            draw.rectangle((right, top + 3, right + 4, top + 7), fill=(255, 90, 30, 255))
            # A detached small prop must survive because the whole rectangle is copied.
            draw.rectangle((left - 4, top + 5, left - 2, top + 7), fill=(20, 240, 120, 255))
            frames.append(
                {
                    "unit": f"unit_{row}",
                    "state": "idle",
                    "direction": directions[column],
                    "row": row,
                    "column": column,
                    "crop_rect": [left - 5, top - 2, 31, 34],
                    "semantic_anchor_source": [center_x, bottom - 1],
                    "anchor_kind": "foot_or_hoof",
                    "review_note": "Synthetic fixed crop contains the complete asymmetric body and detached prop.",
                }
            )
    source = temp / "fixture.png"
    atlas.save(source)
    base_prompt = temp / "base.txt"
    correction_prompt = temp / "correction.txt"
    base_prompt.write_text("reviewed base prompt\n", encoding="utf-8")
    correction_prompt.write_text("reviewed correction prompt\n", encoding="utf-8")
    payload = {
        "schema_version": 1,
        "kind": "direction4_fixed_rect_normalization_spec",
        "source_rule": "fixed_cell_rect_v1",
        "source": {
            "sha256": M.sha256_file(source),
            "conversation_url": "https://chatgpt.com/c/12345678-1234-1234-1234-123456789012",
            "base_prompt": {"path": str(base_prompt), "sha256": M.sha256_file(base_prompt)},
            "correction_prompt": {
                "path": str(correction_prompt),
                "sha256": M.sha256_file(correction_prompt),
            },
        },
        "atlas": {"size": [400, 400], "rows": 4, "columns": 4, "directions": list(directions)},
        "normalization": {
            "canvas_size": 128,
            "target_width": 80,
            "target_height": 80,
            "anchor_target_y": 100,
            "pre_scale_transparent_padding": 2,
            "visible_alpha_threshold": 6,
            "minimum_component_pixels": 100,
            "scale_scope": "row",
            "allow_upscale": False,
        },
        "frames": frames,
    }
    spec_path = temp / "spec.json"
    write_json(spec_path, payload)
    return source, spec_path, payload


def build_row_fixture(temp: Path) -> tuple[Path, Path]:
    atlas = Image.new("RGBA", (400, 100), (0, 0, 0, 0))
    draw = ImageDraw.Draw(atlas)
    frames = []
    directions = ("se", "sw", "ne", "nw")
    for column, center_x in enumerate((50, 150, 250, 350)):
        left, top, right, bottom = center_x - 12, 20, center_x + 12, 76
        draw.rectangle((left, top, right - 1, bottom - 1), fill=(70, 80 + column * 30, 170, 255))
        draw.rectangle((right, top + 8, right + 5, top + 13), fill=(245, 80, 35, 255))
        frames.append(
            {
                "unit": "unit_row",
                "state": "attack",
                "direction": directions[column],
                "row": 0,
                "column": column,
                "crop_rect": [left - 2, top - 2, 34, 60],
                "semantic_anchor_source": [center_x, bottom - 1],
                "anchor_kind": "foot_or_hoof",
                "review_note": "Synthetic one-row direction crop keeps the complete asymmetric body.",
            }
        )
    source = temp / "row_fixture.png"
    atlas.save(source)
    base_prompt = temp / "row_base.txt"
    base_prompt.write_text("reviewed one-row direction prompt\n", encoding="utf-8")
    payload = {
        "schema_version": 1,
        "kind": "direction4_fixed_rect_normalization_spec",
        "source_rule": "fixed_direction_row_rect_v1",
        "source": {
            "sha256": M.sha256_file(source),
            "conversation_url": "https://chatgpt.com/c/12345678-1234-1234-1234-123456789012",
            "base_prompt": {"path": str(base_prompt), "sha256": M.sha256_file(base_prompt)},
            "correction_prompt": None,
        },
        "atlas": {"size": [400, 100], "rows": 1, "columns": 4, "directions": list(directions)},
        "normalization": {
            "canvas_size": 128,
            "target_width": 80,
            "target_height": 80,
            "anchor_target_y": 100,
            "pre_scale_transparent_padding": 2,
            "visible_alpha_threshold": 6,
            "minimum_component_pixels": 100,
            "scale_scope": "row",
            "allow_upscale": False,
        },
        "frames": frames,
    }
    spec_path = temp / "row_spec.json"
    write_json(spec_path, payload)
    return source, spec_path


def main() -> int:
    production_before = tree_digest(ROOT / "assets")
    with tempfile.TemporaryDirectory(prefix="direction4_fixed_crop_selftest_") as raw_temp:
        temp = Path(raw_temp)
        source, spec_path, payload = build_fixture(temp)
        output_dir = temp / "candidate" / "png"
        manifest_path = temp / "candidate" / "manifest.json"
        manifest, writes = M.prepare_candidate(source, spec_path, output_dir, manifest_path)
        check(len(writes) == 16 and len(manifest["outputs"]) == 16, "positive plan contains all 16 outputs")
        check(manifest["source"]["raw_sha256"] == M.sha256_file(source), "raw SHA is preserved")
        check(manifest["source"]["base_prompt"]["sha256"] == M.sha256_file(temp / "base.txt"), "base prompt SHA is preserved")
        check(manifest["source"]["correction_prompt"]["sha256"] == M.sha256_file(temp / "correction.txt"), "optional correction prompt SHA is preserved")
        check(
            manifest["source_rule"] == "fixed_cell_rect_v1"
            and manifest["candidate_only"] is True
            and manifest["production_commit_allowed"] is False
            and manifest["adoption_status"] == "pending_manual_visual_review",
            "manifest is explicitly fixed-cell and candidate only",
        )
        check(
            all(item["forbidden_operations_used"] == [] for item in manifest["outputs"]),
            "manifest records no forbidden operation",
        )
        check(
            all(item["read_only_component_qa"]["visible_component_complete"] for item in manifest["outputs"]),
            "read-only QA proves every large body complete",
        )
        for output, data in writes:
            M.atomic_write(output, data)
        M.atomic_write(
            manifest_path,
            (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8"),
        )
        check(manifest_path.is_file() and len(list(output_dir.glob("*.png"))) == 16, "candidate write stays in the requested candidate directory")
        first_record = manifest["outputs"][0]
        first_output = Image.open(output_dir / "unit_0_idle_se.png").convert("RGBA")
        first_frame = payload["frames"][0]
        x, y, width, height = first_frame["crop_rect"]
        source_image = Image.open(source).convert("RGBA")
        crop = source_image.crop((x, y, x + width, y + height))
        padded = Image.new("RGBA", (width + 4, height + 4), (0, 0, 0, 0))
        padded.paste(crop, (2, 2))
        paste_x, paste_y = first_record["paste_xy"]
        extracted = first_output.crop((paste_x, paste_y, paste_x + padded.width, paste_y + padded.height))
        check(extracted.tobytes() == padded.tobytes(), "scale-one output preserves every pixel of the whole fixed crop")
        check(extracted.getpixel((3, 9))[3] == 255, "detached prop remains present without component masking")
        check(extracted.getpixel((27, 7))[:3] == (255, 90, 30), "asymmetric marker remains on its original side")

        row_source, row_spec = build_row_fixture(temp)
        row_manifest, row_writes = M.prepare_candidate(
            row_source,
            row_spec,
            temp / "row_candidate" / "png",
            temp / "row_candidate" / "manifest.json",
        )
        check(
            row_manifest["source_rule"] == "fixed_direction_row_rect_v1"
            and len(row_writes) == 4
            and [item["direction"] for item in row_manifest["outputs"]] == ["se", "sw", "ne", "nw"],
            "candidate-only one-row override preserves four independently drawn directions",
        )
        check(
            all(item["read_only_component_qa"]["foreign_large_visible_pixels"] == 0 for item in row_manifest["outputs"]),
            "one-row override crops keep complete isolated bodies without masking",
        )

        bad_sha = copy.deepcopy(payload)
        bad_sha["source"]["sha256"] = "0" * 64
        bad_sha_path = temp / "bad_source_sha.json"
        write_json(bad_sha_path, bad_sha)
        expect_failure(
            "source byte drift is rejected",
            "raw source SHA mismatch",
            lambda: M.prepare_candidate(source, bad_sha_path, temp / "bad1", temp / "bad1.json"),
        )

        bad_rule = copy.deepcopy(payload)
        bad_rule["source_rule"] = "transparent_grid_v1"
        bad_rule_path = temp / "bad_source_rule.json"
        write_json(bad_rule_path, bad_rule)
        expect_failure(
            "wrong source rule is rejected",
            "unsupported schema",
            lambda: M.prepare_candidate(source, bad_rule_path, temp / "bad_rule", temp / "bad_rule.json"),
        )

        bad_prompt = copy.deepcopy(payload)
        bad_prompt["source"]["base_prompt"]["sha256"] = "1" * 64
        bad_prompt_path = temp / "bad_prompt_sha.json"
        write_json(bad_prompt_path, bad_prompt)
        expect_failure(
            "base prompt drift is rejected",
            "source.base_prompt SHA mismatch",
            lambda: M.prepare_candidate(source, bad_prompt_path, temp / "bad2", temp / "bad2.json"),
        )

        bad_correction = copy.deepcopy(payload)
        bad_correction["source"]["correction_prompt"]["sha256"] = "2" * 64
        bad_correction_path = temp / "bad_correction_sha.json"
        write_json(bad_correction_path, bad_correction)
        expect_failure(
            "correction prompt drift is rejected",
            "source.correction_prompt SHA mismatch",
            lambda: M.prepare_candidate(source, bad_correction_path, temp / "bad3", temp / "bad3.json"),
        )

        truncated = copy.deepcopy(payload)
        truncated["frames"][0]["crop_rect"][2] = 20
        truncated_path = temp / "truncated.json"
        write_json(truncated_path, truncated)
        expect_failure(
            "fixed crop that truncates a body is rejected",
            "crop truncates its complete visible component",
            lambda: M.prepare_candidate(source, truncated_path, temp / "bad4", temp / "bad4.json"),
        )

        foreign = copy.deepcopy(payload)
        foreign["frames"][0]["crop_rect"] = [30, 70, 130, 70]
        foreign_path = temp / "foreign.json"
        write_json(foreign_path, foreign)
        expect_failure(
            "fixed crop containing another body is rejected",
            "pixels from another large visible body",
            lambda: M.prepare_candidate(source, foreign_path, temp / "bad5", temp / "bad5.json"),
        )

        blank_anchor = copy.deepcopy(payload)
        blank_anchor["frames"][0]["semantic_anchor_source"] = [31, 78]
        blank_anchor_path = temp / "blank_anchor.json"
        write_json(blank_anchor_path, blank_anchor)
        expect_failure(
            "anchor without nearby foot pixels is rejected",
            "semantic anchor has no visible foot/hoof contact",
            lambda: M.prepare_candidate(source, blank_anchor_path, temp / "bad6", temp / "bad6.json"),
        )

        expect_failure(
            "candidate output cannot target production assets",
            "candidate path outside protected production root",
            lambda: M.prepare_candidate(source, spec_path, ROOT / "assets" / "anim", temp / "bad7.json"),
        )

        source_text = TOOL.read_text(encoding="utf-8")
        forbidden_snippets = ("crop[~keep]", "ImageOps.mirror", "np.fliplr", "putalpha(")
        check(not any(snippet in source_text for snippet in forbidden_snippets), "tool source contains no masking or mirroring primitive")

    production_after = tree_digest(ROOT / "assets")
    check(production_before == production_after, "self-test leaves production assets byte-identical")
    report = {
        "schema_version": 1,
        "kind": "direction4_fixed_crop_normalize_selftest",
        "passed": all(item["passed"] for item in CHECKS),
        "checks": len(CHECKS),
        "negative_checks": NEGATIVE_CHECKS,
        "production_assets_modified": production_before != production_after,
        "production_tree_sha256_before": production_before,
        "production_tree_sha256_after": production_after,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
