"""Read-only provenance and explicitly selected view audit; never edits PNGs.

This does not qualify full source atlases, native import/mipmaps, motion or game use.
Unused corner-alpha failures and rejected views stay visible in the report.
"""
import hashlib,json
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'assets/characters/chao_gai_pushcart_sources_20261017/prompt_set.json'
DIRS=('se','sw','ne','nw')
POSES=('push_idle','push_contact_a','push_passing_a','push_contact_b','push_passing_b')
def path(name):
 p=Path(name)
 assert not p.is_absolute() and '..' not in p.parts and '\\' not in name
 target=(ROOT/p).resolve();assert target.is_relative_to(ROOT) and target.is_file()
 assert not (ROOT/p).is_symlink()
 return target
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def verify():
 m=json.loads(MANIFEST.read_text(encoding='utf-8'));rows=m['sources'];by_key={r['key']:r for r in rows}
 assert len(rows)==len(by_key)==12 and len(m['selected_candidates'])==7
 assert m['mode']=='builtin_imagegen' and not m['pixel_writes'] and not m['runtime_adopted']
 assert (MANIFEST.parent/'.gdignore').is_file()
 assert set(m['view_bindings'])==set(POSES)
 checks=[];alpha_failures=[];references=0;images={}
 def check(ok,label):
  checks.append({'name':label,'passed':bool(ok)})
  assert ok,label
 for row in rows:
  p=path(row['path']);check(sha(p)==row['sha256'] and p.stat().st_size==row['bytes'],'original bytes '+row['key'])
  check(bool(row['prompt']) and bool(row['references']),'complete generation request '+row['key'])
  for ref in row['references']:
   check(sha(path(ref['repository_path']))==ref['sha256'],'reference '+row['key']+' '+ref['repository_path']);references+=1
  with Image.open(p) as image:
   check(image.mode=='RGBA' and list(image.size)==row['geometry']['size'],'native RGBA dimensions '+row['key']);alpha=np.asarray(image)[:,:,3].copy()
  images[row['key']]=alpha;h,w=alpha.shape
  corners=alpha[[0,0,-1,-1],[0,-1,0,-1]].tolist();check(corners==row['geometry']['corner_alpha'],'whole-image alpha record '+row['key'])
  if any(corners):alpha_failures.append({'key':row['key'],'corners':corners,'selected_directions':row['selected_directions']})
 selected=set();views=[]
 for pose in POSES:
  bindings=m['view_bindings'][pose];check(set(bindings)==set(DIRS),'four explicit directions '+pose)
  for d in DIRS:
   key=bindings[d];selected.add(key);row=by_key[key];a=images[key];h,w=a.shape
   x,y,cw,ch=row['geometry']['cells'][d]['region'];sx,sy=row['geometry']['split']
   check(min(x,y)>=0 and min(cw,ch)>0 and x+cw<=w and y+ch<=h,'view bounds '+pose+d)
   check(not np.any(a[:,sx]>=16) and not np.any(a[sy,:]>=16),'separated atlas axes '+pose+d)
   corners=a[[y,y,y+ch-1,y+ch-1],[x,x+cw-1,x,x+cw-1]].tolist()
   check(corners==[0,0,0,0] and corners==row['geometry']['cells'][d]['corner_alpha'],'selected-view zero corners '+pose+d)
   check(row['selected_candidate'] and d in row['selected_directions'],'explicit selected-view authority '+pose+d)
   check(m['manual_view_review'][pose][d]['seen'] and m['manual_view_review'][pose][d]['source']==key,'manual source view review '+pose+d)
   views.append({'pose':pose,'direction':d,'source':key,'region':[x,y,cw,ch],'corner_alpha':corners})
 check(selected==set(m['selected_candidates']),'selected source inventory')
 return {'passed':True,'checks':checks,'sources':len(rows),'references':references,'selected_source_pngs':len(selected),'selected_views':views,
  'whole_source_corner_alpha_failures_retained':alpha_failures,'full_selected_atlases_zero_corner_alpha_passed':not any(r['key'] in selected for r in alpha_failures),
  'scope':'Only original-byte provenance, original references, explicit selected view bounds/corner transparency and recorded manual source review. Passing-B view selection does not qualify unused views or full PNG alpha, native mipmaps, motion continuity or production integration.',
  'pixel_writes':False,'runtime_adopted':False,'native_launched':False}
if __name__=='__main__':
 result=verify();print(json.dumps({k:v for k,v in result.items() if k not in ['checks','selected_views']},ensure_ascii=False))
