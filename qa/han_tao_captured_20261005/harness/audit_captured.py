"""Read-only native lineage/import/sample/resource audit. Never edits pixels."""
from pathlib import Path
import hashlib,json,sys
from PIL import Image
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
sys.path.insert(0,str(repo/'tools'))
import build_directional_spriteframes as builder
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
tag='han_tao_captured_20261005';contract=repo/'tools/contracts'/tag
manifest=json.loads((repo/'assets/direction4'/f'{tag}.json').read_text(encoding='utf-8'))
jobs=json.loads((contract/'jobs.json').read_text(encoding='utf-8'))
checks=[]
def check(ok,label):checks.append({'passed':bool(ok),'label':label})
for job in jobs:
    p=repo/job['repository_input']
    check(p.is_file() and sha(p)==job['sha256'],'retained repository source: '+job['key'])
    if job['method']=='built_in_imagegen':
        check(sha(Path(job['native_path']))==sha(p),'selected native output byte equality')
        check(job['generation_id']=='b2de3608-129e-4a56-9497-40070a103c3d','actual generation identity')
        request=json.loads((contract/'generation_request.json').read_text(encoding='utf-8'))
        check(request['prompt']==job['prompt'] and request['transparent_background'] is True,'exact actual generation request')
        check([Path(v).resolve() for v in request['referenced_image_paths']]==[Path(v).resolve() for v in job['original_reference_paths']] and job['references']==['portrait'],'actual portrait-only reference chain')
    else:check(job['references']==[],'project reference has no invented native parent')
p=repo/manifest['sources']['captured']['path']
im=Image.open(p);alpha=im.getchannel('A')
check(im.mode=='RGBA' and im.size==(1254,1254),'native RGBA and dimensions')
check(alpha.getextrema()==(0,255) and alpha.histogram()[0]/(im.width*im.height)>.35,'true alpha cutouts')
descriptor=Path(str(p)+'.import').read_text(encoding='utf-8')
for recipe in ['compress/mode=0','process/size_limit=1536','process/premult_alpha=false','mipmaps/generate=true','uid="uid://']:
    check(recipe in descriptor,'production import recipe: '+recipe)
dimensions=json.loads((base/'texture_bootstrap_dd9cdb8f/project/dimensions.json').read_text(encoding='utf-8'))
check(dimensions['passed'] and all(r['width']==1254 and r['height']==1254 for r in dimensions['checks']),'Godot native import dimensions verified')
sample_hashes=[]
for key,pose in manifest['poses'].items():
    x,y,w,h=pose['region'];cropped=alpha.crop((x,y,x+w,y+h))
    bounds=cropped.point(lambda a:255 if a>16 else 0).getbbox()
    check(bool(bounds) and min(bounds[0],bounds[1],w-bounds[2],h-bounds[3])>=4,'sample alpha clearance: '+key)
    margin=pose['margin']
    check(w+margin[2]==h+margin[3] and min(margin)>=0,'square runtime frame: '+key)
    check(.25<=pose['draw_scale']<=4 and pose['source']=='captured','body metadata only: '+key)
    sample_hashes.append(hashlib.sha256(im.crop((x,y,x+w,y+h)).tobytes()).hexdigest())
check(len(set(sample_hashes))==4,'four distinct independently sampled native drawings')
outputs=builder.render(manifest)
for path,text in outputs.items():check((repo/path).read_text(encoding='utf-8')==text,'zero-drift resource reproduction: '+path)
check(len(outputs)==4 and manifest['states']=={'captured':['captured']},'story-only four-resource scope')
check(sha(p)==manifest['sources']['captured']['sha256'],'native input unchanged after read-only audit')
result={'passed':all(r['passed'] for r in checks),'checks':checks,'check_count':len(checks),'production_pngs':1,'required_native_parents':0,'independent_poses':4,'resources':4,'native_pixel_edits':False,'ordinary_combat_art_verified':False,'scope':'Native byte/reference/import/sample and exact resource reproduction only; gameplay and visual QA are separate.'}
out=repo/'qa'/tag/'source_audit.json';out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps({'passed':result['passed'],'checks':len(checks),'failures':[r for r in checks if not r['passed']]}))
assert result['passed']
