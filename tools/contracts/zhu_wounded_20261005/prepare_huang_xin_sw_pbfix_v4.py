"""Preserve wrong support SW passing B; generate distinct opposite support natively."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;QA=ROOT/'qa/zhu_wounded_20261005'
def persist(p,v):
    if p.exists():assert json.loads(p.read_text(encoding='utf-8'))==v
    else:p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
bad='assets/characters/huang_xin_wounded_20261005/passing_b_idlefix_sw_v4.png'
persist(QA/'huang_xin_passing_b_sw_rejection_v4.json',{'path':bad,'sha256':hashlib.sha256((ROOT/bad).read_bytes()).hexdigest(),
    'reason':'SW passing B repeats A support: image-left remains flat and image-right raised. B requires image-right flat and image-left low raised near pelvis.',
    'selected':False,'production_qualified':False})
r={'transparent_background':True,'referenced_image_paths':[(HERE/'guides/wang_ying_passing_b_sw_geometry_v7.png').as_posix(),(ROOT/bad).as_posix()],
    'prompt':'''Focused native leg correction to IMAGE2 Huang Xin. Preserve EXACT face, frontal SW camera facing image-left, stern mature dark beard/topknot/ochre headband/scarf, gold shoulder beast plates and rivets, dark armor, hands/belt/ochre cloth/torn hem and natural adult proportions. Correct ONLY legs below hips and minimal associated hem.
IMAGE1 geometry is MANDATORY support assignment: RED IMAGE-RIGHT boot HEEL AND TOE FLAT under its own hip bearing weight. BLUE IMAGE-LEFT boot LOW RAISED, passing under pelvis close BESIDE support boot with soft knee. IMAGE2 incorrectly uses image-left flat/image-right raised, repeating A. The corrected pose MUST visibly swap: right foot fully flat, left foot clearly off its corresponding ground plane by about one boot-thickness. Both boot soles distinct and connected to own hips; no crossed/detached leg. No both-flat idle, no wide contact stride, no high knee or large sole/kick. Raised left foot remains very close under body, never rear hidden boot on right.
Keep FRONT three-quarter elevated SW facing LOWER-LEFT, nose/chest/boot toes all left, not front-right or rear. Head/upper back naturally upright, stable military bearing with small balance motion, no hunch or parade arch. IMAGE1 gives pose only, no robot/short box torso/red-blue/green/labels in final.
Exactly ONE complete adult on genuine transparent RGBA native square<=1536, centered with generous80px+ clear alpha margins around cloth/boots/head. Preserve refined painterly materials. No crop/mirror/weapons/rope/banner/props/text/grid/floor/shadow/new costume. Distinct near-foot PASSING B with RIGHT flat support and LEFT low swing.'''}
persist(HERE/'requests/huang_xin_passing_b2_sw_v4.json',r)
print('SW passing B failure and exact B2 native correction request preserved')
