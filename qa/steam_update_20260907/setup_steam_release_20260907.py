from pathlib import Path
import hashlib, json, subprocess

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / '.godot/steam_update_20260907'
COMMIT = '443e75e887afd76f9569cae17b0527a72408aedc'
assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT).decode().strip() == COMMIT
assert not DEST.exists()
DEST.mkdir(parents=True)
names = ['freeze_snapshot.py', 'build_windows.py', 'verify_package.py',
         'package_contract.gd', 'prepare_upload_zip.py', 'finalize_archive_manifest.py']
rows = []
for name in names:
    raw = subprocess.check_output(['git', 'show', f'{COMMIT}:qa/steam_update_20260906/{name}'], cwd=ROOT)
    text = raw.decode('utf8')
    if name == 'freeze_snapshot.py':
        text = text.replace('954ffde683e79fe90656e5acba78692bc5de67b8', COMMIT)
    if name in ('build_windows.py', 'verify_package.py'):
        text = 'import sys\n' + text
        text = text.replace("['py','-3','-X','utf8','-B',", "[sys.executable,'-X','utf8','-B',")
        text = text.replace('and not errors,row', 'and not errors and not warnings,row')
        text = text.replace("result.returncode==0 and not errors}", "result.returncode==0 and not errors and not warnings}")
    if name == 'build_windows.py':
        text = text.replace("'godot':str(GODOT),", "'godot':str(GODOT),'godot_sha256':hashlib.sha256(GODOT.read_bytes()).hexdigest(),")
    if name == 'prepare_upload_zip.py':
        text = text.replace('LiangshanHeroes-Windows-20260906.zip', 'LiangshanHeroes-Windows-20260907.zip')
        text = text.replace("hashlib.file_digest(stream,'sha256').hexdigest()", "hashlib.sha256(stream.read()).hexdigest()")
        text = text.replace("assert verification['passed'] and review['passed']", "assert verification['passed'] and review['passed']\nassert review['executable_sha256'] == build['sha256']\nassert verification['sha256'] == build['sha256']")
    out = text.encode('utf8')
    (DEST / name).write_bytes(out)
    rows.append({'path': name, 'prior_helper_sha256': hashlib.sha256(raw).hexdigest(), 'sha256': hashlib.sha256(out).hexdigest()})
(DEST / 'helper_preparation.json').write_text(json.dumps({'source_commit': COMMIT, 'prior_receipt': 'qa/steam_update_20260906', 'files': rows, 'changes': ['Freeze latest verified stable source', 'Use current Python interpreter', 'Reject warnings as well as errors', 'Pin Godot binary digest', 'New ZIP filename and Python 3.9 compatible checksum', 'Bind visual review and package verification to exact EXE']}, indent=2) + '\n', encoding='utf8')
print(DEST)
