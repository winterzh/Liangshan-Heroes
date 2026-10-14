"""Read literal scoped calibration records and verify their declared source PNGs."""
import hashlib,json,re
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def table(text,name):
    match=re.search(r'const '+name+r'[^=]*=\s*\{',text);assert match
    start=match.end()-1;depth=0;quoted=False;escaped=False;end=None
    for i,char in enumerate(text[start:],start):
        if quoted:
            if escaped:escaped=False
            elif char=='\\':escaped=True
            elif char=='"':quoted=False
        elif char=='"':quoted=True
        elif char=='{':depth+=1
        elif char=='}':
            depth-=1
            if depth==0:end=i+1;break
    raw='\n'.join(line for line in text[start:end].splitlines() if not line.lstrip().startswith('#'))
    return json.loads(re.sub(r',\s*([}\]])',r'\1',raw))
def inputs():
    text=(ROOT/'scripts/campaign_environment_art.gd').read_text(encoding='utf-8')
    calibrated=table(text,'VISUAL_CALIBRATIONS')
    texts=table(text,'TEXT_RECT_SOURCE_SHA256')
    rects=table(text,'TEXT_RECTS')
    routes={'object':table(text,'OBJECT_ROUTES'),'static_flag':table(text,'STATIC_FLAG_ROUTES')}
    rows=[]
    for resolver,records in calibrated.items():
        for key,record in records.items():
            route=routes[resolver][key];assert record['level_id'] in route['levels']
            path=route['paths']['default'].removeprefix('res://');file=ROOT/path
            assert hashlib.sha256(file.read_bytes()).hexdigest()==record['source_sha256']
            image=Image.open(file);assert image.mode=='RGBA'
            row=dict(key=key,resolver=resolver,level_id=record['level_id'],path=path,sha256=record['source_sha256'],size=list(image.size),visible_bbox_xywh=record['visible_bbox_xywh'],decoded_pixel_sha256=hashlib.sha256(image.tobytes()).hexdigest())
            surfaces=[surface for surface,digest in texts.items() if digest==record['source_sha256'] and rects[surface] is not None]
            assert len(surfaces)<=1
            if surfaces:row.update(text_surface=surfaces[0],text_rect=rects[surfaces[0]])
            rows.append(row)
    assert len({r['path'] for r in rows})==len(rows)
    return rows
if __name__=='__main__':
    rows=inputs();print(json.dumps({'calibrated_PNGs':len(rows),'sizes':sorted({tuple(r['size']) for r in rows}),'routes':[r['key'] for r in rows]},ensure_ascii=False))
