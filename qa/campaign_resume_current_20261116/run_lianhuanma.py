"""Run the original four-process full-story contract on the new current candidate.

Workers/assertions are byte-pinned; only the source binding and host change.
This never resumes the user-cleared old runner or opens a player profile.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import time
import uuid

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('current_resume_prepare', HERE / 'prepare.py')
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)
WORKERS = ('bootstrap.gd', 'base.gd', 'terminal.gd', 'policy.gd', 'driver.gd')
MODES = ('save_training', 'resume_training', 'resume_victory', 'reject_terminal')


def worker_pins():
    contract = p.read(HERE / 'workers.json')
    pins = {str(HERE / 'workers.json'): p.sha(HERE / 'workers.json'), str(Path(__file__)): p.sha(__file__)}
    for row in contract['files']:
        source = p.inside(HERE / 'workers', row['name'])
        p.need(p.sha(source) == row['sha256'] and source.stat().st_size == row['bytes'], 'Worker source changed')
        pins[str(source)] = row['sha256']
    strategy = p.read(HERE / 'workers/strategy.json')
    raw = (HERE / 'workers/driver.gd').read_bytes()
    p.need(p.digest(raw) == strategy['derived_sha256'] == contract['driver_sha256'], 'Strategy changed')
    restored = raw.decode('utf-8')
    for patch in reversed(strategy['patches']):
        p.need(restored.count(patch['after']) == 1, 'Strategy inverse not unique')
        restored = restored.replace(patch['after'], patch['before'], 1)
    original = subprocess.check_output(['git', 'show', contract['source_commit'] + ':' + strategy['original_path']], cwd=p.ROOT)
    p.need(restored.encode('utf-8') == original and p.digest(original) == contract['original_driver_sha256'],
           'Original assertions and non-strategy flow must remain unchanged')
    return pins


def execute(args):
    pins = worker_pins()
    run, project, preparation = p.admission(args.candidate)
    cold = p.read(run / 'cold_import/receipt.json')
    p.need(all(cold.get(k) is True for k in ('complete', 'cold_import_qualified', 'children_gone', 'lock_released')),
           'Own complete cold import required')
    p.need(cold['preparation_sha256'] == p.sha(run / 'preparation.json')
           and cold['runner_sha256'] == p.sha(HERE / 'prepare.py')
           and cold['generation_sha256'] == p.sha(run / 'generation.json'), 'Cold binding changed')
    steps = cold['steps']
    p.need(len(steps) == 1 and steps[0]['passed'] and steps[0]['exit_code'] == 0 and not steps[0]['errors']
           and steps[0]['log_sha256'] == p.sha(run / 'cold_import/import.log')
           and str(project) in steps[0]['command'], 'Actual current cold process required')
    generation = p.read(run / 'generation.json')
    p.identity.verify_generated(project, generation)
    engine = args.godot.absolute()
    p.need(p.sha(engine) == cold['engine_sha256'], 'Same engine as cold import required')
    pins.update(preparation['pins'])
    for name in ('preparation.json', 'candidate_manifest.json', 'root_source.json', 'preimport_source.json',
                 'generation.json', 'expected_identity.json', 'cold_import/receipt.json', 'cold_import/import.log'):
        pins[str(run / name)] = p.sha(run / name)
    output = run / ('lianhuanma_' + time.strftime('%H%M%S') + '_' + uuid.uuid4().hex[:8])
    output.mkdir()
    receipt = {'schema': 'current_campaign_lianhuanma_v1', 'complete': False,
               'source_victory_chain_passed': False, 'steps': [], 'preflight_steps': [], 'reports': [],
               'source_identity': 'source-v1:' + generation['identity']['source_sha256'],
               'candidate': str(run), 'original_assertions_preserved': True,
               'full_story_required': True, 'public_continue_qualified': False,
               'native_sdk_qualified': False, 'human_acceptance': False, 'published': False}
    locked = False
    previous = None
    pids = set()
    try:
        p.need(not p.running(), 'Engine lane busy; no child started')
        with args.lock.open('x', encoding='utf-8') as handle:
            handle.write(str(output))
        locked = True
        workers = output / 'workers'
        workers.mkdir()
        for name in (*WORKERS, 'validate_strategy.gd'):
            shutil.copyfile(HERE / 'workers' / name, workers / name)
            p.need(p.sha(workers / name) == pins[str(HERE / 'workers' / name)], 'Worker copy changed')
            pins[str(workers / name)] = p.sha(workers / name)
        binding = workers / 'bindings.json'
        p.save(binding, {name: p.sha(workers / name) for name in WORKERS})
        pins[str(binding)] = p.sha(binding)
        profile = Path(p.ROOT.anchor) / 'CodexQA/resumelian' / uuid.uuid4().hex[:12]
        p.identity.no_links(profile)
        profile.mkdir(parents=True, exist_ok=False)
        env = p.common.private_environment(profile)
        for key in list(env):
            if key.startswith(('LSH_', 'LT_', 'LL_', 'GT_', 'GVT_', 'GLS_', 'DF_', 'DN_', 'UST_', 'UCR_',
                               'USR_', 'UTR_', 'URF_', 'P19_', 'CR_', 'HG_', 'CH_', 'LHMR_', 'RS_')):
                env.pop(key)
        nonce = uuid.uuid4().hex
        manifest_sha = p.sha(run / 'candidate_manifest.json')
        env.update(STEAM_DISABLED='1', CAMPAIGN_QA='', LSH_CONTINUE_FLOW_QA='1',
                   LSH_CONTINUE_FLOW_PROFILE=str(profile), LSH_LANGUAGE='zh_CN',
                   LT_PROFILE=str(profile), LT_PROJECT=str(project), LT_WORKERS=str(workers),
                   LT_BINDINGS=str(binding), LT_BINDINGS_SHA256=p.sha(binding), LT_NONCE=nonce,
                   LT_CANDIDATE_SHA256=manifest_sha, LT_PROVENANCE_SHA256=p.sha(HERE / 'workers/provenance.json'))
        receipt.update(profile=str(profile), batch_nonce=nonce, manifest_sha256=manifest_sha)
        check_env = dict(env, LT_STRATEGY_SOURCE=str(workers / 'driver.gd'))
        p.common.process_step(engine, project, check_env, output, 'strategy_preflight',
                              ['--headless', '--script', str(workers / 'validate_strategy.gd')], 120,
                              'gl_compatibility', p.running, receipt['preflight_steps'])
        p.need('STRATEGY_CONTRACT PASS ' in (output / 'strategy_preflight.log').read_text(encoding='utf-8'), 'Strategy preflight incomplete')
        for mode in MODES:
            p.check_pins(pins)
            stage = output / mode
            stage.mkdir()
            report_path = stage / 'report.json'
            process_nonce = uuid.uuid4().hex
            child_env = dict(env, LT_MODE=mode, LT_REPORT=str(report_path), LT_PROCESS_NONCE=process_nonce)
            if previous:
                child_env.update(LT_PREVIOUS=str(previous), LT_PREVIOUS_SHA256=p.sha(previous))
            try:
                p.common.process_step(engine, project, child_env, stage, mode,
                                      ['--resolution', '1280x720', '--position', '30000,30000',
                                       '--script', str(workers / 'bootstrap.gd')], 1500,
                                      'gl_compatibility', p.running, receipt['steps'])
            finally:
                if report_path.is_file():
                    report = p.read(report_path)
                    receipt['reports'].append({'mode': mode, 'path': str(report_path), 'sha256': p.sha(report_path),
                                               'passed': report.get('passed', False), 'checks': len(report.get('checks', []))})
            report = p.read(report_path)
            p.need(report.get('schema') == 'campaign_lianhuanma_terminal_v2' and report.get('passed') is True
                   and report.get('stage_completed') is True and report.get('failures') == []
                   and report.get('checks') and all(c.get('passed') is True for c in report['checks']), 'Stage incomplete: ' + mode)
            p.need(report.get('mode') == mode and report.get('profile') == str(profile)
                   and report.get('batch_nonce') == nonce and report.get('process_nonce') == process_nonce
                   and report.get('slot_root') == 'user://continue/v1' and report.get('candidate_manifest_sha256') == manifest_sha
                   and report.get('identity', {}).get('content_version') == receipt['source_identity']
                   and report['identity'].get('engine_sha256') == cold['engine_sha256']
                   and report['identity'].get('source_mode') is True and report.get('simulation_time_scale') == 1
                   and report.get('no_gameplay_state_injection') is True and report.get('full_story_required') is True,
                   'Actual scope/identity/full-story contract required')
            p.need(all(report.get(k) is False for k in ('public_continue_qualified', 'native_sdk_qualified',
                                                       'native_release_tested', 'human_acceptance')), 'No wider qualification')
            if mode in ('save_training', 'resume_training'):
                p.need(report.get('save_exit_observed') is True and report.get('exit_reason') == 'continue_saved', 'Production save/exit required')
            if mode == 'reject_terminal':
                refusal = report.get('observations', {}).get('terminal_refusal', {})
                p.need(refusal.get('ok') is False and refusal.get('code') == 'LOCAL_RUN_TERMINAL', 'Original terminal slot refusal required')
            pid = report.get('pid')
            step = receipt['steps'][-1]
            p.need(type(pid) is int and pid > 0 and pid == step['pid'] and pid not in pids
                   and step['exit_code'] == 0 and step['passed'] and not step['errors'], 'Unique actual process required')
            pids.add(pid)
            previous = report_path
            pins[str(report_path)] = p.sha(report_path)
            pins[str(stage / (mode + '.log'))] = p.sha(stage / (mode + '.log'))
        receipt['source_victory_chain_passed'] = True
    except BaseException as error:
        receipt['error'] = repr(error)
    finally:
        try:
            p.identity.verify_generated(project, generation)
            p.need(p.identity.snapshot(p.ROOT) == p.read(run / 'root_source.json'), 'Gameplay changed')
            p.check_pins(pins)
            p.need(p.sha(engine) == cold['engine_sha256'], 'Engine changed')
            receipt['post_source_unchanged'] = True
        except BaseException as error:
            receipt['post_error'] = repr(error)
        receipt['lock_released'] = bool(locked and p.common.release_owned_lock(args.lock, output, receipt, p.running()))
        receipt['complete'] = bool(receipt['source_victory_chain_passed'] and receipt.get('post_source_unchanged')
                                   and receipt['lock_released'] and len(pids) == 4 and 'error' not in receipt)
        receipt['source_victory_chain_passed'] = receipt['complete']
        receipt['pins'] = pins
        p.save(output / 'receipt.json', receipt)
    print(json.dumps({'output': str(output), 'complete': receipt['complete'], 'error': receipt.get('error'),
                      'reports': receipt['reports']}, ensure_ascii=False), flush=True)
    p.need(receipt['complete'], 'Current four-process route incomplete')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--lock', type=Path, required=True)
    args = parser.parse_args()
    p.need(args.candidate.is_absolute() and args.lock.is_absolute(), 'Absolute candidate and shared lock required')
    execute(args)


if __name__ == '__main__':
    main()
