"""Preserve imagegen originals and diagnose raw-alpha frame boundaries without changing PNG pixels."""
from pathlib import Path
import argparse,datetime,hashlib,json,re,shutil
import numpy as np
from scipy import ndimage
from PIL import Image
parser=argparse.ArgumentParser();parser.add_argument('--version',required=True);parser.add_argument('--original',required=True);parser.add_argument('--intent',choices=['new_four_direction_short_knife_body','imagegen_four_direction_body_edit']);args=parser.parse_args();assert re.fullmatch(r'v[0-9]+',args.version)
Q=Path(__file__).resolve().parent;R=Q.parents[1];src=Path(args.original).resolve();key='idle_'+args.version
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,data):
    with p.open('x',encoding='utf-8',newline='\n') as f:f.write(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
target=Q/'native_originals'/f'{key}.png';target.parent.mkdir(exist_ok=True);assert not target.exists();shutil.copyfile(src,target);assert sha(src)==sha(target)
prompt=Q/f'tool_prompt_{key}.json';spec=json.loads(prompt.read_text(encoding='utf-8'))
with Image.open(target) as image:
    assert image.mode=='RGBA' and image.size==(1254,1254);alpha=np.asarray(image.getchannel('A'))
save(Q/f'source_{key}.json',{'key':key,'mode':'builtin_imagegen','intent':args.intent or ('new_four_direction_short_knife_body' if args.version=='v1' else 'imagegen_four_direction_body_edit'),
    'file':target.relative_to(Q).as_posix(),'generated_original':str(src),'sha256':sha(target),'bytes':target.stat().st_size,'pixel_mode':'RGBA','size':[1254,1254],
    'exact_tool_arguments':prompt.name,'prompt_sha256':sha(prompt),'references':[{'path':p,'repository_path':Path(p).relative_to(R).as_posix(),'sha256':sha(Path(p))} for p in spec['referenced_image_paths']],
    'local_pixel_writes':False,'production_adopted':False,'recorded_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()})
labels,count=ndimage.label(alpha>0,structure=np.ones((3,3),dtype=np.uint8));objects=ndimage.find_objects(labels);areas=np.bincount(labels.ravel());components=[]
for index,slices in enumerate(objects,1):
    ys,xs=slices;values=alpha[slices][labels[slices]==index];components.append({'id':index,'pixels':int(areas[index]),'bbox':[xs.start,ys.start,xs.stop,ys.stop],'max_alpha':int(values.max())})
components.sort(key=lambda row:row['pixels'],reverse=True);bodies=[c for c in components if c['pixels']>10000];extra=[c for c in components if c['pixels']<=10000]
failures=[];frames=[]
if len(bodies)!=4:failures.append({'reason':'Expected four raw-alpha body components','actual':len(bodies)})
if max((c['max_alpha'] for c in extra),default=0)>2:failures.append({'reason':'Visible extra disconnected components','extra_max_alpha':max(c['max_alpha'] for c in extra)})
for direction,(left,top,right,bottom) in zip(['se','sw','ne','nw'],[(0,0,627,627),(627,0,1254,627),(0,627,627,1254),(627,627,1254,1254)]):
    owners=[c for c in bodies if left<=c['bbox'][0] and c['bbox'][2]<=right and top<=c['bbox'][1] and c['bbox'][3]<=bottom]
    frame={'direction':direction,'cell':[left,top,right-left,bottom-top],'owned_body_components':len(owners)}
    if len(owners)!=1:failures.append({'direction':direction,'reason':'Body crosses uniform frame boundary or is missing'});frames.append(frame);continue
    c=owners[0];x,y,r,b=c['bbox'];x=max(left+1,x-12);y=max(top+1,y-12);r=min(right-1,r+12);b=min(bottom-1,b+12);qualified=False
    for attempt in range(64):
        cut=alpha[y:b,x:r];hits=[np.any(cut[:,0]),np.any(cut[0]),np.any(cut[:,-1]),np.any(cut[-1])]
        if not any(hits):qualified=True;break
        nx,ny,nr,nb=x-int(hits[0]),y-int(hits[1]),r+int(hits[2]),b+int(hits[3])
        if not (left<nx<nr<right and top<ny<nb<bottom):break
        x,y,r,b=nx,ny,nr,nb
    frame.update({'body':c,'sampling_region':[x,y,r-x,b-y],'strict_sampling_edge_clear':qualified})
    if not qualified:failures.append({'direction':direction,'reason':'Raw-alpha sampling edge cannot clear inside its frame'})
    frames.append(frame)
result={'scope':'Raw alpha>0 complete body ownership and selected sampling edges only. No thresholding, source edits or anatomical/motion acceptance.',
    'source_sha256':sha(target),'raw_body_components':bodies,'frames':frames,'failures':failures,'frame_source_qualified':not failures,
    'extra_components':len(extra),'extra_max_alpha':max((c['max_alpha'] for c in extra),default=0),'production_adopted':False}
save(Q/f'frame_check_{key}.json',result)
print(json.dumps({'key':key,'body_bboxes':[c['bbox'] for c in bodies],'frame_source_qualified':not failures,'failures':failures}))
