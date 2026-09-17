"""Validate byte provenance and scoped native atlas resources without editing images."""
import argparse, hashlib, json, re
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 manifest=json.loads((ROOT/'tools/contracts/art_full_20260915/environment.json').read_text(encoding='utf-8'))
 checks=[]
 def check(ok,label):checks.append({'name':label,'passed':bool(ok)})
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 sources={}
 for r in manifest['sources']:
  p=ROOT/r['path'];im=Image.open(p);sources[r['path']]=im
  check(sha(p)==r['sha256'],r['path']+' exact original SHA')
  check(im.mode=='RGBA' and list(im.size)==r['size'],r['path']+' native RGBA size')
  alpha=im.getchannel('A');check(alpha.getextrema()==(0,255),r['path']+' genuine alpha range')
  check(abs(alpha.histogram()[0]/(im.width*im.height)-r['alpha_zero_fraction'])<1e-12,r['path']+' transparent fraction')
 for r in manifest['resources']:
  p=ROOT/r['resource'];s=p.read_text(encoding='utf-8');im=sources[r['source']];x,y,w,h=r['region'];mx,my,mw,mh=r['margin']
  check(sha(p)==r['sha256'],r['resource']+' resource SHA')
  check('path="res://'+r['source']+'"' in s and 'type="AtlasTexture"' in s,r['resource']+' native source reference')
  check(0<=x and 0<=y and x+w<=im.width and y+h<=im.height and min(w,h)>0,r['resource']+' valid crop region')
  check(min(mx,my,mw,mh)>=-1e-9 and mx+w<=w+mw+1e-6 and my+h<=h+mh+1e-6,r['resource']+' virtual margin contains whole region')
  check(not (ROOT/r['registered_png_path']).exists(),r['resource']+' no PNG shadowing')
  if r['resolver']=='object':check(abs((my+r['alpha_bbox_in_region'][3])/(h+mh)-.82)<1e-6,r['resource']+' painted base .82')
 report={'passed':all(c['passed'] for c in checks),'checks':checks,'sources':len(sources),'resources':len(manifest['resources']),'scope':'Byte, native alpha, region and anchor contracts; visual quality requires engine screenshots.'}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps({k:v for k,v in report.items() if k!='checks'},ensure_ascii=False))
 if not report['passed']:raise SystemExit(1)
if __name__=='__main__':main()
