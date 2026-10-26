import os, json, hashlib, gzip, time, shutil, concurrent.futures
from pathlib import Path

ROOT = Path(r'D:\AI项目\水浒\开发工程')
OUT = Path(r'D:\CodexTemp\shuihu-cleanup-20261026')
ROOTS = json.loads((OUT / 'candidate_roots.json').read_text(encoding='utf-8'))

def extended(p):
    return '\\\\?\\' + str(p)

def digest(rel):
    p = ROOT / rel
    s = os.stat(extended(p), follow_symlinks=False)
    if s.st_file_attributes & 0x400:
        raise RuntimeError('Reparse file: ' + rel)
    with open(extended(p), 'rb') as f:
        h = hashlib.file_digest(f, 'sha256').hexdigest()
    t = os.stat(extended(p), follow_symlinks=False)
    if (s.st_size, s.st_mtime_ns, s.st_ino) != (t.st_size, t.st_mtime_ns, t.st_ino):
        raise RuntimeError('Changed while hashing: ' + rel)
    return {'path': rel, 'bytes': s.st_size, 'sha256': h, 'mtime_ns': s.st_mtime_ns,
            'links': s.st_nlink, 'file_id': s.st_ino}

def enumerate_files(root):
    for base, dirs, names in os.walk(extended(root), followlinks=False):
        for name in dirs[:]:
            p = os.path.join(base, name)
            if os.stat(p, follow_symlinks=False).st_file_attributes & 0x400:
                dirs.remove(name)
        for name in names:
            yield Path(os.path.join(base, name)[4:]).relative_to(ROOT).as_posix()

def main():
    start = time.time()
    targets = []
    for rel in ROOTS:
        root = ROOT / rel
        if not root.resolve().is_relative_to(ROOT / '.godot') or not rel.endswith('/project'):
            raise RuntimeError('Invalid root: ' + rel)
        for p in (root, *root.parents):
            if p.is_symlink() or p.is_junction():
                raise RuntimeError('Reparse ancestor: ' + str(p))
        for path in enumerate_files(root):
            tail = path[len(rel)+1:]
            if tail == '.godot' or tail.startswith('.godot/'):
                continue
            targets.append(path)
    targets = sorted(set(targets))
    print(json.dumps({'phase': 'hash_targets', 'files': len(targets)}), flush=True)
    rows = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        for i, row in enumerate(pool.map(digest, targets), 1):
            if row['links'] != 1:
                raise RuntimeError('Target is hard linked: ' + row['path'])
            rows.append(row)
            if i % 25000 == 0:
                print(json.dumps({'hashed': i, 'elapsed_s': round(time.time()-start)}), flush=True)
    unique = {}
    for row in rows:
        unique.setdefault(row['sha256'], row)
    manifest = {'schema_version': 1, 'source_root': ROOT.as_posix(), 'date': '2026-10-26',
                'roots': ROOTS, 'excluded': 'All nested .godot directories remain in place; all run results, logs and profiles outside project remain in place.',
                'files': rows}
    directories = []
    for rel in ROOTS:
        for base, dirs, names in os.walk(extended(ROOT / rel), followlinks=False):
            for name in dirs[:]:
                p = os.path.join(base, name)
                if name == '.godot' or os.stat(p, follow_symlinks=False).st_file_attributes & 0x400:
                    dirs.remove(name)
            directories.append(Path(base[4:]).relative_to(ROOT).as_posix())
    manifest['directories'] = sorted(set(directories))
    with gzip.open(OUT / 'manifest.json.gz', 'wt', encoding='utf-8') as f:
        json.dump(manifest, f, ensure_ascii=False, separators=(',', ':'))
    targetset = set(targets)
    protected = []
    for rel in enumerate_files(ROOT):
        if rel.startswith('.git/') or rel in targetset:
            continue
        protected.append(rel)
    print(json.dumps({'phase': 'hash_protected', 'files': len(protected)}), flush=True)
    with gzip.open(OUT / 'protected_before.jsonl.gz', 'wt', encoding='utf-8') as f:
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            for i, row in enumerate(pool.map(digest, protected), 1):
                f.write(json.dumps(row, ensure_ascii=False, separators=(',', ':')) + '\n')
                if i % 50000 == 0:
                    print(json.dumps({'protected_hashed': i, 'elapsed_s': round(time.time()-start)}), flush=True)
    summary = {'target_files': len(rows), 'target_bytes': sum(r['bytes'] for r in rows),
               'unique_blobs': len(unique), 'unique_bytes': sum(r['bytes'] for r in unique.values()),
               'protected_files': len(protected), 'free_bytes_before': shutil.disk_usage(ROOT).free,
               'elapsed_s': round(time.time()-start)}
    (OUT / 'prepare_summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print(json.dumps(summary), flush=True)

if __name__ == '__main__':
    main()
