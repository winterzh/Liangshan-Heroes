"""Prepare a fresh, traceable office candidate without running or altering historical QA."""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa/zhu_wounded_20261005"
PROPOSAL = QA / "proposals/daming_safe_retreat_v25"


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def require(value, message):
    if not value:
        raise RuntimeError(message)


def write_new(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as stream:
        stream.write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    candidate = args.candidate_root.resolve(strict=True)
    require(candidate != ROOT and not candidate.is_relative_to(ROOT), "Candidate must be outside production")
    for path in [candidate, *candidate.parents]:
        require(not path.is_symlink() and not getattr(path.lstat(), "st_file_attributes", 0) & 0x400,
                "Linked candidate refused")
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    require(subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=candidate, text=True).strip() == head,
            "Candidate is not based on current production HEAD")
    require(not subprocess.check_output(["git", "status", "--porcelain=v1"], cwd=candidate),
            "Candidate must initially be clean; do not reuse prior batches")
    output = args.output.absolute()
    require(not output.exists(), "Preparation output must be new")
    source_plan = load(QA / "safe_retreat_candidate_v25x1.json")
    candidate_rows = source_plan["files"]
    require(len(candidate_rows) == 6, "Complete six-path declaration required")
    replacements = {"scripts/run_battle_world_core.gd", "scripts/run_level8_unit_contract.gd"}
    rows = []
    for row in candidate_rows:
        name = row["path"]
        original, target = ROOT / name, candidate / name
        require(sha(original) == sha(target), "Fresh checkout bytes differ: " + name)
        if name in replacements:
            require(sha(target) == row["before_sha256"], "Unqualified production candidate already installed")
            proposed = PROPOSAL / "proposed" / name
            require(sha(proposed) == row["after_sha256"] and proposed.stat().st_size == row["bytes"],
                    "Original proposed source bytes changed")
            data = proposed.read_bytes()
        else:
            require(sha(target) == row["after_sha256"], "Qualified JSON predecessor drift")
            data = target.read_bytes()
        rows.append({"path": name, "before_sha256": sha(target), "after_sha256": hashlib.sha256(data).hexdigest(),
                     "bytes": len(data), "changed": name in replacements})
    # Verify every retained full-scope review pin through an exact committed byte bridge.
    lookup = {}
    for path in [*PROPOSAL.rglob("*"), *(QA / "harness").rglob("*"), *(ROOT / "scripts").rglob("*")]:
        if path.is_file():
            lookup.setdefault(path.name, []).append(path)

    def bridge(pin):
        basename = pin["path"].replace("\\", "/").rsplit("/", 1)[-1]
        matches = [path for path in lookup.get(basename, [])
                   if path.stat().st_size == pin["bytes"] and sha(path) == pin["sha256"]]
        if basename in {Path(name).name for name in replacements}:
            matches += [PROPOSAL / "proposed/scripts" / basename]
            matches = [path for path in matches if path.stat().st_size == pin["bytes"] and sha(path) == pin["sha256"]]
        require(matches, "Retained review pin has no exact local source: " + basename)
        path = sorted(set(matches), key=lambda path: len(str(path)))[0]
        return {"historical_path": pin["path"], "current_path": str(path),
                "repository_relative_path": path.relative_to(ROOT).as_posix(),
                "bytes": pin["bytes"], "sha256": pin["sha256"]}

    producer_review = load(PROPOSAL / "ADAPTER_REVIEW_V25S_R2B2_FX.json")
    runner_review = load(PROPOSAL / "RUNNER_REVIEW_V25S1_FULL_FX.json")
    require(producer_review["static_api_closure_passed"] is True and producer_review["approved_stages"] == ["full"],
            "Retained producer review lacks full scope")
    require(runner_review["static_api_closure_passed"] is True and "full" in runner_review["approved_stages"],
            "Retained runner review lacks full scope")
    pins = [producer_review["producer_pin"], *producer_review["inheritance_pins"],
            *producer_review["tool_pins"], *runner_review["candidate_pins"], *runner_review["source_dependency_pins"]]
    bridged = [bridge(pin) for pin in pins]
    interfaces = {}
    for kind, name, count_key, count in [
        ("world", "NEGATIVE_WORLD_INTERFACE_V25B2.json", "route_expectations", 264),
        ("component", "COMPONENT_NEGATIVE_INTERFACE_V25.json", "required_route_rows", 362),
        ("capture", "CAPTURE_NEGATIVE_INTERFACE_V25D1.json", "required_cases", 24),
    ]:
        source = PROPOSAL / name
        interface = load(source)
        require(len(interface[count_key]) == count, "Fixed " + kind + " matrix incomplete")
        interfaces[kind] = {"source": str(source), "sha256": sha(source), "row_count": count,
                            "harness": bridge(interface["harness"]), "scene": bridge(interface["scene"])}
    require({key for key in load(PROPOSAL / "CAPTURE_NEGATIVE_INTERFACE_V25D1.json")["required_cases"]
             if key.startswith("safe_caster_")} == {
                 "safe_caster__walk_casts", "safe_caster__pending_casts", "safe_caster__channels",
                 "safe_caster__walk_item_casts", "safe_caster__pending_item_casts"}, "Five live cast cases omitted")
    base_path = QA / "harness/run_daming_admit_v24s.py"
    base_ast = ast.parse(base_path.read_text(encoding="utf-8-sig"))
    constants = {node.targets[0].id: ast.literal_eval(node.value) for node in base_ast.body
                 if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name)
                 and node.targets[0].id in {"BOUNDARY_HARNESS_SHA256", "BOUNDARY_SCENE_SHA256", "BOUNDARY_MANIFEST_SHA256"}}
    gd = QA / "harness/native_ownership_json_boundary_v24q1.gd"
    scene = gd.with_suffix(".tscn")
    manifest_path = QA / "native_ownership_json_fixtures_v24q.json"
    require(sha(gd) == constants["BOUNDARY_HARNESS_SHA256"]
            and sha(manifest_path) == constants["BOUNDARY_MANIFEST_SHA256"], "Original JSON533 harness/fixtures drift")
    if scene.exists():
        require(sha(scene) == constants["BOUNDARY_SCENE_SHA256"], "Historical JSON scene drift")
        scene_bytes = scene.read_bytes()
    else:
        # The GD and all fixtures are archived; the original external Node scene was not.
        # Retain that limitation and create a separately pinned, explicit Node binding.
        scene_bytes = ('[gd_scene load_steps=2 format=3]\n'
                       '[ext_resource type="Script" path="res://tools/native_ownership_json_boundary_v24q1.gd" id="1"]\n'
                       '[node name="OfficeOwnershipJSONBoundary" type="Node"]\n'
                       'script = ExtResource("1")\n').encode("utf-8")
    manifest = load(manifest_path)
    fixture_paths = {}
    for key, name in [("original_payload", "daming_admit_canonical_original_v24p.txt"),
                      ("normalized_payload", "daming_admit_canonical_normalized_v24p.txt")]:
        path = QA / name
        require(sha(path) == manifest[key]["sha256"], "Original failed JSON bytes unavailable")
        fixture_paths[key] = str(path)
    for row in manifest["maps"]:
        recorded = row["path"].replace("\\", "/")
        require("/水浒/" in recorded, "Original fixture must have a known repository-relative archive bridge")
        relative = Path(recorded.split("/水浒/", 1)[1])
        require(not relative.is_absolute() and ".." not in relative.parts, "Fixture archive bridge escaped repository")
        path = ROOT / relative
        require(sha(path) == row["sha256"], "Original whole-world fixture drift")
        fixture_paths[row["case"]] = str(path)
    require(len(fixture_paths) == 11, "All original eleven JSON cases required")
    # Only after every source, review and fixed-matrix gate is checked, install the isolated proposal.
    output.mkdir(parents=True, exist_ok=False)
    scene_output = output / "sources/native_ownership_json_boundary_v24q1.tscn"
    scene_output.parent.mkdir(parents=True)
    scene_output.write_bytes(scene_bytes)
    for row in rows:
        if not row["changed"]:
            continue
        target = candidate / row["path"]
        backup = output / "original" / row["path"]
        backup.parent.mkdir(parents=True, exist_ok=True)
        backup.write_bytes(target.read_bytes())
        target.write_bytes((PROPOSAL / "proposed" / row["path"]).read_bytes())
        require(sha(target) == row["after_sha256"], "Candidate installation readback failed")
    write_new(output / "preparation.json", {
        "schema": "office_campaign_candidate_preparation_v1", "complete": True,
        "source_head": head, "production_root": str(ROOT), "candidate_root": str(candidate),
        "files": rows, "retained_full_review_source_bridge": bridged,
        "interfaces": interfaces, "json_fixture_paths": fixture_paths,
        "json_scene": {"historical_scene_available": scene.exists(), "historical_scene_sha256": constants["BOUNDARY_SCENE_SHA256"],
                       "current_path": str(scene_output), "sha256": sha(scene_output), "bytes": len(scene_bytes),
                       "explicit_binding": "res://tools/native_ownership_json_boundary_v24q1.gd", "node_type": "Node"},
        "original_JSON_cases": 11, "original_JSON_checks": 533, "OwnedSlot_checks": 76,
        "admission_process_checks": [39, 351, 342], "world_rows_per_role": 264,
        "component_rows_per_role": 362, "live_capture_cases_per_role": 24,
        "natural_variants": ["lu_first", "shi_first"], "required_retreat_processes_per_role": ["A", "B", "C", "D"],
        "native_started": False, "runtime_qualified": False, "production_modified": False,
        "office_runner_independent_review_complete": False,
        "scope": "New detached candidate plus exact retained source bridges. This is preparation only; old deadline, physical cache and source qualification are not reused.",
    })
    print(json.dumps({"complete": True, "candidate_root": str(candidate), "output": str(output),
                      "native_started": False, "runtime_qualified": False}, ensure_ascii=False))


if __name__ == "__main__":
    main()
