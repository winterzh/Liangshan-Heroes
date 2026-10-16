"""Read-only provenance and PNG inspection of unbound Gongsun Sheng daily drafts.

This does not approve anatomy, atlas bindings, animation, native execution or canon
of inherited gameplay. No bitmap pixels or project sources are modified.
"""
import hashlib,json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'assets/characters/gongsun_sheng_daily_sources_20261017/prompt_set.json'

def sha(path):
    with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()

def main():
    manifest=json.loads(MANIFEST.read_text(encoding='utf-8'))
    checks=[];images=[]
    def check(ok,label):checks.append({'name':label,'passed':bool(ok)})
    def source(name):
        p=ROOT/name
        assert p.resolve().is_relative_to(ROOT.resolve()) and not p.is_symlink()
        return p
    check(manifest['runtime_adopted'] is False,'draft manifest has no runtime adoption')
    check(len(manifest['sources'])==18,'18 distinct saved originals including rejected drafts')
    check(len({r['key'] for r in manifest['sources']})==18,'unique source keys')
    check((MANIFEST.parent/'.gdignore').is_file(),'raw sources isolated from Godot import')
    refs=0
    for row in manifest['sources']:
        p=source(row['path']);check(sha(p)==row['sha256'],'exact original SHA '+row['key'])
        check(p.stat().st_size==row['bytes'],'exact byte length '+row['key'])
        check(bool(row['prompt']) and not row['runtime_adopted'],'prompt and unbound status '+row['key'])
        for ref in row['references']:
            check(sha(source(ref['path']))==ref['sha256'],'reference SHA '+row['key']+' '+str(refs));refs+=1
        with Image.open(p) as im:
            im.load();check(im.format=='PNG' and list(im.size)==row['size'] and im.mode==row['mode'],'decodable original PNG '+row['key'])
            entry={'key':row['key'],'size':list(im.size),'mode':im.mode,'status':row['status']}
            if row['key']!='portrait':
                check(im.mode=='RGBA','native alpha channel '+row['key'])
                if im.mode=='RGBA':
                    a=im.getchannel('A');hist=a.histogram();w,h=im.size
                    corners=[im.getpixel((x,y))[3] for x,y in [(0,0),(w-1,0),(0,h-1),(w-1,h-1)]]
                    check(hist[0]>w*h*.20 and hist[255]>0,'transparent and solid subject pixels '+row['key'])
                    check(max(corners)<=1,'no opaque rectangular corner '+row['key'])
                    entry.update(alpha_zero_pixels=hist[0],alpha_full_pixels=hist[255],corner_alpha=corners)
            images.append(entry)
    check(refs==manifest['reference_count']==31,'all31 ordered references retained')
    check(sum(r['status']=='superseded_draft' for r in manifest['sources'])==3,'three superseded drafts retained separately')
    failures=[r['name'] for r in checks if not r['passed']]
    result={'passed':not failures,'scope':'Read-only candidate source SHA, prompt/reference chain, PNG decode and alpha. Not anatomy/animation/native acceptance.','manifest_sha256':sha(MANIFEST),'source_count':18,'reference_count':refs,'checks':checks,'failures':failures,'images':images,'runtime_adopted':False,'native_launched':False,'steam_updated':False}
    print(json.dumps(result,ensure_ascii=False,indent=2))
    if failures:raise SystemExit(1)

if __name__=='__main__':main()
