"""Actual first cloud report/raw-packet/physical CFG evidence; no launcher.

Full native CFG semantics, ordinary cloud restart and complete producer remain
explicit obligations. This intermediate consumer cannot qualify the whole case.
"""
from pathlib import Path
import subprocess

from campaign_callback_controller_v3 import expected_native_identity
from campaign_callback_packets_v2 import json_value, same
from campaign_file_fault_evidence_v2 import labels
from campaign_file_fault_records_v1 import hex_value
from campaign_cloud_arm_packet_evidence_v2 import replay_cloud_arm_packets, CASE
from campaign_cloud_cfg_physical_v2 import validate_cloud_post_cfg
from campaign_cloud_cfg_semantics_v2 import validate_native_semantics
from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import no_links

REPORT_FIELDS = {'schema','passed','checks','failures','observations','pid','nonce','mode','identity','user_directory',
                 'time_scale','physics_ticks','case','observer_sequence','cloud_evidence','arm_ack','scope',
                 'actual_callback_qualified','Steam_account_qualified','upload_qualified','SDK_reward_once_qualified',
                 'original19_faults_qualified','overall_goal_qualified','cfg_semantics'}
EVIDENCE_FIELDS = {'campaign_id','cloud_id','original_memory','original_cloud','original_cfg_sha256','payload',
                   'applied','cfg_sha256','final_memory','final_cloud','synthetic_local_owner','SDK_disabled'}
SCOPE = 'actual normal production cloud apply with synthetic local SDK-disabled owner; host must bind actual stack, raw packet custody, CFG journals and same-profile restart'


class CloudApplyFirstEvidence:
    def __init__(self,suite,contract,manifest):
        require(contract['GD'] == manifest['candidate'] and contract['parent_GD'] == manifest['parent_GD']
                and manifest['case'] == CASE and manifest['required_mode'] == 'first'
                and contract['identity_fields_order'] == list(suite.runtime_fields)
                and len(contract['complete_labels']) == 40, 'Exact first cloud driver and full ordered source-label contract')
        self.suite,self.contract,self.manifest = suite,contract,manifest
        self.completed = False

    def read(self,path,expected=None):
        return json_value(self.suite.freeze_bytes(Path(path),expected).decode('utf-8-sig'))

    def exports(self,step):
        output = Path(step['output'])
        rows = step.get('actual_native_exports')
        require(type(rows) is dict and set(rows) == {'callback_driver_ready.json','cloud_apply_ready.json','cloud_cfg_semantics_ready.json','report.json'}, 'All four closed original native exports')
        log = self.suite.freeze_bytes(output/'native.log',step['log_sha256']).decode('utf-8')
        lines = log.splitlines()
        for name,row in rows.items():
            require(type(row) is dict and set(row) == {'native_stage','published_path','bytes','sha256','pid','nonce'}
                    and type(row['pid']) is int and row['pid'] == step['pid'] and row['nonce'] == step['nonce']
                    and type(row['bytes']) is int and 0 < row['bytes'] <= 2097152 and hex_value(row['sha256']), 'Full original export fields and process identity')
            require(Path(row['native_stage']) == output/(name+'.native-'+step['nonce'])
                    and Path(row['published_path']) == output/name, 'Exact native stage and public export paths')
            raw = self.suite.freeze_bytes(row['native_stage'],row['sha256'])
            require(len(raw) == row['bytes'] and raw == self.suite.freeze_bytes(row['published_path'],row['sha256']), 'Unchanged whole native export bytes')
            marker = 'CAMPAIGN_FILE19_EXPORT %d %s %s %s'%(step['pid'],step['nonce'],name,row['sha256'])
            require(lines.count(marker) == 1, 'One actual closed-stage native marker per export')
        return lines

    def validate_first(self,step):
        require(not self.completed and any(s is step for s in self.suite.batch.steps)
                and step['label'] == 'cloud_applying' and step['mode'] == 'first' and step['case'] == CASE,
                'Current actual first cloud phase object, only once')
        child = self.suite.batch.child
        require(isinstance(child,subprocess.Popen) and type(step['pid']) is int and step['pid'] > 0
                and child.pid == step['pid'] and child.poll() == 0 and step['process_terminal'] is True
                and type(step['exit_code']) is int and step['exit_code'] == 0
                and type(step['engine_errors']) is int and step['engine_errors'] == 0
                and hex_value(step['nonce'],32), 'Retained actual terminal owned Popen and zero diagnostics')
        output,profile = Path(step['output']),Path(step['profile'])
        no_links(output)
        no_links(profile)
        require(output.resolve().is_relative_to((self.suite.run/'steps').resolve())
                and profile.resolve().is_relative_to((self.suite.run/'profiles').resolve()), 'Owned actual phase/profile boundaries')
        env = step['environment_overrides']
        require(env.get('STEAM_DISABLED') == '1' and env.get('CAMPAIGN_QA','') == ''
                and env.get('CAMPAIGN_CALLBACK_CASE') == CASE and env.get('CAMPAIGN_TERMINAL_MODE') == 'first'
                and env.get('CAMPAIGN_TERMINAL_PROFILE') == str(profile) and env.get('CAMPAIGN_TERMINAL_OUTPUT') == str(output)
                and env.get('CAMPAIGN_TERMINAL_NONCE') == step['nonce']
                and all(env.get(k) == str(profile/k.lower()) for k in ['APPDATA','LOCALAPPDATA','TEMP','TMP']), 'Exact normal private native environment')
        lines = self.exports(step)
        report = self.read(output/'report.json')
        require(type(report) is dict and set(report) == REPORT_FIELDS and report['schema'] == 'campaign_original19_cloud_applying_probe_v3'
                and report['passed'] is True and same(report['failures'],[]) and type(report['pid']) is int and report['pid'] == step['pid']
                and report['nonce'] == step['nonce'] and report['case'] == CASE and report['mode'] == 'first'
                and type(report['observer_sequence']) is int and report['observer_sequence'] == 1, 'Complete original successful cloud report and unique snapshot')
        labels(report['checks'],self.contract['complete_labels'])
        require(lines.count('NATURAL_CLOUD_APPLY_COMPLETE %d %s %s 40 true'%(step['pid'],step['nonce'],CASE)) == 1, 'One actual complete successful native marker')
        require(report['scope'] == SCOPE and type(report['observations']) is list
                and type(report['time_scale']) in [int,float] and report['time_scale'] == 1
                and type(report['physics_ticks']) is int and report['physics_ticks'] == 60
                and all(report[k] is False for k in ['actual_callback_qualified','Steam_account_qualified','upload_qualified',
                                                   'SDK_reward_once_qualified','original19_faults_qualified','overall_goal_qualified']),
                'Normal clock and explicit limited local SDK-disabled qualification boundary')
        require(same(report['identity'],expected_native_identity(self.suite.runtime_fields,self.suite.installed_identity)), 'Complete fifteen-field actual Provider identity')
        native_user = report['user_directory']
        require(type(native_user) is str and native_user, 'Original native report user-directory text')
        user = Path(native_user)
        no_links(user)
        require(user.is_absolute() and user.resolve().is_relative_to((profile/'appdata').resolve()), 'Actual current private user directory')
        ready = self.read(output/'callback_driver_ready.json')
        require(set(ready) == {'schema','pid','nonce','case','identity','user_directory'} and ready['schema'] == 'campaign_callback_driver_ready_v1'
                and type(ready['pid']) is int and ready['pid'] == step['pid'] and ready['nonce'] == step['nonce'] and ready['case'] == CASE
                and same(ready['identity'],report['identity']) and ready['user_directory'] == native_user, 'Whole original driver-ready binding')
        apply_ready = self.read(output/'cloud_apply_ready.json')
        apply_fields = {'schema','pid','nonce','case','identity','user_directory','campaign_id','cloud_id','original_memory',
                        'original_cloud','original_cfg_sha256','payload','synthetic_local_owner','SDK_disabled','Steam_account_qualified','upload_qualified'}
        require(type(apply_ready) is dict and set(apply_ready) == apply_fields and apply_ready['schema'] == 'campaign_cloud_apply_ready_v1'
                and type(apply_ready['pid']) is int and apply_ready['pid'] == step['pid'] and apply_ready['nonce'] == step['nonce']
                and apply_ready['case'] == CASE and same(apply_ready['identity'],report['identity']) and apply_ready['user_directory'] == native_user
                and apply_ready['synthetic_local_owner'] is True and apply_ready['SDK_disabled'] is True
                and apply_ready['Steam_account_qualified'] is False and apply_ready['upload_qualified'] is False,
                'Whole actual bounded local apply-ready identity/scope')
        evidence = report['cloud_evidence']
        require(type(evidence) is dict and set(evidence) == EVIDENCE_FIELDS and evidence['applied'] is True
                and evidence['synthetic_local_owner'] is True and evidence['SDK_disabled'] is True and hex_value(evidence['cfg_sha256'])
                and all(same(evidence[k],apply_ready[k]) for k in ['campaign_id','cloud_id','original_memory','original_cloud','original_cfg_sha256','payload']),
                'Complete original input/baseline retained in actual report')
        require(same(evidence['original_memory'],{'records':{},'unlocked':1,'owner':''})
                and same(evidence['final_memory'],{'records':{},'unlocked':2,'owner':'1'}), 'Actual local input changes only declared campaign progress')
        final = evidence['final_cloud']
        require(type(final) is dict and set(final) == {'dirty','pending_upload','revision','applying','shared_profile_pending'}
                and final['applying'] is False and final['shared_profile_pending'] is False
                and all(same(final[k],evidence['original_cloud'][k]) for k in ['dirty','pending_upload','revision']), 'Closed real apply preserves original upload state')
        before = step['cloud_cfg_before']
        require((before['cfg']['sha256'] if before['cfg'] else '') == apply_ready['original_cfg_sha256'], 'Actual pre-arm physical CFG matches native original declaration')
        replay = replay_cloud_arm_packets(self.suite,step,report['identity'],native_user,apply_ready)
        require(same(report['arm_ack'],step['callback_observation']['arm_ack']) and replay['native_ownership_proven'] is False
                and replay['whole_suite_qualified'] is False and replay['breakpoint_installation_verified'] is False,
                'Report arm acknowledgment matches independently replayed raw packet; helper cannot grant ownership')
        physical = validate_cloud_post_cfg(self.suite,step,user,evidence['cfg_sha256'])
        first_semantics = step['cloud_cfg_semantics_ready']
        require(Path(first_semantics['path']) == output/'cloud_cfg_semantics_ready.json'
                and first_semantics['sha256'] == step['actual_native_exports']['cloud_cfg_semantics_ready.json']['sha256'],
                'Same first pre-arm native semantics export retained after actual completion')
        semantics = self.read(first_semantics['path'],first_semantics['sha256'])
        verified_semantics = validate_native_semantics(semantics,report['cfg_semantics'],step['pid'],step['nonce'],
                                                     report['identity'],native_user,apply_ready['original_cfg_sha256'],physical)
        self.completed = True
        return {'case':CASE,'first_report_packets_physical_CFG_verified':True,'packet_replay':replay,'physical_CFG':physical,
                'native_full_CFG_semantics_verified':True,'native_semantics':verified_semantics,'ordinary_restart_qualified':False,
                'original19_qualified':False,'whole_suite_qualified':False}
