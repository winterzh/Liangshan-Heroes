#!/usr/bin/env python3
"""Verify or restore the content-addressed historical snapshot ZIP.

Usage:
  python restore_archive.py ARCHIVE.zip NEW_DESTINATION --verify-only
  python restore_archive.py ARCHIVE.zip NEW_DESTINATION --prefix .godot/batch/run/project/

Paths are restored relative to NEW_DESTINATION, retaining their manifest path.
Existing identical files are skipped; different files are never overwritten.
Only Python's standard library is required. The archive is not extracted with
extractall. A full selected-blob verification precedes any filesystem writes.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile
import zipfile


SHA_RE = re.compile(r"[0-9a-f]{64}\Z")
RESERVED_RE = re.compile(r"(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?\Z", re.I)
CHUNK = 1024 * 1024


class RestoreError(Exception):
    """Archive or destination did not satisfy the restoration contract."""


def safe_relative(value: object, *, prefix: bool = False) -> str:
    if not isinstance(value, str) or not value:
        raise RestoreError("Empty or non-string manifest path/prefix")
    if "\\" in value or ":" in value or value.startswith("/"):
        raise RestoreError(f"Unsafe absolute, drive, ADS or backslash path: {value!r}")
    if prefix and value.endswith("/"):
        value = value[:-1]
    segments = value.split("/")
    for part in segments:
        if (not part or part in (".", "..") or part.endswith((".", " "))
                or any(ord(c) < 32 or c in '<>"|?*' for c in part)
                or RESERVED_RE.fullmatch(part)):
            raise RestoreError(f"Unsafe Windows path component in {value!r}")
    return "/".join(segments)


def long_path(path: Path) -> str:
    text = str(path)
    if os.name == "nt" and not text.startswith("\\\\?\\"):
        if text.startswith("\\\\"):
            return "\\\\?\\UNC\\" + text[2:]
        return "\\\\?\\" + text
    return text


def lstat_optional(path: Path):
    try:
        return os.lstat(long_path(path))
    except FileNotFoundError:
        return None


def assert_no_reparse(path: Path, *, final_may_be_file: bool = False) -> None:
    """Check every existing component, including destination root and drive."""
    chain = list(reversed(path.parents)) + [path]
    for item in chain:
        info = lstat_optional(item)
        if info is None:
            continue
        if (stat.S_ISLNK(info.st_mode)
                or getattr(info, "st_file_attributes", 0) & 0x400):
            raise RestoreError(f"Reparse/symlink component is forbidden: {item}")
        if item == path and final_may_be_file:
            if not stat.S_ISREG(info.st_mode):
                raise RestoreError(f"Destination is not a regular file: {item}")
        elif not stat.S_ISDIR(info.st_mode):
            raise RestoreError(f"Destination ancestor is not a directory: {item}")


def destination_path(root: Path, rel: str) -> Path:
    path = root.joinpath(*rel.split("/"))
    if os.path.commonpath((str(root), str(path))) != str(root):
        raise RestoreError(f"Path escapes destination: {rel}")
    return path


def file_digest(path: Path) -> tuple[int, str]:
    digest = hashlib.sha256()
    count = 0
    with open(long_path(path), "rb") as source:
        while block := source.read(CHUNK):
            count += len(block)
            digest.update(block)
    return count, digest.hexdigest()


def checked_rows(manifest: object) -> list[dict]:
    if not isinstance(manifest, dict) or manifest.get("schema_version") != 1:
        raise RestoreError("Expected manifest schema_version 1")
    rows = manifest.get("files")
    if not isinstance(rows, list):
        raise RestoreError("manifest.files must be a list")
    seen = set()
    checked = []
    for raw in rows:
        if not isinstance(raw, dict):
            raise RestoreError("Manifest row must be an object")
        rel = safe_relative(raw.get("path"))
        key = rel.casefold()
        if key in seen:
            raise RestoreError(f"Duplicate/case-colliding manifest path: {rel}")
        seen.add(key)
        size, digest, mtime = raw.get("bytes"), raw.get("sha256"), raw.get("mtime_ns")
        if type(size) is not int or size < 0:
            raise RestoreError(f"Invalid byte count: {rel}")
        if not isinstance(digest, str) or not SHA_RE.fullmatch(digest):
            raise RestoreError(f"Invalid SHA-256: {rel}")
        if type(mtime) is not int or mtime < 0:
            raise RestoreError(f"Invalid mtime_ns: {rel}")
        checked.append({"path": rel, "bytes": size, "sha256": digest, "mtime_ns": mtime})
    # A file may not also be a parent directory of another file.
    for row in checked:
        parts = row["path"].split("/")
        for length in range(1, len(parts)):
            if "/".join(parts[:length]).casefold() in seen:
                raise RestoreError(f"Manifest file/directory conflict: {row['path']}")
    return checked


def checked_directories(manifest: dict, rows: list[dict]) -> list[str]:
    raw_dirs = manifest.get("directories", [])
    if not isinstance(raw_dirs, list):
        raise RestoreError("manifest.directories must be a list")
    files = {row["path"].casefold() for row in rows}
    seen = set()
    checked = []
    for raw in raw_dirs:
        rel = safe_relative(raw)
        key = rel.casefold()
        if key in seen:
            raise RestoreError(f"Duplicate/case-colliding manifest directory: {rel}")
        seen.add(key)
        parts = rel.split("/")
        for length in range(1, len(parts) + 1):
            if "/".join(parts[:length]).casefold() in files:
                raise RestoreError(f"Manifest directory conflicts with a file or file ancestor: {rel}")
        checked.append(rel)
    return checked


def ensure_directory(path: Path) -> None:
    assert_no_reparse(path)
    for item in list(reversed(path.parents)) + [path]:
        if lstat_optional(item) is None:
            # Parent is checked again immediately before each mutation.
            assert_no_reparse(item.parent)
            try:
                os.mkdir(long_path(item))
            except FileExistsError:
                pass
            assert_no_reparse(item)


def publish_new_file(temp_path: Path, target: Path) -> None:
    """Publish atomically without ever replacing a pre-existing target."""
    assert_no_reparse(target.parent)
    if lstat_optional(target) is not None:
        raise RestoreError(f"Destination appeared during restore; refusing overwrite: {target}")
    if os.name == "nt":
        # Windows rename has no-replace semantics; os.replace would be unsafe.
        os.rename(long_path(temp_path), long_path(target))
    else:
        # POSIX rename replaces a raced-in target, so use atomic create-link.
        os.link(temp_path, target)
        os.unlink(temp_path)


def run(archive: Path, destination: Path, prefix: str | None, verify_only: bool) -> dict:
    root = Path(os.path.abspath(destination))
    assert_no_reparse(root)
    selection = safe_relative(prefix, prefix=True) if prefix else None
    with zipfile.ZipFile(archive, "r") as zf:
        names = [entry.filename for entry in zf.infolist()]
        if len(names) != len(set(names)):
            raise RestoreError("ZIP contains duplicate member names")
        if "manifest.json" not in names:
            raise RestoreError("ZIP has no manifest.json")
        manifest = json.loads(zf.read("manifest.json"))
        all_rows = checked_rows(manifest)
        all_directories = checked_directories(manifest, all_rows)
        rows = [row for row in all_rows if selection is None
                or row["path"] == selection or row["path"].startswith(selection + "/")]
        directories = [rel for rel in all_directories if selection is None
                       or rel == selection or rel.startswith(selection + "/")]
        if selection and not rows and not directories:
            raise RestoreError(f"Prefix selected no files: {selection}")
        unique: dict[str, int] = {}
        for row in rows:
            previous = unique.setdefault(row["sha256"], row["bytes"])
            if previous != row["bytes"]:
                raise RestoreError(f"Same SHA mapped to different sizes: {row['sha256']}")
        for digest, expected_size in unique.items():
            member = "blobs/" + digest
            try:
                info = zf.getinfo(member)
            except KeyError as exc:
                raise RestoreError(f"Missing archive content: {member}") from exc
            if info.is_dir() or info.file_size != expected_size:
                raise RestoreError(f"Archive content size mismatch: {member}")
            hashed = hashlib.sha256()
            count = 0
            with zf.open(info, "r") as source:
                while block := source.read(CHUNK):
                    count += len(block)
                    hashed.update(block)
            if count != expected_size or hashed.hexdigest() != digest:
                raise RestoreError(f"Archive content SHA/size mismatch: {member}")
        # Preflight every selected destination before creating any directories.
        for rel in directories:
            assert_no_reparse(destination_path(root, rel))
        existing: set[str] = set()
        for row in rows:
            target = destination_path(root, row["path"])
            assert_no_reparse(target, final_may_be_file=True)
            if lstat_optional(target) is not None:
                if file_digest(target) != (row["bytes"], row["sha256"]):
                    raise RestoreError(f"Existing different file; refusing overwrite: {target}")
                existing.add(row["path"])
        result = {"verified": True, "verify_only": verify_only,
                  "mapped_files": len(rows), "unique_blobs": len(unique),
                  "mapped_directories": len(directories), "restored_directories": 0,
                  "mapped_bytes": sum(row["bytes"] for row in rows),
                  "unique_bytes": sum(unique.values()), "restored_files": 0,
                  "identical_existing_files": len(existing)}
        if verify_only:
            return result
        for rel in sorted(directories, key=lambda value: (value.count("/"), value)):
            target = destination_path(root, rel)
            was_missing = lstat_optional(target) is None
            ensure_directory(target)
            if was_missing:
                result["restored_directories"] += 1
        for row in rows:
            if row["path"] in existing:
                # Recheck skipped files in case another application changed one.
                target = destination_path(root, row["path"])
                assert_no_reparse(target, final_may_be_file=True)
                if file_digest(target) != (row["bytes"], row["sha256"]):
                    raise RestoreError(f"Existing file changed during restore: {target}")
                continue
            target = destination_path(root, row["path"])
            ensure_directory(target.parent)
            fd, temp_name = tempfile.mkstemp(prefix=".restore-", suffix=".partial", dir=long_path(target.parent))
            temp_path = Path(temp_name)
            try:
                hashed = hashlib.sha256()
                count = 0
                with os.fdopen(fd, "wb") as output, zf.open("blobs/" + row["sha256"], "r") as source:
                    while block := source.read(CHUNK):
                        output.write(block)
                        count += len(block)
                        hashed.update(block)
                    output.flush()
                    os.fsync(output.fileno())
                if count != row["bytes"] or hashed.hexdigest() != row["sha256"]:
                    raise RestoreError(f"Temporary restore SHA/size mismatch: {target}")
                os.utime(long_path(temp_path), ns=(row["mtime_ns"], row["mtime_ns"]))
                publish_new_file(temp_path, target)
                if file_digest(target) != (row["bytes"], row["sha256"]):
                    raise RestoreError(f"Final restored file SHA/size mismatch: {target}")
                result["restored_files"] += 1
            finally:
                # Only our own exclusive-created temporary file may be removed.
                if lstat_optional(temp_path) is not None:
                    os.unlink(long_path(temp_path))
        return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("archive", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--prefix", help="Restore only this manifest-relative directory prefix")
    parser.add_argument("--verify-only", action="store_true", help="Verify contents and destination safety without writes")
    args = parser.parse_args()
    try:
        result = run(args.archive, args.destination, args.prefix, args.verify_only)
    except (RestoreError, OSError, ValueError, zipfile.BadZipFile, RuntimeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
