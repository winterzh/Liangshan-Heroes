"""Two short native windows, one unchanged driver and private user profiles; no source swaps."""
from pathlib import Path
import argparse
import datetime
import hashlib
import importlib.util
import json
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
HERE = ROOT / 'scratchpad/animation_load_candidate'
LOCK = ROOT / '.godot/redraw_rejection_source.lock'


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--driver-sha256', required=True)
    parser.add_argument('--helper-sha256', required=True)
    args = parser.parse_args()
    guard = module(ROOT / 'tools/run_reduced_effects_qa.py', 'animation_guard')
    baseline = module(ROOT / 'tools/run_polish_performance.py', 'animation_baseline')
    tools = {'driver.gd': args.driver_sha256, 'candidate_helper.gd': args.helper_sha256}
    for name, pin in tools.items():
        assert guard.sha((HERE / name).read_bytes()) == pin
    exe = Path(args.godot).resolve()
    assert exe.is_file() and not re.search(r'[._-]console\.exe$', exe.name, re.I)
    guard.require_exclusive_godot()
    assert not LOCK.exists()
    source = guard.source_receipt()
    name = guard.project_name()
    real_user = Path(os.environ['APPDATA']) / 'Godot/app_userdata' / name
    protected = guard.signatures(real_user)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out = HERE / 'runs' / stamp
    out.mkdir(parents=True, exist_ok=False)
    guard.save(out / 'sources.json', source)
    result = {'complete': False, 'lock_released': False, 'source_sha256': source['combined_sha256'],
              'source_files': len(source['raw_file_sha256']), 'tool_pins': tools,
              'git_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'engine_sha256': guard.sha(exe.read_bytes()), 'requested_seconds': 10,
              'performance_acceptance': False, 'production_hook_installed': False,
              'protected_player_before': protected, 'samples': []}
    token = str(os.getpid()) + '|' + str(out)
    with LOCK.open('x', encoding='utf-8') as stream:
        stream.write(token)
    print('OUTPUT ' + str(out), flush=True)
    try:
        for mode in ('none', 'current_units'):
            assert guard.source_receipt() == source
            for file_name, pin in tools.items():
                assert guard.sha((HERE / file_name).read_bytes()) == pin
            stage = out / mode
            stage.mkdir()
            profile = stage / 'private_profile'
            user = profile / 'appdata/Godot/app_userdata' / name
            user.mkdir(parents=True)
            (profile / 'localappdata').mkdir()
            env, controls = baseline.environment()
            for key in list(env):
                if key.startswith(('ANIM_LOAD_', 'FIRST_USE_', 'REDUCED_EFFECTS_', 'VALUE_CODEC_')):
                    env.pop(key)
            env.update(APPDATA=str(profile / 'appdata'), LOCALAPPDATA=str(profile / 'localappdata'),
                       ANIM_LOAD_MODE=mode, ANIM_LOAD_OUT=str(stage / 'preparation.json'),
                       ANIM_LOAD_USER_ROOT=str(profile))
            guard.save(stage / 'configuration.json', {'mode': mode, 'profile': str(profile), 'controls': controls})
            process = guard.run_process(str(exe), ROOT, stage / 'process.log', env, 210,
                                        script='scratchpad/animation_load_candidate/driver.gd')
            guard.save(stage / 'process_receipt.json', process)
            log = (stage / 'process.log').read_text(encoding='utf-8', errors='replace')
            assert not re.search(r'Unicode parsing error|Parse Error', log)
            report = json.loads((stage / 'm1_10s.json').read_bytes())
            preparation = json.loads((stage / 'preparation.json').read_bytes())
            assert report['integrity_passed'] and report['sample_complete'] and report['effects_quality_verified']
            assert report['effects_quality'] == 'standard' and not report['acceptance_eligible']
            assert preparation['valid'] and preparation['completed_plan'] and preparation['observed_state_equal']
            assert preparation['mode'] == mode and preparation['measurement_finished']
            assert preparation['process_id'] == process['child_pid']
            assert preparation['source_sha256_before'] == preparation['source_sha256_after_preparation'] == preparation['source_sha256_after_measurement']
            for path, digest in preparation['source_sha256_before'].items():
                assert path.startswith('res://') and guard.sha((ROOT / path[6:]).read_bytes()) == digest
            assert preparation['existing_unit_ids_before'] == preparation['existing_unit_ids_after']
            assert Path(preparation['actual_user_dir']).resolve() == user.resolve()
            assert guard.source_receipt() == source and guard.signatures(real_user) == protected
            row = {key: report[key] for key in ('fps', 'p95_ms', 'p99_ms', 'physics_ticks', 'integrity_passed', 'sample_complete')}
            row.update(mode=mode, prepare_wall_us=preparation['prepare_wall_us'],
                       api_calls=preparation['api_calls'], texture_bytes_delta=preparation['texture_bytes_delta'],
                       initial_deployment_sha256=guard.sha(json.dumps(report['initial_units'], sort_keys=True).encode()),
                       input_sha256=guard.sha(json.dumps(report['inputs'], sort_keys=True).encode()))
            result['samples'].append(row)
            guard.save(out / 'running_receipt.json', result)
            print(json.dumps(row), flush=True)
        assert len({row['initial_deployment_sha256'] for row in result['samples']}) == 1
        assert len({row['input_sha256'] for row in result['samples']}) == 1
        result['complete'] = True
    except BaseException as error:
        result['error'] = type(error).__name__ + ': ' + str(error)
        raise
    finally:
        try:
            guard.require_exclusive_godot()
            assert guard.source_receipt() == source
            assert all(guard.sha((HERE / file_name).read_bytes()) == pin for file_name, pin in tools.items())
            assert guard.signatures(real_user) == protected
            assert LOCK.read_text() == token
            result['source_unchanged'] = True
            result['protected_player_after'] = guard.signatures(real_user)
            LOCK.unlink()
            result['lock_released'] = True
        except BaseException as error:
            result.update(complete=False, final_guard_error=str(error))
        guard.save(out / 'receipt.json', result)
        print(json.dumps({'run': str(out), 'complete': result['complete'], 'lock_released': result['lock_released']}))


if __name__ == '__main__':
    main()
