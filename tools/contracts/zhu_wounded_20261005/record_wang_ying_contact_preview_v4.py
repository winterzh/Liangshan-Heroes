"""Record a completed, directly viewed contact comparison without gait claims."""
from pathlib import Path
import hashlib,json,shutil,sys
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def preserve(src,dst):
    if dst.exists():assert sha(src)==sha(dst)
    else:shutil.copyfile(src,dst)
run=Path(sys.argv[1]);r=read(run/'receipt.json')
assert r['complete'] and r['lock_released'] and r['diagnostic_only'] and r['input_sha_drift']==0
assert len(r['inputs'])==33 and len(r['result']['checks'])==12
assert all(c['passed'] for c in r['visible_checks'])
assert sha(run/'contact_pair_preview_v4.py')==r['harness_sha256']
assert sha(run/'project/contact_pair_preview_v4.gd')==r['draw_script_sha256']
for item in r['inputs']:assert sha(ROOT/item['path'])==item['sha256']==sha(run/'project'/item['path'])
matrix=run/'project/contact_pair_matrix_v4.png';assert sha(matrix)==r['matrix_sha256']
sources=read(QA/'wang_ying_contact_pair_sources_v4.json');assert sources['passed'] and len(sources['checks'])==236
preserve(run/'receipt.json',QA/'wang_ying_contact_pair_preview_v4.json')
preserve(matrix,QA/'wang_ying_contact_pair_matrix_v4.png')
review={'schema':1,'character':'wang_ying','result':'twelve_native_pose_contact_comparison_candidate_only',
    'source_checks':236,'frozen_inputs':33,'input_drift':0,'matrix_sha256':sha(matrix),
    'review':'Actual 12-pose SpriteFrames matrix directly viewed; static body, wardrobe and support comparison only',
    'observations':['Each direction has a distinct opposing support candidate rather than repeating A',
        'Short broad mature identity and horizontal shin bands remain readable',
        'Equal silhouette-height metadata permits direct pairwise size comparison'],
    'remaining':['Eight genuine passing poses and actual full four-phase movement remain required',
        'Contact lift height, weight transfer, armor/skirt continuity and planted-foot anchors require movement review',
        'Two-contact diagnostic resources do not replace the planned full gait or production route'],
    'diagnostic_only':True,'continuous_gait_qualified':False,'production_qualified':False}
dest=QA/'wang_ying_contact_pair_review_v4.json';assert not dest.exists()
dest.write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
pending=QA/'wang_ying_contact_pair_pending_v4.json'
if pending.exists():
    old=read(pending);old.update(historical_snapshot=True,current_waiter_live=False,terminal_exit_code=0,
        superseded_by='qa/zhu_wounded_20261005/wang_ying_contact_pair_preview_v4.json')
    pending.write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'static_poses':12,'frozen_inputs':33,'input_drift':0,'diagnostic_only':True,'production_qualified':False}))
