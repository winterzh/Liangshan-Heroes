"""Preserve NE B wrong support and request a focused native leg correction."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;QA=ROOT/'qa/zhu_wounded_20261005'
def persist(p,v):
    if p.exists():assert json.loads(p.read_text(encoding='utf-8'))==v
    else:p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
bad='assets/characters/huang_xin_wounded_20261005/walk_b_ne_v4.png'
persist(QA/'huang_xin_walk_b_ne_rejection_v4.json',{'path':bad,'sha256':hashlib.sha256((ROOT/bad).read_bytes()).hexdigest(),
    'reason':'NE B repeats NE A: image-left boot flat and image-right boot raised. B must swap to image-right flat/image-left low raised.',
    'selected':False,'production_qualified':False})
r={'transparent_background':True,'referenced_image_paths':[(HERE/'guides/qin_ming_walk_b_ne_geometry_v4.png').as_posix(),(ROOT/bad).as_posix()],
    'prompt':'''Make one focused leg correction to IMAGE2 native Huang Xin: KEEP his exact rear NE camera, upright mature head/back, ochre headband/topknot/scarf/sleeves/ragged tunic, gold beast shoulder plates and gold rivets/dark lamellar armor, hands, belt, palette and normal adult proportions. Change only legs below hips plus minimal connected lower hem movement.
MANDATORY B SUPPORT SWAP from IMAGE1 mathematical guide: red IMAGE-RIGHT boot heel AND toe FULLY FLAT under its own hip on ground, supporting weight. Blue IMAGE-LEFT boot LOW raised, softly bent knee, short natural swing behind. IMAGE2 is WRONG because image-left remains flat and image-right raised. Result MUST reverse that visible support assignment. Right foot not raised/sole-showing; left foot visibly clear of its own ground by about one boot-thickness. Boot/shin/knee continuously attached to own hip, no crossed/disconnected legs, no high kick/lunge.
Maintain BACK three-quarter elevated isometric AWAY-UPPER-RIGHT NE: back armor/head/scarf visible, far-side beard profile only, boot toes upper-right. Never front view, mirror or rotate to wrong direction. IMAGE1 gives only legs/camera, no robot/box body, colors/labels/green ground in final.
Exactly one whole complete adult on genuine transparent RGBA square native<=1536 with generous80px+ margins, head/hands/hem/both boots unclipped. No weapon/rope/props/banner/grid/text/floor/shadow, giant head/boots, hunch or costume change. Same refined painterly native art, only correct opposing B contact legs.'''}
persist(HERE/'requests/huang_xin_walk_b2_ne_v4.json',r)
print('NE B failure and exact native B2 correction request preserved')
