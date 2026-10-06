"""Persist eight true low-passing edits with separately hashed identity/pose inputs."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
camera={'se':'FRONT-RIGHT/southeast, head and both boot toes down-right',
    'sw':'FRONT-LEFT/southwest, head and both boot toes down-left',
    'ne':'BACK-RIGHT/northeast, face away-right and both boot toes up-right',
    'nw':'BACK-LEFT/northwest, face away-left and both boot toes up-left'}
for phase in ('passing_a','passing_b'):
    for d in ('se','sw','ne','nw'):
        config=json.loads((HERE/f'guides/geometry_{phase}_{d}_v7.json').read_text(encoding='utf-8'))
        side=config['expected_support_image_side'].upper()
        swing='RIGHT' if side=='LEFT' else 'LEFT'
        guide=f'tools/contracts/zhu_wounded_20261005/guides/wang_ying_{phase}_{d}_geometry_v7.png'
        identity=f'assets/characters/wang_ying_wounded_20261005/idle_single_{d}_v4.png'
        for path,name in [(guide,f'wang_ying_{phase}_{d}_geometry_v7'),(identity,f'wang_ying_idle_single_{d}_v4')]:
            j=json.loads((HERE/f'jobs/{name}.json').read_text(encoding='utf-8'))
            assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==j['output_sha256']
        prompt=f'''POSE-GUIDED LOW PASSING PHASE {phase.upper()}, not neutral idle or wide contact stride. IMAGE1 is only the mathematical leg-pose/camera reference. IMAGE2 is the full identity, adult short-stocky body, garments and painterly game style reference for ONE Wang Ying.
Create the exact narrow under-pelvis passing arrangement shown in IMAGE1: RED is the IMAGE-{side} support leg/boot FLAT planted and carrying weight; BLUE is the IMAGE-{swing} swing leg with mildly bent knee and boot held LOW above the ground, traveling just beside and under the pelvis. Its heel/toe must be visibly raised a LITTLE, no high knee/kick, sole facing viewer or long backward extension. Preserve both hip/knee/ankle attachments and the clear {side.lower()} support / {swing.lower()} swing relationship. Translate rods/box boots into his own short adult legs, gray trousers and brown boots with grouped HORIZONTAL shin wraps. Feet are close in horizontal stride; one planted, one modestly raised passing the support leg. Never leave both feet planted like idle, never reuse the wide A/B contact feet.
Wang Ying must remain the specific mature rough round bearded man of IMAGE2: dark topknot and red headband, naturally SHORT BROAD STOCKY adult, upright level head and upper back, natural short adult thighs/calves, normal head/neck/hands/feet, red tunic, brown brass-riveted shoulder/torso armor/bracers and round-studded belt, gray trousers and his own horizontally wrapped boots. Preserve his face, shoulder/body width, short stature, costume layering, colors, lighting and detailed painterly materials. Natural empty hands with only slight quiet walking balance. Do not stretch him tall or slender, make child/chibi or oversized head/boots, hunch, change shin wraps to cross lacing, copy robot box body, or copy guide red/blue leg colors/green plate.
Whole body/head/legs/toes keep {camera[d]}, same elevated isometric camera as IMAGE2. Exactly ONE full complete Wang Ying centered and contained on genuine transparent RGBA square<=1536 with ample clear margins. No floor/shadow/background/grid/text/labels, robot colors, weapon/rope/new accessory or extra person. This is a newly authored real low passing pose between opposing support steps, not a mirrored image or stationary standing frame.'''
        req={'transparent_background':True,'referenced_image_paths':[(ROOT/guide).as_posix(),(ROOT/identity).as_posix()],'prompt':prompt}
        p=HERE/f'requests/wang_ying_{phase}_{d}_v4.json'
        if p.exists():assert json.loads(p.read_text(encoding='utf-8'))==req
        else:p.write_text(json.dumps(req,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'requests':8,'native_pose_identity_parent_hashes_verified':16}))
