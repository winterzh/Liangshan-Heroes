"""Continue after engine contention or retry the documented lure-route failure."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('original_current_lian_host', HERE / 'run_lianhuanma.py')
host = importlib.util.module_from_spec(spec)
spec.loader.exec_module(host)
p = host.p


def wait_idle():
    start = time.monotonic()
    notice = start
    while p.running():
        p.need(time.monotonic() - start < 600, 'Engine lane remains occupied; no next child started')
        if time.monotonic() - notice >= 25:
            print('WAIT engine lane', round(time.monotonic() - start), 'seconds; no child started', flush=True)
            notice = time.monotonic()
        time.sleep(1)


def run_stage_when_idle(engine, project, env, stage, mode, steps, bootstrap):
    deadline = time.monotonic() + 600
    previous_count = len(steps)
    while True:
        wait_idle()
        try:
            p.common.process_step(engine, project, env, stage, mode,
                                  ['--resolution', '1280x720', '--position', '30000,30000',
                                   '--script', str(bootstrap)], 1500,
                                  'gl_compatibility', p.running, steps)
            return
        except RuntimeError as error:
            if (str(error) != 'Godot/Liangshan engine appeared before step ' + mode
                    or len(steps) != previous_count or (stage / (mode + '.log')).exists()
                    or time.monotonic() >= deadline):
                raise


def verified_retry(old, original, tail):
    p.identity.no_links(tail)
    p.need(tail.parent == old.parent and tail.name.startswith('lian_tail_'), 'Expected a sibling continuation')
    prior_receipt = tail / 'receipt.json'
    prior = p.read(prior_receipt)
    p.need(prior['previous_batch'] == str(old)
           and prior['previous_receipt_sha256'] == p.sha(old / 'receipt.json')
           and all(prior[key] == original[key] for key in ('source_identity', 'profile', 'batch_nonce'))
           and prior['post_source_unchanged'] and prior['lock_released'] and not prior['complete'],
           'Expected the closed failed tail of the same saved battle')
    p.need([s['case'] for s in original['steps']] == ['save_training']
           and [s['case'] for s in prior['steps']] == ['resume_training', 'resume_victory'],
           'Expected one save, one re-save and one failed combat')
    failed = prior['steps'][-1]
    failed_row = prior['reports'][-1]
    failed_path = tail / 'resume_victory/report.json'
    failure = p.read(failed_path)
    log = tail / 'resume_victory/resume_victory.log'
    p.need(not failed['passed'] and failed['exit_code'] == 1 and not failed['errors']
           and failed['log_sha256'] == p.sha(log) and failed_row['sha256'] == p.sha(failed_path)
           and failure['pid'] == failed['pid'] and not failure['passed']
           and failure['failures'] == ['ordinary non-hook infantry actually enters lure radius'],
           'Only the documented lure-route failure is eligible')
    pins = {**original['pins'], **prior['pins']}
    archived_paths = {'continue_lianhuanma.py', 'workers.json', 'workers/driver.gd', 'workers/strategy.json'}
    for name in list(pins):
        path = Path(name)
        if path.is_relative_to(HERE) and path.relative_to(HERE).as_posix() in archived_paths:
            git_path = path.relative_to(p.ROOT).as_posix()
            raw = subprocess.check_output(['git', 'show', 'e53cebb4:' + git_path], cwd=p.ROOT)
            p.need(p.digest(raw) == pins[name], 'Unexpected historical worker input: ' + git_path)
            del pins[name]
    pins.update({str(prior_receipt): p.sha(prior_receipt), str(failed_path): p.sha(failed_path), str(log): p.sha(log)})
    return original['steps'] + prior['steps'][:1], original['reports'] + prior['reports'][:1], pins, failed['pid']


def execute(args):
    old = args.batch.absolute()
    p.identity.no_links(old)
    original = p.read(old / 'receipt.json')
    for prior_path in old.parent.glob('lian_tail_*/receipt.json'):
        p.identity.no_links(prior_path)
        prior = p.read(prior_path)
        if prior.get('previous_batch') == str(old):
            if not args.retry_lure_tail or prior_path.parent != args.retry_lure_tail:
                p.need(not prior.get('steps'), 'Another continuation process already started for this batch')
    run, project, preparation = p.admission(old.parent)
    completed_modes = tuple(s['case'] for s in original['steps'])
    p.need(completed_modes in (host.MODES[:1], host.MODES[:2]),
           'Expected one or two completed save stages')
    remaining_modes = host.MODES[len(completed_modes):]
    first_mode = remaining_modes[0]
    occupancy = RuntimeError('Godot/Liangshan engine appeared before step ' + first_mode)
    p.need(original['candidate'] == str(run) and original.get('post_source_unchanged') is True
           and original.get('error') == repr(occupancy)
           and original['complete'] is False, 'Expected an explicit pre-launch occupancy stop')
    p.need(all(s['passed'] and s['exit_code'] == 0 and not s['errors'] for s in original['steps']),
           'Saved prefix processes must have passed')
    saved_steps = original['steps']
    saved_reports = original['reports']
    failed_pid = None
    if args.retry_lure_tail:
        saved_steps, saved_reports, pins, failed_pid = verified_retry(old, original, args.retry_lure_tail)
        remaining_modes = host.MODES[len(saved_steps):]
    else:
        for mode in remaining_modes:
            p.need(not (old / mode / (mode + '.log')).exists()
                   and not (old / mode / 'report.json').exists(), 'Remaining stage already started: ' + mode)
        pins = dict(original['pins'])
    p.check_pins(pins)
    current_worker_pins = host.worker_pins()
    p.check_pins(current_worker_pins)
    pins.update(current_worker_pins)
    pins[str(old / 'receipt.json')] = p.sha(old / 'receipt.json')
    pins[str(Path(__file__))] = p.sha(__file__)
    generation = p.read(run / 'generation.json')
    p.identity.verify_generated(project, generation)
    cold = p.read(run / 'cold_import/receipt.json')
    engine = args.godot.absolute()
    p.need(cold['complete'] and cold['cold_import_qualified'] and cold['lock_released']
           and cold['engine_sha256'] == p.sha(engine), 'Own cold import and same engine required')
    identity = 'source-v1:' + generation['identity']['source_sha256']
    p.need(original['source_identity'] == identity, 'Same current candidate required')
    profile = Path(original['profile'])
    p.identity.no_links(profile)
    nonce = original['batch_nonce']
    manifest_sha = original['manifest_sha256']
    pids = {s['pid'] for s in saved_steps}
    for row, step in zip(saved_reports, saved_steps, strict=True):
        report = p.read(row['path'])
        p.need(step['passed'] and step['exit_code'] == 0 and not step['errors']
               and p.sha(row['path']) == row['sha256'] and report.get('passed') is True
               and report.get('stage_completed') is True and report.get('failures') == []
               and all(c['passed'] for c in report['checks']) and report['pid'] == step['pid']
               and report['mode'] == step['case'] and report['profile'] == str(profile)
               and report['batch_nonce'] == nonce and report['candidate_manifest_sha256'] == manifest_sha
               and report['identity']['content_version'] == identity and report['identity']['engine_sha256'] == cold['engine_sha256']
               and report['full_story_required'] is True and report['save_exit_observed'] is True
               and report['exit_reason'] == 'continue_saved', 'Original saved-stage evidence changed')
    p.need(len(pids) == len(saved_steps) and all(type(pid) is int and pid > 0 for pid in pids),
           'Distinct earlier PIDs required')
    previous = Path(saved_reports[-1]['path'])
    output = run / ('lian_tail_' + time.strftime('%H%M%S') + '_' + uuid.uuid4().hex[:8])
    output.mkdir()
    receipt = {'schema': 'current_lianhuanma_tail_v1', 'complete': False, 'steps': [], 'reports': [],
               'previous_batch': str(old), 'previous_receipt_sha256': p.sha(old / 'receipt.json'),
               'source_identity': identity, 'profile': str(profile), 'batch_nonce': nonce,
               'full_story_required': True, 'source_victory_chain_passed': False,
               'public_continue_qualified': False, 'native_sdk_qualified': False, 'human_acceptance': False}
    if args.retry_lure_tail:
        receipt.update(retry_lure_tail=str(args.retry_lure_tail), reused_saved_reports=saved_reports,
                       retry_strategy_sha256=p.sha(HERE / 'workers/driver.gd'))
    locked = False
    try:
        wait_idle()
        if args.lock.exists():
            p.need(args.lock.read_text(encoding='utf-8') == str(old) and original['lock_released'] is False,
                   'Never remove another owner lock')
            # The old host and its verified saved prefix have exited.
            args.lock.unlink()
            receipt['recovered_previous_owned_lock'] = True
        with args.lock.open('x', encoding='utf-8') as handle:
            handle.write(str(output))
        locked = True
        workers = old / 'workers'
        if args.retry_lure_tail:
            workers = output / 'workers'
            workers.mkdir()
            for name in host.WORKERS:
                source = HERE / 'workers' / name
                shutil.copyfile(source, workers / name)
                p.need(p.sha(workers / name) == pins[str(source)], 'Copied strategy input changed')
                pins[str(workers / name)] = p.sha(workers / name)
            binding = workers / 'bindings.json'
            p.save(binding, {name: p.sha(workers / name) for name in host.WORKERS})
            pins[str(binding)] = p.sha(binding)
        env = os.environ.copy()
        for key in list(env):
            if key.startswith(('LSH_', 'LT_', 'LL_', 'GT_', 'GVT_', 'GLS_', 'DF_', 'DN_', 'UST_', 'UCR_',
                               'USR_', 'UTR_', 'URF_', 'P19_', 'CR_', 'HG_', 'CH_', 'LHMR_', 'RS_')) \
                    or key.endswith(('_QA', '_TEST', '_AUDIT')) or key in ('LEVEL', 'SKIRMISH', 'SKIRMISH_AI',
                    'ARENA', 'CUSTOM_DEFENSE', 'SCENARIO', 'AUTO_MICRO', 'AUTOMICRO'):
                env.pop(key)
        for key in ('APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP'):
            target = profile / key.lower()
            p.need(target.is_dir(), 'Original private directory required')
            env[key] = str(target)
        env.update(STEAM_DISABLED='1', CAMPAIGN_QA='', LSH_CONTINUE_FLOW_QA='1',
                   LSH_CONTINUE_FLOW_PROFILE=str(profile), LSH_LANGUAGE='zh_CN', ART_QA_PROFILE=str(profile),
                   LT_PROFILE=str(profile), LT_PROJECT=str(project), LT_WORKERS=str(workers),
                   LT_BINDINGS=str(workers / 'bindings.json'), LT_BINDINGS_SHA256=p.sha(workers / 'bindings.json'),
                   LT_NONCE=nonce, LT_CANDIDATE_SHA256=manifest_sha,
                   LT_PROVENANCE_SHA256=p.sha(HERE / 'workers/provenance.json'))
        for mode in remaining_modes:
            p.check_pins(pins)
            stage = output / mode
            stage.mkdir()
            report_path = stage / 'report.json'
            process_nonce = uuid.uuid4().hex
            child_env = dict(env, LT_MODE=mode, LT_REPORT=str(report_path), LT_PROCESS_NONCE=process_nonce,
                             LT_PREVIOUS=str(previous), LT_PREVIOUS_SHA256=p.sha(previous))
            try:
                run_stage_when_idle(engine, project, child_env, stage, mode,
                                    receipt['steps'], workers / 'bootstrap.gd')
            finally:
                if report_path.is_file():
                    report = p.read(report_path)
                    receipt['reports'].append({'mode': mode, 'path': str(report_path), 'sha256': p.sha(report_path),
                                               'passed': report.get('passed', False), 'checks': len(report.get('checks', []))})
            report = p.read(report_path)
            step = receipt['steps'][-1]
            p.need(report.get('schema') == 'campaign_lianhuanma_terminal_v2' and report.get('passed') is True
                   and report.get('stage_completed') is True and report.get('failures') == []
                   and report.get('checks') and all(c.get('passed') is True for c in report['checks']), 'Stage incomplete: ' + mode)
            p.need(report.get('mode') == mode and report.get('profile') == str(profile) and report.get('batch_nonce') == nonce
                   and report.get('process_nonce') == process_nonce and report.get('slot_root') == 'user://continue/v1'
                   and report.get('candidate_manifest_sha256') == manifest_sha and report['identity']['content_version'] == identity
                   and report['identity']['engine_sha256'] == cold['engine_sha256'] and report['identity']['source_mode'] is True
                   and report.get('simulation_time_scale') == 1 and report.get('no_gameplay_state_injection') is True
                   and report.get('full_story_required') is True, 'Current private identity and original requirements')
            p.need(all(report.get(k) is False for k in ('public_continue_qualified', 'native_sdk_qualified',
                                                       'native_release_tested', 'human_acceptance')), 'No wider qualification')
            pid = report.get('pid')
            p.need(type(pid) is int and pid > 0 and pid == step['pid'] and pid not in pids and pid != failed_pid
                   and step['passed'] and step['exit_code'] == 0 and not step['errors'], 'Distinct actual current process')
            if mode == 'resume_training':
                p.need(report.get('save_exit_observed') is True and report.get('exit_reason') == 'continue_saved',
                       'Production save/exit required')
            if mode == 'reject_terminal':
                refusal = report.get('observations', {}).get('terminal_refusal', {})
                p.need(refusal.get('ok') is False and refusal.get('code') == 'LOCAL_RUN_TERMINAL', 'Original terminal refusal')
            pids.add(pid)
            previous = report_path
            pins[str(report_path)] = p.sha(report_path)
            pins[str(stage / (mode + '.log'))] = p.sha(stage / (mode + '.log'))
    except BaseException as error:
        receipt['error'] = repr(error)
    finally:
        try:
            p.identity.verify_generated(project, generation)
            p.need(p.identity.snapshot(p.ROOT) == p.read(run / 'root_source.json'), 'Gameplay source changed')
            p.check_pins(pins)
            p.need(p.sha(engine) == cold['engine_sha256'], 'Engine changed')
            receipt['post_source_unchanged'] = True
            wait_idle()
        except BaseException as error:
            receipt['post_error'] = repr(error)
        receipt['lock_released'] = bool(locked and p.common.release_owned_lock(args.lock, output, receipt, p.running()))
        receipt['complete'] = bool(len(pids) == 4 and receipt.get('post_source_unchanged') and receipt['lock_released']
                                   and 'error' not in receipt and 'post_error' not in receipt)
        receipt['source_victory_chain_passed'] = receipt['complete']
        receipt['pins'] = pins
        p.save(output / 'receipt.json', receipt)
    print(json.dumps({'output': str(output), 'complete': receipt['complete'], 'error': receipt.get('error')}, ensure_ascii=False), flush=True)
    p.need(receipt['complete'], 'Current four-process route incomplete')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--batch', type=Path, required=True)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--lock', type=Path, required=True)
    parser.add_argument('--retry-lure-tail', type=Path)
    args = parser.parse_args()
    if args.retry_lure_tail:
        args.retry_lure_tail = args.retry_lure_tail.absolute()
    p.need(args.batch.is_absolute() and args.lock.is_absolute(), 'Absolute batch and lock required')
    execute(args)
