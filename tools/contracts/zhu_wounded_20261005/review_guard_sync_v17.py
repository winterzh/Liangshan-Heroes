"""Review an explicit owned source/evidence whitelist before stable synchronization."""
from pathlib import Path
import ast,hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT.parent/'qa-ordinary-posture-20261006'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT).decode('utf-8').strip()
def main():
    branch='codex/sync-20260905-stable';parent='897c0ad763ac22d9c953ae8dfdc805e2ba0bdc17'
    assert git('branch','--show-current')==branch and git('remote','get-url','origin')=='https://github.com/winterzh/Liangshan-Heroes.git'
    assert git('rev-parse','HEAD')==parent==git('ls-remote','origin','refs/heads/'+branch).split()[0]
    assert not git('diff','--cached','--name-only')
    qa='qa/zhu_wounded_20261005/';td='tools/contracts/zhu_wounded_20261005/'
    r=read(ROOT/(qa+'ordinary_guard_readability_qualified_v17.json'));v=read(ROOT/(qa+'ordinary_guard_readability_visual_review_v17.json'))
    assert r['complete'] and r['lock_released'] and r['root_input_drift']==r['private_input_drift']==r['private_runtime_patches']==0
    assert r['production_source_delta']==['scripts/battle.gd'] and r['result']['passed'] and r['result']['checks']==761
    assert len(r['result']['screenshots'])==112 and v['passed'] and len(v['viewed'])==19
    assert v['receipt_sha256']==sha(ROOT/(qa+'ordinary_guard_readability_qualified_v17.json'))
    for row in r['source_files']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    patch=read(ROOT/(qa+'lin_guard_readability_patch_v17.json'))
    assert patch['applied'] and patch['after_sha256']==sha(ROOT/'scripts/battle.gd')
    before=subprocess.check_output(['git','show',parent+':scripts/battle.gd'],cwd=ROOT)
    assert hashlib.sha256(before).hexdigest()==patch['before_sha256']
    for filename in ['ordinary_skill_clearance_rejected_v16.json','ordinary_skill_clearance_rejected_v16a.json']:
        rejected=read(ROOT/(qa+filename));assert not rejected['qualified'] and rejected['lock_released']
        for row in rejected['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    previous=read(ROOT/(qa+'ordinary_skill_clearance_mechanical_v16b.json'))
    for row in previous['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    for row in previous['source_files']:
        if row['path']=='scripts/battle.gd':assert row['sha256']==patch['before_sha256']
        else:assert sha(ROOT/row['path'])==row['sha256']
    inventory=read(ROOT/(qa+'campaign_restore_gap_inventory_v18.json'))
    assert inventory['missing_declared_factory_or_profile']==['level5','level8'] and not inventory['public_campaign_entry_qualified']
    for row in inventory['sources']:assert sha(ROOT/row['path'])==row['sha256']
    c=read(ROOT/(qa+'rejected_skill_import_cleanup_v17.json'))
    assert c['complete'] and c['protected_hash_drift']==c['keeper_match_hash_drift']==0
    assert sha(Path(c['full_inventory']))==c['full_inventory_sha256']
    docs={'docs/'+n for n in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']}
    allowed=set(docs)|{'scripts/battle.gd'}
    allowed.update(qa+'harness/'+n for n in ['ordinary_skill_clearance_v16a.gd','run_ordinary_skill_clearance_v16a.py','ordinary_skill_clearance_v16b.gd','run_ordinary_skill_clearance_v16b.py','ordinary_guard_readability_v17.gd','run_ordinary_guard_readability_v17.py'])
    allowed.update(qa+n for n in ['campaign_restore_gap_inventory_v18.json','lin_guard_readability_patch_v17.json','ordinary_skill_clearance_failed_receipt_v16.json','ordinary_skill_clearance_failed_report_v16.json','ordinary_skill_clearance_rejected_v16.json','ordinary_skill_clearance_failed_receipt_v16a.json','ordinary_skill_clearance_failed_report_v16a.json','ordinary_skill_clearance_rejected_v16a.json','ordinary_skill_clearance_mechanical_v16b.json','ordinary_skill_clearance_visual_review_v16b.json','ordinary_guard_readability_qualified_v17.json','ordinary_guard_readability_visual_review_v17.json','rejected_skill_import_cleanup_v17.json'])
    allowed.update(td+n for n in ['apply_lin_guard_readability_v17.py','audit_campaign_restore_gaps_v18.py','prepare_guard_readability_runner_v17.py','prepare_skill_clearance_v16a.py','prepare_skill_clearance_v16b.py','record_skill_guard_rejection_v16b.py','record_guard_readability_v17.py','cleanup_rejected_skill_imports_v17.py','record_guard_round_docs_v17.py','review_guard_sync_v17.py'])
    for row in v['viewed']:assert sha(ROOT/row['path'])==row['sha256'];allowed.add(row['path'])
    for filename,field in [('ordinary_skill_clearance_visual_review_v16b.json','viewed_rejection'),('ordinary_skill_clearance_rejected_v16.json','viewed_partial')]:
        previous=read(ROOT/(qa+filename))
        for row in previous.get(field,[]):assert sha(ROOT/row['path'])==row['sha256'];allowed.add(row['path'])
    # The original v16 partial views were directly examined and preserved by its preparer.
    for n in ['lin_chong_0_se_mid_1440x960.png','lin_chong_0_se_late_1920x1080.png','lin_chong_1_se_late_1280x720.png']:
        p=ROOT/(qa+'ordinary_skill_clearance_preview_v16_frames/'+n);assert p.is_file();allowed.add(p.relative_to(ROOT).as_posix())
    names=[]
    for item in subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all','-z'],cwd=ROOT).decode('utf-8').split('\0'):
        if not item:continue
        assert item[:2] in [' M','??'];name=item[3:];assert name in allowed,name;names.append(name)
    assert set(names)==allowed,(allowed-set(names),set(names)-allowed)
    assert set(git('diff','--name-only','--','scripts','assets').splitlines())=={'scripts/battle.gd'}
    files=[]
    for name in sorted(names):
        p=ROOT/name;assert p.is_file() and p.stat().st_size<50*1024*1024
        assert not any(part in ['.git','.godot','profiles','build','__pycache__'] for part in Path(name).parts)
        if p.suffix in ['.py','.gd','.json','.md']:
            content=p.read_text(encoding='utf-8')
            assert not re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{30,}|\bsk-proj-[A-Za-z0-9_-]{20,}',content),name
            if p.suffix=='.py':ast.parse(content,filename=name)
        files.append({'path':name,'bytes':p.stat().st_size,'sha256':sha(p),'git_expected_blob':git('hash-object',name)})
    proof={'passed':True,'parent':parent,'branch':branch,'files':files,'bytes':sum(x['bytes'] for x in files),'secret_findings':[],
      'checks':761,'captures':112,'current_direct_views':19,'actual_effects':28,'production_changed':['scripts/battle.gd'],
      'cleanup_files':c['deleted_files'],'cleanup_bytes':c['deleted_bytes'],'full_goal_qualified':False,'platform_released':False}
    p=OUT/'guard_sync_review_v17.json';assert not p.exists();p.write_bytes((json.dumps(proof,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    p=OUT/'guard_sync_whitelist_v17.nul';assert not p.exists();p.write_bytes(b'\0'.join(n.encode('utf-8') for n in sorted(names))+b'\0')
    print(json.dumps({'passed':True,'files':len(files),'bytes':proof['bytes'],'checks':761,'secret_findings':0}))
if __name__=='__main__':main()
