"""Whitelist diagnostic evidence and unadopted native correction inputs for stable."""
from pathlib import Path
import ast,hashlib,json,re,subprocess

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT.parent/'qa-ordinary-posture-20261006'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT).decode('utf-8').strip()

def main():
    parent='88d6c3f6f3dee4a508ccf45c5eb459a03704dc06';branch='codex/sync-20260905-stable'
    assert git('branch','--show-current')==branch and git('remote','get-url','origin')=='https://github.com/winterzh/Liangshan-Heroes.git'
    assert git('rev-parse','HEAD')==parent==git('ls-remote','origin','refs/heads/'+branch).split()[0]
    assert not git('diff','--cached','--name-only')
    qa='qa/zhu_wounded_20261005/';tools='tools/contracts/zhu_wounded_20261005/'
    r=read(ROOT/(qa+'ordinary_final_actions_pilot_v8a.json'));review=read(ROOT/(qa+'ordinary_final_actions_pilot_visual_review_v8a.json'))
    assert r['complete'] and r['lock_released'] and r['root_input_drift']==0
    assert review['mechanical_checks']==661 and review['actual_viewport_captures']==96 and not review['passed']
    assert sha(ROOT/(qa+'ordinary_final_actions_pilot_v8a.json'))==review['pilot_receipt_sha256']
    for row in r['source_files']+r['candidate_inputs']+r['new_inputs']:assert sha(ROOT/row['path'])==row['sha256']
    m=read(ROOT/'assets/direction4/ordinary_lin_chong_20261007_death_v10.json')
    assert not m['production_qualified'] and not m['runtime_death_qualified'] and len(m['poses'])==4
    native=read(ROOT/(qa+'lin_sw_death_native_texture_v10.json'));assert native['complete'] and native['lock_released'] and native['dimensions']['passed']
    for row in m['sources'].values():assert row['import_dimensions_verified'] and sha(ROOT/row['path'])==row['sha256']
    for row in m['preserved_resources']:assert sha(ROOT/row['original'])==sha(ROOT/row['alias'])==row['sha256']
    lineage=read(ROOT/(tools+'generation_lin_chong_death_v10.json'))
    allowed={'.gitattributes','assets/direction4/ordinary_lin_chong_20261007_death_v10.json'}|set(m['resources'])
    for row in lineage['jobs']:
        assert sha(ROOT/row['path'])==row['sha256'] and sha(ROOT/row['request'])==row['request_sha256'] and not row['native_pixel_edits']
        allowed.update([row['path'],row['request']])
        for ref in row['references']:assert sha(ROOT/ref['path'])==ref['sha256']
    for row in m['sources'].values():allowed.add(row['path']+'.import')
    for row in review['viewed']:assert sha(ROOT/row['path'])==row['sha256'];allowed.add(row['path'])
    allowed.update(qa+n for n in ['ordinary_final_actions_pilot_v8a.json','ordinary_final_actions_pilot_visual_review_v8a.json',
        'lin_sw_death_native_texture_v10.json','lin_sw_death_sampling_v10.json','ordinary_death_pilot_preparation_v10.json',
        'ordinary_death_pilot_preparation_v10a.json','ordinary_death_pilot_rejected_v10.json'])
    allowed.update(qa+'harness/'+n for n in ['ordinary_death_production_v9.gd','run_ordinary_death_production_v9.py',
        'ordinary_death_pilot_v10.gd','run_ordinary_death_pilot_v10.py','ordinary_death_pilot_v10a.gd','run_ordinary_death_pilot_v10a.py','texture_bootstrap_lin_death_v10.py'])
    allowed.update(tools+n for n in ['prepare_ordinary_death_production_v9.py','prepare_ordinary_death_pilot_v10.py','prepare_ordinary_death_pilot_v10a.py',
        'build_lin_sw_death_frames_v10.py','generation_lin_chong_death_v10.json','record_final_actions_pilot_review_v8a.py',
        'record_death_diagnostic_docs_v10.py','record_lin_death_import_and_fixture_v10.py','review_death_diagnostic_sync_v10.py'])
    docs={'docs/'+n for n in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']}
    allowed.update(docs)
    rejected=read(ROOT/(qa+'ordinary_death_pilot_rejected_v10.json'));assert not rejected['qualified'] and rejected['lock_released']
    for row in rejected['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    names=[]
    for item in subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all','-z'],cwd=ROOT).decode('utf-8').split('\0'):
        if not item:continue
        assert item[:2] in [' M','??'];name=item[3:];assert name in allowed,name;names.append(name)
    assert set(names)==allowed,(allowed-set(names),set(names)-allowed)
    files=[]
    for name in sorted(names):
        p=ROOT/name;assert p.is_file() and p.stat().st_size<50*1024*1024
        assert not any(part in ['.git','.godot','profiles','build','__pycache__'] for part in Path(name).parts)
        if p.suffix in ['.py','.gd','.json','.md','.import','.tres'] or name=='.gitattributes':
            text=p.read_text(encoding='utf-8');assert not re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{30,}|\bsk-proj-[A-Za-z0-9_-]{20,}',text),name
            if p.suffix=='.py':ast.parse(text,filename=name)
        files.append({'path':name,'bytes':p.stat().st_size,'sha256':sha(p),'git_expected_blob':git('hash-object',name),
                      'normalization':'Git text filter for documents/attributes' if name in docs or name=='.gitattributes' else 'native bytes'})
    evidence={'passed':True,'parent':parent,'branch':branch,'files':files,'bytes':sum(x['bytes'] for x in files),'secret_findings':[],
              'mechanical_checks':661,'captures':96,'overall_visual_qualified':False,'new_lin_sw_native_import_qualified':True,
              'production_scripts_changed':False,'candidate_default_adopted':False,'platform_released':False,
              'scope':'Completed v8a mechanics and actual visual rejection; native Lin SW correction and provenance/import; exact failed v10 and executing v10a sibling. V9 prototypes retained as generation inputs, never executed. Full new death/production/continuous qualification remains open.'}
    p=OUT/'death_diagnostic_sync_review_v10.json';assert not p.exists();p.write_bytes((json.dumps(evidence,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    p=OUT/'death_diagnostic_sync_whitelist_v10.nul';assert not p.exists();p.write_bytes(b'\0'.join(x.encode('utf-8') for x in sorted(names))+b'\0')
    print(json.dumps({'passed':True,'files':len(files),'bytes':evidence['bytes'],'overall_visual_qualified':False,'production_changed':False,'secret_findings':0}))

if __name__=='__main__':main()
