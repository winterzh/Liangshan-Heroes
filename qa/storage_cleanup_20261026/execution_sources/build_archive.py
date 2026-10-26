import os, json, gzip, hashlib, zipfile, time
from pathlib import Path

ROOT = Path(r'D:\AI项目\水浒\开发工程')
OUT = Path(r'D:\CodexTemp\shuihu-cleanup-20261026')
ARCHIVE = Path(r'D:\AI项目\水浒\归档\水浒_旧测试工程去重归档_20261026.zip')

def main():
    started = time.time()
    with gzip.open(OUT / 'manifest.json.gz', 'rt', encoding='utf-8') as f:
        manifest = json.load(f)
    if 'directories' not in manifest:
        directories = []
        for rel in manifest['roots']:
            for base, dirs, names in os.walk('\\\\?\\' + str(ROOT / rel), followlinks=False):
                for name in dirs[:]:
                    if name == '.godot' or os.stat(os.path.join(base, name), follow_symlinks=False).st_file_attributes & 0x400:
                        dirs.remove(name)
                directories.append(Path(base[4:]).relative_to(ROOT).as_posix())
        manifest['directories'] = sorted(set(directories))
        with gzip.open(OUT / 'manifest.json.gz', 'wt', encoding='utf-8') as f:
            json.dump(manifest, f, ensure_ascii=False, separators=(',', ':'))
    unique = {}
    for row in manifest['files']:
        old = unique.setdefault(row['sha256'], row)
        assert old['bytes'] == row['bytes']
    partial = ARCHIVE.with_suffix('.zip.partial')
    if ARCHIVE.exists() or partial.exists():
        raise RuntimeError('Archive output already exists; do not overwrite')
    with zipfile.ZipFile(partial, 'x', zipfile.ZIP_DEFLATED, compresslevel=4, allowZip64=True) as z:
        z.writestr('manifest.json', json.dumps(manifest, ensure_ascii=False, separators=(',', ':')))
        z.write(OUT / 'restore_archive.py', 'restore_archive.py')
        z.writestr('README.txt', 'Water Margin historical private project snapshots, 2026-10-26.\n'
                    'Unique file bytes are stored at blobs/<SHA-256>. manifest.json maps every original path.\n'
                    'All project/.godot subtrees and external run evidence stay at their original paths.\n'
                    'Verify: python restore_archive.py ARCHIVE.zip DESTINATION --verify-only\n'
                    'Restore one project: python restore_archive.py ARCHIVE.zip DESTINATION --prefix .godot/FAMILY/RUN/project/\n'
                    'Use a new destination to inspect first. Different existing files are never overwritten.\n')
        for i, (sha, row) in enumerate(unique.items(), 1):
            p = '\\\\?\\' + str(ROOT / row['path'])
            s = os.stat(p, follow_symlinks=False)
            if s.st_size != row['bytes'] or s.st_mtime_ns != row['mtime_ns']:
                raise RuntimeError('Source changed: ' + row['path'])
            digest = hashlib.sha256()
            with open(p, 'rb') as f, z.open('blobs/' + sha, 'w', force_zip64=True) as dest:
                while data := f.read(1024 * 1024):
                    digest.update(data)
                    dest.write(data)
            if digest.hexdigest() != sha:
                raise RuntimeError('Content changed: ' + row['path'])
            if i % 2000 == 0:
                print(json.dumps({'archived_unique_blobs': i, 'elapsed_s': round(time.time()-started)}), flush=True)
    with zipfile.ZipFile(partial, 'r') as z:
        reread = json.loads(z.read('manifest.json'))
        if reread != manifest:
            raise RuntimeError('Manifest mismatch')
        total = 0
        for i, (sha, row) in enumerate(unique.items(), 1):
            h = hashlib.sha256(); size = 0
            with z.open('blobs/' + sha, 'r') as f:
                while data := f.read(1024 * 1024):
                    h.update(data); size += len(data)
            if h.hexdigest() != sha or size != row['bytes']:
                raise RuntimeError('Archive verification failed: ' + sha)
            total += size
        if z.read('restore_archive.py') != (OUT / 'restore_archive.py').read_bytes():
            raise RuntimeError('Restore tool mismatch')
    os.rename(partial, ARCHIVE)
    with ARCHIVE.open('rb') as f:
        archive_sha = hashlib.file_digest(f, 'sha256').hexdigest()
    summary = {'archive': str(ARCHIVE), 'archive_bytes': ARCHIVE.stat().st_size, 'archive_sha256': archive_sha,
               'mapped_files': len(manifest['files']), 'mapped_bytes': sum(r['bytes'] for r in manifest['files']),
               'unique_blobs': len(unique), 'verified_unique_bytes': total, 'all_blob_sha256_passed': True,
               'manifest_roundtrip_passed': True, 'elapsed_s': round(time.time()-started)}
    (OUT / 'archive_verification.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(summary, ensure_ascii=False), flush=True)

if __name__ == '__main__':
    main()
