"""Primitive synthetic evidence checks only; no Popen, Godot or real profiles."""
from pathlib import Path
from types import SimpleNamespace
import argparse,hashlib,json,sys,uuid
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'));sys.dont_write_bytecode=True
from campaign_first_repeat_evidence_v1 import FirstRepeatEvidence as V1
from campaign_first_repeat_evidence_v2 import FirstRepeatEvidence as V2
from campaign_original19_binary_files_v1 import publish_binary_new
from campaign_original19_atomic_files_v2 import publish_bytes_new
from campaign_file_fault_records_v1 import ZERO
from campaign_file_fault_evidence_v2 import digest

class Fixture:
    def __init__(self,run):
        self.run=run;self.evidence_by_path={};self.runtime_fields={'content_version':'synthetic','engine_binary_sha256':'e'*64}
    def freeze_bytes(self,path,expected=None):
        raw=Path(path).read_bytes();h=hashlib.sha256(raw).hexdigest();key=str(Path(path).resolve()).casefold()
        assert expected is None or h==expected
        assert key not in self.evidence_by_path or self.evidence_by_path[key]['sha256']==h
        self.evidence_by_path.setdefault(key,{'path':str(path),'bytes':len(raw),'sha256':h});return raw
    def read_fixed(self,path):return json.loads(self.freeze_bytes(path))

def wrapped(doc,generation,previous):
    payload=json.dumps(doc,ensure_ascii=False,separators=(',',':'));b=payload.encode('utf-8')
    return (json.dumps({'magic':'LH_CAMPAIGN_CFG_TRANSACTION','version':'1','app':'5088120','owner':'1','revision':str(generation),'previous_sha256':previous,'payload_bytes':str(len(b)),'payload_sha256':hashlib.sha256(b).hexdigest(),'payload':payload})+'\n').encode()

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=Path(__file__).with_suffix('.json'));args=p.parse_args()
    run=Path('D:/CodexTemp')/('lsh-fr-evidence-synthetic-'+uuid.uuid4().hex[:8]);run.mkdir(exist_ok=False);(run/'steps').mkdir()
    fixture=Fixture(run);old=V1.__new__(V1);old.suite=fixture;new=V2.__new__(V2);new.suite=fixture;new.fresh={}
    checks=[]
    def passed(label):checks.append({'label':label,'passed':True})
    def refuse(label,fn,types=(RuntimeError,AssertionError,ValueError)):
        try:fn()
        except types:passed(label)
        else:raise AssertionError('Expected refusal: '+label)
    source=run/'synthetic_campaign.cfg';raw=b'[progress]\nschema=2\nowner=""\nunlocked=2\nrecords={}\n';source.write_bytes(raw)
    old_target=run/'steps/old.bin';refuse('V1 exact CFG-text copy reproduces JSON publisher defect',lambda:old.capture(source,old_target));assert not old_target.exists() and source.read_bytes()==raw
    target=run/'steps/new.bin';assert new.capture(source,target)==raw and target.read_bytes()==raw;passed('V2 real file CFG-text bytes captured unchanged')
    assert str(source.resolve()).casefold() not in fixture.evidence_by_path;passed('mutable original public CFG is not immutable-ledger adopted')
    refuse('binary publisher cannot replace existing first bytes',lambda:publish_binary_new(target,b'changed'));assert target.read_bytes()==raw
    binary=bytes(range(256));p=run/'steps/all_bytes.bin';publish_binary_new(p,binary);assert p.read_bytes()==binary;passed('generic original non-UTF8 binary bytes preserved')
    refuse('empty binary source refused',lambda:publish_binary_new(run/'steps/empty.bin',b''))
    refuse('oversize binary source refused',lambda:publish_binary_new(run/'steps/large.bin',b'x'*(2097153)))
    refuse('bytearray source type refused',lambda:publish_binary_new(run/'steps/wrong.bin',bytearray(b'x')))
    refuse('JSON handshake publisher still rejects CFG text',lambda:publish_bytes_new(run/'steps/invalid.json',raw))
    (run/'steps/not_file').mkdir();refuse('binary destination directory refused',lambda:publish_binary_new(run/'steps/not_file',raw))
    user=run/'synthetic_userdata';directory=user/'campaign_cfg_transactions/v1/5088120/1';directory.mkdir(parents=True);(user/'campaign_cfg_candidates/v1').mkdir(parents=True)
    first_output=run/'steps/first';first_output.mkdir();repeat_output=run/'steps/repeat';repeat_output.mkdir()
    first_intent={'schema':'campaign_progress_intent_v1','token':'1'*32,'context':{'mode':'campaign','level_id':'level1','waves':0},'profile_id':'campaign_level1_v1','owner':'','content_version':'synthetic','engine_sha256':'e'*64,'victory':True,'result':{'core_cleared':True,'story_complete':True,'story_done':4,'story_total':4,'done_ids':['merchant_cover','wine_scheme','no_bloodshed','all_safe'],'contract_version':2}}
    first_sha=hashlib.sha256(raw).hexdigest()
    def pair(generations,previous,original,candidate,intent,transaction,semantics):
        for g in generations:
            doc={'schema':'campaign_cfg_transaction_v1','generation':g,'state':'prepared' if g%2 else 'applied','transaction':transaction,'original_sha256':original,'candidate_sha256':candidate,'semantics_sha256':semantics,'original_owner':'','target_owner':'','content_version':'synthetic','engine_sha256':'e'*64,'operation':'progress','run_token':intent['token'],'intent_sha256':digest(intent)}
            b=wrapped(doc,g,previous);(directory/('record_%010d.json'%g)).write_bytes(b);previous=hashlib.sha256(b).hexdigest()
    pair([1,2],ZERO,ZERO,first_sha,first_intent,'a'*32,'a'*64)
    originals=new.cfg_pair(user,first_output,first_intent,first_sha,'first');passed('two complete14-field original CFG generations archived')
    assert all(str(Path(r['original_path']).resolve()).casefold() not in fixture.evidence_by_path for r in originals);passed('prunable original CFG generation paths not immutable-ledger adopted')
    new.fresh['first']={'cfg_journals':originals,'cfg_sha256':first_sha}
    for r in originals:
        path=Path(r['original_path']);assert path.resolve().is_relative_to(run.resolve());path.unlink()
    for r in originals:assert new.fixed(r['copy_path'],r['sha256'])
    passed('original two archived byte buffers survive simulated normal pruning')
    repeated={**first_intent,'token':'2'*32};pair([3,4],originals[-1]['sha256'],first_sha,first_sha,repeated,'b'*32,'b'*64)
    second=new.cfg_pair(user,repeat_output,repeated,first_sha,'repeat');assert second[0]['document']['semantics_sha256']!=originals[0]['document']['semantics_sha256'];passed('confirmed later pair permits legitimate distinct canonical container summary')
    new.retained_cfg(user,{'cfg_journals':second});passed('same retained current pair matches original closed copies')
    (directory/'record_0000000003.json').write_bytes(b'changed');refuse('retained original current generation drift refused',lambda:new.retained_cfg(user,{'cfg_journals':second}))
    old_copy=Path(originals[0]['copy_path']);old_copy.write_bytes(b'changed');refuse('first archived generation cannot be rebaselined',lambda:new.fixed(old_copy,originals[0]['sha256']))
    fake={'label':'first','mode':'first','pid':12345,'nonce':'3'*32,'process_terminal':True,'exit_code':0,'engine_errors':0}
    new.completed=[];fixture.batch=SimpleNamespace(steps=[fake],child=SimpleNamespace(pid=12345,poll=lambda:0))
    refuse('synthetic terminal metadata cannot impersonate actual owned Popen',lambda:new.validate(fake,'first'))
    value={'schema':'first_repeat_evidence_synthetic_host_checks_v1_v2','script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'classification':'primitive synthetic filesystem/metadata checks; no complete consumer pipeline or real process','private_fixture_root':str(run),'checks':checks,'count':len(checks),'all_passed':True,'Popen_started':False,'Godot_started':False,'native_qualified':False,'approved_stages':[]}
    with args.output.open('x',encoding='utf-8',newline='\n') as f:json.dump(value,f,ensure_ascii=False,indent=2);f.write('\n')
    print(json.dumps({'primitive_checks':len(checks),'all_passed':True,'native_started':False}))

if __name__=='__main__':main()
