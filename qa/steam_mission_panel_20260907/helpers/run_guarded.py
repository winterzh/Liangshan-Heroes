"""Read-only preflight by default; --run builds/tests, --zip packages reviewed bytes.

Runtime sources: public 443e75e plus exactly the committed f3da82f mission panel.
No upload, Steam login, branch activation, Git write, or production mutation.
"""
from pathlib import Path
import argparse, hashlib, json, os, re, runpy, subprocess, sys, uuid
sys.dont_write_bytecode = True
BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import run_stabilization_performance as guard
import hotfix_runtime as runtime

ENGINE_SHA = 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00'
TEMPLATE_SHA = '91724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6'
LOCK = ROOT/'.godot/redraw_rejection_source.lock'
BASELINE = '443e75e887afd76f9569cae17b0527a72408aedc'
OVERLAY = 'f3da82f7452a2164c704c34a97c6b2696e99b9c3'

def production():
    names = subprocess.check_output(['git','ls-files','-z','--cached','--others','--exclude-standard'],cwd=ROOT).decode('utf8').split('\0')
    names = sorted({p for p in names if p and (p in guard.FIXED or p.split('/')[0] in guard.DIRS)})
    return {p:runtime.sha(ROOT/p) for p in names if (ROOT/p).is_file()}

def binary_processes():
    command = "@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' -or $_.ProcessName -like 'LiangshanHeroes*' } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"
    raw = subprocess.check_output(['powershell.exe','-NoProfile','-NonInteractive','-Command',command],text=True).strip()
    value = json.loads(raw) if raw else []
    return value if isinstance(value,list) else [value]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--run',action='store_true')
    mode.add_argument('--zip',action='store_true')
    parser.add_argument('--godot')
    parser.add_argument('--template')
    parser.add_argument('--profile-root',type=Path,required=True)
    args = parser.parse_args()
    engine = Path(args.godot or os.environ.get('GODOT_PATH','') or (ROOT/'godot.local.txt').read_text(encoding='utf-8-sig').strip()).resolve()
    template = Path(args.template or os.environ.get('GODOT_RELEASE_TEMPLATE','') or Path(os.environ['APPDATA'])/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe').resolve()
    guard.need(runtime.sha(engine)==ENGINE_SHA and runtime.sha(template)==TEMPLATE_SHA,'Unexpected Godot/template bytes')
    guard.need(args.profile_root.is_absolute() and len(str(args.profile_root))<=45,'Use an absolute short profile parent (at most 45 characters)')
    for path in (BASE,args.profile_root,engine,template,LOCK): guard.no_links(path)
    manifest = json.loads((BASE/'source_manifest.json').read_text(encoding='utf8'))
    guard.need(manifest['source_commit']==BASELINE and manifest['overlay_commit']==OVERLAY and len(manifest['overlays'])==1,'Wrong hotfix identity')
    snapshot = runpy.run_path(str(BASE/'freeze_snapshot.py'),run_name='snapshot_preflight')
    # The readonly check does not write a verification receipt.
    for row in manifest['files']:
        guard.need(runtime.sha(BASE/'source'/row['path'])==row['sha256'],'Immutable source changed: '+row['path'])
    helpers = [p for p in BASE.iterdir() if p.suffix in ('.py','.gd')]
    helper_hashes = {str(p):runtime.sha(p) for p in helpers}
    helper_hashes[str(ROOT/'tools/run_stabilization_performance.py')] = runtime.sha(ROOT/'tools/run_stabilization_performance.py')
    source_before = production()
    name = json.loads(re.findall(r'^config/name=("[^\n]+")\s*$',(BASE/'source/project.godot').read_text(encoding='utf8'),re.M)[0])
    players = {str(Path(os.environ[key])/'Godot/app_userdata'/name) for key in ('APPDATA','LOCALAPPDATA')}
    players_before = {p:guard.snapshot(Path(p)) for p in players}
    info = {'preflight':True,'source_commit':BASELINE,'overlay_commit':OVERLAY,'source_manifest_sha256':runtime.sha(BASE/'source_manifest.json'),
            'runtime_files':len(manifest['files']),'protected_production_files':len(source_before),
            'godot':str(engine),'template':str(template),'engine_sha256':ENGINE_SHA,'template_sha256':TEMPLATE_SHA,
            'lock_busy':LOCK.exists(),'active_game_pids':binary_processes(),'profile_root':str(args.profile_root)}
    print(json.dumps(info,ensure_ascii=False),flush=True)
    if not args.run and not args.zip: return
    guard.need(not info['lock_busy'] and not info['active_game_pids'],'Shared Godot window is occupied')
    target_receipt = BASE/('zip_guard_receipt.json' if args.zip else 'guard_receipt.json')
    guard.need(not target_receipt.exists(),'Prior execution receipt exists; preserve it and prepare a new batch')
    owner = json.dumps({'owner':'mission_panel_steam_hotfix','pid':os.getpid(),'token':uuid.uuid4().hex})
    receipt = dict(info,complete=False,steps=[],source_before=source_before,players_before=players_before,helper_sha256=helper_hashes)
    profile = args.profile_root/('mhp_'+uuid.uuid4().hex[:8])
    guard.no_links(profile)
    original_environment = os.environ.copy()
    owned = False
    try:
        with LOCK.open('x',encoding='utf8') as handle:
            handle.write(owner)
            owned = True
        profile.mkdir(parents=True,exist_ok=False)
        switches = set()
        for path in (BASE/'source/scripts').rglob('*.gd'):
            switches.update(re.findall(r'OS\.(?:get_environment|has_environment)\(\s*["\']([A-Z0-9_]+)["\']',path.read_text(encoding='utf-8-sig')))
        for key in switches: os.environ.pop(key,None)
        os.environ.update(HOTFIX_PROFILE=str(profile),GODOT_PATH=str(engine),GODOT_RELEASE_TEMPLATE=str(template),CONTENT_UPDATE_NO_AUTO='1')
        receipt['private_profile'] = str(profile)
        def protect():
            guard.need(LOCK.read_text(encoding='utf8')==owner,'Shared lock ownership changed')
            guard.need(production()==source_before,'Production bytes changed during the source window')
            guard.need({p:guard.snapshot(Path(p)) for p in players}==players_before,'Real player files changed')
            guard.need(all(runtime.sha(Path(p))==digest for p,digest in helper_hashes.items()),'Helper bytes changed')
            guard.need(runtime.sha(engine)==ENGINE_SHA and runtime.sha(template)==TEMPLATE_SHA,'Engine/template changed')
        def before():
            protect()
            guard.need(not binary_processes(),'Unowned game/engine process detected')
        runtime.BEFORE = before
        runtime.AFTER = protect
        before()
        if args.zip:
            runtime.helper('prepare_upload_zip.py')
            receipt['steps'].append('reviewed_upload_zip')
        else:
            snapshot['verify']()
            runtime.helper('build_windows.py')
            receipt['steps'].append('import_export')
            runtime.helper('verify_package.py')
            receipt['steps'].append('contract_smoke_visual')
            build = json.loads((BASE/'build_receipt.json').read_text(encoding='utf8'))
            exe = Path(build['executable'])
            env = runtime.private_env('toggle')
            env.update(CAMPAIGN_TOGGLE_OUT=str(BASE/'toggle'),CAMPAIGN_QA='1',CONTENT_UPDATE_NO_AUTO='1')
            command = [str(engine),'--main-pack',str(exe),'--rendering-method','forward_plus','--rendering-driver','vulkan','--script',str(BASE/'campaign_objective_toggle_test.gd')]
            with (BASE/'toggle.console.log').open('xb') as output:
                result = runtime.run_child(command,cwd=exe.parent,env=env,stdout=output,stderr=subprocess.STDOUT,timeout=300)
            lines = (BASE/'toggle.console.log').read_text(encoding='utf8',errors='replace')
            errors = [line for line in lines.splitlines() if guard.ERROR.search(line)]
            report = json.loads((BASE/'toggle/report.json').read_text(encoding='utf8'))
            guard.need(result.returncode==0 and not errors and report['passed'] and report['checks']==115,'Same-package toggle QA failed')
            guard.need(runtime.sha(exe)==build['sha256'],'EXE changed during same-package toggle test')
            runtime.save(BASE/'toggle_package_receipt.json',{'passed':True,'checks':report['checks'],'source_commit':BASELINE,'overlay_commit':OVERLAY,
                'source_manifest_sha256':build['source_manifest_sha256'],'executable_sha256':build['sha256'],
                'driver_sha256':runtime.sha(BASE/'campaign_objective_toggle_test.gd'),'report_sha256':runtime.sha(BASE/'toggle/report.json'),
                'mount_command':command,'errors':errors,'scope':'Exact exported embedded-PCK mount with committed real-click driver; not full campaign.'})
            receipt['steps'].append('same_package_toggle_115')
            snapshot['verify']()
        protect()
        receipt['complete'] = True
    except BaseException as error:
        receipt['error'] = type(error).__name__+': '+str(error)
        raise
    finally:
        os.environ.clear()
        os.environ.update(original_environment)
        if owned:
            receipt['source_unchanged'] = production()==source_before
            receipt['players_unchanged'] = {p:guard.snapshot(Path(p)) for p in players}==players_before
            receipt['all_children_exited'] = runtime.ACTIVE is None and all(p['child_exit_confirmed'] for p in runtime.PROCESSES)
            receipt['remaining_game_pids'] = binary_processes()
            safe = receipt['all_children_exited'] and not receipt['remaining_game_pids'] and LOCK.read_text(encoding='utf8')==owner
            if safe:
                LOCK.unlink()
                receipt['lock_released'] = True
            else: receipt['lock_released'] = False
            receipt['complete'] = receipt['complete'] and receipt['source_unchanged'] and receipt['players_unchanged'] and safe
            runtime.save(target_receipt,receipt)
            print('GUARD_RECEIPT '+str(target_receipt),flush=True)
            guard.need(safe,'Child exit unconfirmed: shared lock retained')

if __name__=='__main__': main()
