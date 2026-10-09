"""Record native opposite-support authoring; static engine comparison is separate."""
from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
QA=ROOT/'qa/zhu_wounded_20261005';base=ROOT.parent/'qa-zhu-wounded-20261005'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
m=read(ROOT/'assets/direction4/zhu_wounded_wang_ying_20261006_contact_pair_v4.json')
sources=read(QA/'wang_ying_contact_pair_sources_v4.json')
assert m['diagnostic_only'] and not m['production_qualified'] and sources['passed']
assert len(sources['checks'])==236 and len(m['sources'])==12 and len(m['resources'])==8
run=Path(read(base/'texture_bootstrap_wang_ying_contact_pair_v4_run.json')['run']);imp=read(run/'receipt.json')
assert imp['complete'] and imp['lock_released'] and imp['dimensions']['passed'] and len(imp['dimensions']['checks'])==12
for s in m['sources'].values():assert s['import_dimensions_verified'] and sha(ROOT/s['path'])==s['sha256']
for item in imp['source_files']:
    if item['path'].endswith('.png'):assert sha(ROOT/item['path'])==item['before_sha256']==item['after_sha256']
p=QA/'wang_ying_contact_pair_texture_v4.json'
if p.exists():assert sha(p)==sha(run/'receipt.json')
else:shutil.copyfile(run/'receipt.json',p)
rows=[];prompts=[]
for d in ('se','sw','ne','nw'):
    a=m['sources']['walk_a_'+d];b=m['sources']['walk_b_'+d]
    rows.append({'direction':d,'a':{'path':a['path'],'sha256':a['sha256']},
        'b':{'path':b['path'],'sha256':b['sha256']},
        'observed':'SE A image-right boot supports, B3 image-left boot supports' if d=='se' else
            'A image-left boot supports, B image-right boot supports',
        'body_review':'Native mature short broad identity, red/brown armor, horizontal shin bands and upright upper body retained; movement continuity still open'})
    jp=HERE/f"jobs/{b['job']}.json";j=read(jp)
    assert sha(ROOT/j['request'])==j['request_sha256']
    prompts.append({'job':jp.relative_to(ROOT).as_posix(),'path':b['path'],'sha256':b['sha256'],
        'request':j['request'],'request_sha256':j['request_sha256'],'exact_args':read(ROOT/j['request'])})
review={'schema':1,'character':'wang_ying','result':'four_native_opposite_support_pairs_authored_candidate_only',
    'rows':rows,'native_import_sources':12,'source_checks':236,'resources':8,
    'directly_viewed_native':True,'method':'built-in image_gen native PNG byte-preserved',
    'geometry_reference_scope':'New Godot primitives only, no source bitmap read/edit; selected SE v5 and SW/NW v6 projected foot-side checks passed',
    'improvements':['SE B3 actually reverses A support, restoring own horizontal shin bands after failed B/B2',
        'SW/NW separately authored B3 poses reverse A support; NE native B remains the opposing support candidate',
        'Short broad mature adult anatomy and empty-hand rescued identity retained'],
    'remaining':['Eight true passing poses to create four actual walk phases per direction',
        'Raised-boot height and cloth/body continuity must be reviewed in movement',
        'Lower-silhouette foot anchors are initial estimates, not actual planted-foot qualification',
        'Static comparison, actual Unit, original campaign, production routing and UI acceptance'],
    'diagnostic_only':True,'continuous_gait_qualified':False,'production_qualified':False}
rp=QA/'wang_ying_contact_opposite_authoring_v4.json';assert not rp.exists()
rp.write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
pp=QA/'wang_ying_opposite_native_prompt_set_v4.json';assert not pp.exists()
pp.write_text(json.dumps({'method':'built-in image_gen','native_pixel_edits':False,'production_qualified':False,
    'requests':prompts},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'opposite_support_pairs':4,'source_checks':236,'native_import_sources':12,'resources':8,'diagnostic_only':True,'production_qualified':False}))
