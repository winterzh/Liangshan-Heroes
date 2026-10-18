"""Record component geometry independently of the failed margin preparation."""
from pathlib import Path
import hashlib,json
import numpy as np
from scipy import ndimage
from PIL import Image
Q=Path(__file__).resolve().parent
rows=[]
for key in ['torso_v1','thighs_v1','shins_v1','boots_v1']:
    path=Q/'native_originals'/(key+'.png')
    with Image.open(path) as im:alpha=np.asarray(im.getchannel('A'))
    labels,count=ndimage.label(alpha>0,structure=np.ones((3,3),dtype=np.uint8))
    objects=ndimage.find_objects(labels);areas=np.bincount(labels.ravel());comps=[]
    for i,slices in enumerate(objects,1):
        ys,xs=slices;values=alpha[slices][labels[slices]==i]
        comps.append({'id':i,'pixels':int(areas[i]),'bbox':[xs.start,ys.start,xs.stop,ys.stop],'max_alpha':int(values.max())})
    comps.sort(key=lambda c:c['pixels'],reverse=True)
    n=4 if key.startswith('torso') else 8
    rows.append({'key':key,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'main':comps[:n],
                 'other_pixels':sum(c['pixels'] for c in comps[n:]),'other_max_alpha':max((c['max_alpha'] for c in comps[n:]),default=0)})
with (Q/'source_components_v1.json').open('x',encoding='utf-8') as stream:stream.write(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(rows))
