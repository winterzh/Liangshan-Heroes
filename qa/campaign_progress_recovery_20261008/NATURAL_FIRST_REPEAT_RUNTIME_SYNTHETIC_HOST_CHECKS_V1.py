"""Finite synthetic file/env checks only: no Suite, Popen or Godot launch."""
from pathlib import Path
from types import SimpleNamespace
import argparse,ast,hashlib,json,sys,uuid

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'));sys.dont_write_bytecode=True
from campaign_natural_terminal_exports_v1 import NaturalNativeExports
from campaign_natural_terminal_runtime_v1 import NaturalSerialBatch,validate_natural_environment
from durable_campaign_full_runtime import OwnedSerialBatch

class Fixture:
    def __init__(self,run):
        self.run=run;self.evidence_by_path={};self.runtime_fields={'content_version':'synthetic','rules_sha256':'a'*64,'file_count':1,'total_bytes':1,'engine_binary_sha256':'b'*64,'provider_sha256':'c'*64}
        self.installed_identity={'synthetic':True,'count':1}
        self.identity_path=run/'identity.json';self.identity_path.write_text(json.dumps({'runtime_fields':self.runtime_fields,'complete_identity':self.installed_identity}),encoding='utf-8');self.freeze_bytes(self.identity_path)
    def freeze_bytes(self,path,expected=None):
        path=Path(path);raw=path.read_bytes();digest=hashlib.sha256(raw).hexdigest()
        assert expected is None or expected==digest
        key=str(path.resolve()).casefold()
        assert key not in self.evidence_by_path or self.evidence_by_path[key]['sha256']==digest
        self.evidence_by_path.setdefault(key,{'path':str(path),'bytes':len(raw),'sha256':digest});return raw
    def read_fixed(self,path):return json.loads(self.freeze_bytes(path))
    def persist(self):pass

def functions(path):
    tree=ast.parse(path.read_bytes());return {n.name:n for n in ast.walk(tree) if isinstance(n,ast.FunctionDef)}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,default=Path(__file__).with_suffix('.json'));args=parser.parse_args()
    run=Path('D:/CodexTemp')/('lsh-ntr-synthetic-'+uuid.uuid4().hex[:8]);run.mkdir(exist_ok=False)
    checks=[]
    def passed(name):checks.append({'label':name,'passed':True})
    def refuses(name,fn):
        try:fn()
        except (RuntimeError,AssertionError):passed(name)
        else:raise AssertionError('Expected refusal: '+name)
    parent=functions(ROOT/'tools/durable_campaign_full_runtime.py')['phase'];new=functions(ROOT/'tools/campaign_natural_terminal_runtime_v1.py')['phase_with_exports']
    assert ast.dump(next(n for n in parent.body if isinstance(n,ast.Try)).handlers[0])==ast.dump(next(n for n in new.body if isinstance(n,ast.Try)).handlers[0]);passed('owned-child cleanup and unknown-handle lease handler AST exact inherited')
    assert NaturalSerialBatch.phase is OwnedSerialBatch.phase;passed('cold phase inherits unchanged native runtime')
    fixture=Fixture(run)
    for kind,case in [('first','normal_first_full_seal'),('repeat','normal_repeat_full')]:
        p=run/'steps'/kind/'terminal_handoff.json';p.parent.mkdir(parents=True);p.write_text(json.dumps({'schema':'campaign_natural_terminal_handoff_v1','case':case,'token':('1' if kind=='first' else '2')*32}),encoding='utf-8');fixture.freeze_bytes(p);setattr(fixture,kind+'_handoff_path',p)
    step={'profile':str(run/'synthetic_profile'),'output':str(run/'steps/first'),'nonce':'3'*32,'mode':'first'}
    identity_pin=fixture.evidence_by_path[str(fixture.identity_path.resolve()).casefold()]
    base={'CAMPAIGN_TERMINAL_OUTPUT':step['output'],'CAMPAIGN_TERMINAL_NONCE':step['nonce'],'CAMPAIGN_TERMINAL_MODE':'first','CAMPAIGN_TERMINAL_PROFILE':step['profile'],'CAMPAIGN_TERMINAL_TOKEN':'','CAMPAIGN_TERMINAL_EXPECT_RECOVERY':'0','CAMPAIGN_TERMINAL_IDENTITY_FILE':str(fixture.identity_path),'CAMPAIGN_TERMINAL_IDENTITY_SHA256':identity_pin['sha256'],'CAMPAIGN_TERMINAL_PRIOR_HANDOFF_FILE':'','CAMPAIGN_TERMINAL_PRIOR_HANDOFF_SHA256':'','CAMPAIGN_TERMINAL_PRIOR_TOKEN':''}
    for mode in ['first','repeat','restart_first','restart_repeat']:
        st={**step,'mode':mode};values={**base,'CAMPAIGN_TERMINAL_MODE':mode}
        if mode=='repeat':
            p=fixture.first_handoff_path;values.update(CAMPAIGN_TERMINAL_PRIOR_HANDOFF_FILE=str(p),CAMPAIGN_TERMINAL_PRIOR_HANDOFF_SHA256=fixture.evidence_by_path[str(p.resolve()).casefold()]['sha256'],CAMPAIGN_TERMINAL_PRIOR_TOKEN='1'*32)
        if mode.startswith('restart_'):values['CAMPAIGN_TERMINAL_TOKEN']=('1' if mode=='restart_first' else '2')*32
        validate_natural_environment(fixture,st,values);passed('exact synthetic environment '+mode)
        refuses('wrong token rejected '+mode,lambda st=st,v=values:validate_natural_environment(fixture,st,{**v,'CAMPAIGN_TERMINAL_TOKEN':'9'*32}))
    for key in ['CAMPAIGN_TERMINAL_OUTPUT','CAMPAIGN_TERMINAL_NONCE','CAMPAIGN_TERMINAL_PROFILE','CAMPAIGN_TERMINAL_IDENTITY_SHA256']:
        refuses('wrong owned environment '+key,lambda k=key:validate_natural_environment(fixture,step,{**base,k:'changed'}))
    refuses('extra Windows case alias',lambda:validate_natural_environment(fixture,step,{**base,'campaign_terminal_mode':'first'}))
    fixture.installed_identity={'synthetic':True,'count':True}
    refuses('complete source identity bool/int alias',lambda:validate_natural_environment(fixture,step,base));fixture.installed_identity={'synthetic':True,'count':1}
    for mode,names in [('first',['ready_for_terminal.json','terminal_handoff.json','report.json']),('repeat',['ready_for_terminal.json','terminal_handoff.json','report.json']),('restart_first',['restart_handoff.json','report.json']),('restart_repeat',['restart_handoff.json','report.json'])]:
        out=run/'steps'/('exports_'+mode);out.mkdir();st={'pid':12345,'nonce':uuid.uuid4().hex,'output':str(out)};fixture.batch=SimpleNamespace(steps=[st],child=None)
        lines=[]
        for name in names:
            raw=(json.dumps({'synthetic':True,'name':name,'text':'原始字节'},ensure_ascii=False)+'\n').encode('utf-8');(out/(name+'.native-'+st['nonce'])).write_bytes(raw);lines.append(f"CAMPAIGN_FILE19_EXPORT 12345 {st['nonce']} {name} {hashlib.sha256(raw).hexdigest()}\n")
        (out/'native.log').write_text(''.join(lines),encoding='utf-8');export=NaturalNativeExports(fixture,st);export.require_complete(mode)
        assert set(export.rows)==set(names) and all((out/n).read_bytes()==(out/(n+'.native-'+st['nonce'])).read_bytes() for n in names);passed('complete original-byte synthetic export set '+mode)
        refuses('wrong complete set/mode '+mode,lambda e=export,m=mode:e.require_complete('restart_first' if m in ['first','repeat'] else 'first'))
        (out/names[0]).write_bytes(b'changed');refuses('first public bytes drift '+mode,lambda e=export,m=mode:e.require_complete(m))
    out=run/'steps'/'fault_name';out.mkdir();st={'pid':12345,'nonce':uuid.uuid4().hex,'output':str(out)};fixture.batch=SimpleNamespace(steps=[st],child=None)
    (out/'native.log').write_text(f"CAMPAIGN_FILE19_EXPORT 12345 {st['nonce']} file_fault_ready.json {'a'*64}\n",encoding='utf-8')
    refuses('fault-only filename refused before publication',lambda:NaturalNativeExports(fixture,st).publish());assert not (out/'file_fault_ready.json').exists()
    value={'schema':'natural_first_repeat_runtime_synthetic_host_checks_v1','classification':'synthetic primitive checks only; no native PID or real child ownership exercised','script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'private_fixture_root':str(run),'checks':checks,'count':len(checks),'all_passed':True,'Popen_started':False,'Godot_started':False,'producer_qualified':False,'native_qualified':False,'approved_stages':[]}
    with args.output.open('x',encoding='utf-8',newline='\n') as f:json.dump(value,f,ensure_ascii=False,indent=2);f.write('\n')
    print(json.dumps({'synthetic_checks':len(checks),'all_passed':True,'native_started':False}))

if __name__=='__main__':main()
