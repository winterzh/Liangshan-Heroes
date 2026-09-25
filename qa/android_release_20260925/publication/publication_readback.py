"""Read-only checks of published Android 2.0 and untouched desktop channels."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.request

ROOT = Path('/Users/dztdash/Antigravity/ra-aa')
OUT = Path('/tmp/lsh_android_v2_public_20260925')
OUT.mkdir(exist_ok=False)
def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
source = (ROOT / 'scripts/android_updater.gd').read_text()
public = re.search(r'const MANIFEST_PUBLIC_KEY := """(.*?)"""', source, re.S)[1]
(OUT / 'pinned_public.pem').write_text(public)
channels = {}
for platform in ('android', 'windows', 'macos'):
    for suffix in ('json', 'sig'):
        with opener.open(f'http://120.26.237.195:1234/liangshan/{platform}/stable/manifest.{suffix}', timeout=30) as response:
            (OUT / f'{platform}_manifest.{suffix}').write_bytes(response.read())
    signature = OUT / f'{platform}_signature.bin'
    signature.write_bytes(base64.b64decode((OUT / f'{platform}_manifest.sig').read_bytes(), validate=True))
    subprocess.run(['openssl', 'dgst', '-sha256', '-verify', str(OUT / 'pinned_public.pem'),
                    '-signature', str(signature), str(OUT / f'{platform}_manifest.json')], check=True)
    data = json.loads((OUT / f'{platform}_manifest.json').read_text())
    unchanged = {}
    for suffix in ('json', 'sig'):
        unchanged[suffix] = (OUT / f'{platform}_manifest.{suffix}').read_bytes() == (ROOT / f'qa/android_release_20260925/server_before/{platform}_manifest.{suffix}').read_bytes()
    if platform != 'android':
        assert all(unchanged.values())
    else:
        assert data['content_version'] == '2.0' and data['min_bootstrap'] == 4 and data['patch'] is None
        assert data['packaged_base'] == data['patch_base'] and data['patch_base']['version'] == '2.0'
        assert data['full_apk']['version_name'] == '2.0' and data['full_apk']['version_code'] == 16
        assert data['full_apk']['sha256'] == sha(ROOT / 'build/LiangshanHeroes-v2.0.apk')
        assert data['patch_base']['sha256'] == sha(ROOT / 'build/updates/android/base-2.0.pck')
    channels[platform] = {'version': data['content_version'], 'signature_verified': True,
                          'manifest_sha256': sha(OUT / f'{platform}_manifest.json'),
                          'signature_sha256': sha(OUT / f'{platform}_manifest.sig'), 'unchanged': unchanged}

release_raw = subprocess.check_output(['gh', 'release', 'view', 'v2.0', '--repo', 'winterzh/Liangshan-Heroes',
                                       '--json', 'tagName,isDraft,isPrerelease,assets,url,body,publishedAt'])
(OUT / 'github_release.json').write_bytes(release_raw)
release = json.loads(release_raw)
assert release['tagName'] == 'v2.0' and not release['isDraft'] and not release['isPrerelease']
assert release['body'].strip() == (ROOT / 'qa/android_release_20260925/release_notes.md').read_text().strip()
assert len(release['assets']) == 1
asset = release['assets'][0]
expected = sha(ROOT / 'build/LiangshanHeroes-v2.0.apk')
assert asset['name'] == 'LiangshanHeroes-v2.0.apk' and asset['size'] == 344116603 and asset['digest'] == 'sha256:' + expected
downloads = {}
for label, path in {
    'github': Path('/tmp/lsh_android_v2_github_download_20260925/LiangshanHeroes-v2.0.apk'),
    'update_server': ROOT / 'build/update-publish/baseline-2.0/android/public-LiangshanHeroes-v2.0.apk'
}.items():
    assert sha(path) == expected and path.stat().st_size == asset['size']
    downloads[label] = {'bytes': path.stat().st_size, 'sha256': expected}
env = dict(os.environ, DEVELOPER_DIR='/Library/Developer/CommandLineTools')
remote = subprocess.check_output(['/usr/bin/git', 'ls-remote', 'origin', 'refs/heads/codex/sync-20260905-stable', 'refs/tags/v2.0', 'refs/tags/v2.0^{}'], cwd=ROOT, env=env, text=True)
refs = {line.split()[1]: line.split()[0] for line in remote.splitlines()}
assert refs['refs/tags/v2.0^{}'] == '9cf45c7204d3a3f6a31a3d3765b3bf5db8439a80'
report = {'passed': True, 'channels': channels, 'downloads': downloads, 'remote_refs': refs,
          'release_url': release['url'], 'release_published_at': release['publishedAt'], 'github_asset_id': asset['id'],
          'native_android_tested': False, 'steam_changed': False}
(OUT / 'publication_receipt.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(report, ensure_ascii=False, indent=2))
