from pathlib import Path
import ast,hashlib,json,shutil
Q=Path(__file__).resolve().parent;R=Q.parents[1];E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_horse_rig_sources_20261019')
old=json.loads((Q/'assembly_v2/prepared_binding.json').read_text());source=Path(old['project'])
assert not (E/'assembly_v2').exists(),'No modification of attempted inputs'
N=Q/'assembly_v3';N.mkdir();P=E/'prepared_assembly_v3';P.mkdir()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for row in old['files']:
    p=source/row['path'];assert sha(p)==row['sha256'];dst=P/row['path'];dst.parent.mkdir(exist_ok=True,parents=True);shutil.copyfile(p,dst)
driver=(P/'preview.gd').read_text();needle='var bob: float=2.0*cos(t/cycle*TAU*2.0)\n';assert driver.count(needle)==1
driver=driver.replace(needle,'var bob: float=2.0*cos(t/cycle*TAU*2.0)*speed\n')
for p in [P/'preview.gd',N/'preview.gd.txt']:p.write_text(driver,encoding='utf-8',newline='\n')
runner=(Q/'assembly_v2/run.py').read_text().replace('assembly_v2','assembly_v3');ast.parse(runner);(N/'run.py').write_text(runner,encoding='utf-8',newline='\n')
files=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(P.rglob('*')) if p.is_file()]
with (N/'prepared_binding.json').open('x',encoding='utf-8') as f:f.write(json.dumps({'project':str(P),'files':files,'inputs':old['inputs'],'native_executed':False,'predecessor':'assembly_v2 prepared only; lane admission refused; body bob multiplier aligned with leg roots before a new candidate'},ensure_ascii=False,indent=2)+'\n')
queue=(R/'qa/gongsun_sheng_mounted_walk_20261019/native_sw_v1/wait_then_run.py').read_text().replace('gongsun_sheng_mounted_walk_20261019','gongsun_sheng_horse_rig_sources_20261019').replace('native_sw_v1','assembly_v3').replace('queue_sw_v1','queue_assembly_v3')
ast.parse(queue);(N/'wait_then_run.py').write_text(queue,encoding='utf-8',newline='\n')
print(json.dumps({'prepared_files':len(files),'predecessor_executed':False,'candidate':'assembly_v3'}))
