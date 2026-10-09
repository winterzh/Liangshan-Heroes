"""Native human lower-leg references supplement math diagrams; no borrowed identity."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):assert not p.exists();p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
fail=[]
for state,why in [('walk_b_sw2','Still image-left planted; required image-right planted B not authored.'),('walk_a_ne2','Still image-right planted; required image-left planted A not authored.'),('walk_b_nw','Repeats NW A image-left support; required image-right B not authored.')]:
 p=ROOT/f'assets/characters/lin_chong_traits_20261006/{state}_v5.png';fail.append({'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p),'reason':why})
write(ROOT/'qa/zhu_wounded_20261005/lin_contact_second_rejections_v5.json',{'scope':'Direct static native inspection; no motion acceptance','rejected':fail,'production_qualified':False})
parent=HERE/'save_ordinary_walk_native_v5.py';text=parent.read_text(encoding='utf-8')
anchor="    elif p.parent.name=='guides':"
replacement="""    elif p.parent.name=='wu_song_traits_20261006' and key=='lin_chong':
        jp=HERE/'jobs'/f'wu_song_{p.stem}.json'
        jr=json.loads(jp.read_text(encoding='utf-8'))
        assert jr['output']==rel and jr['output_sha256']==sha(p)
        row.update(reference_role='Human leg geometry/camera ONLY; no identity, clothes or weapons inherited',parent_job=jp.relative_to(ROOT).as_posix(),parent_job_sha256=sha(jp))
    elif p.parent.name=='guides':"""
assert anchor in text;text=text.replace(anchor,replacement)
dest=HERE/'save_lin_human_pose_native_v5.py';assert not dest.exists();compile(text,str(dest),'exec');dest.write_bytes(text.encode('utf-8'))
headings={'se':('TOP-LEFT','FRONT-RIGHT DOWN-RIGHT','RIGHT'),'sw':('TOP-RIGHT','FRONT-LEFT DOWN-LEFT','LEFT'),
          'ne':('BOTTOM-LEFT','BACK-RIGHT AWAY-UPPER-RIGHT','LEFT'),'nw':('BOTTOM-RIGHT','BACK-LEFT AWAY-UPPER-LEFT','LEFT')}
states=[('walk_b_sw3','walk_b_sw','walk_b_sw3'),('walk_a_ne3','walk_a_ne','walk_a_ne'),('walk_b_nw2','walk_b_nw','walk_b_nw2')]
states += [(f'{s}_{d}2',f'{s}_{d}',f'{s}_{d}') for s in ['passing_a','passing_b'] for d in ['se','sw','ne','nw']]
for name,pose,human_name in states:
 state,direction=pose.rsplit('_',1);quadrant,camera,side_a=headings[direction]
 support=side_a if state.endswith('_a') else ('LEFT' if side_a=='RIGHT' else 'RIGHT');swing='LEFT' if support=='RIGHT' else 'RIGHT';passing=state.startswith('passing')
 human=ROOT/f'assets/characters/wu_song_traits_20261006/{human_name}_v5.png'
 guide=HERE/'guides'/f"{'wang_ying' if passing else 'qin_ming'}_{pose}_geometry_v{'7' if passing else '4'}.png"
 assert human.is_file() and guide.is_file()
 prompt=(f'Create ONE Lin Chong {state.upper()} sprite facing {camera}. IMAGE1 is ONLY a real-human '
  f'LEG POSE/camera reference, showing IMAGE-{support} boot flat planted support and IMAGE-{swing} '
  'boot modestly raised. Reproduce its exact lower-leg arrangement in Lin Chong’s armored legs/boots. '
  'Do NOT inherit IMAGE1 face, headcloth, beads, charcoal robes, twin dao, broad Wu Song body or identity. '
  f'IMAGE2 {quadrant} figure is the SOLE Lin Chong identity/style: same tall mature military instructor, '
  'healthy upright upper back/head/chest, short beard, tied long black hair/gold clasp, blue scarf and '
  'patterned blue robe, steel-black lamellar armor/gold edges, red waist belt, armored shins and boots. '
  'Preserve those panels/materials and exact ONE wooden spear with steel point/red tassel in the SAME '
  'hand and LOW DIAGONAL carry of that selected figure, other hand relaxed. No dao/beads/other weapons. '
  f'IMAGE3 is only math verification: RED IMAGE-{support} flat support heel+forefoot, BLUE IMAGE-{swing} '
  'raised recovery, no robot/proportions/colors/green floor/text. Each leg attaches to own hip without crossing. ')
 if passing:prompt+='Feet narrow beneath pelvis, raised foot passes close beside support leg, mild knee and small ground gap, not a wide contact stride or two-flat idle. '
 else:prompt+='Compact ordinary contact step: support reaches modestly forward and down, opposite boot softly bends back LOW, not wide lunge or two-flat idle. '
 if direction in ['ne','nw']:prompt+='True BACK three-quarter, back of armor/hair visible, small face profile only; no frontal chest/both eyes. '
 prompt+=('Head/torso/pelvis/boot toes all follow specified heading and image1 camera. Natural adult long '
  'legs, stable upright torso with mild hip transfer; no hunch/deep squat, child/chibi or rigid parade, '
  'high kick/run/attack. Keep spear angle/length/grip and blue robe consistent with image2. Exactly one '
  'complete man/spear, full silhouette including tip/shaft/tassel/boots on native transparent RGBA '
  'squarePNG<=1536,80px+ clear margins. No floor/shadow/background/grid/text/extra people. New Lin '
  'Chong lower-leg phase; never return another copy of the same wrong support leg.')
 write(HERE/f'requests/lin_chong_{name}_v5.json',{'prompt':prompt,'referenced_image_paths':[str(human),str(ROOT/'assets/characters/lin_chong_traits_20261006/idle_spacing2_v4.png'),str(guide)],'transparent_background':True})
print(json.dumps({'new_requests':len(states),'failed_originals_preserved':3,'new_save_helper':dest.name,'parent_sha256':sha(parent)}))
