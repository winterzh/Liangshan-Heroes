"""Persist four true four-direction phases retaining the individual infiltrator idle."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
identity='assets/characters/shi_qian_wounded_20261005/idle_traits_v4.png'
j=read(HERE/'jobs/shi_qian_idle_traits_v4.json');assert sha(ROOT/identity)==j['output_sha256']
old=read(ROOT/'assets/direction4/zhu_wounded_shi_qian_20261005.json')
dirs=('se','sw','ne','nw')
for phase in ('walk_a','passing_a','walk_b','passing_b'):
    refs=[identity]
    if phase in ('walk_a','walk_b'):
        refs.extend(old['sources'][phase+'_'+d]['path'] for d in dirs)
        phase_spec='''A compact walking contact/support step with separated feet: use each direction's lower-body guide in images2–5 for its knee/boot placement and planted-versus-lifted foot. Keep the stride short and knees softly flexible. Do not copy the guide upper body, head shape, heavy garment pattern or expression.'''
    else:
        refs.extend(f'tools/contracts/zhu_wounded_20261005/guides/wang_ying_{phase}_{d}_geometry_v7.png' for d in dirs)
        phase_spec='''A true LOW near-foot passing step: use each direction's red/blue geometry in images2–5. RED is the flat planted support boot; BLUE is the modestly raised swing boot passing CLOSE UNDER THE PELVIS with mild knee bend. Feet nearly alongside, one flat and one visibly but only slightly lifted. No large stride/high knee/kick or wide backward extension; do not stand with both feet flat. Geometry supplies only relative knee/ankle/support arrangement, never the robot box torso, short-stocky anatomy, leg colors or green plate.'''
    for p in refs:assert (ROOT/p).is_file()
    prompt=f'''Edit IMAGE1 into ONE FOUR-DIRECTION 2x2 Shi Qian sprite atlas for {phase.upper()}, a separately authored walking phase. Preserve the same distinct SLIM agile mature adult infiltrator: alert eyes, black mouth/nose mask, dark tied headwrap/topknot/trailing cloth, charcoal cross-over tunic with the same subtle cloth pattern and garment layers, plain tan cloth sash, dark trousers, tan DIAGONAL shin wraps and his modest dark cloth boots. Empty hands, no weapons/ropes/sack/armor/blood/new accessory. Every figure must keep the identity and garment detail of IMAGE1, not any older human guide.
PERSONALITY AND ANATOMY: match IMAGE1's light flexible knees, modest lowered/forward weight from hips, alert searching head, arms close with slight ready balance. Natural slim adult neck/torso/thigh/calf proportions and normal hands/feet. He is a nimble infiltrator; do not force rigid military parade chest/locked knees. Avoid an accidental rounded hump, elderly stoop, deep squat, timid grimace, oversized head/boots or child/chibi proportions. This is a quiet light short walking step in the current unarmed rescued context.
FOUR FIXED VIEWS: top-left SE FRONT-RIGHT with toes down-right; top-right SW FRONT-LEFT with toes down-left; bottom-left NE BACK-RIGHT away-right with toes up-right; bottom-right NW BACK-LEFT away-left with toes up-left. Never swap views, mirror a figure, rotate its upper torso against its feet, or show a front face in a back cell.
IMAGE2 is only SE lower-leg pose guide, IMAGE3 only SW, IMAGE4 only NE, IMAGE5 only NW. {phase_spec}
Use each guide solely for its corresponding leg pose. Re-author those legs on the slim adult Shi Qian of IMAGE1 while preserving his alert low-ready upper body and all charcoal clothing. Keep all four figures and all phases consistent in face, head size, body proportions, cloth layering/texture, sash and wrapped boots. Newly authored {phase} feet must differ from IMAGE1's idle feet; no reused stationary idle as passing.
Native square transparent RGBA atlas <=1536, preferably same1254 square as IMAGE1, exactly FOUR complete full-body figures, each centered in its own equal cell with generous clear margins around headcloth/fingers/boots and at least50px cell padding. Same elevated isometric painterly historic game camera/light/palette as IMAGE1. No background, floor/shadow, grid lines, text/labels, robot colors or extra figures.'''
    req={'transparent_background':True,'referenced_image_paths':[(ROOT/p).as_posix() for p in refs],'prompt':prompt}
    p=HERE/f'requests/shi_qian_{phase}_traits_atlas_v4.json'
    if p.exists():assert read(p)==req
    else:p.write_text(json.dumps(req,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'native_phase_requests':4,'authored_directions_per_phase':4,'total_new_gait_poses':16,'idle_is_not_reused_as_passing':True}))
