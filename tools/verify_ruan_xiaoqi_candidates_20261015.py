"""Read-only provenance/dimensions audit for unadopted Ruan Xiaoqi PNG candidates.

No PNG write, cropping, painting, scaling or production route change.
This does not validate gameplay, four-direction animation quality or adoption.
"""
import argparse,hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/characters/ruan_xiaoqi_canon_sources_20261015'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def audit():
    prompts=json.loads((SOURCE/'prompt_set.json').read_text(encoding='utf-8'))
    assert prompts['mode']=='builtin'
    rows=[]
    for job in prompts['jobs']:
        path=SOURCE/(job['key']+'_native.png')
        assert path.is_file() and sha(path)==sha(Path(job['generated_path']))
        refs=[{'path':Path(p).relative_to(ROOT).as_posix(),'sha256':sha(Path(p))} for p in job['refs']]
        im=Image.open(path);assert im.format=='PNG'
        assert min(im.size)>=1000
        # The single NW source is native1240x1269, not an atlas; do not resize it.
        if job['key']!='walk_contact_b_nw':assert im.size[0]==im.size[1]
        if job['transparent_background']:
            assert im.mode=='RGBA'
            alpha=im.getchannel('A')
            assert alpha.getextrema()==(0,255) and alpha.getpixel((0,0))==0
            bounds=alpha.point(lambda v:255 if v>=128 else 0).getbbox()
        else:bounds=None
        rows.append({'key':job['key'],'path':path.relative_to(ROOT).as_posix(),'sha256':sha(path),'bytes':path.stat().st_size,'mode':im.mode,'native_size':list(im.size),'strong_alpha_bounds':bounds,'references':refs})
    assert len(rows)==len({r['key'] for r in rows})==22
    return {'mode':'builtin','sources':rows,'prompt_set_sha256':sha(SOURCE/'prompt_set.json'),'identity_card':'docs/RUAN_XIAOQI_IDENTITY_20261015.md','png_pixel_writes':False,'candidate_only':True,'production_qualified':False,'native_import_run':False,'gait_accepted':False,'combat_correction_complete':False,'steam_updated':False}
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path);args=parser.parse_args()
    report=audit()
    if args.out:
        path=args.out.resolve()
        assert path.is_relative_to((ROOT/'qa/ruan_xiaoqi_canon_20261015').resolve())
        assert not path.exists(),'Preserve prior receipts'
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes((json.dumps(report,ensure_ascii=False,indent=2)+'\n').encode())
    print(json.dumps({'candidate_pngs':len(report['sources']),'raw_png_sha_match':True,'references_sha_recorded':True,'candidate_only':True,'native_run':False,'production_qualified':False}))
if __name__=='__main__':main()
