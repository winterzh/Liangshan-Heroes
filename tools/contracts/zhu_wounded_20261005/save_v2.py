"""Preserve built-in native PNG and its portable request/source lineage."""
from pathlib import Path
import hashlib,json,shutil,sys
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
key,state,original=sys.argv[1:4]
request=HERE/'requests'/f'{key}_{state}_v2.json'
args=json.loads(request.read_text(encoding='utf-8'))
dest=ROOT/'assets'/'characters'/f'{key}_wounded_20261005'/f'{state}_v2.png'
assert not dest.exists(),dest
dest.parent.mkdir(parents=True,exist_ok=True)
shutil.copyfile(original,dest)
assert sha(dest)==sha(Path(original))
im=Image.open(dest);assert im.mode=='RGBA' and max(im.size)<=1536
refs=[]
for path in args.get('referenced_image_paths',[]):
    p=Path(path);refs.append({'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)})
job={'schema':1,'character':key,'state':state,'method':'built-in image_gen native PNG byte-preserved','generation_id':Path(original).stem,'request':request.relative_to(ROOT).as_posix(),'request_sha256':sha(request),'references':refs,'output':dest.relative_to(ROOT).as_posix(),'output_sha256':sha(dest),'native_size':list(im.size),'mode':im.mode,'native_pixel_edits':False,'runtime_qualified':False}
out=HERE/'jobs'/f'{key}_{state}_v2.json';out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(job,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(job,ensure_ascii=False))
