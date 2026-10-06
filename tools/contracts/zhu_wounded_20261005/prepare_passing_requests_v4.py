"""Persist full-canvas native passing/ordinary-idle requests; no PNG editing."""
from pathlib import Path
import json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
directions={'se':'down-right front-right','sw':'down-left front-left','ne':'up-right back-right','nw':'up-left back-left'}
for d,facing in directions.items():
    a=ROOT/f'assets/characters/shi_xiu_wounded_20261005/walk_a_matched_{d}_v4.png'
    if d=='nw':a=ROOT/'assets/characters/shi_xiu_wounded_20261005/walk_a_matched_nw2_v4.png'
    b=ROOT/f'assets/characters/shi_xiu_wounded_20261005/step_b_body2_{d}_v4.png'
    for state,target in [('passing_a',a),('passing_b',b),('idle_single',b)]:
        assert target.is_file()
        common=f'Edit this exact single whole-body Shi Xiu sprite, full native square canvas. Preserve this same adult face, head/body ratio, shoulder/chest build, upright naturally resolute posture, grey headband/hair, grey torn short tunic, simple brown waist sash, cloth weave detail, pale trousers, brown leg wraps/boots, camera, lighting, material density and scale. Preserve the entire {facing} facing: head, torso, hips, knees and boots all belong to this view; back views remain actual back views. No weapon, injury props, kneeling, hunch or modern parade pose. True transparent RGBA, one complete figure, full headband tails/hands/boots inside canvas with at least 70 transparent pixels at all edges. No text, grid, shadow, background or extra figure. '
        if state.startswith('passing'):
            change='Create the natural PASSING moment immediately AFTER this reference contact stride in a short ordinary walking cycle. The same currently FLAT PLANTED support boot keeps supporting weight, but bring that support leg naturally under its hip rather than far ahead. The other currently raised/rear SWING leg moves forward under the pelvis past the support leg, knee mildly bent, heel/boot clear of ground and toe relaxed. Legs are close together at the passing moment, not a wide stride or crossed/twisted shins. Support boot stays flat; swing boot remains visibly lifted and does not become a second planted foot. Keep the anatomical support leg of the source: do NOT swap left/right support, do NOT merely copy the original stride unchanged, and do NOT replace with a stationary two-feet-grounded idle. Subtle natural arm counter-swing only, empty hands. This is one moving passing phase, not new contact stride or running lunge. '
        else:
            change='Change ONLY the ordinary IDLE pose: both boots flat grounded at relaxed natural stance width, knees softly extended, pelvis balanced, head level, shoulders open relaxed, empty hands lowered naturally beside thighs. Keep exactly the same upper-body size and cloth material detail as this single full-canvas walking reference. Do not keep lifted/rear swing foot, do not crouch or parade stiffly. '
        args={'transparent_background':True,'referenced_image_paths':[target.as_posix()],'prompt':common+change}
        out=HERE/'requests'/f'shi_xiu_{state}_{d}_v4.json'
        assert not out.exists(),'Preserve exact requests; use a versioned successor.'
        out.write_text(json.dumps(args,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'requests':12,'scope':'8 actual passing phases and 4 full-canvas idle candidates; not generation or quality completion'}))
