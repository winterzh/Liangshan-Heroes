"""Record directly viewed full-canvas idle candidates after independent native import."""
from pathlib import Path
import hashlib,json,shutil,sys
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def preserve(src,dst):
    if dst.exists():assert sha(src)==sha(dst)
    else:shutil.copyfile(src,dst)
key=sys.argv[1];assert key=='wang_ying'
imp_run,preview_run=map(Path,sys.argv[2:4]);imp=read(imp_run/'receipt.json');r=read(preview_run/'receipt.json')
m=read(ROOT/f'assets/direction4/zhu_wounded_{key}_20261006_fullidle_v4.json')
assert imp['complete'] and imp['lock_released'] and imp['dimensions']['passed']
assert len(imp['dimensions']['checks'])==len(m['sources'])==4
for source in m['sources'].values():
    assert source['import_dimensions_verified'] and sha(ROOT/source['path'])==source['sha256']
for row in imp['source_files']:
    if row['path'].endswith('.png'):assert sha(ROOT/row['path'])==row['before_sha256']==row['after_sha256']
assert r['complete'] and r['lock_released'] and r['native_input_drift']==0
assert len(r['inputs'])==13 and len(r['preview']['checks'])==4
assert {c['character'] for c in r['preview']['checks']}=={key}
assert all(c['passed'] for c in r['visible_render_checks'])
for row in r['inputs']:assert sha(ROOT/row['path'])==row['sha256']==sha(preview_run/'project'/row['path'])
sources=read(QA/f'{key}_fullidle_sources_v4.json');assert sources['passed']
matrix=preview_run/'project/idle_matrix_v3.png';assert sha(matrix)==r['matrix_sha256']
preserve(imp_run/'receipt.json',QA/f'{key}_fullidle_texture_v4.json')
preserve(preview_run/'receipt.json',QA/f'{key}_fullidle_preview_v4.json')
preserve(matrix,QA/f'{key}_fullidle_matrix_v4.png')
review={'schema':1,'character':key,'result':'accepted_short_sturdy_adult_full_canvas_idle_static_candidate',
    'review':'Native four full-canvas sprites and actual four-direction SpriteFrames matrix directly viewed',
    'observations':['Mature bearded short sturdy adult preserved in each direction',
        'Body height and estimated lower silhouette anchors consistent in actual static rendering',
        'Belt round studs and brown riveted armor are readable; exact action continuity remains open',
        'New matrix correctly labels rescued context and identity key; prior mislabelled matrix retained'],
    'source_checks':len(sources['checks']),'frozen_inputs':13,'input_drift':0,'matrix_sha256':sha(matrix),
    'import_dimensions_verified':True,'limits':['Static matrix only; no original Unit or campaign actions',
        'Native faint edge alpha and less than requested 80px padding remain documented; no pixels modified',
        'Walk foot anchors, posture through movement, UI and production routing pending'],
    'runtime_qualified':False,'production_qualified':False}
p=QA/f'{key}_fullidle_review_v4.json';assert not p.exists()
p.write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'source_checks':len(sources['checks']),'sources':4,'inputs':13,'input_drift':0,'production_qualified':False}))
