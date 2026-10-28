"""Run the exact embedded-PCK candidate for ordinary OS-input acceptance.

This host injects no gameplay or QA driver. UI observations are recorded
separately; a clean process exit alone does not grant interaction acceptance.
"""
from pathlib import Path
import datetime,hashlib,json,os,re,subprocess,sys,time,uuid
ROOT=Path(__file__).resolve().parents[2];sys.dont_write_bytecode=True;sys.path.insert(0,str(ROOT/'tools'))
from contracts.run_content_identity_20260907.probe_runner import utilities
from run_steam_integration_qa import LOCK,create_private_profile,resolve_profile_root
candidate=Path(sys.argv[1]).resolve();candidate.relative_to(ROOT/'.godot/steam_candidates');proof=json.loads((candidate/'receipt.json').read_bytes());assert proof['complete']
exe=candidate/'windows/LiangshanHeroes.exe'
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
assert sha(exe)==next(x['sha256'] for x in proof['archive']['members'] if x['path']==exe.name)
u=utilities();guard=u.load_helper(u.GUARD,u.GUARD_SHA,'release_gui_source_guard');safety=u.load_helper(u.HELPER,u.HELPER_SHA,'release_gui_process_guard');safety.require_exclusive_godot()
out=ROOT/'.godot/steam_release_20261028'/('gui_'+datetime.datetime.now().strftime('%H%M%S')+'_'+uuid.uuid4().hex[:8]);out.mkdir(parents=True,exist_ok=False)
profile=create_private_profile(out,resolve_profile_root(Path('D:/CodexQA/steam_release_20261028')))
env=os.environ.copy()
for key in list(env):
 if key.endswith(('_TEST','_QA','_AUDIT','_QA_MANIFEST')) or key.startswith(('HG_','DN_','HNS_')) or key in {'LEVEL','SKIRMISH','SKIRMISH_AI','SCENARIO','CUSTOM_DEFENSE','ARENA','AUTO_MICRO','AUTOMICRO','SCREENSHOT_DIR'}:env.pop(key)
for key in ('APPDATA','LOCALAPPDATA','TEMP','TMP'):
 p=profile/key.lower();p.mkdir();env[key]=str(p)
env.update(STEAM_DISABLED='1',CONTENT_UPDATE_NO_AUTO='1',LSH_LANGUAGE='zh_CN')
players=Path(os.environ['APPDATA'])/'Godot/app_userdata'/guard.project_name(ROOT);before=guard.source_receipt(ROOT);pb=u.tree(players)
record={'complete':False,'source_head':proof['source_head'],'candidate':str(candidate),'exe_sha256':sha(exe),'private_profile':str(profile),'execution_kind':'actual_release_exe_ordinary_OS_input','gameplay_driver_installed':False,'ui_acceptance_recorded_separately':True}
child=None
with LOCK.open('x',encoding='utf8') as f:f.write(str(out))
try:
 command=[str(exe),'--rendering-method','gl_compatibility','--resolution','1280x720','--position','80,80','--max-fps','60','--log-file',str(out/'gui.godot.log')]
 with (out/'gui.console.log').open('xb') as log:
  child=subprocess.Popen(command,cwd=exe.parent,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
  record.update(pid=child.pid,command=command);u.save(out/'launch.json',record);print(json.dumps({'run':str(out),'pid':child.pid},ensure_ascii=False),flush=True);started=time.monotonic()
  while child.poll() is None:
   text=(out/'gui.console.log').read_text(encoding='utf8',errors='replace')
   errors=re.findall(r'^.*(?:SCRIPT ERROR|Parse Error|ERROR:|Failed loading resource|Assertion failed).*$',text,re.M)
   if errors:raise RuntimeError('Release GUI log errors: '+repr(errors[:5]))
   if (out/'stop.request').exists():raise RuntimeError('User-requested GUI cancellation')
   if time.monotonic()-started>1800:raise TimeoutError('GUI acceptance host 30-minute limit')
   time.sleep(.5)
  record.update(exit_code=child.returncode,seconds=round(time.monotonic()-started,3),errors=[]);assert child.returncode==0;record['complete']=True
except BaseException as e:record['error']=repr(e)
finally:
 if child is not None and child.poll() is None:child.terminate();child.wait(timeout=20)
 record['child_exit_confirmed']=child is None or child.poll() is not None
 try:
  record.update(source_unchanged=guard.source_receipt(ROOT)==before,players_unchanged=u.tree(players)==pb,exe_unchanged=sha(exe)==record['exe_sha256']);assert all(record[k] for k in ('source_unchanged','players_unchanged','exe_unchanged','child_exit_confirmed'))
  assert LOCK.read_text(encoding='utf8')==str(out);LOCK.unlink();record['lock_released']=True
 except BaseException as e:record.update(complete=False,guard_error=repr(e))
 u.save(out/'receipt.json',record);print(json.dumps({'run':str(out),**record},ensure_ascii=False),flush=True)
sys.exit(0 if record['complete'] else 1)
