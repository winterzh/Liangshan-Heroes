"""Read-only native bytes/alpha audit of Shi Xiu transferred opposite steps.

No pixel output, import, SpriteFrames, animation or production qualification.
"""
from pathlib import Path
import hashlib, json
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
QA = ROOT/'qa/zhu_wounded_20261005'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p, obj): p.write_text(json.dumps(obj, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

jobs = []
for jp in sorted((HERE/'jobs').glob('*_v3.json')):
    job = json.loads(jp.read_text(encoding='utf-8'))
    assert sha(ROOT/job['output']) == job['output_sha256']
    assert sha(ROOT/job['request']) == job['request_sha256']
    request = json.loads((ROOT/job['request']).read_text(encoding='utf-8'))
    assert request['transparent_background']
    # Exact archived request paths are matched to the stored hashed relative
    # parents without rewriting host-specific historical request bytes.
    assert len(request.get('referenced_image_paths', [])) == len(job['references'])
    for recorded, ref in zip(request.get('referenced_image_paths', []), job['references']):
        assert recorded.replace('\\','/').lower().endswith('/'+ref['path'].lower())
        assert sha(ROOT/ref['path']) == ref['sha256']
    with Image.open(ROOT/job['output']) as im:
        assert im.mode == 'RGBA' and list(im.size) == job['native_size'] and max(im.size) <= 1536
        assert im.getextrema()[3][0] == 0 and im.getextrema()[3][1] > 0
    jobs.append(jp.relative_to(ROOT).as_posix())

steps = {}
for direction, state in [('se','step_b_transfer'), ('sw','step_b_transfer_sw'), ('ne','step_b_transfer_ne'), ('nw','step_b_transfer_nw')]:
    job_path = HERE/'jobs'/f'shi_xiu_{state}_v3.json'
    job = json.loads(job_path.read_text(encoding='utf-8'))
    with Image.open(ROOT/job['output']) as im:
        alpha=im.getchannel('A')
        bbox=alpha.point(lambda value:255 if value>16 else 0).getbbox()
        assert bbox
        clearance=min(bbox[0],bbox[1],im.width-bbox[2],im.height-bbox[3])
        assert clearance >= 4 and alpha.histogram()[0]/(im.width*im.height) > .35
    steps[direction]={'job':job_path.stem,'path':job['output'],'sha256':job['output_sha256'],
        'native_size':job['native_size'],'alpha_bounds':list(bbox),'edge_clearance_px':clearance,
        'directly_viewed':True,'selection_status':'opposite-step authoring candidate; no runtime acceptance'}

idle=json.loads((QA/'seven_idle_preview_v3.json').read_text(encoding='utf-8'))
assert idle['complete']
assert all(sha(ROOT/r['path'])==r['sha256'] for r in idle['inputs'])
portable=json.loads((QA/'portable_idle_metadata_v3.json').read_text(encoding='utf-8'))
assert portable['passed']
old=QA/'authoring_check_v3.json'
write(QA/'authoring_check_v3_transfer.json', {'passed':True,
    'scope':'Current native output/request/immediate parent byte identity and alpha; no full walk ancestry/import/render/gait/gameplay qualification',
    'generation_jobs':len(jobs),'job_paths':jobs,'frozen_idle_inputs':len(idle['inputs']),'idle_input_sha_drift':0,
    'prior_authoring_check':{'path':old.relative_to(ROOT).as_posix(),'sha256':sha(old)},
    'portable_idle_metadata':{'path':'qa/zhu_wounded_20261005/portable_idle_metadata_v3.json',
        'sha256':sha(QA/'portable_idle_metadata_v3.json'),'passed':True},'production_qualified':False})
write(QA/'shi_xiu_walk_transfer_v3.json', {'scope':'Direct native authoring review and read-only single-view bounds only',
    'phase_a_reference':{'path':'assets/characters/shi_xiu_wounded_20261005/walk_a_v3.png',
        'sha256':sha(ROOT/'assets/characters/shi_xiu_wounded_20261005/walk_a_v3.png')},
    'phase_b_candidates':steps,
    'observations':'All four body facings retained with visibly different supporting/trailing leg arrangement from A. Heads raised and upper body upright. Tunic texture/hem and body continuity still require animated comparison; no anatomy metric or human approval.',
    'ancestry_note':'Historical Shi Qian v2 images used only as explicit lower-body pose references; latest Shi Xiu posture supplies upper body/identity. This does not re-qualify old tired posture or masked clothing.',
    'continuous_gait_qualified':False,'native_import_verified':False,'runtime_qualified':False,'production_qualified':False})
bad=json.loads((HERE/'jobs/shi_xiu_step_b_priority_v3.json').read_text(encoding='utf-8'))
write(QA/'shi_xiu_step_b_priority_v3_rejection.json', {'path':bad['output'],'sha256':bad['output_sha256'],
    'rejected':True,'reason':'Prioritizing geometry diagram still produced the same visible grounded-right/trailing-left silhouette as A. Native output also rectangular 1169x1346; byte preserved. Not selected as an opposite gait frame.',
    'native_pixel_edits':False,'production_qualified':False})
print(json.dumps({'passed':True,'generation_jobs':len(jobs),'opposite_step_candidates':len(steps),
    'clearance_px':{d:r['edge_clearance_px'] for d,r in steps.items()},'idle_input_sha_drift':0,'production_qualified':False}))
