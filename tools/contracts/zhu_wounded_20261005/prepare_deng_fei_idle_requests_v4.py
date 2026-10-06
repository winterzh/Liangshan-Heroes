"""Prepare four independent native Deng Fei idle requests, preserving identity."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
FACING={
    'se':'FRONT elevated isometric three-quarter facing LOWER-RIGHT SE, chest ornament/beard visible, head torso and both boot toes lower-right.',
    'sw':'FRONT elevated isometric three-quarter facing LOWER-LEFT SW, chest ornament/beard visible, nose/eyes explicitly image-left, head torso and both boot toes lower-left. Not another right-facing SE.',
    'ne':'BACK elevated isometric three-quarter facing AWAY-UPPER-RIGHT NE, back armor/scarf/curly hair visible, tiny far-side beard profile only, no frontal chest ornament/both eyes, boot toes upper-right.',
    'nw':'BACK elevated isometric three-quarter facing AWAY-UPPER-LEFT NW, back armor/scarf/curly hair visible, tiny far-side beard profile only, no frontal chest ornament/both eyes, boot toes upper-left.',
}
for d,camera in FACING.items():
    req={'transparent_background':True,'referenced_image_paths':[(ROOT/'assets/characters/deng_fei_wounded_20261005/idle_v3.png').as_posix()],
         'prompt':f'''Create exactly ONE whole full-body Deng Fei IDLE from corresponding {d.upper()} reference-sheet view in IMAGE1. IMAGE1 locks his recognizable mature rugged tawny Chinese face, THICK CURLY BLACK HAIR tied high with RUST-BROWN cloth and trailing ends, FULL thick CURLY BLACK beard/moustache, intense natural reddish-brown eyes (NO glowing/fire eyes), brown ragged shoulder scarf/torn layered brown cloth, brown leather/lamellar armor with round BRASS chest ornament, rust-red tied waist sash, dark-brown trousers and dark boots with existing brass ornamental shin armor. Preserve the existing face/costume/material layers and refined painterly palette. No iron chain, weapon/sheath, rope, banner, bag or new prop.
FACING: {camera} Whole head, shoulders, hips and feet agree. Rear views must be real back views, not mirrored front portraits. Single view only.
INDIVIDUAL BEARING: mature rugged martial adult with a strong grounded balanced stance and alert intense level gaze. Naturally open shoulders, head over neck/spine, straight healthy upper back; subtle individual shoulder/hip asymmetry allowed. Feet both planted in moderate stance, softly natural knees, relaxed empty hands ready near sides. Keep natural long adult limbs and proportionate head/hands/boots, do not make short/chibi, giant boots/head, deep squat or collapsed rounded hunch. Strong alertness does not require stiff parade chest-arching, scowling caricature or elderly stoop. Preserve full curly hair/beard and brass/brown armor; not a generic uniform soldier. Specific hair/costume/proportions are retained project design.
Exactly ONE COMPLETE adult on genuine transparent RGBA square native<=1536, centered with generous80px+ clear alpha margins around curly hair/trailing cloth/hem/both boots. Head/hands/feet whole, no crop/mirror/local paint or costume changes. No floor/shadow/background/grid/text/labels/extra people/views/props/attack pose. Refined native painterly unarmed rescued-foot idle candidate.'''}
    p=HERE/f'requests/deng_fei_idle_single_{d}_v4.json'
    if p.exists():assert json.loads(p.read_text(encoding='utf-8'))==req
    else:p.write_text(json.dumps(req,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('4 exact native Deng Fei idle requests prepared; not executed by helper')
