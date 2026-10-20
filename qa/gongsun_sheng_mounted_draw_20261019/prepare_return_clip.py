from pathlib import Path
import ast,hashlib,json,shutil
Q=Path(__file__).resolve().parent;E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_draw_20261019')
old=json.loads((Q/'rig_v1/prepared_binding.json').read_text());S=Path(old['project']);assert not (E/'rig_v1').exists()
N=Q/'rig_v2';N.mkdir();P=E/'prepared_rig_v2';P.mkdir()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for row in old['files']:
    src=S/row['path'];assert sha(src)==row['sha256'];dst=P/row['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
driver=(P/'preview.gd').read_text();needle='index in [0,1,2,8,9,10]';assert driver.count(needle)==1
driver=driver.replace(needle,'index in [0,1,2,7,8,9,10]')
for p in [P/'preview.gd',N/'preview.gd.txt']:p.write_text(driver,encoding='utf-8',newline='\n')
for name in ['run.py','wait_then_run.py']:
    code=(Q/'rig_v1'/name).read_text().replace('rig_v1','rig_v2');ast.parse(code);(N/name).write_text(code,encoding='utf-8',newline='\n')
files=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(P.rglob('*')) if p.is_file()]
with (N/'prepared_binding.json').open('x',encoding='utf-8') as f:f.write(json.dumps({'project':str(P),'files':files,'inputs':old['inputs'],'native_executed':False,'predecessor':'rig_v1 prepared only; static review found return_clear insertion interval missing mouth clipping; new immutable v2 includes it'},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'candidate':'rig_v2','predecessor_native_executed':False,'files':len(files)}))
