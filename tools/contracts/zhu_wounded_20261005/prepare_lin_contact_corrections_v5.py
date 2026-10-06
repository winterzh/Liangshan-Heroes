"""Record incorrect Lin contact legs and prepare precise native lower-leg edits."""
from pathlib import Path
import json,hashlib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):assert not p.exists();p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
failed=[]
for state,reason in [('walk_b_sw','Image-left planted/image-right raised repeats SW A; intended B requires image-right planted.'),('walk_a_ne','Image-right planted/image-left raised repeats NE B; intended A requires image-left planted.')]:
 p=ROOT/f'assets/characters/lin_chong_traits_20261006/{state}_v5.png';failed.append({'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p),'reason':reason})
write(ROOT/'qa/zhu_wounded_20261005/lin_contact_rejections_v5.json',{'scope':'Direct static native image inspection','rejected':failed,'production_qualified':False})
for state,original,guide,support,swing,heading in [
 ('walk_b_sw2','walk_a_sw','walk_b_sw','RIGHT','LEFT','SW FRONT-LEFT, facing DOWN-LEFT; nose/face on image-left'),
 ('walk_a_ne2','walk_b_ne','walk_a_ne','LEFT','RIGHT','NE BACK-RIGHT, facing AWAY-UPPER-RIGHT; small face profile at image-right')]:
 prompt=(f'Edit ONLY the two lower-leg roles of Lin Chong in IMAGE1. Preserve his exact {heading} camera '
  'and upright mature body, head/hair, gold hair clasp, blue scarf/robe, gold-edged steel armor, waist, '
  'arms/hands and single low diagonal wooden spear/steel point/red tassel, no weapon or camera change. '
  f'The current IMAGE-{swing} boot supports while IMAGE-{support} boot is raised. This must SWITCH: '
  f'IMAGE-{support} leg now extends down and slightly forward to a FLAT PLANTED boot at the lowest '
  f'contact level, heel AND toe down. IMAGE-{swing} leg now bends softly back with a LOW raised boot. '
  'Each leg stays on its own anatomical side and attaches to its own hip, never crosses. '
  f'IMAGE2 is mandatory geometry only: RED IMAGE-{support} flat support, BLUE IMAGE-{swing} low '
  'recovery. Copy only that leg assignment, not robot, colors, ground or labels. Do not repeat the '
  'original planted leg. Adjust lower robe drape only as needed for the switched step, preserve '
  'everything else, normal adult long legs, restrained short walking contact, no deep squat/hunch '
  'or high knee/run/attack. Exactly one complete Lin Chong/spear, no extra limbs or accessories. '
  'Native genuinely transparent RGBA squarePNG<=1536, full head/boots/shaft/tip/tassel contained '
  'with80px+ clear margins; no shadow/background/floor/grid/text.')
 write(HERE/f'requests/lin_chong_{state}_v5.json',{'prompt':prompt,'transparent_background':True,'referenced_image_paths':[
  str(ROOT/f'assets/characters/lin_chong_traits_20261006/{original}_v5.png'),str(HERE/f'guides/qin_ming_{guide}_geometry_v4.png')]})
print(json.dumps({'rejected':2,'corrective_requests':2,'submitted':False}))
