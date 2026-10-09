"""Preserve independent Shi Xiu per-frame identity follow-up; retain prior run."""
from pathlib import Path
import hashlib,json,shutil,sys
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
run=Path(sys.argv[1]);r=read(run/'receipt.json')
assert r['complete'] and r['lock_released'] and r['input_sha_drift']==0 and r['identity_key']=='shi_xiu'
assert len(r['result']['checks'])==52 and len(r['result']['samples'])==len(r['captures'])==80
assert sha(run/'unit_motion_shi_xiu_identity_v4.py')==r['runner_sha256']
for item in r['inputs']:assert sha(ROOT/item['path'])==item['sha256']==sha(run/'project'/item['path'])
for item in r['harnesses']:assert sha(ROOT/item['path'])==item['sha256']==sha(run/'project'/Path(item['path']).name)
for item in r['captures']:assert sha(run/'project'/item['path'])==item['sha256']
for sample in r['result']['samples']:
    for u in sample['units']:
        assert u['key']=='shi_xiu' and u['hp']==u['max_hp']==110 and u['atk']==0 and u['base_speed']==82 and not u['hero'] and u['noncombat'] and u['slots']==0
dest=QA/'shi_xiu_unit_motion_identity_footclear_v4.json'
if dest.exists():assert sha(dest)==sha(run/'receipt.json')
else:shutil.copyfile(run/'receipt.json',dest)
phases=[next(s['frame'] for s in r['result']['samples'] if 6<=s['frame']<29 and s['units'][0]['state']=='walk' and s['units'][0]['index']==i) for i in range(4)]
review={'scope':'Existing native Shi Xiu footclear candidates with additional own-key/per-frame fixture assertions; not original campaign acceptance',
    'receipt_sha256':sha(dest),'checks':52,'captures':80,'frozen_inputs':len(r['inputs']),'input_drift':0,
    'observed_frames':[5,15,28,35,42,59,75],'observed_full_cycle_frames':phases,
    'observations':['Actual 1x/4x idle, movement, stop, reverse and all four phases directly viewed','Own Shi Xiu key/HP110/speed82/attack0/nonhero/noncombat/slots0 verified for all 80 samples'],
    'prior_44_check_receipt_retained':'qa/zhu_wounded_20261005/shi_xiu_unit_motion_footclear_v4.json',
    'continuous_playback_watched':False,'production_qualified':False}
clip=run/'unit_motion_shi_xiu_identity_footclear_v4.mp4'
assert clip.exists()
review['review_clip']={'path':str(clip),'sha256':sha(clip),'frames':80,'width':880,'height':620,'fixed_fps':'25/2','duration_seconds':6.4,
    'scope':'Original viewport frames assembled at fixed12.5fps without image transforms; approximate preview, not measured performance or watched playback'}
p=QA/'shi_xiu_unit_motion_identity_footclear_review_v4.json';assert not p.exists();p.write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'checks':52,'captures':80,'inputs':len(r['inputs']),'input_drift':0,'production_qualified':False}))
