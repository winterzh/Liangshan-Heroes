"""Run only the predeclared six normal defense200 A/B windows after slot handoff.

Default preflight reads manifests/small tool files only; it neither clones assets
nor starts Godot. --run verifies/copies the complete original c028 source under
the shared lock. All new artifacts are private; no source swaps or Git writes.
"""
import argparse
import ctypes
from ctypes import wintypes
import datetime
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import statistics
import subprocess
import sys
import time
import uuid

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASELINE = ROOT / '.godot/stabilization_performance/20260907T053341Z_cd6e93a0'
DATA = ROOT / 'scratchpad/stabilization_dust_filter_20260907'
DATA_RUN = ROOT / '.godot/stabilization_performance/dust_data_20260907T071006Z_c95a6641'
def sha(raw): return hashlib.sha256(raw).hexdigest()
def need(ok, message):
    if not ok: raise RuntimeError(message)
def read(path): return json.loads(path.read_text(encoding='utf-8'))
def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

class ProcessMemoryCounters(ctypes.Structure):
    _fields_ = [('cb',wintypes.DWORD),('PageFaultCount',wintypes.DWORD)] + [(name,ctypes.c_size_t) for name in
        ('PeakWorkingSetSize','WorkingSetSize','QuotaPeakPagedPoolUsage','QuotaPagedPoolUsage',
         'QuotaPeakNonPagedPoolUsage','QuotaNonPagedPoolUsage','PagefileUsage','PeakPagefileUsage','PrivateUsage')]

def process_memory(child, elapsed):
    counters = ProcessMemoryCounters(); counters.cb = ctypes.sizeof(counters)
    psapi = ctypes.WinDLL('psapi',use_last_error=True)
    query = psapi.GetProcessMemoryInfo
    query.argtypes = [wintypes.HANDLE,ctypes.POINTER(ProcessMemoryCounters),wintypes.DWORD]
    query.restype = wintypes.BOOL
    if not query(wintypes.HANDLE(int(child._handle)),ctypes.byref(counters),counters.cb):
        raise ctypes.WinError(ctypes.get_last_error())
    return {'process_seconds':elapsed,'working_set_bytes':counters.WorkingSetSize,
            'peak_working_set_bytes':counters.PeakWorkingSetSize,'private_bytes':counters.PrivateUsage}

def pair_analysis(rows):
    pairs = []
    for index in range(3):
        a, b = rows[index*2:index*2+2]
        pairs.append({'pair':index+1,
            'first10_fps_improvement_percent':100*(b['first10']['fps']/a['first10']['fps']-1),
            'first10_p95_reduction_percent':100*(1-b['first10']['p95_ms']/a['first10']['p95_ms']),
            'tail_guard':all(b[k] <= a[k]*1.02 for k in ('full_p95_ms','full_p99_ms','worst10_p95_ms','worst10_p99_ms'))
                and b['first10']['p99_ms'] <= a['first10']['p99_ms']*1.02,
            'worst10_fps_not_regressed':b['lowest10_fps'] >= a['lowest10_fps']})
    aa, bb = rows[::2], rows[1::2]
    conditions = {
        'all_pairs_first10_fps_improved':all(p['first10_fps_improvement_percent'] > 0 for p in pairs),
        'median_first10_fps_improvement_ge_5pct':statistics.median(p['first10_fps_improvement_percent'] for p in pairs) >= 5,
        'first10_fps_ranges_separated':min(x['first10']['fps'] for x in bb) > max(x['first10']['fps'] for x in aa),
        'all_pairs_first10_p95_not_regressed':all(p['first10_p95_reduction_percent'] >= 0 for p in pairs),
        'median_first10_p95_reduction_ge_5pct':statistics.median(p['first10_p95_reduction_percent'] for p in pairs) >= 5,
        'all_tail_guards':all(p['tail_guard'] for p in pairs),
        'all_worst10_fps_not_regressed':all(p['worst10_fps_not_regressed'] for p in pairs),
        'memory_peak_no_pair_over_10pct':all(b['peak_private_bytes'] <= a['peak_private_bytes']*1.10 for a,b in zip(aa,bb)),
        'memory_peak_median_no_over_5pct':statistics.median(x['peak_private_bytes'] for x in bb) <= statistics.median(x['peak_private_bytes'] for x in aa)*1.05,
        'all_complete_segments_ge_30fps':all(x['lowest10_fps'] >= 30 for x in rows)}
    return {'pairs':pairs,'conditions':conditions,'screen_passed':all(conditions.values()),
            'decision':'eligible_for_full_M1_only' if all(conditions.values()) else 'stop_candidate_no_credible_pressure_gain',
            'statistical_significance_claimed':False,'production_adoption_authorized':False}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--freeze-sha256', required=True)
    parser.add_argument('--run', action='store_true')
    args = parser.parse_args()
    frozen_bytes = (HERE/'freeze.json').read_bytes()
    need(sha(frozen_bytes) == args.freeze_sha256, 'Wrong A/B freeze')
    frozen = json.loads(frozen_bytes.decode('utf-8'))
    for name, digest in frozen['inputs'].items():
        need(sha((HERE/name).read_bytes()) == digest, 'A/B frozen tool drift: '+name)
    need(sha((ROOT/'tools/run_stabilization_performance.py').read_bytes()) == frozen['guard_sha256'], 'Guard drift')
    guard = load('dust_ab_guard', ROOT/'tools/run_stabilization_performance.py')
    for directory in (HERE, BASELINE, DATA, DATA_RUN): guard.no_links(directory)
    baseline_bytes = (BASELINE/'receipt.json').read_bytes()
    need(sha(baseline_bytes) == frozen['baseline_receipt_sha256'], 'Baseline receipt drift')
    baseline = json.loads(baseline_bytes.decode('utf-8'))
    need(baseline['source_head'] == frozen['source_head'] and all(baseline.get(k) is True for k in
         ('complete','baseline_eligible','player_unchanged','lock_released')), 'Incomplete original baseline')
    data_bytes = (DATA/'freeze.json').read_bytes()
    need(sha(data_bytes) == frozen['data_freeze_sha256'] and sha((DATA_RUN/'receipt.json').read_bytes()) == frozen['data_receipt_sha256'], 'Native-data evidence drift')
    data_freeze = json.loads(data_bytes.decode('utf-8'))
    for name, digest in data_freeze['inputs'].items():
        guard.no_links(DATA/name)
        need(sha((DATA/name).read_bytes()) == digest, 'Data candidate drift: '+name)
    candidate = (DATA/'candidate/scripts/unit.gd').read_bytes()
    need(sha(candidate) == frozen['candidate_sha256'], 'Candidate bytes drift')
    source_meta = read(DATA/'source_receipt.json')
    expected = {r['path']:r['sha256'] for r in baseline['source_files']+baseline['tools']}
    committed = {r['path']:r['git_oid'] for r in guard.tree(frozen['source_head'])}
    need(committed == {r['path']:r['git_oid'] for r in baseline['source_files']}, 'Original Git tree mismatch')
    need(expected['scripts/unit.gd'] == source_meta['before_sha256'], 'Candidate base mismatch')
    exe = Path((ROOT/'godot.local.txt').read_text(encoding='utf-8-sig').strip())
    guard.no_links(exe)
    engine_sha = sha(exe.read_bytes())
    need(engine_sha == baseline['godot_sha256'], 'Original engine changed')
    lock = ROOT/'.godot/redraw_rejection_source.lock'
    guard.no_links(lock)
    info = {'preflight':True,'source_head':frozen['source_head'],'freeze_sha256':args.freeze_sha256,
            'baseline_receipt_sha256':frozen['baseline_receipt_sha256'],'godot_sha256':engine_sha,
            'order':frozen['order'],'normal_seconds_each':60,'source_files':len(expected),
            'godot_pids':guard.godot_processes(),'lock_busy':lock.exists(),
            'full_source_verified':False,'asset_copy_started':False}
    print(json.dumps(info), flush=True)
    if not args.run: return 0
    need(not info['godot_pids'] and not info['lock_busy'], 'Godot slot occupied')
    run_id = 'dust_ab_' + datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'_'+uuid.uuid4().hex[:8]
    run = ROOT/'.godot/stabilization_performance'/run_id
    guard.no_links(run); run.mkdir(parents=True,exist_ok=False)
    receipt = dict(info,run_id=run_id,complete=False,steps=[],samples=[],final_issues=[])
    owner = json.dumps({'owner':'dust_ab','run_id':run_id,'pid':os.getpid()})
    lock_owned = False
    active = None
    player = None
    player_before = None
    production_before = None
    projects = {}
    private_expected = {}
    imported_expected = {}
    def production_snapshot():
        return {name:guard.snapshot(ROOT/name) for name in sorted(guard.DIRS)} | {
            'root_files':{name:sha((ROOT/name).read_bytes()) for name in sorted(guard.FIXED) if (ROOT/name).exists()}}
    def check_sources(project, hashes):
        actual = {}
        for base, dirs, files in os.walk(project,followlinks=False):
            dirs[:] = [name for name in dirs if name != '.godot']
            for name in dirs+files: guard.no_links(Path(base)/name)
            for name in files:
                path = Path(base)/name
                actual[path.relative_to(project).as_posix()] = sha(path.read_bytes())
        need(actual == hashes, 'Private source identity/inventory changed: '+str(project))
    def profile_env(label, project_name):
        profile = Path('D:/LHPerfProfiles')/(run_id+'_'+label)
        guard.no_links(profile); profile.mkdir(parents=True,exist_ok=False)
        env = os.environ.copy()
        for key in ('APPDATA','LOCALAPPDATA','TEMP','TMP'):
            path = profile/key.lower(); path.mkdir(); env[key] = str(path)
        env.update(CAMPAIGN_QA='1',STEAM_DISABLED='1',PYTHONDONTWRITEBYTECODE='1')
        return env, profile/'appdata/Godot/app_userdata'/project_name
    def execute(label, command, project, env, timeout):
        nonlocal active
        need(not guard.godot_processes(), 'Godot exists before '+label)
        started = time.monotonic()
        print('RUN '+label,flush=True)
        log = run/(label+'.log')
        memory = []
        with log.open('xb') as stream:
            active = subprocess.Popen(command,cwd=project,env=env,stdout=stream,stderr=subprocess.STDOUT,
                creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            pid = active.pid
            while True:
                if active.poll() is not None:
                    code = active.returncode; break
                if time.monotonic()-started > timeout:
                    active.kill(); active.wait(timeout=30); code = -1; break
                try: memory.append(process_memory(active,time.monotonic()-started))
                except OSError:
                    if active.poll() is None: raise
                    code = active.returncode; break
                try: code = active.wait(timeout=1); break
                except subprocess.TimeoutExpired: pass
            active = None
        guard.save(run/(label+'_process_memory.json'),{'pid':pid,'scope':'whole process lifetime; external 1-second samples, not exact render-window or engine allocation measurements','samples':memory})
        console = log.read_text(encoding='utf-8',errors='strict')
        errors = [line for line in console.splitlines() if guard.ERROR.search(line)]
        receipt['steps'].append({'label':label,'pid':pid,'exit_code':code,'seconds':time.monotonic()-started,'errors':errors,'command':command})
        guard.save(run/'receipt.json',receipt)
        need(code == 0 and not errors and not guard.godot_processes(), 'Invalid process '+label)
        need(guard.snapshot(player) == player_before, 'Real player changed')
        return pid, console, memory
    try:
        with lock.open('x',encoding='utf-8') as stream:
            lock_owned = True; stream.write(owner)
        production_before = production_snapshot()
        text = (ROOT/'project.godot').read_text(encoding='utf-8-sig')
        need('config/use_custom_user_dir' not in text and 'config/custom_user_dir_name' not in text, 'Custom player path unreviewed')
        names = re.findall(r'^config/name=("[^\n]+")\s*$',text,re.M)
        need(len(names) == 1, 'Ambiguous player name')
        project_name = json.loads(names[0])
        need(not any(c in project_name for c in '<>:"/\\|?*'), 'Unsafe project name')
        player = Path(os.environ['APPDATA'])/'Godot/app_userdata'/project_name
        player_before = guard.snapshot(player)
        receipt['player_before_digest'] = sha(json.dumps(player_before,sort_keys=True).encode())
        for name,digest in expected.items():
            path = BASELINE/'project'/name; guard.no_links(path)
            raw = path.read_bytes()
            need(sha(raw) == digest, 'Original frozen input changed: '+name)
            if name in committed:
                need(hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest() == committed[name], 'Original Git blob changed: '+name)
        receipt['full_source_verified'] = True
        cache = BASELINE/'project/.godot/imported'
        cache_files = []
        for path in cache.rglob('*'):
            guard.no_links(path)
            if path.is_file(): cache_files.append(path)
        reserve = 2*(sum((BASELINE/'project'/name).stat().st_size for name in expected)+sum(p.stat().st_size for p in cache_files))
        receipt['source_and_cache_copy_bytes'] = reserve
        print('RESERVE_BYTES '+str(reserve)+' plus logs/reports',flush=True)
        for variant in ('A','B'):
            project = run/variant; project.mkdir(); projects[variant] = project
            hashes = dict(expected)
            for name,digest in expected.items():
                raw = (BASELINE/'project'/name).read_bytes()
                need(sha(raw) == digest, 'Original input changed during copy: '+name)
                if variant == 'B' and name == 'scripts/unit.gd': raw = candidate
                dest = project/name; dest.parent.mkdir(parents=True,exist_ok=True); dest.write_bytes(raw)
                hashes[name] = sha(raw)
            marker = {'source_head':frozen['source_head'],'source_kind':'original' if variant=='A' else 'single-file derivative',
                      'baseline_receipt_sha256':frozen['baseline_receipt_sha256'],'candidate_sha256':None if variant=='A' else sha(candidate)}
            guard.save(project/'.polish_frozen_source.json',marker)
            hashes['.polish_frozen_source.json'] = sha((project/'.polish_frozen_source.json').read_bytes())
            private_expected[variant] = hashes
            cache_hashes = {}
            for path in cache_files:
                raw = path.read_bytes(); relative = path.relative_to(cache)
                dest = project/'.godot/imported'/relative; dest.parent.mkdir(parents=True,exist_ok=True); dest.write_bytes(raw)
                cache_hashes[relative.as_posix()] = sha(raw)
            imported_expected[variant] = cache_hashes
        need(imported_expected['A'] == imported_expected['B'], 'Cache seeds differed')
        guard.save(run/'source_manifest.json',{'baseline':expected,'variants':private_expected,'committed_blob_oids':committed,'cache_seed_sha256':sha(json.dumps(imported_expected['A'],sort_keys=True).encode())})
        (run/'freeze.json').write_bytes(frozen_bytes)
        for name in frozen['inputs']: (run/('executed_'+name+'.txt')).write_bytes((HERE/name).read_bytes())
        (run/'executed_guard.py.txt').write_bytes((ROOT/'tools/run_stabilization_performance.py').read_bytes())
        for variant,project in projects.items():
            env,_ = profile_env('import'+variant,project_name)
            execute('import'+variant,[str(exe),'--headless','--editor','--import','--path',str(project)],project,env,600)
            check_sources(project,private_expected[variant])
        analyzer = load('dust_ab_segments',projects['A']/'tools/analyze_polish_performance.py')
        signatures = []
        for index,variant in enumerate(frozen['order']):
            label = variant+str(index//2+1)
            project = projects[variant]
            env,actual_user = profile_env(label,project_name)
            perf = load('dust_ab_perf_'+label,project/'tools/run_polish_performance.py')
            old_env = os.environ.copy()
            try:
                os.environ.clear(); os.environ.update(env)
                env,controlled = perf.environment()
            finally: os.environ.clear(); os.environ.update(old_env)
            report_path = run/(label+'.json')
            env.update(POLISH_CASE='defense200',POLISH_CAMERA='fixed',POLISH_SECONDS='60',POLISH_OUT=str(report_path),POLISH_EFFECTS_QUALITY='standard')
            guard.save(run/(label+'_configuration.json'),{'controlled_production_environment':controlled,'actual_user_expected':str(actual_user),'seed':5088120,'variant':variant})
            pid,console,memory = execute(label,[str(exe),'--path',str(project),'--script','res://tools/polish_performance_probe.gd'],project,env,240)
            check_sources(project,private_expected[variant])
            r = read(report_path)
            printed = [json.loads(line[len('[polish-performance] '):]) for line in console.splitlines() if line.startswith('[polish-performance] ')]
            need(len(printed) == 1 and printed[0] == {'scenario':r['scenario'],'camera':r['camera_mode'],'complete':r['sample_complete'],
                 'seconds':r['seconds'],'fps':r['fps'],'p95_ms':r['p95_ms'],'checks':r['checks'],'failures':r['failures']}, 'Stdout/report mismatch')
            need(r.get('schema') == 2 and all(r.get(k) is True for k in ('integrity_passed','sample_complete','acceptance_eligible','effects_quality_verified','fixture_identity_ok')), 'Incomplete native report '+label)
            need(not r['failures'] and not r['gameplay_rng_fault'] and r['effects_quality_violations'] == 0 and r['camera_violations'] == 0, 'Report violation '+label)
            need(all(r.get(k) == 'standard' for k in ('effects_quality','effects_quality_requested','effects_quality_initial','effects_quality_start','effects_quality_end')) and r['configured_settings']['effects_quality'] == 'standard', 'Effects changed')
            need(Path(r['actual_user_dir']).resolve() == actual_user.resolve(), 'Wrong native private user')
            need(r['time_scale'] == 1 and r['physics_hz'] == 60 and r['requested_seconds'] == 60 and r['seconds'] >= 60 and r['gameplay_rng_seed'] == 5088120 and r['seed'] == 5088120, 'Timing/RNG configuration changed')
            need(r['scenario'] == 'defense200' and r['camera_mode'] == 'fixed' and r['resolution'] == [1440,900] and r['renderer'] == 'forward_plus', 'Fixture/render config changed')
            need(r['warmup_target_ticks'] == 300 and r['warmup_end_tick'] >= 300 and r['sample_start']['count'][1] >= 150, 'Pressure workload insufficient')
            need(len(memory) >= 60 and all(x['private_bytes'] > 0 and x['working_set_bytes'] > 0 for x in memory)
                 and all(b['process_seconds']-a['process_seconds'] <= 5 for a,b in zip(memory,memory[1:])), 'Process memory sampling incomplete')
            vectors = [r[k] for k in ('raw_frame_ms','process_monitor_ms','physics_monitor_ms','render_cpu_ms','draw_calls')]
            if r['gpu_ms'] is not None: vectors.append(r['gpu_ms'])
            need(len({len(v) for v in vectors}) == 1 and len(vectors[0]) == r['frames'] and all(math.isfinite(v) and v > 0 for v in vectors[0]), 'Frame arrays invalid')
            need(all(math.isfinite(value) and value >= 0 for vector in vectors[1:] for value in vector)
                 and abs(math.fsum(vectors[0])/1000-r['seconds']) < 0.2, 'Monitor values or frame clock invalid')
            segments = analyzer.segments(r['raw_frame_ms'])
            full = [segment for segment in segments if segment['complete_ten_seconds']]
            need(len(full) == 6 and full[0]['index'] == 0, 'Six complete wall-clock segments missing')
            rng = {entry[0]['v']:entry[1].get('v') for entry in r['gameplay_rng_initial']['record']['entries'] if entry[0].get('v') in ('seed','state','calls')}
            need(r['gameplay_rng_initial']['ok'] and rng.get('seed') == '5088120' and rng.get('calls') == '0', 'Initial RNG record mismatch')
            signature = {'deployment':r['initial_units'],'inputs':r['inputs'],'rng':rng,'gpu':r['gpu'],'godot':r['godot']}
            signatures.append(signature)
            need(all(value == signatures[0] for value in signatures), 'Initial paired fixture/hardware/RNG changed')
            row = {'label':label,'variant':variant,'pid':pid,'report_sha256':sha(report_path.read_bytes()),'first10':full[0],
                   'segments':segments,'lowest10_fps':min(x['fps'] for x in full),'worst10_p95_ms':max(x['p95_ms'] for x in full),'worst10_p99_ms':max(x['p99_ms'] for x in full),
                   'full_fps':r['fps'],'full_p95_ms':r['p95_ms'],'full_p99_ms':r['p99_ms'],'sample_start':r['sample_start'],'sample_end':r['sample_end'],
                   'peak_private_bytes':max(x['private_bytes'] for x in memory),'memory_samples':len(memory),
                   'gpu_monitor_available':r['gpu_ms'] is not None,
                   'simulated_seconds':r['simulated_seconds'],'initial_signature_sha256':sha(json.dumps(signature,sort_keys=True).encode())}
            receipt['samples'].append(row)
            if index%2:
                a,b = receipt['samples'][-2:]
                need(all(a['sample_end'][key] == b['sample_end'][key] for key in ('count','phase')), 'Paired terminal workload differs')
            guard.save(run/'receipt.json',receipt)
        need(len(receipt['samples']) == 6, 'Incomplete pair inventory')
        receipt['analysis'] = pair_analysis(receipt['samples'])
        guard.save(run/'analysis.json',receipt['analysis'])
        receipt['complete'] = True
    except BaseException as exc: receipt['error'] = type(exc).__name__+': '+str(exc)
    finally:
        if active is not None:
            try: active.kill(); active.wait(timeout=30)
            except BaseException as exc: receipt['final_issues'].append(str(exc))
        checks = (
            ('production_unchanged',lambda:production_before is not None and production_snapshot() == production_before),
            ('player_unchanged',lambda:player_before is not None and guard.snapshot(player) == player_before),
            ('private_sources_unchanged',lambda:len(private_expected)==2 and all(check_sources(projects[v],private_expected[v]) is None for v in private_expected)),
            ('baseline_sources_unchanged',lambda:sha((BASELINE/'receipt.json').read_bytes()) == frozen['baseline_receipt_sha256'] and all(sha((BASELINE/'project'/name).read_bytes()) == digest for name,digest in expected.items())),
            ('candidate_unchanged',lambda:sha((DATA/'freeze.json').read_bytes()) == frozen['data_freeze_sha256'] and all(sha((DATA/name).read_bytes()) == digest for name,digest in data_freeze['inputs'].items())),
            ('tools_unchanged',lambda:sha((HERE/'freeze.json').read_bytes()) == args.freeze_sha256 and all(sha((HERE/name).read_bytes()) == digest for name,digest in frozen['inputs'].items()) and sha((ROOT/'tools/run_stabilization_performance.py').read_bytes()) == frozen['guard_sha256']))
        for label,check in checks:
            try: receipt[label] = check()
            except BaseException as exc: receipt[label] = False; receipt['final_issues'].append(label+': '+str(exc))
        try:
            receipt['godot_pids_after'] = guard.godot_processes()
            need(not receipt['godot_pids_after'] and lock_owned and lock.read_text(encoding='utf-8') == owner, 'Godot exit/lock ownership mismatch')
            lock.unlink(); receipt['lock_released'] = True
        except BaseException as exc: receipt['lock_released'] = False; receipt['final_issues'].append(str(exc))
        receipt['complete'] = receipt['complete'] and not receipt['final_issues'] and receipt.get('lock_released') is True and all(receipt.get(label) is True for label,_ in checks)
        guard.save(run/'receipt.json',receipt)
        print('RECEIPT '+str(run/'receipt.json'),flush=True)
    return 0 if receipt['complete'] else 1

if __name__ == '__main__': raise SystemExit(main())
