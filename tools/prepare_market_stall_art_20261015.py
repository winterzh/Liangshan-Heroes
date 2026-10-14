"""Fixed six-cell crop of selected native web art; never repaint or remove alpha."""
import argparse,hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/campaign/environment/market_stalls_20261015/native_references/source_v2_selected.png'
QA=ROOT/'qa/market_stall_art_20261015'
KEYS=['inn_a','wine','goods','dice','money','inn_b']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--verify',action='store_true');args=ap.parse_args()
    image=Image.open(SOURCE)
    assert image.mode=='RGBA' and image.size==(1536,1024)
    assert sha(SOURCE)=='b2db28b7a810916c55eb33ce8028947148bcdb4a80074d994c159d7bbd94cc57'
    if args.verify:
        manifest=json.loads((QA/'source_manifest.json').read_text(encoding='utf-8'))
        for row in manifest['variants']:
            x,y,w,h=row['region'];assert w==h==512
            actual=Image.open(ROOT/row['path'])
            assert sha(ROOT/row['path'])==row['sha256'] and actual.tobytes()==image.crop((x,y,x+w,y+h)).tobytes()
        print(json.dumps({'all_six_native_crops_exact':True}));return
    QA.mkdir(exist_ok=False)
    rows=[]
    for i,key in enumerate(KEYS):
        x,y=(i%3)*512,(i//3)*512
        tile=image.crop((x,y,x+512,y+512));alpha=tile.getchannel('A')
        bbox=alpha.point(lambda v:255 if v>=16 else 0).getbbox();assert bbox
        assert min(bbox[:2])>=40 and max(bbox[2:])<=472, 'Visible geometry approaches a grid boundary'
        for border in [(0,0,512,1),(0,511,512,512),(0,0,1,512),(511,0,512,512)]:
            assert alpha.crop(border).getextrema()[1]<=1, 'Visible neighboring tile contamination'
        assert alpha.getextrema()[0]==0 and alpha.getextrema()[1]>=240
        path=ROOT/('assets/campaign/environment/level7/stall_'+key+'.png');assert not path.exists()
        tile.save(path)
        assert Image.open(path).tobytes()==tile.tobytes()
        rows.append({'key':'kuaihuolin_stall_'+key,'kind':key,'path':path.relative_to(ROOT).as_posix(),'sha256':sha(path),
            'region':[x,y,512,512],'visible_bbox_xywh':[bbox[0],bbox[1],bbox[2]-bbox[0],bbox[3]-bbox[1]],
            'foot':bbox[3]/512,'decoded_pixel_sha256':hashlib.sha256(tile.tobytes()).hexdigest(),'alpha_extrema':list(alpha.getextrema())})
    manifest={'source':SOURCE.relative_to(ROOT).as_posix(),'source_sha256':sha(SOURCE),'source_size':[1536,1024],
        'provider':'Web ChatGPT generated image UI','conversation_url':'https://chatgpt.com/c/6acfda54-afcc-83ea-a0c5-4c1932231c1f',
        'operations':['fixed original 512x512 cell crop only'],'variants':rows,'pixel_repainting':False,'background_removal':False,
        'mirroring':False,'native_started':False,'overall_art_qualified':False}
    (QA/'source_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'prepared':6,'source_unchanged':sha(SOURCE)==manifest['source_sha256']},ensure_ascii=False))
if __name__=='__main__':main()
