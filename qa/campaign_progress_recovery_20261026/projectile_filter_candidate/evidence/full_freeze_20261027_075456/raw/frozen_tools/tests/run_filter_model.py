"""Named-input native component model; default reads small pins only, --run owns one engine.

Uses the existing imported 3365 project plus an external candidate Graph. Does
not certify a combined freeze, gameplay, profile business state, or full source.
"""
from __future__ import annotations
import argparse, importlib.util, json, os, sys, time, traceback, uuid
from pathlib import Path
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
CANDIDATE = HERE.parent
ROOT = CANDIDATE.parents[2]
BASE = ROOT / '.godot/campaign_progress_recovery_20261026/20261027_063133_392242bc'
BASE_IDENTITY = 'source-v1:3365e369ba351e9d9593d2324391c7b042a967144df85f1c35f7cb9aad932539'
HELPER = ROOT / 'qa/campaign_progress_recovery_20261026/daming_continue_candidate/integration_941/prepare_daming.py'
spec = importlib.util.spec_from_file_location('projectile_component_helpers', HELPER)
helpers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helpers)
p, h, require = helpers.p, helpers.h, helpers.require

def light():
    manifest = h.read(p.fs(CANDIDATE / 'source_manifest.json'))
    sources = h.read(p.fs(CANDIDATE / 'sources.json'))
    require(manifest.get('schema') == 'projectile_filter_overlay_v1' and manifest.get('base_identity') == BASE_IDENTITY,
            'Exact component overlay contract required')
    require(sources.get('schema') == 'projectile_filter_candidate_sources_v1', 'Exact source registry required')
    pins = {}
    for row in sources['sources']:
        path = (ROOT / row['path']).resolve()
        require(path.is_relative_to(ROOT), 'Source path escaped ROOT')
        p.pin(path, pins, row['sha256'])
    for path in [CANDIDATE / 'sources.json', CANDIDATE / 'source_manifest.json', HELPER,
                 Path(h.__file__), Path(h.common.__file__), Path(h.shared.__file__), Path(h.identity.__file__)]:
        p.pin(path, pins)
    row = manifest['files'][0]
    require(len(manifest['files']) == 1 and row['path'] == 'scripts/run_visual_graph.gd', 'Only one Graph overlay')
    require(pins[str(BASE / 'project' / row['path'])] == row['base_sha256']
            and pins[str(CANDIDATE / row['path'])] == row['candidate_sha256'], 'Base/candidate Graph pins differ')
    for item in manifest['support_files']:
        path = (CANDIDATE / item['path']).resolve()
        require(path.is_relative_to(CANDIDATE), 'Support escaped candidate')
        p.pin(path, pins, item['sha256'])
    generation = h.read(p.fs(BASE / 'generation.json'))
    require('source-v1:' + generation['identity']['source_sha256'] == BASE_IDENTITY, 'Recorded generation identity mismatch')
    index = {row['path']: row for row in generation['identity']['files']}
    for path, digest in pins.items():
        named = Path(path)
        if named.is_relative_to(BASE / 'project'):
            key = named.relative_to(BASE / 'project').as_posix()
            require(key in index and index[key]['sha256'] == digest and index[key]['bytes'] == p.fs(named).stat().st_size, 'Named input differs from frozen generation: ' + key)
    p.verify_pins(pins)
    return manifest, pins

def save_receipt(output, receipt):
    h.save(p.fs(output / 'receipt.json'), receipt)

def execute(args):
    manifest, pins = light()
    project = BASE / 'project'
    imports = [p for p in BASE.glob('import__*/receipt.json') if h.read(p).get('complete') is True]
    require(len(imports) == 1, 'One successful existing independent 3365 import receipt required')
    imported = h.read(p.fs(imports[0]))
    # Native import metadata is evidence of the existing project, not a new full-source check.
    generation = h.read(p.fs(BASE / 'generation.json'))
    require('source-v1:' + generation['identity']['source_sha256'] == BASE_IDENTITY, 'Unexpected recorded base identity')
    require(imported.get('phase') == 'import' and imported.get('lock_released') is True
            and imported.get('project') == str(project) and len(imported.get('steps', [])) == 1, 'Existing import scope mismatch')
    import_step = imported['steps'][0]
    require(import_step.get('exit_code') == 0 and import_step.get('errors') == [] and import_step.get('stopped_for') is None, 'Existing native import failed')
    engine = Path(import_step['command'][0])
    expected_engine = imported['engine_sha256']
    require(h.sha(p.fs(engine)) == expected_engine, 'Exact native engine bytes required')
    p.pin(imports[0], pins)
    p.pin(engine, pins, expected_engine)
    output = ROOT / '.godot/projectile_filter_component_20261027' / h.stamp()
    p.fs(output).mkdir(parents=True, exist_ok=False)
    owner = str(output)
    receipt = {'schema':'projectile_filter_component_host_v1','complete':False,'steps':[],
               'named_inputs_only':True,'full_source_qualified':False,'combined_freeze_qualified':False,
               'native_gameplay_qualified':False,'baseline_run':str(BASE),'base_recorded_identity':BASE_IDENTITY,
               'candidate_sha256':manifest['files'][0]['candidate_sha256'],'errors':[],'cleanup_errors':[]}
    locked = False
    attempted = False
    try:
        end = time.monotonic() + args.wait_lane
        while p.fs(h.shared.LOCK).exists() or h.running():
            require(time.monotonic() < end, 'Engine lane occupied; model did not start')
            time.sleep(min(1, max(0.01, end-time.monotonic())))
        p.fs(h.shared.LOCK).parent.mkdir(parents=True, exist_ok=True)
        with p.fs(h.shared.LOCK).open('x', encoding='utf-8') as f: f.write(owner)
        locked = True
        require(not h.running(), 'Engine appeared after owned lock')
        workers = output / 'workers'; p.fs(workers).mkdir()
        copies = [(HERE/'bootstrap.gd','bootstrap.gd'),(HERE/'worker.gd','worker.gd'),
                  (CANDIDATE/'scripts/run_visual_graph.gd','candidate_graph.gd')]
        for original, name in copies:
            p.copy(original, workers/name, pins[str(original)]);p.pin(workers/name,pins)
        frozen = output/'runner_inputs';p.fs(frozen).mkdir()
        for original in [Path(__file__).resolve(), CANDIDATE/'README.md', CANDIDATE/'minimal.diff',
                         CANDIDATE/'sources.json', CANDIDATE/'source_manifest.json']:
            p.copy(original,frozen/original.name,pins[str(original)]);p.pin(frozen/original.name,pins)
        profile = Path('D:/CodexQA/projectilefilter')/uuid.uuid4().hex[:12]
        h.identity.no_links(profile);p.fs(profile).mkdir(parents=True,exist_ok=False)
        env = h.common.private_environment(profile)
        for key in list(env):
            if key.startswith(('PF_','DF_','GVT_','GLS_','GT_','LL_','LT_','LSH_CONTINUE_FLOW_',
                               'CB_','CC_','CT_','SC_','CR_','HG_','LHMR_','MR_','LR_','RS_')): env.pop(key)
        nonce = uuid.uuid4().hex
        bindings = output/'bindings.json'
        h.save(p.fs(bindings),{'schema':'projectile_filter_bindings_v1','nonce':nonce,'project':str(project),
            'profile':str(profile),'base_recorded_identity':BASE_IDENTITY,'engine_sha256':expected_engine,
            'candidate_sha256':manifest['files'][0]['candidate_sha256'],'named_pins':dict(pins)})
        p.pin(bindings,pins)
        report_path=output/'report.json'
        env.update(STEAM_DISABLED='1',CAMPAIGN_QA='',LSH_CONTINUE_FLOW_QA='',LSH_LANGUAGE='zh_CN',
            PF_WORKER=str(workers/'worker.gd'),PF_WORKER_SHA=pins[str(workers/'worker.gd')],
            PF_CANDIDATE=str(workers/'candidate_graph.gd'),PF_CANDIDATE_SHA=pins[str(workers/'candidate_graph.gd')],
            PF_NONCE=nonce,PF_PROFILE=str(profile),PF_REPORT=str(report_path),PF_BINDINGS=str(bindings),PF_BINDINGS_SHA=pins[str(bindings)])
        receipt.update(profile=str(profile),nonce=nonce,engine=str(engine),engine_sha256=expected_engine,
                       bindings=str(bindings),bindings_sha256=pins[str(bindings)])
        p.verify_pins(pins)
        attempted=True
        try:
            h.common.process_step(engine,project,env,p.fs(output),'component',
                ['--headless','--script',str(workers/'bootstrap.gd')],args.timeout,'gl_compatibility',h.running,receipt['steps'])
        finally:
            for path in [report_path,output/'component.log']:
                if p.fs(path).is_file(): p.pin(path,pins)
        require(len(receipt['steps'])==1,'Exactly one native owned process required')
        step=receipt['steps'][0];report=h.read(p.fs(report_path))
        require(step['exit_code']==0 and not step['errors'] and step.get('stopped_for') is None,'Native process failed')
        require(report.get('schema')=='projectile_filter_component_v1' and report.get('pid')==step['pid']
                and report.get('nonce')==nonce and report.get('profile')==str(profile)
                and report.get('candidate_sha256')==manifest['files'][0]['candidate_sha256']
                and report.get('bindings_sha256')==pins[str(bindings)],'Native report binding mismatch')
        require(report.get('passed') is True and not report.get('failures') and report.get('checks')
                and all(row.get('passed') is True for row in report['checks']), 'Component assertions failed')
        require(report.get('synthetic_fixture') is True and report.get('gameplay_state_modified') is False
                and report.get('native_gameplay_qualified') is False and report.get('public_continue_qualified') is False
                and report.get('sdk_qualified') is False,'Qualification boundary mismatch')
        require(report['observations'].get('roundtrip_exact') is True and len(report['negative_cases'])==12
                and all(row.get('passed') is True for row in report['negative_cases']), 'Roundtrip/negative matrix incomplete')
        user_data = Path(report['user_data_dir']).resolve()
        require(user_data.is_relative_to(profile.resolve()), 'Actual user data escaped isolated profile')
        h.identity.no_links(user_data)
        for name in ['continue','steam_receipts','campaign.cfg','campaign_cfg_candidates','campaign_cfg_transactions']:
            require(not p.fs(user_data/name).exists(), 'Component produced business state: ' + name)
        receipt['business_paths_absent_after_exit'] = True
        receipt.update(component_passed=True,report=str(report_path),report_sha256=pins[str(report_path)],
                       checks=len(report['checks']),negative_cases=12)
    except BaseException as error:
        receipt['errors'].append({'error':repr(error),'traceback':traceback.format_exc()})
    finally:
        try:
            p.verify_pins(pins)
            require(h.sha(p.fs(engine))==expected_engine,'Engine bytes changed')
            receipt['named_inputs_unchanged']=True
        except BaseException as error:
            receipt['cleanup_errors'].append({'phase':'named_inputs','error':repr(error)})
        terminal = (not attempted) or (len(receipt['steps'])==1 and type(receipt['steps'][0].get('pid')) is int
                    and type(receipt['steps'][0].get('exit_code')) is int)
        receipt.update(child_terminal=terminal,lock_ownership_confirmed=False,engine_lane_idle=False,lock_released=False)
        try:
            receipt['lock_ownership_confirmed']=bool(locked and p.fs(h.shared.LOCK).is_file()
                and p.fs(h.shared.LOCK).read_text(encoding='utf-8')==owner)
            receipt['engine_lane_idle']=not h.running()
            if receipt['lock_ownership_confirmed'] and terminal and receipt['engine_lane_idle']:
                p.fs(h.shared.LOCK).unlink();receipt['lock_released']=not p.fs(h.shared.LOCK).exists()
        except BaseException as error:
            receipt['cleanup_errors'].append({'phase':'owned_terminal_lock','error':repr(error)})
        receipt['complete']=bool(receipt.get('component_passed') and receipt.get('named_inputs_unchanged')
            and terminal and receipt['lock_ownership_confirmed'] and receipt['engine_lane_idle'] and receipt['lock_released']
            and not receipt['errors'] and not receipt['cleanup_errors'])
        receipt['pinned_files']=pins
        save_receipt(output,receipt)
    print(json.dumps({'output':str(output),'complete':receipt['complete'],'errors':receipt['errors'],
                     'lock_released':receipt['lock_released']},ensure_ascii=False),flush=True)
    if not receipt['complete']: raise SystemExit(1)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',action='store_true',help='Explicitly execute one isolated native component process')
    parser.add_argument('--timeout',type=int,default=300)
    parser.add_argument('--wait-lane',type=int,default=0)
    args=parser.parse_args()
    if args.timeout<30 or args.timeout>600 or args.wait_lane<0: parser.error('Invalid bounded deadline')
    if args.run: execute(args)
    else:
        manifest,pins=light()
        print(json.dumps({'validation_level':'named_inputs_only','engine_started':False,'full_source_qualified':False,
                          'pins':len(pins),'candidate_sha256':manifest['files'][0]['candidate_sha256']},ensure_ascii=False))
if __name__=='__main__':main()
