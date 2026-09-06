"""Read-only PNG lineage, alpha and inter-frame contamination audit (Pillow)."""
from pathlib import Path
import argparse, hashlib, json, re
from itertools import combinations
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('lineage', type=Path)
    parser.add_argument('--out', type=Path, default=ROOT/'.godot/directional_character_sources.json')
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding='utf-8'))
    lineage = json.loads(args.lineage.read_text(encoding='utf-8'))
    jobs = {j['key']:j for j in lineage['jobs']}
    checks = []
    def check(name, ok): checks.append({'name':name,'passed':bool(ok)})
    def verify(path, sha):
        p=(ROOT/path).resolve()
        return p.is_relative_to(ROOT) and p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==sha
    check('original identity reference retained',verify(lineage['original_reference']['path'],lineage['original_reference']['sha256']))
    for key,job in jobs.items():
        if not job['repository_path']: continue
        check(key+' native bytes',verify(job['repository_path'],job['sha256']))
        if job.get('method')=='godot_3d_pose_reference':
            generators=job.get('generator_artifacts',[])
            check(key+' code-native pose generator retained',bool(generators) and all(verify(item['path'],item['sha256']) for item in generators))
        else:
            check(key+' exact prompt retained',bool(job['prompt'].strip()))
        check(key+' portable reference chain',all(ref=='original' or ref in jobs and jobs[ref]['repository_path'] for ref in job['references']))
    alpha_by_source={}
    for key,source in manifest['sources'].items():
        p=ROOT/source['path']
        check(key+' native hash',verify(source['path'],source['sha256']))
        with Image.open(p) as im:
            check(key+' native RGBA and dimensions',im.mode=='RGBA' and list(im.size)==source['native_size'])
            if im.mode!='RGBA': continue
            a=im.getchannel('A');alpha_by_source[key]=a
            check(key+' substantial real transparency',a.histogram()[0]/(im.width*im.height)>.35)
        meta=Path(str(p)+'.import').read_text(encoding='utf-8')
        check(key+' bounded mipmapped import',f"process/size_limit={source['import_limit']}" in meta and 'mipmaps/generate=true' in meta and max(source['imported_size'])<=source['import_limit'])
        check(key+' selected generation matches',source['sha256']==jobs[source['job']]['sha256'])
    for key,pose in manifest['poses'].items():
        source=manifest['sources'][pose['source']]
        x,y,w,h=pose['region_raw']
        check(key+' region inside native source',min(x,y)>=0 and min(w,h)>0 and x+w<=source['native_size'][0] and y+h<=source['native_size'][1])
        check(key+' square padding',pose['region'][2]+pose['margin'][2]==pose['virtual_size_imported'] and pose['region'][3]+pose['margin'][3]==pose['virtual_size_imported'])
        check(key+' ground pivot finite and authored',len(pose['pivot'])==2 and all(isinstance(v,(int,float)) for v in pose['pivot']))
    # Each pose has a distinct sampling rectangle. Shared nontransparent pixels
    # between two rectangles reveal a neighboring spear/limb entering the crop.
    for (ka,a),(kb,b) in combinations(manifest['poses'].items(),2):
        if a['source']!=b['source']: continue
        ax,ay,aw,ah=a['region_raw'];bx,by,bw,bh=b['region_raw']
        box=(max(ax,bx),max(ay,by),min(ax+aw,bx+bw),min(ay+ah,by+bh))
        if box[0]>=box[2] or box[1]>=box[3]: continue
        alpha=alpha_by_source.get(a['source'])
        check(ka+' / '+kb+' no shared visible pixels',alpha is not None and sum(alpha.crop(box).histogram()[16:])==0)
    for key,source in manifest['sources'].items():
        unused=source.get('unused_regions',[])
        if (not source.get('full_atlas',False) and not unused) or key not in alpha_by_source: continue
        alpha=alpha_by_source[key]
        total=sum(alpha.histogram()[16:]);covered=0
        used_boxes=[]
        for pose in manifest['poses'].values():
            if pose['source']!=key:continue
            x,y,w,h=pose['region_raw'];covered+=sum(alpha.crop((x,y,x+w,y+h)).histogram()[16:])
            used_boxes.append((x,y,x+w,y+h))
        for index,entry in enumerate(unused):
            x,y,w,h=entry['region'];box=(x,y,x+w,y+h)
            check(key+' unused pose reason and native bounds '+str(index),bool(entry.get('reason','').strip()) and min(x,y)>=0 and min(w,h)>0 and x+w<=alpha.width and y+h<=alpha.height)
            for other in used_boxes:
                overlap=(max(x,other[0]),max(y,other[1]),min(x+w,other[2]),min(y+h,other[3]))
                if overlap[0]<overlap[2] and overlap[1]<overlap[3]:
                    check(key+' unused pose cannot contain selected foreground '+str(index),sum(alpha.crop(overlap).histogram()[16:])==0)
            covered+=sum(alpha.crop(box).histogram()[16:]);used_boxes.append(box)
        check(key+' complete atlas foreground selected or explicitly rejected exactly once',covered==total)
    for resource in manifest['resources']:
        paths=re.findall(r'path="res://([^\"]+)"',(ROOT/resource).read_text(encoding='utf-8'))
        check(resource+' dependencies present',bool(paths) and all((ROOT/p).is_file() for p in paths))
    result={'checks':checks,'passed':all(c['passed'] for c in checks),'production_pngs':len(manifest['sources']),'authored_poses':len(manifest['poses']),'scope':'Native bytes, lineage, import, alpha and sampling contamination; anatomy and facing require visual review.'}
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'checks':len(checks),'passed':result['passed'],'failed':[c['name'] for c in checks if not c['passed']]}))
    return 0 if result['passed'] else 1

if __name__=='__main__': raise SystemExit(main())
