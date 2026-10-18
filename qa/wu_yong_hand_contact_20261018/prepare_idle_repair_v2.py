"""Create a new isolated idle comparison; PNGs copied verbatim, never repainted."""
from pathlib import Path
import copy,hashlib,json,shutil
from PIL import Image
R=Path(__file__).resolve().parents[2]
Q=Path(__file__).resolve().parent
E=Path('D:/CodexEvidence/shuihu/wu_yong_idle_rear_repair_v2_20261018')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
assert not E.exists(),'Immutable preparation already exists'
new=Q/'native_originals/idle_rear_grip_v2.png'
original=Path('C:/Users/rsb/.codex/generated_images/01a11902-b95a-7981-aed1-f143736f8853/exec-81c6a532-27a0-4007-bcba-134a6db044ab.png')
new.parent.mkdir(exist_ok=True)
assert not new.exists()
shutil.copyfile(original,new);assert sha(new)==sha(original)
base=json.loads((Q/'prepared_inputs.json').read_text())
P=E/'prepared';(P/'images').mkdir(parents=True)
data={'scope':'Idle-only raw source and fixed-scale two-handle comparison. Rear far hand is occluded and unmeasured. Not Unit, gait or adoption acceptance.','textures':{},'views':{}}
sources={'cart':R/'assets/characters/liu_tang_pushcart_20261017/cart_only.png','old':R/'qa/wu_yong_layered_sources_20261018/native_originals/idle_actor.png','new':new}
template=(R/'assets/characters/liu_tang_pushcart_20261017/cart_only.png.import').read_text()
for key,src in sources.items():
    im=Image.open(src);assert im.size==(1254,1254) and im.mode=='RGBA'
    dst=P/'images'/f'{key}.png';shutil.copyfile(src,dst);assert sha(src)==sha(dst)
    # Keep the adopted texture's native pixel-preserving import policy.
    descriptor=template.replace('res://assets/characters/liu_tang_pushcart_20261017/cart_only.png',f'res://images/{key}.png')
    descriptor='\n'.join(line for line in descriptor.splitlines() if not line.startswith('uid='))+'\n'
    (Path(str(dst)+'.import')).write_text(descriptor,encoding='utf-8')
    data['textures'][key]={'file':f'images/{key}.png','canonical_source':src.relative_to(R).as_posix(),'sha256':sha(src),'rgba8_sha256':hashlib.sha256(im.tobytes()).hexdigest()}
new_hands={'se':[[139,326],[332,294]],'sw':[[1126,330],[943,294]],'ne':[[358,886]],'nw':[[895,889]]}
for direction in ['se','sw','ne','nw']:
    item=base['views'][direction]['idle'];cart=base['cart_poses'][direction];reg=base['semantic_hand_registration'][direction]
    targets=reg['fixed_cart_targets'];ref=reg['fixed_actor_reference'];hands=new_hands[direction]
    pp=[sum(h[i]-(t[i]-cart['pivot_native'][i])*ref/cart['virtual_canvas_reference'] for h,t in zip(hands,targets))/len(hands) for i in range(2)]
    pose=copy.deepcopy(item['actor_pose']);pose['pivot_native']=pp;pose['region']=item['actor_region']
    old=copy.deepcopy(item['actor_pose']);old['region']=item['actor_region']
    # A second handle target for diagnostics only; it is not a measured hidden hand.
    both=targets if len(targets)==2 else [targets[0],{'ne':[64,1008],'nw':[1182,1021]}[direction]]
    boxes=[]
    for key,p in [('cart',cart),('old',old),('new',pose)]:
        region=p['region'];alpha=Image.open(P/data['textures'][key]['file']).getchannel('A').crop((region[0],region[1],region[0]+region[2],region[1]+region[3]))
        bb=alpha.point(lambda x:255 if x>=64 else 0).getbbox();assert bb
        sc=160/p['virtual_canvas_reference'];piv=p['pivot_native']
        boxes.append([(bb[0]+region[0]-piv[0])*sc,(bb[1]+region[1]-piv[1])*sc,(bb[2]+region[0]-piv[0])*sc,(bb[3]+region[1]-piv[1])*sc])
    union=[min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes)]
    fit=min(450/(union[2]-union[0]),410/(union[3]-union[1]))
    data['views'][direction]={'cart_pose':cart,'old_pose':old,'new_pose':pose,'cart_targets':both,'new_manual_visible_palms':hands,'uncertainty_source_px':6,'hidden_far_hand_measured':False if direction in ['ne','nw'] else None,'fixed_actor_reference':ref,'fit':{'scale':fit,'origin':[256-(union[0]+union[2])*fit/2,265-(union[1]+union[3])*fit/2]}}
save(P/'inputs.json',data)
shutil.copyfile(Q/'idle_repair_v2_preview.gd.txt',P/'preview.gd')
shutil.copyfile(Path(json.loads((Q/'prepared_binding.json').read_text())['project'])/'project.godot',P/'project.godot')
frozen=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(P.rglob('*')) if p.is_file()]
prior=Path(json.loads((Path('D:/CodexEvidence/shuihu/wu_yong_semantic_hand_registration_20261018/latest.json')).read_text())['receipt'])
binding={'prepared':True,'native_executed':False,'project':str(P),'frozen':frozen,'previous_receipt':str(prior),'scope':data['scope']}
save(E/'prepared_binding.json',binding);save(Q/'idle_repair_v2_binding.json',binding);save(Q/'idle_repair_v2_inputs.json',data)
prompt=json.loads((Q/'tool_prompt_idle_rear_grip_v2.json').read_text())
save(Q/'idle_repair_v2_source.json',{'mode':'builtin_imagegen','output':str(original),'project_source':str(new),'sha256':sha(new),'bytes':new.stat().st_size,'size':[1254,1254],'pixel_mode':'RGBA','exact_tool_prompt_json':'tool_prompt_idle_rear_grip_v2.json','prompt_sha256':hashlib.sha256(prompt['prompt'].encode()).hexdigest(),'references':[{'path':p,'sha256':sha(Path(p))} for p in prompt['referenced_image_paths']],'production_adopted':False,'native_executed_at_preparation':False,'direct_view':'Rear far fists no longer visibly rest at the lower back; near palms also moved up despite requested invariants. Must compare against the fixed cart before accepting. No PNG pixels edited locally.'})
print(json.dumps({'prepared':str(P),'files':len(frozen),'source_sha256':sha(new)}))
