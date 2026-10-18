import copy,hashlib,json,pathlib,shutil
import numpy as np
from PIL import Image
R=pathlib.Path('D:/AI项目/水浒/开发工程');E=pathlib.Path(__file__).parent
S=R/'assets/characters/tribute_cart_wheel_layers_20261018';Q=R/'qa/tribute_cart_wheel_layers_20261018'
assert not S.exists() and not Q.exists();S.mkdir();Q.mkdir();(S/'.gdignore').write_bytes(b'');(Q/'.gdignore').write_bytes(b'')
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def save(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode())
request=json.loads((E/'requests.json').read_text('utf-8'));baseline=json.loads((R/'assets/direction4/level1_ruan_xiaoqi_layered_20261018.json').read_text('utf-8'));old=baseline['sources']['cart_only'];assert sha(R/old['path'])==old['sha256']
body_regions={d:[627 if d in ['sw','nw'] else 0,627 if d in ['ne','nw'] else 0,627,627] for d in ['se','sw','ne','nw']}
wheel_regions={'se':[0,0,627,730],'sw':[627,0,627,730],'ne':[0,730,627,524],'nw':[627,730,627,524]}
for row in request['sources']:
 original=pathlib.Path(row['generated_original']);dest=S/row['filename'];shutil.copyfile(original,dest);assert sha(original)==sha(dest)
 row.update(path=dest.relative_to(R).as_posix(),sha256=sha(dest),status='isolated_component_candidate',runtime_adopted=False,references=[{'path':p,'sha256':sha(p)} for p in row['request']['referenced_image_paths']])
 with Image.open(dest) as im:a=np.asarray(im)[:,:,3];row['native_size']=list(im.size)
 row['geometry']={}
 for d,region in (body_regions if row['key']=='cart_body' else wheel_regions).items():
  x,y,w,h=region;mask=a[y:y+h,x:x+w]>=64;yy,xx=np.nonzero(mask);bounds=[x+int(xx.min()),y+int(yy.min()),x+int(xx.max())+1,y+int(yy.max())+1]
  edges=[int(mask[0,:].sum()),int(mask[-1,:].sum()),int(mask[:,0].sum()),int(mask[:,-1].sum())]
  row['geometry'][d]={'region':region,'strong_alpha_bounds_absolute':bounds,'strong_alpha_edge_counts':edges}
  assert not any(edges),(row['key'],d,edges)
request.update(schema='tribute_cart_wheel_component_sources_v1',source_views_directly_seen=8,script_bitmap_edits=False,runtime_adopted=False,native_preview_complete=False,rotating_animation_accepted=False,full_art_complete=False,original_production_cart=old,canon='Chapter16 explicitly loads eleven burdens into seven Jiangzhou carts and covers the treasure. Single central wooden wheel, exact chassis, grey-brown cloth, knots and movement are existing art interpretations, not verbatim original specifications. This component work changes no story/counts/mission/save state.',observations=['Cart body omits all four painted wheels; fixed axle ends are newly revealed. Original cart-like scale/shaft/cargo layout broadly retained on direct inspection, not a pixel-preservation guarantee.','Generated wheel-only view positions, scale and rim shape differ from original. SW crosses the nominal y627 cell boundary; custom non-overlapping wheel regions split at y730 retain the complete rims. Do not use equal quadrants for this wheel atlas.','No native/composite/rotation acceptance yet. Real contact, axle alignment, chassis occlusion, perspective and lighting need direct native comparison.','For perspective rotation do not simply spin the already elliptical PNG in screen space. Either author wheel phases or use a hub-centred in-plane projection with verified rim/lighting. Do not alter the fixed cart hull or animate it with the actor gait.'])
save(S/'prompt_set.json',request)
old_hubs={'se':[277,453],'sw':[982,483],'ne':[492,945],'nw':[778,975]};new_hubs={'se':[278,474],'sw':[994,516],'ne':[507,946],'nw':[839,994]};old_heights={'se':211,'sw':207,'ne':205,'nw':205}
layout={'schema':'unadopted_cart_wheel_layout_v1','native_size':[1254,1254],'original_cart_sha256':old['sha256'],'directions':{},'scope':'Manual approximate hub estimates and uniform wheel-height fit, no claim of original geometry equality, physical contact, native rendering or working animation.'}
wheel=next(x for x in request['sources'] if x['key']=='wheel_only')
for d in body_regions:
 bounds=wheel['geometry'][d]['strong_alpha_bounds_absolute'];scale=old_heights[d]/(bounds[3]-bounds[1]);translation=[old_hubs[d][i]-new_hubs[d][i]*scale for i in range(2)]
 layout['directions'][d]={'body_region':body_regions[d],'wheel_region':wheel_regions[d],'original_hub_estimate':old_hubs[d],'new_wheel_hub_estimate':new_hubs[d],'wheel_uniform_scale':scale,'wheel_translation_original_native':translation,'original_cart_pose':copy.deepcopy(baseline['poses']['cart_only_'+d]),'original_wheel_ground_contact':copy.deepcopy(old['wheel_contacts'][d])}
save(S/'component_layout.json',layout)
save(Q/'source_audit.json',{'source_pngs':2,'source_views_directly_seen':8,'original_and_copies_sha_match':True,'script_bitmap_edits':False,'all_selected_strong_alpha_edges_clear':True,'sources':request['sources'],'runtime_adopted':False,'native_preview_complete':False,'rotating_animation_accepted':False})
checks=[]
for n in ['runtime_inventory.json','preservation/protected_preflight.json','preservation/unrelated_before.json']:
 rows=json.loads((R/'qa/ruan_xiaoqi_grip_20261018'/n).read_text('utf-8'))
 for row in rows:assert sha(R/row['path'])==row['sha256'],row['path']
 checks.append({'inventory':n,'unchanged':len(rows),'differences':[]})
save(Q/'production_preservation.json',{'inventories':checks,'production_cart_sha256':sha(R/old['path']),'production_applied':False,'scope':'Listed runtime/protected/unrelated byte preservation only; new isolated sources change future canonical identity.'})
shutil.copyfile(__file__,Q/'prepare_sources.py')
print(json.dumps({'source_pngs':2,'views_seen':8,'wheel_regions':wheel_regions,'geometries':[{x['key']:x['geometry']} for x in request['sources']],'production_applied':False},ensure_ascii=False))
