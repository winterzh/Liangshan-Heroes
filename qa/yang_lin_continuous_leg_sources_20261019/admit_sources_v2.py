"""Read-only raw-alpha source admission; never alters image pixels."""
from pathlib import Path
import datetime,hashlib,json,shutil
import numpy as np
from scipy import ndimage
from PIL import Image
Q=Path(__file__).resolve().parent;R=Q.parents[1]
original=Path('C:/Users/rsb/.codex/generated_images/01a11902-b95a-7981-aed1-f143736f8853/exec-c24ad0f3-6f3a-4945-bbc2-e65181660f1f.png')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,data):
    with p.open('x',encoding='utf-8',newline='\n') as f:f.write(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
target=Q/'native_originals/full_leg_v2.png';target.parent.mkdir(exist_ok=True)
assert not target.exists();shutil.copyfile(original,target);assert sha(original)==sha(target)
args=json.loads((Q/'tool_prompt_full_leg_v2.json').read_text(encoding='utf-8'))
with Image.open(target) as im:
    assert im.mode=='RGBA' and im.size==(1254,1254)
    alpha=np.asarray(im.getchannel('A'))
source={'key':'full_leg_v2','mode':'builtin_imagegen','intent':'imagegen_background_extraction_edit',
    'file':'native_originals/full_leg_v2.png','generated_original':str(original),'sha256':sha(target),'bytes':target.stat().st_size,
    'size':[1254,1254],'pixel_mode':'RGBA','exact_tool_arguments':'tool_prompt_full_leg_v2.json','prompt_sha256':sha(Q/'tool_prompt_full_leg_v2.json'),
    'references':[{'path':p,'sha256':sha(Path(p)),'role':'imagegen_edit_target'} for p in args['referenced_image_paths']],
    'local_pixel_writes':False,'production_adopted':False,'recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
write(Q/'source_full_leg_v2.json',source)
labels,count=ndimage.label(alpha>0,structure=np.ones((3,3),dtype=np.uint8));objects=ndimage.find_objects(labels);areas=np.bincount(labels.ravel())
comps=[]
for index,slices in enumerate(objects,1):
    ys,xs=slices;values=alpha[slices][labels[slices]==index]
    comps.append({'id':index,'pixels':int(areas[index]),'bbox':[xs.start,ys.start,xs.stop,ys.stop],'max_alpha':int(values.max())})
comps.sort(key=lambda r:r['pixels'],reverse=True);main=comps[:8];extra=comps[8:]
assert max((r['max_alpha'] for r in extra),default=0)<=2
regions=[];failures=[];xs=[0,313,627,940,1254]
for row_index,(top,bottom) in enumerate([(0,627),(627,1254)]):
    for col,(left,right) in enumerate(zip(xs,xs[1:])):
        owned=[c for c in main if left<=c['bbox'][0] and c['bbox'][2]<=right and top<=c['bbox'][1] and c['bbox'][3]<=bottom]
        assert len(owned)==1,(row_index,col,owned)
        c=owned[0];bx,by,br,bb=c['bbox'];x=max(left+1,bx-12);y=max(top+1,by-12);r=min(right-1,br+12);b=min(bottom-1,bb+12)
        strict=False;failure=''
        for attempt in range(64):
            cut=alpha[y:b,x:r];hits=[np.any(cut[:,0]),np.any(cut[0]),np.any(cut[:,-1]),np.any(cut[-1])]
            if not any(hits):strict=True;break
            nx=x-int(hits[0]);ny=y-int(hits[1]);nr=r+int(hits[2]);nb=b+int(hits[3])
            if not (left<nx<nr<right and top<ny<nb<bottom):failure='Expansion reaches cell boundary';break
            x,y,r,b=nx,ny,nr,nb
        if not strict:
            failure=failure or 'Sampling edge expansion exhausted';failures.append({'leg':['right','left'][row_index],'direction':['se','sw','ne','nw'][col],'reason':failure})
            # Explicitly preview-only fallback, retaining all main component pixels without image edits.
            x,y,r,b=max(left+1,bx-12),max(top+1,by-12),min(right-1,br+12),min(bottom-1,bb+12)
        cut=alpha[y:b,x:r];edges=np.concatenate([cut[:,0],cut[0],cut[:,-1],cut[-1]])
        regions.append({'leg':['right','left'][row_index],'direction':['se','sw','ne','nw'][col],
            'cell':[left,top,right-left,bottom-top],'region':[x,y,r-x,b-y],
            'main_component':c,'edge_nonzero_pixels':int(np.count_nonzero(edges)),'edge_max_alpha':int(edges.max()),'strict_edge_clear':strict})
write(Q/'source_admission_v2.json',{'scope':'Same raw alpha>0 connected-component and edge-expansion rule as prior modular sources. No thresholding or PNG writes.',
    'source_sha256':sha(target),'main_components':len(main),'extra_components':len(extra),'extra_max_alpha':max((r['max_alpha'] for r in extra),default=0),
    'regions':regions,'failures':failures,'source_alpha_accepted':not failures,'production_adopted':False})
canon=json.loads((R/'qa/yang_lin_leg_rig_sources_20261019/canon_basis.json').read_text(encoding='utf-8'))
canon['scope']='Continuous clothing source layer only. Neutral cloth/leg topology and colors are art implementation, not novel-prescribed costume or an injury state.'
assert (Q/'canon_basis.json').exists()
print(json.dumps({'sha256':sha(target),'main_components':len(main),'extra_components':len(extra),'source_alpha_accepted':not failures,'failures':failures,'regions':[{'direction':r['direction'],'leg':r['leg'],'region':r['region']} for r in regions]}))
