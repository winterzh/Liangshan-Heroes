"""Filesystem-isolated tests for the environment surface candidate normalizer."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

from PIL import Image

from environment_validation_common import LEGACY_BATCH, legacy_preflight


ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools/environment_surface_candidate_normalize.py"
BATCH_MANIFEST = ROOT / LEGACY_BATCH


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(arguments: list[str], expected: int) -> dict:
    process = subprocess.run(
        [sys.executable, "-X", "utf8", "-B", str(TOOL), *arguments],
        text=True,
        encoding="utf-8",
        capture_output=True,
        check=False,
    )
    if process.returncode != expected:
        raise AssertionError(
            f"expected exit {expected}, got {process.returncode}\n"
            f"stdout={process.stdout}\nstderr={process.stderr}"
        )
    payload = process.stdout if expected in (0, 2) else process.stderr
    return json.loads(payload)


def main() -> int:
    preflight = legacy_preflight(ROOT)
    if not preflight["passed"]:
        print(json.dumps({"kind": "environment_surface_normalize_selftest", "tests_executed": 0, **preflight}, ensure_ascii=False))
        return 2
    batch_data = json.loads(BATCH_MANIFEST.read_text(encoding="utf-8"))
    batch = next(item for item in batch_data["send_order"] if item["id"] == "surface_dry_earth")
    checks: list[str] = []
    with tempfile.TemporaryDirectory(prefix="environment_surface_normalize_") as temporary:
        workspace = Path(temporary)
        raw = workspace / "raw.png"
        Image.new("RGB", (1254, 1254), (133, 108, 70)).save(raw)
        raw_sha = sha256(raw)
        candidate_dir = workspace / "candidates/good"
        report_path = candidate_dir / "report.json"
        common = [
            "--workspace-root",
            str(workspace),
            "--batch-manifest",
            str(BATCH_MANIFEST),
            "--batch-id",
            "surface_dry_earth",
            "--conversation-url",
            "https://chatgpt.com/c/00000000-0000-0000-0000-000000000001",
            "--prompt-sha256",
            batch["prompt_sha256"],
        ]
        passed = run(
            common
            + [
                "--raw-png",
                str(raw),
                "--candidate-dir",
                str(candidate_dir),
                "--report",
                str(report_path),
            ],
            0,
        )
        candidate = Path(passed["normalization"]["candidate_png"])
        preview = Path(passed["repeat_preview"]["preview_png"])
        with Image.open(candidate) as image:
            image.load()
            assert image.size == (2048, 2048) and image.mode == "RGBA"
            assert image.getchannel("A").getextrema() == (255, 255)
        with Image.open(preview) as image:
            assert image.size == (1536, 1536) and image.mode == "RGBA"
        assert sha256(raw) == raw_sha == passed["source"]["raw_sha256"]
        assert passed["raw_source_unchanged"] is True
        assert passed["production_assets_written"] is False and passed["steam_written"] is False
        assert passed["normalization"]["localized_pixel_operations"] == []
        assert not any(passed["normalization"]["forbidden_operations_performed"].values())
        assert passed["objective_edge_and_wrap_gate"]["passed"] is True
        checks.append("rgb_1254_whole_image_rgba_2048_candidate")

        # Idempotent rerun may reuse identical PNG bytes while replacing only the report.
        rerun = run(
            common
            + [
                "--raw-png",
                str(raw),
                "--candidate-dir",
                str(candidate_dir),
                "--report",
                str(report_path),
            ],
            0,
        )
        assert set(rerun["candidate_write_status"].values()) == {"reused_identical"}
        checks.append("idempotent_identical_candidate_reuse")

        # The only repair-like fallback allowed is one exact source rectangle.
        crop_raw = workspace / "crop_source.png"
        crop_source = Image.new("RGB", (1254, 1254), (160, 35, 25))
        crop_source.paste(Image.new("RGB", (627, 1254), (25, 50, 165)), (627, 0))
        crop_source.paste(Image.new("RGB", (1024, 1024), (132, 109, 73)), (112, 112))
        crop_source.save(crop_raw)
        crop_dir = workspace / "candidates/crop"
        cropped = run(
            common
            + [
                "--raw-png",
                str(crop_raw),
                "--candidate-dir",
                str(crop_dir),
                "--report",
                str(crop_dir / "report.json"),
                "--allow-square-crop-search",
                "--crop-min-size",
                "896",
            ],
            0,
        )
        assert cropped["whole_source_objective_gate_before_optional_crop"]["passed"] is False
        assert cropped["square_crop_search"]["passed"] is True
        assert cropped["normalization"]["single_square_crop"]["performed"] is True
        assert cropped["normalization"]["single_square_crop"]["source_rectangle"] == [
            112,
            112,
            1024,
            1024,
        ]
        assert cropped["objective_edge_and_wrap_gate"]["passed"] is True
        assert cropped["normalization"]["localized_pixel_operations"] == []
        checks.append("single_contiguous_square_crop_can_pass_without_repair")

        # A strong left-to-right gradient remains seamful after the allowed resize.
        seamful = workspace / "seamful.png"
        gradient = Image.new("RGB", (1254, 1254))
        pixels = gradient.load()
        for x in range(1254):
            value = int(round(255 * x / 1253))
            for y in range(1254):
                pixels[x, y] = (value, value, value)
        gradient.save(seamful)
        failed_dir = workspace / "candidates/seamful"
        failed = run(
            common
            + [
                "--raw-png",
                str(seamful),
                "--candidate-dir",
                str(failed_dir),
                "--report",
                str(failed_dir / "report.json"),
            ],
            2,
        )
        assert failed["objective_edge_and_wrap_gate"]["passed"] is False
        assert failed["candidate_disposition"].startswith("reject_for_production")
        assert Path(failed["normalization"]["candidate_png"]).is_file()
        checks.append("seam_failure_reported_without_local_repair")

        # A candidate output below assets is always refused.
        blocked = run(
            common
            + [
                "--raw-png",
                str(raw),
                "--candidate-dir",
                str(workspace / "assets/candidates"),
                "--report",
                str(workspace / "qa/blocked.json"),
            ],
            1,
        )
        assert "production assets" in blocked["error"]
        checks.append("production_assets_write_refused")

    print(
        json.dumps(
            {
                "schema_version": 1,
                "kind": "environment_surface_candidate_normalize_selftest",
                "passed": True,
                "checks": checks,
                "browser_used": False,
                "production_assets_written": False,
                "steam_written": False,
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
