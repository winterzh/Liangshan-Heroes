"""Prepare redraw render/timing validation; never run Godot or change production.

The two accepted helper bodies are checked against contracts. All other source
hashes describe this run, so unrelated future Unit changes do not stale the tool.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import stat

ROOT = Path(__file__).resolve().parents[1]
CONTRACTS = ROOT / "tools/contracts/redraw_reject"
NAMES = ("_queue_animated_redraw", "_queue_motion_redraw")
SOURCE_DIRECTORIES = ("scripts", "scenes", "assets", "shaders", "resources", "data",
                      "addons", "content", "scenarios", "tools/contracts/redraw_reject")
FIXED_SOURCE_FILES = ("project.godot", "tools/prepare_redraw_reject_validation.py",
                      "tools/redraw_reject_qa.gd", "tools/redraw_reject_timing.gd",
                      "tools/redraw_reject_validation_base.gd", "tools/campaign_mode_performance_test.gd")
TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc", ".json", ".cfg",
                 ".import", ".uid", ".svg", ".txt", ".csv", ".godot", ".py", ".md"}
COUNTED = '''extends "res://scripts/unit.gd"
var qa_draws := 0
var qa_last := {}
func qa_snapshot() -> Dictionary:
	return {"idle":_idle_t,"anim":_anim_t,"hp":hp,"direction":animation_direction,"selected":selected,"lunge":_lunge,"death":_death_t,"variant":art_variant,"flash":_flash,"burn":_burn_t}
func _draw() -> void:
	qa_draws += 1
	qa_last = qa_snapshot()
	super._draw()
'''


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def method(text, name):
    text = text.replace("\r\n", "\n")
    found = re.search(r"(?m)^func " + re.escape(name) + r"\(", text)
    if found is None:
        raise RuntimeError("Required redraw method missing: " + name)
    following = re.search(r"(?m)^func ", text[found.end():])
    end = found.end() + following.start() if following else len(text)
    return text[found.start():end].rstrip() + "\n"


def validate_methods(reference, current, contract):
    if sha(reference.encode()) != contract["reference_sha256"]:
        raise RuntimeError("Frozen redraw reference differs from its contract")
    for name in NAMES:
        for label, text in [("reference", reference), ("candidate", current)]:
            if sha(method(text, name).encode()) != contract[label + "_method_sha256"][name]:
                raise RuntimeError(label + " method changed; review contract before generating: " + name)


def source_scope(generated):
    return {"directory_roots": list(SOURCE_DIRECTORIES), "fixed_files": list(FIXED_SOURCE_FILES),
            "generated_files": sorted(path.relative_to(ROOT).as_posix() for path in generated),
            "root_icon_prefix": "icon.", "include_hidden": True, "links": "reject",
            "text_suffixes": sorted(TEXT_SUFFIXES)}


def plain_kind(path):
    info = path.lstat()  # Missing/unreadable paths raise, rather than becoming empty results.
    if stat.S_ISLNK(info.st_mode) or getattr(info, "st_file_attributes", 0) & 0x400:
        raise RuntimeError("Source links/reparse points require explicit review: " + str(path))
    if stat.S_ISDIR(info.st_mode):
        return "directory"
    if stat.S_ISREG(info.st_mode):
        return "file"
    raise RuntimeError("Unsupported source entry: " + str(path))


def directory_entries(path):
    # scandir includes dot/Windows-hidden entries and propagates enumeration errors.
    with os.scandir(path) as entries:
        return sorted((entry.name for entry in entries))


def enumerate_sources(scope):
    files, directories, presence = set(), set(), {}

    def walk(relative):
        if plain_kind(ROOT / relative) != "directory":
            raise RuntimeError("Source directory missing or replaced: " + relative)
        directories.add(relative)
        for name in directory_entries(ROOT / relative):
            child = relative + "/" + name
            if plain_kind(ROOT / child) == "directory":
                walk(child)
            else:
                files.add(child)

    root_names = set(directory_entries(ROOT))
    for directory in scope["directory_roots"]:
        # Nine top-level production roots are optional only when initially absent.
        # Record absence explicitly; runtime compares this map before hashing.
        exists = directory in root_names if "/" not in directory else True
        presence[directory] = exists
        if exists:
            walk(directory)  # Contracts is required; a missing path raises here.
    for name in root_names:
        if name.lower().startswith(scope["root_icon_prefix"]):
            if plain_kind(ROOT / name) == "file":
                files.add(name)
    for name in scope["fixed_files"] + scope["generated_files"]:
        if plain_kind(ROOT / name) != "file":
            raise RuntimeError("Required source file missing or replaced: " + name)
        files.add(name)
    return sorted(files), sorted(directories), presence


def source_snapshot(scope):
    paths, directories, presence = enumerate_sources(scope)
    sources, hashes = {}, {}
    for name in paths:
        path = ROOT / name
        normalized = path.suffix.lower() in TEXT_SUFFIXES
        raw = path.read_bytes()
        hashes[name] = sha(raw.replace(b"\r\n", b"\n") if normalized else raw)
        sources[name] = {"normalize_lf": normalized}
    if enumerate_sources(scope) != (paths, directories, presence):
        raise RuntimeError("Source paths changed during preparation; prepare again")
    combined = sha("\n".join(name + "\t" + hashes[name] for name in sorted(hashes)).encode())
    return sources, {"valid": True, "file_sha256": hashes, "combined_sha256": combined,
                     "file_count": len(hashes), "file_paths": paths,
                     "directory_paths": directories, "directory_presence": presence}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path(".godot/redraw_reject_validation"),
                        help="Parent output directory under this checkout's ignored .godot directory.")
    args = parser.parse_args()
    base = (args.output if args.output.is_absolute() else ROOT / args.output).resolve()
    if not base.is_relative_to((ROOT / ".godot").resolve()):
        parser.error("Output must stay under this checkout's .godot directory")
    contract = json.loads((CONTRACTS / "methods.json").read_text(encoding="utf-8"))
    reference = (CONTRACTS / contract["reference_file"]).read_text(encoding="utf-8")
    current = (ROOT / "scripts/unit.gd").read_bytes().replace(b"\r\n", b"\n").decode()
    validate_methods(reference, current, contract)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    out = base / stamp
    out.mkdir(parents=True, exist_ok=False)
    # Candidate render class deliberately inherits both actual production helpers.
    artifacts = {"old_render_unit.gd": COUNTED + reference, "new_render_unit.gd": COUNTED}
    timing = 'extends "res://scripts/unit.gd"\n'
    for prefix, text in [("old", reference), ("new", current)]:
        for name, suffix in zip(NAMES, ("animated", "motion")):
            timing += method(text, name).replace("func " + name + "(", "func rr_" + prefix + "_" + suffix + "(", 1) + "\n"
    timing += "func rr_empty_animated(_interval := 0.08, _force := false) -> void: pass\nfunc rr_empty_motion() -> void: pass\n"
    artifacts["timing_unit.gd"] = timing
    for name, text in artifacts.items():
        (out / name).write_bytes(text.encode())
    scope = source_scope([out / name for name in artifacts])
    sources, snapshot = source_snapshot(scope)
    # Guard a source change while preparing; no generated class is silently paired
    # with a later Unit body. No production file is ever written or restored here.
    if (ROOT / "scripts/unit.gd").read_bytes().replace(b"\r\n", b"\n").decode() != current:
        raise RuntimeError("Unit changed during preparation; retain this output and prepare again")
    manifest = {"schema": 2, "status": "prepared only; Godot has not run", "contract": contract,
                "source_scope": scope, "sources": sources, "prepared_source_snapshot": snapshot,
                "production_mutated": False, "godot_executed": False}
    (out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    res = "res://" + out.relative_to(ROOT).as_posix()
    print(json.dumps({"manifest": res + "/manifest.json", "output": str(out),
                      "render_output": res + "/render", "timing_output": res + "/timing",
                      "render_script": "res://tools/redraw_reject_qa.gd",
                      "timing_script": "res://tools/redraw_reject_timing.gd"}, ensure_ascii=False))


if __name__ == "__main__":
    main()
