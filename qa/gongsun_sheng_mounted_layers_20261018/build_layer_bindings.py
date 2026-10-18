"""Author one fixed horse transform and one rider scale per direction for all states."""
from pathlib import Path
import hashlib,json
from PIL import Image
Q=Path(__file__).resolve().parent;R=Q.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
states={'sheathed_idle':'rider_sheathed_idle_v2','reach':'rider_reach_v2','draw_mid':'rider_draw_mid_v1','point':'rider_point_v1','drawn_recoil':'rider_drawn_recoil_v1','drawn_recover':'rider_drawn_recover_v1','sheathed_recoil':'rider_sheathed_recoil_v1','sheathed_recover':'rider_sheathed_recover_v1'}
horse={
'se':{'scale':.97,'offset':[9.61,3.43],'rein':[348,266]},
'sw':{'scale':.97,'offset':[35.23,3.43],'rein':[936,267]},
'ne':{'scale':.91,'offset':[42.03,112.96],'rein':[370,829]},
'nw':{'scale':.91,'offset':[103.31,112.96],'rein':[935,833]}}
palms={
'se':{'drawn_recoil':[365,291],'drawn_recover':[370,302],'point':[374,302],'sheathed_idle':[365,298],'sheathed_recoil':[365,291],'sheathed_recover':[365,288],'reach':[377,302],'draw_mid':[377,302]},
'sw':{'drawn_recoil':[960,302],'drawn_recover':[960,312],'point':[963,309],'sheathed_idle':[940,305],'sheathed_recoil':[936,294],'sheathed_recover':[936,288],'reach':[877,303],'draw_mid':[877,303]},
'ne':{'drawn_recoil':[354,908],'drawn_recover':[356,915],'point':[356,914],'sheathed_idle':[354,908],'sheathed_recoil':[354,897],'sheathed_recover':[354,897],'reach':[355,902],'draw_mid':[355,902]},
'nw':{'drawn_recoil':[917,909],'drawn_recover':[917,919],'point':[917,920],'sheathed_idle':[899,908],'sheathed_recoil':[899,897],'sheathed_recover':[899,897],'reach':[899,903],'draw_mid':[899,903]}}
textures={}
for key in ['horse_idle_v1']+list(states.values()):
    p=Q/'native_originals'/(key+'.png');im=Image.open(p);assert im.mode=='RGBA' and im.size==(1254,1254)
    textures[key]={'canonical_source':p.relative_to(R).as_posix(),'file':'images/'+key+'.png','sha256':sha(p),'rgba8_sha256':hashlib.sha256(im.tobytes()).hexdigest()}
reference=R/'qa/gongsun_sheng_mounted_hurt_sources_20261018/native_originals/drawn_recoil_v1.png';im=Image.open(reference)
textures['original_recoil']={'canonical_source':reference.relative_to(R).as_posix(),'file':'images/original_recoil.png','sha256':sha(reference),'rgba8_sha256':hashlib.sha256(im.tobytes()).hexdigest()}
views={}
for i,d in enumerate(['se','sw','ne','nw']):
    h=horse[d];target=[h['rein'][j]*h['scale']+h['offset'][j] for j in range(2)]
    views[d]={'region':[(i%2)*627,(i//2)*627,627,627],'horse':h,'rider_scale':.8,'target_rein':target,'phases':{}}
    for phase in states:
        hand=palms[d][phase];views[d]['phases'][phase]={'texture':states[phase],'scale':.8,'offset':[target[j]-hand[j]*.8 for j in range(2)],'manual_visible_rein_hand':hand,'manual_uncertainty_source_pixels':8 if d in ['ne','nw'] else 5,'hidden_hand_measured':False,'physical_contact_accepted':False}
save(Q/'layer_bindings.json',{'scope':'Fixed standing horse plus rider pose layers, translation registration only. Browser composition checked for first two rider states; complete arm/weapon/feet continuity and native/Unit/chapter acceptance remain open.','textures':textures,'states':states,'views':views,'canon_basis':'qa/gongsun_sheng_mounted_topology_20261018/source_basis.json','canon_basis_sha256':sha(R/'qa/gongsun_sheng_mounted_topology_20261018/source_basis.json'),'horse_transform_fixed_across_states':True,'rider_scale_fixed_across_states':True,'source_png_pixel_writes':False,'production_adopted':False,'native_executed':False,'full_draw_recovery_accepted':False})
rows=[]
for p in sorted(Q.glob('source_*.json')):
    row=json.loads(p.read_text());assert sha(Q/row['file'])==row['sha256'];row['directly_viewed']=True;row['selected_for_comparison']=row['key'] in ['horse_idle_v1']+list(states.values());rows.append(row)
save(Q/'prompt_set.json',{'mode':'builtin_imagegen','originals':len(rows),'selected_for_comparison':9,'rejected_or_superseded':{'rider_sheathed_idle_v1':'Hollow-looking pommel confused hilt with an empty scabbard.','rider_reach_v1':'Rear views use a different sword arm from point reference.'},'sources':rows,'canon':'Chapter54 only: star crown/cloud robe, short fringed cord, one back sword and yellow-flowered horse. Exact hue/tack/saddle and reach/draw/hit timing are game art interpretation. No new plot injury, magic or weapon.','production_adopted':False})
save(Q/'source_review.json',{'directly_viewed_originals':len(rows),'selected_comparison_pngs':9,'new_native_accepted':False,'browser_first_recoil_recover_viewed':True,'observations':['Horse source is drawn unchanged at one transform for every rider state, eliminating per-state horse redraw drift by composition.','Extracted rider is larger than old composite; a fixed 0.8 rider scale is provisional per-family calibration, not per-frame fitting.','Reach v1 rear sword arm discontinuity rejected. Reach v2 and partial draw have improved cross-shoulder pose, but fingers/occlusion/anatomy still need enlarged and temporal review.','Sheathed idle v1 hollow-looking pommels superseded by solid-cap v2.','Partial draw has a visible connected blade section and only one hilt; complete unsheathing/return and rein/boot/seat continuity are not accepted.'],'full_draw_recovery_accepted':False,'actual_unit_tested':False,'production_adopted':False})
print(json.dumps({'originals':len(rows),'selected_for_comparison':9,'rider_states':8,'local_pixel_writes':0}))
