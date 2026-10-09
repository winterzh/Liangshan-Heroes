"""Prepare an explicit pose-first SE opposite-support transfer after failed edit."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
guide='assets/characters/shi_xiu_wounded_20261005/step_b_body2_se_v4.png'
identity='assets/characters/wang_ying_wounded_20261005/idle_single_se_v4.png'
for p,name in [(guide,'shi_xiu_step_b_body2_se_v4'),(identity,'wang_ying_idle_single_se_v4')]:
    j=json.loads((HERE/f'jobs/{name}.json').read_text(encoding='utf-8'))
    assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==j['output_sha256']
prompt='''POSE-FIRST CHARACTER TRANSFER. Create ONE full-body native Wang Ying walking sprite from two references with different roles. IMAGE1 controls ONLY the opposing lower-body walking POSE and southeast camera. IMAGE2 controls the ENTIRE Wang Ying identity, face/hair/clothing/colors, SHORT STOCKY mature adult anatomy and hand-painted game rendering. Output must be the stout armored bearded Wang Ying of IMAGE2, never the blue slender man.
CRITICAL LEGS: Preserve the exact support pattern shown in IMAGE1 while translating it onto Wang Ying's own short adult legs and gray trousers/brown wrapped boots. The image-LEFT FOREGROUND leg goes down and forward to a FLAT planted boot carrying weight. The image-RIGHT REAR knee bends back, heel/boot raised modestly behind. BOTH toes point down-RIGHT / southeast. Do not place the flat planted foreground boot on image-right. It must be the image-left foreground leg that supports him. Both legs remain attached naturally to their own hip sides. This opposing pattern is mandatory; do not reuse IMAGE2's quiet symmetric idle feet.
Render Wang Ying from IMAGE2 with mature rough round bearded face, tied topknot/red headband, broad stocky shoulders/torso, natural SHORT adult thigh/calf lengths, red tunic, brown brass-riveted armor/bracers/round-studded belt, gray trousers and his own wrapped boots. Preserve the costume layers and adult head/neck/hands/foot proportions. Upright quiet bearing, modest compact stride. Never copy blue clothing, torn skirt, cloth sash, slim waist or tall long legs of IMAGE1. No exaggerated hunch, child anatomy, big head, knee-high kick, giant boots or stretched tall body.
Same SE front-right elevated isometric viewpoint, lighting and material detail as IMAGE2. Exactly ONE complete man wholly contained and centered on genuine transparent RGBA square<=1536 with generous clear edges. No rope/weapon/extra person, floor/shadow/background/grid/text or new accessory. Natural empty hands. New native opposing walk pose, no mirror or local pixel edits.'''
req={'transparent_background':True,'referenced_image_paths':[(ROOT/guide).as_posix(),(ROOT/identity).as_posix()],'prompt':prompt}
p=HERE/'requests/wang_ying_walk_b2_se_v4.json'
if p.exists():assert json.loads(p.read_text(encoding='utf-8'))==req
else:p.write_text(json.dumps(req,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'request':p.relative_to(ROOT).as_posix(),'pose_first':True}))
