"""Archive completed body2 process render and its direct visual rejection."""
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
assert imp['complete'] and imp['dimensions']['passed'] and imp['lock_released']
assert len(imp['dimensions']['checks'])==6 and all(v['passed'] for v in imp['dimensions']['checks'])
for v in imp['source_files']:
    if v['path'].endswith('.png'):assert sha(ROOT/v['path'])==v['before_sha256']==v['after_sha256']
assert r['complete'] and r['lock_released'] and r['input_sha_drift']==0
assert len(r['inputs'])==22 and len(r['captures'])==64 and len(r['preview']['seen'])==20
for v in r['inputs']:assert sha(ROOT/v['path'])==v['sha256']==sha(preview_run/'project'/v['path'])
for v in r['captures']:assert sha(preview_run/'project'/v['path'])==v['sha256']
sources=read(QA/'shi_xiu_walk_sources_body2_v4.json')
assert len(sources['checks'])==169 and all(v['passed'] for v in sources['checks'])
matrix=preview_run/'project/walk_matrix_v3.png';assert sha(matrix)==r['matrix_sha256']
preserve(imp_run/'receipt.json',QA/'shi_xiu_walk_texture_body2_v4.json')
preserve(preview_run/'receipt.json',QA/'shi_xiu_walk_cycle_body2_v4.json')
preserve(matrix,QA/'shi_xiu_walk_cycle_body2_v4.png')
phases=[next(c for c in r['preview']['captures'] if c['moving'] and c['indexes'][0]==p) for p in range(4)]
review={'schema':1,'result':'rejected_phase_identity_and_material_continuity',
  'review':'Direct inspection of native sources, matched matrix, and sequential actual capture phases 0/1/2/3',
  'matrix_sha256':sha(matrix),'phase_rows':phases,
  'improvements':['Upper body broadened without losing opposite support legs','Back sash and layered hem remain corrected'],
  'remaining':['A/idle and B still show different relative head/body scale and cloth weave density',
    'Rebuild A/idle from one common native body reference, then recheck all four directions and actual movement'],
  'browser_attempt':{'result':'connection_unavailable','reason':'Browser-client native bridge was unavailable; no browser playback qualification claimed','own_review_server_stopped':True},
  'limits':['Only four recorded phases directly viewed; no browser continuous playback or actual Unit/campaign',
    'Prompt lower-body pixel invariance was not claimed; visual support pose preserved, native PNGs byte-preserved'],
  'continuous_gait_qualified':False,'production_qualified':False}
(QA/'shi_xiu_walk_body2_review_v4.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'technical_complete':True,'source_checks':169,'input_drift':0,'visual_result':review['result']}))
