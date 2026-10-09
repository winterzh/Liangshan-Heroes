"""Consume the owned cloud-write failure boundary with linked journal pairs; no launcher.

This does not qualify authorized account retry, restart, the original19 case,
or player UI. Native canonical CFG text is never reconstructed on the host.
"""
import hashlib
from pathlib import Path
import re
import subprocess

from campaign_callback_controller_v3 import expected_native_identity
from campaign_callback_packets_v2 import json_value, same
from campaign_cloud_cfg_physical_v2 import original_copy, strict_journal
from campaign_cloud_cfg_semantics_v2 import DATA_TYPES, TARGET_TYPES
from campaign_cloud_restart_exports_v1 import CallbackNativeExports
from campaign_file_fault_evidence_v2 import labels
from campaign_file_fault_records_v1 import hex_value, ZERO
from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import OwnedSerialBatch, no_links, sha

CASE = 'legacy_real_cloud_apply_failure_boundary'
SCOPE = 'SDK-disabled real storage failure and refused-account retry boundary only'
REPORT_FIELDS = {'schema','passed','checks','failures','observations','pid','nonce','mode','case','identity',
                 'user_directory','time_scale','physics_ticks','failure_evidence','scope',
                 'successful_authorized_same_writer_retry_required','successful_authorized_same_writer_retry_qualified',
                 'restart_qualified','Steam_account_qualified','upload_qualified','SDK_reward_once_qualified',
                 'original19_faults_qualified','pending_failure_UI_qualified','overall_goal_qualified'}
EVIDENCE_FIELDS = {'campaign_id','cloud_id','writer_id','proposal_id','original_memory','original_cloud',
                   'original_shared_pending','original_cfg_sha256','blocker_sha256','apply_returned','writer_error',
                   'retry_error','writer_scope','writer_active','writer_pending_record','proposal_semantics',
                   'final_memory','final_cloud','final_shared_pending','final_cfg_sha256',
                   'same_pending_writer_retained','real_fault_repaired','successful_authorized_retry'}
SHARED_FIELDS = {'profile','source_profile','identity','kind','phase','original_owner','binding_sha',
                 'marker_owner','confirmation','current_owner'}
WRITER_SCOPE_FIELDS = {'operation','run_token','intent_sha256','target_owner','content_version','engine_sha256'}
ACTIVE_FIELDS = {'request','original_sha256','original_owner','transaction','stage','semantics_sha256'}

def native_object_id(value):
    # RefCounted ObjectID uses the high bit; its native signed int may be negative.
    return type(value) is int and -(1 << 63) <= value < (1 << 63) and value != 0

def failure_structure(value,identity,runtime_fields):
    """Pure untrusted-report shape check. It never proves Popen or native success."""
    require(type(value) is dict and set(value) == EVIDENCE_FIELDS, 'Whole failure evidence fields')
    require(all(native_object_id(value[k]) for k in ['campaign_id','cloud_id','writer_id','proposal_id'])
            and value['campaign_id'] > 0 and value['cloud_id'] > 0
            and len({value[k] for k in ['campaign_id','cloud_id','writer_id','proposal_id']}) == 4,
            'Distinct native Node and signed RefCounted identifiers')
    require(same(value['original_memory'],{'records':{},'unlocked':1,'owner':''})
            and same(value['original_memory'],value['final_memory']), 'Original fresh Campaign memory never published')
    flags = value['original_cloud']
    require(type(flags) is dict and set(flags) == {'dirty','pending_upload','revision'}
            and type(flags['dirty']) is bool and type(flags['pending_upload']) is bool
            and type(flags['revision']) is int and flags['revision'] >= 0
            and same(flags,value['final_cloud']), 'Original typed cloud flags retained')
    require(type(value['original_cfg_sha256']) is str
            and (value['original_cfg_sha256'] == '' or hex_value(value['original_cfg_sha256']))
            and value['final_cfg_sha256'] == value['original_cfg_sha256']
            and hex_value(value['blocker_sha256']) and value['apply_returned'] is False
            and value['writer_error'] == 'CFG_STAGE_PARENT'
            and same(value['retry_error'],{'ok':False,'code':'CLOUD_RETRY_SCOPE_CHANGED','config_pending':True})
            and value['same_pending_writer_retained'] is True and value['real_fault_repaired'] is True
            and value['successful_authorized_retry'] is False, 'Exact actual failure, refusal and limited outcome')
    scope = value['writer_scope']
    require(type(scope) is dict and set(scope) == WRITER_SCOPE_FIELDS
            and all(type(v) is str for v in scope.values())
            and scope == {'operation':'cloud','run_token':'','intent_sha256':'','target_owner':'1',
                          'content_version':runtime_fields['content_version'],
                          'engine_sha256':runtime_fields['engine_binary_sha256']}, 'Complete retained installed cloud writer scope')
    active = value['writer_active']
    require(type(active) is dict and set(active) == ACTIVE_FIELDS and same(active['request'],scope)
            and active['original_sha256'] == (value['original_cfg_sha256'] or ZERO)
            and active['original_owner'] == '' and active['stage'] == 'staging'
            and hex_value(active['transaction'],32) and hex_value(active['semantics_sha256'])
            and same(value['writer_pending_record'],{}), 'Original pre-journal staging operation and pending-record boundary')
    semantics = value['proposal_semantics']
    require(type(semantics) is dict and set(semantics) == {'ok','sections'} and semantics['ok'] is True
            and type(semantics['sections']) is dict, 'Whole native frozen proposal semantics')
    for section,keys in semantics['sections'].items():
        require(type(section) is str and type(keys) is dict, 'Native proposal section map')
        for key,row in keys.items():
            require(type(key) is str and type(row) is dict and set(row) == {'variant_type','canonical'}
                    and type(row['variant_type']) is int and row['variant_type'] in DATA_TYPES
                    and type(row['canonical']) is str and row['canonical'], 'Typed opaque native canonical probe text')
    progress = semantics['sections'].get('progress')
    require(type(progress) is dict and set(TARGET_TYPES) <= set(progress)
            and all(progress[k]['variant_type'] == kind for k,kind in TARGET_TYPES.items()),
            'Four target progress values have actual native Variant types')
    shared = value['original_shared_pending']
    require(type(shared) is dict and set(shared) == SHARED_FIELDS and same(shared,value['final_shared_pending'])
            and same(shared['identity'],identity) and shared['kind'] == shared['phase'] == 'apply'
            and shared['current_owner'] == '1' and shared['original_owner'] == ''
            and shared['marker_owner'] == '' and same(shared['confirmation'],{})
            and type(shared['binding_sha']) is str and (shared['binding_sha'] == '' or hex_value(shared['binding_sha'])),
            'Whole original shared source, identity and binding snapshot unchanged')
    for name in ['profile','source_profile']:
        payload = shared[name]
        require(type(payload) is dict and payload.get('owner') == '1' and type(payload.get('schema')) is int
                and payload['schema'] == 1 and type(payload.get('updated_at')) is int
                and 0 <= payload['updated_at'] <= 9007199254740991
                and type(payload.get('settings_text')) is str and type(payload.get('language_text')) is str
                and same(payload.get('campaign'),{'schema':2,'unlocked':2,'records':{}}), 'Original bounded synthetic cloud input')
    require(same(shared['profile'],shared['source_profile']), 'Empty-record merge preserves this original local payload')
    return {'structural_contract_verified':True,'native_execution_proven':False,
            'native_canonical_SHA_reconstructed':False,'full_case_qualified':False}

def retained_cfg_links(retained, current_cfg_sha256):
    """Link already decoded original journal pairs to the current physical CFG.

    The first pruned ancestor and a preapply host snapshot stay unproved.
    This pure data check does not itself establish original byte custody.
    """
    require(type(retained) is list and len(retained) in [0,2,4], 'Whole retained complete journal pairs')
    require(type(current_cfg_sha256) is str and (current_cfg_sha256 == '' or hex_value(current_cfg_sha256)),
            'Actual current CFG hash or strictly absent file')
    prior_transaction = None
    for index in range(0,len(retained),2):
        prepared,applied = retained[index]['document'],retained[index+1]['document']
        require(prepared['state'] == 'prepared' and applied['state'] == 'applied'
                and type(prepared['generation']) is int and type(applied['generation']) is int
                and prepared['generation'] % 2 == 1 and applied['generation'] == prepared['generation']+1
                and set(prepared) == set(applied)
                and all(same(prepared[key],applied[key]) for key in prepared if key not in ['generation','state']),
                'Every actual prepared/applied pair preserves the whole proposal')
        require(prior_transaction is None or prepared['transaction'] != prior_transaction,
                'Subsequent original transaction is distinct from the previous applied transaction')
        prior_transaction = applied['transaction']
    if retained:
        require(current_cfg_sha256 and retained[-1]['document']['candidate_sha256'] == current_cfg_sha256,
                'Final retained applied proposal binds the actual unchanged physical CFG')
    return {'retained_pair_proposals_verified':True,'last_applied_physical_CFG_verified':bool(retained),
            'pruned_ancestor_bytes_available':False,'preapply_host_snapshot_available':False}

class CloudFailureNativeExports(CallbackNativeExports):
    def require_complete(self,case):
        child = self.suite.batch.child
        require(case == CASE and type(child) is subprocess.Popen and child._child_created is True
                and child.pid == self.step['pid'] and subprocess.Popen.poll(child) == 0
                and self.step['process_terminal'] is True, 'Retained actual terminal failure-boundary Popen')
        self.publish(terminal=True)
        require(set(self.rows) == {'report.json'}, 'One fixed closed failure-boundary report export')
        for row in self.rows.values():
            self.suite.freeze_bytes(Path(row['native_stage']),row['sha256'])
            self.suite.freeze_bytes(Path(row['published_path']),row['sha256'])

class CloudFailureEvidence:
    def __init__(self,suite,contract,manifest):
        require(type(contract) is dict and type(manifest) is dict
                and manifest['schema'] == 'cloud_write_failure_candidate_source_v2'
                and manifest['case'] == CASE and manifest['required_mode'] == 'first'
                and contract['GD'] == manifest['candidate'] and contract['parent_GD'] == manifest['parent_GD']
                and contract['source_label_count'] == len(contract['complete_local_boundary_labels']) == 40
                and len(set(contract['complete_local_boundary_labels'])) == 40,
                'Exact V2 driver and whole local-boundary source contract')
        require(isinstance(suite.batch,OwnedSerialBatch) and suite.batch.frozen is suite.frozen
                and suite.batch.run == suite.run
                and getattr(suite.batch.phase,'__func__',None) is OwnedSerialBatch.phase,
                'Actual inherited owned phase interface, never a simulated holder')
        declared = {row['path']:row for row in suite.spec['pins']}
        for path,value in [(Path(manifest['candidate']['path']).parent/'SOURCE.json',manifest),
                           (Path(manifest['candidate']['path']).parent/'LOCAL_BOUNDARY_LABEL_CONTRACT_V2.json',contract)]:
            no_links(path)
            row = declared.get(str(path))
            require(type(row) is dict and row['bytes'] == path.stat().st_size and row['sha256'] == sha(path)
                    and same(suite.read_fixed(path,row['sha256']),value), 'Original sealed complete manifest and label-contract bytes')
        for row in manifest['pins']:
            require(declared.get(row['path']) == row, 'Whole candidate provenance is part of sealed caller input')
            no_links(Path(row['path']))
            require(Path(row['path']).stat().st_size == row['bytes'] and sha(Path(row['path'])) == row['sha256'], 'Exact candidate source bytes')
        basis = suite.read_fixed(manifest['source_recipe_basis']['path'],manifest['source_recipe_basis']['sha256'])['recipe']
        engine = basis['engine']
        no_links(suite.batch.engine)
        require(suite.spec['engine'] == engine and suite.batch.engine.resolve() == Path(engine['path']).resolve()
                and suite.batch.engine_sha256 == engine['sha256'] == suite.runtime_fields['engine_binary_sha256']
                and suite.batch.engine.stat().st_size == engine['bytes'] and sha(suite.batch.engine) == engine['sha256'],
                'Actual original workstation Godot binary, never another executable emitting fixtures')
        for key in ['candidate','parent_GD']:
            row = manifest[key]
            alias = 'tools/'+Path(row['path']).name
            matches = [v for v in suite.spec['inputs']['runtime_and_harness_overlays'] if v['runtime_path'] == alias]
            require(len(matches) == 1 and all(matches[0][k] == row[k] for k in ['path','bytes','sha256']), 'Exact installed driver and parent alias')
            installed = suite.frozen.project/alias;no_links(installed)
            require(installed.is_file() and installed.stat().st_size == row['bytes'] and sha(installed) == row['sha256'],
                    'Actual installed driver and parent are the source-sealed originals')
        self.suite,self.contract,self.manifest = suite,contract,manifest
        self.completed = False

    def validate(self,step):
        suite,batch = self.suite,self.suite.batch
        require(not self.completed and len(batch.steps) == 2 and batch.steps[-1] is step
                and batch.steps[0]['label'] == 'cold_import' and batch.steps[0]['complete'] is True
                and step['label'] == 'cloud_write_failure' and step['mode'] == 'first' and step['case'] == CASE
                and step['complete'] is False and step['CAMPAIGN_QA_enabled'] is False, 'Only current original cold/failure phase')
        child = batch.child
        command = [str(batch.engine),'--path',str(suite.frozen.project),'--script',
                   'res://tools/'+Path(self.manifest['candidate']['path']).name]
        require(type(child) is subprocess.Popen and child._child_created is True and child.args == command
                and step['command'] == command and type(step['pid']) is int and child.pid == step['pid']
                and subprocess.Popen.poll(child) == 0 and step['process_terminal'] is True
                and type(step['exit_code']) is int and step['exit_code'] == step['expected_exit'] == 0
                and type(step['engine_errors']) is int and step['engine_errors'] == 0
                and hex_value(step['nonce'],32)
                and step['pid'] != batch.steps[0]['pid'] and step['nonce'] != batch.steps[0]['nonce'],
                'Actual retained distinct normal-GUI native process and exact command')
        output,profile = Path(step['output']),Path(step['profile'])
        no_links(output);no_links(profile)
        require(output == suite.run/'steps'/'cloud_write_failure'
                and profile.resolve().is_relative_to((suite.run/'profiles').resolve()), 'Original owned output and private profile')
        env = step['environment_overrides']
        require(env.get('STEAM_DISABLED') == '1' and env.get('CAMPAIGN_QA','') == ''
                and env.get('CAMPAIGN_CALLBACK_CASE') == CASE and env.get('CAMPAIGN_TERMINAL_MODE') == 'first'
                and env.get('CAMPAIGN_TERMINAL_PROFILE') == str(profile) and env.get('CAMPAIGN_TERMINAL_OUTPUT') == str(output)
                and env.get('CAMPAIGN_TERMINAL_NONCE') == step['nonce']
                and all(env.get(k) == str(profile/k.lower()) for k in ['APPDATA','LOCALAPPDATA','TEMP','TMP']), 'Original exact isolated native environment')
        rows = step.get('actual_native_exports')
        require(type(rows) is dict and set(rows) == {'report.json'}, 'One closed original export')
        row = rows['report.json']
        require(type(row) is dict and set(row) == {'native_stage','published_path','bytes','sha256','pid','nonce'}
                and type(row['pid']) is int and row['pid'] == step['pid'] and row['nonce'] == step['nonce']
                and type(row['bytes']) is int and 0 < row['bytes'] <= 2097152 and hex_value(row['sha256'])
                and Path(row['native_stage']) == output/('report.json.native-'+step['nonce'])
                and Path(row['published_path']) == output/'report.json', 'Full original report custody fields')
        raw = suite.freeze_bytes(row['native_stage'],row['sha256'])
        require(len(raw) == row['bytes'] and raw == suite.freeze_bytes(row['published_path'],row['sha256']), 'Original closed stage equals published whole bytes')
        lines = suite.freeze_bytes(output/'native.log',step['log_sha256']).decode('utf-8').splitlines()
        require(lines.count('CAMPAIGN_FILE19_EXPORT %d %s report.json %s'%(step['pid'],step['nonce'],row['sha256'])) == 1
                and lines.count('CLOUD_REAL_WRITE_FAILURE_BOUNDARY_COMPLETE %d %s 40 true'%(step['pid'],step['nonce'])) == 1,
                'Exactly one original closed export and complete successful marker')
        report = json_value(raw.decode('utf-8'))
        require(type(report) is dict and set(report) == REPORT_FIELDS
                and report['schema'] == 'campaign_original19_cloud_write_failure_probe_v2'
                and report['passed'] is True and same(report['failures'],[]) and type(report['pid']) is int
                and report['pid'] == step['pid'] and report['nonce'] == step['nonce']
                and report['mode'] == 'first' and report['case'] == CASE and report['scope'] == SCOPE
                and type(report['observations']) is list and type(report['time_scale']) in [int,float] and report['time_scale'] == 1
                and type(report['physics_ticks']) is int and report['physics_ticks'] == 60
                and report['successful_authorized_same_writer_retry_required'] is True
                and all(report[k] is False for k in ['successful_authorized_same_writer_retry_qualified','restart_qualified',
                      'Steam_account_qualified','upload_qualified','SDK_reward_once_qualified','original19_faults_qualified',
                      'pending_failure_UI_qualified','overall_goal_qualified']), 'Complete original normal-clock limited report')
        labels(report['checks'],self.contract['complete_local_boundary_labels'])
        identity = expected_native_identity(suite.runtime_fields,suite.installed_identity)
        require(same(report['identity'],identity) and type(report['user_directory']) is str and report['user_directory'], 'Whole native identity and original raw userdata text')
        user = Path(report['user_directory']);no_links(user)
        require(user.is_absolute() and user.resolve().is_relative_to((profile/'appdata').resolve()), 'Actual private physical userdata boundary')
        evidence = report['failure_evidence']
        structural = failure_structure(evidence,identity,suite.runtime_fields)
        expected_blocker = ('CLOUD_FAILURE_PRIVATE_FIXTURE '+step['nonce']+'\n').encode('utf-8')
        require(evidence['blocker_sha256'] == hashlib.sha256(expected_blocker).hexdigest(), 'Closed obstruction bound to original nonce bytes')
        repaired = user/'campaign_cfg_candidates/v1';no_links(repaired)
        require(repaired.is_dir() and not list(repaired.iterdir()), 'Actual repaired stage parent has no candidate publication')
        copies = output/'failure_originals';no_links(copies);copies.mkdir(exist_ok=False)
        cfg = user/'campaign.cfg';no_links(cfg)
        physical = {}
        if evidence['original_cfg_sha256']:
            physical['cfg'] = original_copy(suite,cfg,copies/'campaign_cfg.bin',evidence['original_cfg_sha256'])
        else:
            require(not cfg.exists(), 'Originally absent CFG remains physically absent');physical['cfg'] = None
        binding = user/'steam_cloud_owner.cfg';no_links(binding)
        if evidence['original_shared_pending']['binding_sha']:
            physical['binding'] = original_copy(suite,binding,copies/'cloud_owner.bin',evidence['original_shared_pending']['binding_sha'])
        else:
            require(not binding.exists(), 'Originally absent binding remains absent');physical['binding'] = None
        directory = user/'campaign_cfg_transactions/v1/5088120/1';no_links(directory)
        require(directory.is_dir(), 'Actual retained writer directory')
        writing = directory/'writing';no_links(writing)
        require(writing.is_dir() and {p.name for p in writing.iterdir()} == {'owner.json'}, 'Whole actual retained owner lock shape')
        lock = original_copy(suite,writing/'owner.json',copies/'writer_owner.json',journal=True)
        owner = json_value(suite.freeze_bytes(lock['copy_path'],lock['sha256']).decode('utf-8'))
        require(type(owner) is dict and set(owner) == {'version','owner','pid','token'}
                and owner['version'] == '1' and owner['owner'] == '1' and owner['pid'] == str(step['pid'])
                and hex_value(owner['token'],32), 'Original retained lock binds actual terminated process')
        names = sorted(p.name for p in directory.iterdir() if p.name != 'writing')
        require(len(names) in [0,2,4] and all(re.fullmatch(r'record_[0-9]{10}\.json',name) for name in names), 'No candidate, pending record or unexpected journal files')
        retained = [];previous = None;last_generation = None
        for name in names:
            number = int(name[7:17])
            copy = original_copy(suite,directory/name,copies/name,journal=True)
            original = suite.freeze_bytes(copy['copy_path'],copy['sha256'])
            envelope = json_value(original.decode('utf-8'))
            expected_previous = previous if previous is not None else envelope['previous_sha256']
            require(hex_value(expected_previous) and (number != 1 or expected_previous == ZERO)
                    and (last_generation is None or number == last_generation+1), 'Actual retained journal link sequence')
            document = strict_journal(original,number,expected_previous)
            require(document['state'] == ('prepared' if number%2 else 'applied'), 'Actual prior journal alternating state')
            copy['document'] = document;retained.append(copy)
            previous,last_generation = copy['sha256'],number
        require(not retained or retained[0]['document']['generation']%2 == 1, 'Prior journal begins with prepared generation')
        if retained:require(retained[-1]['document']['state'] == 'applied', 'No new prepared commit from failed staging')
        physical['retained_CFG_links'] = retained_cfg_links(retained,evidence['original_cfg_sha256'])
        physical.update(writer_lock=lock,retained_prior_journals=retained,
                        pruned_ancestor_bytes_available=False,preapply_host_snapshot_available=False)
        require(repaired.is_dir() and not list(repaired.iterdir()), 'Repaired parent still empty after original capture')
        for copy in [physical['cfg'],physical['binding'],lock,*retained]:
            if copy is not None:
                path = Path(copy['original_path']);no_links(path)
                require(path.is_file() and path.stat().st_size == copy['bytes'] and sha(path) == copy['sha256'],
                        'Actual source originals stable after entire capture')
        require((cfg.is_file() if physical['cfg'] else not cfg.exists())
                and (binding.is_file() if physical['binding'] else not binding.exists())
                and sorted(p.name for p in directory.iterdir() if p.name != 'writing') == names
                and {p.name for p in writing.iterdir()} == {'owner.json'}, 'Whole physical presence and directory inventory stable')
        self.completed = True
        return {'local_failure_boundary_evidence_verified':True,'report_structure':structural,'physical_originals':physical,
                'successful_authorized_same_writer_retry_qualified':False,'restart_qualified':False,
                'native_full_CFG_semantics_verified':False,'player_UI_qualified':False,'original19_qualified':False,
                'SDK_reward_once_qualified':False,'overall_goal_qualified':False}
