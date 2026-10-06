"""Record complete active-skill mechanics and actual guard occlusion rejection."""
from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005'
RUN=ROOT.parent/'qa-ordinary-posture-20261006/ordinary_skill_clearance_v16b_dc124f7f'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def main():
    rp=RUN/'receipt.json';r=read(rp)
    assert r['complete'] and r['lock_released'] and r['private_runtime_patches']==0 and r['root_input_drift']==r['private_input_drift']==0
    assert r['result']['passed'] and r['result']['checks']==761 and len(r['result']['screenshots'])==112
    effects=[x for x in r['result']['runtime'] if x['case']=='cast_effect'];assert len(effects)==28
    assert len({(x['actor'],x['direction'],x['ability']) for x in effects})==28
    for row in r['source_files']+r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    p=QA/'ordinary_skill_clearance_mechanical_v16b.json';assert not p.exists();shutil.copy2(rp,p);assert sha(p)==sha(rp)
    directory=QA/'ordinary_skill_guard_rejection_v16b_frames';directory.mkdir(exist_ok=False);views=[]
    for name in ['lin_chong_3_ne_mid_1440x960','lin_chong_3_ne_late_1920x1080']:
        row=next(x for x in r['result']['screenshots'] if x['name']==name);src=Path(row['path']);assert sha(src)==row['sha256']
        dst=directory/src.name;shutil.copy2(src,dst);views.append({'case':name,'path':dst.relative_to(ROOT).as_posix(),'sha256':sha(dst)})
    review={'passed':False,'mechanical_passed':True,'blocked_by':'lin_guard_sprite_occlusion','receipt_sha256':sha(rp),
        'checks':761,'captures':112,'actual_effects':28,'viewed_rejection':views,
        'findings':['Complete seven active abilities/four headings actual mid/late phases and outcomes passed; whole source/private inputs unchanged, original roster targets retained.',
            'Current Lin R with preceding W guard: bright center-to-edge spokes and near-opaque white spearheads cover upper body and approach/overlap the healthbar. Directly viewed current NE mid/late native views confirm defect.',
            'LinGuardFx draw geometry in Battle uses zero origin, spokes9..35, tips41 and white alpha0.9. Fix drawing placement/opacity/peripheral spokes only; preserve target, life/dur/process, damage reduction and retaliation. Full new production/source/visual verification required.'],
        'scope':'Full mechanics qualified; overall visual qualification false. No uninterrupted skill playback, complete campaign/save/nine-mode/performance/export/device qualification.'}
    p=QA/'ordinary_skill_clearance_visual_review_v16b.json';assert not p.exists();p.write_bytes((json.dumps(review,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    print(json.dumps({'mechanical_checks':761,'captures':112,'effects':28,'overall_visual_passed':False,'blocked_by':review['blocked_by']}))
if __name__=='__main__':main()
