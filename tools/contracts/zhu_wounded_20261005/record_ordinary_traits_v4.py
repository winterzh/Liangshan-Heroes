"""Archive independently imported ordinary hero idle candidates and static review."""
from pathlib import Path
import hashlib,json,shutil,sys
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005'
key,imp_arg,preview_arg=sys.argv[1:4];assert key in ('wu_song','lin_chong')
imp_run,preview_run=Path(imp_arg),Path(preview_arg)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def preserve(src,dst):
    if dst.exists():assert sha(src)==sha(dst)
    else:shutil.copyfile(src,dst)
imp=read(imp_run/'receipt.json');r=read(preview_run/'receipt.json')
assert imp['complete'] and imp['lock_released'] and imp['dimensions']['passed']
assert len(imp['dimensions']['checks'])==1
for v in imp['source_files']:
    if v['path'].endswith('.png'):assert sha(ROOT/v['path'])==v['before_sha256']==v['after_sha256']
assert r['complete'] and r['lock_released'] and r['native_input_drift']==0
assert len(r['inputs'])==7 and len(r['preview']['checks'])==4
assert all(v['passed'] for v in r['visible_render_checks'])
for v in r['inputs']:assert sha(ROOT/v['path'])==v['sha256']==sha(preview_run/'project'/v['path'])
sources=read(QA/f'{key}_idle_traits_sources_v4.json');assert all(v['passed'] for v in sources['checks'])
matrix=preview_run/'project/idle_matrix_v3.png';assert sha(matrix)==r['matrix_sha256']
preserve(imp_run/'receipt.json',QA/f'{key}_idle_traits_texture_v4.json')
preserve(preview_run/'receipt.json',QA/f'{key}_idle_traits_preview_v4.json')
preserve(matrix,QA/f'{key}_idle_traits_matrix_v4.png')
review={'schema':1,'character':key,'result':'accepted_static_upright_posture_candidate_only',
    'review':'Native four-direction PNG and actual four-direction SpriteFrames static matrix directly viewed',
    'posture':'Wu Song imposing steady adult ordinary stance with lowered twin daos' if key=='wu_song' else 'Lin Chong upright calm instructor stance in established armor with spear',
    'source_checks':len(sources['checks']),'frozen_inputs':7,'input_drift':0,'matrix_sha256':sha(matrix),
    'limits':['Not human approval','No original Unit movement, full action cycle, ordinary/combat state routing or UI acceptance','Weapon-hand anatomy and consistent weapon length through subsequent actions remain open'],
    'static_posture_candidate':True,'runtime_qualified':False,'production_qualified':False}
(QA/f'{key}_idle_traits_review_v4.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'character':key,'source_checks':len(sources['checks']),'inputs':7,'input_drift':0,'production_qualified':False}))
