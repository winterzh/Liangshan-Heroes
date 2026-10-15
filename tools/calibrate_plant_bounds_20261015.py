"""Measure accepted alpha contours; update only seven stale alignment records."""
import argparse,hashlib,json,re
from pathlib import Path
from PIL import Image
from environment_png_calibration_inputs_20261015 import inputs
ROOT=Path(__file__).resolve().parents[1]
KEYS={'reeds_short','reeds_tall','reeds_bent','reeds_seeded','willow_old','tree_broad','tree_young'}
QA=ROOT/'qa/plant_bounds_20261015'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def measured():
    rows=[]
    for row in inputs():
        if row['key'] not in KEYS:continue
        image=Image.open(ROOT/row['path'])
        bbox=image.getchannel('A').point(lambda value:255 if value>=16 else 0).getbbox()
        new=[bbox[0],bbox[1],bbox[2]-bbox[0],bbox[3]-bbox[1]]
        assert 0<=bbox[0]<bbox[2]<=512 and 0<=bbox[1]<bbox[3]<=512
        rows.append({**row,'measured_bbox_xywh':new,'measured_foot':bbox[3]/512})
    assert len(rows)==7
    return rows
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--verify',action='store_true');args=ap.parse_args()
    rows=measured();path=ROOT/'scripts/campaign_environment_art.gd'
    if args.verify:
        original=json.loads((QA/'source_calibration.json').read_text(encoding='utf-8'))
        for row in rows:
            assert row['visible_bbox_xywh']==row['measured_bbox_xywh']
            prior=next(r for r in original['plants'] if r['key']==row['key'])
            assert prior['sha256']==row['sha256'] and prior['measured_bbox_xywh']==row['measured_bbox_xywh']
        print(json.dumps({'seven_actual_alpha_bounds_match':True,'source_PNGs_unchanged':True}));return
    QA.mkdir(exist_ok=False)
    raw=path.read_bytes();before_sha=sha(path)
    for row in rows:
        assert row['visible_bbox_xywh']!=row['measured_bbox_xywh']
        pattern=rb'("'+row['key'].encode()+rb'": \{[^\r\n]*"visible_bbox_xywh":)\[[^\]]+\]'
        raw,count=re.subn(pattern,lambda m:m.group(1)+json.dumps(row['measured_bbox_xywh'],separators=(',',':')).encode(),raw)
        assert count==1
    path.write_bytes(raw)
    manifest={'scope':'Seven existing Level5 accepted PNG alpha>=16 bounds; alignment metadata only, no pixels/layout/gameplay changes.',
        'resolver_before_sha256':before_sha,'resolver_after_sha256':sha(path),'plants':rows,'native_qualified':False,'overall_art_qualified':False}
    (QA/'source_calibration.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'calibrated':7,'pixel_changes':False,'native_pending':True}))
if __name__=='__main__':main()
