"""Review exact owned original Unit graph source, native evidence and failed ancestry."""
from pathlib import Path
import ast,hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT.parent/'qa-ordinary-posture-20261006'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT).decode('utf-8').strip()
def main():
    branch='codex/sync-20260905-stable';parent='e1d546d04cb166905ac5493afbc5275d95c87574'
    assert git('branch','--show-current')==branch and git('remote','get-url','origin')=='https://github.com/winterzh/Liangshan-Heroes.git'
    assert git('rev-parse','HEAD')==parent==git('ls-remote','origin','refs/heads/'+branch).split()[0]
    assert not git('diff','--cached','--name-only')
    qa='qa/zhu_wounded_20261005/';td='tools/contracts/zhu_wounded_20261005/'
    r=read(ROOT/(qa+'campaign_units_qualified_v19d.json'));v=read(ROOT/(qa+'campaign_units_review_v19d.json'))
    assert r['complete'] and r['lock_released'] and r['result']['passed'] and r['unit_graph_qualified']
    assert r['root_input_drift']==r['private_input_drift']==r['private_runtime_patches']==0 and len(r['source_files'])==5038
    assert v['passed'] and len(v['cases'])==7 and not v['full_world_qualified'] and not v['full_goal_qualified']
    assert v['receipt_sha256']==sha(ROOT/(qa+'campaign_units_qualified_v19d.json')) and v['log_sha256']==sha(ROOT/(qa+'campaign_units_verified_log_v19d.txt'))
    for row in r['source_files']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    for name in ['campaign_units_rejected_v19b.json','campaign_units_rejected_v19c.json']:
        previous=read(ROOT/(qa+name));assert not previous['qualified']
        for row in previous['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    cancelled=read(ROOT/(qa+'campaign_units_preimport_cancelled_v19.json'));assert not cancelled['engine_started'] and cancelled['lock_released']
    for row in cancelled['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    audit=read(ROOT/(qa+'remaining_world_restore_audit_v20.json'));assert not audit['runtime_qualified']
    for row in audit['sources']:assert sha(ROOT/row['path'])==row['sha256']
    c=read(ROOT/(qa+'failed_unit_graph_import_cleanup_v19.json'));assert c['complete'] and c['protected_hash_drift']==c['keeper_match_hash_drift']==0
    assert sha(Path(c['full_inventory']))==c['full_inventory_sha256']
    allowed={'.gitattributes','scripts/run_unit_state.gd','scripts/run_unit_graph.gd','scripts/run_level5_unit_contract.gd','scripts/run_level8_unit_contract.gd'}
    allowed.update('docs/'+n for n in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md'])
    allowed.update(qa+'harness/'+n for n in ['campaign_units_v19.gd','run_campaign_units_v19.py','campaign_units_v19b.gd','run_campaign_units_v19b.py','campaign_units_v19c.gd','run_campaign_units_v19c.py','campaign_units_v19d.gd','run_campaign_units_v19d.py'])
    allowed.update(qa+n for n in ['campaign_naval_definition_fix_v19c.json','campaign_units_contract_review_fix_v19b.json','campaign_units_gate_review_fix_v19.json','campaign_units_patch_v19.json','campaign_units_preimport_cancelled_v19.json','campaign_units_preparer_rejected_v19.json','campaign_units_review_preparer_rejected_v19a.json','campaign_units_failed_receipt_v19b.json','campaign_units_failed_report_v19b.json','campaign_units_failed_log_v19b.txt','campaign_units_rejected_v19b.json','campaign_units_failed_receipt_v19c.json','campaign_units_failed_report_v19c.json','campaign_units_failed_log_v19c.txt','campaign_units_rejected_v19c.json','campaign_units_qualified_v19d.json','campaign_units_verified_log_v19d.txt','campaign_units_review_v19d.json','failed_unit_graph_import_cleanup_v19.json','remaining_world_restore_audit_v20.json'])
    allowed.update(td+n for n in ['prepare_campaign_units_v19.py','prepare_campaign_units_v19a.py','close_unit_review_wait_v19.py','prepare_unit_review_v19a.py','prepare_unit_review_v19b.py','prepare_naval_definition_v19c.py','prepare_unit_mission_shell_v19d.py','record_campaign_units_v19.py','record_campaign_units_v19d.py','cleanup_failed_unit_graph_imports_v19.py','cleanup_failed_unit_graph_imports_v19d.py','record_unit_graph_cleanup_v19.py','review_unit_graph_sync_v19.py','audit_remaining_world_restore_v20.py'])
    allowed.add(td+'fix_unit_evidence_names_v19d.py');allowed.add(qa+'campaign_units_evidence_names_v19d.json')
    for row in v['cases']+read(ROOT/(qa+'campaign_units_rejected_v19c.json'))['snapshots']:
        assert sha(ROOT/row['path'])==row['sha256'];allowed.add(row['path'])
    actual=[]
    for row in subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all','-z'],cwd=ROOT).decode('utf-8').split('\0'):
        if row:assert row[:2] in [' M','??'];actual.append(row[3:])
    assert set(actual)==allowed,(set(actual)-allowed,allowed-set(actual))
    assert set(git('diff','--name-only','--','scripts','assets').splitlines())=={'scripts/run_unit_state.gd','scripts/run_unit_graph.gd'}
    for n in ['scripts/continue_flow.gd','scripts/run_state_value_codec.gd','scripts/unit.gd','scripts/defs.gd','scripts/battle.gd','scripts/run_battle_world_core.gd','scripts/run_scenery_state.gd','scripts/run_visual_graph.gd']:
        assert sha(ROOT/n)==hashlib.sha256(subprocess.check_output(['git','show',parent+':'+n],cwd=ROOT)).hexdigest()
    for n in ['scripts/run_level5_unit_contract.gd','scripts/run_level8_unit_contract.gd']:assert git('check-attr','text','--',n).endswith('text: unset')
    files=[]
    for name in sorted(allowed):
        p=ROOT/name;assert p.is_file() and p.stat().st_size<50*1024*1024
        assert not any(part in ['.git','.godot','build','profiles','__pycache__'] for part in Path(name).parts)
        content=p.read_text(encoding='utf-8')
        assert not re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{30,}|\bsk-proj-[A-Za-z0-9_-]{20,}',content),name
        if p.suffix=='.py':ast.parse(content,filename=name)
        files.append({'path':name,'bytes':p.stat().st_size,'sha256':sha(p),'git_expected_blob':git('hash-object',name)})
    review={'passed':True,'parent':parent,'branch':branch,'files':files,'bytes':sum(x['bytes'] for x in files),'unit_graph_checks':r['result']['checks'],'unit_graph_cases':7,'inputs':5038,'source_drift':0,'private_runtime_patches':0,'production_changed':['scripts/run_unit_graph.gd','scripts/run_unit_state.gd','scripts/run_level5_unit_contract.gd','scripts/run_level8_unit_contract.gd'],'cleanup_files':c['deleted_files'],'cleanup_bytes':c['deleted_bytes'],'secret_findings':[],'full_world_qualified':False,'full_goal_qualified':False,'platform_released':False}
    p=OUT/'unit_graph_sync_review_v19.json';assert not p.exists();p.write_bytes((json.dumps(review,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    p=OUT/'unit_graph_sync_whitelist_v19.nul';assert not p.exists();p.write_bytes(b'\0'.join(n.encode('utf-8') for n in sorted(allowed))+b'\0')
    print(json.dumps({'passed':True,'files':len(files),'bytes':review['bytes'],'checks':r['result']['checks'],'full_world_qualified':False}))
if __name__=='__main__':main()
