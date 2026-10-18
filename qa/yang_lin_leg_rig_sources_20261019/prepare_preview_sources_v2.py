"""Preview bindings preserve raw pixels; strict failed alpha-edge gate stays failed."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
Q=Path(__file__).resolve().parent
diagnostics=json.loads((Q/'source_components_v1.json').read_text(encoding='utf-8'))
rows=[]
for source in diagnostics:
    key=source['key'];path=Q/'native_originals'/(key+'.png')
    assert hashlib.sha256(path.read_bytes()).hexdigest()==source['sha256']
    with Image.open(path) as im:alpha=np.asarray(im.getchannel('A'))
    torso=key.startswith('torso');xs=[0,627,1254] if torso else [0,313,627,940,1254]
    regions=[]
    for row_index,(top,bottom) in enumerate([(0,627),(627,1254)]):
        for col,(left,right) in enumerate(zip(xs,xs[1:])):
            main=[c for c in source['main'] if left<=c['bbox'][0] and c['bbox'][2]<=right and top<=c['bbox'][1] and c['bbox'][3]<=bottom]
            assert len(main)==1
            bx,by,br,bb=main[0]['bbox']
            x=max(left,bx-12);y=max(top,by-12);r=min(right,br+12);b=min(bottom,bb+12)
            cut=alpha[y:b,x:r]
            edges=np.concatenate([cut[0],cut[-1],cut[:,0],cut[:,-1]])
            direction=['se','sw','ne','nw'][row_index*2+col] if torso else ['se','sw','ne','nw'][col]
            regions.append({'direction':direction,'leg':None if torso else ['right','left'][row_index],
                            'region':[x,y,r-x,b-y],'main_component':main[0],
                            'edge_nonzero_pixels':int(np.count_nonzero(edges)),
                            'edge_max_alpha':int(edges.max()),'edge_clear':not np.any(edges)})
    rows.append({'key':key,'source':'native_originals/'+key+'.png','sha256':source['sha256'],'regions':regions,
                 'other_component_pixels':source['other_pixels'],'other_component_max_alpha':source['other_max_alpha']})
result={'sources':rows,'scope':'Preview-only fixed spatial rectangles. All complete main components retained, no source PNG writes or alpha mask. Edge noise remains an unresolved source qualification issue.',
        'prior_strict_preparation':'prepare_sources.py','prior_strict_exit_code':1,
        'prior_failure':"AssertionError: ('thighs_v1', 0, 0, [False, False, True, False]) while expanding raw-alpha edge",
        'prior_failure_reclassified':False,'strict_alpha_edges_accepted':False,
        'production_adopted':False,'native_accepted':False}
with (Q/'preview_sources_v2.json').open('x',encoding='utf-8') as stream:stream.write(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps([{'key':r['key'],'regions':len(r['regions']),'edge_hits':sum(x['edge_nonzero_pixels'] for x in r['regions'])} for r in rows]))
