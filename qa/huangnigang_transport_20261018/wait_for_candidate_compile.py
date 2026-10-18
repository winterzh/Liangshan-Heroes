from pathlib import Path
import datetime,hashlib,json,os,subprocess,time
R=Path('D:/AI项目/水浒/开发工程');E=Path(__file__).parent;LOCK=R/'.godot/redraw_rejection_source.lock'
def state(**fields):
 out={'pid':os.getpid(),'time':datetime.datetime.now(datetime.timezone.utc).isoformat(),**fields}
 (E/'compile_wait_status.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def engines():return json.loads(subprocess.check_output(['powershell','-NoProfile','-Command',"@((Get-CimInstance Win32_Process | Where-Object {$_.Name -match '^Godot.*\\.exe$'}).ProcessId) | ConvertTo-Json -Compress"],text=True).strip() or '[]')
candidate=E/'integration_candidate.json';pinned=hashlib.sha256(candidate.read_bytes()).hexdigest()
state(state='waiting_for_shared_lane',candidate_manifest_sha256=pinned)
while True:
 assert hashlib.sha256(candidate.read_bytes()).hexdigest()==pinned,'candidate changed while queued'
 live=engines()
 if not LOCK.exists() and not live:
  state(state='starting_exact_candidate_compile',candidate_manifest_sha256=pinned)
  with (E/'compile_wait_child.log').open('ab') as log:
   child=subprocess.Popen(['python','-X','utf8','-B',str(E/'parse_integration_candidate.py')],cwd=R,stdout=log,stderr=subprocess.STDOUT)
   state(state='candidate_compile_running',child_pid=child.pid,candidate_manifest_sha256=pinned)
   code=child.wait()
  state(state='complete' if code==0 else 'failed',child_pid=child.pid,exit_code=code,candidate_manifest_sha256=pinned)
  raise SystemExit(code)
 state(state='waiting_for_shared_lane',live_godot_pids=live,foreign_lock=LOCK.read_text(encoding='utf-8') if LOCK.exists() else None,candidate_manifest_sha256=pinned)
 time.sleep(5)
