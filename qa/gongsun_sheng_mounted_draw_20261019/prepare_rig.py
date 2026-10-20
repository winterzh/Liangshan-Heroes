from pathlib import Path
import ast,hashlib,json,math,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1];N=Q/'rig_v1';N.mkdir()
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_draw_20261019');P=E/'prepared_rig_v1';P.mkdir(parents=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
old=json.loads((R/'qa/gongsun_sheng_mounted_assembly_20261019/mounted_v1/prepared_binding.json').read_text());source=Path(old['project']);data=old['inputs']
discard=['rider_sheathed_idle_v2','rider_point_v1']
for key in discard:data['textures'].pop(key)
data.pop('mounted')
for row in old['files']:
    if any(key+'.png' in row['path'] for key in discard):continue
    src=source/row['path'];assert sha(src)==row['sha256'];dst=P/row['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
lookup={Path(x['file']).stem:x for x in json.loads((Q/'source_inspection.json').read_text())['sources']};template=(source/'images/body.png.import').read_text()
chosen={'torso':'torso_v1','upper_arm':'upper_arm_v2','forearm':'forearm_v1','hand':'hand_v1','sword':'sword_v1','scabbard':'scabbard_v1'}
for key,name in chosen.items():
    row=lookup[name];src=Q/row['file'];assert sha(src)==row['sha256'];rel=f'images/{key}.png';shutil.copyfile(src,P/rel)
    (P/(rel+'.import')).write_text(template.replace('body.png',key+'.png'),encoding='utf-8',newline='\n');data['textures'][key]={'canonical_source':src.relative_to(R).as_posix(),'file':rel,'sha256':row['sha256'],'rgba8_sha256':row['rgba8_sha256']}
data.update(torso_scale=.7,hand_scale=.10,blade_length=136.0,scabbard_length=148.0,upper_length=100.0,fore_length=100.0)
waists=[[316,298],[311,298],[322,258],[312,258]];shoulders=[[258,217],[367,217],[400,177],[243,177]]
rein_hands=[[414,315],[288,327],[403,273],[418,280]];targets=[[280,260],[354,260],[325,190],[315,190]]
mouths=[[216,185],[416,185],[310,150],[335,150]];carry=[[350,65],[282,65],[405,-5],[240,-5]];point_hands=[[385,160],[247,160],[485,100],[160,100]]
rest=[[350,280],[282,280],[390,210],[255,210]];bits=[[539,288],[105,288],[580,231],[105,231]]
upper=[[[200,280],[430,480]],[[430,280],[200,480]],[[200,245],[440,400]],[[430,245],[190,400]]]
fore=[[[200,230],[460,510]],[[430,230],[175,510]],[[210,190],[480,470]],[[420,190],[160,470]]]
hands=[{'wrist':a,'grip':b} for a,b in [([250,370],[440,340]),([415,380],[225,340]),([300,360],[425,290]),([400,350],[220,290])]]
swords=[{'guard':a,'tip':b,'grip':c} for a,b,c in [([333,468],[333,42],[333,525]),([292,468],[292,42],[292,525]),([338,425],[338,25],[338,490]),([287,425],[287,25],[287,490])]]
scabbards=[{'mouth':a,'tip':b} for a,b in [([314,90],[321,550]),([313,90],[306,550]),([305,80],[340,550]),([322,80],[287,550])]]
views=[]
for i,d in enumerate(['se','sw','ne','nw']):
    sign=1 if i%2==0 else -1;out=[-.33*sign,-math.sqrt(1-.33**2)];angle=math.atan2(-out[1],-out[0]);point_angle=math.atan2(-.342,.94*sign)
    factor=data['blade_length']/math.dist(swords[i]['guard'],swords[i]['tip']);grip_distance=math.dist(swords[i]['guard'],swords[i]['grip'])*factor
    clear=[mouths[i][j]+out[j]*(data['blade_length']+8) for j in range(2)];point=[point_hands[i][0]+math.cos(point_angle)*grip_distance,point_hands[i][1]+math.sin(point_angle)*grip_distance]
    def key(label,guard,ang):return {'label':label,'guard':guard,'angle':ang}
    partial=[mouths[i][j]+out[j]*60 for j in range(2)]
    keys=[key('idle',mouths[i],angle),key('grip',mouths[i],angle),key('partial_out',partial,angle),key('clear',clear,angle),key('carry',carry[i],point_angle),key('point',point,point_angle),key('return_carry',carry[i],point_angle),key('return_clear',clear,angle),key('partial_in',partial,angle),key('seated_grip',mouths[i],angle),key('idle_return',mouths[i],angle)]
    shoulder=[targets[i][j]+(shoulders[i][j]-waists[i][j])*.7 for j in range(2)]
    views.append({'direction':d,'body_waist':waists[i],'waist_target':targets[i],'rein_hand':rein_hands[i],'rein_hand_is_hidden_proxy':d=='nw','manual_registration_uncertainty_source_pixels':15,'shoulder':shoulder,'mouth':mouths[i],'out':out,'sword':swords[i],'scabbard':scabbards[i],'hand':hands[i],'upper_arm':upper[i],'forearm':fore[i],'rest_hand':rest[i],'bit':bits[i],'keys':keys})
data['arm_views']=views;data['scope']='Articulated sword-draw/return prototype on assembled horse. Fixed painted torso, one separated dominant arm/hand, one sword, one fixed empty sheath. Eleven timed model states, axial extraction plane clipping and reverse insertion. Manual anchors and 2D geometry are not physical grip, full swept clearance, final continuous visual quality, actual Unit/chapter/package/performance/adoption acceptance.'
(P/'inputs.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
driver=(source/'preview.gd').read_text();start=driver.index('\tfunc mounted(');end=driver.index('\tfunc _draw()',start)
driver=driver[:start]+(Q/'arm_rig.gd.txt').read_text()+driver[end:]
driver=driver.replace('mounted(d,motion_time,debug)','articulated_rider(d,elapsed,debug)').replace('"mounted_registration":stage.data.mounted','"rig_registration":stage.data.arm_views')
driver=driver.replace('var drawn_phase: int=-1','var drawn_phase: int=-1\n\tvar drawn_action_index: int=-1')
driver=driver.replace('drawn_phase=phase;drawn_time=elapsed;','drawn_phase=phase;drawn_action_index=int(draw_state(0,elapsed).index);drawn_time=elapsed;')
driver=driver.replace(' / mounted comparison / ',' / articulated sword / ')
driver=driver.replace('Vector2(55 if not debug else 690,70)','Vector2(55 if not debug else 690,140)').replace('Vector2.ONE*.8);articulated_rider','Vector2.ONE*.7);articulated_rider').replace('Vector2(0,555)','Vector2(0,500)')
driver=driver.replace('"Sheathed idle rider" if not debug else "Sword-point pose / not draw trajectory"','String(draw_state(d,elapsed).label) if not debug else "Joint / grip / tip model overlay"')
driver=driver.replace('Fixed waist registration on assembled horse. Rider and painted leather reins follow body during move / hold / restart.','Fixed torso, separated sword arm / hand / sword / sheath. Eleven timed draw and reverse-return model states.')
driver=driver.replace('First mounted comparison only. Not complete sword draw / return, physical seat contact, actual Unit, chapter or adoption.','Prototype source / geometry rendering only. Not full swept clearance, physical grip, final visual quality or production adoption.')
start=driver.index('\tvar captures: Array=[]');end=driver.index('\tcheck(stage.max_bone_error',start)
capture='''\tfor d in range(4):
\t\tvar reach_error: float=0.0;var length_error: float=0.0
\t\tfor sample in range(1100):
\t\t\tvar pose: Dictionary=stage.draw_state(d,float(sample)/1100.0*8.8)
\t\t\treach_error=maxf(reach_error,float(pose.reach_error));length_error=maxf(length_error,absf(pose.guard.distance_to(pose.tip)-float(stage.data.blade_length)))
\t\tcheck(reach_error<.001,"arm target within two-bone reach across modeled cycle "+str(d))
\t\tcheck(length_error<.001,"fixed projected sword blade length across cycle "+str(d))
\t\tvar clear_pose: Dictionary=stage.draw_state(d,2.4)
\t\tcheck((clear_pose.tip-stage.vec(stage.data.arm_views[d].mouth)).dot(stage.vec(stage.data.arm_views[d].out))>7.9,"modeled tip fully beyond sheath mouth at clear key "+str(d))
\tvar captures: Array=[]
\tfor wanted in range(11):
\t\tvar deadline: int=Time.get_ticks_msec()+11000
\t\twhile int(stage.draw_state(0,stage.elapsed).index)!=wanted and Time.get_ticks_msec()<deadline:await process_frame
\t\tawait RenderingServer.frame_post_draw
\t\tcheck(stage.drawn_action_index==wanted,"normal process rendered sword state "+str(wanted))
\t\tvar name: String="draw_phase_%02d.png"%wanted
\t\tcheck(root.get_texture().get_image().save_png("res://"+name)==OK,"capture "+name)
\t\tcaptures.append({"file":name,"sha256":FileAccess.get_sha256("res://"+name),"action_index":stage.drawn_action_index,"elapsed":stage.elapsed,"body_mode":stage.mode})
\tvar deadline: int=Time.get_ticks_msec()+8000
\twhile stage.transitions.size()<16 and Time.get_ticks_msec()<deadline:await process_frame
\tcheck(stage.transitions.size()>=16,"at least sixteen normal horse phase transitions")
'''
driver=driver[:start]+capture+driver[end:]
for p in [N/'preview.gd.txt',P/'preview.gd']:p.write_text(driver,encoding='utf-8',newline='\n')
runner=(R/'qa/gongsun_sheng_mounted_assembly_20261019/mounted_v1/run.py').read_text().replace('gongsun_sheng_mounted_assembly_20261019','gongsun_sheng_mounted_draw_20261019').replace('mounted_v1','rig_v1').replace("len(report['screenshots'])==6","len(report['screenshots'])==11")
ast.parse(runner);(N/'run.py').write_text(runner,encoding='utf-8',newline='\n')
queue=(R/'qa/gongsun_sheng_mounted_assembly_20261019/mounted_v1/wait_then_run.py').read_text().replace('gongsun_sheng_mounted_assembly_20261019','gongsun_sheng_mounted_draw_20261019').replace('mounted_v1','rig_v1');ast.parse(queue);(N/'wait_then_run.py').write_text(queue,encoding='utf-8',newline='\n')
files=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(P.rglob('*')) if p.is_file()]
save(N/'prepared_binding.json',{'project':str(P),'files':files,'inputs':data,'native_executed':False})
print(json.dumps({'prepared_files':len(files),'source_textures':len(data['textures']),'modeled_action_states':11,'production_adopted':False}))
