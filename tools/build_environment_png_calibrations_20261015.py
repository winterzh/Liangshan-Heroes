"""Bind existing PNG bytes to pixels observed in a real, successful import/PCK run."""
import argparse,hashlib,json
from pathlib import Path
from environment_png_calibration_inputs_20261015 import inputs,table
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--baseline-run',type=Path,required=True);ap.add_argument('--verify',action='store_true');args=ap.parse_args()
    evidence=args.baseline_run/'evidence'
    receipt=json.loads((evidence/'receipt.json').read_text(encoding='utf-8'))
    source=json.loads((evidence/'source/report.json').read_text(encoding='utf-8'))
    packed=json.loads((evidence/'packed/report.json').read_text(encoding='utf-8'))
    assert receipt['complete'] and receipt['source_calibrated'] and not receipt['packed_calibrated'] and source['all_loaded'] and packed['all_loaded']
    assert len(source['rows'])==len(packed['rows'])==26 and all(not r['raw_png_available'] for r in packed['rows'])
    paired={r['key']:r for r in packed['rows']}
    observed={r['key']:r for r in source['rows']}
    rows=inputs();binding={}
    for row in rows:
        native,exported=observed[row['key']],paired[row['key']]
        assert native['source_sha256']==row['sha256'] and native['size']==row['size']==exported['size']
        assert native['imported_pixel_sha256']==exported['imported_pixel_sha256']
        binding['res://'+row['path']]={'source_sha256':row['sha256'],'pixel_sha256':row['decoded_pixel_sha256'],'imported_pixel_sha256':native['imported_pixel_sha256'],'size':row['size']}
    target=ROOT/'scripts/campaign_environment_art.gd';text=target.read_text(encoding='utf-8')
    if args.verify:
        assert table(text,'PNG_TEXTURE_CALIBRATIONS')==binding
        print(json.dumps({'source_and_actual_import_bindings_verified':26}));return
    original=next(r for r in receipt['source_files'] if r['path']=='scripts/campaign_environment_art.gd')
    assert sha(target)==original['sha256'] and 'const PNG_TEXTURE_CALIBRATIONS' not in text
    marker=b'const VISUAL_CALIBRATIONS: Dictionary = {'
    raw=target.read_bytes();assert raw.count(marker)==1
    declaration=('## Exact imported RGBA identity for accepted PNGs, including remapped PCKs.\r\nconst PNG_TEXTURE_CALIBRATIONS: Dictionary = '+json.dumps(binding,ensure_ascii=False,indent=2).replace('\n','\r\n')+'\r\n\r\n').encode('utf-8')
    target.write_bytes(raw.replace(marker,declaration+marker))
    qa=ROOT/'qa/packed_environment_art_20261015';qa.mkdir(exist_ok=False)
    lineage={'source_baseline':str(args.baseline_run),'receipt_sha256':sha(evidence/'receipt.json'),'native_report_sha256':sha(evidence/'source/report.json'),'packed_report_sha256':sha(evidence/'packed/report.json'),'original_resolver_sha256':original['sha256'],'bindings':binding,'pixel_repainting':False,'source_images_changed':False,'overall_art_qualified':False}
    (qa/'pixel_binding_lineage.json').write_text(json.dumps(lineage,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'bound_pngs':26,'source_images_unchanged':True}))
if __name__=='__main__':main()
