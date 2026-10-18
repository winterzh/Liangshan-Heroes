import hashlib,json,pathlib,shutil
import numpy as np
from PIL import Image
R=pathlib.Path('D:/AI项目/水浒/开发工程');E=pathlib.Path(__file__).parent
G=pathlib.Path('C:/Users/rsb/.codex/generated_images/01a11902-b95a-7981-aed1-f143736f8853')
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def save(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode())
raw_path=R/'assets/characters/ruan_xiaoqi_walk_grips_20261018/prompt_set.json'
raw=json.loads(raw_path.read_text('utf-8'));assert len(raw['sources'])==7
prompts=json.loads((E/'new_prompts.json').read_text('utf-8'))
specs=[
 ('contact_b_front_repeat_rejected','contact_b_front_repeat_rejected.png','exec-41e707e4-186f-49a5-ab71-93cdec5ec8c3.png','walkgrip_cb_front_fix_prompt',[],['se','sw','ne','nw'],[G/'exec-50612e1c-fbfc-4c2a-baac-7a2af64acf90.png',R/'assets/characters/ruan_xiaoqi_layered_20261018/contact_b_pose_8050a0c6.png',R/'assets/characters/ruan_xiaoqi_layered_20261018/contact_b_sw_33f17357.png']),
 ('contact_b_se_primary','contact_b_se_primary.png','exec-d3e5a15b-6584-4597-9cef-c5dcf0e259a0.png','walkgrip_cb_se_primary_prompt',['se'],['se','sw','ne','nw'],[R/'assets/characters/ruan_xiaoqi_layered_20261018/contact_b_pose_8050a0c6.png']),
 ('contact_b_sw_wide_rejected','contact_b_sw_wide_rejected.png','exec-eef3f3a4-7d3d-4484-a57d-febbd0c29361.png','walkgrip_cb_sw_primary_prompt',[],['sw'],[R/'assets/characters/ruan_xiaoqi_layered_20261018/contact_b_sw_33f17357.png']),
 ('contact_b_sw_close','contact_b_sw_close.png','exec-9f67f9f7-3e3c-4894-b79a-10f77f35b97f.png','walkgrip_cb_sw_close_prompt',['sw'],['sw'],[R/'assets/characters/ruan_xiaoqi_layered_20261018/contact_b_sw_33f17357.png'])]
for key,name,filename,prompt,selected,directions,refs in specs:
 source=G/filename;dest=raw_path.parent/name;assert not dest.exists();shutil.copyfile(source,dest);assert sha(source)==sha(dest)
 with Image.open(source) as im: size=list(im.size);a=np.asarray(im)[:,:,3]
 geometry={}
 for d in directions:
  if len(directions)==1:x,y,w,h=0,0,*size
  else:w,h=size[0]//2,size[1]//2;x=w if d in ['sw','nw'] else 0;y=h if d in ['ne','nw'] else 0
  cell=a[y:y+h,x:x+w]>=64;yy,xx=np.nonzero(cell)
  geometry[d]={'region':[x,y,w,h],'strong_alpha_bounds':[int(xx.min()),int(yy.min()),int(xx.max())+1,int(yy.max())+1],'strong_alpha_edge_counts':[int(cell[0,:].sum()),int(cell[-1,:].sum()),int(cell[:,0].sum()),int(cell[:,-1].sum())]}
 for d in selected:assert not any(geometry[d]['strong_alpha_edge_counts'])
 raw['sources'].append({'key':key,'path':dest.relative_to(R).as_posix(),'generated_original':str(source),'sha256':sha(source),'native_size':size,'status':'candidate' if selected else 'rejected','selected_directions':selected,'geometry':geometry,'request':{'prompt':prompts[prompt],'referenced_image_paths':[str(p) for p in refs],'transparent_background':True},'references':[{'path':str(p),'sha256':sha(p)} for p in refs]})
next(x for x in raw['sources'] if x['key']=='contact_b')['selected_directions']=['ne','nw']
raw['directly_seen_views']=38
raw['candidate_selected_views']=sum(len(x['selected_directions']) for x in raw['sources']);assert raw['candidate_selected_views']==14
raw['observations'] += ['First complete resource comparison passed120 structural checks but its CONTACT B front views repeated CONTACT A lead/support legs: rejected those two views. Corrected SE/SW edit from each original CONTACT B source retains the opposite contact step.','First SW-only grip edit retained the correct step but spread the arms far too wide; retained as a rejected source. Its modest-arm successor is the current candidate.','Source views counted per actual layout: nine four-view atlases plus two single-SW originals =38 views, not44. No exact finger contact or full gait acceptance from source inspection.']
save(raw_path,raw)
print(json.dumps({'sources':len(raw['sources']),'views_seen':38,'selected':raw['candidate_selected_views'],'script_bitmap_edits':False}))
