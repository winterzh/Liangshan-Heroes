"""Retain repeated support SW passing B and request focused native correction."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;QA=ROOT/'qa/zhu_wounded_20261005'
def persist(p,v):
    if p.exists():assert json.loads(p.read_text(encoding='utf-8'))==v
    else:p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
bad='assets/characters/deng_fei_wounded_20261005/passing_b_sw_v4.png'
persist(QA/'deng_fei_passing_b_sw_rejection_v4.json',{'path':bad,'sha256':hashlib.sha256((ROOT/bad).read_bytes()).hexdigest(),
    'reason':'SW passing B repeats A: image-left boot remains flat and image-right raised. B must swap to image-right flat and image-left low passing boot near pelvis.',
    'selected':False,'production_qualified':False})
r={'transparent_background':True,'referenced_image_paths':[(HERE/'guides/wang_ying_passing_b_sw_geometry_v7.png').as_posix(),(ROOT/bad).as_posix()],
    'prompt':'''Focused native leg correction to IMAGE2 Deng Fei. Keep exact mature rugged tawny face, full CURLY black hair/high tied bundle/beard, rust hair tie/trailing cloth, brown ragged scarf/cloth, brown brass-decorated lamellar armor, brass chest ornaments, rust-red sash, hands/torso and adult proportions. Keep FRONT three-quarter elevated SW facing LOWER-LEFT, nose/chest/boot toes left. Change ONLY legs below hips and minimal connected lower hem.
MANDATORY opposite B support from IMAGE1 geometry: RED IMAGE-RIGHT boot HEEL AND TOE FULLY FLAT under own hip bearing weight. BLUE IMAGE-LEFT boot LOW raised, passing UNDER pelvis very close beside support boot with softly bent knee. IMAGE2 is WRONG because image-left is flat and image-right raised, repeating A. Result MUST visibly swap to RIGHT flat/LEFT low raised. Left heel AND toe clear of its corresponding ground by one boot-thickness, right sole rests flat, not raised. Normal own-hip leg connections, no crossing/disconnection, no both-planted idle or wide contact stance, no high kick/giant sole. Boots and ornate shin armor stay same adult size/material.
IMAGE1 gives lower legs/camera only, no robot box body/short proportions/colors/green marker/labels in final. Healthy upper back/aligned level head, relaxed EMPTY hands and natural martial balance; no hunch/parade arch/elderly stoop. Eyes natural reddish-brown with no glow, no chain/weapon/rope/banner/new prop or costume.
Exactly ONE complete full-body adult on genuine transparent RGBA native square<=1536, centered with generous80px+ clear alpha margins including hair/scarf/hem/boots; whole head/hands/both boots, no crop/mirror/floor/shadow/grid/text/extra views. Refined painterly materials unchanged; distinct close-foot B with RIGHT flat support and LEFT low swing.'''}
persist(HERE/'requests/deng_fei_passing_b2_sw_v4.json',r)
print('Deng Fei SW B failure and exact focused native B2 request preserved')
