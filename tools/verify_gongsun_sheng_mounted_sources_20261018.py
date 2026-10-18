"""Read-only provenance/PNG hygiene audit, never animation or novel acceptance."""
from pathlib import Path
import argparse,hashlib,json
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
MANIFEST='assets/characters/gongsun_sheng_mounted_sources_20261018/prompt_set.json'

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path);args=parser.parse_args()
    manifest=json.loads((ROOT/MANIFEST).read_text(encoding='utf-8'))
    checks=[];observations=[]
    def check(ok,label):checks.append({'label':label,'passed':bool(ok)})
    def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
    check(len(manifest['sources'])==11,'eleven retained original PNG drafts')
    check(len(manifest['candidate_keys'])==5,'five unbound idle/walk candidates only')
    for row in manifest['sources']:
        source=ROOT/row['path'];key=row['key']
        check(source.is_file(),'source exists '+key)
        if not source.is_file():continue
        check(sha(source)==row['sha256'],'original bytes match '+key)
        check(not row['runtime_adopted'],'source is not production mounted art '+key)
        with Image.open(source) as image:
            image.load();check(image.size==(1254,1254),'source dimensions '+key)
            check(image.mode=='RGBA','native alpha format '+key)
            alpha=np.asarray(image)[:,:,3]
        boxes=[]
        for direction,x,y in [('se',0,0),('sw',627,0),('ne',0,627),('nw',627,627)]:
            a=alpha[y:y+627,x:x+627];ys,xs=np.where(a>16)
            box=[int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max())]
            margin=int(min(xs.min(),ys.min(),626-xs.max(),626-ys.max()))
            corners=[int(a[0,0]),int(a[0,-1]),int(a[-1,0]),int(a[-1,-1])]
            boxes.append({'direction':direction,'strong_alpha_bounds':box,'min_strong_margin':margin,'corner_alpha':corners})
            if row['status']=='candidate':
                check(margin>=8,'candidate strong-alpha cell separation '+key+' '+direction)
                check(corners==[0,0,0,0],'candidate cell corners transparent '+key+' '+direction)
        observations.append({'key':key,'status':row['status'],'boxes':boxes,'central_vertical_strong_pixels':int((alpha[:,624:631]>16).sum()),'central_horizontal_strong_pixels':int((alpha[624:631,:]>16).sum())})
        for index,ref in enumerate(row['references']):
            path=ROOT/ref['path'];check(path.is_file(),'reference exists '+key+' '+str(index))
            if path.is_file():check(sha(path)==ref['sha256'],'reference exact bytes '+key+' '+str(index))
    failures=[x['label'] for x in checks if not x['passed']]
    report={'passed':not failures,'checks':checks,'failures':failures,'observations':observations,'pngs':len(manifest['sources']),'references':sum(len(x['references']) for x in manifest['sources']),'runtime_adopted':False,'scope':'Read-only original-byte/reference/PNG geometry checks only. Does not approve anatomy, gait timing, sword/sheath topology, chapter binding, skills, actual rendering, game or all art.'}
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'passed':not failures,'checks':len(checks),'failures':failures,'pngs':11,'references':report['references'],'runtime_adopted':False},ensure_ascii=False))
    raise SystemExit(1 if failures else 0)

if __name__=='__main__':main()
