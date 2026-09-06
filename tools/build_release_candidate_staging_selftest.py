"""Read-only-on-repository tests for build_release_candidate_staging.py.

Every fixture and attempted candidate is created under the OS temporary
directory.  The tests do not run Godot, export a build, or access Steam.
"""
from __future__ import annotations

import sys
from pathlib import Path
import tempfile
import unittest


TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import build_release_candidate_staging as staging  # noqa: E402


class ReleaseCandidateStagingTests(unittest.TestCase):
    def test_path_escape_and_absolute_metadata_are_rejected(self) -> None:
        bad = (
            "../escape.png",
            "assets/../escape.png",
            "/absolute/file.png",
            "C:/absolute/file.png",
            "C:\\absolute\\file.png",
            "assets\\anim\\unit.png",
        )
        for value in bad:
            with self.subTest(value=value), self.assertRaises(staging.StagingError):
                staging.safe_rel_path(value)

    def test_repository_and_steamworks_targets_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="liangshan_release_boundary_") as raw:
            base = Path(raw)
            source = base / "source"
            source.mkdir()
            inside = source / "candidate"
            errors = staging.validate_staging_target(source, inside)
            self.assertTrue(any("outside the source repository" in item for item in errors))
            steam_parent = base / "Steamworks"
            steam_parent.mkdir()
            errors = staging.validate_staging_target(source, steam_parent / "candidate")
            self.assertTrue(any("Steamworks" in item for item in errors))

    def test_missing_environment_art_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="liangshan_release_missing_env_") as raw:
            root = Path(raw)
            router = root / staging.ENVIRONMENT_ROUTER
            router.parent.mkdir(parents=True)
            router.write_text(
                'const P := "res://assets/campaign/environment/level1/missing.png"\n',
                encoding="utf-8",
            )
            errors, metrics, provenance_sha = staging.validate_environment_gate(root, set())
            self.assertEqual(metrics["present"], 0)
            self.assertEqual(metrics["required"], staging.EXPECTED_ENVIRONMENT_PNGS)
            self.assertEqual(provenance_sha, "")
            self.assertTrue(any("environment runtime PNG gate failed: 0/69" in item for item in errors))
            self.assertTrue(any("provenance ledger is missing" in item for item in errors))

    def test_concrete_dynamic_load_outside_allowlist_is_reported(self) -> None:
        with tempfile.TemporaryDirectory(prefix="liangshan_release_dynamic_") as raw:
            root = Path(raw)
            script = root / "scripts/main.gd"
            script.parent.mkdir(parents=True)
            script.write_text(
                'extends Node\nvar t = load("res://assets/runtime_extra/forgotten.png")\n',
                encoding="utf-8",
            )
            forgotten = root / "assets/runtime_extra/forgotten.png"
            forgotten.parent.mkdir(parents=True)
            forgotten.write_bytes(b"not-a-real-png")
            errors = staging.scan_runtime_references(root, {"scripts/main.gd"})
            self.assertTrue(any("absent from the physical allowlist" in item for item in errors))

    def test_local_absolute_path_in_candidate_text_is_reported(self) -> None:
        with tempfile.TemporaryDirectory(prefix="liangshan_release_absolute_") as raw:
            root = Path(raw)
            script = root / "scripts/main.gd"
            script.parent.mkdir(parents=True)
            script.write_text('const BAD := "C:/Users/example/dev.png"\n', encoding="utf-8")
            errors = staging.scan_forbidden_absolute_paths(root, {"scripts/main.gd"})
            self.assertTrue(any("local absolute path is forbidden" in item for item in errors))

    def test_development_and_cache_paths_cannot_enter_allowlist(self) -> None:
        errors = staging.assert_no_forbidden_selected(
            {
                "implementation_20260902/checkpoint.png",
                "qa/capture.png",
                "tools/__pycache__/audit.cpython-314.pyc",
                "assets/campaign/source/web_source.png",
                "assets/campaign/web_prompts_20260902/prompt.txt",
            }
        )
        self.assertGreaterEqual(len(errors), 5)
        joined = "\n".join(errors)
        self.assertIn("development path entered", joined)
        self.assertIn("raw/cache file entered", joined)

    def test_failure_after_atomic_install_restores_empty_target(self) -> None:
        with tempfile.TemporaryDirectory(prefix="liangshan_release_rollback_") as raw:
            base = Path(raw)
            source = base / "source"
            source.mkdir()
            payload = source / "project.godot"
            payload.write_text("config_version=5\n", encoding="utf-8")
            record = staging.FileRecord(
                "project.godot", payload.stat().st_size, staging.sha256_file(payload)
            )
            target = base / "candidate"
            target.mkdir()
            plan = staging.Plan(
                source_root=source,
                staging=target,
                gate_manifest=source / "qa/release_candidate_gate.json",
                records=(record,),
                source_tree_sha256=staging.tree_sha256((record,)),
                errors=[],
                metrics={},
                gate_bindings={},
            )

            def injected_failure() -> None:
                raise OSError("synthetic post-install failure")

            with self.assertRaisesRegex(staging.StagingError, "rolled back"):
                staging.commit_staging(
                    plan,
                    after_install=injected_failure,
                    revalidator=lambda _plan: [],
                )
            self.assertTrue(target.is_dir())
            self.assertEqual(list(target.iterdir()), [])
            self.assertFalse(target.with_name(target.name + ".manifest.json").exists())
            leftovers = [
                path.name for path in base.iterdir()
                if path.name.startswith(".candidate.")
            ]
            self.assertEqual(leftovers, [])

    def test_success_manifest_stays_adjacent_to_candidate(self) -> None:
        with tempfile.TemporaryDirectory(prefix="liangshan_release_success_") as raw:
            base = Path(raw)
            source = base / "source"
            source.mkdir()
            payload = source / "project.godot"
            payload.write_text("config_version=5\n", encoding="utf-8")
            record = staging.FileRecord(
                "project.godot", payload.stat().st_size, staging.sha256_file(payload)
            )
            target = base / "candidate"
            plan = staging.Plan(
                source_root=source,
                staging=target,
                gate_manifest=source / "qa/release_candidate_gate.json",
                records=(record,),
                source_tree_sha256=staging.tree_sha256((record,)),
                errors=[],
                metrics={},
                gate_bindings={},
            )
            result = staging.commit_staging(plan, revalidator=lambda _plan: [])
            self.assertTrue(result["committed"])
            self.assertTrue((target / "project.godot").is_file())
            self.assertFalse((target / "release_candidate_manifest.json").exists())
            sidecar = target.with_name(target.name + ".manifest.json")
            self.assertTrue(sidecar.is_file())
            self.assertEqual(staging.sha256_file(target / "project.godot"), record.sha256)

    def test_source_sha_drift_is_detected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="liangshan_release_drift_") as raw:
            root = Path(raw)
            file = root / "project.godot"
            file.write_text("before\n", encoding="utf-8")
            record = staging.FileRecord(
                "project.godot", file.stat().st_size, staging.sha256_file(file)
            )
            file.write_text("after\n", encoding="utf-8")
            errors = staging.verify_records(root, (record,))
            self.assertTrue(any("SHA changed" in item for item in errors))


if __name__ == "__main__":
    unittest.main(verbosity=2)
