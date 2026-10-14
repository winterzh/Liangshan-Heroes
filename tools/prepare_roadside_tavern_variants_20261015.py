"""Reuse the accepted native atlas by fixed crop and deterministic scale only."""
from pathlib import Path
import argparse
import hashlib,json,re
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/campaign/environment/art_full_20260915/taverns.png'
QA=ROOT/'qa/roadside_tavern_variants_20261015'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify',action='store_true')
    args=parser.parse_args()
    if args.verify:
        manifest=json.loads((QA/'source_manifest.json').read_bytes())
        assert sha(SOURCE)==manifest['source_sha256']
        original=Image.open(SOURCE)
        for row in manifest['variants']:
            x,y,w,h=row['region']
            expected=original.crop((x,y,x+w,y+h)).resize((512,512),Image.Resampling.LANCZOS)
            target=ROOT/row['path']
            assert sha(target)==row['sha256'] and Image.open(target).tobytes()==expected.tobytes()
            assert sha(target.with_suffix('.tres'))==row['tres_sha256']
        print(json.dumps({'source_and_all_four_pixel_derivations_exact':True}))
        return
    QA.mkdir(exist_ok=False)
    im=Image.open(SOURCE);assert im.mode=='RGBA' and im.size==(1254,1254)
    original_sha=sha(SOURCE)
    table=[]
    for letter in 'abcd':
        key='roadside_tavern_'+letter
        tres=ROOT/('assets/campaign/environment/level7/'+key+'.tres')
        match=re.search(r'region = Rect2\((\d+), (\d+), (\d+), (\d+)\)',tres.read_text())
        x,y,w,h=map(int,match.groups());assert w==h==627
        target=ROOT/('assets/campaign/environment/level7/'+key+'.png');assert not target.exists()
        native=im.crop((x,y,x+w,y+h));production=native.resize((512,512),Image.Resampling.LANCZOS)
        production.save(target)
        reread=Image.open(target);assert reread.mode=='RGBA' and reread.tobytes()==production.tobytes()
        alpha=reread.getchannel('A');bbox=alpha.point(lambda value:255 if value>=16 else 0).getbbox();assert bbox
        assert alpha.getextrema()==(0,255) and all(reread.getpixel(p)[3]==0 for p in [(0,0),(511,0),(0,511),(511,511)])
        table.append(dict(key=key,path=target.relative_to(ROOT).as_posix(),sha256=sha(target),size=[512,512],region=[x,y,w,h],tres_sha256=sha(tres),visible_bbox_xywh=[bbox[0],bbox[1],bbox[2]-bbox[0],bbox[3]-bbox[1]],foot=bbox[3]/512,visible_top=bbox[1]/512,decoded_pixel_sha256=hashlib.sha256(reread.tobytes()).hexdigest()))
    assert len({row['sha256'] for row in table})==4 and sha(SOURCE)==original_sha
    manifest=dict(schema='roadside_tavern_variants_source_v1',source=SOURCE.relative_to(ROOT).as_posix(),source_sha256=original_sha,source_size=[1254,1254],source_provider='accepted web ChatGPT native atlas from 2026-09-15',operations=['exact existing TRES integer region crop','512x512 LANCZOS deterministic scale'],pixel_repainting=False,mirroring=False,background_removal=False,variants=table,native_started=False,visual_qualified=False,overall_art_qualified=False)
    (QA/'source_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    env=ROOT/'scripts/campaign_environment_art.gd';raw=env.read_bytes();needle=b'const VISUAL_CALIBRATIONS: Dictionary = {\r\n\t"object": {\r\n';assert raw.count(needle)==1
    newrows=''.join('\t\t"'+row['key']+'": {"level_id":"level7", "label_visible_top":true, "source_sha256":"'+row['sha256']+'", "visible_bbox_xywh":'+json.dumps(row['visible_bbox_xywh'],separators=(',',':'))+'},\r\n' for row in table).encode()
    env.write_bytes(raw.replace(needle,needle+newrows))
    print(json.dumps({'variants':table,'source_unchanged':True},ensure_ascii=False))
if __name__=='__main__':main()
