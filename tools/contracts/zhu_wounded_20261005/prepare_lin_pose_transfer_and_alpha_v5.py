"""Preserve further native failures; transform the pose target without pixel edits."""
from pathlib import Path
import json,hashlib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):assert not p.exists();p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
fail=[]
for state,why in [('walk_b_sw3','Still leftmost planted/rightmost raised instead of required opposite SW contact.'),('walk_b_nw2','Contact/facing is suitable, but gray/color halo behind figure is not a clean transparent cutout.')]:
 p=ROOT/f'assets/characters/lin_chong_traits_20261006/{state}_v5.png';fail.append({'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p),'reason':why})
write(ROOT/'qa/zhu_wounded_20261005/lin_contact_third_rejections_v5.json',{'scope':'Direct static native inspection','rejected':fail,'production_qualified':False})
write(HERE/'requests/lin_chong_walk_b_sw4_v5.json',{'transparent_background':True,'referenced_image_paths':[
 str(ROOT/'assets/characters/wu_song_traits_20261006/walk_b_sw3_v5.png'),str(ROOT/'assets/characters/lin_chong_traits_20261006/idle_spacing2_v4.png')],
 'prompt':('Transform the SINGLE warrior in IMAGE1 into Lin Chong from IMAGE2 TOP-RIGHT. IMAGE1 is the '
  'EDIT TARGET for pose: lock its exact camera facing DOWN-LEFT and skeleton/hip/knee/ankle/boot positions. '
  'The rightmost boot is flat and down at lower-right; leftmost boot is bent back and LOW raised at '
  'upper-left. Preserve this exact opposing support arrangement and torso/head posture. Do NOT use '
  'the standing leg positions of IMAGE2. Replace only appearance: remove Wu Song’s headcloth, beads, '
  'charcoal clothes and twin dao. Make the exact mature short-bearded Lin Chong with tied black hair '
  'and gold clasp, blue scarf/patterned robe, steel-black lamellar armor with gold trim/red waist belt, '
  'armored shins/boots. Replace dao with exactly ONE low diagonal wooden spear/steel point/red tassel '
  'held like IMAGE2 TOP-RIGHT, other hand relaxed. Preserve target leg positions while covering them '
  'with Lin armor. Calm upright disciplined adult, healthy upper back/head/chest and normal long legs; '
  'not hunched/deep-squat or parade-stiff. Keep boot centers in target locations: rightmost boot near '
  '(820,1110) flat; leftmost boot near(550,960) raised, proportional to1254square. Single complete man '
  'and spear, full tip/shaft/tassel/hair/boots contained,80px+ clear margins. Native genuinely transparent '
  'RGBA squarePNG<=1536. No floor/shadow/halo/background/grid/text. Pose must remain IMAGE1 exactly; '
  'only identity, costume and weapon become Lin Chong.')})
write(HERE/'requests/lin_chong_walk_b_nw3_v5.json',{'transparent_background':True,'referenced_image_paths':[
 str(ROOT/'assets/characters/lin_chong_traits_20261006/walk_b_nw2_v5.png')],
 'prompt':('Background extraction ONLY. Remove the entire gray/beige/color misty oval/halo behind this '
  'Lin Chong and set all background around his silhouette to genuine fully transparent alpha. '
  'Preserve the exact complete character pixels/appearance, BACK-LEFT facing upper-left, adult '
  'upright body, face/hair/gold clasp, blue scarf/robe, gold-edged armor, rightmost flat planted boot '
  'and leftmost raised boot, hand/grip and complete single wooden spear/steel point/red tassel. '
  'Do not change pose, proportions, clothing, weapon length, direction or placement. No crop/scale '
  'or added shadow. Full clean cutout on native transparent RGBA squarePNG<=1536,80px+ clear margins. '
  'No replacement background, halo/glow, floor/grid/text. Only remove the accidental background oval.')})
print(json.dumps({'rejected':2,'correction_requests':2,'submitted':False}))
