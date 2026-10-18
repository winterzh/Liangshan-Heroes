"""New immutable comparison using the same fixed physical scale for every phase."""
from pathlib import Path
import copy,hashlib,json,shutil
from PIL import Image
R=Path(__file__).resolve().parents[2];Q=Path(__file__).resolve().parent
E=Path('D:/CodexEvidence/shuihu/wu_yong_push_gait_20261018')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
assert not E.exists(),'Do not modify an existing prepared candidate'
P=E/'prepared';(P/'images').mkdir(parents=True)
data=json.loads((R/'qa/wu_yong_hand_contact_20261018/prepared_inputs.json').read_text())
data['scope']='Wu corrected push gait: 5 fixed-scale phases, original fixed cart, native source/registered old-new comparison only. Far rear hands occluded; not actual Unit or whole-gait acceptance.'
selected={'idle':'qa/wu_yong_hand_contact_20261018/native_originals/idle_rear_grip_v2.png','contact_a':'qa/wu_yong_push_gait_20261018/native_originals/contact_a_v2.png','passing_a':'qa/wu_yong_push_gait_20261018/native_originals/passing_a_v1.png','contact_b':'qa/wu_yong_push_gait_20261018/native_originals/contact_b_v2.png','passing_b':'qa/wu_yong_push_gait_20261018/native_originals/passing_b_v1.png'}
hands={
'se':{'idle':[[139,326],[332,294]],'contact_a':[[171,326],[349,294]],'passing_a':[[171,323],[347,296]],'contact_b':[[172,329],[349,298]],'passing_b':[[173,329],[349,297]]},
'sw':{'idle':[[1126,330],[943,294]],'contact_a':[[1098,330],[904,303]],'passing_a':[[1094,331],[902,300]],'contact_b':[[1092,332],[905,303]],'passing_b':[[1090,336],[901,301]]},
'ne':{'idle':[[358,886]],'contact_a':[[378,889]],'passing_a':[[378,892]],'contact_b':[[378,892]],'passing_b':[[378,894]]},
'nw':{'idle':[[895,889]],'contact_a':[[882,892]],'passing_a':[[881,897]],'contact_b':[[880,897]],'passing_b':[[881,897]]}}
for phase,rel in selected.items():
    src=R/rel;im=Image.open(src);assert im.mode=='RGBA' and im.size==(1254,1254)
    data['textures']['new:'+phase]={'file':'images/new_'+phase+'.png','canonical_source':rel,'sha256':sha(src),'rgba8_sha256':hashlib.sha256(im.tobytes()).hexdigest()}
template=(R/'assets/characters/liu_tang_pushcart_20261017/cart_only.png.import').read_text()
import re
for key,row in data['textures'].items():
    src=R/row['canonical_source'];dst=P/row['file'];assert sha(src)==row['sha256'];shutil.copyfile(src,dst)
    resource='res://'+row['file'];cache='res://.godot/imported/'+dst.name+'-'+hashlib.md5(resource.encode()).hexdigest()+'.ctex'
    descriptor=template.replace('res://assets/characters/liu_tang_pushcart_20261017/cart_only.png',resource)
    descriptor=re.sub(r'res://\.godot/imported/[^"\n]+\.ctex',cache,descriptor)
    descriptor='\n'.join(line for line in descriptor.splitlines() if not line.startswith('uid='))+'\n'
    Path(str(dst)+'.import').write_text(descriptor,encoding='utf-8')
for direction,phases in data['views'].items():
    cart=data['cart_poses'][direction];reg=data['semantic_hand_registration'][direction]
    ref=reg['fixed_actor_reference'];targets=reg['fixed_cart_targets']
    boxes=[]
    for phase,row in phases.items():
        row['previous_actor_texture']=row['actor_texture'];row['previous_actor_pose']=copy.deepcopy(row['actor_pose'])
        palms=hands[direction][phase]
        pivot=[sum(h[i]-(t[i]-cart['pivot_native'][i])*ref/cart['virtual_canvas_reference'] for h,t in zip(palms,targets))/len(palms) for i in range(2)]
        residual=[[(h[i]-pivot[i])*160/ref-(t[i]-cart['pivot_native'][i])*160/cart['virtual_canvas_reference'] for i in range(2)] for h,t in zip(palms,targets)]
        row['actor_texture']='new:'+phase;row['actor_pose']['pivot_native']=pivot
        row['actor_pose']['virtual_canvas_reference']=ref
        row['hand_annotation']={'manual_source_palm_centres':palms,'manual_uncertainty_source_pixels':5,'pivot_native':pivot,'estimated_residual_world_at_body160':residual,'physical_contact_accepted':False,'hidden_far_hand_not_measured':direction in ['ne','nw']}
        for key,pose in [(row['actor_texture'],row['actor_pose']),(row['previous_actor_texture'],row['previous_actor_pose'])]:
            region=row['actor_region'];alpha=Image.open(P/data['textures'][key]['file']).getchannel('A').crop((region[0],region[1],region[0]+region[2],region[1]+region[3]))
            bb=alpha.point(lambda a:255 if a>=64 else 0).getbbox();assert bb
            sc=160/pose['virtual_canvas_reference'];pp=pose['pivot_native']
            boxes.append([(bb[0]+region[0]-pp[0])*sc,(bb[1]+region[1]-pp[1])*sc,(bb[2]+region[0]-pp[0])*sc,(bb[3]+region[1]-pp[1])*sc])
    for key,pose in [(data['cart_texture'],cart),('reference:empty_idle',data['empty_reference']['poses'][direction])]:
        region=pose['region'];alpha=Image.open(P/data['textures'][key]['file']).getchannel('A').crop((region[0],region[1],region[0]+region[2],region[1]+region[3]));bb=alpha.point(lambda a:255 if a>=64 else 0).getbbox();assert bb
        sc=160/pose['virtual_canvas_reference'];pp=pose['pivot_native'];boxes.append([(bb[0]+region[0]-pp[0])*sc,(bb[1]+region[1]-pp[1])*sc,(bb[2]+region[0]-pp[0])*sc,(bb[3]+region[1]-pp[1])*sc])
    union=[min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes)]
    fit=min(335/(union[2]-union[0]),260/(union[3]-union[1]))
    data['placement'][direction]={'common_scale':fit,'origin':[192-(union[0]+union[2])*fit/2,172-(union[1]+union[3])*fit/2]}
script=(R/'qa/wu_yong_hand_contact_20261018/prepared_preview.gd.txt').read_text()
script=script.replace('REJECTED INHERITED COMPOSITE','PREVIOUS REGISTERED FAMILY').replace('PHASE PALM REGISTRATION','NEW CORRECTED GAIT')
script=script.replace('paint(item.actor_texture,pose,actor_region)','paint(item.previous_actor_texture if row==1 else item.actor_texture,pose,actor_region)')
(P/'preview.gd').write_text(script,encoding='utf-8')
shutil.copyfile(Path(json.loads((R/'qa/wu_yong_hand_contact_20261018/prepared_binding.json').read_text())['project'])/'project.godot',P/'project.godot')
save(P/'inputs.json',data);save(Q/'registration_inputs.json',data)
with (Q/'preview.gd.txt').open('x',encoding='utf-8') as f:f.write(script)
frozen=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(P.rglob('*')) if p.is_file()]
previous=R/'qa/wu_yong_hand_contact_20261018/actual_registration/receipt.json'
binding={'prepared':True,'native_executed':False,'project':str(P),'frozen':frozen,'previous_receipt':str(previous),'scope':data['scope']}
save(E/'prepared_binding.json',binding);save(Q/'prepared_binding.json',binding)
selection={'mode':'builtin_imagegen','selected':selected,'rejected':{'contact_a_v1':'Upper body/hand span and size drift from a second full-body pose reference.','contact_b_v1':'Repeated contact A support-leg roles instead of alternating.'},'canon':'Chapter16 bare-chested jujube merchants with pu-dao in unloaded/interruption state. Chapter14 refined fair face/long beard and chapter15 straw sandals support identity; fixed empty grip/grey clothes/black headcloth are art interpretation.','production_adopted':False,'whole_gait_accepted':False}
save(Q/'candidate_selection.json',selection)
runner=(R/'qa/wu_yong_hand_contact_20261018/run_native_registration.py').read_text().replace('wu_yong_semantic_hand_registration_20261018','wu_yong_push_gait_20261018').replace("previous['native_checks']==48","previous['native_checks']==43").replace("len(report['texture_references'])==7","len(report['texture_references'])==12").replace('D:/CodexQA/wuhand_profiles','D:/CodexQA/wugait_profiles')
with (Q/'run_native.py').open('x',encoding='utf-8') as f:f.write(runner)
print(json.dumps({'prepared':str(P),'source_pngs':len(data['textures']),'files':len(frozen),'selected_views':20,'per_phase_body_rescaling':False}))
