"""Verify the clean Steam download and boot its real EXE with an isolated profile."""
from pathlib import Path
import datetime,hashlib,json,os,re,shutil,subprocess,sys,uuid
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
sys.dont_write_bytecode=True;sys.path.insert(0,str(ROOT/'tools'))
from contracts.run_content_identity_20260907.probe_runner import utilities
from run_steam_integration_qa import create_private_profile,resolve_profile_root,LOCK
u=utilities();guard=u.load_helper(u.GUARD,u.GUARD_SHA,'delivery_source_guard');safety=u.load_helper(u.HELPER,u.HELPER_SHA,'delivery_process_guard')
proof=json.loads((HERE/'candidate_delivery.json').read_bytes());folder=Path('D:/CodexTemp/lsh_rel_20261028/download')
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def save(name,value):
 (HERE/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
acf=(folder/'steamapps/appmanifest_5088120.acf').read_text(encoding='utf8')
assert re.search(r'"buildid"\s*"26260970"',acf) and re.search(r'"manifest"\s*"7760891311054131368"',acf)
assert re.search(r'"StateFlags"\s*"4"',acf) and re.search(r'"UpdateResult"\s*"0"',acf)
members=proof['members'];assert {p.name for p in folder.iterdir() if p.is_file()}=={r['path'] for r in members}
for row in members:
 p=folder/row['path'];assert p.stat().st_size==row['bytes'] and sha(p)==row['sha256'],row['path']
save('server_download_verified.json',{'complete':True,'build_id':26260970,'manifest_id':'7760891311054131368','new_empty_install_directory':True,'member_count':6,'files':members,'steamcmd_exit_code':0,'checked_at':datetime.datetime.now(datetime.timezone.utc).isoformat()})
run=ROOT/'.godot/steam_release_20261028'/('server_runtime_'+uuid.uuid4().hex[:8]);run.mkdir()
profile=create_private_profile(run,resolve_profile_root(Path('D:/CodexQA/steam_release_20261028')))
players=Path(os.environ['APPDATA'])/'Godot/app_userdata'/guard.project_name(ROOT)
safety.require_exclusive_godot();before=guard.source_receipt(ROOT);pb=u.tree(players)
env=os.environ.copy()
for key in list(env):
 if key.endswith(('_TEST','_QA','_AUDIT','_QA_MANIFEST')) or key.startswith(('HG_','DN_','HNS_')) or key in {'LEVEL','SKIRMISH','SKIRMISH_AI','SCENARIO','CUSTOM_DEFENSE','ARENA','AUTO_MICRO','AUTOMICRO','SCREENSHOT_DIR'}:env.pop(key)
for key in ('APPDATA','LOCALAPPDATA','TEMP','TMP'):
 p=profile/key.lower();p.mkdir();env[key]=str(p)
env.update(STEAM_DISABLED='1',CONTENT_UPDATE_NO_AUTO='1')
exe=folder/'LiangshanHeroes.exe';command=[str(exe),'--rendering-method','gl_compatibility','--resolution','1280x720','--max-fps','60','--quit-after','180','--log-file',str(run/'menu.godot.log')]
record={'complete':False,'build_id':26260970,'manifest_id':'7760891311054131368','scope':'clean server download real EXE menu boot only','human_playthrough':False,'steam_disabled_for_isolated_boot':True,'command':command}
child=None
with LOCK.open('x',encoding='utf8') as f:f.write(str(run))
try:
 with (run/'menu.console.log').open('xb') as log:
  child=subprocess.Popen(command,cwd=folder,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW);record['pid']=child.pid;child.wait(timeout=90)
 output=(run/'menu.console.log').read_text(encoding='utf8',errors='replace')
 errors=re.findall(r'^.*(?:SCRIPT ERROR|Parse Error|ERROR:|Failed loading resource|Assertion failed).*$',output,re.M)
 record.update(exit_code=child.returncode,errors=errors);assert child.returncode==0 and not errors;record['complete']=True
except BaseException as e:record['error']=repr(e)
finally:
 if child is not None and child.poll() is None:child.terminate();child.wait(timeout=20)
 record.update(source_unchanged=guard.source_receipt(ROOT)==before,players_unchanged=u.tree(players)==pb,child_exit_confirmed=child is None or child.poll() is not None)
 record['six_files_unchanged']=all(sha(folder/r['path'])==r['sha256'] for r in members)
 if not all(record[k] for k in ('source_unchanged','players_unchanged','child_exit_confirmed','six_files_unchanged')):record['complete']=False
 assert LOCK.read_text(encoding='utf8')==str(run);LOCK.unlink();record['lock_released']=True
 save('server_runtime_verified.json',record)
 for name in ('menu.console.log','menu.godot.log'):shutil.copyfile(run/name,HERE/('server_'+name))
assert record['complete'],record
backup=Path('D:/CodexQA/steam_release_20261028')/('client_backup_'+uuid.uuid4().hex[:8]);backup.mkdir()
if players.exists():shutil.copytree(players,backup/'players');assert u.tree(backup/'players')==pb
(backup/'before.json').write_text(json.dumps(pb,ensure_ascii=False,indent=2),encoding='utf8')
save('client_player_backup.json',{'complete':True,'private_backup':str(backup),'real_player_directory':str(players),'files':len(pb['files']),'tree_entries':len(pb['directories'])+len(pb['files']),'player_files_still_unchanged':u.tree(players)==pb})
print(json.dumps({'server_download':'six exact files','server_runtime':record['complete'],'player_backup':str(backup)},ensure_ascii=False))
