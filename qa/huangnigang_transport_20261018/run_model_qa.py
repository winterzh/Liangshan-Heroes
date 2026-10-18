from pathlib import Path
import datetime,hashlib,json,os,shutil,subprocess,time,uuid,sys
R=Path('D:/AI项目/水浒/开发工程');E=Path(__file__).parent
ENGINE=Path('C:/Users/rsb/Desktop/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe')
LOCK=R/'.godot/redraw_rejection_source.lock'
def sha(p):return hashlib.file_digest(p.open('rb'),'sha256').hexdigest()
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
busy=subprocess.check_output(['powershell','-NoProfile','-Command',"@(Get-CimInstance Win32_Process | Where-Object {$_.Name -match '^Godot.*\\.exe$'}).Count"],text=True).strip()
assert busy=='0' and not LOCK.exists(),'shared Godot lane occupied'
P=E/'model_native'/(datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]);P.mkdir(parents=True)
shutil.copyfile(R/'scripts/huangnigang_transport.gd',P/'huangnigang_transport.gd');shutil.copyfile(E/'transport_model_qa.gd',P/'qa.gd')
(P/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Huangnigang pure transport contract"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
frozen=[{'path':p.name,'sha256':sha(p)} for p in P.iterdir() if p.is_file()]
receipt={'complete':False,'project':str(P),'frozen':frozen,'actual_level_or_save_acceptance':False,'native_launched':False,'engine_sha256':sha(ENGINE),'steps':[]}
pins=json.loads((R/'qa/tribute_cart_wheel_unit_20261018/runtime_inventory.json').read_text())
pins+=json.loads((R/'qa/tribute_cart_wheel_unit_20261018/protected_next.json').read_text())
before={x['path']:sha(R/x['path']) for x in pins}
sys.path.insert(0,str(R/'tools'))
import run_character_art_qa as common
profile=P/'profile';profile.mkdir();env=common.private_environment(profile)
with LOCK.open('x',encoding='utf-8') as f:f.write(str(P))
try:
 receipt['native_launched']=True
 for tag,tail in [('import',['--editor','--import']),('contract',['--script','res://qa.gd'])]:
  command=[str(ENGINE),'--path',str(P),'--headless','--audio-driver','Dummy',*tail];start=time.monotonic()
  with (P/(tag+'.log')).open('wb') as log:
   process=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,env=env,cwd=P);code=process.wait(timeout=90)
  receipt['steps'].append({'case':tag,'command':command,'pid':process.pid,'exit_code':code,'seconds':time.monotonic()-start,'log_sha256':sha(P/(tag+'.log'))})
  assert code==0,(tag,code)
  content=(P/(tag+'.log')).read_text(encoding='utf-8',errors='replace');assert 'SCRIPT ERROR:' not in content and 'ERROR:' not in content
 report=json.loads((P/'report.json').read_text());assert report['passed'] and not report['failures']
 assert all(sha(P/x['path'])==x['sha256'] for x in frozen)
 assert all(sha(R/k)==v for k,v in before.items())
 receipt.update(complete=True,checks=len(report['checks']),states_tested=report['states_tested'],root_pin_changes=[])
except BaseException as error:
 receipt['error']=repr(error)
 if 'process' in locals() and process.poll() is None:process.terminate();process.wait(timeout=15)
finally:
 if LOCK.exists() and LOCK.read_text(encoding='utf-8')==str(P):LOCK.unlink()
 receipt['lock_released']=not LOCK.exists();save(P/'receipt.json',receipt)
save(E/'model_native_latest.json',{'receipt':str(P/'receipt.json')})
print(json.dumps({k:receipt.get(k) for k in ['complete','checks','states_tested','error','lock_released']},ensure_ascii=False))
assert receipt['complete']
