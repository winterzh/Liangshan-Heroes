"""Review only owned installed chapter components and preserved executed QA ancestry."""
from pathlib import Path
import ast,hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT.parent/'qa-ordinary-posture-20261006'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT).decode('utf-8').strip()
def main():
    parent='d561d78c4bb9f6357e24436d2c8cdfddab48a4e2';branch='codex/sync-20260905-stable'
    assert git('branch','--show-current')==branch and git('remote','get-url','origin')=='https://github.com/winterzh/Liangshan-Heroes.git'
    assert git('rev-parse','HEAD')==parent==git('ls-remote','origin','refs/heads/'+branch).split()[0]
    assert not git('diff','--cached','--name-only')
    qa='qa/zhu_wounded_20261005/';td='tools/contracts/zhu_wounded_20261005/'
    r=read(ROOT/(qa+'campaign_foundation_qualified_v18b.json'));v=read(ROOT/(qa+'campaign_foundation_review_v18b.json'))
    assert r['complete'] and r['lock_released'] and r['result']['passed'] and r['result']['checks']==76
    assert r['private_runtime_patches']==r['root_input_drift']==r['private_input_drift']==0 and len(r['source_files'])==5036
    assert v['passed'] and not v['requirements']['unit_state_graph_restore'] and not v['full_goal_qualified']
    assert sha(ROOT/(qa+'campaign_foundation_qualified_v18b.json'))==v['receipt_sha256']
    assert sha(ROOT/(qa+'campaign_foundation_verified_log_v18b.txt'))==v['log_sha256']
    for row in r['source_files']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    for name in ['campaign_foundation_rejected_v18.json','campaign_foundation_rejected_v18a.json']:
        previous=read(ROOT/(qa+name));assert not previous['qualified']
        for row in previous['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    c=read(ROOT/(qa+'failed_campaign_import_cleanup_v18.json'));assert c['complete'] and c['protected_hash_drift']==c['keeper_match_hash_drift']==0
    assert sha(Path(c['full_inventory']))==c['full_inventory_sha256']
    production={'scripts/run_official_restore_profile.gd','scripts/levels/level5_gao_rts.gd','scripts/run_level5_world_factory.gd','scripts/run_level8_world_factory.gd'}
    allowed=set(production)
    allowed.update('docs/'+n for n in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md'])
    allowed.update(qa+'harness/'+n for n in ['campaign_foundation_v18.gd','run_campaign_foundation_v18.py','campaign_foundation_v18a.gd','run_campaign_foundation_v18a.py','campaign_foundation_v18b.gd','run_campaign_foundation_v18b.py'])
    allowed.update(qa+n for n in ['campaign_foundation_patch_v18.json','campaign_profile_line_endings_v18.json','campaign_gao_factory_fix_v18b.json','campaign_foundation_failed_receipt_v18.json','campaign_foundation_rejected_v18.json','campaign_foundation_failed_receipt_v18a.json','campaign_foundation_rejected_v18a.json','campaign_foundation_failed_log_v18a.txt','campaign_foundation_qualified_v18b.json','campaign_foundation_verified_log_v18b.txt','campaign_foundation_review_v18b.json','failed_campaign_import_cleanup_v18.json'])
    allowed.update(td+n for n in ['prepare_campaign_foundation_v18.py','preserve_profile_line_endings_v18.py','prepare_campaign_foundation_v18a.py','prepare_campaign_foundation_v18b.py','record_campaign_foundation_v18.py','cleanup_failed_campaign_imports_v18.py','record_campaign_cleanup_v18.py','review_campaign_sync_v18.py'])
    actual=[]
    for row in subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all','-z'],cwd=ROOT).decode('utf-8').split('\0'):
        if row:assert row[:2] in [' M','??'];actual.append(row[3:])
    assert set(actual)==allowed,(set(actual)-allowed,allowed-set(actual))
    assert set(git('diff','--name-only','--','scripts','assets').splitlines())=={'scripts/run_official_restore_profile.gd','scripts/levels/level5_gao_rts.gd'}
    for n in ['scripts/continue_flow.gd','scripts/run_unit_graph.gd','scripts/run_unit_state.gd','scripts/run_battle_world_core.gd','scripts/run_scenery_state.gd','scripts/run_visual_graph.gd','scripts/battle.gd','scripts/unit.gd','scripts/defs.gd']:
        assert sha(ROOT/n)==hashlib.sha256(subprocess.check_output(['git','show',parent+':'+n],cwd=ROOT)).hexdigest()
    files=[]
    for n in sorted(allowed):
        p=ROOT/n;assert p.is_file() and p.stat().st_size<50*1024*1024
        assert not any(x in ['.git','.godot','build','profiles','__pycache__'] for x in Path(n).parts)
        text=p.read_text(encoding='utf-8')
        assert not re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{30,}|\bsk-proj-[A-Za-z0-9_-]{20,}',text),n
        if p.suffix=='.py':ast.parse(text,filename=n)
        files.append({'path':n,'bytes':p.stat().st_size,'sha256':sha(p),'git_expected_blob':git('hash-object',n)})
    review={'passed':True,'parent':parent,'branch':branch,'files':files,'bytes':sum(x['bytes'] for x in files),'production_changed':sorted(production),'component_checks':76,'inputs':5036,'source_drift':0,'private_runtime_patches':0,'cleanup_files':c['deleted_files'],'cleanup_bytes':c['deleted_bytes'],'secret_findings':[],'full_world_qualified':False,'full_goal_qualified':False,'platform_released':False}
    p=OUT/'campaign_sync_review_v18.json';assert not p.exists();p.write_bytes((json.dumps(review,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    p=OUT/'campaign_sync_whitelist_v18.nul';assert not p.exists();p.write_bytes(b'\0'.join(n.encode('utf-8') for n in sorted(allowed))+b'\0')
    print(json.dumps({'passed':True,'files':len(files),'bytes':review['bytes'],'component_checks':76,'full_world_qualified':False}))
if __name__=='__main__':main()
