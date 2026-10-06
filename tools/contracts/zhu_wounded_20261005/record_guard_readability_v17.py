"""Preserve complete production verification and the actually inspected native views."""
from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005'
RUN=ROOT.parent/'qa-ordinary-posture-20261006/ordinary_guard_readability_v17_7e0754cd'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    rp=RUN/'receipt.json';r=json.loads(rp.read_text(encoding='utf-8'))
    assert r['complete'] and r['lock_released'] and r['private_runtime_patches']==0
    assert r['root_input_drift']==r['private_input_drift']==0
    assert r['production_source_delta']==['scripts/battle.gd']
    assert r['result']['passed'] and r['result']['checks']==761 and len(r['result']['screenshots'])==112
    effects=[x for x in r['result']['runtime'] if x['case']=='cast_effect'];assert len(effects)==28
    for row in r['source_files']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    for row in r['result']['screenshots']:assert sha(Path(row['path']))==row['sha256']
    p=QA/'ordinary_guard_readability_qualified_v17.json';assert not p.exists();shutil.copy2(rp,p);assert sha(p)==sha(rp)
    names=['lin_chong_3_se_mid_1440x960','lin_chong_3_se_late_1920x1080','lin_chong_3_sw_late_1280x720']
    names += [f'wu_song_{slot}_se_{phase}_{size}' for slot in range(4) for phase,size in [('mid','1440x960'),('late','1920x1080')]]
    names += ['lin_chong_3_sw_mid_1440x960','lin_chong_3_ne_mid_1440x960','lin_chong_3_nw_mid_1440x960','lin_chong_3_ne_late_1280x720','lin_chong_3_nw_late_1920x1080','wu_song_2_sw_late_1280x720','wu_song_3_ne_mid_1440x960','wu_song_0_nw_late_1920x1080']
    directory=QA/'ordinary_guard_readability_review_v17_frames';directory.mkdir(exist_ok=False);views=[]
    for name in names:
        row=next(x for x in r['result']['screenshots'] if x['name']==name);dst=directory/Path(row['path']).name
        shutil.copy2(row['path'],dst);assert sha(dst)==row['sha256']
        views.append({'case':name,'path':dst.relative_to(ROOT).as_posix(),'sha256':sha(dst)})
    review={'passed':True,'mechanical_passed':True,'receipt_sha256':sha(rp),'checks':761,'captures':112,'actual_effects':28,'viewed':views,
      'findings':['Directly inspected 19 current native views; changed Lin guard examined in all four headings, actual mid/late cast phases, with selected minimum and maximum desktop windows.',
        'Peripheral lower-opacity Lin guard cue remains visible; dense opaque central spear fan removed. Upper body, head and healthbar readable in inspected views. Cast posture bends naturally; ordinary upright idle/walk qualification retained from v14/v15b.',
        'Wu original body and twin sabres retained. Q summons two actual tigers; close formation produces legitimate tiger/body/healthbar/name overlaps in selected SW/NE views. This remains open for crowded formation UI review and is not qualified as entirely unobstructed UI.',
        'Skill effects follow original mechanics and authored attack poses. No bespoke wine-drinking animation claim.'],
      'scope':'Qualified targeted Lin guard readability fix and full seven-active-ability/four-heading phase/effect checks. Only listed 19 views directly inspected. Not uninterrupted cast playback, crowded formation clearance, natural progression, full campaign/save/nine-mode/performance/export or Android qualification.',
      'open_visual_items':['crowded tiger/hero/name/healthbar clearance','uninterrupted cast playback','complete multi-size chapter UI'],
      'full_goal_qualified':False,'platform_released':False}
    p=QA/'ordinary_guard_readability_visual_review_v17.json';assert not p.exists();p.write_bytes((json.dumps(review,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    print(json.dumps({'checks':761,'captures':112,'direct_views':len(views),'targeted_fix_qualified':True,'full_goal_qualified':False}))
if __name__=='__main__':main()
