"""Use a verified human passing pose as leg-only reference; retain failed B3."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;QA=ROOT/'qa/zhu_wounded_20261005'
def persist(p,v):
    if p.exists():assert json.loads(p.read_text(encoding='utf-8'))==v
    else:p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
bad='assets/characters/deng_fei_wounded_20261005/passing_b3_sw_v4.png'
persist(QA/'deng_fei_passing_b3_sw_rejection_v4.json',{'path':bad,'sha256':hashlib.sha256((ROOT/bad).read_bytes()).hexdigest(),
    'reason':'B3 still reads as image-left straight planted leg/image-right raised, too similar to A; reject for unequivocal opposite B support.',
    'selected':False,'production_qualified':False})
r={'transparent_background':True,'referenced_image_paths':[(ROOT/'assets/characters/huang_xin_wounded_20261005/passing_b2_sw_v4.png').as_posix(),(HERE/'guides/wang_ying_passing_b_sw_geometry_v7.png').as_posix(),(ROOT/'assets/characters/deng_fei_wounded_20261005/walk_b_sw_v4.png').as_posix()],
    'prompt':'''Create ONE full-body DENG FEI in EXACT lower-leg passing POSE of IMAGE1, with ONLY Deng Fei identity/materials from IMAGE3. IMAGE1 is a HUMAN POSE REFERENCE ONLY: IMAGE-RIGHT leg straight, vertical weight-bearing, right boot heel AND toe FLAT planted; IMAGE-LEFT thigh/knee distinctly bent and left boot LOW dangling OFF ground close beneath pelvis beside planted foot. Copy that exact visible right-straight/left-bent leg topology and foot spacing. Never use left-straight/planted and right-raised legs. IMAGE2 mathematical guide confirms RIGHT red support/LEFT blue swing only; no guide colors/robot/green marker/labels in final. IMAGE3 locks Deng Fei face/body/clothes, NOT its extended contact legs.
MUST be Deng Fei: rugged mature tawny Chinese face, thick curly BLACK hair/high tied bundle and full CURLY black beard, rust-brown hair tie/trailing cloth, brown ragged shoulder scarf/cloth, brown brass-decorated lamellar armor and brass chest ornaments, rust-red tied sash, dark brown trousers, dark boots with Deng Fei ornate brass shin armor. Exact refined painterly palette/materials from IMAGE3. Do NOT copy IMAGE1's face/topknot/ochre headband/yellow robe/gold lion pauldrons or generic uniform torso/body. Natural adult limbs/head/hands/boots, robust alert individual martial build, healthy upper back/level gaze and relaxed empty hands. No chain/weapon/rope/banner/new prop.
FRONT elevated isometric three-quarter SOUTHWEST LOWER-LEFT, chest visible, nose/head/torso/boot toes all left, same camera as references. RIGHT support leg straight and flat under own hip; LEFT knee obviously bent, left heel/toe completely OFF its own ground plane about one boot-thickness with left foot close under body. Both legs continuously connect to own hips and boots distinct. No crossed leg, two planted idle feet, wide contact stride, high kick/huge sole, hunch/parade arch or glowing eyes. Cloth moves minimally without hiding the raised LEFT foot.
Exactly ONE complete adult on genuine transparent RGBA native square<=1536, centered with generous80px+ clear alpha margins around entire curly hair/scarf/hem/boots; whole head/hands/both feet, no crop/mirror/background/floor/shadow/grid/text/extra views. Only IMAGE1 LEG POSE, IMAGE3 Deng Fei identity, true distinct passing B with RIGHT planted and LEFT bent/low raised.'''}
persist(HERE/'requests/deng_fei_passing_b4_sw_v4.json',r)
print('B3 rejected; B4 uses verified human legs only and own Deng Fei identity')
