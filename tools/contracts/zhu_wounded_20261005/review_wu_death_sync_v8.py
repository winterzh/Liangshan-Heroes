"""Review the exact candidate checkpoint whitelist; never qualify a live pilot."""
from pathlib import Path
import ast, hashlib, json, re, subprocess

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT.parent/'qa-ordinary-posture-20261006'

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf-8'))
def git(*args): return subprocess.check_output(['git',*args],cwd=ROOT).decode('utf-8').strip()

def main():
    parent='db9d2f84d6065c850a9693d6fe3a8cf668c52d9b';branch='codex/sync-20260905-stable'
    assert git('branch','--show-current')==branch
    assert git('remote','get-url','origin')=='https://github.com/winterzh/Liangshan-Heroes.git'
    assert git('rev-parse','HEAD')==parent==git('ls-remote','origin','refs/heads/'+branch).split()[0]
    assert not git('diff','--cached','--name-only')
    m=read(ROOT/'assets/direction4/ordinary_wu_song_20261007_death_v8.json')
    assert not m['production_qualified'] and not m['runtime_death_qualified']
    native=read(ROOT/'qa/zhu_wounded_20261005/wu_death_native_review_v8.json')
    assert native['native_lineage_verified'] and not native['runtime_qualified']
    assert sha(ROOT/native['lineage'])==native['lineage_sha256']
    assert sha(ROOT/native['manifest'])==native['manifest_sha256']
    g=read(ROOT/native['lineage'])
    allowed={'.gitattributes','assets/direction4/ordinary_wu_song_20261007_death_v8.json'}|set(m['resources'])
    for job in g['jobs']:
        assert sha(ROOT/job['repository_path'])==job['sha256'] and sha(ROOT/job['request'])==job['request_sha256']
        allowed.update([job['repository_path'],job['request']])
        for ref in job['references']: assert sha(ROOT/ref['path'])==ref['sha256']
    for row in m['sources'].values():
        assert row['import_dimensions_verified'] and sha(ROOT/row['path'])==row['sha256']
        if '/death_' in row['path']: allowed.add(row['path']+'.import')
    docs={'docs/'+n for n in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']}
    allowed.update(docs)
    prefix='tools/contracts/zhu_wounded_20261005/'
    allowed.update(prefix+n for n in ['build_wu_death_frames_v8.py','generation_wu_song_death_v8.json','record_wu_death_candidate_v8.py','record_wu_death_checkpoint_v8.py','review_wu_death_sync_v8.py'])
    qa='qa/zhu_wounded_20261005/'
    allowed.update(qa+'harness/'+n for n in ['ordinary_skills_death_v8.gd','ordinary_skills_death_v8a.gd','run_ordinary_final_actions_v8.py','run_ordinary_final_actions_v8a.py','texture_bootstrap_wu_death_v8.py'])
    allowed.update(qa+n for n in ['wu_death_sampling_v8.json','wu_death_native_review_v8.json','ordinary_final_actions_rejected_v8.json','ordinary_lin_skill0_checkpoint_v8a.json'])
    partial=read(ROOT/(qa+'ordinary_lin_skill0_checkpoint_v8a.json'))
    assert partial['result']['passed'] and partial['result']['checks']==61 and len(partial['result']['screenshots'])==8
    assert partial['root_input_drift']==0 and not partial['whole_pilot_complete'] and not partial['production_qualified']
    rejected=read(ROOT/(qa+'ordinary_final_actions_rejected_v8.json'))
    assert not rejected['qualified'] and rejected['lock_released']
    for row in partial['saved_native_viewports']+rejected['reviewed_native_viewports']:
        allowed.add(row['path']);assert sha(ROOT/row['path'])==row['sha256']
    names=[]
    raw=subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all','-z'],cwd=ROOT).decode('utf-8')
    for item in raw.split('\0'):
        if not item: continue
        assert item[:2] in [' M','??'],item
        name=item[3:];assert name in allowed,name;names.append(name)
    assert set(names)==allowed,(allowed-set(names),set(names)-allowed)
    files=[]
    for name in sorted(names):
        p=ROOT/name;assert p.is_file() and p.stat().st_size<50*1024*1024
        assert not any(part in ['.git','.godot','profiles','build','__pycache__'] for part in Path(name).parts)
        if p.suffix in ['.py','.gd','.json','.md','.import','.tres'] or name=='.gitattributes':
            text=p.read_text(encoding='utf-8')
            assert not re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|\bgh[pousr]_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{30,}|\bsk-proj-[A-Za-z0-9_-]{20,}',text),name
            if p.suffix=='.py': ast.parse(text,filename=name)
        files.append({'path':name,'bytes':p.stat().st_size,'sha256':sha(p),'git_expected_blob':git('hash-object',name),
                      'normalization':'Git text filter for docs/attributes' if name in docs or name=='.gitattributes' else 'native bytes'})
    evidence={'passed':True,'parent':parent,'branch':branch,'files':files,'bytes':sum(x['bytes'] for x in files),
              'secret_findings':[],'completed_stage_checks':61,'completed_stage_captures':8,
              'whole_pilot_complete':False,'production_scripts_changed':False,'platform_released':False,
              'scope':'Wu native death candidate resources and lineage/import audit; rejected fog fixture; corrected completed Lin skill0 checkpoint. Full skill/death pilot remains live. No default death adoption or full-goal completion.'}
    p=OUT/'wu_death_sync_review_v8.json';assert not p.exists()
    p.write_bytes((json.dumps(evidence,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    p=OUT/'wu_death_sync_whitelist_v8.nul';assert not p.exists();p.write_bytes(b'\0'.join(x.encode('utf-8') for x in sorted(names))+b'\0')
    print(json.dumps({'passed':True,'files':len(files),'bytes':evidence['bytes'],'secret_findings':0,'production_scripts_changed':False}))

if __name__=='__main__': main()
