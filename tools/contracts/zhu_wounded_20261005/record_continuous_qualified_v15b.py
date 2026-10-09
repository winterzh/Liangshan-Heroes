"""Record current normal-motion sampling, reviewed appearance ancestry and viewport fixes."""
from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005';BASE=ROOT.parent/'qa-ordinary-posture-20261006'
RUN=BASE/'ordinary_continuous_gait_v15b_2029052f';PRIOR=BASE/'ordinary_continuous_gait_v15a_b3766d7b'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def main():
    rp=RUN/'receipt.json';r=read(rp);old=read(PRIOR/'receipt.json')
    assert r['complete'] and r['lock_released'] and r['root_input_drift']==r['private_input_drift']==0 and r['private_runtime_patches']==0
    assert r['result']['passed'] and r['result']['checks']==441 and len(r['result']['screenshots'])==70
    assert r['source_files']==old['source_files']
    for row in r['source_files']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    current=[x for x in r['result']['runtime'] if x['case']=='gait_summary'];prior=[x for x in old['result']['runtime'] if x['case']=='gait_summary']
    assert len(current)==len(prior)==8
    for a,b in zip(current,prior):
        assert a['actor']==b['actor'] and a['direction']==b['direction'] and set(a['poses_seen'])==set(b['poses_seen']) and len(a['poses_seen'])==4
        assert a['samples']==8 and a['distance']>30 and not a['subject_paused']
    p=QA/'ordinary_continuous_gait_qualified_v15b.json';assert not p.exists();shutil.copy2(rp,p);assert sha(p)==sha(rp)
    selected=[];ancestor=[]
    current_names=[k+'_'+d+'_live_2' for k in ['lin_chong','wu_song'] for d in ['se','sw','ne','nw']]
    current_names += [k+'_idle_'+s for k in ['lin_chong','wu_song'] for s in ['1280x720','1440x960','1920x1080']]
    old_names=[k+'_'+d+'_live_'+str(i) for k in ['lin_chong','wu_song'] for d in ['se','sw','ne','nw'] for i in range(4)]
    for names,receipt,directory,rows in [(current_names,r,'ordinary_continuous_gait_review_v15b_frames',selected),
                                        (old_names,old,'ordinary_continuous_gait_reviewed_appearance_v15a_frames',ancestor)]:
        target=QA/directory;target.mkdir(exist_ok=False)
        for name in names:
            row=next(x for x in receipt['result']['screenshots'] if x['name']==name);src=Path(row['path']);assert sha(src)==row['sha256']
            dst=target/src.name;shutil.copy2(src,dst);assert sha(dst)==row['sha256']
            rows.append({'case':name,'path':dst.relative_to(ROOT).as_posix(),'sha256':sha(dst)})
    review={'passed':True,'receipt_sha256':sha(rp),'checks':441,'captures':70,'private_runtime_patches':0,'root_input_drift':0,
        'viewed':selected,'reviewed_gait_appearance_ancestry':ancestor,'ancestry_receipt_sha256':sha(PRIOR/'receipt.json'),
        'findings':['Eight original-actor gait cases retain real normal physics and movement. Each produced eight native motion samples and visited all four unchanged directional walk resources; no animation values or subject physics were forced.',
            'Thirty-two first-four motion views from v15a directly inspected for body, boots, armor/clothes and weapon identity. Source inputs and each case gait pose set equal current v15b. Prior overall visual rejection remains preserved for stale atmosphere capture geometry.',
            'Fourteen current native views directly inspected: one live sample per actor/direction and all six desktop idle sizes. Rectangular atmosphere boundary corrected by existing derived-presentation refresh; no production pixel/source change. HUD portrait, resource line, skills and bottom panel visible at all three sizes.'],
        'scope':'Qualifies this normal continuous-motion sampling and selected desktop viewport review only. Sampled renders are not uninterrupted video or pixel-tracked foot-contact proof. Skill mid/late clearance, continuous attack/cast playback, complete chapter/save/nine-mode/performance/export and Android device qualification remain open.'}
    p=QA/'ordinary_continuous_gait_visual_review_v15b.json';assert not p.exists();p.write_bytes((json.dumps(review,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    print(json.dumps({'checks':441,'captures':70,'current_views':14,'reviewed_ancestry_views':32,'overall_scoped_visual_passed':True,'production_changed':False}))
if __name__=='__main__':main()
