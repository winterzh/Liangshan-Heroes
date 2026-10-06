"""Exact requests for the remaining ordinary Wu Song four-heading walk phases."""
from pathlib import Path
import json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
identity=ROOT/'assets/characters/wu_song_traits_20261006/idle_spacing_v4.png'
headings={
    'se':('TOP-LEFT','FRONT three-quarter facing DOWN-RIGHT / southeast','RIGHT'),
    'sw':('TOP-RIGHT','FRONT three-quarter facing DOWN-LEFT / southwest','LEFT'),
    'ne':('BOTTOM-LEFT','BACK three-quarter facing AWAY-UPPER-RIGHT / northeast','LEFT'),
    'nw':('BOTTOM-RIGHT','BACK three-quarter facing AWAY-UPPER-LEFT / northwest','LEFT'),
}
created=[]
for state in ['walk_a','passing_a','walk_b','passing_b']:
    for direction,(quadrant,camera,side_a) in headings.items():
        if direction=='se' and state in ['walk_a','walk_b']:continue
        phase=state.rsplit('_',1)[1]
        support=side_a if phase=='a' else ('LEFT' if side_a=='RIGHT' else 'RIGHT')
        swing='LEFT' if support=='RIGHT' else 'RIGHT'
        passing=state.startswith('passing')
        guide=HERE/'guides'/f"{'wang_ying' if passing else 'qin_ming'}_{state}_{direction}_geometry_v{'7' if passing else '4'}.png"
        assert identity.is_file() and guide.is_file()
        prompt=(
            f'Use case: historical-scene. Native transparent SINGLE ordinary Wu Song {state.upper()} sprite. '
            f'Reference1 is identity/clothes/anatomy/style: use ONLY its {quadrant} {direction.upper()} man. '
            'Same broad powerful mature man, healthy straight upper back and naturally raised head, normal '
            'adult head/neck/hands and long usable legs, dark headcloth and tied long black hair, short beard '
            'where face is visible, large wooden Buddhist beads, charcoal crossed robe, green-gray cloth belt '
            'and ragged skirt layers, dark trousers, pale grouped horizontal shin wraps, dark boots, brown '
            'bracers. Preserve the exact bead arrangement, garment lengths/layers and painterly materials. '
            'Keep exactly one curved steel dao in EACH hand, low near the own hip, gently angled out/down, '
            'same quiet carry as identity idle, with slight natural counter-motion; no raised attack blade. '
            'Reference2 is ONLY mathematical leg-pose and heading guidance. Never inherit its robot body, '
            'colors, ground or labels, nor any other character anatomy/clothes. '
            f'CAMERA: elevated RTS isometric, {camera}. Entire head/torso/pelvis/toes keep that heading. '
        )
        if direction in ['ne','nw']:
            prompt+='Back of headcloth/shoulders/robe is visible, only a small far-side facial profile; no frontal chest or both eyes. '
        prompt+=(
            f'LEGS: reference2 RED IMAGE-{support} leg is FLAT PLANTED support with heel AND forefoot '
            f'at one ground level. BLUE IMAGE-{swing} boot is modestly raised, each leg connects to its own '
            'hip. Translate colored rods/boxes into this Wu Song’s normal wrapped adult legs and boots. '
        )
        if passing:
            prompt+=(
                'This is a NARROW LOW PASSING phase: raised boot travels close beside the support leg '
                'directly under the pelvis, with mildly flexed knee and only a little clear ground gap. '
                'Feet are close in horizontal stride. Not two planted idle boots, not a wide contact stride, '
                'not a high knee/kick or large exposed sole. Newly author this actual passing leg arrangement. '
            )
        else:
            prompt+=(
                'This is a short purposeful ordinary CONTACT step. Support leg reaches modestly forward; '
                'opposite boot recovers low behind with a soft knee. Distinct opposing support, not both flat '
                'idle boots, not a long lunge/run/jump or attack. '
            )
        prompt+=(
            'Stable upright chest/shoulders and forward gaze, slight natural hip transfer; no hunch, rounded '
            'hump, deep squat, child/chibi proportions or exaggerated rigid parade stance. Clothing/hair '
            'follow the restrained motion, both boots visible. One complete man only, no atlas/grid/extra '
            'views. Square native RGBA PNG<=1536, genuinely transparent alpha, centered full silhouette '
            'including swords with generous80px+ clear margins. Body about75-78% square height. No floor, '
            'shadow, background, text, guide colors or new accessories. No crop/mirror of another heading.'
        )
        dest=HERE/'requests'/f'wu_song_{state}_{direction}_v5.json'
        assert not dest.exists()
        args={'prompt':prompt,'referenced_image_paths':[str(identity),str(guide)],'transparent_background':True}
        dest.write_bytes((json.dumps(args,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
        created.append(dest.relative_to(ROOT).as_posix())
print(json.dumps({'requests':created,'count':len(created),'submitted':False}))
