from __future__ import annotations
import argparse, hashlib, json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def sha(path:Path)->str:return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser(); ap.add_argument('--manifest',type=Path,required=True); ap.add_argument('--output',type=Path,required=True); a=ap.parse_args()
 m=json.loads(a.manifest.read_text(encoding='utf-8')); checks=[]
 def check(name,ok,detail=None): checks.append({'name':name,'passed':bool(ok), 'detail':detail})
 source=ROOT/'assets/campaign/environment/art_scene_20260916/huangnigang_pines_source_20260916.png'
 check('source_present',source.is_file()); check('source_sha',source.is_file() and sha(source)==m['source_sha256']);
 if source.is_file():
  im=Image.open(source).convert('RGBA'); check('source_dimensions',im.size==tuple(m['source_size'])); check('source_alpha',im.getchannel('A').getextrema()==(0,255))
 prompt=ROOT/m['prompt_path']; check('prompt_present',prompt.is_file()); check('prompt_sha',prompt.is_file() and sha(prompt)==m['prompt_sha256'])
 for t in m['targets']:
  path=ROOT/t['runtime_path']; ok=path.is_file(); check(t['key']+'_present',ok)
  if ok:
   im=Image.open(path).convert('RGBA'); check(t['key']+'_png_rgba_size',im.size==(512,512)); check(t['key']+'_alpha_range',im.getchannel('A').getextrema()==(0,255)); check(t['key']+'_sha',sha(path)==t['runtime_sha256']); check(t['key']+'_alpha_bbox',list(im.getchannel('A').getbbox())==t['runtime_alpha_bbox'])
 report={'schema':'huangnigang_pines_scene_contract_v1','passed':all(c['passed'] for c in checks),'checks':checks,'source_sha256':m['source_sha256'],'prompt_sha256':m['prompt_sha256'],'targets':len(m['targets'])}
 a.output.parent.mkdir(parents=True,exist_ok=True); a.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8'); print(json.dumps({'passed':report['passed'],'checks':len(checks)},ensure_ascii=False)); raise SystemExit(0 if report['passed'] else 1)
if __name__=='__main__':main()
