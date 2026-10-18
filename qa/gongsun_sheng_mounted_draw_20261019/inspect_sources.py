from pathlib import Path
import hashlib,json
from PIL import Image
Q=Path(__file__).resolve().parent;rows=[]
for p in sorted((Q/'native_originals').glob('*.png')):
    im=Image.open(p);assert im.size==(1254,1254) and im.mode=='RGBA';views={}
    for name,x,y in [('se',0,0),('sw',627,0),('ne',0,627),('nw',627,627)]:
        a=im.getchannel('A').crop((x,y,x+627,y+627));bbox=a.point(lambda v:255 if v>8 else 0).getbbox();assert bbox
        views[name]={'visible_bbox':bbox,'touches_cell_edge':bbox[0]==0 or bbox[1]==0 or bbox[2]==627 or bbox[3]==627}
    rows.append({'file':p.relative_to(Q).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'rgba8_sha256':hashlib.sha256(im.tobytes()).hexdigest(),'views':views})
with (Q/'source_inspection.json').open('x',encoding='utf-8') as f:f.write(json.dumps({'scope':'Read-only original PNG/RGBA/bounds; not anatomy, registration or native acceptance.','sources':rows},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'sources':len(rows),'edge_touching':[(r['file'],d) for r in rows for d,v in r['views'].items() if v['touches_cell_edge']]}))
