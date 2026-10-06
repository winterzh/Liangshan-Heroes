"""Publish byte-preserved isolated Shi Qian QA evidence; no asset pixel edits."""
from pathlib import Path
import hashlib, json, shutil, sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
QA = ROOT / 'qa/zhu_wounded_20261005'
HERE = Path(__file__).resolve().parent
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8'))
def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
def preserve(source, target):
    if target.exists(): assert sha(source)==sha(target), 'Do not overwrite prior evidence'
    else: shutil.copyfile(source, target)

import_run, preview_run = map(Path, sys.argv[1:3])
imp = read(import_run/'receipt.json')
preview = read(preview_run/'receipt.json')
assert imp['complete'] and imp['dimensions']['passed'] and imp['lock_released']
assert not imp['engine_remaining']
png = ROOT/'assets/characters/shi_qian_wounded_20261005/idle_traits_v4.png'
assert imp['source_files'][0]['before_sha256']==sha(png)==imp['source_files'][0]['after_sha256']
assert preview['complete'] and preview['preview']['passed'] and preview['lock_released']
assert preview['native_input_drift']==0 and len(preview['inputs'])==7
assert {r['direction'] for r in preview['preview']['checks']}=={'se','sw','ne','nw'}
assert len(preview['visible_render_checks'])==4 and all(r['passed'] for r in preview['visible_render_checks'])
sources=read(QA/'shi_qian_traits_sources_v4.json')
assert len(sources['checks'])==45 and all(r['passed'] for r in sources['checks'])
for item in preview['inputs']: assert sha(ROOT/item['path'])==item['sha256']
matrix = preview_run/'project/idle_matrix_v3.png'
assert sha(matrix)==preview['matrix_sha256']
preserve(import_run/'receipt.json',QA/'shi_qian_traits_texture_import_v4.json')
preserve(preview_run/'receipt.json',QA/'shi_qian_traits_idle_preview_v4.json')
preserve(matrix,QA/'shi_qian_traits_idle_matrix_v4.png')
write(QA/'shi_qian_traits_idle_review_v4.json', {
    'schema':1, 'character':'shi_qian', 'source_sha256':sha(png),
    'matrix_sha256':sha(matrix), 'review':'Direct visual inspection of native source and actual isolated SpriteFrames matrix',
    'result':'accepted_static_candidate',
    'observations':['Four authored SE/SW/NE/NW facings; no runtime mirroring',
      'Alert head and torso, soft knees and lower ready weight suit infiltrator role',
      'Adult proportions and charcoal clothing retained; no compulsory military chest posture'],
    'technical':{'native_dimensions':[1254,1254], 'source_checks':45, 'resources':4,'frozen_inputs':7,'input_drift':0},
    'limits':['Static SpriteFrames with Unit draw metadata, not actual Unit/campaign',
      'Walking, transitions, rescue, withdrawal, UI and production routing still pending'],
    'production_qualified':False, 'user_approval_claimed':False
})

job=read(HERE/'jobs/shi_xiu_step_b_cloth_se_v4.json')
asset=ROOT/job['output']
assert sha(asset)==job['output_sha256']
assert sha(ROOT/job['request'])==job['request_sha256']
for ref in job['references']: assert sha(ROOT/ref['path'])==ref['sha256']
with Image.open(asset) as image:
    assert image.mode=='RGBA' and image.size==(1254,1254)
    box=image.getchannel('A').getbbox()
    assert box and min(box[0],box[1],image.width-box[2],image.height-box[3])>=4
write(QA/'shi_xiu_step_b_cloth_se_review_v4.json', {
    'schema':1, 'job':job, 'alpha_bbox':list(box),
    'review':'Direct native image visual inspection', 'result':'candidate_requires_matched_render',
    'observations':['SE opposite support leg retained', 'Extra layered tunic hem reduced',
      'Dense diamond pattern softened but exact fabric/body continuity still requires matched A/idle/B preview'],
    'runtime_qualified':False, 'continuous_gait_qualified':False, 'production_qualified':False
})
print(json.dumps({'shi_qian_static_candidate':True,'frozen_inputs':7,'input_drift':0,
    'shi_xiu_se_cloth':'candidate_requires_matched_render','production_qualified':False}))
