"""Bind two untouched rear opposite-contact sprites; preserve other Ruan poses."""
import argparse,copy,importlib.util,json,math
from pathlib import Path
import build_ruan_xiaoqi_canon_20261016 as prior
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'assets/direction4/ordinary_ruan_xiaoqi_gait_20261016.json'
FAMILY='character_traits_v2_ruan_xiaoqi_gait_20261016'
def rendered(manifest):
 spec=importlib.util.spec_from_file_location('ruan_gait_frames',ROOT/'tools/build_directional_spriteframes.py');builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
 recipe=copy.deepcopy(manifest);recipe['character']=FAMILY;recipe['states']={'walk':manifest['states']['walk']}
 recipe['resources']=[f'assets/anim/{FAMILY}_walk_{d}.tres' for d in prior.DIRS]
 return builder.render(recipe)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prepare',action='store_true');args=p.parse_args()
 if args.prepare:
  assert not MANIFEST.exists()
  m=json.loads(prior.MANIFEST.read_text(encoding='utf-8'));m['character']=FAMILY
  m['base_manifest']=prior.MANIFEST.relative_to(ROOT).as_posix();m['base_manifest_sha256']=prior.sha(prior.MANIFEST)
  for d in ['ne','nw']:
   key='contact_b_'+d+'_v4';path=ROOT/'assets/characters/ruan_xiaoqi_gait_20261016'/(key+'.png')
   source=ROOT/'assets/characters/ruan_xiaoqi_gait_sources_20261016'/(key+'.png')
   assert prior.sha(path)==prior.sha(source)
   prior.shared.import_descriptor(path)
   g=prior.geometry(path,True);cell=g['cells']['nw'];g['cells']={d:cell}
   m['sources'][key]={'path':path.relative_to(ROOT).as_posix(),'candidate_origin':source.relative_to(ROOT).as_posix(),'sha256':prior.sha(path),'native_size':g['size'],'imported_size':g['size'],'geometry':g,'import_dimensions_verified':False}
   x,y,w,h=cell['region'];px,py=cell['measured_pivot'];intended=math.ceil((py-cell['strong_bounds'][1])/.74)
   canvas=math.ceil(max(intended,2*px,2*(w-px),py/.82,(h-py)/.18));left=canvas*.5-px;top=canvas*.82-py
   assert min(left,top,canvas-w,canvas-h)>=0
   m['poses']['walk_contact_b_'+d]={'source':key,'region':[x,y,w,h],'margin':[left,top,canvas-w,canvas-h],'draw_offset_px':[0,0],'draw_scale':canvas/intended,'virtual_canvas_reference':intended,'pivot_native':[px,py],'operations':'Untouched native PNG; Godot sampling, transparent virtual margin and uniform scale only.'}
  m['resources']=[n for n in m['resources'] if '_walk_' not in n]+[f'assets/anim/{FAMILY}_walk_{d}.tres' for d in prior.DIRS]
  m['production_qualified']=False;m['native_dimensions_verified']=False
  m['scope']='Rear NE/NW opposite-contact B now exchanges leg depth and corrects far foot direction. Other poses and 120-chapter canon unchanged. Adoption requires separate actual evidence.'
  MANIFEST.write_bytes((json.dumps(m,ensure_ascii=False,indent=2)+'\n').encode())
  for n,t in rendered(m).items():
   dest=ROOT/n;assert not dest.exists();dest.write_bytes(t.encode())
 else:
  m=json.loads(MANIFEST.read_text(encoding='utf-8'))
  assert prior.sha(ROOT/m['base_manifest'])==m['base_manifest_sha256']
  for n,t in rendered(m).items():assert (ROOT/n).read_bytes()==t.encode()
  for row in m['sources'].values():assert prior.sha(ROOT/row['path'])==row['sha256']==prior.sha(ROOT/row['candidate_origin'])
 print(json.dumps({'walk_resources':4,'replaced_poses':['walk_contact_b_ne','walk_contact_b_nw'],'native_body_textures':len(m['sources'])+1,'png_pixels_edited':False,'native_qualified':False}))
if __name__=='__main__':main()
