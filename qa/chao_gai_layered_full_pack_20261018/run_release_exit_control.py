from pathlib import Path
import json,hashlib,sys,datetime,uuid
R=Path('D:/AI项目/水浒/开发工程');E=Path(__file__).parent;sys.path[:0]=[str(E),str(R/'tools')]
import run_character_art_qa as common
from release_step import run_release_step
shared,running=common.load_helpers(R)
assert not running() and not shared.LOCK.exists(),'shared engine occupied; no new native process started'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();b=json.loads((E/'retained_export_binding.json').read_text());exe=Path(b['exe']['path']);pck=Path(b['pack_observed_after_failed_launch']['path'])
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8];O=E/'release_no_screenshot_control'/stamp;O.mkdir(parents=True)
receipt={'complete':False,'steps':[],'runner_sha256':sha(Path(__file__)),'exe':b['exe'],'pck':b['pack_observed_after_failed_launch'],'scope':'Unchanged real release EXE auto-loads unchanged full PCK; LEVEL=1 selects chapter. 480-frame startup/forced-quit control without SCREENSHOT_DIR, movie writer or external script; same count as the earlier screenshot-hook case. No full gameplay or identity-probe acceptance.'};locked=False
try:
 with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(O))
 locked=True;assert not running();assert sha(exe)==b['exe']['sha256'] and sha(pck)==b['pack_observed_after_failed_launch']['sha256']
 profile=shared.create_private_profile(O,Path('D:/CodexQA/cg_no_shot_control'));env=common.private_environment(profile)
 for key in ['SCREENSHOT_DIR','SMOKE_TEST','ARTSHOT','ABILITY_VIS_AUDIT','ANIM_TEST']:env.pop(key,None)
 env['LEVEL']='1';movie=O/'unused_movie_marker'
 run_release_step(exe,exe.parent,env,O,'normal_release_480frames_without_screenshot_hook',['--resolution','1280x720','--position','30000,30000','--fixed-fps','60','--quit-after','480'],120,common,running,receipt['steps'])
 frames=[]
 assert sha(exe)==b['exe']['sha256'] and sha(pck)==b['pack_observed_after_failed_launch']['sha256'];receipt.update(complete=True,forced_quit_after_frames=480,no_screenshot_hook=True)
except BaseException as error:receipt['error']=repr(error)
finally:
 if locked and not running() and shared.LOCK.exists() and shared.LOCK.read_text()==str(O):shared.LOCK.unlink()
 receipt['lock_released']=not shared.LOCK.exists();(O/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');(E/'release_control_latest.json').write_text(json.dumps({'receipt':str(O/'receipt.json')})+'\n')
print(json.dumps({k:receipt.get(k) for k in ['complete','forced_quit_after_frames','error','lock_released']},ensure_ascii=False))
