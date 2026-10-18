"""Append an exact builtin original; never modify existing candidate PNGs."""
from pathlib import Path
import hashlib,json,shutil,sys
from PIL import Image
Q=Path(__file__).resolve().parent
key,name=sys.argv[1:3];source=Path(name);dest=Q/'native_originals'/(key+'.png')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert not dest.exists();shutil.copyfile(source,dest);assert sha(source)==sha(dest)
im=Image.open(dest);assert im.mode=='RGBA' and im.size==(1254,1254)
args=json.loads((Q/('tool_prompt_'+key+'.json')).read_text())
row={'key':key,'file':dest.relative_to(Q).as_posix(),'sha256':sha(dest),'bytes':dest.stat().st_size,'generated_original':str(source),'exact_tool_prompt_json':'tool_prompt_'+key+'.json','exact_sent_prompt_sha256':hashlib.sha256(args['prompt'].encode()).hexdigest(),'mode':'builtin_imagegen','production_adopted':False,'native_executed':False,'dimensions':list(im.size),'pixel_mode':im.mode,'references':[{'path':p,'role':'edit_target' if i==0 else 'reference_only','sha256':sha(Path(p))} for i,p in enumerate(args['referenced_image_paths'])],'direct_view':'Four static directions viewed. One drawn sword and empty diagonal back scabbard retained; reins and planted horse maintained visually, exact anchors/size and temporal animation not yet verified. Short soft cord replaces extra rigid dangling waist strand. No new story injury.'}
for filename in ['prompt_set.json','partial_inventory.json']:
    p=Q/filename;data=json.loads(p.read_text());assert all(x['key']!=key for x in data['sources']);data['sources'].append(row)
    if filename=='prompt_set.json':
        data['pending']=[x for x in data['pending'] if x!='drawn-sword recoil and recovery']
        if 'drawn-sword recoil/recovery native and temporal validation' not in data['pending']:data['pending'].append('drawn-sword recoil/recovery native and temporal validation')
    p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
with (Q/('review_'+key+'.json')).open('x',encoding='utf-8') as f:f.write(json.dumps({'source_sha256':sha(dest),'original_bytes_preserved':True,'directly_viewed':True,'candidate_only':True,'native_animation_accepted':False,'exact_hoof_rein_anchors_accepted':False,'new_story_event_added':False},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'key':key,'sha256':sha(dest),'original_count':len(data['sources'])}))
