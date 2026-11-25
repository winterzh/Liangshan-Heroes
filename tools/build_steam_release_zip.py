# -*- coding: utf-8 -*-
"""Package an already frozen Windows Steam build and recheck every ZIP member."""

import argparse
from hashlib import file_digest
import json
from pathlib import Path
import re
import zipfile


RUNTIME_FILES = frozenset({
    "GODOTSTEAM_LICENSE.txt",
    "LiangshanHeroes.exe",
    "LiangshanHeroes.pck",
    "STEAM_STATS_READER_GODOT_CPP_LICENSE.txt",
    "libgodotsteam.windows.template_release.x86_64.dll",
    "steam_api64.dll",
    "steam_stats_reader.dll",
})


def hash_file(path, algorithm="sha256"):
    with path.open("rb") as stream:
        return file_digest(stream, algorithm).hexdigest()


def package_release(frozen, output):
    receipt = json.loads((frozen / "freeze_receipt.json").read_bytes())
    commit = receipt["commit"]
    if not re.fullmatch("[0-9a-f]{40}", commit) or not receipt["source_version"]:
        raise ValueError("The frozen release source identity is invalid")
    if not receipt["steps"] or any(step["exit_code"] or step["errors"] for step in receipt["steps"]):
        raise ValueError("The frozen build must pass its import and export steps")
    members = {row["path"]: row for row in receipt["files"]}
    runtime = frozen / "windows"
    if (len(receipt["files"]) != len(RUNTIME_FILES) or members.keys() != RUNTIME_FILES
            or {path.name for path in runtime.iterdir()} != RUNTIME_FILES):
        raise ValueError("The build does not contain the seven split Windows depot files")
    for name, row in members.items():
        path = runtime / name
        if not path.is_file() or path.stat().st_size != row["bytes"] or hash_file(path) != row["sha256"]:
            raise ValueError(f"Frozen file does not match its receipt: {name}")
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"LiangshanHeroes_Windows_{commit[:8]}.zip"
    summary = output / "package_receipt.json"
    partial = archive.with_suffix(".zip.partial")
    if archive.exists() or summary.exists():
        raise FileExistsError("Choose a new directory for the release ZIP")
    with zipfile.ZipFile(partial, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as writer:
        for name in sorted(RUNTIME_FILES):
            writer.write(runtime / name, name)
    with zipfile.ZipFile(partial) as verifier:
        if len(verifier.infolist()) != len(members) or set(verifier.namelist()) != RUNTIME_FILES:
            raise ValueError("ZIP inventory does not match the Windows depot")
        for entry in verifier.infolist():
            row = members[entry.filename]
            with verifier.open(entry) as stream:
                if entry.file_size != row["bytes"] or file_digest(stream, "sha256").hexdigest() != row["sha256"]:
                    raise ValueError(f"ZIP member failed verification: {entry.filename}")
    archive_metadata = {"name": archive.name, "bytes": partial.stat().st_size, "sha256": hash_file(partial)}
    partial.rename(archive)
    result = {"source_commit": commit, "source_version": receipt["source_version"],
              "layout": "split_pck", "archive": archive_metadata, "files": receipt["files"]}
    with summary.open("x", encoding="utf-8") as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frozen", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    result = package_release(args.frozen.resolve(strict=True), args.output.resolve())
    print(json.dumps(result["archive"], ensure_ascii=False))


if __name__ == "__main__":
    main()
