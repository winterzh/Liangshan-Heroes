from pathlib import Path
import datetime,hashlib,json,shutil,sys
from PIL import Image
Q=Path(__file__).resolve().parent;key,source_name=sys.argv[1:3];source=Path(source_name)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
args_path=Q/f'tool_prompt_{key}.json';args=json.loads(args_path.read_text())
dest=Q/'native_originals'/(key+'.png');assert not dest.exists();shutil.copyfile(source,dest);assert sha(source)==sha(dest)
im=Image.open(dest);assert im.mode=='RGBA'
row={'key':key,'mode':'builtin_imagegen','intent':'new_single_view_generation_from_references','generated_original':str(source),'file':dest.relative_to(Q).as_posix(),'sha256':sha(dest),'bytes':dest.stat().st_size,'size':list(im.size),'pixel_mode':im.mode,'exact_tool_arguments':args_path.name,'exact_prompt_sha256':hashlib.sha256(args['prompt'].encode()).hexdigest(),'references':[{'path':p,'role':'reference_only_role_described_in_prompt','sha256':sha(Path(p))} for p in args['referenced_image_paths']],'production_adopted':False,'local_pixel_writes':False,'recorded_at':datetime.datetime.now().isoformat()}
with (Q/f'source_{key}.json').open('x',encoding='utf-8') as f:f.write(json.dumps(row,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'key':key,'sha256':sha(dest),'size':list(im.size)}))
