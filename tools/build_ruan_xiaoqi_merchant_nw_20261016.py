"""Bind an untouched opposite-contact NW merchant sprite; other poses stay exact."""
import argparse,copy,importlib.util,json,math
from pathlib import Path
import build_ruan_xiaoqi_merchant_20261016 as prior
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/direction4/level1_ruan_xiaoqi_merchant_20261016.json'
MANIFEST=ROOT/'assets/direction4/level1_ruan_xiaoqi_merchant_nw_20261016.json'
FAMILY='character_traits_v2_ruan_xiaoqi_merchant_nw_20261016'
def render(m):
 spec=importlib.util.spec_from_file_location('ruan_merchant_nw_frames',ROOT/'tools/build_directional_spriteframes.py');b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
 recipe=copy.deepcopy(m);recipe['character']=FAMILY;recipe['states']={'walk':m['states']['walk']};recipe['resources']=[f'assets/anim/{FAMILY}_walk_{d}.tres' for d in prior.DIRS]
 return b.render(recipe)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prepare',action='store_true');args=p.parse_args()
 if args.prepare:
  assert not MANIFEST.exists();m=json.loads(BASE.read_text(encoding='utf-8'))
  path=ROOT/'assets/characters/ruan_xiaoqi_merchant_nw_20261016/contact_b_nw.png';source=ROOT/'assets/characters/ruan_xiaoqi_merchant_nw_sources_20261016/contact_b_nw_native.png'
  assert prior.sha(path)==prior.sha(source);prior.shared.import_descriptor(path)
  g=prior.geometry(path,True);cell=g['cells']['nw'];x,y,w,h=cell['region'];px,py=cell['measured_pivot']
  intended=math.ceil((py-cell['strong_bounds'][1])/.74);canvas=math.ceil(max(intended,2*px,2*(w-px),py/.82,(h-py)/.18));left=canvas*.5-px;top=canvas*.82-py
  assert min(left,top,canvas-w,canvas-h)>=0
  m['sources']['contact_b_nw']={'path':path.relative_to(ROOT).as_posix(),'candidate_origin':source.relative_to(ROOT).as_posix(),'sha256':prior.sha(path),'native_size':g['size'],'imported_size':g['size'],'geometry':g,'import_dimensions_verified':False}
  m['poses']['walk_contact_b_nw']={'source':'contact_b_nw','region':[x,y,w,h],'margin':[left,top,canvas-w,canvas-h],'draw_offset_px':[0,0],'draw_scale':canvas/intended,'virtual_canvas_reference':intended,'pivot_native':[px,py],'operations':'Untouched native PNG; Godot atlas sample, transparent virtual margin and uniform scale only.'}
  m['resources']=[n for n in m['resources'] if '_walk_' not in n]+[f'assets/anim/{FAMILY}_walk_{d}.tres' for d in prior.DIRS]
  m.update(character=FAMILY,base_manifest=BASE.relative_to(ROOT).as_posix(),base_manifest_sha256=prior.sha(BASE),production_qualified=False,native_dimensions_verified=False)
  m['scope']='Only merchant NW contact B changes. Pose reference ordinary NW lower-leg anatomy; appearance/pu-dao reference canonical chapter16 merchant. Precise gait is conservative game art; original canon unchanged.'
  MANIFEST.write_bytes((json.dumps(m,ensure_ascii=False,indent=2)+'\n').encode())
  for n,t in render(m).items():
   dest=ROOT/n;assert not dest.exists();dest.write_bytes(t.encode())
 else:
  m=json.loads(MANIFEST.read_text(encoding='utf-8'));assert prior.sha(BASE)==m['base_manifest_sha256']
  for n,t in render(m).items():assert (ROOT/n).read_bytes()==t.encode()
  for row in m['sources'].values():assert prior.sha(ROOT/row['path'])==row['sha256']==prior.sha(ROOT/row['candidate_origin'])
 print(json.dumps({'walk_resources':4,'changed_poses':['walk_contact_b_nw'],'merchant_textures':len(m['sources'])+1,'png_pixels_edited':False,'native_qualified':False}))
if __name__=='__main__':main()
