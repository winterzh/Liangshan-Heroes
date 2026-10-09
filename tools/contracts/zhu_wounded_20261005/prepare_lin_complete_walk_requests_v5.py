"""Exact geometry-first requests for ordinary Lin Chong's remaining gait phases."""
from pathlib import Path
import json
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[2]
identity=ROOT/'assets/characters/lin_chong_traits_20261006/idle_spacing2_v4.png'
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
  support=side_a if state.endswith('_a') else ('LEFT' if side_a=='RIGHT' else 'RIGHT')
  swing='LEFT' if support=='RIGHT' else 'RIGHT';passing=state.startswith('passing')
  guide=HERE/'guides'/f"{'wang_ying' if passing else 'qin_ming'}_{state}_{direction}_geometry_v{'7' if passing else '4'}.png"
  assert guide.is_file() and identity.is_file()
  prompt=(f'Use case: historical-scene. SINGLE full-body ordinary Lin Chong {state.upper()} sprite. '
   f'IMAGE1 is ONLY mandatory mathematical leg pose and camera: RED IMAGE-{support} leg/boot is '
   f'flat support, heel AND forefoot down at one contact level; BLUE IMAGE-{swing} boot is low raised '
   'recovery. Match that exact support assignment. Never copy robot box torso/anatomy, colored legs, '
   f'green floor or text. IMAGE2 supplies ONLY identity/clothes/weapon/adult proportions/style: its {quadrant} '
   f'{direction.upper()} man is the exact Lin Chong. Same tall mature disciplined instructor, healthy upright '
   'upper back, head lifted, natural broad shoulders/chest and long adult legs, calm resolute short-bearded '
   'face where visible, long tied black hair/gold hair clasp, blue scarf/blue patterned robe, steel-black '
   'lamellar armor with gold edges, red waist belt, armored shin guards/boots. Preserve armor panels, '
   'robe length, material colors and the exact SINGLE wooden-shaft spear, steel point/red tassel. '
   'Spear stays in the same hand and LOW DIAGONAL carry of the chosen identity figure, other hand relaxed; '
   'do not raise/reverse spear, shorten its shaft, add blade/weapon or change grip. Small natural arm balance. '
   f'CAMERA: elevated isometric RTS, {camera}. Head, torso, pelvis and both boot toes keep the SAME heading. ')
  if direction in ['ne','nw']:
   prompt+='Back of hair/shoulders/armor is visible; only small far-side facial profile, no frontal chest or both eyes. Spear follows the low diagonal carry of that BACK reference, full tip/shaft contained. '
  else:
   prompt+='Spear point extends low towards IMAGE-LEFT as in the front identity, full shaft behind hand; preserve its angle between idle and walk. '
  if passing:
   prompt+='MANDATORY LOW PASSING: feet close in horizontal stride beneath pelvis. Swing boot travels just beside support leg with mild knee bend, a small visible gap above ground, not a wide contact stride or two-flat idle. No high knee/kick or large exposed sole. '
  else:
   prompt+='MANDATORY CONTACT: a compact ordinary step with support leg modestly forward, opposite boot recovering low behind with soft knee. Neither wide lunge/run/jump nor two-flat idle. '
  prompt+=('Each normal armored leg attaches to own hip; no crossing/disconnected knee. Stable healthy upright chest '
   'and gaze, slight natural hip transfer. No hunch, rounded hump, deep squat, child/chibi proportions, '
   'oversized head/boot or exaggerated parade rigidity. Exactly one complete man/spear, square native RGBA '
   'PNG<=1536, truly transparent alpha, full silhouette centered with80px+ clear margins including spear/tassel '
   'and boots. Body about75-78% square height; no cropping/mirroring, background/shadow/floor/grid/labels '
   'or extra people. Detailed historical game painting matching IMAGE2.')
  dest=HERE/'requests'/f'lin_chong_{state}_{direction}_v5.json';assert not dest.exists()
  dest.write_bytes((json.dumps({'prompt':prompt,'referenced_image_paths':[str(guide),str(identity)],'transparent_background':True},ensure_ascii=False,indent=2)+'\n').encode('utf-8'));created.append(dest.relative_to(ROOT).as_posix())
print(json.dumps({'requests':created,'count':len(created),'submitted':False}))
