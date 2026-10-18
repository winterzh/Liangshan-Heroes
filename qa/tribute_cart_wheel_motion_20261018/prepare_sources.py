import hashlib,json,pathlib,shutil
import numpy as np
from PIL import Image
from scipy import ndimage
R=pathlib.Path('D:/AI项目/水浒/开发工程');E=pathlib.Path(__file__).parent;S=R/'assets/characters/tribute_cart_wheel_motion_20261018';assert not S.exists();S.mkdir();(S/'.gdignore').write_bytes(b'')
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def save(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode())
raw=json.loads((E/'requests.json').read_text('utf-8'));regions={'se':[0,0,627,730],'sw':[627,0,627,730],'ne':[0,730,627,524],'nw':[627,730,627,524]};masks={}
for row in raw['sources']:
 p=S/row['filename'];shutil.copyfile(row['generated_original'],p);assert sha(p)==sha(row['generated_original'])
 with Image.open(p) as im:a=np.asarray(im)[:,:,3];size=list(im.size)
 row.update(path=p.relative_to(R).as_posix(),sha256=sha(p),native_size=size,references=[{'path':n,'sha256':sha(n)} for n in row['request']['referenced_image_paths']],runtime_adopted=False,geometry={})
 masks[row['key']]={}
 for d,(x,y,w,h) in regions.items():
  mask=a[y:y+h,x:x+w]>=64;yy,xx=np.nonzero(mask);edges=[int(mask[0,:].sum()),int(mask[-1,:].sum()),int(mask[:,0].sum()),int(mask[:,-1].sum())];assert not any(edges),(row['key'],d,edges)
  row['geometry'][d]={'region':[x,y,w,h],'strong_alpha_bounds_absolute':[x+int(xx.min()),y+int(yy.min()),x+int(xx.max())+1,y+int(yy.max())+1],'strong_alpha_edge_counts':edges};masks[row['key']][d]=mask
raw.update(schema='unadopted_cart_wheel_motion_sources_v1',source_views_directly_seen=8,script_bitmap_edits=False,runtime_adopted=False,native_complete=False,actual_game_rolling_accepted=False,full_art_complete=False,canon='Chapter16 cart/covered treasure continues; exact wheel structure/colour and animation layers are art interpretations. No change to seven-cart/eleven-burden story quantity, mission, unit, save or balance.',observations=['Separate rim+hub and spoke stars generated from the prior unadopted complete-wheel atlas. All four views directly inspected.','Generator changed component scales/positions/shapes despite preservation request. Independent measured registrations are required; no exact unchanged-pixel claim.','Spoke-plane affine display transform/inner-rim clipping is a prototype rendering operation, not a rewritten bitmap. Rim/hub must remain stationary relative to the chassis while spokes turn. Final physical rolling, shading and native gameplay remain unaccepted.'])
save(S/'prompt_set.json',raw)
old=json.loads((R/'assets/characters/tribute_cart_wheel_layers_20261018/component_layout.json').read_text('utf-8'));heights={'se':211,'sw':207,'ne':205,'nw':205};fit={'schema':'experimental_spoke_plane_fit_v1','scope':'Read-only alpha-region moments plus original contact-height registration. These mathematical fits do not prove physical axle contact, source fidelity, native rendering or true rolling.','directions':{}}
for d,(x,y,w,h) in regions.items():
 mask=masks['rim_hub'][d];labels,count=ndimage.label(mask);sizes=np.bincount(labels.ravel());sizes[0]=0;order=np.argsort(sizes)[::-1];assert sizes[order[1]]>100
 ring=labels==order[0];hub=labels==order[1];yy,xx=np.nonzero(ring);bottomx=float(np.median(xx[yy>=yy.max()-1]))+x;bottomy=float(yy.max()+1+y);sr=heights[d]/(yy.max()+1-yy.min());target=old['directions'][d]['original_wheel_ground_contact'];tr=[target[0]-bottomx*sr,target[1]-bottomy*sr]
 holes,n=ndimage.label(~ring);hs=np.bincount(holes.ravel());outside=set(holes[0,:])|set(holes[-1,:])|set(holes[:,0])|set(holes[:,-1]);candidates=[i for i in range(1,n+1) if i not in outside];assert candidates
 hole=holes==max(candidates,key=lambda i:hs[i]);hy,hx=np.nonzero(hole);pts=np.stack([hx+x,hy+y],axis=1).astype(float);rc=pts.mean(axis=0);cov=np.cov(pts.T,bias=True);values,vectors=np.linalg.eigh(cov);ar=vectors@np.diag(2*np.sqrt(values))
 sy,sx=np.nonzero(masks['spokes'][d]);pts=np.stack([sx+x,sy+y],axis=1).astype(float);sc=pts.mean(axis=0);values,vectors=np.linalg.eigh(np.cov(pts.T,bias=True));base=vectors@np.diag(np.sqrt(values));rad=np.linalg.norm((np.linalg.inv(base)@(pts-sc).T).T,axis=1);asp=base*np.percentile(rad,99.9)
 fit['directions'][d]={'region':regions[d],'rim_uniform_scale':float(sr),'rim_translation_original_native':[float(v) for v in tr],'rim_bottom_native':[bottomx,bottomy],'target_ground_original_native':target,'rim_plane_center':rc.tolist(),'rim_inner_plane_axes':ar.tolist(),'spoke_plane_center':sc.tolist(),'spoke_normalization_axes':asp.tolist(),'spoke_end_overlap':1.06,'clip_inner_radius':1.04,'original_cart_pose':old['directions'][d]['original_cart_pose'],'phase_sign':1 if d in ['se','ne'] else -1,'test_radius_original_native':heights[d]/2}
save(S/'projection_fit.json',fit);save(E/'source_audit.json',{'source_pngs':2,'source_views_directly_seen':8,'original_copies_sha_match':True,'runtime_adopted':False,'native_complete':False,'sources':raw['sources']})
print(json.dumps({'sources':2,'views':8,'fit_directions':4,'bitmap_pixels_modified':False,'native_complete':False,'fit_summary':{d:{k:v[k] for k in ['rim_uniform_scale','rim_plane_center','spoke_plane_center']} for d,v in fit['directions'].items()}}))
