"""Prepare the remaining three visually guided opposite-support native edits."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
directions={'se':('FRONT-RIGHT / southeast, both toes down-right','image-left foreground boot planted flat, image-right rear knee bent and boot raised modestly'),
    'sw':('FRONT-LEFT / southwest, both toes down-left','image-right foreground boot planted flat, image-left rear knee bent and boot raised modestly'),
    'nw':('BACK-LEFT / northwest, both toes up-left','image-right foreground boot planted flat, image-left rear knee bent and boot raised modestly')}
for d,(heading,feet) in directions.items():
    target=f'assets/characters/wang_ying_wounded_20261005/walk_a_{d}_v4.png'
    guide=f'assets/characters/shi_xiu_wounded_20261005/step_b_body2_{d}_v4.png'
    for path,name in [(target,f'wang_ying_walk_a_{d}_v4'),(guide,f'shi_xiu_step_b_body2_{d}_v4')]:
        j=json.loads((HERE/f'jobs/{name}.json').read_text(encoding='utf-8'))
        assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==j['output_sha256']
    prompt=f'''Two images have strictly separate roles. IMAGE1 is the EDIT TARGET: ONE short stocky mature Wang Ying {d.upper()} walking sprite. Preserve his exact mature bearded face, topknot/red headband, broad stocky body and short adult thighs/calves, adult head/hand/boot proportions, red tunic, brown brass-riveted armor/bracers and round belt studs, gray trousers and his own wrapped boots, empty hands, upright upper torso, lighting and elevated isometric camera.
Change ONLY his two legs below the lower tunic and minimal lower cloth into the OPPOSITE support pose. IMAGE2 is ONLY a LOWER-BODY LEG-POSE GUIDE, not identity/body type/clothes/hair/colors/armor. Copy its relative knee/ankle/boot placement and boot directions onto Wang Ying's SHORT BROAD adult anatomy: {feet}. This must visibly reverse the two support legs of IMAGE1. Keep each leg naturally attached to its own hip. Quiet compact step, no large lunge/high kick/running/jump.
Do not copy the taller slender blue man, torn tunic, cloth sash or thin legs from IMAGE2. Preserve all Wang Ying costume layers, face and upper-body materials and own boots; only lower cloth follows new legs. Whole body/head/knees/toes maintain {heading}; do not mirror or rotate away from the original camera. Exactly ONE full complete Wang Ying centered on genuine transparent RGBA square<=1536, ample clear margins, entire fingers/boots/headband contained. No other person, floor/shadow/background/grid/labels/text, rope/weapon/new accessory. This is a newly authored opposing support walking pose, not neutral idle.'''
    req={'transparent_background':True,'referenced_image_paths':[(ROOT/target).as_posix(),(ROOT/guide).as_posix()],'prompt':prompt}
    p=HERE/f'requests/wang_ying_walk_b_{d}_v4.json'
    if p.exists():assert json.loads(p.read_text(encoding='utf-8'))==req
    else:p.write_text(json.dumps(req,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'requests':3,'role_separation':'Wang Ying identity; Shi Xiu opposite lower-body guide only'}))
