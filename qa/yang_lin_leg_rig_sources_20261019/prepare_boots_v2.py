"""Preserve built-in low-boot edit, then prepare preview-only source rectangles."""
from pathlib import Path
import datetime,hashlib,json,shutil,sys
import numpy as np
from scipy import ndimage
from PIL import Image
Q=Path(__file__).resolve().parent
generated=Path(sys.argv[1]).resolve();target=Q/'native_originals/boots_v2.png'
assert not target.exists()
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
args_file=Q/'tool_prompt_boots_v2.json';args=json.loads(args_file.read_text(encoding='utf-8'))
shutil.copyfile(generated,target);assert sha(generated)==sha(target)
with Image.open(target) as im:
    assert im.mode=='RGBA' and im.size==(1254,1254)
    alpha=np.asarray(im.getchannel('A'))
row={'key':'boots_v2','mode':'builtin_imagegen','intent':'remove_extra_boot_shaft_edit',
     'file':'native_originals/boots_v2.png','generated_original':str(generated),'sha256':sha(target),'bytes':target.stat().st_size,
     'pixel_mode':'RGBA','size':[1254,1254],'exact_tool_arguments':args_file.name,
     'prompt_sha256':hashlib.sha256(args['prompt'].encode()).hexdigest(),
     'references':[{'path':p,'sha256':sha(Path(p)),'role':'edit_target'} for p in args['referenced_image_paths']],
     'local_pixel_writes':False,'production_adopted':False,'native_accepted':False,'recorded_at':datetime.datetime.now().isoformat()}
with (Q/'source_boots_v2.json').open('x',encoding='utf-8') as stream:stream.write(json.dumps(row,ensure_ascii=False,indent=2)+'\n')
labels,count=ndimage.label(alpha>0,structure=np.ones((3,3),dtype=np.uint8));objects=ndimage.find_objects(labels);areas=np.bincount(labels.ravel());comps=[]
for i,slices in enumerate(objects,1):
    ys,xs=slices;values=alpha[slices][labels[slices]==i]
    comps.append({'id':i,'pixels':int(areas[i]),'bbox':[xs.start,ys.start,xs.stop,ys.stop],'max_alpha':int(values.max())})
comps.sort(key=lambda c:c['pixels'],reverse=True);main=comps[:8];other=comps[8:]
assert max((c['max_alpha'] for c in other),default=0)<=2
regions=[];xs=[0,313,627,940,1254]
for ri,(top,bottom) in enumerate([(0,627),(627,1254)]):
    for ci,(left,right) in enumerate(zip(xs,xs[1:])):
        owned=[c for c in main if left<=c['bbox'][0] and c['bbox'][2]<=right and top<=c['bbox'][1] and c['bbox'][3]<=bottom]
        assert len(owned)==1
        bx,by,br,bb=owned[0]['bbox'];x=max(left,bx-12);y=max(top,by-12);r=min(right,br+12);b=min(bottom,bb+12)
        cut=alpha[y:b,x:r];edge=np.concatenate([cut[0],cut[-1],cut[:,0],cut[:,-1]])
        regions.append({'direction':['se','sw','ne','nw'][ci],'leg':['right','left'][ri],
                        'region':[x,y,r-x,b-y],'main_component':owned[0],
                        'edge_nonzero_pixels':int(np.count_nonzero(edge)),'edge_max_alpha':int(edge.max()),'edge_clear':not np.any(edge)})
new_source={'key':'boots_v2','source':row['file'],'sha256':row['sha256'],'regions':regions,
            'other_component_pixels':sum(c['pixels'] for c in other),'other_component_max_alpha':max((c['max_alpha'] for c in other),default=0)}
binding=json.loads((Q/'preview_sources_v2.json').read_text(encoding='utf-8'))
binding['sources']=[new_source if s['key']=='boots_v1' else s for s in binding['sources']]
binding['strict_alpha_edges_accepted']=False
binding['revision_note']='Low boots replace shafts for ankle overlap preview; all previous source/strict-edge failures retained.'
with (Q/'preview_sources_v3.json').open('x',encoding='utf-8') as stream:stream.write(json.dumps(binding,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'source_sha256':row['sha256'],'main':main,'edge_hits':sum(r['edge_nonzero_pixels'] for r in regions)}))
