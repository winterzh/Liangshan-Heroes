"""Read-only component diagnostics and spatial regions for modular source sheets."""
from pathlib import Path
import hashlib,json
import numpy as np
from scipy import ndimage
from PIL import Image
Q=Path(__file__).resolve().parent
rows=[]
for key in ['torso_v1','thighs_v1','shins_v1','boots_v1']:
    path=Q/'native_originals'/(key+'.png')
    source=json.loads((Q/('source_'+key+'.json')).read_text(encoding='utf-8'))
    assert hashlib.sha256(path.read_bytes()).hexdigest()==source['sha256']
    with Image.open(path) as im:
        assert im.mode=='RGBA' and im.size==(1254,1254)
        alpha=np.asarray(im.getchannel('A'))
    labels,count=ndimage.label(alpha>0,structure=np.ones((3,3),dtype=np.uint8))
    objects=ndimage.find_objects(labels);areas=np.bincount(labels.ravel())
    comps=[]
    for i,slices in enumerate(objects,1):
        ys,xs=slices;values=alpha[slices][labels[slices]==i]
        comps.append({'id':i,'pixels':int(areas[i]),'bbox':[xs.start,ys.start,xs.stop,ys.stop],
                      'max_alpha':int(values.max())})
    comps.sort(key=lambda c:c['pixels'],reverse=True)
    n=4 if key.startswith('torso') else 8
    main=comps[:n]
    extras=comps[n:]
    assert max((c['max_alpha'] for c in extras),default=0)<=2,(key,extras[:3])
    xs=[0,627,1254] if n==4 else [0,313,627,940,1254]
    regions=[]
    for row_index,(top,bottom) in enumerate([(0,627),(627,1254)]):
        for col,(left,right) in enumerate(zip(xs,xs[1:])):
            owned=[c for c in main if left<=c['bbox'][0] and c['bbox'][2]<=right and top<=c['bbox'][1] and c['bbox'][3]<=bottom]
            assert len(owned)==1,(key,row_index,col,owned,main)
            c=owned[0];bx,by,br,bb=c['bbox']
            x=max(left+1,bx-12);y=max(top+1,by-12);r=min(right-1,br+12);b=min(bottom-1,bb+12)
            for attempt in range(64):
                cut=alpha[y:b,x:r]
                hits=[np.any(cut[:,0]),np.any(cut[0]),np.any(cut[:,-1]),np.any(cut[-1])]
                if not any(hits):break
                x-=bool(hits[0]);y-=bool(hits[1]);r+=bool(hits[2]);b+=bool(hits[3])
                assert left<x<r<right and top<y<b<bottom,(key,row_index,col,hits)
            else:raise AssertionError('Sampling edge expansion exhausted')
            direction=['se','sw','ne','nw'][row_index*2+col] if n==4 else ['se','sw','ne','nw'][col]
            regions.append({'direction':direction,'leg':None if n==4 else ['right','left'][row_index],
                            'cell':[left,top,right-left,bottom-top],'region':[x,y,r-x,b-y],
                            'main_component':c,'edge_alpha_nonzero_pixels':0})
    rows.append({'key':key,'source':source['file'],'sha256':source['sha256'],'regions':regions,
                 'alpha_zero_pixels':int(np.count_nonzero(alpha==0)),
                 'other_component_pixels':sum(c['pixels'] for c in extras),
                 'other_component_max_alpha':max((c['max_alpha'] for c in extras),default=0)})
result={'scope':'Raw original alpha>0 components and explicit sampling rectangles only. No PNG writes or alpha mask. Faint isolated pixels outside sampled parts remain in original files.',
        'sources':rows,'production_adopted':False,'native_accepted':False}
with (Q/'prepared_sources_v1.json').open('x',encoding='utf-8') as stream:stream.write(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps([{'key':r['key'],'regions':len(r['regions']),'other_max_alpha':r['other_component_max_alpha']} for r in rows]))
