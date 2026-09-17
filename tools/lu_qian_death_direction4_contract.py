from __future__ import annotations
import argparse,hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]; DIRECTIONS=('se','sw','ne','nw'); FRAMES=('fall_a','fall_b','fall_c','fall_d')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def chk(xs,n,ok,d=None):
 x={'name':n,'passed':bool(ok)}
 if d is not None:x['detail']=d
 xs.append(x)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();xs=[];mp=ROOT/'assets/direction4/lu_qian_death_20260916.json';data=json.loads(mp.read_text(encoding='utf-8'));chk(xs,'manifest schema',data.get('schema')=='native_direction4_spriteframes_v1');chk(xs,'character identity',data.get('character')=='lu_qian');chk(xs,'death state',data.get('states',{}).get('death')==list(FRAMES));src=data['sources']['lu_qian_death_atlas'];prod=ROOT/src['path'];raw=ROOT/src['raw_web_source'];chk(xs,'production exists',prod.is_file(),str(prod));chk(xs,'raw exists',raw.is_file(),str(raw))
 if prod.is_file() and raw.is_file():
  im=Image.open(prod).convert('RGBA');ri=Image.open(raw).convert('RGBA');al=im.getchannel('A');chk(xs,'production SHA',sha(prod)==src['sha256'],sha(prod));chk(xs,'raw SHA',sha(raw)==src['raw_web_source_sha256'],sha(raw));chk(xs,'production RGBA 2508',im.size==(2508,2508),list(im.size));chk(xs,'raw RGBA 1254',ri.size==(1254,1254),list(ri.size));chk(xs,'alpha range',al.getextrema()==(0,255),list(al.getextrema()));chk(xs,'zero fraction',abs(al.histogram()[0]/(im.width*im.height)-src['alpha_zero_fraction'])<1e-12,al.histogram()[0]/(im.width*im.height));chk(xs,'exact 2x scale',im.tobytes()==ri.resize((2508,2508),Image.Resampling.LANCZOS).tobytes())
  for r,d in enumerate(DIRECTIONS):
   hs=[]
   for c,f in enumerate(FRAMES):
    crop=al.crop((c*627,r*627,c*627+627,r*627+627));chk(xs,f'{d} {f} visible',crop.getbbox() is not None);hs.append(hashlib.sha256(crop.tobytes()).hexdigest());pose=data['poses'][f'{f}_{d}'];chk(xs,f'{d} {f} region',pose['region']==[c*627,r*627,627,627]);chk(xs,f'{d} {f} square margin',pose['region'][2]+pose['margin'][2]==pose['region'][3]+pose['margin'][3])
   chk(xs,f'{d} death frames distinct',len(set(hs))==4,hs)
 chk(xs,'conversation URL',src['conversation_url']=='https://chatgpt.com/c/6aa954d2-8d40-83e9-abb6-e30963f8ae3c');prompt=ROOT/src['prompt_file'];chk(xs,'prompt SHA',prompt.is_file() and sha(prompt)==src['prompt_sha256'],str(prompt))
 for r,d in enumerate(DIRECTIONS):
  p=ROOT/f'assets/anim/lu_qian_death_{d}.tres';tx=p.read_text(encoding='utf-8') if p.is_file() else '';chk(xs,f'{d} resource exists',p.is_file(),str(p));chk(xs,f'{d} native source',f'path="res://{src["path"]}"' in tx)
  for c,f in enumerate(FRAMES):chk(xs,f'{d} {f} crop',f'region = Rect2({c*627}, {r*627}, 627, 627)' in tx);chk(xs,f'{d} {f} filter clip','filter_clip = true' in tx);chk(xs,f'{d} {f} metadata','metadata/authored_direction4 = true' in tx)
  chk(xs,f'{d} no PNG shadow',not (ROOT/f'assets/anim/lu_qian_death_{d}.png').exists())
 rep={'passed':all(x['passed'] for x in xs),'checks':xs,'manifest':str(mp),'scope':'Lu Qian death-only native web atlas and deterministic production scale; idle/walk/attack/hurt are separate.'};a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(rep,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps({'passed':rep['passed'],'checks':len(xs)},ensure_ascii=False));return 0 if rep['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
