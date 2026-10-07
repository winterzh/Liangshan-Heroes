from pathlib import Path
import json, hashlib, datetime, subprocess
ROOT=Path('E:/ChatGPT/水浒');P=Path('E:/ChatGPT/daming_safe_retreat_v25_proposal')
OUT=Path('E:/ChatGPT/daming_safe_retreat_v25_preapply_20261008');Q=ROOT/'qa/zhu_wounded_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert subprocess.check_output(['git','branch','--show-current'],cwd=ROOT).decode().strip()=='codex/sync-20260905-stable'
assert not subprocess.check_output(['git','status','--porcelain=v1'],cwd=ROOT).decode().strip()
pins=[('scripts/run_level8_unit_contract.gd','abfa6c3ddeede8116324880e44000639df4e2c2391ae1cd1e583e09fb220d37c','b2f52bcce60b27507b498a6d32e45b5cadd3409030fcd2e1024c78dac90e90d5'),
      ('scripts/run_battle_world_core.gd','621426f2714207dd69fb66981dbf73f34b9b9a1637cd890b23fb53d4a39fd571','92b2bdac0058f9e1642d1b991c3ca353e902481d8daff990388e377597df87b1')]
for path,before,after in pins:
    assert sha(ROOT/path)==sha(P/'original'/path)==before
    assert sha(P/'proposed'/path)==after
    for p in [ROOT/path,P/'proposed'/path]:
        assert not p.is_symlink() and not p.lstat().st_file_attributes & 0x400
OUT.mkdir(exist_ok=False)
rows=[]
for path,before,after in pins:
    p=OUT/path;p.parent.mkdir(parents=True,exist_ok=True)
    with p.open('xb') as f:f.write((ROOT/path).read_bytes())
    assert sha(p)==before
    rows.append({'path':path,'before_sha256':before,'after_sha256':after,'bytes':(P/'proposed'/path).stat().st_size})
base=json.loads((Q/'native_ownership_json_candidate_v24q.json').read_text(encoding='utf-8'))
for row in base['files']:
    assert sha(ROOT/row['path'])==row['after_sha256']
receipt={'scope':'Controlled reversible local candidate: qualified JSON4 plus proposed Daming safe retreat Unit contract/Core pair guards. Not runtime-qualified, not Git production committed.',
         'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'runtime_qualified':False,
         'qualified_JSON_predecessor':'qa/zhu_wounded_20261005/daming_admission_continuation_qualified_v24s.json',
         'source_root':str(ROOT),'before_backup':str(OUT),'files':base['files']+rows,
         'public_campaign_gate_opened':False,'candidate_scope':'single Lu/Shi safely retreated while other alive and battle FIGHT; exact paired records before allocation/capture output'}
with (Q/'safe_retreat_candidate_v25x1.json').open('x',encoding='utf-8') as f:json.dump(receipt,f,ensure_ascii=False,indent=2);f.write('\n')
for path,before,after in pins:
    assert sha(ROOT/path)==before
    (ROOT/path).write_bytes((P/'proposed'/path).read_bytes());assert sha(ROOT/path)==after
with (OUT/'applied.json').open('x',encoding='utf-8') as f:json.dump({'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'files':rows,'runtime_qualified':False,'production_commit':False},f,ensure_ascii=False,indent=2)
print(json.dumps({'applied_local_paths':[r['path'] for r in rows],'candidate_receipt':'qa/zhu_wounded_20261005/safe_retreat_candidate_v25x1.json','qualified':False}))
