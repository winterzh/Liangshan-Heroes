"""Persist the pose-first geometry edit with separated pose and identity roles."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
guide='tools/contracts/zhu_wounded_20261005/guides/wang_ying_walk_b_se_geometry_v5.png'
identity='assets/characters/wang_ying_wounded_20261005/idle_single_se_v4.png'
for path,name in [(guide,'wang_ying_walk_b_se_geometry_v5'),(identity,'wang_ying_idle_single_se_v4')]:
    j=json.loads((HERE/f'jobs/{name}.json').read_text(encoding='utf-8'))
    assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==j['output_sha256']
prompt='''POSE-GUIDED NATIVE CHARACTER EDIT. TWO reference images have different roles. IMAGE1 is a NEW GEOMETRY pose guide only: it fixes which foot is planted and which is raised. IMAGE2 is the identity/body/costume/style reference for the one short stout mature Wang Ying character.
Make a full-body native Wang Ying sprite in the EXACT OPPOSING LOWER-BODY SUPPORT LAYOUT of IMAGE1: the leg/boot colored RED in the guide is the IMAGE-LEFT foreground support leg, boot FLAT planted at lower-left, connected continuously to its own hip. The BLUE leg/boot is IMAGE-RIGHT raised slightly at upper-right, knee bent modestly, attached to the other hip. This image-left planted / image-right raised pattern is mandatory. Do NOT reuse the quiet leg positions of IMAGE2. Preserve the geometric hip-knee-ankle relation and separation; do not reverse the two legs. Replace colored rods/box boots with Wang Ying's own believable short adult legs, gray trousers and brown wrapped boots with HORIZONTAL band groups. Both boot toes point DOWN-RIGHT / southeast. Quiet compact step, not deep lunge, high kick, run or jump.
Render the Wang Ying of IMAGE2: specific mature rough bearded round face, dark topknot/red headband, naturally SHORT BROAD STOCKY adult body, normal head/neck/hands/feet, upright head and upper back, red tunic, brown brass-riveted shoulder/torso armor/bracers and round-studded belt. Preserve his recognizable face, shoulder width, naturally short adult thighs/calves, armor layering, palette, horizontal shin wraps and native painterly materials. Do not stretch tall, slim down, hunch, make child/chibi, oversize head/boots, or copy the robot's box torso/gray body/colors. No red or blue leg colors or green ground patch in output.
Image1 contributes only lower-body pose and the same SE front-right elevated isometric camera. Image2 contributes all identity and materials. Exactly ONE complete full-body Wang Ying on genuine transparent RGBA square<=1536, wholly contained and centered with clear margins. No floor/shadow/background, robot/color patches, text/labels, grid, weapon/rope/new prop/other person. Natural empty hands close to his body. New opposing walking support sprite; not a mirrored image.'''
req={'transparent_background':True,'referenced_image_paths':[(ROOT/guide).as_posix(),(ROOT/identity).as_posix()],'prompt':prompt}
p=HERE/'requests/wang_ying_walk_b3_se_v4.json'
if p.exists():assert json.loads(p.read_text(encoding='utf-8'))==req
else:p.write_text(json.dumps(req,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'request':p.relative_to(ROOT).as_posix(),'pose_reference':'projection-verified native Godot geometry'}))
