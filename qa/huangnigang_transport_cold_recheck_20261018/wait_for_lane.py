from pathlib import Path
import sys,json,time,subprocess,datetime,os
R=Path(r"D:/AI项目/水浒/开发工程"); E=Path(__file__).parent;sys.path.insert(0,str(R/'tools'))
import run_character_art_qa as common
shared,running=common.load_helpers(R)
status={'state':'waiting','watcher_pid':os.getpid(),'initial_foreign_engine_pid':None,'initial_foreign_owner':shared.LOCK.read_text(encoding='utf-8') if shared.LOCK.exists() else None}
def save():
 status['time']=datetime.datetime.now(datetime.timezone.utc).isoformat();(E/'queue_status.json').write_text(json.dumps(status,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
start=time.monotonic();save()
while running() or shared.LOCK.exists():
 if time.monotonic()-start>2400:
  status['state']='observation_window_ended_no_child_started';save();sys.exit(3)
 time.sleep(5)
status['state']='launching';save()
child=subprocess.Popen([sys.executable,'-X','utf8',str(E/'run_actual_transport.py')],cwd=R,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0));status['child_pid']=child.pid;status['state']='running';save()
code=child.wait();status['state']='complete' if code==0 else 'terminal_failure';status['exit_code']=code;save();sys.exit(code)
