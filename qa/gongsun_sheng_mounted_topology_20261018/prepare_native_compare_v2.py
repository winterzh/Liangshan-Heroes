"""Same original pixels/virtual canvas; fixed 1px unused-border inset for all frames.

Whole-cell alpha failures remain failures in a separate audit. No pixel edits.
"""
from pathlib import Path
import hashlib,json,shutil
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[2]
Q=Path(__file__).resolve().parent
B=Path('D:/CodexEvidence/shuihu/gongsun_mounted_topology_20261018')
E=Path('D:/CodexEvidence/shuihu/gongsun_mounted_topology_inset_v2_20261018')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')

def main():
    assert not E.exists(),'Never overwrite an immutable comparison'
    seed=json.loads((B/'prepared_binding.json').read_text())
    assert all(sha(B/'prepared'/x['path'])==x['sha256'] for x in seed['frozen'])
    d=json.loads((B/'prepared/inputs.json').read_text());audit=[]
    E.mkdir(parents=True);P=E/'prepared';P.mkdir()
    for row in seed['frozen']:
        src=B/'prepared'/row['path'];dst=P/row['path'];dst.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(src,dst);assert sha(src)==sha(dst)==row['sha256']
    for direction,views in d['views'].items():
        for v in views:
            r=v['region'];x,y,w,h=r
            a=np.asarray(Image.open(P/d['textures'][v['source_key']]['file']))[y:y+h,x:x+w,3]
            border=np.concatenate([a[0],a[-1],a[:,0],a[:,-1]])
            assert int(border.max())<=1,'Never cut visible art or meaningful alpha to satisfy corners'
            original_corners=[int(a[py,px]) for px,py in [(0,0),(626,0),(0,626),(626,626)]]
            inner_corners=[int(a[py,px]) for px,py in [(1,1),(625,1),(1,625),(625,625)]]
            assert inner_corners==[0,0,0,0]
            audit.append({'resource':v['resource'],'source':v['source_key'],'direction':direction,
                'original_corner_alphas':original_corners,'original_corner_check_passed':original_corners==[0,0,0,0],
                'max_excluded_alpha':int(border.max()),'selected_corner_alphas':inner_corners})
            v['original_full_region']=r;v['region']=[x+1,y+1,625,625];v['virtual_margin']=[1,1,2,2]
            old='region = Rect2('+', '.join(map(str,r))+')'
            new='region = Rect2('+', '.join(map(str,v['region']))+')\nmargin = Rect2(1, 1, 2, 2)'
            f=P/v['resource'];text=f.read_text();assert old in text;f.write_text(text.replace(old,new),encoding='utf-8')
    failures=[r for r in audit if not r['original_corner_check_passed']]
    d['whole_cell_corner_audit']={'passed':not failures,'failures':failures,'frames':audit,
        'native_executed':False,'scope':'Original whole-cell corner checks retain their original strict alpha-zero criterion and observed failures.'}
    d['scope']+=' All frames use the same 1px inset with (1,1,2,2) virtual margin:627 canvas and actual sprite positions retained. Every excluded source-border pixel has alpha<=1; original whole-cell failures remain recorded, and full native pixel hashes must still equal untouched originals.'
    (P/'inputs.json').unlink();save(P/'inputs.json',d)
    preview=(P/'preview.gd').read_text()
    preview=preview.replace('texture.region == Rect2(region[0],region[1],region[2],region[3]) and texture.get_size() == Vector2(627,627)',
        'texture.region == Rect2(region[0],region[1],region[2],region[3]) and texture.margin == Rect2(1,1,2,2) and texture.get_size() == Vector2(627,627)')
    preview=preview.replace('full original quadrant','fixed inset and original virtual canvas')
    preview=preview.replace('region[0]+626','region[0]+region[2]-1').replace('region[1]+626','region[1]+region[3]-1')
    preview=preview.replace('native full quadrant corners transparent','native selected-region corners transparent')
    preview=preview.replace('"scope":data.scope}', '"whole_cell_corner_failures_preserved":data.whole_cell_corner_audit.failures,"scope":data.scope}')
    (P/'preview.gd').write_text(preview,encoding='utf-8')
    frozen=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(P.rglob('*')) if p.is_file()]
    value={'prepared':True,'native_executed':False,'project':str(P),'frozen':frozen,
        'preparer_sha256':sha(Path(__file__)),'seed_binding_sha256':sha(B/'prepared_binding.json'),
        'png_count':len(d['textures']),'candidate_views':8,'new_source_selected_views':5,
        'previous_receipt':seed['previous_receipt'],'production_adopted':False,'whole_cell_corner_failures_preserved':failures}
    save(E/'prepared_binding.json',value)
    for src,dst in [(P/'inputs.json',Q/'native_v2_inputs.json'),(P/'preview.gd',Q/'native_v2_preview.gd.txt'),(E/'prepared_binding.json',Q/'native_v2_prepared_binding.json')]:shutil.copyfile(src,dst)
    save(Q/'whole_cell_preflight.json',d['whole_cell_corner_audit'])
    print(json.dumps({'prepared_files':len(frozen),'pngs':len(d['textures']),'raw_whole_cell_failures_preserved':len(failures),'native_executed':False}))

if __name__=='__main__':main()
