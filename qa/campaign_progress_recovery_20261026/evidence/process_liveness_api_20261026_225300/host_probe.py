from pathlib import Path
import ctypes,hashlib,importlib.util,json,os,subprocess,sys,uuid
R=Path.cwd(); S=R/'qa/huangnigang_production_20261020/run_batch.py'
s=importlib.util.spec_from_file_location('probe_helpers',S);h=importlib.util.module_from_spec(s);s.loader.exec_module(h)
name=h.stamp();out=R/'.godot/process_liveness_api_20261026'/name;out.mkdir(parents=True)
project=out/'project';project.mkdir()
(project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Process Liveness API Probe"\n',encoding='utf-8')
code='''extends SceneTree
func _initialize() -> void:
 call_deferred("probe")
func probe() -> void:
 var pid: int = int(OS.get_environment("PROBE_OTHER_PID"))
 var report := {"engine":Engine.get_version_info(),"observer_pid":OS.get_process_id(),"other_pid":pid,"self_query":OS.is_process_running(OS.get_process_id()),"other_query":OS.is_process_running(pid),"api":"OS.is_process_running","no_gameplay_or_store_test":true}
 var file := FileAccess.open(OS.get_environment("PROBE_REPORT"),FileAccess.WRITE)
 if file == null: quit(2); return
 file.store_string(JSON.stringify(report,"\\t"));file.flush();file.close()
 print("PROCESS_LIVENESS_API_PROBE ",report)
 quit(0)
'''
worker=project/'probe.gd';worker.write_text(code,encoding='utf-8')
k=ctypes.WinDLL('kernel32',use_last_error=True)
k.OpenProcess.argtypes=[ctypes.c_uint32,ctypes.c_int,ctypes.c_uint32];k.OpenProcess.restype=ctypes.c_void_p
k.GetExitCodeProcess.argtypes=[ctypes.c_void_p,ctypes.POINTER(ctypes.c_uint32)];k.GetExitCodeProcess.restype=ctypes.c_int
k.CloseHandle.argtypes=[ctypes.c_void_p];k.CloseHandle.restype=ctypes.c_int
def native(pid):
 handle=k.OpenProcess(0x1000,False,pid)
 assert handle,ctypes.get_last_error()
 try:
  status=ctypes.c_uint32();assert k.GetExitCodeProcess(handle,ctypes.byref(status))
  return {'pid':pid,'exit_code':status.value,'alive':status.value==259,'api':'OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION)+GetExitCodeProcess'}
 finally:k.CloseHandle(handle)
receipt={'schema':'windows_external_pid_api_probe_v1','complete':False,'gameplay_qualified':False,'store_recovery_qualified':False}
child=None;external=None;locked=False
try:
 assert not h.shared.LOCK.exists() and not h.running()
 with h.shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(out))
 locked=True;engine=h.shared.resolve_godot(None)
 profile=Path(R.anchor)/'CodexQA/processapi'/uuid.uuid4().hex[:12];profile.mkdir(parents=True)
 env=h.common.private_environment(profile)
 external=subprocess.Popen([sys.executable,'-c','import time; time.sleep(120)'],creationflags=subprocess.CREATE_NO_WINDOW)
 receipt['before']=native(external.pid);assert external.poll() is None and receipt['before']['alive']
 env.update(PROBE_OTHER_PID=str(external.pid),PROBE_REPORT=str(out/'report.json'))
 with (out/'native.log').open('wb') as log:
  child=subprocess.Popen([str(engine),'--headless','--path',str(project),'--script',str(worker)],env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
  child.wait(timeout=30)
 receipt['after']=native(external.pid);assert external.poll() is None and receipt['after']['alive']
 report=json.loads((out/'report.json').read_text('utf-8'))
 assert child.returncode==0 and report['observer_pid']==child.pid and report['other_pid']==external.pid
 assert report['self_query'] is True and report['other_query'] is False
 receipt.update(complete=True,engine_sha256=h.sha(engine),engine_path=str(engine),worker_sha256=h.sha(worker),worker_pid=child.pid,worker_exit=child.returncode,external_sibling_pid=external.pid,observed_external_alive_but_godot_false=True,report_sha256=h.sha(out/'report.json'))
except BaseException as e:
 receipt['error']=repr(e)
finally:
 for process in [child,external]:
  if process is not None and process.poll() is None:process.terminate();process.wait(timeout=15)
 receipt['owned_children_terminal']=all(p is None or p.poll() is not None for p in [child,external])
 if locked and h.shared.LOCK.exists() and h.shared.LOCK.read_text('utf-8')==str(out) and not h.running():h.shared.LOCK.unlink()
 receipt['lock_released']=locked and not h.shared.LOCK.exists()
 receipt['complete']=receipt['complete'] and receipt['owned_children_terminal'] and receipt['lock_released']
 (out/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'output':str(out),**receipt},ensure_ascii=False))
if not receipt['complete']:raise SystemExit(1)
