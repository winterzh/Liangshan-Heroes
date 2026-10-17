import hashlib,json,pathlib,shutil
R=pathlib.Path('D:/AI项目/水浒/开发工程');E=pathlib.Path('D:/CodexEvidence/shuihu/ruan_xiaoqi_layer_registration_20261018');P=R/'assets/characters/ruan_xiaoqi_layer_fixes_20261018/prompt_set.json';M=R/'assets/direction4/level1_ruan_xiaoqi_layered_20261018.json'
def load(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.file_digest(p.open('rb'),'sha256').hexdigest()
def save(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
a=load(P);m=load(M);assert not a.get('hand_registration');assert not (E/'before_inventory.json').exists()
names=[P.relative_to(R).as_posix(),M.relative_to(R).as_posix(),*m['resources']]
for n in names:q=E/'before'/n;q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/n,q)
save(E/'before_inventory.json',[{'path':n,'sha256':sha(R/n)} for n in names])
save(E/'texture_baseline.json',[{'path':x['path'],'sha256':sha(R/x['path'])} for x in m['sources'].values()])
hands={
 'push_idle':{'se':[[345,382],[495,354]],'sw':[[789,355],[924,390]],'ne':[[369,888],[493,917]],'nw':[[804,917],[925,889]]},
 'push_contact_a':{'se':[[388,349],[514,325]],'sw':[[786,337],[894,351]],'ne':[[367,885],[499,918]],'nw':[[787,919],[925,889]]},
 'push_passing_a':{'se':[[417,316],[541,287]],'sw':[[748,289],[859,316]],'ne':[[365,891],[485,910]],'nw':[[795,917],[902,890]]},
 'push_contact_b':{'se':[[363,325],[496,315]],'sw':[[327,586],[567,634]],'ne':[[502,902]],'nw':[[416,533],[608,505]]},
 'push_passing_b':{'se':[[625,714],[968,637]],'sw':[[326,586],[566,636]],'ne':[[938,566]],'nw':[[416,535],[611,502]]}}
targets={'se':[[52,194],[171,141]],'sw':[[1086,155],[1200,198]],'ne':[[53,1010],[194,1069]],'nw':[[1047,1088],[1197,1018]]}
registration={}
for state,views in hands.items():
 for d,points in views.items():
  pose=m['poses'][state+'_'+d];cart=m['poses']['cart_only_'+d];target=targets[d] if len(points)==2 else [targets[d][1]]
  source_world=[[(p[i]-pose['pivot_native'][i])/pose['virtual_canvas_reference'] for i in range(2)] for p in points]
  target_world=[[(p[i]-cart['pivot_native'][i])/cart['virtual_canvas_reference'] for i in range(2)] for p in target]
  delta=[sum(q[i]-p[i] for p,q in zip(source_world,target_world))/len(points) for i in range(2)]
  residuals=[sum((p[i]+delta[i]-q[i])**2 for i in range(2))**.5 for p,q in zip(source_world,target_world)]
  registration[state+'_'+d]={'manual_source_grip_centres':points,'manual_cart_grip_targets':target,'translation_per_body_size':delta,'estimated_residual_per_body_size':residuals,'method':'Manual approximate grip landmarks; translation only, no scale/rotation/bitmap change. Single NE anchor when far grip is visually occluded. Measured residual is annotation fit, not proof of actual fingers touching.'}
a.update(hand_registration=registration,registration_revision=2);save(P,a);save(E/'registration_worksheet.json',{'actor_poses':20,'points':'Manual approximate source pixel coordinates; native visual review required.','fixed_cart_targets':targets,'registration':registration,'cart_or_body_scale_changed':False,'source_bitmap_edits':False,'full_hand_contact_accepted':False})
print(json.dumps({'poses_registered':len(registration),'max_translation_per_body_size':max((sum(v*v for v in x['translation_per_body_size']))**.5 for x in registration.values()),'max_estimated_residual':max(v for x in registration.values() for v in x['estimated_residual_per_body_size']),'bitmap_edits':False}))
