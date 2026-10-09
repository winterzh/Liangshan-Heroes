"""Strict data-only acceptance for original19 CFG evidence. Never launches native."""
import hashlib
import json
from pathlib import Path
import re
from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import no_links

ZERO = '0' * 64
CONTEXT = {'mode':'campaign', 'level_id':'level8', 'waves':0}
REQUEST = {'target_owner','content_version','engine_sha256','operation','run_token','intent_sha256'}
RECORD = REQUEST | {'schema','generation','state','transaction','original_sha256','candidate_sha256','semantics_sha256','original_owner'}
ENVELOPE = {'magic','version','app','owner','revision','previous_sha256','payload_bytes','payload_sha256','payload'}
INTENT = {'schema','token','context','profile_id','owner','content_version','engine_sha256','victory','result'}
RESULT = {'core_cleared','story_complete','story_done','story_total','done_ids','contract_version'}
TAGS = ['first_progress','best_0','best_1','best_2','best_3','legal_seed','legal_progress']
PARTIAL = ['daming_signal','daming_response']
FULL = ['daming_infiltration','daming_signal','daming_response']
UNKNOWN_TYPES = {'vector':(5,'Vector2'), 'transform':(18,'Transform3D'), 'projection':(19,'Projection'),
    'bytes':(29,'PackedByteArray'), 'integers':(31,'PackedInt64Array'), 'vectors':(38,'PackedVector4Array'),
    'colors':(37,'PackedColorArray'), 'typed_array':(28,'Array'), 'typed_dict':(27,'Dictionary'),
    'string_name':(21,'StringName'), 'node_path':(22,'NodePath'), 'nan':(3,'float'), 'inf':(3,'float'), 'negative_zero':(3,'float')}


def canonical(value):
    return json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode('utf-8')


def digest(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def hex_value(value, size=64):
    return type(value) is str and re.fullmatch('[0-9a-f]{'+str(size)+'}',value) is not None


def labels(checks, expected, case=None):
    require(type(checks) is list and len(checks)==len(expected), 'Exact complete mandatory count')
    require(all(type(row) is dict and type(row.get('label')) is str and type(row.get('ok')) is bool and row['ok'] is True for row in checks), 'Typed actual mandatory assertions')
    require([row['label'] for row in checks]==expected, 'All complete ordered mandatory labels')
    if case is not None: require(all(type(row.get('case')) is str and row['case']==case for row in checks), 'Exact native assertion case scope')


def intent(value, scope, ids, changed_context=None, core=True):
    require(type(value) is dict and set(value)==INTENT and hex_value(value['token'],32), 'Full original actual typed intent')
    require(value['schema']=='campaign_progress_intent_v1' and value['profile_id']=='campaign_level8_v1' and value['victory'] is True, 'Original intent schema profile victory')
    context = dict(CONTEXT)
    if changed_context: context.update(changed_context)
    require(value['context']==context and type(value['context']['waves']) is int, 'Exact actual request context')
    for key in ['owner','content_version','engine_sha256']: require(type(value[key]) is str and value[key]==scope[key], 'Current actual request account/source')
    result=value['result']
    require(type(result) is dict and set(result)==RESULT and result['core_cleared'] is core and result['story_complete'] is (len(ids)==3), 'Exact original outcome booleans')
    require(all(type(result[key]) is int for key in ['story_done','story_total','contract_version']) and result['story_done']==len(ids) and result['story_total']==3 and result['contract_version']==2, 'Typed current outcome counts')
    require(type(result['done_ids']) is list and all(type(x) is str for x in result['done_ids']) and result['done_ids']==ids, 'Exact actual outcome identifiers')


class DataEvidence:
    def __init__(self, suite, report, output, contract):
        self.suite, self.report, self.output, self.contract = suite, report, Path(output), contract
        self.user=Path(report['actual_user_directory']); no_links(self.user); no_links(self.output)
        self.journal=self.user/'campaign_cfg_transactions/v1/5088120/1'
        self.files=set(); self.revisions={}
        self.scope={'owner':'','content_version':suite.runtime_fields['content_version'],'engine_sha256':suite.runtime_fields['engine_binary_sha256']}

    def copy(self, row, source, name):
        require(type(row) is dict and set(row)=={'ok','source_path','copy_path','bytes','sha256'} and row['ok'] is True, 'Full native original byte declaration')
        require(type(row['bytes']) is int and 0<row['bytes']<=2*1024*1024 and hex_value(row['sha256']), 'Bounded original native evidence bytes')
        target=self.output/'cfg_evidence'/name
        declared=Path(row['copy_path']); original=Path(row['source_path'])
        require(declared.is_absolute() and original.is_absolute() and declared.resolve()==target.resolve() and original.resolve()==Path(source).resolve(), 'Exact current owned source and copy paths')
        no_links(declared); no_links(original)
        raw=self.suite.freeze_bytes(declared,row['sha256'])
        require(len(raw)==row['bytes'], 'Original native copy byte length')
        self.files.add(declared.resolve()); return raw

    def records(self, value, label, generation):
        require(type(value) is dict and value.get('ok') is True and type(value.get('head_generation')) is int and value['head_generation']==generation, 'Actual closed journal generation')
        require(Path(value['directory']).resolve()==self.journal.resolve() and value['directories']==[], 'Exact journal location and no lock/pending directories')
        entries=value['files']
        if generation==0:
            require(value['exists'] is False and entries==[], 'Genuinely absent first journal'); return
        require(value['exists'] is True and type(entries) is list and [e['name'] for e in entries]==['record_%010d.json'%g for g in [generation-1,generation]], 'Exact production two-record retained inventory')
        for entry in entries:
            g=entry['revision']; require(type(g) is int, 'Typed original journal revision')
            raw=self.copy(entry['copy'],self.journal/entry['name'],label+'_'+entry['name'])
            env=json.loads(raw)
            require(type(env) is dict and set(env)==ENVELOPE and all(type(v) is str for v in env.values()), 'Original nine-string envelope')
            previous=ZERO if g==1 else self.revisions[g-1]['sha256']
            require(env['magic']=='LH_CAMPAIGN_CFG_TRANSACTION' and env['version']=='1' and env['app']=='5088120' and env['owner']=='1' and env['revision']==str(g) and env['previous_sha256']==previous, 'Actual full available original raw journal chain')
            payload=env['payload'].encode('utf-8')
            require(env['payload_bytes']==str(len(payload)) and env['payload_sha256']==hashlib.sha256(payload).hexdigest() and canonical(env)==raw, 'Canonical original envelope payload and raw bytes')
            doc=json.loads(payload)
            require(type(doc) is dict and set(doc)==RECORD and type(doc['generation']) is int and doc['generation']==g and all(type(v) is str for k,v in doc.items() if k!='generation'), 'Complete typed CFG journal record')
            require(doc['schema']=='campaign_cfg_transaction_v1' and doc['state']==('prepared' if g%2 else 'applied') and hex_value(doc['transaction'],32), 'Actual prepared/applied journal identity')
            require(all(hex_value(doc[k]) for k in ['original_sha256','candidate_sha256','semantics_sha256','engine_sha256']) and canonical(doc)==payload, 'Original canonical typed record hashes')
            sha=hashlib.sha256(raw).hexdigest()
            require(entry['document']==doc and entry['file_sha256']==sha and entry['previous_sha256']==previous, 'Native verified document matches first original bytes')
            if g in self.revisions: require(self.revisions[g]=={'sha256':sha,'document':doc}, 'No rebasing historical revision')
            else: self.revisions[g]={'sha256':sha,'document':doc}
        require(value['head_sha256']==self.revisions[generation]['sha256'], 'Actual retained head original SHA')

    def snapshot(self, value, label, generation):
        require(type(value) is dict and value.get('ok') is True and type(value.get('exists')) is bool, 'Actual native CFG snapshot')
        self.records(value['journal'],label,generation)
        stage=value['stages']
        require(stage.get('ok') is True and type(stage.get('exists')) is bool and Path(stage['path']).resolve()==(self.user/'campaign_cfg_candidates/v1').resolve() and stage['files']==[] and stage['directories']==[], 'No unresolved candidate stage')
        if not value['exists']:
            require(generation==0 and value['sha256']==ZERO and value['bytes']==0 and value['copy']=={} and value['progress']=={} and value['type_metadata']=={} and value['semantics']=={'ok':True,'sections':{}}, 'Only genuine first missing CFG'); return
        raw=self.copy(value['copy'],self.user/'campaign.cfg',label+'_campaign.cfg')
        require(value['sha256']==hashlib.sha256(raw).hexdigest() and type(value['bytes']) is int and value['bytes']==len(raw), 'CFG model bound to original stable bytes')
        sem=value['semantics']; types=value['type_metadata']
        require(type(sem) is dict and set(sem)=={'ok','sections'} and sem['ok'] is True and type(sem['sections']) is dict and set(sem['sections'])==set(types)=={'progress','future]section'}, 'Complete original ConfigFile sections and type metadata')
        for section, keys in sem['sections'].items():
            require(type(keys) is dict and set(keys)==set(types[section]), 'Every original CFG key typed')
            for key, row in keys.items():
                require(type(row) is dict and set(row)=={'variant_type','canonical'} and type(row['variant_type']) is int and type(row['canonical']) is str and row['canonical'], 'Full canonical per-value ConfigFile semantics')
                require(type(types[section][key]) is dict and type(types[section][key]['variant_type']) is int and types[section][key]['variant_type']==row['variant_type'] and type(types[section][key]['variant_name']) is str, 'Actual complete native value type')
        require(self.revisions[generation]['document']['candidate_sha256']==value['sha256'] and self.revisions[generation]['document']['semantics_sha256']==digest(sem['sections']), 'Current physical CFG/semantic SHA bound to real applied journal')

    def progress(self, value, ids, future=False):
        progress=value['progress']; fields={'schema','owner','unlocked','records'}|({'future_progress_pref'} if future else set())
        require(type(progress) is dict and set(progress)==fields and type(progress['schema']) is int and progress['schema']==2 and type(progress['unlocked']) is int and progress['unlocked']==9 and progress['owner']==self.scope['owner'], 'Complete actual progress schema account unlock')
        records=progress['records']; require(type(records) is dict and set(records)==({'level8','level2'} if future else {'level8'}), 'Actual affected and unrelated records')
        record=records['level8']; expected={'cleared':True,'story_complete':len(ids)==3,'best_done':len(ids),'story_total':3,'best_goal_ids':ids,'contract_version':2}
        if future: expected.update(future_record_flag='keep-target',future_blob={'opaque':[1,'two']})
        require(record==expected and type(record['cleared']) is bool and type(record['story_complete']) is bool and all(type(record[k]) is int for k in ['best_done','story_total','contract_version']), 'Complete actual current single-run record')
        if future:
            require(progress['future_progress_pref']=='preserve-me' and records['level2']=={'cleared':False,'story_complete':False,'best_done':0,'story_total':0,'best_goal_ids':[],'contract_version':1,'future_record_flag':'keep-other'}, 'All original progress/affected/unrelated future data retained')

    def run(self):
        report=self.report; contract=self.contract
        require(report['trusted_scope']=={'ok':True,'context':CONTEXT,'profile_id':'campaign_level8_v1','scope':self.scope}, 'Current actual trusted pure scope')
        checks=report['checks']; labels(checks[:11],contract['data_header'],'')
        cases=report['cases']; require([c['id'] for c in cases]==contract['data_case_order'], 'All original case IDs in order')
        offset=11
        for case in cases:
            expected=contract['data_case_labels'][case['id']]; labels(case['checks'],expected,case['id'])
            require(case['passed'] is True and checks[offset:offset+len(expected)]==case['checks'], 'Actual flat and case checks identical')
            offset+=len(expected)
        labels(checks[offset:],contract['data_footer'],contract['data_case_order'][-1]); require(offset+1==len(checks)==109, 'All original109 checks retained')
        commits=report['commits']; require(type(commits) is list and [row['tag'] for row in commits]==TAGS, 'Seven actual original CFG commits')
        ids_sets=[['daming_infiltration'],['daming_infiltration'],PARTIAL,PARTIAL,PARTIAL,PARTIAL,FULL]
        intent_ids=[['daming_infiltration'],['daming_infiltration'],PARTIAL,['daming_infiltration','daming_response'],['daming_infiltration'],[],FULL]
        prior_sha=ZERO; tokens=set(); transactions=set()
        for index, row in enumerate(commits):
            tag=row['tag']; generation=2*(index+1); snapshot=row['actual']
            require(row['case']==(['true_new_missing_cfg']+['best_single_run_no_union']*4+['legal_unknown_variant_preservation']*2)[index], 'Actual commit bound to original case')
            self.snapshot(snapshot,'commit_'+tag,generation)
            request=row['request']; require(type(request) is dict and set(request)==REQUEST and all(type(v) is str for v in request.values()), 'Complete original commit request')
            require(request['target_owner']==self.scope['owner'] and request['content_version']==self.scope['content_version'] and request['engine_sha256']==self.scope['engine_sha256'], 'Original commit source/account scope')
            if tag=='legal_seed': require(row['intent']=={} and request['operation']=='prefs' and request['run_token']==request['intent_sha256']=='', 'Actual original legal preference seed')
            else:
                intent(row['intent'],self.scope,intent_ids[index]); token=row['intent']['token']; require(token not in tokens, 'Distinct actual pure intent'); tokens.add(token)
                require(request['operation']=='progress' and request['run_token']==token and request['intent_sha256']==digest(row['intent']), 'Full actual progress request bound to intent')
            receipt=row['receipt']; require(type(receipt) is dict and receipt['ok'] is True and receipt['persisted'] is True and receipt['suppressed'] is False and receipt['code']=='CAMPAIGN_CFG_READBACK_VERIFIED' and receipt['normal_process_readback'] is True and receipt['power_loss_atomicity_qualified'] is False and receipt['external_uncooperative_writer_atomic_CAS'] is False and receipt['owned_stage_cleanup']=={'ok':True}, 'Actual normal CFG confirmation and complete owned cleanup')
            require(row['original_sha256']==prior_sha and receipt['file_sha256']==snapshot['sha256'], 'Actual original source SHA and final receipt bytes')
            prepared=self.revisions[generation-1]['document']; applied=self.revisions[generation]['document']
            require(all(prepared[k]==applied[k] for k in RECORD-{'generation','state'}), 'Full prepared/applied proposal immutable')
            require(all(applied[k]==request[k] for k in REQUEST) and applied['original_sha256']==prior_sha and applied['original_owner']==self.scope['owner'] and applied['candidate_sha256']==snapshot['sha256'], 'Exact journal request/source/account and original candidate')
            require(applied['transaction']==receipt['transaction'] and receipt['transaction'] not in transactions, 'Seven distinct actual CFG transaction identities'); transactions.add(receipt['transaction'])
            self.progress(snapshot,ids_sets[index],index>=5); prior_sha=snapshot['sha256']
        require(set(self.revisions)==set(range(1,15)), 'Complete available14 original journal chain')
        generations=[(0,2),(2,10),(10,10),(10,14),(14,14),(14,14)]; previous=ZERO
        for case,(before,after) in zip(cases,generations):
            self.snapshot(case['before_CFG'],case['id']+'_before',before); self.snapshot(case['after_CFG'],case['id']+'_after',after)
            require(case['before_CFG']['sha256']==previous, 'Same actual physical prior between cases'); previous=case['after_CFG']['sha256']
        original=report['original_unknown_expectation']; seed=commits[5]['actual']; final=report['final_CFG']
        self.snapshot(final,'final',14); self.progress(final,FULL,True)
        require(original['semantics']==seed['semantics'] and original['type_metadata']==seed['type_metadata'] and original['progress']==seed['progress'], 'Original unknown values confirmed in physical seed')
        expected_keys={'sentinel'}|set(UNKNOWN_TYPES)
        require(set(original['semantics']['sections']['future]section'])==expected_keys, 'All14 original legal unknown values plus sentinel')
        for key,(kind,name) in UNKNOWN_TYPES.items():
            metadata=original['type_metadata']['future]section'][key]
            require(metadata['variant_type']==kind and metadata['variant_name']==name, 'Original legal unknown native type '+key)
        array=original['type_metadata']['future]section']['typed_array']; typed_dict=original['type_metadata']['future]section']['typed_dict']
        require(array['array_builtin']==4 and array['array_class']=='' and array['array_script_null'] is True and typed_dict['key_builtin']==4 and typed_dict['value_builtin']==5 and typed_dict['key_class']==typed_dict['value_class']=='' and typed_dict['key_script_null'] is typed_dict['value_script_null'] is True, 'Original typed builtin containers retained')
        require(final['semantics']['sections']['future]section']==original['semantics']['sections']['future]section'] and final['type_metadata']['future]section']==original['type_metadata']['future]section'], 'Complete original unknown canonical data and types retained')
        require(final['semantics']['sections']['progress']['future_progress_pref']==original['semantics']['sections']['progress']['future_progress_pref'], 'Original unknown progress key semantics retained')
        refusals=report['invalid_refusals']; require(type(refusals) is list and len(refusals)==4, 'All actual original refusal requests')
        before=cases[2]['before_CFG']; after=cases[2]['after_CFG']; require(before['sha256']==after['sha256'], 'No actual invalid CFG write')
        variants=[({'mode':'custom'},True,['daming_signal']),({'level_id':'unknown'},True,['daming_signal']),(None,False,['daming_signal']),(None,True,['d'])]
        codes=['CAMPAIGN_INTENT_CONTEXT','CAMPAIGN_INTENT_CONTEXT','CAMPAIGN_INTENT_OUTCOME_MISMATCH','CAMPAIGN_INTENT_IDS']
        for index,(row,(context,core,ids),code) in enumerate(zip(refusals,variants,codes)):
            require(type(row['index']) is int and row['index']==index and type(row['refusal']) is dict and set(row['refusal'])=={'ok','code'} and row['refusal']['ok'] is False and row['refusal']['code']==code, 'Exact original invalid outcome')
            intent(row['request'],self.scope,ids,context,core)
            require(row['before_CFG_sha256']==row['after_CFG_sha256']==before['sha256'], 'Invalid request bound to actual original physical CFG')
        self.suite.freeze_bytes(self.user/'campaign.cfg',final['sha256'])
        require({p.name for p in self.journal.iterdir()}=={'record_0000000013.json','record_0000000014.json'}, 'Actual retained production pair only; no extra/pending/lock files')
        for generation in [13,14]: self.suite.freeze_bytes(self.journal/('record_%010d.json'%generation),self.revisions[generation]['sha256'])
        stage_dir=self.user/'campaign_cfg_candidates/v1'; no_links(stage_dir)
        require(stage_dir.is_dir() and not list(stage_dir.iterdir()), 'Independent final candidate stage inventory empty')
        evidence_dir=self.output/'cfg_evidence'; no_links(evidence_dir)
        actual_files={p.resolve() for p in evidence_dir.iterdir()}; require(actual_files==self.files and len(self.files)==57 and all(p.is_file() for p in actual_files), 'Exact57 controlled raw evidence copies with no foreign entries')
        return {'original_checks':109,'original_commits':7,'archived_available_generations':14,'retained_final_generations':[13,14],'fixed_raw_evidence_files':57}
