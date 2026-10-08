"""Synthetic host-only guard checks. No Popen, debugger or Godot is exercised."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from campaign_original19_fault_runtime_v2 import diagnostic_budget, validate_phase_environment
from campaign_original19_native_exports_v1 import NativeExports

checks=[]
def reject(label, function):
    try: function()
    except (RuntimeError,AssertionError): checks.append({'label':label,'rejected':True}); return
    raise AssertionError(label)

class SyntheticSuite:
    def __init__(self,run,step):
        self.run=run; self.batch=SimpleNamespace(steps=[step]); self.evidence_by_path={}
        self.runtime_fields={'content_version':'SYNTHETIC_NO_NATIVE','file_count':2}
        self.identity_path=run/'synthetic_identity.json'
        self.identity_path.write_text(json.dumps({'runtime_fields':self.runtime_fields,'complete_identity':{'synthetic':True}}),encoding='utf-8')
        self.freeze_bytes(self.identity_path)
    def freeze_bytes(self,path,expected=None):
        path=Path(path);raw=path.read_bytes();digest=hashlib.sha256(raw).hexdigest();key=str(path.resolve()).casefold()
        assert expected is None or digest==expected
        assert key not in self.evidence_by_path or digest==self.evidence_by_path[key]['sha256']
        self.evidence_by_path[key]={'path':str(path),'bytes':len(raw),'sha256':digest};return raw
    def read_fixed(self,path):return json.loads(self.freeze_bytes(path))
    def persist(self):pass

with tempfile.TemporaryDirectory(prefix='lsh-f19-v2-host-') as temporary:
    run=Path(temporary);output=run/'steps/synthetic';output.mkdir(parents=True)
    step={'pid':424242,'case':'readback_semantic_mismatch','nonce':'c'*32,'profile':str(run/'profiles/synthetic'),'output':str(output)}
    suite=SyntheticSuite(run,step)
    first=suite.evidence_by_path[str(suite.identity_path.resolve()).casefold()]['sha256']
    values={'CAMPAIGN_FILE19_CASE':step['case'],'CAMPAIGN_TERMINAL_MODE':'fresh','CAMPAIGN_TERMINAL_OUTPUT':step['output'],
            'CAMPAIGN_TERMINAL_PROFILE':step['profile'],'CAMPAIGN_TERMINAL_NONCE':step['nonce'],'CAMPAIGN_TERMINAL_TOKEN':'',
            'CAMPAIGN_TERMINAL_EXPECT_RECOVERY':'0','CAMPAIGN_TERMINAL_IDENTITY_FILE':str(suite.identity_path),
            'CAMPAIGN_TERMINAL_IDENTITY_SHA256':first}
    validate_phase_environment(suite,step,values);checks.append({'label':'synthetic exact original environment positive','passed':True})
    for field in ['OUTPUT','PROFILE','NONCE','IDENTITY_FILE','IDENTITY_SHA256']:
        wrong=values.copy();wrong['CAMPAIGN_TERMINAL_'+field]='SYNTHETIC_WRONG'
        reject('wrong '+field+' refused before launch',lambda wrong=wrong:validate_phase_environment(suite,step,wrong))
    alias=values.copy();alias['campaign_terminal_output']='SYNTHETIC_FOREIGN'
    reject('Windows case alias refused',lambda:validate_phase_environment(suite,step,alias))
    log=output/'native.log';ctrl=SimpleNamespace(case='bad_existing_cfg_load',injection='1'*64,target=run/'campaign.cfg')
    header='ERROR: ConfigFile parse error at '+str(ctrl.target).replace('\\','/')+':0: Unexpected EOF while parsing simple tag.'
    good='   at: _parse (core/io/config_file.cpp:292)\n   GDScript backtrace (most recent call first):\n       [0] _stable_cfg (res://scripts/run_campaign_cfg_transaction.gd:146)\n'
    log.write_text(header+'\n'+good,encoding='utf-8');assert diagnostic_budget(log,ctrl,True)['total']==1
    checks.append({'label':'immediately associated exact diagnostic block positive','passed':True})
    log.write_text(good+header+'\n   at: WRONG_PARSER (wrong.cpp:999)\n   GDScript backtrace (most recent call first):\n       [0] WRONG_SCRIPT (res://wrong.gd:999)\n',encoding='utf-8')
    reject('unrelated correct decoy cannot qualify wrong ERROR block',lambda:diagnostic_budget(log,ctrl,True))
    log.write_text(header+'\n'+good+header+'\n'+good,encoding='utf-8')
    reject('duplicate owned parser diagnostic refused',lambda:diagnostic_budget(log,ctrl,True))
    log.write_text(header+'\n'+good+'SCRIPT ERROR: SYNTHETIC\n',encoding='utf-8')
    reject('unrelated script diagnostic refused',lambda:diagnostic_budget(log,ctrl,True))
    log.write_bytes(b'normal complete line\n\xe6\xb0');ctrl.case='write_failure';assert diagnostic_budget(log,ctrl)['total']==0
    checks.append({'label':'in-flight UTF8 suffix deferred','passed':True})
    name='file_fault_ready.json';native=output/(name+'.native-'+step['nonce'])
    original=b'{"schema":"SYNTHETIC_NO_NATIVE","value":1}\n';native.write_bytes(original);digest=hashlib.sha256(original).hexdigest()
    marker='CAMPAIGN_FILE19_EXPORT '+str(step['pid'])+' '+step['nonce']+' '+name+' '+digest
    exports=NativeExports(suite,step)
    log.write_text(marker[:len(marker)//2],encoding='utf-8');assert exports.publish()=={} and not (output/name).exists()
    checks.append({'label':'incomplete marker does not expose final JSON','passed':True})
    log.write_text(marker+'\n',encoding='utf-8');exports.publish();assert (output/name).read_bytes()==original
    checks.append({'label':'closed native original bytes published exactly once with native SHA','passed':True})
    log.write_text(marker+'\n'+marker+'\n',encoding='utf-8');reject('duplicate native export marker refused',exports.publish)
    assert (output/name).read_bytes()==original
    log.write_text(marker.replace(str(step['pid']),'999999')+'\n',encoding='utf-8');reject('wrong native marker PID refused',exports.publish)
    log.write_text(marker.replace(step['nonce'],'d'*32)+'\n',encoding='utf-8');reject('wrong native marker nonce refused',exports.publish)
    log.write_text(marker+'\n',encoding='utf-8');reject('incomplete fresh export set refused',lambda:exports.require_complete('fresh'))
    native.write_bytes(b'{"unexpected":"changed"}\n');reject('first closed native byte drift refused',lambda:suite.freeze_bytes(native,digest))
    suite.identity_path.write_text(json.dumps({'runtime_fields':{'content_version':'DRIFT'},'complete_identity':{}}),encoding='utf-8')
    reject('original installed identity pin drift refused',lambda:validate_phase_environment(suite,step,values))

source_files=['tools/campaign_original19_fault_runtime_v2.py','tools/campaign_original19_native_exports_v1.py','tools/campaign_original19_atomic_files_v2.py']
result={'schema':'campaign_original19_fault_runtime_synthetic_host_checks_v2','synthetic':True,'pure_host':True,
        'native_started':False,'real_Popen_debugger_process_ownership_not_tested':True,'passed':True,'count':len(checks),
        'checks':checks,'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in source_files},
        'approved_stages':[],'full_original19_qualified':False}
path=Path(__file__).with_suffix('.json')
with path.open('x',encoding='utf-8',newline='\n') as stream:stream.write(json.dumps(result,indent=2)+'\n')
print(json.dumps({'synthetic_host_checks':len(checks),'passed':True,'native_started':False}))
