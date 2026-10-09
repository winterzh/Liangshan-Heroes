"""Review exact owned continuous evidence and next running skill producer for stable."""
from pathlib import Path
import ast,hashlib,json,re,shutil,subprocess
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT.parent/'qa-ordinary-posture-20261006'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT).decode('utf-8').strip()
def main():
    branch='codex/sync-20260905-stable';parent='99ed9d85a1341918f4eed045520c8387240268c6'
    assert git('branch','--show-current')==branch and git('remote','get-url','origin')=='https://github.com/winterzh/Liangshan-Heroes.git'
    assert git('rev-parse','HEAD')==parent==git('ls-remote','origin','refs/heads/'+branch).split()[0]
    assert not git('diff','--cached','--name-only') and not git('diff','--name-only','--','scripts','assets')
    qa='qa/zhu_wounded_20261005/';td='tools/contracts/zhu_wounded_20261005/'
    r=read(ROOT/(qa+'ordinary_continuous_gait_qualified_v15b.json'));v=read(ROOT/(qa+'ordinary_continuous_gait_visual_review_v15b.json'))
    assert r['complete'] and r['lock_released'] and r['root_input_drift']==r['private_input_drift']==0 and r['private_runtime_patches']==0
    assert r['result']['checks']==441 and r['result']['passed'] and len(r['result']['screenshots'])==70 and v['passed']
    assert v['receipt_sha256']==sha(ROOT/(qa+'ordinary_continuous_gait_qualified_v15b.json'))
    for row in r['source_files']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    previous=read(ROOT/(qa+'ordinary_continuous_gait_mechanical_v15a.json'));assert previous['source_files']==r['source_files']
    for row in previous['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    reject=read(ROOT/(qa+'ordinary_continuous_gait_rejected_v15.json'))
    assert not reject['qualified'] and reject['checks']==301 and reject['captures']==70
    for row in reject['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    for src_name,dst_name in [('receipt.json','ordinary_continuous_gait_failed_receipt_v15.json'),('gait/report.json','ordinary_continuous_gait_failed_report_v15.json')]:
        src=OUT/'ordinary_continuous_gait_v15_84f1500f'/src_name;dst=ROOT/(qa+dst_name)
        if not dst.exists():shutil.copy2(src,dst)
        assert sha(src)==sha(dst)
    c=read(ROOT/(qa+'rejected_continuous_import_cleanup_v15.json'))
    assert c['complete'] and c['deleted_files']==7476 and c['deleted_bytes']==1803637428
    assert c['protected_hash_drift']==c['keeper_match_hash_drift']==0 and sha(Path(c['full_inventory']))==c['full_inventory_sha256']
    docs={'docs/'+n for n in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']}
    allowed=set(docs)
    allowed.update(qa+'harness/'+n for n in ['ordinary_continuous_gait_v15.gd','ordinary_continuous_gait_v15a.gd','ordinary_continuous_gait_v15b.gd',
        'run_ordinary_continuous_gait_v15.py','run_ordinary_continuous_gait_v15a.py','run_ordinary_continuous_gait_v15b.py',
        'ordinary_skill_clearance_v16.gd','run_ordinary_skill_clearance_v16.py'])
    allowed.update(qa+n for n in ['ordinary_continuous_gait_mechanical_v15a.json','ordinary_continuous_gait_qualified_v15b.json',
        'ordinary_continuous_gait_rejected_v15.json','ordinary_continuous_gait_failed_receipt_v15.json','ordinary_continuous_gait_failed_report_v15.json',
        'ordinary_continuous_gait_visual_review_v15a.json','ordinary_continuous_gait_visual_review_v15b.json','rejected_continuous_import_cleanup_v15.json'])
    reject_view=read(ROOT/(qa+'ordinary_continuous_gait_visual_review_v15a.json'));assert not reject_view['passed'] and reject_view['mechanical_passed']
    assert reject_view['receipt_sha256']==sha(ROOT/(qa+'ordinary_continuous_gait_mechanical_v15a.json'))
    for row in v['viewed']+v['reviewed_gait_appearance_ancestry']+reject_view['viewed_rejection']:
        assert sha(ROOT/row['path'])==row['sha256'];allowed.add(row['path'])
    allowed.update(td+n for n in ['cleanup_rejected_continuous_imports_v15.py','prepare_continuous_cache_cleanup_v15.py',
        'prepare_continuous_gait_v15a.py','prepare_continuous_gait_v15b.py','prepare_skill_clearance_runner_v16.py',
        'record_continuous_qualified_v15b.py','record_continuous_round_docs_v15.py','review_continuous_sync_v15.py'])
    names=[]
    for item in subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all','-z'],cwd=ROOT).decode('utf-8').split('\0'):
        if not item:continue
        assert item[:2] in [' M','??'];name=item[3:];assert name in allowed,name;names.append(name)
    assert set(names)==allowed,(allowed-set(names),set(names)-allowed)
    files=[]
    for name in sorted(names):
        p=ROOT/name;assert p.is_file() and p.stat().st_size<50*1024*1024
        assert not any(part in ['.git','.godot','profiles','build','__pycache__'] for part in Path(name).parts)
        if p.suffix in ['.py','.gd','.json','.md']:
            content=p.read_text(encoding='utf-8')
            assert not re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{30,}|\bsk-proj-[A-Za-z0-9_-]{20,}',content),name
            if p.suffix=='.py':ast.parse(content,filename=name)
        files.append({'path':name,'bytes':p.stat().st_size,'sha256':sha(p),'git_expected_blob':git('hash-object',name),'normalization':'Git text filter' if name in docs else 'native bytes'})
    proof={'passed':True,'parent':parent,'branch':branch,'files':files,'bytes':sum(x['bytes'] for x in files),'secret_findings':[],
        'checks':441,'captures':70,'current_direct_views':14,'direct_appearance_ancestry_views':32,'production_changed':False,
        'cleanup_files':7476,'cleanup_bytes':1803637428,'next_skill_producer_included':True,'next_skill_qualification':False,
        'full_goal_qualified':False,'platform_released':False}
    p=OUT/'continuous_sync_review_v15.json';assert not p.exists();p.write_bytes((json.dumps(proof,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    p=OUT/'continuous_sync_whitelist_v15.nul';assert not p.exists();p.write_bytes(b'\0'.join(n.encode('utf-8') for n in sorted(names))+b'\0')
    print(json.dumps({'passed':True,'files':len(files),'bytes':proof['bytes'],'checks':441,'secret_findings':0,'next_skill_qualified':False,'production_changed':False}))
if __name__=='__main__':main()
