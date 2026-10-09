"""Owned read-only debugger observation and exact private CFG fault mutation.

No process launch, native entry point, or execution admission. A reviewed serial
native owner must provide its live Popen and first-byte evidence suite.
"""
import hashlib
import json
import re
import subprocess
from pathlib import Path
import time
from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import no_links
from campaign_original19_atomic_files_v1 import publish_new
from godot_debug_wire import stack_frames
from campaign_file_fault_records_v1 import decode_envelope, cfg_document, ZERO

TXN='res://scripts/run_campaign_cfg_transaction.gd'
COORD='res://scripts/run_campaign_progress_coordinator.gd'
FLOW='res://scripts/continue_flow.gd'


def typed_equal(left, right):
    if type(left) is not type(right): return False
    if type(left) is dict:
        return set(left)==set(right) and all(type(k) is str and typed_equal(left[k],right[k]) for k in left)
    if type(left) is list:
        return len(left)==len(right) and all(typed_equal(a,b) for a,b in zip(left,right))
    return type(left) in (str,int,float,bool,type(None)) and left==right


class FaultController:
    def __init__(self, suite, child, step, case, source_manifest):
        require(case in source_manifest['case_ids'] and isinstance(child,subprocess.Popen) and suite.batch.child is child and child.poll() is None and type(child.pid) is int and child.pid==step['pid'], 'Actual owned live native Popen required')
        self.suite,self.child,self.step,self.case=suite,child,step,case
        self.output=Path(step['output']); self.profile=Path(step['profile'])
        no_links(self.output); no_links(self.profile)
        require(self.output.resolve().is_relative_to(suite.run.resolve()) and self.profile.resolve().is_relative_to((suite.run/'profiles').resolve()), 'Current owned serial phase boundaries')
        self.window=source_manifest['actual_debugger_windows'][case]
        self.armed=False; self.entered=None; self.injection=None; self.backup=None; self.target=None
        self.original=None; self.changed=None; self.directory_identity=None; self.repaired=False
        self.ready_original=None; self.life_original=None; self.user=None

    def live(self):
        require(self.suite.batch.child is self.child and self.child.pid==self.step['pid'] and self.child.poll() is None, 'Original owned process must still be live')

    def handle(self, peer, message):
        self.live(); name,thread,data=message
        require(type(thread) is int, 'Actual debugger thread identity')
        if name=='set_pid':
            require(data==[self.child.pid] and not self.armed, 'Exact first native debugger PID')
            stop=self.window['stop']; peer.command('breakpoint',thread,[stop['source'],stop['line'],True]); self.armed=True
        elif name=='debug_enter':
            require(self.armed and self.entered is None and type(data) is list and len(data)==4 and data[:3]==[True,'Breakpoint',True] and type(data[3]) is int and data[3]==thread, 'Exact actual native breakpoint entry')
            self.entered=thread; peer.command('get_stack_dump',thread)
        elif name=='stack_dump':
            require(self.entered==thread, 'Stack dump from entered owned thread only')
            frames=stack_frames(data); stop=self.window['stop']
            require(frames and frames[0]=={k:stop[k] for k in ['source','line','function']}, 'Exact pinned production fault source window')
            expected=self.window.get('immediate_caller')
            matches=(not expected or (len(frames)>1 and frames[1]['source']==TXN and frames[1]['function']==expected))
            matches=matches and any(f['source']==COORD and f['function']=='_drive_cfg' for f in frames)
            matches=matches and any(f['source']==COORD and f['function']=='retry' for f in frames)
            matches=matches and any(f['source']==FLOW and f['function']=='_commit_terminal' for f in frames)
            if matches:
                require(self.injection is None, 'Only one actual owned fault injection')
                self.inject(frames)
                peer.command('breakpoint',thread,[stop['source'],stop['line'],False])
            # Real preference seed/prior reads are resumed unchanged.
            peer.command('continue',thread); self.entered=None

    def ready(self):
        ready=self.suite.read_fixed(self.output/'file_fault_ready.json')
        require(ready['schema']=='campaign_natural_file_fault_ready_v1' and type(ready['pid']) is int and ready['pid']==self.child.pid and ready['nonce']==self.step['nonce'] and ready['case']==self.case, 'Actual natural fault-ready identity')
        user=Path(ready['user_directory']); no_links(user)
        require(user.is_absolute() and user.resolve().is_relative_to((self.profile/'appdata').resolve()) and typed_equal(ready['context'],{'mode':'campaign','level_id':'level1','waves':0}), 'Actual current natural campaign user scope')
        for key,value in self.suite.runtime_fields.items(): require(type(ready['identity'].get(key)) is type(value) and ready['identity'][key]==value, 'Actual current installed source identity')
        require(type(ready['orders']) is int and ready['orders']>0 and type(ready['prior_CFG_sha256']) is str and len(ready['prior_CFG_sha256'])==64, 'Actual natural orders and seeded private CFG')
        return ready,user

    def lifecycle(self, user):
        parent=user/'continue/v1/local_runs'; no_links(parent)
        children=list(parent.iterdir())
        require(len(children)==1 and children[0].is_dir() and re.fullmatch('[0-9a-f]{32}',children[0].name), 'Exactly one actual natural local run token')
        token=children[0].name; directory=children[0]/'5088120/1'; no_links(directory)
        require(directory.is_dir() and {p.name for p in directory.iterdir()}=={'record_0000000001.json','record_0000000002.json'}, 'Actual terminal has exact gen1/gen2 and no gen3/lock/pending')
        records=[]; previous='0'*64
        for generation in [1,2]:
            path=directory/('record_%010d.json'%generation); raw=self.suite.freeze_bytes(path)
            env=json.loads(raw)
            require(type(env) is dict and set(env)=={'magic','version','app','owner','revision','previous_sha256','payload_bytes','payload_sha256','payload'} and all(type(v) is str for v in env.values()), 'Actual nine-string lifecycle envelope')
            require(env['magic']=='LH_LOCAL_CONTINUE_LIFECYCLE' and env['version']=='1' and env['app']=='5088120' and env['owner']=='1' and env['revision']==str(generation) and env['previous_sha256']==previous, 'Actual original lifecycle identity and available chain')
            payload=env['payload'].encode('utf-8'); require(env['payload_bytes']==str(len(payload)) and env['payload_sha256']==hashlib.sha256(payload).hexdigest(), 'Actual original lifecycle payload bytes')
            doc=json.loads(payload)
            require(type(doc) is dict and set(doc)=={'schema','generation','token','context','scope','state','victory','progress_state','intent','progress_receipt'} and type(doc['generation']) is int and doc['generation']==generation and doc['schema']=='local_campaign_continue_lifecycle_v2' and doc['token']==token, 'Current complete typed lifecycle')
            require(typed_equal(doc['context'],{'mode':'campaign','level_id':'level1','waves':0}) and typed_equal(doc['scope'],{'owner':'','content_version':self.suite.runtime_fields['content_version'],'engine_sha256':self.suite.runtime_fields['engine_binary_sha256']}), 'Actual current natural context/source/account')
            if generation==1:
                require(doc['state']=='active' and doc['victory'] is False and doc['progress_state']=='none' and doc['intent']=={} and doc['progress_receipt']=={}, 'Original active genesis')
            else:
                require(doc['state']=='terminal' and doc['victory'] is True and doc['progress_state']=='pending' and doc['progress_receipt']=={}, 'Actual same natural terminal without acknowledgement')
                intent=doc['intent']; require(type(intent) is dict and set(intent)=={'schema','token','context','profile_id','owner','content_version','engine_sha256','victory','result'} and intent['schema']=='campaign_progress_intent_v1' and intent['token']==token and typed_equal(intent['context'],doc['context']) and intent['profile_id']=='campaign_level1_v1' and intent['victory'] is True, 'Actual frozen natural intent')
                for key in doc['scope']: require(type(intent[key]) is str and intent[key]==doc['scope'][key], 'Actual intent installed/account scope')
                result=intent['result']; require(type(result) is dict and set(result)=={'core_cleared','story_complete','story_done','story_total','done_ids','contract_version'} and result['core_cleared'] is True and result['story_complete'] is True and all(type(result[k]) is int for k in ['story_done','story_total','contract_version']) and result['story_done']==result['story_total']==4 and result['contract_version']==2, 'Actual four current natural goals')
                require(type(result['done_ids']) is list and len(result['done_ids'])==4 and all(type(x) is str for x in result['done_ids']) and set(result['done_ids'])=={'merchant_cover','wine_scheme','no_bloodshed','all_safe'}, 'All real Huangnigang goal identifiers')
            previous=hashlib.sha256(raw).hexdigest(); records.append({'path':str(path),'sha256':previous,'document':doc})
        return {'token':token,'directory':str(directory),'records':records}

    def original_bytes(self, path, expected=None):
        no_links(path); require(path.is_file(), 'Only actual current owned file')
        size=path.stat().st_size; require(0<size<=2*1024*1024, 'Bounded original CFG size before reading')
        raw=path.read_bytes(); first_sha=hashlib.sha256(raw).hexdigest()
        require(len(raw)==size and (expected is None or first_sha==expected) and hashlib.sha256(path.read_bytes()).hexdigest()==first_sha, 'First original bytes stable and match declared native SHA')
        require(0<len(raw)<=2*1024*1024, 'Bounded current CFG original bytes')
        return raw

    def archive_seed(self, user, public_raw):
        self.live();directory=user/'campaign_cfg_transactions/v1/5088120/1';no_links(directory)
        require({p.name for p in directory.iterdir()}=={'record_0000000001.json','record_0000000002.json','writing'}, 'Actual seed pair and current owned CFG lock only')
        lock=directory/'writing/owner.json';no_links(lock)
        require({p.name for p in lock.parent.iterdir()}=={'owner.json'}, 'Actual current owned lock shape')
        lock_raw=self.original_bytes(lock);owner=json.loads(lock_raw)
        require(type(owner) is dict and set(owner)=={'version','owner','pid','token'} and all(type(v) is str for v in owner.values())
                and owner['version']=='1' and owner['owner']=='1' and owner['pid']==str(self.child.pid)
                and re.fullmatch('[0-9a-f]{32}',owner['token']), 'Actual paused writer belongs to same native PID')
        archive=self.output/'seed_cfg_evidence';no_links(archive);archive.mkdir(exist_ok=False)
        previous=ZERO;records=[];first=None
        for generation in [1,2]:
            original=directory/('record_%010d.json'%generation);raw=self.original_bytes(original)
            document=decode_envelope(raw,'LH_CAMPAIGN_CFG_TRANSACTION',generation,previous)
            cfg_document(document,generation,self.suite.runtime_fields,'prefs','','',ZERO,self.ready_original['prior_CFG_sha256'])
            if first is None:first=document
            else:require(typed_equal({k:v for k,v in first.items() if k not in ['generation','state']},
                                    {k:v for k,v in document.items() if k not in ['generation','state']}), 'Original preference prepared/applied pair identical')
            copy=archive/original.name
            with copy.open('xb') as stream:stream.write(raw);stream.flush()
            fixed=self.suite.freeze_bytes(copy,hashlib.sha256(raw).hexdigest());previous=hashlib.sha256(fixed).hexdigest()
            records.append({'original_path':str(original),'copy_path':str(copy),'sha256':previous,'document':document})
        cfg_copy=archive/'seed_campaign.cfg'
        with cfg_copy.open('xb') as stream:stream.write(public_raw);stream.flush()
        self.suite.freeze_bytes(cfg_copy,self.ready_original['prior_CFG_sha256'])
        require(lock.read_bytes()==lock_raw, 'Actual held CFG lock unchanged across original seed archive')
        return {'directory':str(directory),'records':records,'public_CFG_copy':str(cfg_copy),
                'public_CFG_sha256':self.ready_original['prior_CFG_sha256'],'owned_lock':owner}

    def inject(self, frames):
        self.live(); ready,user=self.ready(); actual_life=self.lifecycle(user); public=user/'campaign.cfg'
        self.ready_original=ready; self.life_original=actual_life; self.user=user
        public_raw=self.original_bytes(public,ready['prior_CFG_sha256'])
        actual_seed=self.archive_seed(user,public_raw)
        if self.case in ['bad_existing_cfg_load','existing_vanished_prior']:
            target=public; original=public_raw
        else:
            stages=user/'campaign_cfg_candidates/v1'; no_links(stages)
            require(stages.is_dir() and not any(p.is_file() for p in stages.iterdir()), 'Actual native stage parent shape')
            dirs=list(stages.iterdir())
            require(len(dirs)==1 and dirs[0].is_dir() and len(dirs[0].name)==32 and all(c in '0123456789abcdef' for c in dirs[0].name), 'Single actual native owned candidate stage')
            no_links(dirs[0]); target=dirs[0]/'candidate.cfg'
            if self.case=='write_failure':
                require(not target.exists(), 'Actual native candidate destination absent before save'); original=None
            else: original=self.original_bytes(target)
        if original is not None: require(target.is_file() and target.read_bytes()==original, 'Actual original source bytes unchanged immediately before owned mutation')
        self.target,self.original=target,original
        backup=self.output/'fault_original.bin'
        if original is not None:
            with backup.open('xb') as file: file.write(original); file.flush()
            self.backup=self.suite.freeze_bytes(backup,hashlib.sha256(original).hexdigest())
        if self.case=='write_failure':
            target.mkdir(); stat=target.stat(); self.directory_identity=(stat.st_dev,stat.st_ino)
            changed=None
        elif self.case in ['existing_vanished_prior','save_OK_fresh_load_failure']:
            target.unlink(); changed=None
        else:
            if self.case=='bad_existing_cfg_load': changed=b'[broken'
            elif self.case=='readback_semantic_mismatch': changed=original+b'\n[owned_fault_probe]\nnonce="'+self.step['nonce'].encode('ascii')+b'"\n'
            else: changed=original+b'\n;owned_comment_fault_'+self.step['nonce'].encode('ascii')+b'\n'
            with target.open('wb') as file: file.write(changed); file.flush()
            require(target.read_bytes()==changed, 'Actual changed owned bytes read back')
        self.changed=changed
        mutation={'target':str(target),'original_bytes':0 if original is None else len(original),'original_sha256':None if original is None else hashlib.sha256(original).hexdigest(),
                  'after_kind':'empty_directory' if self.case=='write_failure' else 'absent' if changed is None else 'file',
                  'after_sha256':None if changed is None else hashlib.sha256(changed).hexdigest(),
                  'backup_file':None if original is None else str(backup),'backup_sha256':None if original is None else hashlib.sha256(self.backup).hexdigest()}
        payload={'schema':'campaign_file_fault_actual_injection_v1','pid':self.child.pid,'nonce':self.step['nonce'],'case':self.case,
                 'actual_debugger_stack':frames,'source_window':self.window['stop'],'ready_sha256':self.suite.evidence_by_path[str((self.output/'file_fault_ready.json').resolve()).casefold()]['sha256'],
                 'actual_user_directory':str(user),'actual_lifecycle':actual_life,'actual_seed_CFG':actual_seed,'mutation':mutation,'monotonic_ns':time.monotonic_ns(),'full_original19_qualified':False}
        path=self.output/'fault_injection.json'; publish_new(path,payload)
        raw=self.suite.freeze_bytes(path); self.injection=hashlib.sha256(raw).hexdigest()
        self.step['actual_fault_injection']={'path':str(path),'sha256':self.injection,'mutation':mutation}
        self.suite.persist()

    def validate_pending(self, pending):
        self.live()
        # Re-read first immutable files and current disk before ANY repair.
        self.suite.freeze_bytes(self.output/'fault_injection.json',self.injection)
        ready,user=self.ready()
        require(user==self.user and typed_equal(ready,self.ready_original), 'Original armed ready data unchanged')
        current=self.lifecycle(user)
        require(typed_equal(current,self.life_original), 'Exact original gen1/gen2 lifecycle remains pending with no gen3')
        fields={'case','code','coordinator_id','writer_id','lifecycle_id','proposal_id','proposal_semantics','proposal_semantics_sha256','intent',
                'gen1_sha256','gen2_sha256','actual_memory','actual_cloud','writer_stage','prior_CFG_sha256','injection_sha256'}
        require(type(pending) is dict and set(pending)==fields, 'Exact complete native pending fields')
        for key,expected in {'case':self.case,'code':self.window['code'],'injection_sha256':self.injection,
                             'prior_CFG_sha256':ready['prior_CFG_sha256'],
                             'gen1_sha256':current['records'][0]['sha256'],'gen2_sha256':current['records'][1]['sha256']}.items():
            require(type(pending[key]) is str and pending[key]==expected, 'Original pending field: '+key)
        for key,expected in {'intent':current['records'][1]['document']['intent'],
                             'actual_memory':ready['original_progress'],'actual_cloud':ready['original_cloud']}.items():
            require(typed_equal(pending[key],expected), 'Original complete typed pending field: '+key)
        require(all(type(pending[k]) is int and pending[k]!=0 for k in ['coordinator_id','writer_id','lifecycle_id']), 'Actual retained native object identifiers')
        prior_fault=self.case in ['bad_existing_cfg_load','existing_vanished_prior']
        require(type(pending['proposal_id']) is int and type(pending['writer_stage']) is str, 'Native proposal/stage exact types')
        if prior_fault:
            require(pending['proposal_id']==0 and pending['writer_stage']=='' and typed_equal(pending['proposal_semantics'],{}) and pending['proposal_semantics_sha256']=='', 'Actual unprepared writer has no proposal/stage/hash')
        else:
            require(pending['proposal_id']!=0 and pending['writer_stage']=='staging', 'Actual frozen proposal retains original staging operation')
            require(type(pending['proposal_semantics_sha256']) is str and re.fullmatch('[0-9a-f]{64}',pending['proposal_semantics_sha256']), 'Actual native frozen proposal semantics hash')
            semantics=pending['proposal_semantics']
            require(type(semantics) is dict and set(semantics)=={'ok','sections'} and semantics['ok'] is True and type(semantics['sections']) is dict, 'Actual supported frozen ConfigFile semantics')
            for section,keys in semantics['sections'].items():
                require(type(section) is str and type(keys) is dict, 'Native ConfigFile section/key container types')
                for key,value in keys.items():
                    require(type(key) is str and type(value) is dict and set(value)=={'variant_type','canonical'}
                            and type(value['variant_type']) is int and 0<=value['variant_type']<=38
                            and type(value['canonical']) is str, 'Exact native per-value semantics')
            self.original_bytes(user/'campaign.cfg',ready['prior_CFG_sha256'])
        self.live()

    def repair_if_pending(self):
        self.live()
        if self.injection is None or self.repaired or not (self.output/'file_fault_pending.json').exists(): return False
        pending=self.suite.read_fixed(self.output/'file_fault_pending.json')
        self.validate_pending(pending)
        no_links(self.target)
        if self.case=='write_failure':
            require(self.target.is_dir() and not list(self.target.iterdir()), 'Only exact empty owned denial directory may be removed')
            current=self.target.stat(); require((current.st_dev,current.st_ino)==self.directory_identity, 'Original owned denial directory identity unchanged')
            self.target.rmdir()
        else:
            if self.changed is None: require(not self.target.exists(), 'Original injected absence unchanged')
            else: require(self.target.is_file() and self.target.read_bytes()==self.changed, 'Exact injected bytes unchanged before repair')
            if self.changed is not None: self.target.unlink()
            require(not self.target.exists(), 'No overwrite of another target during original-byte restore')
            with self.target.open('xb') as file: file.write(self.original); file.flush()
            require(self.target.read_bytes()==self.backup, 'Restore exact first owned original byte copy')
        payload={'schema':'campaign_file_fault_actual_repair_v1','pid':self.child.pid,'nonce':self.step['nonce'],'case':self.case,
                 'injection_sha256':self.injection,'pending_sha256':self.suite.evidence_by_path[str((self.output/'file_fault_pending.json').resolve()).casefold()]['sha256'],
                 'target':str(self.target),'restored_sha256':None if self.original is None else hashlib.sha256(self.original).hexdigest(),'monotonic_ns':time.monotonic_ns()}
        path=self.output/'fault_repaired.json'; publish_new(path,payload); self.suite.freeze_bytes(path)
        self.repaired=True; self.step['actual_fault_repair']=payload; self.suite.persist(); return True
