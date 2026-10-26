"""Read-only candidate provenance/diff check. Never imports or launches Godot."""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def require(condition, reason):
    if not condition:
        raise RuntimeError(reason)


def source(relative):
    part = Path(relative)
    require(not part.is_absolute() and ".." not in part.parts, "Repository-relative source required")
    path = ROOT / part
    for item in [path, *path.parents]:
        if item.exists() or item.is_symlink():
            require(not item.is_symlink() and not getattr(item.lstat(), "st_file_attributes", 0) & 0x400,
                    "Link/reparse input: " + str(item))
    return path


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def verify():
    manifest = json.loads((HERE / "source_manifest.json").read_text(encoding="utf-8"))
    require(manifest["schema"] == "continue_binding_candidate_v1", "Unknown manifest")
    for row in manifest["base_records"]:
        require(digest(source(row["path"])) == row["sha256"], "Frozen base record changed")
    generation = json.loads(source(manifest["base_generation"]).read_text(encoding="utf-8"))
    require("source-v1:" + generation["identity"]["source_sha256"] == manifest["base_identity"], "Wrong original identity")
    require(len(manifest["files"]) == 3 and {row["path"] for row in manifest["files"]} == {
        "scripts/continue_flow.gd", "scripts/run_world_session.gd", "scripts/run_campaign_local_lifecycle.gd"},
        "Exact three-script overlay required")
    changes = []
    for row in manifest["files"]:
        before = source(row["base_path"])
        after = HERE / row["path"]
        require(digest(before) == row["base_sha256"], "Original script changed: " + row["path"])
        require(digest(after) == row["candidate_sha256"] and after.stat().st_size == row["candidate_bytes"],
                "Candidate changed: " + row["path"])
        changes.extend(difflib.unified_diff(before.read_text(encoding="utf-8-sig").splitlines(True),
                       after.read_text(encoding="utf-8-sig").splitlines(True),
                       fromfile="e97a/" + row["path"], tofile="candidate/" + row["path"]))
    require((HERE / "candidate.diff").read_text(encoding="utf-8") == "".join(changes), "Exact diff changed")
    for row in manifest["support_files"]:
        require(digest(HERE / row["path"]) == row["sha256"], "Supporting source changed: " + row["path"])
    return manifest


def main():
    argparse.ArgumentParser(description=__doc__).parse_args()
    manifest = verify()
    print(json.dumps({"source_provenance_checked": True, "scripts": 3, "base_identity": manifest["base_identity"],
                      "manifest_sha256": digest(HERE / "source_manifest.json"),
                      "engine_started": False, "gdscript_compiled": False, "runtime_qualified": False}, indent=2))


if __name__ == "__main__":
    main()
