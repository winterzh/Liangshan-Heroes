"""Record unchanged-production evidence, reviewed native views and 36 default resources."""
from pathlib import Path
import hashlib,json,shutil

ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005'
RUN=ROOT.parent/'qa-ordinary-posture-20261006/ordinary_production_v14_088ab281'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def dump(p,v):assert not p.exists();p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))

def main():
    rp=RUN/'receipt.json';r=read(rp)
    assert r['complete'] and r['lock_released'] and r['covered_default_routes_verified'] and r['private_runtime_patches']==0
    assert r['root_input_drift']==r['private_input_drift']==0 and set(r['results'])=={'combat','death'}
    assert r['results']['combat']['checks']==369 and r['results']['death']['checks']==346
    assert all(x['passed'] and x['engine_time_scale']==1.0 for x in r['results'].values())
    assert len(r['results']['combat']['screenshots'])==48 and len(r['results']['death']['screenshots'])==32
    for row in r['source_files']+r['candidate_inputs']+r['new_inputs']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    target=QA/'ordinary_production_qualified_v14.json';assert not target.exists();shutil.copy2(rp,target);assert sha(target)==sha(rp)
    cases=[('combat',name) for name in ['lin_chong_sw_idle','lin_chong_sw_hurt','lin_chong_sw_walk','wu_song_sw_attack']]
    cases += [('death','lin_chong_sw_death_'+str(i)) for i in range(4)]
    cases += [('death','wu_song_'+d+'_death_2') for d in ['se','sw','ne','nw']]
    directory=QA/'ordinary_production_review_v14_frames';directory.mkdir(exist_ok=False);viewed=[]
    for stage,name in cases:
        row=next(x for x in r['results'][stage]['screenshots'] if x['name']==name);src=Path(row['path']);assert sha(src)==row['sha256']
        dst=directory/src.name;shutil.copy2(src,dst);assert sha(dst)==row['sha256']
        viewed.append({'case':name,'stage':stage,'path':dst.relative_to(ROOT).as_posix(),'sha256':sha(dst)})
    review_path=QA/'ordinary_production_visual_review_v14.json'
    dump(review_path,{'passed':True,'production_receipt':str(rp),'production_receipt_sha256':sha(rp),'viewed':viewed,
        'checks':715,'captures':80,'private_runtime_patches':0,'covered_default_routes_verified':True,
        'findings':['Current production Lin SW normal nonlethal hurt/recovered walk and all four SW death phases directly viewed: consistent left-facing adult identity, complete spear and grounded terminal pose.',
                    'Current production Wu SW normal attack and all four grounded death directions directly viewed: mature body identity and two sabres preserved.',
                    'Real original combat and death/shadow retention/pruning/Unit release completed in separate normal-clock processes. Source/resource inputs unchanged during verification.'],
        'scope':'Reviewed current default ordinary Wu death and Lin SW death/standing-hurt plus original combat/HUD transitions only. Contact/freeze/phase/fog/zoom are fixtures. Continuous gait/cast clearance/multi-size UI, full chapter/save/nine-mode/performance/export/platform and full-goal qualification remain open.'})
    paths=set();manifests=[]
    for name in ['ordinary_wu_song_20261006_gait_v5.json','ordinary_lin_chong_20261006_gait_v5.json','ordinary_wu_song_20261007_combat_v7.json',
                 'ordinary_wu_song_20261007_death_v8.json','ordinary_lin_chong_20261007_death_v10.json','ordinary_lin_chong_20261007_hurt_v12.json']:
        p=ROOT/'assets/direction4'/name;m=read(p);paths.update(m['resources']);manifests.append({'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)})
    assert len(paths)==36
    routes={'wu_song':{'idle':'character_traits_v5_wu_song_gait','walk':'character_traits_v5_wu_song_gait','attack':'character_traits_v7_wu_song_combat',
                       'hurt':'character_traits_v7_wu_song_combat','death':'character_traits_v8_wu_song_death'},
            'lin_chong':{'idle':'character_traits_v5_lin_chong_gait','walk':'character_traits_v5_lin_chong_gait','death':'character_traits_v10_lin_chong_death','hurt':'character_traits_v12_lin_chong_hurt'}}
    dump(QA/'ordinary_character_default_routes_v14.json',{'current_default_routes_verified':True,'routes':routes,
        'resources':[{'path':p,'sha256':sha(ROOT/p)} for p in sorted(paths)],'source_manifests':manifests,
        'production_scripts':[{'path':p,'sha256':sha(ROOT/p)} for p in ['scripts/art_db.gd','scripts/unit.gd']],
        'evidence':target.relative_to(ROOT).as_posix(),'evidence_sha256':sha(target),
        'scope':'Current empty-explicit-variant ordinary default state registry only; Lin SE/NE/NW death and hurt aliases preserve exact old frames. Authoring manifests retain historical candidate flags; runtime adoption proven by this separate current registry and unchanged-production evidence.'})
    print(json.dumps({'checks':715,'captures':80,'viewed':12,'default_resources':36,'private_patches':0,'root_drift':0}))

if __name__=='__main__':main()
