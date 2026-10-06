"""Persist sixteen independent native Yang Lin gait requests; never edit pixels."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent
FACING = {
    'se': 'FRONT three-quarter elevated isometric view facing LOWER-RIGHT SE; chest/pointed beard visible, head torso and boot toes lower-right.',
    'sw': 'FRONT three-quarter elevated isometric view facing LOWER-LEFT SW; chest/pointed beard visible, head torso and boot toes lower-left.',
    'ne': 'BACK three-quarter elevated isometric view facing AWAY-UPPER-RIGHT NE; back of coat/shoulders/headcloth visible, tiny far-side beard profile only, no frontal chest or both eyes; boot toes upper-right.',
    'nw': 'BACK three-quarter elevated isometric view facing AWAY-UPPER-LEFT NW; back of coat/shoulders/headcloth visible, tiny far-side beard profile only, no frontal chest or both eyes; boot toes upper-left.',
}
BODY = """Yang Lin's exact mature face/POINTED short black beard/moustache and blue-black tied headcloth with trailing ends; tan LEOPARD-ROSETTE spotted fur coat with pale fur collar/front/hem trim, pale rolled linen sleeves, BLUE tied sash, tan trousers, layered dark-blue shin wraps and ordinary dark cloth boots. Preserve spots, never tiger stripes/plain fur. NORMAL ADULT proportions with broad shoulders, relatively narrow waist and long natural limbs; exact head/hand/boot sizes and painterly materials from IMAGE2. Do not copy robot stocky box torso/short body or colored legs. Experienced mobile traveler/martial bearing, naturally aligned level head/upper back and searching gaze, lightly soft knees and modest functional hip movement. No forced parade stiffness, deep squat, rounded hump, huge head/boots or overarched chest."""

for phase in ('walk_a', 'passing_a', 'walk_b', 'passing_b'):
    for d in FACING:
        side = 'RIGHT' if ((phase.endswith('_a') and d == 'se') or (phase.endswith('_b') and d != 'se')) else 'LEFT'
        other = 'LEFT' if side == 'RIGHT' else 'RIGHT'
        if phase.startswith('walk_'):
            guide = HERE / f'guides/qin_ming_{phase}_{d}_geometry_v4.png'
            legs = f"""COMPACT NATURAL CONTACT: RED IMAGE-{side} support boot HEEL AND TOE fully flat on ground under own hip, BLUE IMAGE-{other} opposite boot modestly LOW raised, soft knee, short natural stride. Preserve colored guide's support assignment rather than two-planted idle legs. Each adult leg continuously belongs to its own hip; no crossing/disconnected shins. Entire underside of PLANTED boot must not face camera; support heel stays down. Raised foot low, no large high sole/kick. A/B alternate support side."""
        else:
            guide = HERE / f'guides/wang_ying_{phase}_{d}_geometry_v7.png'
            legs = f"""TRUE DISTINCT NEAR-FOOT PASSING: RED IMAGE-{side} boot FLAT planted, supporting weight directly under hip. BLUE IMAGE-{other} boot clearly LOW raised and moving past UNDER pelvis beside support foot, knee mildly bent. Close fore-aft/lateral gap rather than wide walking-contact stride. Both boots fully distinct and connected through normal adult ankle/shin/knee to own hips. Raised heel/toe visibly clear of its corresponding ground plane by about ONE BOOT-THICKNESS, not both boots flat planted. Do not replace with idle/contact legs. Compact low passing, never high knee/huge sole/kick; A/B alternate support. Avoid hiding raised boot behind hem."""
        prompt = f"""POSE-GUIDED SINGLE Yang Lin {phase.upper()} native sprite. IMAGE1 gives ONLY lower-leg pose and camera: RED IMAGE-{side} boot flat support, BLUE IMAGE-{other} low raised swing. Robot torso/proportions/colors/green marker/labels NOT character art. IMAGE2 gives all Yang Lin identity/body/garment/material invariants. {BODY}
FACING: {FACING[d]} Keep entire body orientation, never turn rear view into frontal portrait or mirror front to fake back.
MANDATORY LOWER BODY: {legs}
Relaxed empty hands near sides with a SMALL natural opposing arm swing/balance; head level/neck aligned, shoulders comfortable and waist mobile. Preserve coat rosette density, pale trim and sleeve cuffs, blue sash knot/pattern and calf wraps throughout; coat hem follows minimally and never hides both boots. No helmet/armor/weapon/sheath/rope/bag/banner/new prop. No long lunge/run/jump/attack/deep crouch/hump/parade chest.
Exactly ONE complete full-body adult Yang Lin on genuine transparent RGBA native square<=1536, centered with generous80px+ clear alpha margins including headcloth/boots. Head, both hands and boots whole/unclipped; original adult limb lengths. No floor/shadow/background, grid/text/guide colors/robots, extra people/views, cropping/mirroring or changed costume. New {phase.upper()} leg pose, matching identifiable Yang Lin."""
        req = {
            'transparent_background': True,
            'referenced_image_paths': [
                guide.as_posix(),
                (ROOT / f'assets/characters/yang_lin_wounded_20261005/idle_single_{d}_v4.png').as_posix(),
            ],
            'prompt': prompt,
        }
        dest = HERE / f'requests/yang_lin_{phase}_{d}_v4.json'
        if dest.exists():
            assert json.loads(dest.read_text(encoding='utf-8')) == req
        else:
            dest.write_text(json.dumps(req, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('16 exact native Yang Lin gait requests prepared; not executed by this helper')
