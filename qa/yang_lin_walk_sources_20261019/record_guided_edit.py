"""Exact guided edit preservation; no pose acceptance is implied."""
from pathlib import Path
import datetime, hashlib, json, shutil, sys
from PIL import Image
Q = Path(__file__).resolve().parent
source = Path(sys.argv[1]).resolve()
target = Q/'native_originals/contact_b_ne_v3.png'
assert not target.exists()
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
args_file = Q/'tool_prompt_contact_b_ne_v3.json'
args = json.loads(args_file.read_text(encoding='utf-8'))
assert len(args['referenced_image_paths']) == 2
shutil.copyfile(source,target)
assert sha(source)==sha(target)
with Image.open(target) as im:
    assert im.mode=='RGBA' and im.size==(1254,1254)
    row={'key':'contact_b_ne_v3','mode':'builtin_imagegen','intent':'edit_with_debug_geometry_guide',
         'file':target.relative_to(Q).as_posix(),'generated_original':str(source),'sha256':sha(target),
         'bytes':target.stat().st_size,'pixel_mode':im.mode,'size':list(im.size),
         'exact_tool_arguments':args_file.name,'prompt_sha256':hashlib.sha256(args['prompt'].encode()).hexdigest(),
         'references':[{'path':p,'sha256':sha(Path(p)),'role':['edit_target','debug_pose_guide_not_production_art'][i]}
                       for i,p in enumerate(args['referenced_image_paths'])],
         'local_pixel_writes':False,'production_adopted':False,'native_accepted':False,
         'recorded_at':datetime.datetime.now().isoformat()}
with (Q/'source_contact_b_ne_v3.json').open('x',encoding='utf-8') as stream:
    stream.write(json.dumps(row,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'key':row['key'],'sha256':row['sha256']}))
