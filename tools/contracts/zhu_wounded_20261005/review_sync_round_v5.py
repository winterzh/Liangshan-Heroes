"""Read-only review of tested inputs and an explicit, owned Git sync whitelist."""
from pathlib import Path
import hashlib, json, re, subprocess, ast

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT.parent/'qa-rescued-seven-current-20261006'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf-8'))
def git(*args): return subprocess.check_output(['git',*args],cwd=ROOT).decode('utf-8').strip()
expected = '27f45b245e2b39f1f779fbfa62772e14bb68dd56'
assert git('rev-parse','HEAD') == expected == git('rev-parse','origin/codex/sync-20260905-stable')
assert git('branch','--show-current') == 'codex/sync-20260905-stable'
assert git('remote','get-url','origin') == 'https://github.com/winterzh/Liangshan-Heroes.git'
assert not git('diff','--cached','--name-only')

proofs=[]
for name in ['original_rescued_seven_production_route_v4','rescued_seven_cross_process_qualified_v4']:
    summary = read(ROOT/'qa/zhu_wounded_20261005'/f'{name}.json')
    receipt = Path(summary['receipt'])
    assert sha(receipt) == summary['receipt_sha256']
    r=read(receipt); assert r['complete'] and r['lock_released']
    mismatches=[v['path'] for v in r['source_files'] if sha(ROOT/v['path'])!=v['sha256']]
    assert not mismatches,mismatches
    proofs.append({'path':f'qa/zhu_wounded_20261005/{name}.json','receipt_sha256':sha(receipt),
                   'checks':summary['checks'],'unchanged_frozen_inputs':len(r['source_files'])})
audit=read(ROOT/'qa/zhu_wounded_20261005/rescued_seven_candidate_identity_audit_v4.json')
assert audit['passed']
for row in audit['characters']:
    for field in ['manifest','source_receipt','unit_receipt']:
        assert sha(ROOT/row[field])==row[field+'_sha256']
    m=read(ROOT/row['manifest']); u=read(ROOT/row['unit_receipt'])
    ins={v['path']:v['sha256'] for v in u['inputs']}
    for v in m['sources'].values():
        assert sha(ROOT/v['path'])==v['sha256']==ins[v['path']]
        assert sha(ROOT/(v['path']+'.import'))==ins[v['path']+'.import']
    for p in m['resources']: assert sha(ROOT/p)==ins[p]

fixed=['.gitattributes','scripts/unit.gd','scripts/art_db.gd','scripts/campaign_art.gd','scripts/liangshan_scenery.gd',
       'tools/directional_character_sources.py','tools/rescued_seven_art_qa.gd','tools/run_rescued_seven_art_qa.py',
       'tools/rescued_seven_cross_process_qa.gd','tools/run_rescued_seven_cross_process_qa.py']
fixed += ['docs/'+n for n in ['ART_COMPLETION_20260926.md','WORKLOG.md','SOURCE_SETUP.md','DIRECTORY_INDEX.md',
                            'PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','CHARACTER_POSTURE_20261006.md',
                            'DEVELOPMENT_AUDIT_20261006.md','RESCUED_ART_CANDIDATE_MATRIX_20261006.md','RESCUED_ART_INTEGRATION_20261006.md']]
paths=set(fixed)
directories=['tools/contracts/zhu_wounded_20261005','qa/zhu_wounded_20261005']
directories += [f'assets/characters/{key}_wounded_20261005' for key in ['shi_qian','shi_xiu','qin_ming','yang_lin','huang_xin','wang_ying','deng_fei']]
directories += [f'assets/characters/{key}_traits_20261006' for key in ['wu_song','lin_chong']]
for directory in directories:
    for p in (ROOT/directory).rglob('*'):
        if not p.is_file():continue
        relative=p.relative_to(ROOT)
        if any(part in ['.godot','.git','__pycache__'] for part in relative.parts):continue
        if p.suffix in ['.uid','.tmp','.pyc']:continue
        if p.suffix=='.import' and directory.startswith(('tools/','qa/')):continue
        paths.add(relative.as_posix())
for pat in ['zhu_wounded_*.tres','character_traits_v4_*.tres']:
    paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT/'assets/anim').glob(pat))
for pat in ['zhu_wounded_*.json','ordinary_*_20261006_traits_v4.json']:
    paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT/'assets/direction4').glob(pat))
assert all((ROOT/p).is_file() for p in paths)
for name in paths:
    p=ROOT/name
    assert p.stat().st_size<50*1024*1024
    assert not any(part in ['.godot','.git','build','vendor','profiles'] for part in Path(name).parts)
    assert p.suffix.lower() not in ['.exe','.pck','.zip','.7z','.key','.pem']

changed=subprocess.check_output(['git','-c','core.quotepath=false','status','--porcelain=v1','--untracked-files=all'],cwd=ROOT).decode('utf-8').rstrip('\r\n')
changed_paths=[line[3:] for line in changed.splitlines()]
outside=[name for name in changed_paths if name not in paths]
assert not outside, outside
patterns=[re.compile(x) for x in [r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
           r'\bgh[pousr]_[A-Za-z0-9]{30,}',r'\bgithub_pat_[A-Za-z0-9_]{30,}',r'\bsk-proj-[A-Za-z0-9_-]{20,}']]
findings=[];py_count=0
for name in sorted(paths):
    p=ROOT/name
    if p.suffix.lower() in ['.py','.gd','.json','.md','.txt','.cfg','.tres','.import','.gitattributes','.log','.toml'] or name=='.gitattributes':
        value=p.read_text(encoding='utf-8',errors='replace')
        if any(rx.search(value) for rx in patterns):findings.append(name)
        if p.suffix=='.py':ast.parse(value,filename=name);py_count+=1
assert not findings,findings
snapshot={'passed':True,'scope':'Owned posture native provenance, limited production routing, component QA and docs; no platform publication or final whole-plan acceptance.',
          'branch':git('branch','--show-current'),'parent_commit':expected,'remote':git('remote','get-url','origin'),
          'qualified_component_proofs':proofs,'seven_candidate_source_hashes_verified':True,
          'secret_scan_findings':findings,'python_syntax_files':py_count,
          'review':'Derived appearance is constrained to actual current-chapter freed actors; persisted variant, stats, rescue callbacks and save schema are unchanged. Ordinary Wusong/Lin production routes unchanged; new candidates remain unqualified.',
          'files':[{'path':name,'bytes':(ROOT/name).stat().st_size,'sha256':sha(ROOT/name)} for name in sorted(paths)]}
snapshot['bytes']=sum(v['bytes'] for v in snapshot['files'])
destination=OUT/'reviewable_sync_snapshot_v5.json'
assert not destination.exists()
destination.write_bytes((json.dumps(snapshot,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
pathspec=OUT/'sync_whitelist_v5.nul'
assert not pathspec.exists()
pathspec.write_bytes(b'\0'.join(p.encode('utf-8') for p in sorted(paths))+b'\0')
print(json.dumps({'passed':True,'whitelist_files':len(paths),'bytes':snapshot['bytes'],
                  'python_syntax_files':py_count,'frozen_inputs_verified':[p['unchanged_frozen_inputs'] for p in proofs],
                  'secret_findings':0,'snapshot':str(destination),'staged':False}))
