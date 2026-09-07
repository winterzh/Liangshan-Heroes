"""One-time preparation only. No Godot, export, upload, or production writes."""
from pathlib import Path
import hashlib, json, subprocess

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[1]
ARCHIVE = ROOT / 'qa/steam_update_20260907'
OVERLAY = 'f3da82f7452a2164c704c34a97c6b2696e99b9c3'
rows = []

def replace(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new)

def finish(name, text):
    original = (ARCHIVE / name).read_bytes()
    target = BASE / name
    target.write_text(text, encoding='utf-8', newline='\n')
    rows.append({'path': name, 'original_archive': str((ARCHIVE / name).relative_to(ROOT)),
                 'before_sha256': hashlib.sha256(original).hexdigest(),
                 'after_sha256': hashlib.sha256(target.read_bytes()).hexdigest()})

text = (ARCHIVE / 'freeze_snapshot.py').read_text(encoding='utf-8')
text = replace(text, "BASE = Path(__file__).resolve().parent", "OVERLAY_COMMIT = '" + OVERLAY + "'\nOVERLAY_PATH = 'scripts/campaign_mission.gd'\nBASE = Path(__file__).resolve().parent")
text = replace(text, "    rows=inventory()", """    rows=inventory()
    baseline = json.loads((ROOT/'qa/steam_update_20260907/source_manifest.json').read_text(encoding='utf8'))
    assert [(r['path'],r['git_blob']) for r in rows] == [(r['path'],r['git_blob']) for r in baseline['files']]
    original = next(r for r in baseline['files'] if r['path'] == OVERLAY_PATH)
    overlay_blob = subprocess.check_output(['git','rev-parse',OVERLAY_COMMIT+':'+OVERLAY_PATH],cwd=ROOT,text=True).strip()
    assert original['git_blob'] == '83535c0b52bd69640220f5c7f1b7bd1228a416f5'
    assert overlay_blob == 'db8f4edc30d238f446461334899b041766a744cb'
    for row in rows:
        row['origin_commit'] = OVERLAY_COMMIT if row['path'] == OVERLAY_PATH else COMMIT
        if row['path'] == OVERLAY_PATH: row['git_blob'] = overlay_blob""")
text = replace(text, "    process.stdin.close(); assert process.wait()==0", """    process.stdin.close(); assert process.wait(timeout=30)==0
    baseline_by_path = {r['path']:r for r in baseline['files']}
    changed = [r for r in rows if r['sha256'] != baseline_by_path[r['path']]['sha256']]
    assert len(changed) == 1 and changed[0]['path'] == OVERLAY_PATH
    overlay = {'path':OVERLAY_PATH, 'before_git_blob':original['git_blob'], 'after_git_blob':overlay_blob,
               'before_sha256':original['sha256'], 'after_sha256':changed[0]['sha256'],
               'before_size_bytes':original['size_bytes'], 'after_size_bytes':changed[0]['size_bytes']}""")
text = replace(text, "'kind':'steam_windows_update_committed_runtime_snapshot','source_commit':COMMIT,", "'kind':'steam_windows_public_baseline_single_file_hotfix','source_commit':COMMIT,\n             'overlay_commit':OVERLAY_COMMIT,'overlays':[overlay],'runtime_inventory_matches_public_baseline':True,\n             'baseline_manifest_sha256':sha((ROOT/'qa/steam_update_20260907/source_manifest.json').read_bytes()),")
text = replace(text, "    forbidden=[p for p in extras if not p.endswith('.uid')]", "    known_uids = json.loads((ROOT/'qa/steam_update_20260907/source_verification.json').read_text(encoding='utf8'))['generated_uids']\n    forbidden=[p for p in extras if p not in known_uids]")
text = replace(text, "report={'passed':not differences and not forbidden,'source_commit':COMMIT", "report={'passed':not differences and not importer_changes and not forbidden,'source_commit':COMMIT,\n            'overlay_commit':OVERLAY_COMMIT,'source_manifest_sha256':sha((BASE/'source_manifest.json').read_bytes())")
finish('freeze_snapshot.py', text)

for name in ['build_windows.py', 'verify_package.py']:
    text = (ARCHIVE / name).read_text(encoding='utf-8')
    text = 'from hotfix_runtime import run_child, private_env\n' + text
    text = text.replace('subprocess.run(', 'run_child(')
    old = "run_child([sys.executable,'-X','utf8','-B',str(BASE/'freeze_snapshot.py'),'verify'],check=True)"
    text = replace(text, old, "import runpy\nrunpy.run_path(str(BASE/'freeze_snapshot.py'),run_name='snapshot_verify')['verify']()")
    if name == 'build_windows.py':
        text = replace(text, "DATA=BASE/'userdata'/'export'", "DATA=Path(os.environ['HOTFIX_PROFILE'])/'export'/'appdata'")
        text = replace(text, "TEMPLATE=Path(os.environ['APPDATA'])/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe'", "TEMPLATE=Path(os.environ['GODOT_RELEASE_TEMPLATE'])")
        text = replace(text, "env=os.environ.copy();env['APPDATA']=str(DATA);env['CONTENT_UPDATE_NO_AUTO']='1'", "env=private_env('export');env['CONTENT_UPDATE_NO_AUTO']='1'")
        text = replace(text, "'godot_version':subprocess.check_output([str(GODOT),'--version'],creationflags=subprocess.CREATE_NO_WINDOW).decode().strip(),", "'godot_version':run_child([str(GODOT),'--version'],env=env,capture_output=True,timeout=30).stdout.decode().strip(),\n   'overlay_commit':d['overlay_commit'],'overlays':d['overlays'],'source_manifest_sha256':hashlib.sha256((BASE/'source_manifest.json').read_bytes()).hexdigest(),")
    else:
        text = replace(text, "case_env=env.copy();case_env['APPDATA']=str(BASE/'userdata'/name)", "case_env=private_env(name,env)")
        text = replace(text, "smoke=(ROOT/'qa/steam_test_build_20260905/run_package_smoke.py').read_text(encoding='utf8')", "smoke=(BASE/'frozen_run_package_smoke.py').read_text(encoding='utf8')")
        text = replace(text, "execute('smoke_driver',[sys.executable,'-X','utf8','-B',str(BASE/'run_package_smoke.py')],\n        {'LIANGSHAN_TEST_EXE':str(EXE),'LIANGSHAN_TEST_DATA':str(BASE/'userdata/smoke')},timeout=600)", "from hotfix_runtime import run_smoke\nrun_smoke(BASE/'run_package_smoke.py', EXE, env)")
        text = replace(text, "visual=(ROOT/'qa/steam_test_build_20260905/package_visual_capture.gd').read_text(encoding='utf8')", "visual=(BASE/'frozen_package_visual_capture.gd').read_text(encoding='utf8')")
        text = replace(text, "r={'passed':True,'source_commit':build['source_commit'],'executable':str(EXE)", "r={'passed':True,'source_commit':build['source_commit'],'overlay_commit':build['overlay_commit'],\n   'source_tree_sha256':build['source_tree_sha256'],'source_manifest_sha256':build['source_manifest_sha256'],'executable':str(EXE)")
    finish(name, text)

name = 'prepare_upload_zip.py'
text = (ARCHIVE / name).read_text(encoding='utf8')
text = replace(text, "assert review['source_commit'] == build['source_commit']", """assert review['source_commit'] == build['source_commit']
assert verification['overlay_commit'] == review['overlay_commit'] == build['overlay_commit']
assert verification['source_manifest_sha256'] == review['source_manifest_sha256'] == build['source_manifest_sha256']
toggle = json.loads((BASE/'toggle_package_receipt.json').read_text(encoding='utf8'))
assert toggle['passed'] and toggle['checks'] == 115 and toggle['executable_sha256'] == build['sha256']
assert review['toggle_review_passed'] and review['toggle_report_sha256'] == toggle['report_sha256']
toggle_report = json.loads((BASE/'toggle/report.json').read_text(encoding='utf8'))
assert toggle_report['passed'] and toggle_report['checks'] == 115
assert hashlib.sha256((BASE/'toggle/report.json').read_bytes()).hexdigest() == toggle['report_sha256']
for sample in toggle_report['samples']:
    path = Path(sample['png'])
    assert path.resolve().parent == (BASE/'toggle').resolve()
    assert hashlib.sha256(path.read_bytes()).hexdigest() == sample['sha256']""")
text = replace(text, "'LiangshanHeroes-Windows-20260907.zip'", "'LiangshanHeroes-Windows-mission-panel-20260907.zip'")
text = replace(text, "'executable':str(exe),'executable_size_bytes'", "'overlay_commit':build['overlay_commit'],'source_tree_sha256':build['source_tree_sha256'],'source_manifest_sha256':build['source_manifest_sha256'],\n   'executable':str(exe),'executable_size_bytes'")
finish(name, text)

for source, target, commit in [
    ('qa/steam_test_build_20260905/run_package_smoke.py','frozen_run_package_smoke.py','443e75e887afd76f9569cae17b0527a72408aedc'),
    ('qa/steam_test_build_20260905/package_visual_capture.gd','frozen_package_visual_capture.gd','443e75e887afd76f9569cae17b0527a72408aedc'),
    ('tools/campaign_objective_toggle_test.gd','campaign_objective_toggle_test.gd',OVERLAY)]:
    raw = subprocess.check_output(['git','show',commit+':'+source],cwd=ROOT)
    (BASE/target).write_bytes(raw)
    rows.append({'path':target,'git_source':source,'commit':commit,'git_blob':subprocess.check_output(['git','rev-parse',commit+':'+source],cwd=ROOT,text=True).strip(),'after_sha256':hashlib.sha256(raw).hexdigest()})
(BASE/'helper_preparation.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('Prepared helpers; no Godot executed.')
