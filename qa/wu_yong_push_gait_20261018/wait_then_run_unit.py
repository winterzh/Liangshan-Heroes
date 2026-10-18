"""Single observed queue: run once after both engine processes and lease are absent."""
from pathlib import Path
import datetime,hashlib,json,os,subprocess,sys,time
R=Path(__file__).resolve().parents[2];Q=Path(__file__).resolve().parent
E=Path('D:/CodexEvidence/shuihu/wu_yong_push_gait_20261018/unit')
sys.path.insert(0,str(R/'tools'));import run_character_art_qa as common
shared,running=common.load_helpers(R)
marker=E/'queue';marker.mkdir()
runner=Q/'run_unit_native.py';digest=hashlib.sha256(runner.read_bytes()).hexdigest()
state={'pid':os.getpid(),'started':datetime.datetime.now().isoformat(),'runner_sha256':digest,'native_started':False,'state':'waiting_for_processes_and_lease_to_clear'}
def save():
    (marker/'state.json').write_text(json.dumps(state,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
save();print(json.dumps(state),flush=True)
while running() or shared.LOCK.exists():
    state['last_live_check']=datetime.datetime.now().isoformat();state['lease_present']=shared.LOCK.exists();save();time.sleep(15)
assert hashlib.sha256(runner.read_bytes()).hexdigest()==digest
assert not (E/'actual_native').exists(),'Another attempt already exists; never restart'
state.update(state='native_admission_requested',admission_time=datetime.datetime.now().isoformat());save()
with (marker/'native.stdout.log').open('xb') as stdout,(marker/'native.stderr.log').open('xb') as stderr:
    child=subprocess.Popen([sys.executable,'-X','utf8','-B',str(runner)],cwd=R,stdout=stdout,stderr=stderr)
    state.update(child_pid=child.pid,native_started=True,state='owned_unit_runner_live');save()
    code=child.wait()
state.update(state='terminal',exit_code=code,ended=datetime.datetime.now().isoformat());save();print(json.dumps(state),flush=True)
sys.exit(code)
