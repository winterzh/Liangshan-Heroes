"""Preserve viewed opposite-support candidates and the ineffective NE edit."""
from pathlib import Path
import hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
rows=[]
for state in ('walk_a_ne','walk_a2_ne','walk_b_ne'):
    jp=HERE/f'jobs/wang_ying_{state}_v4.json';j=read(jp);p=ROOT/j['output']
    assert sha(p)==j['output_sha256'] and sha(ROOT/j['request'])==j['request_sha256']
    for ref in j['references']:assert sha(ROOT/ref['path'])==ref['sha256']
    with Image.open(p) as im:
        assert im.mode=='RGBA' and im.size==(1254,1254)
        box=im.getchannel('A').point(lambda v:255 if v>16 else 0).getbbox();assert box
        margins=[box[0],box[1],im.width-box[2],im.height-box[3]]
        assert min(margins)>=4
    rows.append({'state':state,'path':j['output'],'sha256':sha(p),'job':jp.relative_to(ROOT).as_posix(),
        'job_sha256':sha(jp),'visible_alpha_threshold':16,'visible_margins':margins,
        'selected_as_pair_candidate':state!='walk_a2_ne'})
review={'schema':1,'result':'native_ne_opposite_support_pair_candidate','character':'wang_ying','rows':rows,
    'direct_native_review':True,
    'observations':['A has image-left rear planted boot with the right boot ahead; its original strict left-leading wording is not fulfilled',
        'Text-only A2 fix did not sufficiently reverse the leg layout; preserved as unselected sibling',
        'B uses Shi Xiu native opposite lower-body pose as guide, preserving Wang Ying identity and short broad adult body',
        'B visibly raises the image-left rear boot and plants the image-right foreground boot; support differs from A',
        'Mature face/topknot, red tunic/headband, brown armor and round belt remain consistent enough for paired movement review'],
    'phase_role_policy':'Candidate A/B names denote opposite support poses, not proof of the original requested left-leading contact geometry',
    'remaining':['A/B foot contact timing, compact stride amplitude and lower-garment continuity require true passing phases and actual animation',
        'Other directions need separately authored opposite poses; no full walk resource exists',
        'Actual texture import, Unit, campaign and production qualification pending'],
    'continuous_gait_qualified':False,'runtime_qualified':False,'production_qualified':False}
p=ROOT/'qa/zhu_wounded_20261005/wang_ying_ne_support_pair_v4.json';assert not p.exists()
p.write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'native_sources':3,'opposite_support_pair_candidates':2,'ineffective_edit_preserved':1,'production_qualified':False}))
