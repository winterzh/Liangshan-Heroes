from pathlib import Path
import ast,hashlib,json,re,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1];N=Q/'assembly_v2';N.mkdir()
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_horse_rig_sources_20261019');P=E/'prepared_assembly_v2';P.mkdir()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
old=json.loads((Q/'assembly_v1/prepared_binding.json').read_text());data=old['inputs']
inspect=json.loads((Q/'source_inspection_v2.json').read_text());lookup={Path(x['file']).stem:x for x in inspect['sources']}
chosen={'body':'body_v1','fore_upper':'fore_upper_v2','fore_lower':'fore_shin_v2','hind_upper':'hind_upper_v2','hind_lower':'hind_shin_v1','hoof':'hoof_v1'}
template=(Path(old['project'])/'images/body.png.import').read_text();textures={}
for key,name in chosen.items():
    row=lookup[name];src=Q/row['file'];assert sha(src)==row['sha256'];rel=f'images/{key}.png';dst=P/rel;dst.parent.mkdir(exist_ok=True);shutil.copyfile(src,dst)
    (P/(rel+'.import')).write_text(template.replace('body.png',key+'.png'),encoding='utf-8',newline='\n')
    textures[key]={'file':rel,'canonical_source':src.relative_to(R).as_posix(),'sha256':row['sha256'],'rgba8_sha256':row['rgba8_sha256']}
data['textures']=textures
data['anchors']['fore_lower']=[[[365,125],[375,495]],[[275,125],[275,495]],[[350,115],[355,475]],[[275,115],[285,475]]]
data['anchors']['hind_lower']=[[[390,125],[375,510]],[[270,125],[275,510]],[[365,120],[350,480]],[[285,120],[285,480]]]
data['hoof_scale']=0.245
data['hoof_anchors']=[{'attach':a,'left':l,'right':r} for a,l,r in [
 ([370,480],[315,590],[365,590]),([275,485],[280,590],[335,590]),
 ([350,455],[305,560],[355,560]),([300,460],[310,563],[365,563])]]
for i,view in enumerate(data['views']):view['near_hind_front_start_y']=486 if i<2 else 405
data['scope']='Four-direction four-leg assembly v2: dedicated independent hoof layer, manual sole-line anchors, revised brown joint caps, fixed near-hind overlay below body, normal-process slowdown/hold/restart. Sole-line and stance invariants are a mathematical/source-anchor model, not physical collision, full silhouette contact, human gait acceptance, rider, Unit, chapter, package or performance acceptance.'
save(P/'inputs.json',data)
driver=(Q/'assembly_preview.gd.txt').read_text()
driver=driver.replace('leg.joint.distance_to(leg.foot)','leg.joint.distance_to(leg.ankle)')
needle='\tvar captures: Array=[]'
extra='''\tfor d in range(4):
\t\tvar sole_error: float=0.0
\t\tfor sample in range(240):
\t\t\tfor leg in stage.legs(d,float(sample)/240.0*stage.cycle):
\t\t\t\tif leg.stance:sole_error=maxf(sole_error,absf(leg.sole_l.y-leg.sole_r.y))
\t\tcheck(sole_error<.001,"selected painted sole anchor line level during stance "+str(d))
\tvar captures: Array=[]'''
assert driver.count(needle)==1;driver=driver.replace(needle,extra)
needle='\tvar deadline: int=Time.get_ticks_msec()+8000'
extra='''\tfor wanted_mode in ["hold","restart"]:
\t\tvar mode_deadline: int=Time.get_ticks_msec()+9000
\t\twhile stage.mode!=wanted_mode and Time.get_ticks_msec()<mode_deadline:await process_frame
\t\tawait RenderingServer.frame_post_draw
\t\tcheck(stage.mode==wanted_mode,"normal process reached "+wanted_mode)
\t\tvar mode_name: String="assembled_"+wanted_mode+".png"
\t\tcheck(root.get_texture().get_image().save_png("res://"+mode_name)==OK,"capture "+mode_name)
\t\tcaptures.append({"file":mode_name,"sha256":FileAccess.get_sha256("res://"+mode_name),"mode":stage.mode,"elapsed":stage.elapsed,"motion_time":stage.motion_time})
\t\tif wanted_mode=="hold":
\t\t\tvar frozen_time: float=stage.motion_time
\t\t\tfor i in range(8):await process_frame
\t\t\tcheck(stage.motion_time==frozen_time and stage.speed==0.0,"motion clock stays fixed while stopped")
\t\t\tvar stopped_ok: bool=true
\t\t\tfor d in range(4):
\t\t\t\tfor leg in stage.legs(d,stage.motion_time):
\t\t\t\t\tif leg.lift!=0.0 or not leg.stance:stopped_ok=false
\t\t\tcheck(stopped_ok,"all sixteen modeled hooves settle during hold")
\tvar deadline: int=Time.get_ticks_msec()+8000'''
assert driver.count(needle)==1;driver=driver.replace(needle,extra)
driver=driver.replace('"max_bone_error":stage.max_bone_error,','"max_bone_error":stage.max_bone_error,"motion_controls":stage.controls,')
driver=driver.replace('\tvar cycle: float=1.6','\tvar motion_time: float=0.0\n\tvar speed: float=1.0\n\tvar mode: String="moving"\n\tvar controls: Array=[]\n\tvar cycle: float=1.6')
start=driver.index('\tfunc _process(delta: float)->void:',driver.index('class Stage'))
end=driver.index('\tfunc legs(',start)
driver=driver[:start]+'''\tfunc _process(delta: float)->void:
\t\telapsed+=delta
\t\tvar next_mode: String="moving"
\t\tif elapsed<3.2:speed=1.0
\t\telif elapsed<3.8:speed=1.0-smoothstep(3.2,3.8,elapsed);next_mode="slowing"
\t\telif elapsed<5.0:speed=0.0;next_mode="hold"
\t\telif elapsed<5.6:speed=smoothstep(5.0,5.6,elapsed);next_mode="starting"
\t\telse:speed=1.0;next_mode="restart"
\t\tif next_mode!=mode:mode=next_mode;controls.append({"mode":mode,"elapsed":elapsed,"motion_time":motion_time,"speed":speed})
\t\tmotion_time+=delta*speed
\t\tvar next: int=floori(motion_time/cycle*4.0)%4
\t\tif next!=phase:phase=next;transitions.append({"phase":phase,"elapsed":elapsed,"motion_time":motion_time})
\t\tqueue_redraw()
\tfunc hoof_info(d: int,foot: Vector2,angle: float)->Dictionary:
\t\tvar row: Dictionary=data.hoof_anchors[d];var left: Vector2=vec(row.left);var right: Vector2=vec(row.right);var sole: Vector2=(left+right)*.5
\t\tvar factor: float=data.hoof_scale;var rotation: float=angle-(right-left).angle()
\t\treturn {"ankle":foot+(vec(row.attach)-sole).rotated(rotation)*factor,"sole_l":foot+(left-sole).rotated(rotation)*factor,"sole_r":foot+(right-sole).rotated(rotation)*factor,"sole":sole,"rotation":rotation,"scale":factor}
''' +driver[end:]
driver=driver.replace('var bob: float=2.0*cos(t/cycle*TAU*2.0);','var bob: float=2.0*cos(t/cycle*TAU*2.0)*speed;')
driver=driver.replace('\t\t\tvar root: Vector2=','\t\t\ttravel*=speed;lift*=speed;supporting=supporting or speed==0.0\n\t\t\tvar root: Vector2=',1)
driver=driver.replace('var lower: float=115.0','var lower: float=95.0')
driver=driver.replace('\t\t\tvar delta: Vector2=foot-root;', '\t\t\tvar roll: float=0.0 if supporting else facing*.22*sin((p-stance)/(1.0-stance)*PI)*speed\n\t\t\tvar hoof: Dictionary=hoof_info(d,foot,roll);var ankle: Vector2=hoof.ankle\n\t\t\tvar delta: Vector2=ankle-root;')
driver=driver.replace('"foot":foot,"rest":rest,','"foot":foot,"ankle":ankle,"hoof":hoof,"sole_l":hoof.sole_l,"sole_r":hoof.sole_r,"rest":rest,')
start=driver.index('\tfunc part(');end=driver.index('\tfunc horse(',start)
driver=driver[:start]+'''\tfunc paint_source(key: String,d: int,at: Vector2,source_at: Vector2,factor: float,angle: float,tint: Color,clip_y: float=-10000.0)->void:
\t\tvar polygon:=PackedVector2Array()
\t\tfor corner in [Vector2.ZERO,Vector2(627,0),Vector2(627,627),Vector2(0,627)]:polygon.append(at+(corner-source_at).rotated(angle)*factor)
\t\tvar pieces: Array[PackedVector2Array]=[polygon]
\t\tif clip_y> -1000.0:pieces=Geometry2D.intersect_polygons(polygon,PackedVector2Array([Vector2(-1000,clip_y),Vector2(1600,clip_y),Vector2(1600,1800),Vector2(-1000,1800)]))
\t\tfor piece in pieces:
\t\t\tvar uv:=PackedVector2Array();var colors:=PackedColorArray()
\t\t\tfor point in piece:uv.append(((point-at).rotated(-angle)/factor+source_at+cell(d))/1254.0);colors.append(tint)
\t\t\tdraw_polygon(piece,colors,uv,textures[key])
\tfunc part(key: String,d: int,a: Vector2,b: Vector2,tint: Color,clip_y: float=-10000.0)->void:
\t\tvar pair: Array=data.anchors[key][d];var s0: Vector2=vec(pair[0]);var s1: Vector2=vec(pair[1])
\t\tpaint_source(key,d,a,s0,(b-a).length()/(s1-s0).length(),(b-a).angle()-(s1-s0).angle(),tint,clip_y)
\tfunc paint_leg(d: int,leg: Dictionary,clip_y: float=-10000.0)->void:
\t\tvar tint: Color=Color.WHITE if leg.near else Color(.79,.78,.76,1.0)
\t\tvar prefix: String="fore" if leg.fore else "hind"
\t\tpaint_source("hoof",d,leg.foot,leg.hoof.sole,leg.hoof.scale,leg.hoof.rotation,tint,clip_y)
\t\tpart(prefix+"_lower",d,leg.joint,leg.ankle,tint,clip_y);part(prefix+"_upper",d,leg.root,leg.joint,tint,clip_y)
\t\tmax_bone_error=maxf(max_bone_error,maxf(absf(leg.root.distance_to(leg.joint)-leg.upper),absf(leg.joint.distance_to(leg.ankle)-leg.lower)))
''' +driver[end:]
driver=driver.replace('source)\n\t\tif debug:','source)\n\t\tpaint_leg(d,poses[2],float(data.views[d].near_hind_front_start_y))\n\t\tif debug:')
driver=driver.replace('draw_line(leg.joint,leg.foot,color,2.0)','draw_line(leg.joint,leg.ankle,color,2.0);draw_line(leg.sole_l,leg.sole_r,Color.WHITE,2.0)')
driver=driver.replace('" / full 4-leg assembly / phase "+str(phase)','" / separate hoof / "+mode+" / phase "+str(phase)')
driver=driver.replace('horse(d,elapsed,debug)','horse(d,motion_time,debug)')
driver=driver.replace('Dedicated original body + upper/lower fore/hind layers. Same fixed anchors and scale for all phases; no per-frame image fitting.','Separate shin and hoof layers. Fixed manual sole line stays level during stance; normal slowdown / hold / restart.')
driver=driver.replace('Standalone anatomy / seam diagnostic. Ground dots are a mathematical reference, not collision proof. No rider / Unit / adoption.','Standalone seam / ground-anchor model diagnostic. Not full sole silhouette contact, collision, rider, Unit or adoption acceptance.')
(Q/'ankle_preview.gd.txt').write_text(driver,encoding='utf-8',newline='\n');(N/'preview.gd.txt').write_text(driver,encoding='utf-8',newline='\n');(P/'preview.gd').write_text(driver,encoding='utf-8',newline='\n')
shutil.copyfile(Path(old['project'])/'project.godot',P/'project.godot')
runner=(Q/'assembly_v1/run.py').read_text().replace('assembly_v1','assembly_v2').replace("len(report['screenshots'])==4","len(report['screenshots'])==6")
(N/'run.py').write_text(runner,encoding='utf-8',newline='\n');ast.parse(runner)
files=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(P.rglob('*')) if p.is_file()]
save(N/'prepared_binding.json',{'project':str(P),'files':files,'inputs':data,'native_executed':False})
print(json.dumps({'prepared_files':len(files),'painted_textures':6,'target_captures':6,'production_adopted':False}))
