"""Record completed candidate death/shadow qualification and remaining living hurt issue."""
from pathlib import Path
import hashlib,json,shutil

ROOT=Path(__file__).resolve().parents[3]
QA=ROOT/'qa/zhu_wounded_20261005'
RUN=ROOT.parent/'qa-ordinary-posture-20261006/ordinary_death_pilot_v10a_0291f705'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def dump(p,v):assert not p.exists();p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))

def main():
    rp=RUN/'receipt.json';r=read(rp)
    assert r['complete'] and r['lock_released'] and r['private_patch_verified'] and r['candidate_death_routes_verified']
    assert r['root_input_drift']==r['private_input_drift_except_declared_patch']==0
    assert r['result']['passed'] and r['result']['checks']==346 and len(r['result']['screenshots'])==32
    for row in r['source_files']+r['candidate_inputs']+r['new_inputs']:assert sha(ROOT/row['path'])==row['sha256']
    target=QA/'ordinary_death_pilot_qualified_v10a.json';assert not target.exists();shutil.copy2(rp,target)
    names={'lin_chong_sw_death_'+str(i) for i in range(4)}|{'wu_song_'+d+'_death_2' for d in ['se','sw','ne','nw']}
    directory=QA/'ordinary_death_pilot_review_v10a_frames';directory.mkdir(exist_ok=False);viewed=[]
    for name in sorted(names):
        row=next(x for x in r['result']['screenshots'] if x['name']==name);source=Path(row['path'])
        assert sha(source)==row['sha256'];dst=directory/source.name;shutil.copy2(source,dst);assert sha(dst)==row['sha256']
        viewed.append({'case':name,'path':dst.relative_to(ROOT).as_posix(),'sha256':sha(dst)})
    old=read(QA/'ordinary_final_actions_pilot_v8a.json')
    before={x['case']:x['observed'] for x in old['results']['death']['runtime'] if 'observed' in x}
    after={x['case']:x['observed'] for x in r['result']['runtime'] if 'observed' in x}
    for name in before:
        if name.startswith('lin_chong_sw'):continue
        assert before[name]['source']==after[name]['source'] and before[name]['pose']==after[name]['pose']
    dump(QA/'ordinary_death_pilot_visual_review_v10a.json',{
        'passed':True,'death_qualified':True,'pilot_receipt':str(rp),'pilot_receipt_sha256':sha(rp),'viewed':viewed,
        'checks':346,'captures':32,'root_input_drift':0,'private_input_drift_except_declared_patch':0,
        'other_death_source_pose_changes':0,'production_default_adopted':False,
        'findings':['Corrected Lin SW four actual phases directly viewed: left-facing recoil/fall and left-headed grounded rest, one full spear, adult body identity/scale retained.',
                    'Four current Wu rest phases directly viewed; all Wu phase source/pose identities equal the sixteen directly reviewed v8a death phases.',
                    'Actual original level1 combat/death removes live registration and releases node; direct actual shadow batch retention/pruning checks passed in all eight actor/direction cases.',
                    'Lin SW living hurt still uses the exact old wrong-heading death-recoil region. New v12 standing-hurt candidate prepared; actual normal counterhit validation required.'],
        'scope':'Candidate death/shadow qualification only, private ArtDB lookup fixture. No root production adoption, living-hurt approval, continuous/multi-size UI, natural chapter/save/performance/platform or full-goal completion.'})
    print(json.dumps({'checks':346,'captures':32,'directly_saved_viewports':8,'candidate_death_qualified':True,'production_adopted':False,'living_hurt_pending':True}))

if __name__=='__main__':main()
