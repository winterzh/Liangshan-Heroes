from pathlib import Path
import hashlib,json,sys
from PIL import Image
Q=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
rows=[]
for p in sorted((Q/'native_originals').glob('*.png')):
    im=Image.open(p);assert im.size==(1254,1254) and im.mode=='RGBA'
    views={}
    for name,x,y in [('se',0,0),('sw',627,0),('ne',0,627),('nw',627,627)]:
        a=im.getchannel('A').crop((x,y,x+627,y+627));bbox=a.point(lambda v:255 if v>8 else 0).getbbox();assert bbox
        v={'visible_bbox_local_alpha_gt8':bbox,'visible_touches_cell_edge':bbox[0]==0 or bbox[1]==0 or bbox[2]==627 or bbox[3]==627}
        if p.stem=='hoof_v1':
            dense=a.point(lambda v:255 if v>128 else 0).getbbox();yy=dense[3]-2
            xs=[xx for xx in range(627) if a.getpixel((xx,yy))>128]
            v['sole_row_diagnostic']={'y':yy,'first':min(xs),'last':max(xs),'scope':'Read-only silhouette sample, not an accepted ground-contact edge or automatic registration.'}
        views[name]=v
    rows.append({'file':p.relative_to(Q).as_posix(),'sha256':sha(p),'rgba8_sha256':hashlib.sha256(im.tobytes()).hexdigest(),'views':views})
out=Q/(sys.argv[1] if len(sys.argv)>1 else 'source_inspection_v2.json')
assert out.parent==Q and out.name.startswith('source_inspection_') and out.suffix=='.json'
with out.open('x',encoding='utf-8') as f:f.write(json.dumps({'scope':'Read-only source alpha and original RGBA, no pixel writes or native/visual acceptance.','sources':rows},ensure_ascii=False,indent=2)+'\n')
print(json.dumps([r for r in rows if Path(r['file']).stem in ['body_no_tail_v1','tail_v1']],ensure_ascii=False))
