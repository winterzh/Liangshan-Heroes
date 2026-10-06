"""Persist twenty exact native Huang Xin requests without editing image pixels."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent
FACING = {
    'se': 'FRONT elevated isometric three-quarter facing LOWER-RIGHT SE, chest/beard visible, head torso and both boot toes lower-right.',
    'sw': 'FRONT elevated isometric three-quarter facing LOWER-LEFT SW, chest/beard visible, head torso and both boot toes lower-left.',
    'ne': 'BACK elevated isometric three-quarter facing AWAY-UPPER-RIGHT NE, back of armor/headcloth visible, small far-side beard profile only, no frontal chest/both eyes, boot toes upper-right.',
    'nw': 'BACK elevated isometric three-quarter facing AWAY-UPPER-LEFT NW, back of armor/headcloth visible, small far-side beard profile only, no frontal chest/both eyes, boot toes upper-left.',
}
IDENTITY = '''Stern MATURE Chinese Huang Xin with full dark beard/moustache, ochre cloth headband and dark topknot, ochre scarf tied at chest with trailing back cloth, ochre sleeves/tunic, black-brown lamellar chest/back/hip armor with gold rivets and gold beast-face shoulder plates, brown belt with round gold buckle, dark trousers, ochre crossed shin wraps and dark cloth boots edged ochre. Exact recognizable face, armor layers, scarf/hem silhouette and painterly palette from character reference. No helmet, banner, lettering, pole, weapon, sheath, rope, bag or new prop.'''
BODY = '''NORMAL MATURE ADULT anatomy, natural head/hands/boots and long natural legs, robust officer build. Steady upright military bearing: level alert gaze, head comfortably over neck/spine, straight upper back, shoulders open, grounded balanced weight. Natural knees and minimal walking hip/arm motion; not rigid parade or overarched chest. No hunch, elderly slump, timid cramped shoulders, short/chibi limbs, giant head or inflated boots. Specific armor/proportions are project art design, preserve individuality.'''

def persist(name, request):
    p = HERE / ('requests/' + name + '_v4.json')
    if p.exists(): assert json.loads(p.read_text(encoding='utf-8')) == request
    else: p.write_text(json.dumps(request,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

for d, camera in FACING.items():
    prompt = f'''Create exactly ONE complete full-body Huang Xin idle sprite from the corresponding {d.upper()} view in IMAGE1 reference sheet, not another multi-view sheet. IMAGE1 is identity/material/camera reference. {IDENTITY}
FACING: {camera} Rear means armor BACK and back of head/scarf, never mirrored front portrait.
INDIVIDUAL BEARING: {BODY} Feet both planted in a modest stable standing stance, relaxed empty hands naturally near sides. No attack/running pose.
Exactly ONE whole figure centered on genuine transparent RGBA square native<=1536, generous80px+ clear alpha margin around complete topknot/scarf/hem/boots. No ground, shadows, grid, text, guide colors, extra people/views, cropped hands/feet, mirror or costume change.'''
    persist('huang_xin_idle_single_'+d, {'transparent_background':True,
        'referenced_image_paths':[(ROOT/'assets/characters/huang_xin_wounded_20261005/idle_v3.png').as_posix()], 'prompt':prompt})

for phase in ('walk_a','passing_a','walk_b','passing_b'):
    for d, camera in FACING.items():
        side = 'RIGHT' if ((phase.endswith('_a') and d=='se') or (phase.endswith('_b') and d!='se')) else 'LEFT'
        other = 'LEFT' if side=='RIGHT' else 'RIGHT'
        if phase.startswith('walk_'):
            guide = HERE / f'guides/qin_ming_{phase}_{d}_geometry_v4.png'
            legs = f'''SHORT NATURAL CONTACT: red IMAGE-{side} support boot heel AND toe FLAT on its ground plane under own hip, blue IMAGE-{other} opposite boot LOW raised in short stride with mild bent knee. Distinct boots/legs connected to own hips, no crossing/disconnected shins. Support whole underside must NOT face camera; support heel stays down. Opposite boot visibly low raised, not two-planted idle. A/B alternate support side; no high sole/kick or wide lunge.'''
        else:
            guide = HERE / f'guides/wang_ying_{phase}_{d}_geometry_v7.png'
            legs = f'''TRUE DISTINCT PASSING: red IMAGE-{side} support boot heel AND toe FLAT under hip, blue IMAGE-{other} boot clearly LOW raised about one boot-thickness and passing UNDER pelvis beside support foot with soft knee. Near-foot spacing, not wide contact stride. Both boots distinct/fully visible and connected to own hip. Not both planted or idle legs; not hidden swing foot. A/B alternate support. No kick/high knee/giant sole.'''
        prompt = f'''POSE-GUIDED exactly ONE full-body Huang Xin {phase.upper()} sprite. IMAGE1 gives ONLY camera/lower-body geometry: red IMAGE-{side} flat support, blue IMAGE-{other} low raised swing. Do NOT copy robot torso/short proportions/colors/green marker/labels. IMAGE2 gives character identity/body/clothes. {IDENTITY} {BODY}
FACING: {camera} Do not turn a rear view frontal or mirror a front sprite.
MANDATORY LOWER BODY: {legs}
Natural SMALL opposing empty-arm swing; steady upright head/upper back and normal shoulders. Armor and scarf/hem follow slightly, preserving gold rivets, beast-face shoulder plates, dark armor panel arrangement, ochre cloth and wrapped boots. Hem must not hide both feet. No weapon/rope/banner, running/jumping/attack/deep squat/parade arch or hunched head.
Exactly ONE complete figure centered on genuine transparent RGBA native square<=1536, generous80px+ alpha margins around topknot/scarf/hem/boots. Head/hands/feet whole, natural adult limb lengths. No floor/shadow/background/grid/text/guide colors/robots/extra people/views/crop/mirror/costume changes. Distinct new {phase.upper()} legs.'''
        persist('huang_xin_'+phase+'_'+d, {'transparent_background':True,
            'referenced_image_paths':[guide.as_posix(),(ROOT/f'assets/characters/huang_xin_wounded_20261005/idle_single_{d}_v4.png').as_posix()], 'prompt':prompt})
print('20 exact native Huang Xin requests prepared; this helper does not execute generation')
