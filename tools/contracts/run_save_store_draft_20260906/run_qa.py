"""Private disk-layer QA. Default lists/preflights; --prepare copies ~30 KiB only.
--run explicitly launches serial Godot children under the shared exclusive lock.
Never changes the original store, production files, or real player directories.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
LOCK = ROOT / '.godot/redraw_rejection_source.lock'
PIN = '86619f5cbf87e984ed253d66dddf2b852c8e11fe5e34d256c5a463bef16abca3'
FILES = {'run_save_store.gd': 'scratchpad/run_save_store/run_save_store.gd',
         'qa_faults.gd': 'qa/qa_faults.gd', 'qa_driver.gd': 'qa/qa_driver.gd'}
PROJECT_NAME = 'RunSaveStore Private QA'
PROJECT = ('config_version=5\n\n[application]\nconfig/name="' + PROJECT_NAME +
           '"\nconfig/features=PackedStringArray("4.6")\n').encode()
ERROR = re.compile(r'SCRIPT ERROR|^ERROR:|^WARNING:|\bFAIL\b', re.M)
ACTIVE = None


def need(ok, detail):
    if not ok:
        raise RuntimeError(detail)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def save(path, data):
    path.write_bytes((json.dumps(data, ensure_ascii=False, indent=2) + '\n').encode())


def no_links(path):
    for current in [path] + list(path.parents):
        if not current.exists():
            continue
        st = current.lstat()
        need(not current.is_symlink() and not getattr(st, 'st_file_attributes', 0) & 0x400,
             'Link/reparse point refused: ' + str(current))


def bounded(path, parent):
    return parent.resolve() in path.resolve().parents


def catalog():
    rows = {}
    def row(name, kind, code='OK', state=None, commit='not_attempted'):
        rows[name] = {'kind':kind, 'expected_code':code, 'expected_commit':commit,
                      'expected_state':state or {}}
    def fs(slot='A', pending='B', previous='absent', lock='directory'):
        return dict(zip(['run_continue.json', 'run_continue.pending',
                         'run_continue.previous', 'run_continue.writing'],
                        [slot, pending, previous, lock]))
    clean = fs('B','absent','absent','absent')
    row('roundtrip', 'smoke', state=clean)
    for name, code in {'unknown_schema':'UNSUPPORTED_SCHEMA', 'unknown_format':'UNSUPPORTED_FORMAT',
                       'bad_magic':'MAGIC_MISMATCH', 'bad_sha':'PAYLOAD_DIGEST',
                       'bad_length':'PAYLOAD_LENGTH', 'empty_file':'FILE_SIZE',
                       'empty_payload':'PAYLOAD_SIZE',
                       'truncated':'ENVELOPE_JSON', 'file_utf8':'FILE_UTF8',
                       'envelope_shape':'ENVELOPE_SHAPE', 'envelope_fields':'ENVELOPE_FIELDS',
                       'envelope_types':'ENVELOPE_TYPES', 'semantic_file':'PAYLOAD_REJECTED'}.items():
        row(name, 'corrupt', code, fs('any_file','absent','absent','absent'))
    row('slot_directory','corrupt','READ_OPEN',fs('directory','absent','absent','absent'))
    for name, code in {'input_empty':'PAYLOAD_SIZE', 'input_oversize':'PAYLOAD_SIZE',
                       'input_utf8':'PAYLOAD_UTF8', 'input_semantic':'PAYLOAD_REJECTED',
                       'validator_missing':'VALIDATOR_REQUIRED',
                       'validator_contract':'VALIDATOR_CONTRACT'}.items():
        row(name, 'input', code, fs('A','absent','absent','absent'))
    for name, code, state, commit in [
        ('lock_race','LOCK_UNAVAILABLE',fs(pending='absent'),'not_attempted'),
        ('write_open','WRITE_OPEN',fs(pending='absent'),'not_attempted'),
        ('write_short','WRITE_INCOMPLETE',fs(pending='any_file'),'not_attempted'),
        ('pending_race','PATH_ALREADY_EXISTS',fs(pending='external_pending'),'not_attempted'),
        ('temp_read_open','READ_OPEN',fs(),'not_attempted'),
        ('temp_read_incomplete','READ_INCOMPLETE',fs(),'not_attempted'),
        ('temp_truncated','ENVELOPE_JSON',fs(pending='any_file'),'not_attempted'),
        ('temp_digest','PAYLOAD_DIGEST',fs(pending='any_file'),'not_attempted'),
        ('temp_semantic','PAYLOAD_REJECTED',fs(pending='any_file'),'not_attempted'),
        ('temp_whitespace','TEMP_READBACK_MISMATCH',fs(pending='B_space'),'not_attempted'),
        ('slot_changed','SLOT_CHANGED',fs(slot='A_space'),'not_attempted'),
        ('backup_move','BACKUP_MOVE',fs(),'not_attempted'),
        ('backup_read','BACKUP_VERIFY',fs(slot='absent',previous='A'),'not_attempted'),
        ('replace_rollback','REPLACE_FAILED',fs(),'not_committed'),
        ('replace_no_rollback','REPLACE_FAILED',fs(slot='absent',previous='A'),'not_committed'),
        ('rollback_read','REPLACE_FAILED',fs(slot='absent',previous='A'),'not_committed'),
        ('replace_external','REPLACE_FAILED',fs(slot='external',previous='A'),'unknown'),
        ('final_read','COMMIT_UNVERIFIED',fs(slot='B',pending='absent',previous='A'),'unknown'),
        ('final_corrupt','COMMIT_UNVERIFIED',fs(slot='broken',pending='absent',previous='A'),'unknown'),
        ('backup_changed','BACKUP_CHANGED',fs(slot='B',pending='absent',previous='A_space'),'new_verified'),
        ('cleanup_previous','CLEANUP_FAILED',fs(slot='B',pending='absent',previous='A'),'new_verified'),
        ('cleanup_lock','CLEANUP_FAILED',fs(slot='B',pending='absent'),'new_verified'),
    ]:
        row(name, 'io', code, state, commit)
    row('new_write_open','io','WRITE_OPEN',fs('absent','absent','absent','directory'))
    rows['new_write_open'].update(fault='write_open',no_old=True)
    row('restart', 'restart', state=fs('A','absent','absent','absent'))
    for name, state in [('temp_closed',fs()), ('backup_moved',fs(slot='absent',previous='A')),
                        ('committed',fs(slot='B',pending='absent',previous='A')),
                        ('backup_removed',fs(slot='B',pending='absent'))]:
        row('interrupt_'+name,'interrupt',state=state)
    return rows


def sources():
    names = list(FILES) + ['run_qa.py']
    for name in names:
        no_links(HERE / name)
    data = {name:sha((HERE/name).read_bytes()) for name in names}
    need(data['run_save_store.gd'] == PIN, 'Store changed; review and explicitly rebase its pin before QA')
    return data


def prepare(selected, source):
    no_links(HERE)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    run_root = HERE / 'runs' / stamp
    need(bounded(run_root, HERE), 'Unbounded run root')
    run_root.mkdir(parents=True, exist_ok=False)
    project = run_root / 'project'
    project.mkdir()
    hashes = {}
    for name, relative in FILES.items():
        raw = (HERE/name).read_bytes()
        need(sha(raw) == source[name], 'Source changed during tiny project copy')
        target = project / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
        hashes[relative] = sha(raw)
    (project/'project.godot').write_bytes(PROJECT)
    hashes['project.godot'] = sha(PROJECT)
    profile = run_root/'private_profile'
    user = profile/'appdata/Godot/app_userdata'/PROJECT_NAME
    for path in [user, profile/'localappdata', profile/'temp', run_root/'reports']:
        path.mkdir(parents=True, exist_ok=False)
    for name in selected:
        (project/'scratchpad/run_save_store/fixtures'/name).mkdir(parents=True, exist_ok=False)
    receipt = {'schema':1,'run_id':stamp,'run_root':str(run_root),'selected':selected,
               'source':source,'private_sources':hashes,'private_project':str(project),
               'private_user':str(user),'godot_run':False,'production_mutated':False,
               'copies':'three exact GD files plus no-Autoload project.godot; no imports/assets/player files'}
    save(run_root/'preparation.json', receipt)
    return receipt


def exclusive():
    if ACTIVE is not None:
        need(ACTIVE.poll() is not None, 'Owned child exit unconfirmed; shared lock must remain')
    need(os.name == 'nt', 'Only the reviewed Windows private profile mapping is supported')
    command = "@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"
    raw = subprocess.check_output(['powershell.exe','-NoProfile','-NonInteractive','-Command',command],
                                  text=True, timeout=20).strip()
    need(not (json.loads(raw) if raw else []), 'Godot is running; wait for the shared exclusive slot')


def child_env(prepared, manifest_path):
    env = os.environ.copy()
    for key in list(env):
        if key.startswith(('GODOT_', 'STORE_QA_', 'POLISH_', 'PERF_', 'REDUCED_EFFECTS_',
                           'CONTENT_UPDATE_', 'ANDROID_UPDATE_')):
            env.pop(key)
    profile = Path(prepared['run_root'])/'private_profile'
    env.update(APPDATA=str(profile/'appdata'), LOCALAPPDATA=str(profile/'localappdata'),
               TEMP=str(profile/'temp'), TMP=str(profile/'temp'), STORE_QA_MANIFEST=str(manifest_path))
    return env


def verify_sources(prepared):
    need(sources() == prepared['source'], 'Authored QA/store source changed; preserve the run')
    project = Path(prepared['private_project'])
    for path, expected in prepared['private_sources'].items():
        no_links(project/path)
        need(sha((project/path).read_bytes()) == expected, 'Private executable source changed: '+path)


def run_process(exe, prepared, manifest_path, manifest, timeout):
    global ACTIVE
    exclusive()
    project = Path(prepared['private_project'])
    log_path = Path(manifest['report']).with_suffix('.log')
    marker = Path(manifest.get('checkpoint','unused'))
    interrupted = manifest['phase'] == 'interrupt_writer'
    command = [exe,'--headless','--path',str(project),'--script','res://qa/qa_driver.gd']
    process = None
    failure = None
    confirmed = False
    checkpoint = None
    terminated_at_checkpoint = False
    with log_path.open('xb') as log:
        try:
            process = subprocess.Popen(command,cwd=project,env=child_env(prepared,manifest_path),
                                       stdout=log,stderr=subprocess.STDOUT,
                                       creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            ACTIVE = process
            if interrupted:
                deadline = time.monotonic() + timeout
                while process.poll() is None and time.monotonic() < deadline:
                    if marker.is_file():
                        try:
                            checkpoint = json.loads(marker.read_bytes())
                        except (json.JSONDecodeError, UnicodeDecodeError):
                            time.sleep(0.02)
                            continue
                        need(checkpoint.get('run_id') == prepared['run_id'] and checkpoint.get('case') == manifest['case']
                             and checkpoint.get('process_id') == process.pid and checkpoint.get('failures') == []
                             and checkpoint.get('manifest_sha256') == sha(manifest_path.read_bytes()),
                             'Checkpoint provenance/checks invalid; expected interruption not established')
                        need(checkpoint.get('checkpoint') == manifest['case'].removeprefix('interrupt_'), 'Wrong checkpoint')
                        process.kill()  # Exact owned handle, not a PID/name search.
                        process.wait(timeout=30)
                        terminated_at_checkpoint = True
                        break
                    time.sleep(0.02)
                need(terminated_at_checkpoint, 'Child failed/exited or timed out before its checkpoint')
            else:
                process.wait(timeout=timeout)
        except BaseException as exc:
            failure = exc
            if process is not None:
                try:
                    if process.poll() is None: process.kill()
                    process.wait(timeout=30)
                except BaseException as cleanup:
                    failure = RuntimeError(str(exc)+'; owned child cleanup: '+repr(cleanup))
        finally:
            if process is not None:
                try:
                    confirmed = process.poll() is not None
                    if confirmed: ACTIVE = None
                except BaseException:
                    confirmed = False
    text = log_path.read_text(encoding='utf-8',errors='replace')
    errors = [line for line in text.splitlines() if ERROR.search(line)]
    result = {'command':command,'pid':process.pid if process else None,
              'exit_code':process.returncode if process else None,'exit_confirmed':confirmed,
              'expected_external_termination':terminated_at_checkpoint,'checkpoint':checkpoint,
              'exception':repr(failure) if failure else None,'matched_errors':errors}
    save(log_path.with_name(log_path.stem+'_process.json'), result)
    if failure is not None: raise failure
    need(confirmed and not errors, 'Unconfirmed child exit or engine diagnostics: '+str(log_path))
    exclusive()
    if not interrupted: need(process.returncode == 0, 'Nonzero ordinary QA exit')
    return result


def independent_filesystem_check(manifest, report):
    """Compare actual bytes with GD evidence; Python parses real output independently."""
    case_dir = Path(manifest['case_dir'])
    for leaf, row in report['snapshot'].items():
        path = case_dir/leaf
        no_links(path)
        if row['kind'] == 'file':
            raw = path.read_bytes()
            need(len(raw) == row['bytes'] and sha(raw) == row['sha256'], 'Disk/report bytes disagree: '+leaf)
            if manifest['expected_state'].get(leaf) in ('A','B'):
                envelope = json.loads(raw)
                payload = envelope['payload'].encode('utf-8')
                need(envelope['payload_bytes'] == str(len(payload)) and envelope['payload_sha256'] == sha(payload),
                     'Independent payload length/digest verification failed')
                decoded = json.loads(payload)
                label = manifest['expected_state'][leaf]
                need(decoded == {'kind':'disk_fixture', 'revision':'9223372036854775807' if label=='A' else '2',
                                 'marker':'one' if label=='A' else 'two', 'text':'梁山\n继续'},
                     'Independent expected payload semantics failed')
        elif row['kind'] == 'directory':
            need(path.is_dir(), 'Expected residue directory missing')
            actual = {p.name:sha(p.read_bytes()) for p in path.iterdir() if p.is_file()}
            need(actual == row['files'], 'Residue directory files changed')
        else:
            need(not path.exists(), 'Unexpected path after reported absence')


def run(args, prepared, cases):
    exe_value = args.godot or os.environ.get('GODOT_PATH','')
    if not exe_value and (ROOT/'godot.local.txt').is_file():
        exe_value = (ROOT/'godot.local.txt').read_text(encoding='utf-8-sig').strip()
    need(exe_value and Path(exe_value).is_file(), 'Provide --godot, GODOT_PATH or ignored godot.local.txt')
    exe = str(Path(exe_value).resolve())
    exclusive()
    no_links(LOCK.parent)
    need(LOCK.parent.is_dir() and not LOCK.exists(), 'Shared source/engine lock unavailable')
    root = Path(prepared['run_root'])
    receipt = {'schema':1,'run_id':prepared['run_id'],'complete':False,'godot_run':False,
               'production_mutated':False,'lock_released':False,'cases':[],
               'engine_sha256':sha(Path(exe).read_bytes()),'automatic_recovery_implemented':False}
    with LOCK.open('x',encoding='utf-8') as stream: stream.write(str(root)+'\n')
    try:
        for name in prepared['selected']:
            item = cases[name]
            phases = ['single'] if item['kind'] not in ('restart','interrupt') else (
                ['writer','reader'] if item['kind']=='restart' else ['interrupt_writer','interrupt_reader'])
            references = {}
            case_receipt = {'case':name,'phases':[],'passed':False}
            for phase in phases:
                verify_sources(prepared)
                path = root/'reports'/(name+'_'+phase+'_manifest.json')
                manifest = dict(item, schema=1,run_id=prepared['run_id'],case=name,phase=phase,
                    run_root=str(root),report=str(root/'reports'/(name+'_'+phase+'.json')),
                    checkpoint=str(root/'reports'/(name+'_checkpoint.json')),
                    expected_user_dir=prepared['private_user'],source_sha256=prepared['private_sources'],
                    case_dir=str(Path(prepared['private_project'])/'scratchpad/run_save_store/fixtures'/name),
                    references=references)
                save(path,manifest)
                digest = sha(path.read_bytes())
                receipt['godot_run'] = True
                process = run_process(exe,prepared,path,manifest,args.timeout)
                verify_sources(prepared)
                need(sha(path.read_bytes()) == digest, 'External manifest changed')
                if phase == 'interrupt_writer':
                    references = process['checkpoint']['references']
                    independent_filesystem_check(manifest,process['checkpoint'])
                    case_receipt['phases'].append({'phase':phase,'expected_termination':True,'pid':process['pid']})
                else:
                    report_path = Path(manifest['report'])
                    need(report_path.is_file(), 'Fresh report missing')
                    report = json.loads(report_path.read_bytes())
                    need(report.get('schema') == 1 and report.get('run_id') == prepared['run_id']
                         and report.get('case') == name and report.get('phase') == phase
                         and report.get('process_id') == process['pid'] and report.get('manifest_sha256') == digest,
                         'Report provenance mismatch')
                    need(report.get('passed') is True and report.get('failures') == []
                         and len(report.get('checks',[])) >= 8 and all(r.get('passed') is True for r in report['checks']),
                         'Real disk QA assertions failed or missing')
                    need(Path(report['actual_user_dir']).resolve() == Path(prepared['private_user']).resolve(), 'Actual user path escaped')
                    independent_filesystem_check(manifest,report)
                    references = report['references']
                    case_receipt['phases'].append({'phase':phase,'pid':process['pid'],'checks':len(report['checks']),
                                                  'report':report_path.name,'sha256':sha(report_path.read_bytes())})
                save(root/'receipt.json',receipt)
            case_receipt['passed'] = True
            receipt['cases'].append(case_receipt)
            save(root/'receipt.json',receipt)
            print('CASE '+name+' passed',flush=True)
        receipt['complete'] = len(receipt['cases']) == len(prepared['selected'])
    except BaseException as exc:
        receipt['exception'] = repr(exc)
    finally:
        try:
            exclusive()
            verify_sources(prepared)
            need(LOCK.read_text(encoding='utf-8').strip() == str(root), 'Shared lock owner changed')
            LOCK.unlink()
            receipt['lock_released'] = True
        except BaseException as exc:
            receipt['cleanup_error'] = repr(exc)
        save(root/'receipt.json',receipt)
        print(json.dumps({'output':str(root),'complete':receipt['complete'],'lock_released':receipt['lock_released']}),flush=True)
    return 0 if receipt['complete'] and receipt['lock_released'] else 2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--prepare',action='store_true')
    mode.add_argument('--run',action='store_true')
    parser.add_argument('--suite',choices=['smoke','corrupt','input','io','restart','interrupt','all'],default='smoke')
    parser.add_argument('--case',nargs='+')
    parser.add_argument('--godot')
    parser.add_argument('--timeout',type=int,default=90)
    args = parser.parse_args()
    need(15 <= args.timeout <= 240, 'Timeout must be 15..240 seconds')
    cases = catalog()
    selected = args.case or [name for name,item in cases.items() if args.suite=='all' or item['kind']==args.suite]
    need(selected and len(set(selected))==len(selected) and all(name in cases for name in selected), 'Unknown/duplicate/empty case selection')
    source = sources()
    if not (args.prepare or args.run):
        print(json.dumps({'preflight':True,'godot_run':False,'copies_created':False,'store_sha256':PIN,
                          'selected':selected,'available':list(cases)},ensure_ascii=False,indent=2))
        return 0
    if args.run: exclusive() # No project copy while another engine run owns the slot.
    prepared = prepare(selected,source)
    print('PREPARED '+prepared['run_root'],flush=True)
    return run(args,prepared,cases) if args.run else 0


if __name__ == '__main__':
    raise SystemExit(main())
