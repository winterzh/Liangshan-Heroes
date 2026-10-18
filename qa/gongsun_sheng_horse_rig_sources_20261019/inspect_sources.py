from pathlib import Path
import hashlib,json
from PIL import Image
Q=Path(__file__).resolve().parent;rows=[]
for p in sorted((Q/'native_originals').glob('*.png')):
    im=Image.open(p);assert im.size==(1254,1254) and im.mode=='RGBA'
    a=im.getchannel('A');visible=a.point(lambda v:255 if v>8 else 0);views={}
    for name,x,y in [('se',0,0),('sw',627,0),('ne',0,627),('nw',627,627)]:
        region=visible.crop((x,y,x+627,y+627));bbox=region.getbbox();assert bbox
        views[name]={'visible_bbox_local_alpha_gt8':bbox,'visible_touches_cell_edge':bbox[0]==0 or bbox[1]==0 or bbox[2]==627 or bbox[3]==627,'raw_selected_corner_alpha':[im.getpixel(t)[3] for t in [(x,y),(x+626,y),(x,y+626),(x+626,y+626)]]}
    rows.append({'file':p.relative_to(Q).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'rgba8_sha256':hashlib.sha256(im.tobytes()).hexdigest(),'views':views})
out=Q/'source_inspection_v1.json';assert not out.exists();out.write_text(json.dumps({'scope':'Read-only original PNG alpha/bounds; no pixel edits, anatomical/assembly/native qualification or automatic bbox fitting.','sources':rows},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({Path(x['file']).stem:{k:v['visible_bbox_local_alpha_gt8'] for k,v in x['views'].items()} for x in rows}))
