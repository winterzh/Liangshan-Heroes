"""Only the frozen Unit-reference and Inventory QA suites; default is read-only.
--run owns one headless child, a new private profile and the common Godot lock.
No project copy, source editing, import, restore or gameplay acceptance.
"""
import argparse
from collections import Counter
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import types

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SELF = ROOT / 'scratchpad/run_resume_adapters_qa.py'
CONTRACT = SELF.with_suffix('.contract.json')
GUARD = ROOT / 'tools/run_reduced_effects_qa.py'
LIFECYCLE = ROOT / 'scratchpad/run_unit_state_adapter/run_qa.py'
LOCK = ROOT / '.godot/redraw_rejection_source.lock'
SUITES = {'unit-references': 'scratchpad/run_unit_references', 'inventory': 'scratchpad/run_inventory_state'}
REF_DEFERRED = ['_lin_spear_target_id','_aura_atkspeed_sources','_damage_reduction_sources','_charge_hit',
                '_chase_last_id','_giveup_id','battle','map','inventory']
REF_VISUAL = ['_real_frames','_frame_directional','_animated_redraw_t','_queued_redraw_frame','_dust']
KEY_CHECKS = {
    'unit-references': [
        'changed Unit source rejected before explicit property access',
        'actual production Unit remains outside simulation tree',
        'combined 243 native values and 17 reference/order fields validate',
        'fixture retains a truly freed Object Variant',
        'none and truly freed direct reference remain distinct',
        'mine waiter order and duplicate multiplicity retained',
        'passenger order and duplicate multiplicity retained',
        'all seven known order kinds and repeated command order remain exact',
        'capture/validation/codec does not consume gameplay RNG',
        'unregistered live direct target cannot become none or expired',
        'combined capture still enforces frozen value adapter',
        'no restoration, expiration replay or ObjectID gameplay migration claimed'],
    'inventory': [
        'real production HeroInventory instance',
        'all five local declaration fields validated',
        'non-default six-slot positions item counts shared CDs proc CDs and phase captured',
        'real JSON non-default inventory record validated',
        'capture JSON hop and validation consume no gameplay RNG',
        'decoded containers do not alias the live inventory',
        'old snapshot missing periodic phase refused',
        'duplicate local item UID refused',
        'proc-map width rejected before traversal and encoding',
        'expired owner explicitly remains deferred rather than restored or dereferenced',
        'all positive and rejected cases avoid owner or effect callbacks']}


def need(ok, message):
    if not ok: raise RuntimeError(message)


def sha(raw): return hashlib.sha256(raw).hexdigest()
def save(path, value): path.write_bytes((json.dumps(value, ensure_ascii=False, indent=2)+'\n').encode('utf-8'))


def read(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            need(key not in result, 'Duplicate JSON key: '+key)
            result[key] = value
        return result
    raw = path.read_bytes()
    need(len(raw) <= 16*1024*1024, 'Unexpected JSON size: '+str(path))
    return json.loads(raw.decode('utf-8'), object_pairs_hook=unique)


def no_links(path):
    for item in [path]+list(path.parents):
        if item.exists() or item.is_symlink():
            stat = item.lstat()
            need(not item.is_symlink() and not getattr(stat, 'st_file_attributes', 0) & 0x400,
                 'Link/reparse path refused: '+str(item))


def frozen(suite, contract, contract_sha):
    need(suite in SUITES and contract.get('schema') == 1 and set(contract.get('suites',{})) == set(SUITES), 'Unknown controller contract')
    for path in [SELF,CONTRACT,LIFECYCLE]: no_links(path)
    need(sha(CONTRACT.read_bytes()) == contract_sha, 'Controller contract changed')
    need(sha(SELF.read_bytes()) == contract['controller_raw_sha256'], 'Controller changed')
    need(sha(LIFECYCLE.read_bytes()) == contract['lifecycle_raw_sha256'], 'Frozen lifecycle helper changed')
    here = ROOT / SUITES[suite]
    no_links(here)
    pins_path = here/'pins.json'
    no_links(pins_path)
    need(sha(pins_path.read_bytes()) == contract['suites'][suite]['pins_raw_sha256'], 'Suite pins changed')
    pins = read(pins_path)
    need(pins.get('schema') == 1, 'Unknown suite pin schema')
    if suite == 'unit-references':
        expected = {name: row['raw_sha256'] for name,row in pins['source_files'].items()}
        expected.update({SUITES[suite]+'/'+name: row['raw_sha256'] for name,row in pins['draft_files'].items()})
    else:
        expected = {name: row['raw_sha256'] for name,row in pins['runtime_sources'].items()}
        expected.update({SUITES[suite]+'/'+name: row['raw_sha256'] for name,row in pins['support_files'].items()})
    for name, value in expected.items():
        path = ROOT/name
        need(not Path(name).is_absolute() and ROOT in path.resolve().parents, 'Frozen path escapes checkout')
        no_links(path)
        need(path.is_file() and sha(path.read_bytes()) == value, 'Frozen file drift: '+name)
    return pins, expected


def load_snapshot(path, module_name):
    no_links(path)
    raw = path.read_bytes()
    module = types.ModuleType(module_name)
    module.__file__ = str(path)
    exec(compile(raw.decode('utf-8-sig'),str(path),'exec'),module.__dict__)
    return module, sha(raw)


def validate_report(suite, report, execution, process, private_user):
    need(type(report.get('schema')) is int and report['schema'] == 1, 'Wrong report schema')
    need(type(report.get('process_id')) is int and report['process_id'] == process['child_pid'], 'Report PID mismatch')
    need(isinstance(report.get('actual_user_dir'),str) and Path(report['actual_user_dir']).resolve() == private_user.resolve(), 'Actual user:// escaped private profile')
    checks = report.get('checks')
    need(isinstance(checks,list) and 45 <= len(checks) <= 10000 and report.get('passed') is True and report.get('failures') == [], 'Missing or failed checks')
    need(all(isinstance(row,dict) and row.get('passed') is True and isinstance(row.get('label'),str) and row['label'] for row in checks), 'Check rows contradict report')
    labels = Counter(row['label'] for row in checks)
    for label in KEY_CHECKS[suite]: need(labels[label] == 1, 'Incomplete real QA sequence: '+label)
    need(report.get('battle_resume_tested') is False, 'Adapter QA cannot claim battle resume')
    if suite == 'unit-references':
        need(report.get('run_id') == execution['run_id'] and report.get('manifest_sha256') == execution['manifest_sha256'], 'Reference run/manifest mismatch')
        need(report.get('source_sha256') == execution['runtime_sources'], 'Reference runtime source mismatch')
        groups = dict(Counter(row.get('group') for row in checks))
        need(set(groups) <= {'behavior','rejection','json','fixture','source','environment'} and report.get('check_groups') == groups, 'Reference check groups disagree')
        coverage = report.get('coverage',{})
        for key, value in {'declared_fields':272,'captured_declared_values':241,'direct_reference_fields':14,
                           'ordered_reference_arrays':2,'known_order_queue_fields':1,'combined_declared_fields':258}.items():
            need(type(coverage.get(key)) is int and coverage[key] == value, 'Reference coverage changed: '+key)
        need(coverage.get('inherited_values') == ['position','modulate'], 'Inherited value scope changed')
        need(coverage.get('deferred_fields') == REF_DEFERRED and coverage.get('omitted_visual_fields') == REF_VISUAL, 'Deferred/visual fields changed')
        need(coverage.get('references_transport_only') is True, 'Reference transport boundary missing')
        for key in ['restore_ready','graph_validated','metadata_capture_implemented','business_definition_validated',
                    'stable_id_gameplay_migrated','expired_restore_policy_implemented']:
            need(coverage.get(key) is False, 'Unsupported reference scope marked complete: '+key)
        need(report.get('restore_ready') is False and report.get('cross_process_id_continuity_tested') is False, 'False restore/cross-process claim')
        source_checks = sum(row['label'].startswith(('runtime source ','source unchanged ')) for row in checks)
        need(source_checks == 12, 'Expected six source hashes before and after')
    else:
        need(report.get('source_raw_sha256') == execution['runtime_sources'], 'Inventory runtime source mismatch')
        need(type(report.get('check_count')) is int and report['check_count'] == len(checks), 'Inventory check_count mismatch')
        for key in ['real_inventory_object','capture_validate_only','owner_is_test_probe']:
            need(report.get(key) is True, 'Inventory evidence scope missing: '+key)
        for key in ['assignment_restore_implemented','business_definitions_validated','global_item_uid_allocator_restored']:
            need(report.get(key) is False, 'Unsupported Inventory scope marked complete: '+key)
        engine = report.get('engine',{})
        need(isinstance(engine,dict) and all(type(engine.get(key)) is int for key in ['major','minor','patch']) and engine['major'] == 4, 'Missing actual Godot version report')
        source_checks = sum(row['label'].startswith('source raw SHA exists: ') for row in checks)
        need(source_checks == 10 and labels['five runtime source files unchanged'] == 1, 'Expected five source hashes before and after')
    return {'checks':len(checks),'source_hash_checks':source_checks,'other_checks':len(checks)-source_checks,
            'check_groups':report.get('check_groups'),'key_functional_checks':len(KEY_CHECKS[suite])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite',required=True,choices=SUITES)
    parser.add_argument('--run',action='store_true')
    parser.add_argument('--godot')
    parser.add_argument('--timeout',type=int,default=120)
    args = parser.parse_args()
    need(30 <= args.timeout <= 240, 'Timeout must be 30..240 seconds')
    contract = read(CONTRACT)
    contract_sha = sha(CONTRACT.read_bytes())
    pins, expected = frozen(args.suite,contract,contract_sha)
    if not args.run:
        print(json.dumps({'suite':args.suite,'preflight':True,'frozen_files':len(expected),'godot_run':False,'project_copy':False,'writes':False}))
        return 0
    guard, guard_sha = load_snapshot(GUARD,'resume_adapters_public_guard')
    lifecycle, lifecycle_sha = load_snapshot(LIFECYCLE,'resume_adapters_frozen_lifecycle')
    need(lifecycle_sha == contract['lifecycle_raw_sha256'], 'Lifecycle changed while loading')
    lifecycle.SCRIPT = SUITES[args.suite]+'/qa_driver.gd'  # In-memory selector; frozen file untouched.
    need(lifecycle.ROOT == ROOT, 'Lifecycle checkout mismatch')
    exe = Path(guard.resolve_godot(args.godot))
    need(exe.suffix.lower() == '.exe' and not re.search(r'[._-]console\.exe$',exe.name,re.I), 'Actual non-console exe required')
    no_links(exe)
    guard.require_exclusive_godot()
    need(not LOCK.exists(), 'Shared Godot slot occupied')
    name = guard.project_name(ROOT)
    real_user = Path(os.environ['APPDATA'])/'Godot/app_userdata'/name
    no_links(real_user)
    protected = guard.signatures(real_user)
    here = ROOT/SUITES[args.suite]
    no_links(here/'runs')
    no_links(LOCK)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out = here/'runs'/stamp
    out.mkdir(parents=True,exist_ok=False)
    no_links(out)
    LOCK.parent.mkdir(exist_ok=True)
    token = str(os.getpid())+'|'+str(out)
    result = {'schema':1,'suite':args.suite,'complete':False,'lock_released':False,'godot_run':False,
              'source_mutations':False,'project_copy':False,'restore_ready':False,'protected_player_before':protected,
              'controller_contract':contract,'controller_contract_raw_sha256':contract_sha,'suite_pins':pins,
              'lifecycle_raw_sha256':lifecycle_sha,'engine_raw_sha256':sha(exe.read_bytes())}
    with LOCK.open('x',encoding='utf-8') as file: file.write(token)
    source = None
    try:
        guard.require_exclusive_godot()
        frozen(args.suite,contract,contract_sha)
        source = guard.source_receipt(ROOT)
        need(source['raw_file_sha256']['tools/run_reduced_effects_qa.py'] == guard_sha, 'Public guard changed while loading')
        save(out/'sources.json',source)
        profile = out/'private_profile'
        user = profile/'appdata/Godot/app_userdata'/name
        user.mkdir(parents=True,exist_ok=False)
        (profile/'localappdata').mkdir()
        (profile/'temp').mkdir()
        env, controls = guard.environment(source,out,profile,user)
        for key in list(env):
            if key.startswith(('UNIT_ADAPTER_','UNIT_REFERENCES_','INVENTORY_QA_','ANIM_LOAD_','FIRST_USE_',
                               'VALUE_CODEC_','STORE_QA_','REDRAW_','SEPARATION_','REDUCED_EFFECTS_')): env.pop(key)
        env.update(APPDATA=str(profile/'appdata'),LOCALAPPDATA=str(profile/'localappdata'),TEMP=str(profile/'temp'),TMP=str(profile/'temp'))
        if args.suite == 'unit-references':
            runtime = {key:expected[key] for key in ['project.godot','scripts/unit.gd','scripts/run_state_value_codec.gd',
                       'scratchpad/run_unit_state_adapter/unit_values.gd',SUITES[args.suite]+'/unit_references.gd',lifecycle.SCRIPT]}
            report_path = out/'report.json'
            manifest = {'schema':1,'run_id':stamp,'run_dir':str(out),'private_user':str(user),'report':str(report_path),'source_sha256':runtime}
        else:
            runtime = {key:row['raw_sha256'] for key,row in pins['runtime_sources'].items()}
            report_path = user/'inventory_report.json'
            manifest = {'schema':1,'suite':args.suite,'run_id':stamp,'private_user':str(user),'report':str(report_path),'runtime_sources':runtime}
        need(not report_path.exists(), 'Report must be new')
        manifest_path = out/'manifest.json'
        save(manifest_path,manifest)
        manifest_sha = sha(manifest_path.read_bytes())
        if args.suite == 'unit-references': env['UNIT_REFERENCES_QA_MANIFEST'] = str(manifest_path)
        else: env.update(INVENTORY_QA_EXPECTED_USER_DIR=str(user),INVENTORY_QA_OUT=str(report_path))
        execution = {'suite':args.suite,'run_id':stamp,'source_project':str(ROOT),'private_profile':str(profile),'private_user':str(user),
                     'report':str(report_path),'temp':str(profile/'temp'),'controlled_production_switches':controls,
                     'manifest_sha256':manifest_sha,'runtime_sources':runtime,'read_only_source_root':True}
        save(out/'configuration.json',execution)
        need(guard.signatures(real_user) == protected, 'Player files changed before launch')
        process = lifecycle.run_process(guard,exe,out,env,args.timeout)
        need(sha(manifest_path.read_bytes()) == manifest_sha, 'Execution manifest changed')
        no_links(report_path)
        report = read(report_path)
        counts = validate_report(args.suite,report,execution,process,user)
        frozen(args.suite,contract,contract_sha)
        need(guard.source_receipt(ROOT) == source, 'Root source paths/bytes changed')
        need(guard.signatures(real_user) == protected, 'Real player files changed')
        result.update(complete=True,process_id=process['child_pid'],exit_code=process['exit_code'],
                      source_combined_sha256=source['combined_sha256'],source_files=len(source['raw_file_sha256']),
                      report_path=str(report_path),report_raw_sha256=sha(report_path.read_bytes()),manifest_raw_sha256=manifest_sha,**counts)
    except BaseException as error:
        result['error'] = type(error).__name__+': '+str(error)
        raise
    finally:
        try:
            process_path = out/'process_receipt.json'
            if process_path.exists():
                process = read(process_path)
                # Recontextualize only this new controller-owned receipt. The
                # helper's code, exit handling and old receipts remain intact.
                process['lifecycle_original_scope'] = process['scope']
                process['scope'] = args.suite+' capture/validate QA; no gameplay restore'
                process['lifecycle_raw_sha256'] = lifecycle_sha
                save(process_path,process)
                result['godot_run'] = process.get('child_pid') is not None
            guard.require_exclusive_godot()
            frozen(args.suite,contract,contract_sha)
            need(source is not None and guard.source_receipt(ROOT) == source, 'Source verification failed; retain lock')
            need(guard.signatures(real_user) == protected, 'Protected player files drifted; retain lock')
            need(LOCK.read_text(encoding='utf-8') == token, 'Shared lock ownership changed')
            result['source_unchanged'] = True
            result['protected_player_after'] = guard.signatures(real_user)
            LOCK.unlink()
            result['lock_released'] = True
        except BaseException as error:
            result.update(complete=False,final_guard_error=type(error).__name__+': '+str(error))
        save(out/'receipt.json',result)
        print(json.dumps({'suite':args.suite,'run':str(out),'complete':result['complete'],'lock_released':result['lock_released']}))
    return 0 if result['complete'] and result['lock_released'] else 2


if __name__ == '__main__': sys.exit(main())
