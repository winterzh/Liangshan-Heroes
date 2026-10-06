"""Review the exact owned v14 production/evidence/document whitelist before stable sync."""
from pathlib import Path
import ast,hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT.parent/'qa-ordinary-posture-20261006'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT).decode('utf-8').strip()
def main():
    parent='7ebfe4e3d5f4e87fc25e5d86dda69b4c6ac0eed5';branch='codex/sync-20260905-stable'
    assert git('branch','--show-current')==branch and git('remote','get-url','origin')=='https://github.com/winterzh/Liangshan-Heroes.git'
    assert git('rev-parse','HEAD')==parent==git('ls-remote','origin','refs/heads/'+branch).split()[0]
    assert not git('diff','--cached','--name-only')
    qa='qa/zhu_wounded_20261005/';td='tools/contracts/zhu_wounded_20261005/'
    rp=ROOT/(qa+'ordinary_production_qualified_v14.json');r=read(rp)
    assert r['complete'] and r['lock_released'] and r['covered_default_routes_verified'] and r['private_runtime_patches']==0
    assert r['root_input_drift']==r['private_input_drift']==0
    assert r['results']['combat']['checks']==369 and r['results']['death']['checks']==346
    assert all(x['passed'] and x['engine_time_scale']==1.0 for x in r['results'].values())
    for row in r['source_files']+r['candidate_inputs']+r['new_inputs']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    registry=read(ROOT/(qa+'ordinary_character_default_routes_v14.json'))
    assert registry['current_default_routes_verified'] and len(registry['resources'])==36 and registry['evidence_sha256']==sha(rp)
    for row in registry['resources']+registry['production_scripts']+registry['source_manifests']:assert sha(ROOT/row['path'])==row['sha256']
    m=read(ROOT/'assets/direction4/ordinary_lin_chong_20261007_hurt_v12.json')
    for row in m['preserved_resources']:assert sha(ROOT/row['original'])==sha(ROOT/row['alias'])==row['sha256']
    c=read(ROOT/(qa+'failed_death_import_cleanup_v14.json'))
    assert c['complete'] and c['deleted_files']==3738 and c['deleted_bytes']==901818714
    assert c['protected_hash_drift']==c['keeper_match_hash_drift']==0 and sha(Path(c['full_inventory']))==c['full_inventory_sha256']
    docs={'docs/'+n for n in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']}
    allowed={'.gitattributes','scripts/art_db.gd','assets/direction4/ordinary_lin_chong_20261007_hurt_v12.json'}|set(m['resources'])|docs
    allowed.update(qa+n for n in ['death_diagnostic_source_sync_v10.json','ordinary_character_default_routes_v14.json','failed_death_import_cleanup_v14.json',
        'ordinary_death_pilot_qualified_v10a.json','ordinary_death_pilot_visual_review_v10a.json','ordinary_hurt_pilot_qualified_v13.json','ordinary_hurt_pilot_visual_review_v13.json',
        'ordinary_production_qualified_v14.json','ordinary_production_visual_review_v14.json'])
    for name,receipt_key,receipt_name in [('ordinary_death_pilot_visual_review_v10a.json','pilot_receipt_sha256','ordinary_death_pilot_qualified_v10a.json'),
        ('ordinary_hurt_pilot_visual_review_v13.json','pilot_receipt_sha256','ordinary_hurt_pilot_qualified_v13.json'),
        ('ordinary_production_visual_review_v14.json','production_receipt_sha256','ordinary_production_qualified_v14.json')]:
        v=read(ROOT/(qa+name));assert v['passed'] and v[receipt_key]==sha(ROOT/(qa+receipt_name))
        for row in v['viewed']:assert sha(ROOT/row['path'])==row['sha256'];allowed.add(row['path'])
    allowed.update(qa+'harness/'+n for n in ['ordinary_combat_production_v14.gd','ordinary_death_production_v14.gd','ordinary_hurt_pilot_v13.gd','run_ordinary_hurt_pilot_v13.py','run_ordinary_production_v14.py'])
    allowed.update(td+n for n in ['build_lin_sw_hurt_frames_v12.py','cleanup_failed_death_imports_v14.py','prepare_failed_death_cleanup_v14.py',
        'prepare_ordinary_hurt_pilot_v13.py','prepare_ordinary_production_v14.py','record_death_and_hurt_docs_v13.py','record_death_pilot_qualified_v10a.py',
        'record_hurt_pilot_review_v13.py','record_ordinary_adoption_docs_v14.py','record_ordinary_production_v14.py','record_production_round_docs_v14.py','review_production_sync_v14.py'])
    names=[]
    for item in subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all','-z'],cwd=ROOT).decode('utf-8').split('\0'):
        if not item:continue
        assert item[:2] in [' M','??'];name=item[3:];assert name in allowed,name;names.append(name)
    assert set(names)==allowed,(allowed-set(names),set(names)-allowed)
    assert set(git('diff','--name-only','--','scripts').splitlines())=={'scripts/art_db.gd'}
    files=[]
    for name in sorted(names):
        p=ROOT/name;assert p.is_file() and p.stat().st_size<50*1024*1024
        assert not any(part in ['.git','.godot','profiles','build','__pycache__'] for part in Path(name).parts)
        if p.suffix in ['.py','.gd','.json','.md','.import','.tres'] or name=='.gitattributes':
            content=p.read_text(encoding='utf-8')
            assert not re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{30,}|\bsk-proj-[A-Za-z0-9_-]{20,}',content),name
            if p.suffix=='.py':ast.parse(content,filename=name)
        files.append({'path':name,'bytes':p.stat().st_size,'sha256':sha(p),'git_expected_blob':git('hash-object',name),'normalization':'Git text filter' if name in docs or name=='.gitattributes' else 'native bytes'})
    result={'passed':True,'parent':parent,'branch':branch,'files':files,'bytes':sum(x['bytes'] for x in files),'secret_findings':[],
        'checks':715,'captures':80,'visual_reviewed':12,'default_resources':36,'production_scripts_changed':['scripts/art_db.gd'],
        'private_runtime_patches':0,'root_input_drift':0,'cleanup_files':3738,'cleanup_bytes':901818714,'full_goal_qualified':False,'platform_released':False}
    p=OUT/'ordinary_production_sync_review_v14.json';assert not p.exists();p.write_bytes((json.dumps(result,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    p=OUT/'ordinary_production_sync_whitelist_v14.nul';assert not p.exists();p.write_bytes(b'\0'.join(x.encode('utf-8') for x in sorted(names))+b'\0')
    print(json.dumps({'passed':True,'files':len(files),'bytes':result['bytes'],'secret_findings':0,'checks':715,'default_resources':36,'full_goal_qualified':False}))
if __name__=='__main__':main()
