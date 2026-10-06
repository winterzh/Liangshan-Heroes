"""Persist sixteen native Deng Fei gait requests using reviewed own idle sources."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
FACING={
    'se':'FRONT elevated isometric three-quarter LOWER-RIGHT SE; chest brass ornament/full curly beard visible, head torso and boot toes lower-right.',
    'sw':'FRONT elevated isometric three-quarter LOWER-LEFT SW; chest brass ornament/full curly beard visible, head torso and boot toes lower-left.',
    'ne':'BACK elevated isometric three-quarter AWAY-UPPER-RIGHT NE; back armor/scarf/curly hair visible, only tiny far-side beard profile, no frontal chest ornament/both eyes, boot toes upper-right.',
    'nw':'BACK elevated isometric three-quarter AWAY-UPPER-LEFT NW; back armor/scarf/curly hair visible, only tiny far-side beard profile, no frontal chest ornament/both eyes, boot toes upper-left.',
}
BODY='''Exact mature rugged tawny Chinese Deng Fei face, thick curly black hair/high tied bundle and full thick curly black beard/moustache, rust-brown hair cloth and trailing ends, intense natural reddish-brown eyes without glow. Brown ragged shoulder scarf/layered torn brown cloth, brown leather/lamellar armor with round brass chest ornament, rust-red tied sash, dark brown trousers, dark boots/brass decorative shin armor. Match character reference's adult head/hands/boots and long normal limbs, all armor/cloth layers and refined painterly materials. Rugged alert martial adult, strong balanced stance, healthy straight upper back and aligned level head/gaze, naturally open shoulders, small individual hip/shoulder asymmetry. Never short/chibi/giant head/boots, collapsed hunch, deep squat, elderly slump, forced parade/chest arch. No chain/weapon/rope/bag/banner/props/new costume.'''
for phase in ('walk_a','passing_a','walk_b','passing_b'):
    for d,camera in FACING.items():
        side='RIGHT' if ((phase.endswith('_a') and d=='se') or (phase.endswith('_b') and d!='se')) else 'LEFT'
        other='LEFT' if side=='RIGHT' else 'RIGHT'
        if phase.startswith('walk_'):
            guide=HERE/f'guides/qin_ming_{phase}_{d}_geometry_v4.png'
            legs=f'''SHORT CONTACT: RED IMAGE-{side} support boot heel AND toe fully FLAT on its ground under own hip, BLUE IMAGE-{other} boot low raised in compact short stride with soft knee. Both legs connect continuously to own hips, no crossing/disconnected shins. Support whole underside must not face camera; supporting heel remains down. Opposite foot visibly low raised, not both-planted idle. A and B MUST alternate visible support. No huge forward sole, high knee/kick, run or lunge.'''
        else:
            guide=HERE/f'guides/wang_ying_{phase}_{d}_geometry_v7.png'
            legs=f'''TRUE DISTINCT NEAR-FOOT PASSING: RED IMAGE-{side} support boot heel AND toe fully FLAT under hip bearing weight, BLUE IMAGE-{other} boot LOW raised about one boot-thickness and passing UNDER pelvis closely BESIDE support boot with mild knee bend. Both boots clear/distinct and connected to own hip. Small gap, not wide contact stride. A/B MUST visibly alternate support. No both-planted idle, invisible raised boot, huge sole/high knee/kick. Preserve image-{side} flat/image-{other} raised assignment, do not repeat A as B.'''
        req={'transparent_background':True,'referenced_image_paths':[guide.as_posix(),(ROOT/f'assets/characters/deng_fei_wounded_20261005/idle_single_{d}_v4.png').as_posix()],
             'prompt':f'''POSE-GUIDED exactly ONE full-body Deng Fei {phase.upper()} native sprite. IMAGE1 provides ONLY lower leg geometry/camera, RED IMAGE-{side} FLAT support and BLUE IMAGE-{other} LOW swing. Do not copy robot torso/short box proportions/colors/green marker/labels. IMAGE2 provides exact Deng Fei identity/adult body/wardrobe. {BODY}
FACING: {camera} Head shoulders torso hips feet all agree; rear shows actual BACK, never front portrait or mirrored front.
MANDATORY LEG POSE: {legs}
Relaxed EMPTY hands near sides with small natural opposite arm swing, stable level head/neck and natural shoulders. Rust sash, curly hair, brass rivets/ornaments, ragged scarf/hem follow minimally and stay consistent. Keep both boots readable; cloth must not hide swing foot. Personality stays alert rugged, no aggressive attack pose.
Exactly ONE COMPLETE adult on genuine transparent RGBA native square<=1536, centered with generous80px+ clear alpha margins including hair/trailing cloth/hem/boots. Head/hands/feet whole, no crop/mirror/background/floor/shadow/grid/text/guide colors/extra people/views/changed clothes. New distinct {phase.upper()} legs with stated support side.'''}
        p=HERE/f'requests/deng_fei_{phase}_{d}_v4.json'
        if p.exists():assert json.loads(p.read_text(encoding='utf-8'))==req
        else:p.write_text(json.dumps(req,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('16 exact native Deng Fei gait requests prepared; generation not executed by helper')
