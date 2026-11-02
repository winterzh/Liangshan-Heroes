"""Real Windows filesystem tests for generated-copy retirement; no engine."""
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest

from artifact_retirement_windows import NativeFiles
from generated_artifact_retention import retire, choose_current, completion_signature

FAMILY = "huangnigang_production_20261020"
OLD = "20261020_151614_f6c5b4b5"
NEW = "20261030_234411_1490316c"


@unittest.skipUnless(os.name == "nt", "Windows same-handle deletion")
class RetirementTests(unittest.TestCase):
    def setUp(self):
        self.fixture = tempfile.TemporaryDirectory(prefix="watermargin_retention_")
        self.root = Path(self.fixture.name)
        (self.root / ".godot").mkdir()
        (self.root / "scripts").mkdir()
        (self.root / "scripts/current.gd").write_bytes(b"keep production")
        self.batch(OLD)
        self.batch(NEW)

    def tearDown(self):
        self.fixture.cleanup()

    def save(self, path, value):
        path.write_text(json.dumps(value), encoding="utf-8")

    def batch(self, name, complete=True):
        run = self.root / ".godot" / FAMILY / name
        project = run / "project"
        project.mkdir(parents=True)
        source = project / "runtime.bin"
        source.write_bytes(b"frozen " + name.encode())
        generated = project / "derived.gd"
        generated.write_bytes(b"generated identity")
        row = lambda p: {"path":p.name, "bytes":p.stat().st_size,
                         "sha256":hashlib.sha256(p.read_bytes()).hexdigest()}
        self.save(run / "generation.json", {"identity":{"files":[row(source)]}, "derived":row(generated)})
        self.save(run / "preparation.json", {"complete":True, "project":str(project)})
        imported = run / "import__fixture"
        imported.mkdir()
        self.save(imported / "receipt.json", {"complete":complete, "phase":"import",
                       "lock_released":True, "project":str(project)})
        (imported / "original.log").write_bytes(b"keep raw evidence")
        return run

    def test_retire_old_project_keep_current_production_and_reports(self):
        result = retire(self.root, apply=True)
        self.assertEqual(result["deleted_files"], 2)
        self.assertFalse((self.root / ".godot" / FAMILY / OLD / "project").exists())
        self.assertTrue((self.root / ".godot" / FAMILY / NEW / "project/runtime.bin").exists())
        self.assertTrue((self.root / "scripts/current.gd").exists())
        self.assertTrue((self.root / ".godot" / FAMILY / OLD / "import__fixture/original.log").exists())
        self.assertTrue(result["keepers_verified_after"])

    def test_failed_new_import_keeps_last_working_project(self):
        path = self.root / ".godot" / FAMILY / NEW / "import__fixture/receipt.json"
        proof = json.loads(path.read_text())
        proof["complete"] = False
        self.save(path, proof)
        result = retire(self.root, apply=True)
        self.assertEqual(result["deleted_files"], 0)
        self.assertTrue((self.root / ".godot" / FAMILY / OLD / "project/runtime.bin").exists())

    def test_corrupt_new_project_blocks_deletion(self):
        (self.root / ".godot" / FAMILY / NEW / "project/runtime.bin").write_bytes(b"changed")
        with self.assertRaises(ValueError):
            retire(self.root, apply=True)
        self.assertTrue((self.root / ".godot" / FAMILY / OLD / "project").exists())

    def test_explicit_active_baseline_pin_is_preserved(self):
        state = self.root / ".godot/artifact_retention"
        state.mkdir()
        self.save(state / "pins.json", {"runs":[".godot/" + FAMILY + "/" + OLD]})
        self.assertEqual(retire(self.root, apply=True)["deleted_files"], 0)

    def test_native_lane_busy_blocks_every_delete(self):
        (self.root / ".godot/redraw_rejection_source.lock").write_bytes(b"other task")
        with self.assertRaises(RuntimeError):
            retire(self.root, apply=True)
        self.assertTrue((self.root / ".godot" / FAMILY / OLD / "project").exists())

    def test_busy_file_retains_entire_payload_and_owner(self):
        path = self.root / ".godot" / FAMILY / OLD / "project/runtime.bin"
        with path.open("rb"):
            result = retire(self.root, apply=True)
        self.assertTrue(path.exists())
        self.assertTrue(result["issues"])

    def test_outside_dependency_pin_rejected(self):
        state = self.root / ".godot/artifact_retention"
        state.mkdir()
        self.save(state / "pins.json", {"runs":["../other-project"]})
        with self.assertRaises(ValueError):
            retire(self.root, apply=True)

    def test_dry_run_and_non_registered_family_are_untouched(self):
        outside = self.root / ".godot/other_family/project"
        outside.mkdir(parents=True)
        (outside / "keep.bin").write_bytes(b"keep")
        result = retire(self.root)
        self.assertEqual(result["planned_files"], 2)
        self.assertTrue((self.root / ".godot" / FAMILY / OLD / "project").exists())
        self.assertTrue((outside / "keep.bin").exists())

    def test_repeat_is_idempotent_and_keeps_original_receipt(self):
        retire(self.root, apply=True)
        path = self.root / ".godot/artifact_retention/receipt.json"
        before = path.read_bytes()
        self.assertEqual(retire(self.root, apply=True)["deleted_files"], 0)
        self.assertEqual(path.read_bytes(), before)

    def test_watcher_signature_ignores_failed_build_then_observes_success(self):
        before = completion_signature(self.root)
        newer = "20261102_160000_abcd1234"
        run = self.batch(newer, complete=False)
        self.assertEqual(completion_signature(self.root), before)
        self.save(run / "import__fixture/receipt.json", {"complete":True, "phase":"import",
                          "lock_released":True, "project":str(run / "project")})
        self.assertNotEqual(completion_signature(self.root), before)

    def test_strict_cold_import_receipt_without_phase_is_recognized(self):
        run = self.root / ".godot" / FAMILY / NEW
        self.save(run / "import__fixture/receipt.json", {"complete":True,
            "cold_import_qualified":True, "source_and_generated_postchecks":True,
            "children_gone":True, "lock_released":True, "project":str(run / "project")})
        self.assertEqual(choose_current(self.root, FAMILY)[0], run)

    def test_deletion_journal_does_not_accumulate_full_old_operation_lists(self):
        retire(self.root, apply=True)
        self.batch("20261102_160000_abcd1234")
        result = retire(self.root, apply=True)
        journal = self.root / ".godot/artifact_retention/deleted.jsonl"
        self.assertEqual(len(journal.read_text().splitlines()), result["deleted_files"])

    def test_steam_zip_is_complete_keeper_when_expanded_copy_was_removed(self):
        family = self.root / ".godot/steam_candidates"
        for name in (OLD, NEW):
            run = family / name
            run.mkdir(parents=True)
            archive = run / "LiangshanHeroes_Steam_candidate.zip"
            archive.write_bytes(b"verified-archive-" + name.encode())
            row = {"path":"LiangshanHeroes.exe", "sha256":"a"*64, "bytes":100}
            self.save(run / "receipt.json", {"complete":True, "outputs":[row], "archive":{
                "passed":True, "path":archive.name, "sha256":hashlib.sha256(archive.read_bytes()).hexdigest(),
                "members":[row]}})
        result = retire(self.root, apply=True)
        self.assertTrue(result["keepers_verified_after"])
        self.assertFalse((family / OLD / "LiangshanHeroes_Steam_candidate.zip").exists())
        self.assertTrue((family / NEW / "LiangshanHeroes_Steam_candidate.zip").exists())

    def test_same_handle_identity_guard_and_hardlink_content(self):
        path = self.root / ".godot" / FAMILY / OLD / "project/runtime.bin"
        native = NativeFiles()
        identity = native.snapshot(path)
        path.unlink()
        path.write_bytes(b"replacement")
        with self.assertRaises(ValueError):
            native.delete(path, identity)
        keeper = self.root / "not-retired.bin"
        os.link(path, keeper)
        content = keeper.read_bytes()
        _, freed = native.delete(path, native.snapshot(path))
        self.assertEqual(freed, 0)
        self.assertEqual(keeper.read_bytes(), content)


if __name__ == "__main__":
    unittest.main()
