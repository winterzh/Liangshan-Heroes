"""Load three fixed-source release-fault-model scripts without instantiating a worker.

Default: named sources and Python AST only; no engine/profile/lane acquisition.
--run: one owned headless load/can_instantiate process; no fault injection or model execution.
"""
from __future__ import annotations

import argparse
import ast
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time
import traceback
import uuid

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / 'qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_release_fault_model/run_ui_release_fault_model.py'
spec = importlib.util.spec_from_file_location('ui_release_fault_load_host', HOST)
ui = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ui)
p, h = ui.p, ui.h
PROJECT = ROOT / '.godot/campaign_progress_recovery_20261026/20261027_075456_3e4a48ab/project'
ENGINE = Path('C:/Users/rsb/Desktop/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe')
ENGINE_SHA = 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00'
LOADER = '''extends SceneTree
func _initialize() -> void:
    check.call_deferred()
func check() -> void:
    var paths: Variant = JSON.parse_string(OS.get_environment("LOAD_SCRIPT_PATHS"))
    if not paths is Array or paths.size() != 3:
        push_error("INVALID_UI_LOAD_ONLY_INVENTORY")
        quit(2)
        return
    for path: String in paths:
        var script: Script = load(path)
        if script == null or not script.can_instantiate():
            push_error("LOAD_ONLY_INVALID: " + path)
            quit(2)
            return
        print("LOAD_ONLY_PASS " + path)
    print("THREE_UI_SCRIPTS_LOADED_WITHOUT_INSTANTIATION")
    quit(0)
'''


def named_check():
    _, pins = ui.named_state()
    ui.require(tuple(ui.WORKERS) == ('bootstrap.gd', 'base.gd', 'worker.gd'),
               'Exactly the three current release-fault-model scripts are required')
    python_sources = [Path(name) for name in pins if Path(name).suffix.lower() == '.py']
    for path in [Path(__file__).resolve(), *python_sources]:
        h.identity.no_links(p.fs(path))
        ast.parse(p.fs(path).read_text(encoding='utf-8-sig'), filename=str(path))
    return pins, len(python_sources) + 1


def execute(args, named_pins, ast_count):
    output = Path(__file__).resolve().parent / h.stamp()
    h.identity.no_links(p.fs(output)); p.fs(output).mkdir(exist_ok=False)
    runner_sha = ui.sha(__file__)
    pins = dict(named_pins)
    p.pin(Path(__file__).resolve(), pins, runner_sha)
    receipt = {'schema': 'ui_release_fault_model_external_load_only_v1', 'complete': False, 'steps': [],
               'named_source_count': len(named_pins), 'python_ast_count': ast_count,
               'worker_names': list(ui.WORKERS), 'runner_sha256': runner_sha,
               'engine_sha256': ENGINE_SHA, 'project': str(PROJECT), 'source_identity_expected': ui.CONTENT,
               'worker_instantiated': False, 'battle_instantiated': False,
               'private_continue_gate_enabled': False, 'full_source_qualified': False,
               'runtime_qualified': False, 'two_process_release_fault_model_qualified': False,
               'clock_fault_injected': False, 'permanent_clock_fault_model_executed': False,
               'natural_fault_reproduced': False, 'retry_release_success_qualified': False,
               'desktop_os_input': False, 'native_sdk_qualified': False,
               'human_acceptance': False, 'published': False, 'post_errors': []}
    owner, locked, child = str(output), False, None
    try:
        started = time.monotonic()
        while not locked:
            if not p.fs(h.shared.LOCK).exists() and not ui.baseline.engines():
                try:
                    with p.fs(h.shared.LOCK).open('x', encoding='utf-8') as stream:
                        stream.write(owner)
                    locked = True
                    break
                except FileExistsError:
                    pass
            ui.require(time.monotonic() - started < args.wait_lane, 'Shared native lane is occupied; no child started')
            time.sleep(1)
        ui.require(not ui.baseline.engines() and ui.sha(ENGINE) == ENGINE_SHA, 'Engine/lane identity changed')
        p.verify_pins(pins)
        for name, digest in named_pins.items():
            source = Path(name)
            ui.require(source.is_relative_to(ROOT) and source.suffix.lower() not in ('.exe', '.dll', '.pck'),
                       'Only repository source inputs may be frozen')
            target = output / 'source_inputs' / source.relative_to(ROOT)
            p.copy(source, target, digest); p.pin(target, pins, digest)
        p.copy(Path(__file__).resolve(), output / 'run_load.py', runner_sha)
        p.pin(output / 'run_load.py', pins, runner_sha)
        workers = output / 'workers'; p.fs(workers).mkdir()
        scripts = []
        for name in ui.WORKERS:
            target = workers / name
            p.copy(ui.HERE / name, target, named_pins[str(ui.HERE / name)])
            p.pin(target, pins); scripts.append(str(target))
        loader = output / 'loader.gd'
        with p.fs(loader).open('x', encoding='utf-8', newline='\n') as stream:
            stream.write(LOADER)
        p.pin(loader, pins)
        profile = Path('D:/CodexQA/uireleasefaultload') / uuid.uuid4().hex[:12]
        h.identity.no_links(p.fs(profile)); p.fs(profile).mkdir(parents=True, exist_ok=False)
        env = h.common.private_environment(profile)
        for key in list(env):
            if key.startswith(('URF_', 'UTR_', 'UST_', 'UCR_', 'USR_', 'P19_', 'DN_', 'DF_', 'GVT_', 'GT_', 'GLS_', 'CR_', 'CC_', 'RS_', 'LSH_CONTINUE_FLOW_', 'LOAD_SCRIPT_')):
                env.pop(key)
        env.update(STEAM_DISABLED='1', CAMPAIGN_QA='', LSH_CONTINUE_FLOW_QA='',
                   LOAD_SCRIPT_PATHS=json.dumps(scripts))
        receipt['profile'] = str(profile)
        command = [str(ENGINE), '--headless', '--path', str(PROJECT), '--script', str(loader)]
        step = {'command': command, 'complete': False, 'stopped_for': None}
        receipt['steps'].append(step)
        start = time.monotonic()
        with p.fs(output / 'load.log').open('xb') as log:
            child = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT,
                                     creationflags=subprocess.CREATE_NO_WINDOW)
            step['pid'] = child.pid
            try:
                child.wait(timeout=args.timeout)
            except subprocess.TimeoutExpired:
                step['stopped_for'] = 'timeout'
                child.terminate()
                try:
                    child.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    child.kill(); child.wait(timeout=10)
        text = p.fs(output / 'load.log').read_text(encoding='utf-8', errors='replace')
        lines = text.splitlines()
        errors = [line for line in lines if 'ERROR:' in line or 'SCRIPT ERROR' in line or 'Parse Error:' in line]
        loaded = [line for line in lines if line.startswith('LOAD_ONLY_PASS ')]
        step.update(exit_code=child.returncode, seconds=round(time.monotonic() - start, 3),
                    errors=errors, loaded_lines=loaded, log_sha256=ui.sha(output / 'load.log'))
        ui.require(child.returncode == 0 and step['stopped_for'] is None and not errors
                   and loaded == ['LOAD_ONLY_PASS ' + name for name in scripts]
                   and lines.count('THREE_UI_SCRIPTS_LOADED_WITHOUT_INSTANTIATION') == 1,
                   'Exactly three native load/can_instantiate results required')
        step['complete'] = True
        receipt['native_load_passed'] = True
    except BaseException as error:
        receipt.update(error=repr(error), traceback=traceback.format_exc())
    finally:
        def cleanup_child():
            if child is not None and child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    child.kill(); child.wait(timeout=10)
            receipt['child_terminal'] = child is None or child.poll() is not None
            if child is not None and receipt['steps']:
                receipt['steps'][-1].update(pid=child.pid, exit_code=child.returncode)
        ui.attempt(receipt, 'owned_child_terminal', cleanup_child)
        okay, _ = ui.attempt(receipt, 'final_pins', lambda: p.verify_pins(pins))
        receipt['final_pins_passed'] = okay
        okay, _ = ui.attempt(receipt, 'engine_unchanged', lambda: ui.require(ui.sha(ENGINE) == ENGINE_SHA, 'Engine changed'))
        receipt['engine_unchanged'] = okay
        def unlock():
            receipt['lane_idle'] = not ui.baseline.engines()
            receipt['owner_confirmed'] = bool(locked and p.fs(h.shared.LOCK).is_file()
                                               and p.fs(h.shared.LOCK).read_text(encoding='utf-8') == owner)
            if receipt['lane_idle'] and receipt['owner_confirmed'] and receipt.get('child_terminal') is True:
                p.fs(h.shared.LOCK).unlink(); receipt['lock_released'] = not p.fs(h.shared.LOCK).exists()
        ui.attempt(receipt, 'owned_lock_release', unlock)
        receipt['pinned_files'] = pins
        receipt['complete'] = bool(receipt.get('native_load_passed') and receipt['final_pins_passed']
                                   and receipt['engine_unchanged'] and receipt.get('lock_released')
                                   and not receipt.get('error') and not receipt['post_errors'])
        ui.persist(output / 'receipt.json', receipt)
    print(json.dumps({'output': str(output), 'complete': receipt['complete'], 'steps': receipt['steps'],
                      'error': receipt.get('error')}, ensure_ascii=False), flush=True)
    if not receipt['complete']:
        raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--timeout', type=int, default=150)
    parser.add_argument('--wait-lane', type=int, default=0)
    args = parser.parse_args()
    if args.timeout < 30 or args.wait_lane < 0:
        parser.error('Invalid bounded native deadline')
    pins, ast_count = named_check()
    if not args.run:
        print(json.dumps({'named_pins': len(pins), 'python_ast_passed': ast_count,
                          'workers': list(ui.WORKERS), 'engine_started': False, 'profile_created': False,
                          'lane_acquired': False, 'full_source_qualified': False, 'runtime_qualified': False}, ensure_ascii=False))
        return
    execute(args, pins, ast_count)


if __name__ == '__main__':
    main()
