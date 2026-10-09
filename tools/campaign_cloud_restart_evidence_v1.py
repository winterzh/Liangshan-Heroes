"""Bind actual first cloud evidence to its owned ordinary same-profile restart.

No launcher or admission. Both reports and original physical bytes must pass;
local SDK-disabled input never supplies an actual Steam/account/upload claim.
"""
from pathlib import Path
import subprocess

from campaign_cloud_apply_first_evidence_v4 import CloudApplyFirstEvidence
from campaign_cloud_arm_packet_evidence_v2 import CASE
from campaign_cloud_cfg_physical_v2 import original_copy, journal_names, sha
from campaign_callback_controller_v3 import expected_native_identity
from campaign_callback_packets_v2 import json_value, same
from campaign_file_fault_evidence_v2 import labels
from campaign_file_fault_records_v1 import hex_value
from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import no_links

REPORT_FIELDS = {'schema','passed','checks','failures','observations','pid','nonce','mode','identity',
                 'user_directory','time_scale','physics_ticks','case','restart_evidence','ordinary_restart_qualified',
                 'Steam_account_qualified','upload_qualified','SDK_reward_once_qualified','original19_faults_qualified','overall_goal_qualified'}
EVIDENCE_FIELDS = {'prior_report_sha256','prior_pid','prior_nonce','cfg_sha256','journal_files','sections_json',
                   'startup_result','final_memory','cloud_state','campaign_id','cloud_id'}
STARTUP = {'ok':True,'startup_checked':True,'progress_recovered':0,'settlement_authorized':False}


class CloudCaseEvidence(CloudApplyFirstEvidence):
    def __init__(self,suite,first_contract,first_manifest,restart_contract,restart_manifest):
        super().__init__(suite,first_contract,first_manifest)
        require(restart_contract['GD'] == restart_manifest['candidate']
                and restart_contract['parent_GD'] == restart_manifest['parent_GD'] == first_contract['parent_GD']
                and restart_contract['identity_fields_order'] == list(suite.runtime_fields)
                and len(restart_contract['complete_labels']) == 33 and restart_manifest['case'] == CASE
                and restart_manifest['required_mode'] == 'restart_first'
                and restart_manifest['first_driver'] == first_contract['GD'], 'Exact first/restart native dependencies and full labels')
        self.restart_contract,self.restart_manifest = restart_contract,restart_manifest
        self.first_step = self.first_result = None
        self.restart_step = None

    def validate_first(self,step):
        result = super().validate_first(step)
        self.first_step,self.first_result = step,result
        return result

    def validate_restart(self,step):
        require(self.completed and self.first_step is not None and self.first_result is not None
                and self.restart_step is None and any(s is step for s in self.suite.batch.steps)
                and self.first_step['complete'] is True and step['label'] == 'cloud_restart'
                and step['mode'] == 'restart_first' and step['case'] == CASE
                and self.suite.batch.steps == [self.suite.batch.steps[0],self.first_step,step]
                and self.suite.batch.steps[0]['label'] == 'cold_import'
                and self.suite.batch.steps[0]['complete'] is True, 'Actual cold/validated cloud/ordinary restart process order')
        child = self.suite.batch.child
        require(isinstance(child,subprocess.Popen) and type(step['pid']) is int and step['pid'] > 0
                and child.pid == step['pid'] and child.poll() == 0 and step['process_terminal'] is True
                and type(step['exit_code']) is int and step['exit_code'] == 0
                and type(step['engine_errors']) is int and step['engine_errors'] == 0
                and hex_value(step['nonce'],32) and step['pid'] != self.first_step['pid']
                and step['nonce'] != self.first_step['nonce'], 'Retained actual terminal owned restart Popen and distinct identity')
        output,profile = Path(step['output']),Path(step['profile'])
        no_links(output)
        no_links(profile)
        require(profile == Path(self.first_step['profile'])
                and output.resolve().is_relative_to((self.suite.run/'steps').resolve())
                and profile.resolve().is_relative_to((self.suite.run/'profiles').resolve()), 'Same actual private profile and owned output')
        first_path = Path(self.first_step['output'])/'report.json'
        first_pin = self.first_step['actual_native_exports']['report.json']
        first = self.read(first_path,first_pin['sha256'])
        env = step['environment_overrides']
        require(env.get('CAMPAIGN_TERMINAL_MODE') == 'restart_first' and env.get('CAMPAIGN_CALLBACK_CASE') == CASE
                and env.get('CAMPAIGN_TERMINAL_PROFILE') == str(profile) and env.get('CAMPAIGN_TERMINAL_OUTPUT') == str(output)
                and env.get('CAMPAIGN_TERMINAL_NONCE') == step['nonce'] and env.get('STEAM_DISABLED') == '1'
                and env.get('CAMPAIGN_QA','') == '' and env.get('CAMPAIGN_CLOUD_PRIOR_REPORT_FILE') == str(first_path)
                and env.get('CAMPAIGN_CLOUD_PRIOR_REPORT_SHA256') == first_pin['sha256']
                and all(env.get(k) == str(profile/k.lower()) for k in ['APPDATA','LOCALAPPDATA','TEMP','TMP']), 'Exact ordinary restart environment and original preceding report pin')
        rows = step.get('actual_native_exports')
        require(type(rows) is dict and set(rows) == {'report.json'}, 'One fixed original restart export')
        row = rows['report.json']
        require(type(row) is dict and set(row) == {'native_stage','published_path','bytes','sha256','pid','nonce'}
                and type(row['pid']) is int and row['pid'] == step['pid'] and row['nonce'] == step['nonce']
                and type(row['bytes']) is int and 0 < row['bytes'] <= 2097152 and hex_value(row['sha256'])
                and Path(row['native_stage']) == output/('report.json.native-'+step['nonce'])
                and Path(row['published_path']) == output/'report.json', 'Whole original restart publication paths/PID/nonce/size')
        raw = self.suite.freeze_bytes(row['native_stage'],row['sha256'])
        require(len(raw) == row['bytes'] and raw == self.suite.freeze_bytes(row['published_path'],row['sha256']), 'Exact closed original restart export bytes')
        log = self.suite.freeze_bytes(output/'native.log',step['log_sha256']).decode('utf-8').splitlines()
        require(log.count('CAMPAIGN_FILE19_EXPORT %d %s report.json %s'%(step['pid'],step['nonce'],row['sha256'])) == 1
                and log.count('NATURAL_CLOUD_RESTART_COMPLETE %d %s %s 33 true'%(step['pid'],step['nonce'],CASE)) == 1, 'Original successful complete restart markers exactly once')
        report = json_value(raw.decode('utf-8'))
        require(type(report) is dict and set(report) == REPORT_FIELDS and report['schema'] == 'campaign_original19_cloud_restart_probe_v1'
                and report['passed'] is True and same(report['failures'],[]) and type(report['pid']) is int and report['pid'] == step['pid']
                and report['nonce'] == step['nonce'] and report['mode'] == 'restart_first' and report['case'] == CASE
                and type(report['observations']) is list and type(report['time_scale']) in [int,float] and report['time_scale'] == 1
                and type(report['physics_ticks']) is int and report['physics_ticks'] == 60
                and all(report[k] is False for k in ['ordinary_restart_qualified','Steam_account_qualified','upload_qualified',
                                                    'SDK_reward_once_qualified','original19_faults_qualified','overall_goal_qualified']), 'Complete original normal-clock SDK-disabled restart report')
        labels(report['checks'],self.restart_contract['complete_labels'])
        require(same(report['identity'],expected_native_identity(self.suite.runtime_fields,self.suite.installed_identity))
                and same(report['identity'],first['identity']) and type(report['user_directory']) is str
                and report['user_directory'] == first['user_directory'], 'Full actual installed identity and same unmodified native user text')
        user = Path(report['user_directory'])
        no_links(user)
        require(user.is_absolute() and user.resolve().is_relative_to((profile/'appdata').resolve()), 'Actual private physical userdata boundary')
        evidence = report['restart_evidence']
        require(type(evidence) is dict and set(evidence) == EVIDENCE_FIELDS
                and evidence['prior_report_sha256'] == first_pin['sha256'] and type(evidence['prior_pid']) is int
                and evidence['prior_pid'] == self.first_step['pid'] and evidence['prior_nonce'] == self.first_step['nonce']
                and evidence['cfg_sha256'] == first['cloud_evidence']['cfg_sha256']
                and same(evidence['startup_result'],STARTUP) and same(evidence['final_memory'],{'records':{},'unlocked':2,'owner':'1'})
                and type(evidence['cloud_state']) is dict and set(evidence['cloud_state']) == {'dirty','pending_upload','revision'}
                and type(evidence['cloud_state']['dirty']) is bool and type(evidence['cloud_state']['pending_upload']) is bool
                and type(evidence['cloud_state']['revision']) is int
                and all(type(evidence[k]) is int and evidence[k] > 0 for k in ['campaign_id','cloud_id']), 'Full original preceding-cloud binding and ordinary no-settlement result')
        original_sections = first['cfg_semantics']['final_sections_json']
        require(type(evidence['sections_json']) is str and same(json_value(evidence['sections_json']),json_value(original_sections)), 'Whole native restart projection equals original final projection')
        physical = self.first_result['physical_CFG']
        copies = output/'cloud_restart_originals'
        no_links(copies)
        copies.mkdir(exist_ok=False)
        cfg = original_copy(self.suite,user/'campaign.cfg',copies/'campaign_cfg.bin',physical['cfg']['sha256'])
        require(self.suite.freeze_bytes(cfg['copy_path'],cfg['sha256']) == self.suite.freeze_bytes(physical['cfg']['copy_path'],physical['cfg']['sha256']), 'Restart actual public CFG equals first closed original bytes')
        directory = user/'campaign_cfg_transactions/v1/5088120/1'
        originals = physical['journals']
        names = [(Path(r['original_path']).name,r['generation']) for r in originals]
        require(journal_names(directory) == names and same(evidence['journal_files'],{name:r['sha256'] for (name,_),r in zip(names,originals)}), 'Same original cloud prepared/applied generations and native hashes')
        retained = []
        for (name,_),original in zip(names,originals):
            copy = original_copy(self.suite,directory/name,copies/name,original['sha256'],journal=True)
            require(self.suite.freeze_bytes(copy['copy_path'],copy['sha256']) == self.suite.freeze_bytes(original['copy_path'],original['sha256']), 'Whole restart journals equal original first closed copies')
            retained.append(copy)
        stage,lifecycle = user/'campaign_cfg_candidates/v1',user/'continue/v1/local_runs'
        no_links(stage)
        no_links(lifecycle)
        require(stage.is_dir() and not list(stage.iterdir()) and (not lifecycle.exists() or lifecycle.is_dir() and not list(lifecycle.iterdir())), 'Actual ordinary restart has no candidate or terminal replay files')
        require(journal_names(directory) == names and sha((user/'campaign.cfg').read_bytes()) == cfg['sha256'], 'Physical originals stable across restart capture')
        self.read(first_path,first_pin['sha256'])
        self.restart_step = step
        return {'ordinary_same_profile_restart_verified':True,'physical_CFG':cfg,'retained_journals':retained,
                'native_full_CFG_semantics_verified':True,'settlement_authorized':False,'Steam_account_qualified':False,
                'upload_qualified':False,'original19_qualified':False,'whole_suite_qualified':False}

    def require_all(self):
        require(self.completed and self.first_step is not None and self.restart_step is not None
                and self.first_step['complete'] is True and self.restart_step['complete'] is True,
                'Actual first cloud and ordinary restart both closed successfully')
