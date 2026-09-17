from __future__ import annotations
import argparse,hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def sha(p:Path)->str:return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--manifest',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();m=json.loads(a.manifest.read_text(encoding='utf-8')); checks=[]
 def c(n,ok,d=None):checks.append({'name':n,'passed':bool(ok),'detail':d})
 src=ROOT/'assets/campaign/environment/art_scene_20260916/liangshan_trees_source_20260916.png'; c('source_present',src.is_file()); c('source_sha',src.is_file() and sha(src)==m['source_sha256'])
 if src.is_file():
  im=Image.open(src).convert('RGBA'); c('source_size',im.size==tuple(m['source_size'])); c('source_alpha',im.getchannel('A').getextrema()==(0,255))
 prompt=ROOT/m['prompt_path']; c('prompt_present',prompt.is_file()); c('prompt_sha',prompt.is_file() and sha(prompt)==m['prompt_sha256'])
 for t in m['targets']:
  p=ROOT/t['runtime_path']; ok=p.is_file(); c(t['key']+'_present',ok)
  if ok:
   im=Image.open(p).convert('RGBA'); c(t['key']+'_rgba_512',im.size==(512,512)); c(t['key']+'_alpha',im.getchannel('A').getextrema()==(0,255)); c(t['key']+'_sha',sha(p)==t['runtime_sha256']); c(t['key']+'_bbox',list(im.getchannel('A').getbbox())==t['runtime_alpha_bbox'])
 report={'schema':'liangshan_trees_scene_contract_v1','passed':all(x['passed'] for x in checks),'checks':checks,'source_sha256':m['source_sha256'],'prompt_sha256':m['prompt_sha256'],'targets':len(m['targets'])}; a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps({'passed':report['passed'],'checks':len(checks)},ensure_ascii=False));raise SystemExit(0 if report['passed'] else 1)
if __name__=='__main__':main()
