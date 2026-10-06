"""Preserve observed Unit keyframes and a clearly labelled fixed-rate review clip."""
from pathlib import Path
import hashlib,json,sys
ROOT=Path(__file__).resolve().parents[3]
QA=ROOT/'qa/zhu_wounded_20261005'
def read(p): return json.loads(p.read_text(encoding='utf-8'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
run=Path(sys.argv[1]);variant=sys.argv[2]
assert variant in ('passing','refined','footclear')
r=read(run/'receipt.json')
assert r['complete'] and r['input_sha_drift']==0 and r['lock_released']
for c in r['captures']: assert sha(run/'project'/c['path'])==c['sha256']
samples=r['result']['samples']
phases=[next(s for s in samples if 6<=s['frame']<29 and s['units'][0]['state']=='walk' and s['units'][0]['index']==p) for p in range(4)]
review={'schema':1,'result':'actual_unit_fixture_functional_pass_visual_not_production_qualified',
        'receipt_sha256':sha(run/'receipt.json'), 'functional_checks':len(r['result']['checks']),
        'observed_frames':[5,15,28,35,42,59,75], 'observed_full_cycle_frames':[p['frame'] for p in phases],
        'observations':['Idle returns after normal Stop and residual blend decays',
                        'Normal movement and reversal use all four native directions',
                        'Adult silhouette remains upright at rest and readable at four-times view',
                        'Original Unit walking lean, breathing, squash and dust remain active'],
        'remaining':['Full continuous gait, planted-foot/body anchors and cloth transitions require further acceptance',
                     'Candidate frame resolver bypasses production ArtDB route',
                     'Original Battle/campaign, rescue/return, collision, rewards and other six characters unqualified'],
        'camera_tracks_actor':True, 'translation_evidence':'Original physical positions and movement assertions in 80 ordered samples',
        'continuous_playback_watched':False, 'production_qualified':False}
clip=run/f'unit_motion_{variant}_v4.mp4'
if clip.exists():
    review['review_clip']={'path':str(clip),'sha256':sha(clip),'frames':80,'width':880,'height':620,
                          'fixed_fps':'25/2','duration_seconds':6.4,
                          'scope':'80 original viewport captures assembled without image transforms at fixed 12.5 fps; approximate timing preview, not measured frame-time or watched-playback acceptance.'}
p=QA/f'shi_xiu_unit_motion_{variant}_review_v4.json'
assert not p.exists(), 'Use a new review revision instead of overwriting observed evidence'
p.write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'review':p.relative_to(ROOT).as_posix(),'production_qualified':False}))
