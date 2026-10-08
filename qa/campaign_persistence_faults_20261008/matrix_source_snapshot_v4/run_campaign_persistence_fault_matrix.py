"""Run all nineteen v27b Campaign component cases against actual private disk faults."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import time
import uuid

from godot_debug_wire import DebugConnection, stack_frames
from run_steam_integration_qa import ROOT, LOCK, sources, native_dependencies, install_native, resolve_godot
from run_workstation_baseline import engines
from windows_owned_oplock import OwnedOplock

PROPOSAL = ROOT / 'qa/zhu_wounded_20261005/proposals/campaign_persistence_observability_v27/proposed_b/scripts/campaign.gd'
PROPOSAL_SHA = 'a5ad0a3197274c76c2b1fef8dbabc0371bbe36a480a38b722003bf9e94a9a482'
MATRIX = ROOT / 'qa/zhu_wounded_20261005/proposals/campaign_persistence_observability_v27/FAULT_MATRIX_V27B.json'
MATRIX_SHA = '83fb60c2569c02f09c74bf8318a09544bcfca1c0650add3c710a953b2ddc9320'
DEFAULT_BASELINE = ROOT / 'qa/office_baseline_20261008/baseline/receipt.json'
READ_LINES = {
    'prior_vanished': 'var prior_error: int = cfg.load(SAVE_PATH)',
    'write_readonly': 'observed.disk_state_unconfirmed = true',
    'fresh_load_missing': 'observed.readback_error = readback.load(SAVE_PATH)',
    'semantic_mismatch': 'var before_read_sha: String = FileAccess.get_sha256(SAVE_PATH)',
    'sha_interval_change': 'observed.readback_error = readback.load(SAVE_PATH)',
}

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def write_json(path, value):
    path = Path(path)
    pending = path.with_name(path.name + '.writing-' + uuid.uuid4().hex)
    with pending.open('x', encoding='utf-8', newline='\n') as stream:
        stream.write(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
        stream.flush()
        os.fsync(stream.fileno())
    if path.exists(): raise RuntimeError('Owned immutable controller JSON already exists')
    pending.rename(path)  # Same-directory close then rename: reader never sees a partial acknowledgement.

def no_reparse(path):
    for parent in [path, *path.parents]:
        if parent.exists() and (parent.is_symlink() or getattr(parent.lstat(), 'st_file_attributes', 0) & 0x400):
            raise RuntimeError('Reparse path refused: ' + str(parent))

def attributes(path, value=None):
    api = ctypes.WinDLL('kernel32', use_last_error=True)
    api.GetFileAttributesW.argtypes = [ctypes.c_wchar_p]
    api.GetFileAttributesW.restype = ctypes.c_uint32
    api.SetFileAttributesW.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32]
    api.SetFileAttributesW.restype = ctypes.c_int
    if value is None:
        result = api.GetFileAttributesW(str(path))
        if result == 0xFFFFFFFF: raise ctypes.WinError(ctypes.get_last_error())
        return result
    if not api.SetFileAttributesW(str(path), value): raise ctypes.WinError(ctypes.get_last_error())

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--protocol-receipt', type=Path)
    parser.add_argument('--oplock-receipt', type=Path)
    parser.add_argument('--source-preflight', type=Path)
    parser.add_argument('--baseline', type=Path, default=DEFAULT_BASELINE)
    parser.add_argument('--godot')
    parser.add_argument('--work-root', type=Path, default=Path('D:/CodexTemp/lsh-campaign-faults-20261008'))
    args = parser.parse_args()
    engine = resolve_godot(args.godot)
    baseline = json.loads(args.baseline.read_text(encoding='utf-8'))
    if not baseline.get('complete') or sha(engine) != baseline['engine_sha256']:
        raise RuntimeError('Actual completed baseline and installed engine binding required')
    if sha(PROPOSAL) != PROPOSAL_SHA:
        raise RuntimeError('Fixed independently reviewed v27b Campaign source changed')
    if sha(MATRIX) != MATRIX_SHA: raise RuntimeError('Fixed original full nineteen-case matrix changed')
    matrix = json.loads(MATRIX.read_text(encoding='utf-8'))
    ids = [row['id'] for row in matrix['cases']]
    if len(ids) != 19 or len(set(ids)) != 19: raise RuntimeError('Original full fault matrix required')
    gd = ROOT / 'tools/campaign_persistence_fault_matrix.gd'
    declaration = gd.read_text(encoding='utf-8').split('const IDS := [', 1)[1].split(']\n', 1)[0]
    if re.findall(r'"([A-Za-z_]+)"', declaration) != ids:
        raise RuntimeError('Harness IDs differ from original full matrix')
    lines = PROPOSAL.read_text(encoding='utf-8').splitlines()
    breakpoints = {}
    for fault, target in READ_LINES.items():
        found = [i + 1 for i, line in enumerate(lines) if line.strip() == target]
        if len(found) != 1: raise RuntimeError('Exact actual production statement missing: ' + fault)
        breakpoints[fault] = found[0]
    if not args.run:
        print(json.dumps({'complete_preflight':True, 'cases':ids, 'campaign_sha256':PROPOSAL_SHA,
            'breakpoints':breakpoints, 'native_started':False, 'fault_matrix_qualified':False}))
        return
    if args.protocol_receipt is None: raise RuntimeError('Actual successful owned debugger protocol proof required')
    if args.oplock_receipt is None or args.source_preflight is None:
        raise RuntimeError('Actual Windows opener proof and sealed source preflight required')
    source_seal = json.loads(args.source_preflight.read_text(encoding='utf-8'))
    if not source_seal.get('complete') or source_seal.get('original_ids') != ids:
        raise RuntimeError('All original nineteen source cases must be sealed')
    for row in source_seal['files']:
        if sha(ROOT/row['path']) != row['sha256']: raise RuntimeError('Sealed harness/helper source changed')
    if {row['path'] for row in source_seal['files']} != {'tools/campaign_persistence_fault_matrix.gd',
            'tools/run_campaign_persistence_fault_matrix.py','tools/godot_debug_wire.py','tools/windows_owned_oplock.py',
            'tools/run_campaign_debug_fault_probe.py','tools/run_steam_integration_qa.py','tools/run_workstation_baseline.py'}:
        raise RuntimeError('Complete source/helper seal inventory required')
    windows_proof=json.loads(args.oplock_receipt.read_text(encoding='utf-8'))
    if (not windows_proof.get('complete') or not windows_proof.get('actual_read_blocked_before_release')
            or not windows_proof.get('actual_native_read_saw_appended_bytes')
            or windows_proof['source_sha256']!=sha(ROOT/'tools/windows_owned_oplock.py')):
        raise RuntimeError('Actual Windows file opener proof differs from installed helper')
    proof = json.loads(args.protocol_receipt.read_text(encoding='utf-8'))
    if (not proof.get('complete') or not proof.get('process_terminal') or proof.get('exit_code') != 0
            or not proof.get('actual_debugger_stack_verified') or not proof.get('actual_cfg_read_observed')
            or proof['engine_sha256'] != sha(engine)
            or proof['script_sha256'] != sha(ROOT/'tools/campaign_fault_debug_probe.gd')):
        raise RuntimeError('Protocol preparation or failure cannot qualify real file injection')
    run = args.work_root.absolute()/('campaign_19_' + uuid.uuid4().hex[:8])
    no_reparse(run)
    run.mkdir(parents=True, exist_ok=False)
    project, profile, output = run/'project', run/'profile', run/'output'
    project.mkdir(); profile.mkdir(); output.mkdir()
    receipt = {'schema':'campaign_persistence_fault_matrix_runner_v1', 'complete':False, 'run':str(run),
        'protocol_receipt':str(args.protocol_receipt), 'protocol_receipt_sha256':sha(args.protocol_receipt),
        'oplock_receipt':str(args.oplock_receipt), 'oplock_receipt_sha256':sha(args.oplock_receipt),
        'source_preflight_sha256':sha(args.source_preflight),
        'baseline_sha256':sha(args.baseline), 'engine_sha256':sha(engine), 'source_inputs':[], 'mutations':[],
        'cases':ids, 'campaign_runtime_patches':0, 'proposal_installed_at_original_path':True,
        'cfg_return_values_simulated':False, 'player_UI_qualified':False, 'crash_recovery_qualified':False,
        'natural_battle_qualified':False, 'reward_once_qualified':False, 'cloud_upload_qualified':False, 'steps':[]}
    child = listener = connection = None
    acquired = False
    readonly_original = None
    oplock = None
    oplock_request = None
    cfg_path = profile/'appdata/Godot/app_userdata/水浒英雄传：八幕战役/campaign.cfg'
    try:
        native = native_dependencies()
        pins = {}
        names = sources() + ['tools/campaign_persistence_fault_matrix.gd']
        for name in names:
            source = PROPOSAL if name == 'scripts/campaign.gd' else ROOT/name
            pins[str(source)] = sha(source)
            destination = project/name; destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(source.read_bytes())
            if sha(destination) != pins[str(source)]: raise RuntimeError('Source copy drift')
            receipt['source_inputs'].append({'source':str(source), 'installed':name, 'sha256':sha(destination)})
        for source in [ROOT/row['path'] for row in source_seal['files']] + [MATRIX,args.protocol_receipt,args.baseline,args.oplock_receipt,args.source_preflight]:
            pins[str(source)] = sha(source)
        for row in baseline['source_files']:
            source = ROOT/row['path']
            if sha(source) != row['sha256']: raise RuntimeError('Actual baseline source changed: ' + row['path'])
        receipt['native_dependencies'] = install_native(project)
        scene = project/'tools/campaign_persistence_fault_matrix.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tools/campaign_persistence_fault_matrix.gd" id="1"]\n[node name="CampaignFaultMatrix" type="Node"]\nscript = ExtResource("1")\n', encoding='utf-8')
        env = os.environ.copy()
        for key in list(env):
            if key.endswith(('_QA', '_TEST', '_QA_MANIFEST', '_AUDIT')) or key.startswith('STEAM_') or key in {
                'LEVEL','SCENARIO','CUSTOM_DEFENSE','SKIRMISH','SKIRMISH_AI','ARENA','AUTO_MICRO','AUTOMICRO',
                'SMOKE_TEST','SCREENSHOT_DIR','GODOT_USER_HOME'}: env.pop(key)
        for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
            path=profile/key.lower(); path.mkdir(); env[key]=str(path)
        nonce=uuid.uuid4().hex
        env.update(STEAM_DISABLED='1', CAMPAIGN_QA='0', CAMPAIGN_FAULT_MATRIX_OUT=str(output),
                   CAMPAIGN_FAULT_MATRIX_PROFILE=str(profile).replace('\\','/'), CAMPAIGN_FAULT_MATRIX_NONCE=nonce)
        receipt['nonce']=nonce
        deadline=time.monotonic()+6*3600
        def integrity():
            if time.monotonic()>deadline: raise RuntimeError('This native batch deadline reached')
            if sha(engine)!=receipt['engine_sha256'] or native_dependencies()!=native: raise RuntimeError('Engine/native drift')
            for path, digest in pins.items():
                if sha(path)!=digest: raise RuntimeError('Fixed source input changed: '+path)
        def acquire():
            nonlocal acquired
            idle=None
            while True:
                if time.monotonic()>deadline: raise RuntimeError('Natural engine idle deadline')
                if engines() or LOCK.exists(): idle=None
                elif idle is None: idle=time.monotonic()
                elif time.monotonic()-idle>=60:
                    try:
                        with LOCK.open('x',encoding='utf-8') as stream: stream.write(str(run))
                    except FileExistsError:
                        idle=None; continue
                    acquired=True
                    if not engines(): return
                    LOCK.unlink(); acquired=False; idle=None
                time.sleep(2)
        def release():
            nonlocal acquired
            if acquired and LOCK.read_text(encoding='utf-8')==str(run): LOCK.unlink(); acquired=False
        integrity(); acquire()
        command=[str(engine),'--path',str(project),'--headless','--editor','--import','--quit']
        with (run/'import.log').open('wb') as stream:
            child=subprocess.Popen(command,cwd=project,env=env,stdout=stream,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
            end=time.monotonic()+900
            while child.poll() is None:
                if time.monotonic()>end or engines()-{child.pid}: raise RuntimeError('Import timeout or foreign engine resumed')
                time.sleep(2)
        receipt['steps'].append({'stage':'import','pid':child.pid,'exit_code':child.returncode,'process_terminal':True,'log_sha256':sha(run/'import.log')})
        if child.returncode or re.search(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)',(run/'import.log').read_text(encoding='utf-8',errors='replace')):
            raise RuntimeError('Actual full proposal/harness import failed')
        release(); integrity()
        # Existing installed inputs may not change during cold import. Generated
        # sidecars are retained in this new runtime and sealed before execution.
        for row in receipt['source_inputs']:
            if sha(project/row['installed'])!=row['sha256']: raise RuntimeError('Existing import input drift')
        installed={str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file() and '.godot' not in p.relative_to(project).parts}
        receipt['installed_post_import_identity']=installed
        acquire(); integrity()
        if engines(): raise RuntimeError('Foreign engine before owned debugger launch')
        listener=socket.socket(); listener.bind(('127.0.0.1',0)); listener.listen(1); listener.settimeout(30)
        port=listener.getsockname()[1]
        command=[str(engine),'--path',str(project),'--headless','--remote-debug','tcp://127.0.0.1:'+str(port),'res://tools/campaign_persistence_fault_matrix.tscn']
        receipt['command']=command
        pending=None; issued={}; handled=set(); thread_id=None
        with (run/'native.log').open('wb') as stream:
            child=subprocess.Popen(command,cwd=project,env=env,stdout=stream,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
            receipt['pid']=child.pid
            connection,address=listener.accept(); listener.close(); listener=None; connection.settimeout(.15)
            peer=DebugConnection(connection); end=time.monotonic()+300
            while child.poll() is None:
                if time.monotonic()>end or engines()-{child.pid}: raise RuntimeError('Runtime timeout or shared engine resumed')
                if oplock is not None and oplock.poll_break():
                    # The source-pinned real cfg.load was resumed; its actual file
                    # opener now waits for this kernel-notified exclusive break.
                    mutation=oplock_request
                    mutation['kernel_break_observed_ns']=time.monotonic_ns()
                    oplock.append_before_release(b'\n; controlled comment while native cfg.load opener waits\n')
                    oplock=None
                    mutation.update(action='append actual file while ConfigFile.load native opener waits',
                        after_sha256=sha(cfg_path),inside_ConfigFile_load_observed=True,
                        native_oplock_break_acknowledged_by_holder_close=True)
                    receipt['mutations'].append(mutation); handled.add(mutation['index']); oplock_request=None
                index=len(issued); request_path=output/('request_%02d.json'%index)
                if index<19 and request_path.exists() and thread_id is not None:
                    try: request=json.loads(request_path.read_text(encoding='utf-8'))
                    except json.JSONDecodeError: request=None
                    if request is not None:
                        if request['nonce']!=nonce or request['pid']!=child.pid or request['index']!=index or request['id']!=ids[index]:
                            raise RuntimeError('Actual case handshake identity/order differs')
                        fault=request['fault']; line=breakpoints.get(fault)
                        if pending is not None or oplock is not None: raise RuntimeError('Previous real fault stop was not handled')
                        if line:
                            pending={**request,'source':'res://scripts/campaign.gd','line':line}
                            peer.command('breakpoint',thread_id,[pending['source'],line,True])
                        if fault=='write_readonly':
                            no_reparse(cfg_path); readonly_original=attributes(cfg_path)
                            attributes(cfg_path,readonly_original|1)
                            receipt['mutations'].append({'id':request['id'],'action':'actual Windows readonly attribute','before_attributes':readonly_original,'after_attributes':attributes(cfg_path)})
                        issued[index]=request
                        write_json(output/('ack_%02d.json'%index),{'nonce':nonce,'id':request['id']})
                try: message,packet=peer.receive()
                except socket.timeout: continue
                except EOFError: break
                name,thread,data=message
                if name=='set_pid':
                    if data!=[child.pid]: raise RuntimeError('Debugger actual PID mismatch')
                    thread_id=thread
                elif name=='debug_enter':
                    if pending is None or len(data)!=4 or data[:3]!=[True,'Breakpoint',True] or data[3]!=thread:
                        raise RuntimeError('Unexpected/error real debugger stop')
                    peer.command('get_stack_dump',thread)
                elif name=='stack_dump':
                    frames=stack_frames(data)
                    if pending is None or frames[0]!={'source':pending['source'],'line':pending['line'],'function':'_write_config_receipt'}:
                        raise RuntimeError('Actual source/function/line mismatch at file API')
                    no_reparse(cfg_path)
                    if not cfg_path.resolve().is_relative_to(profile.resolve()) or not cfg_path.is_file(): raise RuntimeError('Owned real cfg missing')
                    mutation={**pending,'frames':frames,'before_sha256':sha(cfg_path),'actual_filesystem_operation':True}
                    fault=pending['fault']
                    if fault in {'prior_vanished','fresh_load_missing'}:
                        backup=output/('private_fault_backup_%02d.cfg'%pending['index'])
                        if backup.exists(): raise RuntimeError('Fault backup already exists')
                        cfg_path.rename(backup)
                        mutation.update(action='move owned actual cfg before native load',backup_sha256=sha(backup),source_absent=not cfg_path.exists())
                    elif fault=='write_readonly':
                        attributes(cfg_path,readonly_original); readonly_original=None
                        mutation.update(action='restore owned Windows attributes after actual save',after_sha256=sha(cfg_path))
                    elif fault=='semantic_mismatch':
                        prior=cfg_path.read_bytes()
                        changed,count=re.subn(rb'(?m)^unlocked=1[ \t]*$',b'unlocked=7',prior)
                        if count!=1: raise RuntimeError('Exact written progress fixture differs')
                        cfg_path.write_bytes(changed); mutation.update(action='change real saved unlocked before first SHA/read',after_sha256=sha(cfg_path))
                    elif fault=='sha_interval_change':
                        oplock=OwnedOplock(cfg_path,profile)
                        oplock_request=mutation
                        mutation['exclusive_oplock_armed_ns']=time.monotonic_ns()
                    else: raise RuntimeError('Unknown controlled fault')
                    if fault!='sha_interval_change':
                        receipt['mutations'].append(mutation); handled.add(pending['index'])
                    peer.command('breakpoint',thread,[pending['source'],pending['line'],False])
                    pending=None; peer.command('continue',thread)
        child.wait(timeout=20)
        receipt.update(exit_code=child.returncode,process_terminal=True,log_sha256=sha(run/'native.log'))
        if child.returncode: raise RuntimeError('Actual native matrix returned failure')
        report=json.loads((output/'report.json').read_text(encoding='utf-8'))
        if (not report.get('complete') or report['pid']!=child.pid or report['nonce']!=nonce or report['failures']
                or [c['id'] for c in report['cases']]!=ids or not all(c['complete'] for c in report['cases'])
                or report['engine_time_scale']!=1 or Path(report['actual_user_dir']).resolve()!=cfg_path.parent.resolve()):
            raise RuntimeError('Actual matrix report/identity/all nineteen checks failed')
        if set(i for i,r in issued.items() if r['fault'])!=handled or pending is not None or oplock is not None:
            raise RuntimeError('A planned real file fault was not injected at the actual source line')
        log=(run/'native.log').read_text(encoding='utf-8',errors='replace')
        if re.search(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:)',log): raise RuntimeError('Script error cannot be a fault diagnostic')
        native_errors=re.findall(r'(?m)^\s*ERROR:.*$',log)
        allowed=re.findall(r"(?m)^\s*ERROR: ConfigFile parse error at user://campaign\.cfg:0: Unexpected EOF while parsing simple tag\.$",log)
        if len(native_errors)!=1 or native_errors!=allowed:
            raise RuntimeError('Exact single malformed-CFG native diagnostic budget differs; preserve actual log')
        receipt['native_diagnostic_budget']={'expected_malformed_CFG_errors':1,'actual':native_errors,'SCRIPT_errors':0}
        integrity()
        current={str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file() and '.godot' not in p.relative_to(project).parts}
        if current!=installed: raise RuntimeError('Installed runtime source/native inventory changed')
        receipt.update(complete=True,report=report,component_matrix_qualified=True)
    except BaseException as error:
        receipt['failure']=repr(error)
        raise
    finally:
        if child is not None and child.poll() is None: child.terminate(); child.wait(timeout=20)
        if oplock is not None: oplock.close()
        if readonly_original is not None and cfg_path.exists(): attributes(cfg_path,readonly_original)
        if connection is not None: connection.close()
        if listener is not None: listener.close()
        if acquired and LOCK.read_text(encoding='utf-8')==str(run): LOCK.unlink(); receipt['lock_released']=True
        write_json(run/'receipt.json',receipt)
        print(json.dumps({'complete':receipt['complete'],'run':str(run),'failure':receipt.get('failure')}),flush=True)

if __name__=='__main__':
    main()
