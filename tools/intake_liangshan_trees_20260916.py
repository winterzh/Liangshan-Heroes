from __future__ import annotations
import argparse, hashlib, json
from pathlib import Path
from PIL import Image

# Browser-generated source intake only. Keep this transform deterministic:
# crop fixed atlas quadrants, scale to the existing 512x512 visual slots,
# and do not mirror, mask, repaint, or clear pixels.
TARGETS = {
    "tree_broad": {"quadrant": (0, 0), "visible_height": 303, "anchor": (115, 105)},
    "tree_young": {"quadrant": (1, 0), "crop_left": 80, "visible_height": 280, "anchor": (116, 119)},
    "willow_old": {"quadrant": (0, 1), "visible_height": 294, "anchor": (120, 107)},
}
ROOT = Path(__file__).resolve().parents[1]
def sha(path: Path) -> str: return hashlib.sha256(path.read_bytes()).hexdigest()
def main() -> None:
    ap=argparse.ArgumentParser(); ap.add_argument('--source',type=Path,required=True); ap.add_argument('--manifest',type=Path,required=True); a=ap.parse_args()
    source=a.source.resolve(); im=Image.open(source).convert('RGBA')
    if im.size != (1254,1254): raise SystemExit(f'expected 1254x1254 source, got {im.size}')
    q=627; rows=[]
    for name,spec in TARGETS.items():
        qx,qy=spec['quadrant']; left=int(spec.get('crop_left',0)); tile=im.crop((qx*q+left,qy*q,(qx+1)*q,(qy+1)*q)); bbox=tile.getchannel('A').getbbox()
        if bbox is None: raise SystemExit(f'{name}: no visible pixels')
        scale=spec['visible_height']/(bbox[3]-bbox[1]); resized=tile.resize((round(tile.width*scale),round(tile.height*scale)),Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',(512,512),(0,0,0,0)); x,y=spec['anchor']; canvas.alpha_composite(resized,(x,y))
        target=ROOT/'assets/campaign/environment/level5'/f'{name}.png'; canvas.save(target,format='PNG',optimize=False); out=canvas.getchannel('A').getbbox()
        rows.append({'key':name,'quadrant_xy':[qx,qy],'source_region':[qx*q+int(spec.get('crop_left',0)),qy*q,q-int(spec.get('crop_left',0)),q],'source_alpha_bbox':list(bbox),'runtime_path':str(target.relative_to(ROOT)).replace('\\','/'),'runtime_size':[512,512],'runtime_alpha_bbox':list(out) if out else None,'runtime_sha256':sha(target),'scale':scale,'anchor_xy':[x,y]})
    data={'batch_id':'art_scene_20260916_liangshan_trees','provider':'web_chatgpt','conversation':'https://chatgpt.com/c/6aa954d2-8d40-83e9-abb6-e30963f8ae3c','source_path':str(source),'source_sha256':sha(source),'source_size':[1254,1254],'source_mode':'RGBA','source_alpha_range':list(im.getchannel('A').getextrema()),'method':'deterministic quadrant crop + LANCZOS scale into existing 512x512 slots','targets':rows}
    a.manifest.parent.mkdir(parents=True,exist_ok=True); a.manifest.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8'); print(json.dumps({'source_sha256':data['source_sha256'],'targets':len(rows)},ensure_ascii=False))
if __name__=='__main__': main()
