"""Persist builtin original PNG and exact prompt provenance, without pixel edits."""
from pathlib import Path
import datetime,hashlib,json,shutil,sys
from PIL import Image
Q=Path(__file__).resolve().parent;R=Q.parents[1]
key,original_name=sys.argv[1:3];original=Path(original_name)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
args_path=Q/f'tool_prompt_{key}.json';args=json.loads(args_path.read_text())
dest=Q/'native_originals'/f'{key}.png';dest.parent.mkdir(exist_ok=True);assert not dest.exists()
shutil.copyfile(original,dest);assert sha(original)==sha(dest)
im=Image.open(dest);assert im.mode=='RGBA'
row={'key':key,'mode':'builtin_imagegen','generated_original':str(original),'file':dest.relative_to(Q).as_posix(),'sha256':sha(dest),'bytes':dest.stat().st_size,'size':list(im.size),'pixel_mode':im.mode,'exact_tool_arguments':args_path.name,'exact_prompt_sha256':hashlib.sha256(args['prompt'].encode()).hexdigest(),'references':[{'path':p,'role':'edit_target' if i==0 else 'leg_pose_reference_only','sha256':sha(Path(p))} for i,p in enumerate(args['referenced_image_paths'])],'production_adopted':False,'local_pixel_writes':False,'recorded_at':datetime.datetime.now().isoformat()}
with (Q/f'source_{key}.json').open('x',encoding='utf-8') as f:f.write(json.dumps(row,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'key':key,'sha256':row['sha256'],'size':row['size']}))
