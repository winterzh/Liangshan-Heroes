"""Preserve matched native candidate evidence, without claiming continuous gait."""
from pathlib import Path
import hashlib,json,shutil,sys
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def preserve(src,dst):
    if dst.exists():assert sha(src)==sha(dst)
    else:shutil.copyfile(src,dst)
imp_run,preview_run=map(Path,sys.argv[1:3])
imp=read(imp_run/'receipt.json');r=read(preview_run/'receipt.json')
m=read(ROOT/'assets/direction4/zhu_wounded_shi_xiu_20261006_walk_matched_v4.json')
assert imp['complete'] and imp['dimensions']['passed'] and imp['lock_released']
assert len(imp['dimensions']['checks'])==len(m['sources'])==9
for v in imp['source_files']:
    if v['path'].endswith('.png'):assert sha(ROOT/v['path'])==v['before_sha256']==v['after_sha256']
assert r['complete'] and r['lock_released'] and r['input_sha_drift']==0
assert len(r['inputs'])==28 and len(r['captures'])==64 and len(r['preview']['seen'])==20
for v in r['inputs']:assert sha(ROOT/v['path'])==v['sha256']==sha(preview_run/'project'/v['path'])
for v in r['captures']:assert sha(preview_run/'project'/v['path'])==v['sha256']
sources=read(QA/'shi_xiu_walk_sources_matched_v4.json')
assert all(v['passed'] for v in sources['checks'])
matrix=preview_run/'project/walk_matrix_v3.png';assert sha(matrix)==r['matrix_sha256']
preserve(imp_run/'receipt.json',QA/'shi_xiu_walk_texture_matched_v4.json')
preserve(preview_run/'receipt.json',QA/'shi_xiu_walk_cycle_matched_v4.json')
preserve(matrix,QA/'shi_xiu_walk_cycle_matched_v4.png')
phases=[next(c for c in r['preview']['captures'] if c['moving'] and c['indexes'][0]==p) for p in range(4)]
review={'schema':1,'result':'candidate_improved_but_gait_not_qualified',
  'review':'Direct native 12-pose matrix and actual recorded phases 0/1/2/3 viewed',
  'matrix_sha256':sha(matrix),'phase_rows':phases,
  'improvements':['A and B now share adult body/shoulder template','NW A shortened from wide lunge','Idle atlas padding repaired natively to 63/61/80/84px'],
  'remaining':['Idle cloth detail density still differs from full-canvas A/B','Stationary idle reused as transition, not authored passing phases','Actual Unit movement, secondary motion, planted feet and campaign must be checked'],
  'limits':['No continuous browser playback; browser native bridge unavailable','Only isolated SpriteFrames process-clock/start/stop, not original Unit/campaign'],
  'continuous_gait_qualified':False,'production_qualified':False}
(QA/'shi_xiu_walk_matched_review_v4.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'complete':True,'source_checks':len(sources['checks']),'inputs':len(r['inputs']),'input_drift':0,'result':review['result']}))
