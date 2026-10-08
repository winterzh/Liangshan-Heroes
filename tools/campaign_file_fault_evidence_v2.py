"""Complete six-case report, first-byte handoff and physical journal consumer.

No launcher or execution admission. A reviewed producer must supply the actual
phase/export records and complete original source identity evidence suite.
"""
import hashlib
import json
from pathlib import Path
import struct

from campaign_file_fault_records_v1 import decode_envelope, cfg_document, hex_value, ZERO
from campaign_original19_debug_faults_v5 import typed_equal
from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import no_links
from godot_debug_wire import decode, stack_frames, MAX_PACKET

CONTEXT={'mode':'campaign','level_id':'level1','waves':0}
LIFE_FIELDS={'schema','generation','token','context','scope','state','victory','progress_state','intent','progress_receipt'}
PENDING_FIELDS={'case','code','coordinator_id','writer_id','lifecycle_id','proposal_id','proposal_semantics','proposal_semantics_sha256','intent',
                'gen1_sha256','gen2_sha256','actual_memory','actual_cloud','writer_stage','prior_CFG_sha256','injection_sha256'}


def digest(value):
    return hashlib.sha256(json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode('utf-8')).hexdigest()


def labels(rows, expected):
    require(type(rows) is list and len(rows)==len(expected), 'Complete native check count')
    require(all(type(r) is dict and set(r)=={'label','ok','detail'} and type(r['label']) is str and r['ok'] is True for r in rows), 'All exact native check rows passed')
    require([r['label'] for r in rows]==expected, 'Exact ordered labels with all repeated route/actions')


def validate_intent(value,token,scope):
    require(type(value) is dict and set(value)=={'schema','token','context','profile_id','owner','content_version','engine_sha256','victory','result'}, 'Complete frozen natural intent fields')
    require(value['schema']=='campaign_progress_intent_v1' and value['token']==token and hex_value(token,32)
            and typed_equal(value['context'],CONTEXT) and value['profile_id']=='campaign_level1_v1' and value['victory'] is True, 'Actual same full natural campaign intent')
    require(all(type(value[k]) is str and value[k]==v for k,v in scope.items()), 'Actual natural source/account scope')
    result=value['result'];require(type(result) is dict and set(result)=={'core_cleared','story_complete','story_done','story_total','done_ids','contract_version'}, 'Full original result fields')
    require(result['core_cleared'] is True and result['story_complete'] is True
            and all(type(result[k]) is int for k in ['story_done','story_total','contract_version'])
            and result['story_done']==result['story_total']==4 and result['contract_version']==2
            and type(result['done_ids']) is list and len(result['done_ids'])==4 and all(type(x) is str for x in result['done_ids'])
            and set(result['done_ids'])=={'merchant_cover','wine_scheme','no_bloodshed','all_safe'}, 'All four actual natural goals, no partial/union substitution')


class FileFaultEvidence:
    def __init__(self,suite,contract,manifest):
        self.suite,self.contract,self.manifest=suite,contract,manifest;self.fresh={};self.completed={}
        require(contract['case_ids']==manifest['case_ids'] and contract['identity_fields_order']==list(suite.runtime_fields), 'Exact six case and installed field order')
        require(contract['actual_flow_fault_codes']=={case:manifest['actual_debugger_windows'][case]['code'] for case in contract['case_ids']}, 'Actual outer Flow failure-code contract')

    def fixed(self,path,expected=None):return self.suite.freeze_bytes(Path(path),expected)
    def read(self,path):return self.suite.read_fixed(Path(path))

    def owned_copy(self,path,output):
        require(type(path) is str, 'Exact original evidence path string');p=Path(path);no_links(p)
        require(p.is_absolute() and p.resolve().is_relative_to(output.resolve()), 'Original evidence copy belongs to this phase')
        return p

    def exports(self,step,mode):
        output=Path(step['output']);rows=step.get('actual_native_exports')
        expected={'report.json','restart_handoff.json'} if mode=='restart' else {'ready_for_terminal.json','file_fault_ready.json','file_fault_pending.json','terminal_handoff.json','report.json'}
        require(type(rows) is dict and set(rows)==expected, 'All actual closed native exports present')
        for name,row in rows.items():
            require(type(row) is dict and set(row)=={'native_stage','published_path','bytes','sha256','pid','nonce'}
                    and type(row['pid']) is int and row['pid']==step['pid'] and row['nonce']==step['nonce']
                    and type(row['bytes']) is int and 0<row['bytes']<=2*1024*1024 and hex_value(row['sha256']), 'Actual native export identity/first SHA/size')
            require(Path(row['native_stage'])==output/(name+'.native-'+step['nonce']) and Path(row['published_path'])==output/name, 'Fixed same-phase original/public export paths')
            require(self.fixed(row['native_stage'],row['sha256'])==self.fixed(row['published_path'],row['sha256']), 'Native closed bytes and published bytes exact')

    def lifecycle(self,user,token):
        require(hex_value(token,32), 'Exact natural token before any filesystem lookup')
        parent=user/'continue/v1/local_runs';no_links(parent)
        require({p.name for p in parent.iterdir()}=={token}, 'Only actual natural token in private profile')
        directory=parent/token/'5088120/1';no_links(directory)
        require({p.name for p in directory.iterdir()}=={'record_%010d.json'%g for g in [1,2,3]}, 'Exactly three lifecycle generations, no pending/lock')
        scope={'owner':'','content_version':self.suite.runtime_fields['content_version'],'engine_sha256':self.suite.runtime_fields['engine_binary_sha256']}
        rows=[];previous=ZERO;intent=None
        for generation in [1,2,3]:
            path=directory/('record_%010d.json'%generation);raw=self.fixed(path);document=decode_envelope(raw,'LH_LOCAL_CONTINUE_LIFECYCLE',generation,previous)
            require(set(document)==LIFE_FIELDS and document['schema']=='local_campaign_continue_lifecycle_v2' and document['token']==token
                    and typed_equal(document['context'],CONTEXT) and typed_equal(document['scope'],scope), 'Complete same-source typed lifecycle')
            if generation==1:
                require(document['state']=='active' and document['victory'] is False and document['progress_state']=='none'
                        and typed_equal(document['intent'],{}) and typed_equal(document['progress_receipt'],{}), 'Original active genesis')
            else:
                validate_intent(document['intent'],token,scope)
                require(document['state']=='terminal' and document['victory'] is True and document['progress_state']==('pending' if generation==2 else 'applied'), 'Actual natural pending/applied transition')
                if generation==2:intent=document['intent'];require(typed_equal(document['progress_receipt'],{}), 'Original pending has no ACK')
                else:require(typed_equal(document['intent'],intent), 'Same whole frozen intent after real retry')
            previous=hashlib.sha256(raw).hexdigest();rows.append({'path':str(path),'sha256':previous,'document':document})
        ack=rows[2]['document']['progress_receipt'];require(type(ack) is dict and set(ack)=={'schema','code','persisted','suppressed','file_sha256'}
            and ack['schema']=='campaign_progress_ack_v1' and ack['code']=='CAMPAIGN_CFG_READBACK_VERIFIED'
            and ack['persisted'] is True and ack['suppressed'] is False and hex_value(ack['file_sha256']), 'Complete five-field physical CFG ACK')
        self.fixed(user/'campaign.cfg',ack['file_sha256'])
        return rows,intent,ack['file_sha256']

    def seed_and_final_cfg(self,output,user,injection,intent,cfg_sha):
        seed=injection['actual_seed_CFG'];directory=user/'campaign_cfg_transactions/v1/5088120/1';no_links(directory)
        require(Path(seed['directory'])==directory and type(seed['records']) is list and len(seed['records'])==2, 'Original seeded CFG journal source and two copies')
        seed_sha=seed['public_CFG_sha256'];require(hex_value(seed_sha), 'Actual original public CFG SHA')
        seed_cfg=self.owned_copy(seed['public_CFG_copy'],output)
        require(seed_cfg==output/'seed_cfg_evidence/seed_campaign.cfg', 'Fixed original seed CFG copy')
        self.fixed(seed_cfg,seed_sha);previous=ZERO;documents=[];seed_transaction=None
        require({p.name for p in seed_cfg.parent.iterdir()}=={'seed_campaign.cfg','record_0000000001.json','record_0000000002.json'}, 'Exactly three original seed evidence files')
        for generation in [1,2]:
            row=seed['records'][generation-1];original=directory/('record_%010d.json'%generation)
            copy=self.owned_copy(row['copy_path'],output);require(Path(row['original_path'])==original and copy==output/'seed_cfg_evidence'/original.name, 'Original named CFG seed generation')
            raw=self.fixed(copy,row['sha256']);document=decode_envelope(raw,'LH_CAMPAIGN_CFG_TRANSACTION',generation,previous)
            cfg_document(document,generation,self.suite.runtime_fields,'prefs','','',ZERO,seed_sha)
            require(typed_equal(document,row['document']), 'Original seed document bound to original raw bytes')
            if generation==1:seed_transaction=document['transaction']
            else:require(document['transaction']==seed_transaction, 'Same real preference prepared/applied transaction')
            documents.append(document);previous=hashlib.sha256(raw).hexdigest()
        require(typed_equal({k:v for k,v in documents[0].items() if k not in ['generation','state']},
                            {k:v for k,v in documents[1].items() if k not in ['generation','state']}), 'Seed pair differs only generation/state')
        require({p.name for p in directory.iterdir()}=={'record_0000000003.json','record_0000000004.json'}, 'Actual production retained final CFG pair only')
        final=[]
        for generation in [3,4]:
            path=directory/('record_%010d.json'%generation);raw=self.fixed(path)
            document=decode_envelope(raw,'LH_CAMPAIGN_CFG_TRANSACTION',generation,previous)
            cfg_document(document,generation,self.suite.runtime_fields,'progress',intent['token'],digest(intent),seed_sha,cfg_sha)
            require(document['transaction']!=seed_transaction, 'Actual progress transaction distinct from seed')
            previous=hashlib.sha256(raw).hexdigest();final.append({'path':str(path),'sha256':previous,'document':document})
        require(typed_equal({k:v for k,v in final[0]['document'].items() if k not in ['generation','state']},
                            {k:v for k,v in final[1]['document'].items() if k not in ['generation','state']}), 'Final prepared/applied complete proposal unchanged')
        stage=user/'campaign_cfg_candidates/v1';no_links(stage);require(stage.is_dir() and not list(stage.iterdir()), 'Actual completed candidate stage empty')
        return final

    def injection_details(self,step,output,user,case,injection,pending,repair,journals,cfg_sha,cfg_journals):
        window=self.manifest['actual_debugger_windows'][case];frames=injection['actual_debugger_stack']
        require(type(frames) is list and frames and typed_equal(frames[0],{k:window['stop'][k] for k in ['source','line','function']})
                and typed_equal(injection['source_window'],window['stop']), 'Exact pinned actual production fault window')
        for source,function in [('res://scripts/run_campaign_progress_coordinator.gd','_drive_cfg'),
                                ('res://scripts/run_campaign_progress_coordinator.gd','retry'),('res://scripts/continue_flow.gd','_commit_terminal')]:
            require(any(f['source']==source and f['function']==function for f in frames), 'Complete actual coordinator/terminal stack')
        if 'immediate_caller' in window:
            require(len(frames)>1 and frames[1]['source']=='res://scripts/run_campaign_cfg_transaction.gd' and frames[1]['function']==window['immediate_caller'], 'Exact actual fresh-load caller')
        transcript=self.fixed(output/'debugger_packets.bin',step['debugger_transcript_sha256'])
        offset=0;pids=[];matches=[]
        while offset<len(transcript):
            require(offset+4<=len(transcript), 'Complete original packet size prefix')
            size=struct.unpack('<I',transcript[offset:offset+4])[0];offset+=4
            require(4<=size<=MAX_PACKET and offset+size<=len(transcript), 'Bounded complete original native packet')
            message=decode(transcript[offset:offset+size]);offset+=size
            require(type(message) is list and len(message)==3 and type(message[0]) is str and type(message[1]) is int and type(message[2]) is list, 'Original debugger message schema')
            if message[0]=='set_pid':pids.append(message[2])
            if message[0]=='stack_dump' and typed_equal(stack_frames(message[2]),frames):matches.append(message)
        require(len(pids)==1 and typed_equal(pids[0],[step['pid']]) and len(matches)==1, 'Original native PID packet and unique exact raw stack packet')
        actual_life=injection['actual_lifecycle'];require(actual_life['token']==journals[1]['document']['token']
                and Path(actual_life['directory'])==Path(journals[0]['path']).parent and type(actual_life['records']) is list and len(actual_life['records'])==2, 'Original injected same two-generation lifecycle')
        for actual,final in zip(actual_life['records'],journals[:2]):require(typed_equal(actual,final), 'Original two lifecycle bytes/documents preserved through retry')
        mutation=injection['mutation'];require(type(mutation) is dict and set(mutation)=={'target','original_bytes','original_sha256','after_kind','after_sha256','backup_file','backup_sha256'}, 'Complete original filesystem mutation evidence')
        prior=case in self.contract['case_ids'][:2]
        target=user/'campaign.cfg' if prior else user/'campaign_cfg_candidates/v1'/cfg_journals[0]['document']['transaction']/'candidate.cfg'
        require(Path(mutation['target'])==target and Path(repair['target'])==target, 'Only same original private target repaired')
        if case=='write_failure':
            require(type(mutation['original_bytes']) is int and mutation['original_bytes']==0 and mutation['original_sha256'] is None
                    and mutation['after_kind']=='empty_directory' and mutation['after_sha256'] is None and mutation['backup_file'] is None
                    and mutation['backup_sha256'] is None and repair['restored_sha256'] is None, 'Actual absent destination empty-directory denial/repair')
        else:
            backup=self.owned_copy(mutation['backup_file'],output);require(backup==output/'fault_original.bin', 'Exact first original private backup')
            original=self.fixed(backup,mutation['backup_sha256']);original_sha=hashlib.sha256(original).hexdigest()
            require(type(mutation['original_bytes']) is int and len(original)==mutation['original_bytes']
                    and mutation['original_sha256']==original_sha==repair['restored_sha256']
                    and original_sha==(pending['prior_CFG_sha256'] if prior else cfg_sha), 'Original source bytes restored; same frozen candidate becomes actual CFG')
            if case in ['existing_vanished_prior','save_OK_fresh_load_failure']:
                require(mutation['after_kind']=='absent' and mutation['after_sha256'] is None, 'Only exact owned original file absence')
            else:
                changed=b'[broken' if case=='bad_existing_cfg_load' else original+(b'\n[owned_fault_probe]\nnonce="'+step['nonce'].encode()+b'"\n' if case=='readback_semantic_mismatch' else b'\n;owned_comment_fault_'+step['nonce'].encode()+b'\n')
                require(mutation['after_kind']=='file' and mutation['after_sha256']==hashlib.sha256(changed).hexdigest(), 'Exact declared native malformed/data/comment fault bytes')
        require(type(pending['proposal_id']) is int and type(pending['writer_stage']) is str, 'Exact native proposal/stage types')
        if prior:require(pending['proposal_id']==0 and pending['writer_stage']=='' and typed_equal(pending['proposal_semantics'],{}) and pending['proposal_semantics_sha256']=='', 'Unprepared writer retained no false proposal/hash')
        else:
            require(pending['proposal_id']!=0 and pending['writer_stage']=='staging' and type(pending['proposal_semantics']) is dict
                    and set(pending['proposal_semantics'])=={'ok','sections'} and pending['proposal_semantics']['ok'] is True
                    and type(pending['proposal_semantics']['sections']) is dict, 'Real supported retained frozen proposal')
            require(hex_value(pending['proposal_semantics_sha256']) and all(row['document']['semantics_sha256']==pending['proposal_semantics_sha256'] for row in cfg_journals), 'Actual final CFG journal pair bound to original native proposal semantics hash')
        lock=injection['actual_seed_CFG']['owned_lock'];require(type(lock) is dict and set(lock)=={'version','owner','pid','token'}
                and all(type(v) is str for v in lock.values()) and lock['version']=='1' and lock['owner']=='1'
                and lock['pid']==str(step['pid']) and hex_value(lock['token'],32), 'Same actual held writer source/PID lock')

    def validate(self,step,mode,case):
        require(any(s is step for s in self.suite.batch.steps) and case in self.contract['case_ids'] and mode in ['fresh','restart'], 'Actual owned case/phase identity')
        require(step['process_terminal'] is True and type(step['exit_code']) is int and step['exit_code']==0
                and type(step['pid']) is int and step['pid']>0 and hex_value(step['nonce'],32), 'Actual terminal native process binding')
        expected_errors=1 if mode=='fresh' and case=='bad_existing_cfg_load' else 0
        require(type(step['engine_errors']) is int and step['engine_errors']==expected_errors, 'Precise actual native diagnostic count')
        env=step['environment_overrides'];require(env.get('CAMPAIGN_FILE19_CASE')==case and env.get('CAMPAIGN_TERMINAL_MODE')==mode
                and env.get('CAMPAIGN_TERMINAL_OUTPUT')==step['output'] and env.get('CAMPAIGN_TERMINAL_PROFILE')==step['profile']
                and env.get('CAMPAIGN_TERMINAL_NONCE')==step['nonce'] and env.get('STEAM_DISABLED')=='1'
                and env.get('CAMPAIGN_QA','')=='', 'Actual normal-mode native launch environment closes phase identity')
        self.exports(step,mode);output=Path(step['output']);report=self.read(output/'report.json')
        require(type(report) is dict and set(report)=={'schema','passed','checks','failures','observations','pid','nonce','mode','orders','identity','user_directory','time_scale','physics_ticks','scope','all_roles_ABCD_qualified','original19_faults_qualified','fault_case','same_object_retry_verified','actual_pending_fault','pending_failure_UI_qualified','Steam_rewards_qualified'}, 'Complete native report fields')
        require(report['schema']=='campaign_original19_natural_file_fault_probe_v2' and report['passed'] is True
                and typed_equal(report['failures'],[]) and type(report['pid']) is int and report['pid']==step['pid']
                and report['nonce']==step['nonce'] and report['mode']==mode and report['fault_case']==case, 'Actual complete native report/phase/case')
        expected=self.contract['fresh_labels_by_case'][case] if mode=='fresh' else self.contract['restart_labels'];labels(report['checks'],expected)
        log=self.fixed(output/'native.log',step['log_sha256']).decode('utf-8')
        marker='CAMPAIGN_ORIGINAL19_NATURAL_FILE_FAULT '+case+' '+mode+' true '+str(len(expected))
        require(log.splitlines().count(marker)==1, 'Exact single actual successful terminal marker')
        require(type(report['time_scale']) in [int,float] and report['time_scale']==1 and type(report['physics_ticks']) is int and report['physics_ticks']==60
                and all(report[k] is False for k in ['all_roles_ABCD_qualified','original19_faults_qualified','pending_failure_UI_qualified','Steam_rewards_qualified']), 'Normal native clock and exact limited scope')
        require(report['scope']=='One ordinary fresh Huangnigang natural terminal and production startup recovery; isolated Steam disabled.' and type(report['observations']) is list, 'Exact declared report scope/observations')
        for field,value in self.suite.runtime_fields.items():require(typed_equal(report['identity'][field],value), 'Complete actual installed identity field')
        user=Path(report['user_directory']);no_links(user);require(user.is_absolute() and user.resolve().is_relative_to((Path(step['profile'])/'appdata').resolve()), 'Only current owned native userdata')
        handoff=self.read(output/('terminal_handoff.json' if mode=='fresh' else 'restart_handoff.json'));token=handoff['token']
        journals,intent,cfg_sha=self.lifecycle(user,token)
        require(type(handoff['pid']) is int and handoff['pid']==step['pid'] and handoff['nonce']==step['nonce'] and handoff['cfg_sha256']==cfg_sha
                and typed_equal(handoff['intent'],intent) and typed_equal(handoff['files'],{Path(r['path']).name:r['sha256'] for r in journals}), 'Actual terminal handoff closes all original bytes and intent')
        if mode=='restart':
            require(case in self.fresh and case not in self.completed and report['same_object_retry_verified'] is False and typed_equal(report['actual_pending_fault'],{})
                    and type(report['orders']) is int and report['orders']==0 and handoff['schema']=='campaign_natural_terminal_restart_v1', 'Exactly one ordinary no-fault restart after fresh')
            require(type(handoff['startup_result']['progress_recovered']) is int and handoff['startup_result']['progress_recovered']==0
                    and handoff['startup_result']['settlement_authorized'] is False, 'No replayed settlement or recovery')
            original=self.fresh[case];require(typed_equal(journals,original['journals']) and cfg_sha==original['cfg_sha256'] and user==original['user'], 'Same original lifecycle/CFG/profile bytes across restart')
            require(step['pid']!=original['pid'] and step['nonce']!=original['nonce'] and env.get('CAMPAIGN_TERMINAL_TOKEN')==token and env.get('CAMPAIGN_TERMINAL_EXPECT_RECOVERY')=='0', 'Separate actual process/nonce; same token ordinary restart')
            for row in original['cfg_journals']:self.fixed(row['path'],row['sha256'])
            self.completed[case]=True;return {'case':case,'mode':mode,'checks':len(expected),'original_bytes_preserved':True}
        require(case not in self.fresh and report['same_object_retry_verified'] is True and type(report['orders']) is int and report['orders']==19
                and handoff['schema']=='campaign_natural_terminal_handoff_v1' and typed_equal(handoff['context'],CONTEXT)
                and typed_equal(handoff['identity'],report['identity']), 'Actual fresh natural route and same-object retry')
        ready=self.read(output/'ready_for_terminal.json');fault_ready=self.read(output/'file_fault_ready.json')
        labels(ready['checks'],self.contract['preterminal_ready_labels']);require(typed_equal(report['checks'][:len(ready['checks'])],ready['checks']), 'Full actual preterminal check prefix unchanged')
        for data in [ready,fault_ready]:
            require(type(data['pid']) is int and data['pid']==step['pid'] and data['nonce']==step['nonce'] and type(data['orders']) is int and data['orders']==11
                    and typed_equal(data['identity'],report['identity']), 'Actual original preterminal native identities/orders')
        require(ready['schema']=='campaign_natural_terminal_ready_v1' and type(ready['delivered']) is int and ready['delivered']==3 and type(ready['phase']) is int and ready['phase']==2 and typed_equal(ready['fresh_context'],CONTEXT)
                and Path(ready['actual_user_directory'])==user and fault_ready['schema']=='campaign_natural_file_fault_ready_v1' and fault_ready['case']==case
                and type(fault_ready['battle_phase']) is int and fault_ready['battle_phase']==2 and typed_equal(fault_ready['context'],CONTEXT)
                and Path(fault_ready['user_directory'])==user, 'Original actual level1 FIGHT route and three delivered loads')
        injection=self.read(output/'fault_injection.json');pending=self.read(output/'file_fault_pending.json');repair=self.read(output/'fault_repaired.json')
        require(injection['schema']=='campaign_file_fault_actual_injection_v1' and type(injection['pid']) is int and injection['pid']==step['pid']
                and injection['nonce']==step['nonce'] and injection['case']==case and Path(injection['actual_user_directory'])==user, 'Actual original debugger injection identity')
        require(typed_equal(pending,report['actual_pending_fault']) and type(pending) is dict and set(pending)==PENDING_FIELDS, 'Complete actual retained-object pending report')
        require(pending['case']==case and pending['code']==self.manifest['actual_debugger_windows'][case]['code'] and typed_equal(pending['intent'],intent)
                and pending['gen1_sha256']==journals[0]['sha256'] and pending['gen2_sha256']==journals[1]['sha256']
                and typed_equal(pending['actual_memory'],fault_ready['original_progress']) and typed_equal(pending['actual_cloud'],fault_ready['original_cloud']), 'Actual original pending intent/old memory/cloud/gen1/gen2')
        for key in ['coordinator_id','writer_id','lifecycle_id']:require(type(pending[key]) is int and pending[key]!=0, 'Actual retained RefCounted identifiers including negative IDs')
        injection_sha=hashlib.sha256(self.fixed(output/'fault_injection.json')).hexdigest()
        require(pending['injection_sha256']==injection_sha and repair['schema']=='campaign_file_fault_actual_repair_v1' and type(repair['pid']) is int and repair['pid']==step['pid']
                and repair['nonce']==step['nonce'] and repair['case']==case and repair['injection_sha256']==injection_sha
                and repair['pending_sha256']==hashlib.sha256(self.fixed(output/'file_fault_pending.json')).hexdigest(), 'First native injection/pending/repair byte chain')
        require(injection['ready_sha256']==hashlib.sha256(self.fixed(output/'file_fault_ready.json')).hexdigest()
                and pending['prior_CFG_sha256']==fault_ready['prior_CFG_sha256']==injection['actual_seed_CFG']['public_CFG_sha256'], 'Original prior seed SHA and ready closure')
        cfg_journals=self.seed_and_final_cfg(output,user,injection,intent,cfg_sha)
        self.injection_details(step,output,user,case,injection,pending,repair,journals,cfg_sha,cfg_journals)
        require(type(injection['monotonic_ns']) is int and type(repair['monotonic_ns']) is int and 0<injection['monotonic_ns']<repair['monotonic_ns'], 'Original owned injection precedes exact repair')
        require(not any(value['user']==user or value['journals'][1]['document']['token']==token for value in self.fresh.values()), 'Each case has fresh independent profile and token')
        self.fresh[case]={'user':user,'journals':journals,'cfg_sha256':cfg_sha,'cfg_journals':cfg_journals,'pid':step['pid'],'nonce':step['nonce']}
        return {'case':case,'mode':mode,'checks':len(expected),'token':token,'original_seed_and_final_CFG_generations':[1,2,3,4]}

    def require_all(self):
        require(set(self.completed)==set(self.contract['case_ids']) and len(self.completed)==6, 'All six real fresh/restart case pairs required')
