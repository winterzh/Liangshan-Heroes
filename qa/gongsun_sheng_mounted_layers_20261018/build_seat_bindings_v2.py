"""Separate rein attachment from the rider's fixed seat; never edit PNG pixels."""
from pathlib import Path
import copy,hashlib,json
from PIL import Image
Q=Path(__file__).resolve().parent;R=Q.parents[1]
data=json.loads((Q/'layer_bindings.json').read_text());old=copy.deepcopy(data)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    if p.exists():
        assert json.loads(p.read_text())==x,'Never overwrite a different prepared binding'
        return
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
data['textures'].pop('horse_idle_v1')
for key in ['horse_no_reins_v2','rein_material_v1']:
    p=Q/'native_originals'/(key+'.png');im=Image.open(p);assert im.size==(1254,1254) and im.mode=='RGBA'
    data['textures'][key]={'canonical_source':p.relative_to(R).as_posix(),'file':'images/'+key+'.png','sha256':sha(p),'rgba8_sha256':hashlib.sha256(im.tobytes()).hexdigest()}
waists={
'se':{'drawn_recoil':[286,285],'drawn_recover':[286,290],'point':[286,290],'sheathed_idle':[286,281],'sheathed_recoil':[286,264],'sheathed_recover':[286,264],'reach':[286,282],'draw_mid':[286,282]},
'sw':{'drawn_recoil':[974,284],'drawn_recover':[974,289],'point':[974,289],'sheathed_idle':[974,281],'sheathed_recoil':[974,264],'sheathed_recover':[974,264],'reach':[974,282],'draw_mid':[974,282]},
'ne':{'drawn_recoil':[280,897],'drawn_recover':[280,904],'point':[280,904],'sheathed_idle':[280,894],'sheathed_recoil':[280,880],'sheathed_recover':[280,880],'reach':[280,889],'draw_mid':[280,889]},
'nw':{'drawn_recoil':[974,898],'drawn_recover':[974,903],'point':[974,903],'sheathed_idle':[974,894],'sheathed_recoil':[974,880],'sheathed_recover':[974,880],'reach':[974,889],'draw_mid':[974,889]}}
bits={'se':[499,288],'sw':[780,284],'ne':[517,848],'nw':[753,848]}
for direction,view in data['views'].items():
    base=view['phases']['drawn_recoil']['offset'];anchor=waists[direction]['drawn_recoil'];scale=view['rider_scale']
    target=[anchor[j]*scale+base[j] for j in range(2)]
    view['horse_texture']='horse_no_reins_v2';view['seat_waist_target']=target;view['horse']['bit_source']=bits[direction]
    for phase,pose in view['phases'].items():
        pose['manual_seat_waist_source']=waists[direction][phase]
        pose['offset']=[target[j]-waists[direction][phase][j]*scale for j in range(2)]
        pose['rein_hand_target']=[pose['manual_visible_rein_hand'][j]*scale+pose['offset'][j] for j in range(2)]
        pose['registration']='Provisional manual waist/seat proxy; fixed directional rider scale, phase translation only. Rein follows hand, never translate rider merely to touch a static rein.'
data.update(scope='Three layers: one unchanged standing horse, one fixed-scale rider registered at a provisional waist/seat proxy, painted rein ribbon joins bit and phase-specific hand. Native/Unit/complete draw/seat anatomy not accepted.',rein={'texture':'rein_material_v1','sample_region':[96,600,1060,54],'width_native':4,'sag_native':16,'segments':24,'paired_reins':True,'note':'Raw PNG retained; faint alpha1 dust outside used strip is not sampled. Material is an imagegen-painted bitmap; canvas/native runtime only deforms that texture.'},registration_strategy='seat_translation_and_independent_textured_reins',native_executed=False,production_adopted=False)
save(Q/'layer_bindings_v2.json',data)
save(Q/'binding_v1_limitation.json',{'source':'layer_bindings.json','scope':'V1 first two hurt/recovery browser composites only. Full eight-state hand-to-static-rein pinning was never accepted or run natively.','reason':'In reach SW the free rein hand moves substantially while waist stays in place. Translating the whole rider to a static rein moves him off the saddle. V2 registers waist/seat provisionally and attaches an independent painted rein ribbon.','replaced_by':'layer_bindings_v2.json','source_pngs_repainted_locally':False})
rows=[]
for p in sorted(Q.glob('source_*.json')):
    row=json.loads(p.read_text())
    if 'file' not in row:continue
    assert sha(Q/row['file'])==row['sha256'];row['directly_viewed']=True;row['selected_for_v2_comparison']=row['key'] in ['horse_no_reins_v2','rein_material_v1']+list(data['states'].values());rows.append(row)
save(Q/'prompt_set_v2.json',{'mode':'builtin_imagegen','originals':len(rows),'selected_for_comparison':10,'sources':rows,'superseded_or_rejected':{'horse_idle_v1':'Painted fixed reins fit first hurt pair but not all hand positions; superseded by rein-free horse and independent strap texture.','rider_sheathed_idle_v1':'Hollow-looking pommels.','rider_reach_v1':'Rear sword arm discontinuity.'},'canon_basis':data['canon_basis'],'canon_basis_sha256':data['canon_basis_sha256'],'production_adopted':False})
# Browser uses the exact same binding data intended for native rendering.
with (Q/'layer_data.js').open('x',encoding='utf-8') as f:f.write('window.GSLayers = '+json.dumps(data,ensure_ascii=False,separators=(',',':'))+';\n')
print(json.dumps({'sources':len(rows),'selected':10,'fixed_rider_scales':[v['rider_scale'] for v in data['views'].values()],'rein_is_painted_texture':True}))
