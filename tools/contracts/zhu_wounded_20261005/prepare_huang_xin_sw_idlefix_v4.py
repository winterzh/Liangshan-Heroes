"""Retain wrong-facing SW idle and prepare a native camera correction lineage."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;QA=ROOT/'qa/zhu_wounded_20261005'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def persist(p,v):
    if p.exists():assert read(p)==v
    else:p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
bad='assets/characters/huang_xin_wounded_20261005/idle_single_sw_v4.png'
persist(QA/'huang_xin_idle_sw_rejection_v4.json',{'path':bad,'sha256':hashlib.sha256((ROOT/bad).read_bytes()).hexdigest(),
    'reason':'Requested SW faces LOWER-LEFT, but native output faces LOWER-RIGHT and repeats SE; reject for SW selection.',
    'selected':False,'production_qualified':False})
r=read(HERE/'requests/huang_xin_idle_single_sw_v4.json')
r['referenced_image_paths']=[(HERE/'guides/qin_ming_walk_a_sw_geometry_v4.png').as_posix(),(ROOT/bad).as_posix(),(ROOT/'assets/characters/huang_xin_wounded_20261005/idle_v3.png').as_posix()]
r['prompt']='''Correct ONLY whole-body camera orientation of IMAGE2 Huang Xin: it incorrectly faces image-right. Produce ONE full-body IDLE facing LOWER-LEFT SOUTHWEST. IMAGE1 gives ONLY camera: FRONT three-quarter facing image-LEFT, not red/blue leg colors, robot or walking leg position. Both boots must be PLANTED in a balanced idle stance. IMAGE3 top-right sheet cell is corresponding original Huang Xin left-facing identity reference. IMAGE2 locks his exact face/armor/palette/proportions, not its wrong direction.
MANDATORY: nose and eyes look image-LEFT; chest is seen obliquely on the image-LEFT facing side, both boot toes point LOWER-LEFT. Head, shoulders, chest, hips and both boots turn coherently to southwest. This must visually DIFFER in facing from IMAGE2 right-facing portrait. Do not return another SE, rear view or multi-view sheet. Do not simply flip all decorative details; render the requested side correctly.
Preserve mature bearded Chinese officer, ochre headband/topknot/scarf, gold beast shoulder plates and rivets, dark lamellar chest/back/hip armor, brown belt/gold buckle, ochre sleeves/ragged tunic and crossed calf wraps/dark ochre-edged boots. Upright natural head/upper back, calm stern gaze, normal adult proportions and relaxed empty hands, two planted feet. No hunch/parade arch/weapon/rope/banner/new prop. Refined painterly materials unchanged.
Exactly ONE WHOLE adult figure on genuine transparent RGBA square native<=1536, centered with generous80px+ alpha margins around headcloth/hem/boots. No crop, giant head/boots, floor/shadow/grid/text/guide colors or extra figure.'''
persist(HERE/'requests/huang_xin_idle_single2_sw_v4.json',r)
for phase in ('walk_a','passing_a','walk_b','passing_b'):
    r=read(HERE/f'requests/huang_xin_{phase}_sw_v4.json')
    r['referenced_image_paths'][1]=(ROOT/'assets/characters/huang_xin_wounded_20261005/idle_single2_sw_v4.png').as_posix()
    persist(HERE/f'requests/huang_xin_{phase}_idlefix_sw_v4.json',r)
print('SW failure preserved; one idle correction and four corrected-reference gait requests prepared')
