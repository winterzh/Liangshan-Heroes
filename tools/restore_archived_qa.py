"""Verify or restore archived QA payloads from their immutable Git source commit.

Default verifies only. --output must name a new directory outside this checkout.
Original receipts and logs stay in the checkout; this restores archived payloads.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / 'qa/github_cleanup_20260930/archive_manifest.json'


def checked_relative(value):
    path = PurePosixPath(value)
    if (not value or '\\' in value or ':' in value or path.is_absolute()
            or any(p in ('', '.', '..') for p in value.split('/'))
            or not value.startswith('qa/')):
        raise ValueError('Unsafe archive member: ' + value)
    return path


def no_links(path):
    for part in (path, *path.parents):
        if part.exists() or part.is_symlink():
            if part.is_symlink() or getattr(part.lstat(), 'st_file_attributes', 0) & 0x400:
                raise ValueError('Reparse/symlink path: ' + str(part))


def restore(manifest, output=None):
    source = manifest['source_commit']
    if not re.fullmatch(r'[0-9a-f]{40}', source):
        raise ValueError('Expected full source commit')
    if subprocess.check_output(['git', 'cat-file', '-t', source], cwd=ROOT, text=True).strip() != 'commit':
        raise ValueError('Source is not a commit')
    tree = {}
    for record in subprocess.check_output(['git', 'ls-tree', '-r', '-z', source], cwd=ROOT).split(b'\0'):
        if not record:
            continue
        meta, name = record.split(b'\t', 1)
        mode, kind, oid = meta.decode().split()
        tree[name.decode('utf-8')] = (kind, oid)
    seen = set()
    for row in manifest['files']:
        relative = checked_relative(row['path'])
        if relative in seen:
            raise ValueError('Duplicate member')
        seen.add(relative)
        if tree.get(row['path']) != ('blob', row['git_blob']):
            raise ValueError('Manifest does not match source commit: ' + row['path'])
        if not re.fullmatch(r'[0-9a-f]{64}', row['sha256']) or row['bytes'] < 0:
            raise ValueError('Invalid size/hash')
    if output is not None:
        output = Path(os.path.abspath(output))
        no_links(output)
        if output.exists() or output.is_relative_to(ROOT):
            raise ValueError('Output must be a new directory outside the checkout')
        output.mkdir(parents=True)
    process = subprocess.Popen(['git', 'cat-file', '--batch'], cwd=ROOT,
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    total = 0
    try:
        for row in manifest['files']:
            process.stdin.write((row['git_blob'] + '\n').encode('ascii'))
            process.stdin.flush()
            header = process.stdout.readline().decode('ascii').strip().split()
            if header != [row['git_blob'], 'blob', str(row['bytes'])]:
                raise ValueError('Missing or unexpected Git blob: ' + row['path'])
            remaining = row['bytes']
            digest = hashlib.sha256()
            destination = None
            if output is not None:
                destination = output.joinpath(*checked_relative(row['path']).parts)
                no_links(destination)
                destination.parent.mkdir(parents=True, exist_ok=True)
            stream = destination.open('xb') if destination else None
            try:
                while remaining:
                    chunk = process.stdout.read(min(1024 * 1024, remaining))
                    if not chunk:
                        raise ValueError('Truncated blob')
                    digest.update(chunk)
                    if stream:
                        stream.write(chunk)
                    remaining -= len(chunk)
                if process.stdout.read(1) != b'\n' or digest.hexdigest() != row['sha256']:
                    raise ValueError('Payload verification failed: ' + row['path'])
            finally:
                if stream:
                    stream.close()
            total += row['bytes']
        process.stdin.close()
        if process.wait() != 0:
            raise RuntimeError('git cat-file failed')
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait()
        process.stdout.close()
    return {'passed': True, 'files': len(seen), 'bytes': total,
            'source_commit': source, 'output': str(output) if output else None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding='utf-8'))
    print(json.dumps(restore(manifest, args.output), ensure_ascii=False))


if __name__ == '__main__':
    main()
