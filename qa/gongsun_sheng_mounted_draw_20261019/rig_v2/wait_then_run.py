from pathlib import Path
import datetime,hashlib,json,os,subprocess,sys,time
Q=Path(__file__).resolve().parent;R=Q.parents[2]
E=Path('D:/CodexEvidence/shuihu/gongsun_sheng_mounted_draw_20261019')
sys.path.insert(0,str(R/'tools'));import run_character_art_qa as common
shared,running=common.load_helpers(R)
M=E/'queue_rig_v2';M.mkdir();runner=Q/'run.py';digest=hashlib.sha256(runner.read_bytes()).hexdigest()
state={'pid':os.getpid(),'started':datetime.datetime.now().isoformat(),'runner_sha256':digest,'native_started':False,'state':'waiting_for_processes_and_lease_to_clear'}
def save():(M/'state.json').write_text(json.dumps(state,indent=2)+'\n')
save();print(json.dumps(state),flush=True)
while running() or shared.LOCK.exists():
    state.update(last_live_check=datetime.datetime.now().isoformat(),lease_present=shared.LOCK.exists());save();time.sleep(15)
assert hashlib.sha256(runner.read_bytes()).hexdigest()==digest
assert not (E/'rig_v2').exists()
with (M/'stdout.log').open('xb') as out,(M/'stderr.log').open('xb') as err:
    child=subprocess.Popen([sys.executable,'-X','utf8','-B',str(runner)],cwd=R,stdout=out,stderr=err)
    state.update(state='owned_native_runner_live',native_started=True,child_pid=child.pid);save();code=child.wait()
state.update(state='terminal',exit_code=code,ended=datetime.datetime.now().isoformat());save();print(json.dumps(state),flush=True);sys.exit(code)
