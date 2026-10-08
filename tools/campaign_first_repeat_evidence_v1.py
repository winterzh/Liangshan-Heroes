"""Complete original first/repeat reports and physical bytes; no native launcher.

Only a reviewed producer with its actual still-owned terminal Popen may call
validate. Original mutable/pruned public CFG files are copied before adoption;
their first closed copies, native exports and immutable lifecycle remain pinned.
"""
import hashlib
from pathlib import Path
import subprocess

from campaign_file_fault_evidence_v2 import labels,validate_intent,digest,LIFE_FIELDS,CONTEXT
from campaign_file_fault_records_v1 import decode_envelope,cfg_document,hex_value,ZERO
from campaign_original19_atomic_files_v2 import publish_bytes_new
from campaign_original19_debug_faults_v5 import typed_equal
from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import no_links

MODES=('first','restart_first','repeat','restart_repeat')
CASES=('normal_first_full_seal','normal_repeat_full')
REPORT_FIELDS={'schema','passed','checks','failures','observations','pid','nonce','mode','orders','identity','user_directory','time_scale','physics_ticks','scope','all_roles_ABCD_qualified','original19_faults_qualified','pending_failure_UI_qualified','Steam_rewards_qualified','case','seal_evidence','prior_handoff'}
SCOPE='Two actual ordinary Huangnigang full victories on one private profile and separate-process ordinary restarts; isolated Steam disabled.'

def sha_bytes(raw):return hashlib.sha256(raw).hexdigest()

class FirstRepeatEvidence:
    def __init__(self,suite,contract,manifest):
        self.suite,self.contract,self.manifest=suite,contract,manifest
        require(contract['GD']==manifest['candidate'] and manifest['case_ids']==list(CASES)
                and contract['identity_fields_order']==list(suite.runtime_fields)
                and set(contract['complete_labels_by_mode'])==set(MODES), 'Exact reviewed native source and complete ordered label contract')
        self.completed=[];self.fresh={};self.user=None;self.profile=None

    def fixed(self,path,expected=None):return self.suite.freeze_bytes(Path(path),expected)
    def read(self,path):return self.suite.read_fixed(Path(path))

    def physical(self,path,expected=None):
        path=Path(path);no_links(path);raw=path.read_bytes()
        require(expected is None or sha_bytes(raw)==expected, 'Original physical first-byte SHA')
        require(path.read_bytes()==raw, 'Physical source changed during original capture')
        return raw

    def capture(self,path,destination,expected=None):
        raw=self.physical(path,expected);destination=Path(destination);no_links(destination)
        require(destination.resolve().is_relative_to((self.suite.run/'steps').resolve()), 'Current owned immutable evidence copy')
        publish_bytes_new(destination,raw);require(self.physical(path)==raw, 'Original source changed while copying')
        self.fixed(destination,sha_bytes(raw));return raw

    def exports(self,step,mode):
        output=Path(step['output']);rows=step.get('actual_native_exports')
        expected={'restart_handoff.json','report.json'} if mode.startswith('restart_') else {'ready_for_terminal.json','terminal_handoff.json','report.json'}
        require(type(rows) is dict and set(rows)==expected, 'Complete fixed original natural export set')
        for name,row in rows.items():
            require(type(row) is dict and set(row)=={'native_stage','published_path','bytes','sha256','pid','nonce'}
                    and type(row['pid']) is int and row['pid']==step['pid'] and row['nonce']==step['nonce']
                    and type(row['bytes']) is int and 0<row['bytes']<=2097152 and hex_value(row['sha256']), 'Original native publication fields/PID/nonce/size')
            require(Path(row['native_stage'])==output/(name+'.native-'+step['nonce']) and Path(row['published_path'])==output/name, 'Exact current original stage and published names')
            raw=self.fixed(row['native_stage'],row['sha256']);require(len(raw)==row['bytes'] and raw==self.fixed(row['published_path'],row['sha256']), 'Complete original native bytes unchanged')

    def lifecycle(self,user,token,tokens):
        require(hex_value(token,32) and token in tokens, 'Actual original natural token')
        parent=user/'continue/v1/local_runs';no_links(parent)
        require({p.name for p in parent.iterdir()}==set(tokens), 'Exactly the current one or two real natural tokens')
        directory=parent/token/'5088120/1';no_links(directory)
        require({p.name for p in directory.iterdir()}=={'record_%010d.json'%g for g in [1,2,3]}, 'Complete three-generation immutable lifecycle only')
        scope={'owner':'','content_version':self.suite.runtime_fields['content_version'],'engine_sha256':self.suite.runtime_fields['engine_binary_sha256']}
        rows=[];previous=ZERO;intent=None
        for generation in [1,2,3]:
            path=directory/('record_%010d.json'%generation);raw=self.fixed(path);doc=decode_envelope(raw,'LH_LOCAL_CONTINUE_LIFECYCLE',generation,previous)
            require(set(doc)==LIFE_FIELDS and doc['schema']=='local_campaign_continue_lifecycle_v2' and doc['token']==token
                    and typed_equal(doc['context'],CONTEXT) and typed_equal(doc['scope'],scope), 'Full original typed lifecycle scope')
            if generation==1:
                require(doc['state']=='active' and doc['victory'] is False and doc['progress_state']=='none'
                        and typed_equal(doc['intent'],{}) and typed_equal(doc['progress_receipt'],{}), 'Actual active genesis')
            else:
                validate_intent(doc['intent'],token,scope)
                require(doc['state']=='terminal' and doc['victory'] is True and doc['progress_state']==('pending' if generation==2 else 'applied'), 'Actual natural pending/applied sequence')
                if generation==2:intent=doc['intent'];require(typed_equal(doc['progress_receipt'],{}), 'Pending generation has no false ACK')
                else:require(typed_equal(doc['intent'],intent), 'Same full original intent in applied acknowledgement')
            previous=sha_bytes(raw);rows.append({'path':str(path),'sha256':previous,'document':doc})
        ack=rows[2]['document']['progress_receipt']
        require(type(ack) is dict and set(ack)=={'schema','code','persisted','suppressed','file_sha256'} and ack['schema']=='campaign_progress_ack_v1'
                and ack['code']=='CAMPAIGN_CFG_READBACK_VERIFIED' and ack['persisted'] is True and ack['suppressed'] is False and hex_value(ack['file_sha256']), 'Complete actual five-field persisted CFG acknowledgement')
        return rows,intent,ack['file_sha256']

    def cfg_pair(self,user,output,intent,cfg_sha,kind):
        directory=user/'campaign_cfg_transactions/v1/5088120/1';no_links(directory)
        generations=[1,2] if kind=='first' else [3,4]
        require({p.name for p in directory.iterdir()}=={'record_%010d.json'%g for g in generations}, 'Exact current production retained CFG pair')
        copied=output/'physical_cfg_originals';no_links(copied);copied.mkdir(exist_ok=False)
        previous=ZERO if kind=='first' else self.fresh['first']['cfg_journals'][-1]['sha256']
        original=ZERO if kind=='first' else self.fresh['first']['cfg_sha256'];rows=[]
        for generation in generations:
            source=directory/('record_%010d.json'%generation);target=copied/source.name;raw=self.capture(source,target)
            doc=decode_envelope(raw,'LH_CAMPAIGN_CFG_TRANSACTION',generation,previous)
            cfg_document(doc,generation,self.suite.runtime_fields,'progress',intent['token'],digest(intent),original,cfg_sha)
            previous=sha_bytes(raw);rows.append({'original_path':str(source),'copy_path':str(target),'sha256':previous,'document':doc})
        require(typed_equal({k:v for k,v in rows[0]['document'].items() if k not in ['generation','state']},
                            {k:v for k,v in rows[1]['document'].items() if k not in ['generation','state']}), 'Prepared/applied complete14-field proposal pair unchanged')
        if kind=='repeat':
            require(rows[0]['document']['transaction']!=self.fresh['first']['cfg_journals'][0]['document']['transaction'], 'Distinct real repeated progress transaction')
        stage=user/'campaign_cfg_candidates/v1';no_links(stage);require(stage.is_dir() and not list(stage.iterdir()), 'Completed owned candidate stage empty')
        return rows

    def retained_cfg(self,user,original):
        directory=user/'campaign_cfg_transactions/v1/5088120/1';no_links(directory)
        require({p.name for p in directory.iterdir()}=={Path(r['original_path']).name for r in original['cfg_journals']}, 'Ordinary restart retains exact CFG generations')
        for row in original['cfg_journals']:
            require(self.physical(row['original_path'],row['sha256'])==self.fixed(row['copy_path'],row['sha256']), 'Original retained CFG matches original closed copy')

    def validate(self,step,mode):
        require(mode in MODES and len(self.completed)<4 and mode==MODES[len(self.completed)]
                and any(s is step for s in self.suite.batch.steps) and step['mode']==mode and step['label']==mode, 'Actual owned phase in exact four-process sequence')
        child=self.suite.batch.child
        require(isinstance(child,subprocess.Popen) and child.pid==step['pid'] and child.poll()==0
                and step['process_terminal'] is True and type(step['exit_code']) is int and step['exit_code']==0
                and type(step['engine_errors']) is int and step['engine_errors']==0 and type(step['pid']) is int and step['pid']>0 and hex_value(step['nonce'],32), 'Actual retained terminal Popen/PID/nonce with zero errors')
        require(all(step['pid']!=v['pid'] and step['nonce']!=v['nonce'] for v in self.completed), 'Four actual distinct process IDs and nonces')
        env=step['environment_overrides'];profile=Path(step['profile']);output=Path(step['output']);no_links(profile);no_links(output)
        require(output.resolve().is_relative_to((self.suite.run/'steps').resolve()) and profile.resolve().is_relative_to((self.suite.run/'profiles').resolve())
                and env.get('CAMPAIGN_TERMINAL_MODE')==mode and env.get('CAMPAIGN_TERMINAL_PROFILE')==str(profile)
                and env.get('CAMPAIGN_TERMINAL_OUTPUT')==str(output) and env.get('CAMPAIGN_TERMINAL_NONCE')==step['nonce']
                and env.get('STEAM_DISABLED')=='1' and env.get('CAMPAIGN_QA','')=='', 'Exact owned ordinary native launch')
        require(all(env.get(k)==str(profile/k.lower()) for k in ['APPDATA','LOCALAPPDATA','TEMP','TMP']), 'Actual four private native environment roots')
        if self.profile is not None:require(profile==self.profile, 'All four native phases share same real private profile')
        self.exports(step,mode);report=self.read(output/'report.json');case=CASES[0 if mode in ['first','restart_first'] else 1]
        require(type(report) is dict and set(report)==REPORT_FIELDS and report['schema']=='campaign_original19_first_repeat_probe_v1'
                and report['passed'] is True and typed_equal(report['failures'],[]) and type(report['pid']) is int and report['pid']==step['pid']
                and report['nonce']==step['nonce'] and report['mode']==mode and report['case']==case, 'Full actual native case/report fields')
        expected=self.contract['complete_labels_by_mode'][mode];labels(report['checks'],expected)
        log=self.fixed(output/'native.log',step['log_sha256']).decode('utf-8');marker='CAMPAIGN_ORIGINAL19_FIRST_REPEAT '+case+' '+mode+' true '+str(len(expected))
        require(log.splitlines().count(marker)==1, 'Exactly one successful actual complete marker')
        require(type(report['time_scale']) in [int,float] and report['time_scale']==1 and type(report['physics_ticks']) is int and report['physics_ticks']==60
                and all(report[k] is False for k in ['all_roles_ABCD_qualified','original19_faults_qualified','pending_failure_UI_qualified','Steam_rewards_qualified'])
                and report['scope']==SCOPE and type(report['observations']) is list, 'Actual normal clock and limited report scope')
        require(type(report['identity']) is dict and report['identity'].get('ok') is True and report['identity'].get('save_eligible') is True, 'Native installed identity eligible')
        for k,v in self.suite.runtime_fields.items():require(typed_equal(report['identity'][k],v), 'All original installed source fields')
        user=Path(report['user_directory']);no_links(user)
        require(user.is_absolute() and user.resolve().is_relative_to((profile/'appdata').resolve()) and (self.user is None or user==self.user), 'Same actual private userdata across four processes')
        restart=mode.startswith('restart_');kind=mode.removeprefix('restart_');handoff=self.read(output/('restart_handoff.json' if restart else 'terminal_handoff.json'));token=handoff['token']
        tokens=[token] if kind=='first' else [self.fresh['first']['token'],token]
        if kind=='repeat':require(token!=self.fresh['first']['token'], 'Actual repeat uses a new natural token')
        journals,intent,cfg_sha=self.lifecycle(user,token,tokens)
        require(type(handoff['pid']) is int and handoff['pid']==step['pid'] and handoff['nonce']==step['nonce'] and handoff['cfg_sha256']==cfg_sha and handoff['case']==case
                and typed_equal(handoff['intent'],intent) and typed_equal(handoff['files'],{Path(r['path']).name:r['sha256'] for r in journals}), 'Whole original terminal intent/lifecycle/raw CFG handoff')
        self.capture(user/'campaign.cfg',output/'physical_campaign_cfg.bin',cfg_sha)
        if kind=='repeat':
            first=self.fresh['first'];old,old_intent,old_sha=self.lifecycle(user,first['token'],tokens)
            require(typed_equal(old,first['journals']) and typed_equal(old_intent,first['intent']) and old_sha==first['cfg_sha256'], 'Original first lifecycle and acknowledgement bytes stay unchanged')
            for row in first['cfg_journals']:self.fixed(row['copy_path'],row['sha256'])
        if restart:
            original=self.fresh[kind]
            require(set(handoff)=={'schema','pid','nonce','token','files','cfg_sha256','intent','startup_result','case'} and handoff['schema']=='campaign_natural_terminal_restart_v1'
                    and typed_equal(report['seal_evidence'],{}) and typed_equal(report['prior_handoff'],{}) and type(report['orders']) is int and report['orders']==0
                    and token==original['token'] and cfg_sha==original['cfg_sha256'] and typed_equal(journals,original['journals'])
                    and env.get('CAMPAIGN_TERMINAL_TOKEN')==token and env.get('CAMPAIGN_TERMINAL_EXPECT_RECOVERY')=='0', 'Same original intent/files/token in separate actual ordinary restart')
            startup=handoff['startup_result'];require(type(startup) is dict and startup.get('ok') is True and startup.get('startup_checked') is True
                    and type(startup.get('progress_recovered')) is int and startup['progress_recovered']==0 and startup.get('settlement_authorized') is False
                    and not startup.get('terminal_completed',False), 'Actual ordinary startup does no recovery replay or settlement')
            self.retained_cfg(user,original)
        else:
            require(set(handoff)=={'schema','pid','nonce','token','context','identity','files','cfg_sha256','intent','case','seal_evidence','prior_token'}
                    and handoff['schema']=='campaign_natural_terminal_handoff_v1' and typed_equal(handoff['context'],CONTEXT)
                    and typed_equal(handoff['identity'],report['identity']) and type(report['orders']) is int and report['orders']==19, 'Exact actual ordinary nineteen-order terminal handoff')
            ready=self.read(output/'ready_for_terminal.json');labels(ready['checks'],self.contract['preterminal_ready_labels_by_mode'][mode])
            require(set(ready)=={'schema','pid','nonce','checks','orders','identity','actual_user_directory','phase','delivered','clock','fresh_context'}
                    and ready['schema']=='campaign_natural_terminal_ready_v1' and type(ready['pid']) is int and ready['pid']==step['pid'] and ready['nonce']==step['nonce']
                    and type(ready['orders']) is int and ready['orders']==11 and type(ready['phase']) is int and ready['phase']==2
                    and type(ready['delivered']) is int and ready['delivered']==3 and type(ready['clock']) is int and ready['clock']>0
                    and typed_equal(ready['identity'],report['identity']) and typed_equal(ready['fresh_context'],CONTEXT) and Path(ready['actual_user_directory'])==user
                    and typed_equal(report['checks'][:len(ready['checks'])],ready['checks']), 'Complete original preterminal native route/check prefix')
            seal=report['seal_evidence'];require(typed_equal(seal,handoff['seal_evidence']) and type(seal) is dict
                    and set(seal)=={'case','first','displayed_text','first_label','repeat_label','level_record','unlocked','mission_result','campaign_id','battle_id','hud_id'}
                    and seal['case']==case and seal['first'] is (kind=='first') and type(seal['unlocked']) is int and seal['unlocked']==2, 'Original actual first/repeated seal evidence')
            for k in ['displayed_text','first_label','repeat_label']:require(type(seal[k]) is str and seal[k], 'Actual nonempty localized native HUD text')
            selected,other=(seal['first_label'],seal['repeat_label']) if kind=='first' else (seal['repeat_label'],seal['first_label'])
            require(selected!=other and selected in seal['displayed_text'] and other not in seal['displayed_text'], 'Actual first/collected localized HUD branch')
            require(all(type(seal[k]) is int and seal[k]!=0 for k in ['campaign_id','battle_id','hud_id']), 'Real native object IDs')
            mission=seal['mission_result'];require(type(mission) is dict and all(typed_equal(mission.get(k),v) for k,v in intent['result'].items()), 'Whole actual native Mission result matches frozen original intent')
            record=seal['level_record'];require(type(record) is dict and record.get('cleared') is True and record.get('story_complete') is True
                    and type(record.get('best_done')) is int and record['best_done']==4 and type(record.get('story_total')) is int and record['story_total']==4
                    and type(record.get('contract_version')) is int and record['contract_version']==2 and type(record.get('best_goal_ids')) is list
                    and len(record['best_goal_ids'])==4 and all(type(x) is str for x in record['best_goal_ids']) and set(record['best_goal_ids'])==set(intent['result']['done_ids']), 'Actual single full run record; no union/partial substitute')
            if kind=='first':require(typed_equal(report['prior_handoff'],{}) and handoff['prior_token']=='', 'First has no invented previous terminal')
            else:
                first=self.fresh['first'];require(typed_equal(report['prior_handoff'],first['handoff']) and handoff['prior_token']==first['token']
                        and env.get('CAMPAIGN_TERMINAL_PRIOR_HANDOFF_FILE')==str(first['handoff_path'])
                        and env.get('CAMPAIGN_TERMINAL_PRIOR_HANDOFF_SHA256')==sha_bytes(self.fixed(first['handoff_path']))
                        and env.get('CAMPAIGN_TERMINAL_PRIOR_TOKEN')==first['token']
                        and typed_equal(record,first['handoff']['seal_evidence']['level_record']), 'Repeat binds full first original native handoff and unchanged full record')
            cfg=self.cfg_pair(user,output,intent,cfg_sha,kind)
            if kind=='repeat':require(cfg[0]['document']['semantics_sha256']==self.fresh['first']['cfg_journals'][0]['document']['semantics_sha256'], 'Repeated full result retains original complete CFG semantics')
            self.fresh[kind]={'token':token,'journals':journals,'intent':intent,'cfg_sha256':cfg_sha,'cfg_journals':cfg,'handoff':handoff,'handoff_path':output/'terminal_handoff.json'}
            setattr(self.suite,kind+'_handoff_path',output/'terminal_handoff.json')
        self.profile,self.user=profile,user;self.completed.append({'mode':mode,'pid':step['pid'],'nonce':step['nonce']})
        return {'mode':mode,'checks':len(expected),'token':token,'original_bytes_preserved':True,'whole_suite_qualified':False}

    def require_all(self):
        require([r['mode'] for r in self.completed]==list(MODES) and set(self.fresh)=={'first','repeat'}, 'All four actual ordered natural/restart processes required')
        for kind in ['first','repeat']:
            for row in self.fresh[kind]['journals']:self.fixed(row['path'],row['sha256'])
            for row in self.fresh[kind]['cfg_journals']:self.fixed(row['copy_path'],row['sha256'])
            self.fixed(self.fresh[kind]['handoff_path'])
