#!/usr/bin/env python3
"""Restore only the duplicate files listed in a verified cleanup plan.

python restore_duplicates.py PLAN.jsonl.gz REPOSITORY NEW_DESTINATION
    [--prefix .godot/family/run/project/] [--verify-only] [--from-git]

The original bytes come from an unchanged retained file or its Git blob.
No newline conversion is performed. Existing different files are never replaced.
Only files explicitly listed in the plan are restored; unique historical files
that were retained in place are not modified by this tool.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile

CHUNK = 1024 * 1024
SHA_RE = re.compile(r"[0-9a-f]{64}\Z")
OID_RE = re.compile(r"[0-9a-f]{40}\Z")
RESERVED_RE = re.compile(r"(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?\Z", re.I)
LFS_PREFIX = b"version https://git-lfs.github.com/spec/"


class RestoreError(Exception):
    pass


def safe_relative(value: object, *, prefix: bool = False) -> str:
    if not isinstance(value, str) or not value:
        raise RestoreError("Empty or non-string relative path")
    if "\\" in value or ":" in value or value.startswith("/"):
        raise RestoreError(f"Absolute, drive, ADS or backslash path forbidden: {value!r}")
    if prefix and value.endswith("/"):
        value = value[:-1]
    for part in value.split("/"):
        if (not part or part in (".", "..") or part.endswith((".", " "))
                or any(ord(c) < 32 or c in '<>"|?*' for c in part)
                or RESERVED_RE.fullmatch(part)):
            raise RestoreError(f"Unsafe Windows path component: {value!r}")
    return value


def long_path(path: Path) -> str:
    value = str(path)
    if os.name == "nt" and not value.startswith("\\\\?\\"):
        return "\\\\?\\UNC\\" + value[2:] if value.startswith("\\\\") else "\\\\?\\" + value
    return value


def lstat_optional(path: Path):
    try:
        return os.lstat(long_path(path))
    except FileNotFoundError:
        return None


def assert_no_reparse(path: Path, *, final_may_be_file: bool = False) -> None:
    for item in list(reversed(path.parents)) + [path]:
        info = lstat_optional(item)
        if info is None:
            continue
        if stat.S_ISLNK(info.st_mode) or getattr(info, "st_file_attributes", 0) & 0x400:
            raise RestoreError(f"Reparse/symlink component forbidden: {item}")
        if item == path and final_may_be_file:
            if not stat.S_ISREG(info.st_mode):
                raise RestoreError(f"Not a regular file: {item}")
        elif not stat.S_ISDIR(info.st_mode):
            raise RestoreError(f"Ancestor is not a directory: {item}")


def child_path(root: Path, rel: str) -> Path:
    result = root.joinpath(*rel.split("/"))
    if os.path.commonpath((str(root), str(result))) != str(root):
        raise RestoreError("Path escaped root")
    return result


def ensure_directory(path: Path) -> None:
    assert_no_reparse(path)
    for item in list(reversed(path.parents)) + [path]:
        if lstat_optional(item) is None:
            assert_no_reparse(item.parent)
            try:
                os.mkdir(long_path(item))
            except FileExistsError:
                pass
            assert_no_reparse(item)


def file_chunks(path: Path):
    assert_no_reparse(path, final_may_be_file=True)
    with open(long_path(path), "rb") as source:
        while block := source.read(CHUNK):
            yield block


def checked_digest(chunks, expected_size: int, expected_sha: str) -> None:
    digest = hashlib.sha256()
    size = 0
    prefix = b""
    for block in chunks:
        digest.update(block)
        size += len(block)
        if len(prefix) < len(LFS_PREFIX):
            prefix = (prefix + block)[:len(LFS_PREFIX)]
    if prefix.startswith(LFS_PREFIX):
        raise RestoreError("LFS pointer is not the original file content")
    if size != expected_size or digest.hexdigest() != expected_sha:
        raise RestoreError("Source byte count or SHA-256 mismatch")


def file_digest(path: Path):
    digest = hashlib.sha256()
    size = 0
    for block in file_chunks(path):
        size += len(block)
        digest.update(block)
    return size, digest.hexdigest()


def git_environment():
    result = os.environ.copy()
    for key in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR"):
        result.pop(key, None)
    return result


class GitReader:
    def __init__(self, repository: Path):
        env = git_environment()
        actual = subprocess.check_output(["git", "-C", str(repository), "rev-parse", "--show-toplevel"], env=env, stderr=subprocess.PIPE).decode("utf-8").strip()
        if os.path.normcase(os.path.abspath(actual)) != os.path.normcase(str(repository)):
            raise RestoreError("REPOSITORY must be the Git working tree root")
        self.process = subprocess.Popen(["git", "-C", str(repository), "cat-file", "--batch"],
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.DEVNULL, env=env)

    def chunks(self, oid: str):
        if not OID_RE.fullmatch(oid):
            raise RestoreError("Invalid Git object ID")
        self.process.stdin.write((oid + "\n").encode("ascii"))
        self.process.stdin.flush()
        header = self.process.stdout.readline().decode("ascii").strip().split()
        if len(header) != 3 or header[0] != oid or header[1] != "blob":
            raise RestoreError(f"Git blob unavailable: {oid}")
        remaining = int(header[2])
        while remaining:
            block = self.process.stdout.read(min(CHUNK, remaining))
            if not block:
                raise RestoreError("Truncated Git blob")
            remaining -= len(block)
            yield block
        if self.process.stdout.read(1) != b"\n":
            raise RestoreError("Invalid Git batch framing")

    def close(self):
        if self.process.stdin:
            self.process.stdin.close()
        if self.process.stdout:
            self.process.stdout.close()
        try:
            self.process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self.process.terminate()
            self.process.wait(timeout=10)


def read_plan(plan: Path) -> list[dict]:
    rows = []
    seen = set()
    with gzip.open(plan, "rt", encoding="utf-8") as source:
        for number, line in enumerate(source, 1):
            raw = json.loads(line)
            if not isinstance(raw, dict):
                raise RestoreError(f"Invalid plan row {number}")
            rel = safe_relative(raw.get("path"))
            keeper = safe_relative(raw.get("retained_copy"))
            key = rel.casefold()
            if key in seen:
                raise RestoreError(f"Duplicate/case-colliding plan path: {rel}")
            seen.add(key)
            size, sha, mtime = raw.get("bytes"), raw.get("sha256"), raw.get("mtime_ns")
            blob, commit = raw.get("git_blob"), raw.get("git_commit")
            if type(size) is not int or size < 0 or type(mtime) is not int or mtime < 0:
                raise RestoreError(f"Invalid size or mtime: {rel}")
            if not isinstance(sha, str) or not SHA_RE.fullmatch(sha):
                raise RestoreError(f"Invalid SHA-256: {rel}")
            if not isinstance(blob, str) or not OID_RE.fullmatch(blob) or not isinstance(commit, str) or not OID_RE.fullmatch(commit):
                raise RestoreError(f"Invalid Git IDs: {rel}")
            rows.append({"path": rel, "retained_copy": keeper, "bytes": size, "sha256": sha,
                         "mtime_ns": mtime, "git_blob": blob, "git_commit": commit})
    for row in rows:
        parts = row["path"].split("/")
        if any("/".join(parts[:i]).casefold() in seen for i in range(1, len(parts))):
            raise RestoreError(f"Plan file/directory conflict: {row['path']}")
    return rows


def publish_new_file(temporary: Path, target: Path) -> None:
    assert_no_reparse(target.parent)
    if lstat_optional(target) is not None:
        raise RestoreError(f"Destination appeared; refusing overwrite: {target}")
    if os.name == "nt":
        os.rename(long_path(temporary), long_path(target))
    else:
        os.link(temporary, target)
        os.unlink(temporary)


def run(plan: Path, repository: Path, destination: Path, prefix: str | None = None,
        verify_only: bool = False, from_git: bool = False) -> dict:
    repository = Path(os.path.abspath(repository))
    destination = Path(os.path.abspath(destination))
    assert_no_reparse(repository)
    assert_no_reparse(destination)
    selection = safe_relative(prefix, prefix=True) if prefix else None
    rows = [row for row in read_plan(plan) if selection is None or row["path"] == selection
            or row["path"].startswith(selection + "/")]
    if not rows:
        raise RestoreError("Plan/prefix selected no files")
    unique = {}
    for row in rows:
        previous = unique.setdefault(row["sha256"], row)
        if previous["bytes"] != row["bytes"]:
            raise RestoreError("Same SHA maps to different byte counts")
    reader = GitReader(repository)
    try:
        chosen = {}
        for sha, row in unique.items():
            keeper = child_path(repository, row["retained_copy"])
            use_keeper = False
            if not from_git:
                # A reparse source is rejected rather than traversed, even if Git could supply it.
                assert_no_reparse(keeper, final_may_be_file=True)
                try:
                    checked_digest(file_chunks(keeper), row["bytes"], sha)
                    use_keeper = True
                except (OSError, RestoreError):
                    use_keeper = False
            if use_keeper:
                chosen[sha] = ("keeper", keeper)
            else:
                checked_digest(reader.chunks(row["git_blob"]), row["bytes"], sha)
                chosen[sha] = ("git", row["git_blob"])
        existing = set()
        for row in rows:
            target = child_path(destination, row["path"])
            assert_no_reparse(target, final_may_be_file=True)
            if lstat_optional(target) is not None:
                if file_digest(target) != (row["bytes"], row["sha256"]):
                    raise RestoreError(f"Existing different file; refusing overwrite: {target}")
                existing.add(row["path"])
        result = {"verified": True, "verify_only": verify_only, "from_git": from_git,
                  "mapped_files": len(rows), "unique_sources": len(unique),
                  "mapped_bytes": sum(row["bytes"] for row in rows),
                  "unique_bytes": sum(row["bytes"] for row in unique.values()),
                  "keeper_sources": sum(kind == "keeper" for kind, _ in chosen.values()),
                  "git_sources": sum(kind == "git" for kind, _ in chosen.values()),
                  "restored_files": 0, "identical_existing_files": len(existing)}
        if verify_only:
            return result
        for row in rows:
            target = child_path(destination, row["path"])
            if row["path"] in existing:
                if file_digest(target) != (row["bytes"], row["sha256"]):
                    raise RestoreError(f"Existing file changed during restore: {target}")
                continue
            ensure_directory(target.parent)
            fd, temporary_name = tempfile.mkstemp(prefix=".restore-", suffix=".partial", dir=long_path(target.parent))
            temporary = Path(temporary_name)
            kind, source = chosen[row["sha256"]]
            try:
                chunks = file_chunks(source) if kind == "keeper" else reader.chunks(source)
                digest = hashlib.sha256()
                count = 0
                with os.fdopen(fd, "wb") as output:
                    for block in chunks:
                        output.write(block)
                        digest.update(block)
                        count += len(block)
                    output.flush()
                    os.fsync(output.fileno())
                if count != row["bytes"] or digest.hexdigest() != row["sha256"]:
                    raise RestoreError(f"Source changed during restore: {row['path']}")
                os.utime(long_path(temporary), ns=(row["mtime_ns"], row["mtime_ns"]))
                publish_new_file(temporary, target)
                if file_digest(target) != (row["bytes"], row["sha256"]):
                    raise RestoreError(f"Restored file verification failed: {target}")
                result["restored_files"] += 1
            finally:
                if lstat_optional(temporary) is not None:
                    os.unlink(long_path(temporary))
        return result
    finally:
        reader.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("plan", type=Path)
    parser.add_argument("repository", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--prefix")
    parser.add_argument("--verify-only", action="store_true")
    parser.add_argument("--from-git", action="store_true", help="Read original bytes from Git even if retained files exist")
    args = parser.parse_args()
    try:
        result = run(args.plan, args.repository, args.destination, args.prefix, args.verify_only, args.from_git)
    except (RestoreError, OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
