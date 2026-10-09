"""Record native first walking-pose edits; no import or gait qualification claim."""
from pathlib import Path
import hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
rows=[]
for d in ('se','sw','ne','nw'):
    jp=HERE/f'jobs/wang_ying_walk_a_{d}_v4.json';j=read(jp);p=ROOT/j['output']
    assert sha(p)==j['output_sha256'] and not j['native_pixel_edits']
    assert sha(ROOT/j['request'])==j['request_sha256']
    for parent in j['references']:assert sha(ROOT/parent['path'])==parent['sha256']
    with Image.open(p) as im:
        assert im.mode=='RGBA' and list(im.size)==j['native_size']==[1254,1254]
        alpha=im.getchannel('A');box=alpha.point(lambda v:255 if v>16 else 0).getbbox()
        assert box and alpha.histogram()[0]/(im.width*im.height)>.35
        margins=[box[0],box[1],im.width-box[2],im.height-box[3]]
        assert min(margins)>=4
    rows.append({'direction':d,'path':j['output'],'sha256':sha(p),
        'job':jp.relative_to(ROOT).as_posix(),'job_sha256':sha(jp),
        'visible_alpha_threshold':16,'visible_bounds':box,'visible_margins':margins,
        'observed':'Mature short sturdy figure and facing retained; first single-support walking pose viewed',
        'requested_phase':'contact_a_left_lead','verified_phase_role':None,
        'phase_review':'NE shows right boot ahead and left boot behind; do not assume it satisfies requested left lead' if d=='ne' else
            'Opposing support, stride amplitude and contact-versus-passing role require paired-phase review'})
review={'schema':1,'character':'wang_ying','result':'four_native_first_walking_pose_candidates_ancestry_pass',
    'rows':rows,'method':'built-in image_gen native PNG byte-preserved; read-only geometry audit',
    'directly_viewed_native_directions':['se','sw','ne','nw'],
    'observations':['Short broad mature adult identity retained rather than stretched tall',
        'Gray trousers and brown riveted armor/round belt studs remain identifiable',
        'Trailing feet appear raised; requested light toe contact is not confirmed',
        'NE lead/support role needs correction or explicit phase reassignment after the paired pose is authored'],
    'remaining':['Opposing contact and two genuine passing phases per direction',
        'Pairwise body, hand, armor and foot-anchor continuity',
        'Independent texture import, actual gait rendering and original Unit/campaign qualification'],
    'engine_import_verified':False,'continuous_gait_qualified':False,'production_qualified':False}
dest=ROOT/'qa/zhu_wounded_20261005/wang_ying_walk_a_authoring_v4.json'
assert not dest.exists(),'Preserve existing observations; create a new review revision'
dest.write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'native_sources':4,'ancestry_hashes_passed':True,'visible_bounds_passed':True,'production_qualified':False}))
