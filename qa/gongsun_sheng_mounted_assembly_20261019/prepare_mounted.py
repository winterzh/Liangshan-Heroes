from pathlib import Path
import ast,hashlib,json,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1];N=Q/'mounted_v1'
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_assembly_20261019');P=E/'prepared_mounted_v1'
assert not (N/'prepared_binding.json').exists() and not (E/'mounted_v1').exists(),'Do not rewrite frozen or attempted inputs'
N.mkdir(exist_ok=True);P.mkdir(parents=True,exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
old=json.loads((R/'qa/gongsun_sheng_horse_rig_sources_20261019/assembly_v4/prepared_binding.json').read_text());source=Path(old['project']);data=old['inputs']
for row in old['files']:
    src=source/row['path'];assert sha(src)==row['sha256'];dst=P/row['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
layers=R/'qa/gongsun_sheng_mounted_layers_20261018';binding=json.loads((layers/'layer_bindings_v2.json').read_text());regions=json.loads((layers/'native_selected_regions_v3.json').read_text())
keys=['rider_sheathed_idle_v2','rider_point_v1','rein_material_v1'];template=(source/'images/body.png.import').read_text()
for key in keys:
    row=binding['textures'][key];src=R/row['canonical_source'];assert sha(src)==row['sha256'];rel=f'images/{key}.png';shutil.copyfile(src,P/rel)
    (P/(rel+'.import')).write_text(template.replace('body.png',key+'.png'),encoding='utf-8',newline='\n');data['textures'][key]={**row,'file':rel}
targets=[[280,260],[354,260],[325,190],[315,190]];bits=[[539,288],[105,288],[580,231],[105,231]]
mounted=[]
for i,d in enumerate(['se','sw','ne','nw']):
    cell=binding['views'][d]['region'][:2];poses={}
    for state,key in [('sheathed_idle','rider_sheathed_idle_v2'),('point','rider_point_v1')]:
        original=binding['views'][d]['phases'][state]
        poses[state]={'texture':key,'source_waist_local':[original['manual_seat_waist_source'][j]-cell[j] for j in range(2)],'source_hand_local':[original['manual_visible_rein_hand'][j]-cell[j] for j in range(2)],'used_region':regions['textures'][key]['used_regions'][d]}
    mounted.append({'direction':d,'rider_scale':0.8,'waist_target':targets[i],'bit_local':bits[i],'poses':poses,'manual_registration_uncertainty_source_pixels':10,'physical_seat_or_hand_contact_accepted':False})
data['mounted']=mounted;data['rein']=binding['rein']
data['scope']='First mounted comparison of the assembled four-leg horse: idle/sheath pose on left, fixed sword-point pose on right. One directional waist target, fixed rider scale, rider and rein endpoints follow identical body offset through movement/hold/restart. Not a draw/re-sheath trajectory, physical seat/hand/hoof contact, continuous human gait acceptance, actual Unit, chapter, package, performance or production adoption.'
(P/'inputs.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
driver=(source/'preview.gd').read_text()
driver=driver.replace('"motion_controls":stage.controls,','"motion_controls":stage.controls,"mounted_registration":stage.data.mounted,')
driver=driver.replace('horse(d,motion_time,debug)','mounted(d,motion_time,debug)')
driver=driver.replace(' / separate tail + hoof / ',' / mounted comparison / ')
driver=driver.replace('"Clean painted layers" if not debug else "Joint / stance model overlay"','"Sheathed idle rider" if not debug else "Sword-point pose / not draw trajectory"')
driver=driver.replace('Independent tail, shin and hoof layers. Raised neutral body pose; normal slowdown / hold / restart.','Fixed waist registration on assembled horse. Rider and painted leather reins follow body during move / hold / restart.')
driver=driver.replace('Standalone seam / ground-anchor model diagnostic. Not full sole silhouette contact, collision, rider, Unit or adoption acceptance.','First mounted comparison only. Not complete sword draw / return, physical seat contact, actual Unit, chapter or adoption.')
start=driver.index('\tfunc _draw()->void:')
extra='''\tfunc ribbon(a: Vector2,b: Vector2,sag: float)->void:
\t\tvar points: Array[Vector2]=[];var high: Array[Vector2]=[];var low: Array[Vector2]=[];var count: int=data.rein.segments
\t\tvar control: Vector2=(a+b)*.5+Vector2(0,2.0*sag)
\t\tfor i in range(count+1):
\t\t\tvar t: float=float(i)/count;var u: float=1.0-t;points.append(a*u*u+control*2.0*u*t+b*t*t)
\t\tfor i in range(count+1):
\t\t\tvar tangent: Vector2=points[mini(i+1,count)]-points[maxi(i-1,0)];var normal:=Vector2(-tangent.y,tangent.x).normalized()*float(data.rein.width_native)*.5
\t\t\thigh.append(points[i]+normal);low.append(points[i]-normal)
\t\tvar poly:=PackedVector2Array();var uv:=PackedVector2Array();var colors:=PackedColorArray();var sample: Array=data.rein.sample_region
\t\tfor i in range(count+1):poly.append(high[i]);uv.append(Vector2(float(sample[0])+float(sample[2])*i/count,float(sample[1]))/1254.0);colors.append(Color.WHITE)
\t\tfor i in range(count,-1,-1):poly.append(low[i]);uv.append(Vector2(float(sample[0])+float(sample[2])*i/count,float(sample[1])+float(sample[3]))/1254.0);colors.append(Color.WHITE)
\t\tdraw_polygon(poly,colors,uv,textures[String(data.rein.texture)])
\tfunc mounted(d: int,t: float,pointing: bool)->void:
\t\thorse(d,t,false)
\t\tvar row: Dictionary=data.mounted[d];var pose: Dictionary=row.poses.point if pointing else row.poses.sheathed_idle
\t\tvar factor: float=row.rider_scale;var bob: float=2.0*cos(t/cycle*TAU*2.0)*speed-float(data.neutral_body_rise)*(1.0-speed)
\t\tvar offset: Vector2=vec(row.waist_target)-vec(pose.source_waist_local)*factor+Vector2(0,bob)
\t\tvar bit: Vector2=vec(row.bit_local)+Vector2(0,bob);var hand: Vector2=vec(pose.source_hand_local)*factor+offset
\t\tribbon(bit,hand,float(data.rein.sag_native));ribbon(bit+Vector2(3,2),hand+Vector2(2,1),float(data.rein.sag_native)+3.0)
\t\tvar rr: Array=pose.used_region;var source:=Rect2(rr[0],rr[1],rr[2],rr[3])
\t\tdraw_texture_rect_region(textures[String(pose.texture)],Rect2((source.position-cell(d))*factor+offset,source.size*factor),source)
'''
driver=driver[:start]+extra+driver[start:]
for p in [N/'preview.gd.txt',P/'preview.gd']:p.write_text(driver,encoding='utf-8',newline='\n')
runner=(R/'qa/gongsun_sheng_horse_rig_sources_20261019/assembly_v4/run.py').read_text().replace('gongsun_sheng_horse_rig_sources_20261019','gongsun_sheng_mounted_assembly_20261019').replace('assembly_v4','mounted_v1').replace('gongsun_walk_se','gongsun_mounted_v1')
ast.parse(runner);(N/'run.py').write_text(runner,encoding='utf-8',newline='\n')
queue=(R/'qa/gongsun_sheng_horse_rig_sources_20261019/assembly_v4/wait_then_run.py').read_text().replace('gongsun_sheng_horse_rig_sources_20261019','gongsun_sheng_mounted_assembly_20261019').replace('assembly_v4','mounted_v1')
ast.parse(queue);(N/'wait_then_run.py').write_text(queue,encoding='utf-8',newline='\n')
files=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(P.rglob('*')) if p.is_file()]
save(N/'prepared_binding.json',{'project':str(P),'files':files,'inputs':data,'native_executed':False})
print(json.dumps({'prepared_files':len(files),'original_textures':len(data['textures']),'directions':4,'rider_poses':2,'production_adopted':False}))
