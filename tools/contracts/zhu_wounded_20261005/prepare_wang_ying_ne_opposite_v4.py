"""Persist a visual opposite-support leg guide without copying its identity."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
target='assets/characters/wang_ying_wounded_20261005/walk_a_ne_v4.png'
guide='assets/characters/shi_xiu_wounded_20261005/step_b_body2_ne_v4.png'
for path,name in [(target,'wang_ying_walk_a_ne_v4'),(guide,'shi_xiu_step_b_body2_ne_v4')]:
    j=json.loads((HERE/f'jobs/{name}.json').read_text(encoding='utf-8'))
    assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==j['output_sha256']
prompt='''Two images have strictly separate roles. IMAGE1 is the EDIT TARGET: ONE short stocky mature Wang Ying NE/back-right sprite. Preserve his exact face/profile, topknot/red headband, broad body, short adult thighs/calves, head proportions, red tunic, brown riveted armor/bracers and round belt studs, gray trousers and brown wrapped boots, empty hands, upright upper torso, palette, elevated isometric NE camera. Change ONLY his two legs below the lower tunic into the OPPOSITE support pose.
IMAGE2 is ONLY A LEG-POSE GUIDE for the opposite phase, NOT an identity, body-type, costume, hair, color or armor reference. Match the IMAGE2 relative knee/ankle/sole arrangement and boot direction: the image-right foreground leg carries weight and its boot is FLAT planted; the image-left rear leg bends slightly BACK and its boot is lifted low, heel/sole partially visible. This must visibly reverse IMAGE1, whose image-left rear boot is planted and image-right boot is ahead. Retain both legs attached to their own hips. Natural compact quiet step, no knee-high kick or running/lunge.
Translate that opposite leg pose onto Wang Ying's own SHORT BROAD adult anatomy. Do not copy the slender taller man, blue outfit, torn tunic, cloth sash or slim legs from IMAGE2. Preserve every Wang Ying garment and upper-body material; only necessary lower tunic fabric follows the new legs. Keep both toes and torso pointing away up-RIGHT, same complete NE view. Exactly ONE full Wang Ying on genuine transparent RGBA square<=1536 with ample margins and contained boots/cloth/fingers. No other man, shadow/floor/grid/text/rope/weapons/new accessory. This is a separately authored opposing walking support pose, not neutral idle and not a mirrored image.'''
request={'transparent_background':True,'referenced_image_paths':[(ROOT/target).as_posix(),(ROOT/guide).as_posix()],'prompt':prompt}
p=HERE/'requests/wang_ying_walk_b_ne_v4.json'
if p.exists():assert json.loads(p.read_text(encoding='utf-8'))==request
else:p.write_text(json.dumps(request,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'request':p.relative_to(ROOT).as_posix(),'role_separation':'Wang Ying identity; Shi Xiu lower-body opposite support guide only'}))
