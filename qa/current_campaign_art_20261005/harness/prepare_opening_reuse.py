"""Preserve independently passed opening subcase without accepting its later failed route."""
from pathlib import Path
import json,hashlib,shutil
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
e=base/'20261005_140917_59c0c0c1/evidence'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
r=json.loads((e/'receipt.json').read_text(encoding='utf-8'))
data=json.loads((e/'current_campaign_art/report.json').read_text(encoding='utf-8'))
assert not r['complete'] and not r['source_changes'] and not r['private_source_changes']
private=Path(r['project'])
assert sha(e/'harness/current_campaign_art_qa.gd')==r['qa_sha256']==sha(private/'tools/current_campaign_art_qa.gd')
assert sha(e/'harness/run_character_art_qa.py')==r['driver_sha256']==sha(repo/'tools/run_character_art_qa.py')
assert sha(Path(r['steps'][0]['command'][0]))==r['godot_sha256']
assert all(sha(private/x['path'])==x['sha256'] for x in r['source_files'])
assert all(sha(e/x['path'])==x['sha256'] for x in r['artifacts'])
assert data['failures']==['all original seven normal player movement waypoint (43, 18)']
log=(e/'current_campaign_art.log').read_text(encoding='utf-8')
marker='[rts] PASS all eight current registered openings inventoried'
assert log.count(marker)==1 and '[rts] FAIL' not in log.split(marker)[0]
assert len(data['resources'])==8 and sum(x['original_unit_count'] for x in data['resources'])==325
excluded={'tools/current_campaign_art_qa.gd','tools/run_current_campaign_art_qa.py'}
inputs={row['path']:row['sha256'] for row in r['source_files'] if row['path'] not in excluded}
assert all(sha(repo/path)==digest for path,digest in inputs.items())
qa=repo/'qa/current_campaign_art_20261005/opening_evidence';qa.mkdir(parents=True,exist_ok=True)
files={}
for src,name in [(e/'receipt.json','original_receipt.json'),(e/'current_campaign_art/report.json','original_report.json'),(e/'current_campaign_art.log','original_engine.log')]:
    dst=qa/name;shutil.copyfile(src,dst);assert sha(src)==sha(dst);files[dst.relative_to(repo).as_posix()]=sha(dst)
proof={'schema':1,'opening_checks_passed':True,'whole_source_run_passed':False,
       'scope':'Only earlier independently passed actual eight-opening subcase. Later original evacuation failure remains preserved.',
       'installed_source_sha256':data['identity_before']['source_sha256'],'input_sha256':inputs,
       'source_evidence_sha256':files,'source_report':'qa/current_campaign_art_20261005/opening_evidence/original_report.json',
       'openings':data['resources']}
p=repo/'tools/contracts/current_campaign_opening_20261005/snapshot.json';p.parent.mkdir(parents=True,exist_ok=True)
p.write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
attrs=repo/'.gitattributes';addition=b'tools/contracts/current_campaign_opening_20261005/** -text -whitespace\n'
assert addition not in attrs.read_bytes();attrs.write_bytes(attrs.read_bytes()+addition)
(base/'opening_reuse_receipt.json').write_text(json.dumps({'complete':True,'snapshot_sha256':sha(p),'source_report_sha256':sha(e/'current_campaign_art/report.json'),'verified_input_files':len(inputs),'subcase_only':True},indent=2)+'\n',encoding='utf-8')
print(json.dumps({'complete':True,'verified_inputs':len(inputs),'previous_opening_units':325,'whole_old_run_accepted':False}))
