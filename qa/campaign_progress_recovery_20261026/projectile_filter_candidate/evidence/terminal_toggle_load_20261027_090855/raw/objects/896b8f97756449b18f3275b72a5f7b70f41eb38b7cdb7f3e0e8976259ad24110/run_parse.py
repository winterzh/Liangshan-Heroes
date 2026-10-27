from __future__ import annotations
import hashlib, importlib.util, json, os, subprocess, time, uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / 'qa/campaign_progress_recovery_20261026/projectile_filter_candidate/run_gaoqiu_terminal.py'
spec = importlib.util.spec_from_file_location('gaoqiu_toggle_parse_host', HOST)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
h, p = mod.h, mod.p
output = Path(__file__).parent / h.stamp()
output.mkdir()
owner = str(output)
receipt = {'schema':'gaoqiu_toggle_worker_parser_only_v1', 'complete':False, 'runtime_qualified':False, 'full_source_qualified':False, 'steps':[]}
locked = False
pins = mod.source_pins()
project = ROOT / '.godot/campaign_progress_recovery_20261026/20261027_075456_3e4a48ab/project'
engine = Path('C:/Users/rsb/Desktop/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe')
expected_engine = 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00'
try:
    assert h.sha(engine) == expected_engine
    assert not h.shared.LOCK.exists() and not h.running(), 'Engine lane occupied'
    with h.shared.LOCK.open('x', encoding='utf-8') as f: f.write(owner)
    locked = True
    assert not h.running()
    for path, digest in list(pins.items()):
        source = Path(path)
        assert source.is_relative_to(ROOT) and source.suffix.lower() not in ('.exe','.dll')
        p.copy(source, output / 'source_inputs' / source.relative_to(ROOT), digest)
    p.copy(Path(__file__), output / 'run_parse.py', h.sha(__file__))
    workers = output / 'workers'
    workers.mkdir()
    for name in mod.WORKERS:
        p.copy(mod.WORKER_ROOT / name, workers / name, pins[str(mod.WORKER_ROOT / name)])
        p.pin(workers / name, pins)
    profile = Path('D:/CodexQA/gaoqiutoggleparse') / uuid.uuid4().hex[:12]
    h.identity.no_links(profile)
    profile.mkdir(parents=True, exist_ok=False)
    env = h.common.private_environment(profile)
    env.update(STEAM_DISABLED='1', CAMPAIGN_QA='', LSH_CONTINUE_FLOW_QA='')
    loader = output / 'parse_bootstrap.gd'
    loader.write_text("extends SceneTree\nfunc _initialize() -> void:\n\tcheck.call_deferred()\nfunc check() -> void:\n\tfor name: String in [\"bootstrap.gd\",\"base.gd\",\"terminal.gd\",\"driver.gd\",\"policy.gd\"]:\n\t\tvar script: Script = load(OS.get_environment(\"GAO_TOGGLE_PARSE_WORKERS\").path_join(name))\n\t\tif script == null or not script.can_instantiate():\n\t\t\tpush_error(\"GAO_TOGGLE_PARSER_INVALID: \" + name)\n\t\t\tquit(2)\n\t\t\treturn\n\tprint(\"GAO_TOGGLE_WORKERS_COMPILED_WITHOUT_INSTANTIATION\")\n\tquit(0)\n", encoding='utf-8')
    p.pin(loader, pins)
    env['GAO_TOGGLE_PARSE_WORKERS'] = str(workers)
    for name in ('parse_bootstrap',):
        command = [str(engine), '--headless', '--path', str(project), '--script', str(loader)]
        started = time.monotonic()
        proc = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            stdout = proc.communicate(timeout=120)[0]
        except subprocess.TimeoutExpired:
            proc.kill()
            stdout = proc.communicate()[0]
            raise RuntimeError('Parser timeout after own process termination')
        log = output / (name + '.log')
        log.write_bytes(stdout)
        text = stdout.decode('utf-8', errors='replace')
        errors = [line for line in text.splitlines() if 'ERROR:' in line or 'SCRIPT ERROR' in line]
        row = {'script':name,'command':command,'pid':proc.pid,'exit_code':proc.returncode,'seconds':round(time.monotonic()-started,3),'errors':errors,'log_sha256':h.sha(log)}
        receipt['steps'].append(row)
        print(json.dumps(row, ensure_ascii=False), flush=True)
        assert proc.returncode == 0 and not errors, 'Native parser failed'
    p.verify_pins(pins)
    receipt['complete'] = True
except BaseException as error:
    receipt['error'] = repr(error)
finally:
    receipt['engine_sha256'] = h.sha(engine)
    receipt['pinned_files'] = pins
    receipt['lane_idle'] = not h.running()
    receipt['owner_confirmed'] = bool(locked and h.shared.LOCK.is_file() and h.shared.LOCK.read_text(encoding='utf-8') == owner)
    if receipt['owner_confirmed'] and receipt['lane_idle']:
        h.shared.LOCK.unlink()
    receipt['lock_released'] = bool(locked and not h.shared.LOCK.exists())
    receipt['complete'] = bool(receipt['complete'] and receipt['lock_released'])
    receipt['runner_sha256'] = h.sha(__file__)
    h.save(output / 'receipt.json', receipt)
print(json.dumps({'output':str(output),'complete':receipt['complete'],'error':receipt.get('error')},ensure_ascii=False), flush=True)
raise SystemExit(0 if receipt['complete'] else 1)
