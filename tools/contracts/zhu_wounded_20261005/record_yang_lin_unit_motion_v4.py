"""Preserve real Yang Lin Unit motion, fixture identity and observed keyframes."""
from pathlib import Path
import hashlib,json,shutil,sys
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
run=Path(sys.argv[1]);r=read(run/'receipt.json')
assert r['complete'] and r['lock_released'] and r['input_sha_drift']==0 and not r['production_qualified']
assert r['identity_key']=='yang_lin' and len(r['result']['checks'])==52
assert len(r['result']['samples'])==len(r['captures'])==80
assert sha(run/'unit_motion_yang_lin_v4.py')==r['runner_sha256']
for item in r['inputs']:assert sha(ROOT/item['path'])==item['sha256']==sha(run/'project'/item['path'])
for item in r['harnesses']:assert sha(ROOT/item['path'])==item['sha256']==sha(run/'project'/Path(item['path']).name)
for item in r['captures']:assert sha(run/'project'/item['path'])==item['sha256']
for sample in r['result']['samples']:
    for u in sample['units']:
        assert u['key']=='yang_lin' and u['hp']==u['max_hp']==110 and u['atk']==0
        assert u['base_speed']==82 and not u['hero'] and u['noncombat'] and u['slots']==0
dest=QA/'yang_lin_unit_motion_passing_v4.json'
if dest.exists():assert sha(dest)==sha(run/'receipt.json')
else:shutil.copyfile(run/'receipt.json',dest)
phases=[next(s for s in r['result']['samples'] if 6<=s['frame']<29 and s['units'][0]['state']=='walk' and s['units'][0]['index']==p) for p in range(4)]
review={'schema':1,'character':'yang_lin','result':'actual_unit_fixture_functional_pass_candidate_visual_review',
    'receipt_sha256':sha(run/'receipt.json'),'checks':52,'frozen_inputs':len(r['inputs']),'input_drift':0,
    'observed_frames':[5,15,28,35,42,59,75],'observed_full_cycle_frames':[s['frame'] for s in phases],
    'observations':['Actual 1x/4x Unit idle, movement, stop, reverse and phases directly viewed',
        'Alert broad shoulders/narrow waist, natural head alignment and flexible balanced bearing preserved at rest; original walking lean/breathing/squash/dust remain active',
        'Normal Stop returns to idle and movement blend decays',
        'Actual fixture identity is Yang Lin with HP110, speed82, attack0, nonhero/noncombat and slots0 throughout 80 samples'],
    'fixture_identity_is_not_original_campaign_proof':True,'camera_tracks_actor':True,
    'remaining':['Full continuous gait/foot and cloth transition acceptance remains open',
        'Candidate resolver bypasses production ArtDB route; original Battle/campaign, rescue/return, collision and rewards still unqualified',
        'Other rescued characters and ordinary Wu Song/Lin Chong actions/UI remain in the full plan'],
    'continuous_playback_watched':False,'production_qualified':False}
clip=run/'unit_motion_yang_lin_passing_v4.mp4'
if clip.exists():
    review['review_clip']={'path':str(clip),'sha256':sha(clip),'frames':80,'width':880,'height':620,
        'fixed_fps':'25/2','duration_seconds':6.4,
        'scope':'80 original viewport frames assembled without image transforms at fixed12.5fps; approximate timing preview, not measured frame-time or watched-playback acceptance'}
p=QA/'yang_lin_unit_motion_passing_review_v4.json';assert not p.exists()
p.write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'checks':52,'captures':80,'inputs':len(r['inputs']),'input_drift':0,'production_qualified':False}))
