"""Retain failed B2 and derive true passing B from already correct contact B."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;QA=ROOT/'qa/zhu_wounded_20261005'
def persist(p,v):
    if p.exists():assert json.loads(p.read_text(encoding='utf-8'))==v
    else:p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
bad='assets/characters/deng_fei_wounded_20261005/passing_b2_sw_v4.png'
persist(QA/'deng_fei_passing_b2_sw_rejection_v4.json',{'path':bad,'sha256':hashlib.sha256((ROOT/bad).read_bytes()).hexdigest(),
    'reason':'B2 still repeats A support: image-left boot planted/image-right raised; not selected. Use correct B contact as next native edit target.',
    'selected':False,'production_qualified':False})
r={'transparent_background':True,'referenced_image_paths':[(HERE/'guides/wang_ying_passing_b_sw_geometry_v7.png').as_posix(),(ROOT/'assets/characters/deng_fei_wounded_20261005/walk_b_sw_v4.png').as_posix()],
    'prompt':'''Precise SINGLE-LEG edit of IMAGE2 Deng Fei correct B contact. Keep IMAGE2's IMAGE-RIGHT supporting leg/boot ENTIRELY unchanged: it is FLAT, heel and toe on ground, supporting weight under own hip. KEEP RIGHT leg. Keep whole upper body, frontal SW camera LOWER-LEFT, mature tawny face, CURLY hair/beard, rust hair tie, brown brass-decorated armor/scarf/cloth, rust sash, natural adult proportions, all materials/ornaments/empty hands.
Change ONLY IMAGE-LEFT swinging leg: currently left boot is extended forward with big sole exposed. Move that LEFT boot back toward its own pelvis, close beside RIGHT support foot as BLUE leg in IMAGE1. LEFT knee softly bent and LEFT boot LOW RAISED one boot-thickness above own ground. Toe points lower-left, natural ankle. It is NOT a planted left boot: keep all left heel/toe clearly off ground. Thus right boot unchanged FLAT, left boot LOW AIRBORNE under hip. No large sole facing viewer, wide stride, high knee, kick or crossed/detached leg. Only minimal adjoining hem adjustment for connected LEFT leg; RIGHT supporting leg must NOT change or lift.
IMAGE1 gives exact desired close-foot passing legs/camera only, not robot/box proportions/colors/labels/green marker. IMAGE2 identity and RIGHT support are the invariants. Do not substitute another left-planted/right-raised A. Render TRUE B distinct from A.
Exactly ONE complete mature adult at same FRONT southwest orientation on genuine transparent RGBA native square<=1536 with generous80px+ alpha margins around whole hair/cloth/boots. Upright healthy head/back, strong alert natural bearing, no hunch/parade arch, giant head/boots or glowing eyes. No crop/mirror/grid/text/floor/shadow/extra views/iron chain/weapons/rope/banner/new prop or costume. Refined painterly native art; preserve RIGHT flat leg and only shorten/low-raise LEFT leg into passing.'''}
persist(HERE/'requests/deng_fei_passing_b3_sw_v4.json',r)
print('B2 rejected; exact native passing B3 preserves correct right contact leg')
