"""Preserve the first launch failure; defer installed script loading until autoloads exist."""
from pathlib import Path
import ast,hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    run=ROOT.parent/'qa-ordinary-posture-20261006/campaign_foundation_v18_c8536c21';rp=run/'receipt.json';r=json.loads(rp.read_text(encoding='utf-8'))
    assert not r['complete'] and r['lock_released']
    assert 'Identifier not found: Localize' in r['failure']['message']
    for row in r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    p=QA/'campaign_foundation_failed_receipt_v18.json';assert not p.exists();shutil.copy2(rp,p)
    rejected={'qualified':False,'failure':'QA SceneTree early preloads compiled Battle/chapters before Localize autoload registration; no runtime component result.',
        'receipt_sha256':sha(rp),'harnesses':r['harnesses'],'production_changed_for_fix':False,
        'fix':'Sibling v18a loads installed Scripts after private profile guard and autoload initialization. Original producer and failed receipt retained.'}
    p=QA/'campaign_foundation_rejected_v18.json';assert not p.exists();p.write_bytes((json.dumps(rejected,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    p=QA/'harness/campaign_foundation_v18.gd';s=p.read_text(encoding='utf-8');assign=[]
    for line in s.splitlines():
        if line.startswith('const ') and ' := preload(' in line:
            name=line.split()[1];value=line.split(' := ',1)[1].replace('preload(','load(');assign.append('\t'+name+'='+value)
            s=s.replace(line,'var '+name+': Script',1)
    needle='\tart_output=OS.get_environment("ART_QA_OUT")';assert s.count(needle)==1
    s=s.replace(needle,'\n'.join(assign)+'\n'+needle,1).replace('campaign_foundation_v18','campaign_foundation_v18a')
    p=p.with_name('campaign_foundation_v18a.gd');assert not p.exists();p.write_bytes(s.encode('utf-8'))
    p=QA/'harness/run_campaign_foundation_v18.py';s=p.read_text(encoding='utf-8').replace('campaign_foundation_v18','campaign_foundation_v18a')
    ast.parse(s);p=p.with_name('run_campaign_foundation_v18a.py');assert not p.exists();p.write_bytes(s.encode('utf-8'))
    print(json.dumps({'failed_batch_preserved':True,'siblings_prepared':True,'production_fix':False}))
if __name__=='__main__':main()
