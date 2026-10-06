"""Preserve completed mechanical evidence and separate the failed Lin SW visual."""
from pathlib import Path
import hashlib,json,shutil

ROOT=Path(__file__).resolve().parents[3]
RUN=ROOT.parent/'qa-ordinary-posture-20261006/ordinary_final_actions_v8a_f9097739'
QA=ROOT/'qa/zhu_wounded_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def dump(p,v):assert not p.exists();p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))

def main():
    receipt_path=RUN/'receipt.json';r=read(receipt_path)
    assert r['complete'] and r['lock_released'] and r['private_patch_verified']
    assert r['root_input_drift']==r['private_input_drift_except_declared_patch']==0
    assert all(x['passed'] and x['engine_time_scale']==1.0 for x in r['results'].values())
    assert sum(x['checks'] for x in r['results'].values())==661 and sum(len(x['screenshots']) for x in r['results'].values())==96
    for row in r['source_files']+r['candidate_inputs']+r['new_inputs']:assert sha(ROOT/row['path'])==row['sha256']
    dst=QA/'ordinary_final_actions_pilot_v8a.json';assert not dst.exists();shutil.copy2(receipt_path,dst)
    assert sha(dst)==sha(receipt_path)
    names={('skills_0','lin_chong_0_se_cast'),('skills_0','lin_chong_0_se_effect'),('skills_0','lin_chong_0_nw_cast'),
           ('skills_1','lin_chong_1_se_cast'),('skills_1','lin_chong_1_se_effect'),('skills_1','lin_chong_1_nw_cast'),('skills_1','lin_chong_1_nw_effect'),
           ('skills_2','lin_chong_2_ne_passive_attack'),('skills_3','lin_chong_3_se_effect'),('skills_3','lin_chong_3_sw_effect'),
           ('skills_4','wu_song_0_se_effect'),('skills_6','wu_song_2_se_effect'),('skills_6','wu_song_2_nw_cast'),('skills_7','wu_song_3_nw_effect')}
    names.update(('skills_4','wu_song_0_'+d+'_cast') for d in ['se','sw','ne','nw'])
    names.update(('skills_5','wu_song_1_'+d+'_effect') for d in ['se','sw','ne','nw'])
    names.update(('death','wu_song_'+d+'_death_'+str(i)) for d in ['se','sw','ne','nw'] for i in range(4))
    names.update([('death','lin_chong_sw_death_0'),('death','lin_chong_sw_death_2')])
    directory=QA/'ordinary_final_actions_pilot_review_v8a_frames';directory.mkdir(exist_ok=False);viewed=[]
    for stage,name in sorted(names):
        row=next(x for x in r['results'][stage]['screenshots'] if x['name']==name)
        source=Path(row['path']);assert sha(source)==row['sha256'];target=directory/source.name;shutil.copy2(source,target)
        assert sha(target)==row['sha256'];viewed.append({'case':name,'path':target.relative_to(ROOT).as_posix(),'sha256':sha(target),'stage':stage})
    dump(QA/'ordinary_final_actions_pilot_visual_review_v8a.json',{
        'passed':False,'pilot_receipt':str(receipt_path),'pilot_receipt_sha256':sha(receipt_path),
        'mechanical_checks':661,'skill_checks':484,'death_checks':177,'actual_viewport_captures':96,'viewed':viewed,
        'skills_mechanical_passed':True,'skills_sampled_visual_reviewed':True,'wu_death_sampled_qualified':True,'lin_sw_death_qualified':False,
        'private_runtime_patch':'Wu ordinary death registration only; root production scripts unchanged.',
        'findings':[
            'Wu four directions/four actual death stages directly inspected: adult body scale, both sabres, front/back identity and ground rest retained; terminal hold/fade as original renderer.',
            'Lin SW old native fatal pose faces right; fall then faces left; final lying head reverses right. Exact existing resources confirmed; this visual is rejected despite green mechanics.',
            'Lin SW correction is pending candidate/native import and actual-world repetition; no production death adoption yet.',
            'Sampled skill cast/effect viewports show same original identities, HUD, actual effects and post-cast upright idle. Summon/attack FX can occlude parts of body.',
            'Melee opponents retain natural AI skill use. Original attack orders plus actual original combat damage, not proof of melee-only lethal damage.',
            'Raised weapon/hand near blood bar and later cast-lift clearance remain a separate continuous/multi-size UI check; no confirmed head-overlap fix is claimed.',
            'Shadow retention/pruning is not asserted by v8a; planned sibling verifier adds direct runtime checks.'
        ],
        'scope':'Qualified Wu sampled native death poses and completed sampled skill mechanics only. Overall visual gate fails on Lin SW death. Exact phase freezes/contact/fog/zoom and legal level6 skill restore are fixtures; death actors remain original level1. Not full continuous action, natural leveling/chapter/save/performance/platform or full-goal completion.'})
    print(json.dumps({'mechanical_checks':661,'captures':96,'saved_directly_viewed':len(viewed),'overall_visual_passed':False,'lin_sw_correction_required':True}))

if __name__=='__main__':main()
