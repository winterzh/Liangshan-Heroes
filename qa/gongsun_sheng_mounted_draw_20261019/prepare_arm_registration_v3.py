from pathlib import Path
import ast,hashlib,json,math,shutil
Q=Path(__file__).resolve().parent;E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_draw_20261019')
old=json.loads((Q/'rig_v2/prepared_binding.json').read_text());S=Path(old['project']);data=old['inputs'];N=Q/'rig_v3';N.mkdir();P=E/'prepared_rig_v3';P.mkdir()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for row in old['files']:
    src=S/row['path'];assert sha(src)==row['sha256'];dst=P/row['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
controls=[[360,150],[272,150],[460,40],[180,40]]
for i,row in enumerate(data['arm_views']):
    row['hand_approach_control']=controls[i]
    if i==2:row['rest_hand']=[455,210]
    if i==3:row['rest_hand']=[190,210]
    if i>=2:row['keys'][5]['guard'][1]-=20
data['scope']='Articulated sword-draw/return v3: browser-source review led to rear idle hand repositioning, quadratic grasp/release approach and raised rear-view pointed sword. Prior frozen candidates retained. Manual source-anchor model only; not physical grip, full swept clearance, native/Unit/chapter/package/performance or final visual adoption acceptance.'
(P/'inputs.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
driver=(P/'preview.gd').read_text();a='if index==0:palm=vec(row.rest_hand).lerp(grip,u)';b='elif index==9:palm=grip.lerp(vec(row.rest_hand),u)';assert driver.count(a)==1 and driver.count(b)==1
driver=driver.replace(a,'if index==0:palm=vec(row.rest_hand)*(1.0-u)*(1.0-u)+vec(row.hand_approach_control)*2.0*(1.0-u)*u+grip*u*u')
driver=driver.replace(b,'elif index==9:palm=grip*(1.0-u)*(1.0-u)+vec(row.hand_approach_control)*2.0*(1.0-u)*u+vec(row.rest_hand)*u*u')
for p in [P/'preview.gd',N/'preview.gd.txt']:p.write_text(driver,encoding='utf-8',newline='\n')
for name in ['run.py','wait_then_run.py']:
    code=(Q/'rig_v2'/name).read_text().replace('rig_v2','rig_v3');ast.parse(code);(N/name).write_text(code,encoding='utf-8',newline='\n')
files=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(P.rglob('*')) if p.is_file()]
with (N/'prepared_binding.json').open('x',encoding='utf-8') as f:f.write(json.dumps({'project':str(P),'files':files,'inputs':data,'native_executed':False,'predecessor':'rig_v2 source composition browser review; v2 queued job untouched; v3 is a new frozen candidate'},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'candidate':'rig_v3','files':len(files),'source_png_changes':False,'new_native_queue_started':False}))
