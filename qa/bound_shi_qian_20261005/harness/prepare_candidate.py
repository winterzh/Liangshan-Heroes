"""Copy native bytes and derive reproducible metadata; no image pixel edits."""
from pathlib import Path
import shutil,json,hashlib,subprocess,sys
from PIL import Image
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
raw=Path('C:/Users/Administrator/.codex/generated_images/01a1009d-487a-7213-8be1-dacfb17540a0/exec-97cb8bbd-2db9-4261-978e-482ece6e9844.png')
folder=repo/'assets/characters/shi_qian_bound_20261005';assert not folder.exists();folder.mkdir()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
dest=folder/'bound.png';shutil.copyfile(raw,dest);assert sha(raw)==sha(dest)
im=Image.open(dest);assert im.mode=='RGBA' and max(im.size)<=1536
request=json.loads((base/'generation_request.json').read_text(encoding='utf-8'))
contract=repo/'tools/contracts/shi_qian_bound_20261005';contract.mkdir(parents=True)
shutil.copyfile(base/'generation_request.json',contract/'generation_request.json')
jobs=[{'key':'bound','method':'built_in_imagegen','generation_id':'97cb8bbd-2db9-4261-978e-482ece6e9844','selected':True,'repository_input':dest.relative_to(repo).as_posix(),'sha256':sha(dest),'references':['original','body'],'prompt':request['prompt'],'original_reference_paths':request['referenced_image_paths'],'transparent_background':True,'request_file':'tools/contracts/shi_qian_bound_20261005/generation_request.json','request_sha256':sha(contract/'generation_request.json')}]
for key,p in [('original','assets/portraits18.png'),('body','assets/anim/shi_qian_walk.png')]:
    jobs.append({'key':key,'method':'existing_project_reference','selected':False,'repository_input':p,'sha256':sha(repo/p),'references':[],'prompt':'Current Shi Qian '+('identity portrait sheet MIDDLE ROW RIGHT CELL only.' if key=='original' else 'existing unarmored black-cloth masked walking body reference only.')})
(contract/'jobs.json').write_text(json.dumps(jobs,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
prepare=(repo/'tools/contracts/qin_ming_bound_20261005/prepare.py').read_text(encoding='utf-8').replace('bound-Qin','bound-Shi-Qian').replace('bound_qin_ming','bound_shi_qian')
prepare=prepare.replace('Current Qin Ming red headscarf, curly beard, golden beast shoulders, red robe. Standing foot captive with front wrist and torso ropes, no weapon/mount/blood.','Current Shi Qian portraits18 middle-right: black headwrap/mask, charcoal plain cloth and wrapped boots. Standing captive with front wrist and torso rope; no bag, armor or weapon.')
prepare=prepare.replace('Source candidate; native import/runtime integration pending. Not generic combat or death.','Only authored idle; walk/hurt standing fallback, no generic combat or death borrowing. Runtime acceptance requires separate final receipt.')
(contract/'prepare.py').write_text(prepare,encoding='utf-8')
descriptor=(repo/'assets/characters/qin_ming_bound_20261005/bound.png.import').read_text(encoding='utf-8')
old='assets/characters/qin_ming_bound_20261005/bound.png';new=dest.relative_to(repo).as_posix()
import re
descriptor=re.sub(r'^uid=.*\n','',descriptor,flags=re.M)
descriptor=descriptor.replace(old,new).replace(hashlib.md5(('res://'+old).encode()).hexdigest(),hashlib.md5(('res://'+new).encode()).hexdigest())
(folder/'bound.png.import').write_text(descriptor,encoding='utf-8')
assert subprocess.call([sys.executable,'-X','utf8','-B',str(contract/'prepare.py')],cwd=repo)==0
(base/'candidate.json').write_text(json.dumps({'native_path':str(raw),'repository_path':new,'sha256':sha(dest),'size':im.size,'alpha_zero_fraction':im.getchannel('A').histogram()[0]/(im.width*im.height),'method':'built_in_imagegen','native_pixels_edited':False,'direct_review':'Four independent masked charcoal-cloth standing prisoners. Empty front bound wrists, torso rope, rear hands naturally occluded; no bag/weapon/armor/crop or backdrop. Runtime not yet qualified.'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
bootstrap=(Path('E:/ChatGPT/qa-qin-ming-bound-20261005')/'texture_bootstrap.py').read_text(encoding='utf-8').replace('bound_qin_ming_20261005','bound_shi_qian_20261005').replace('QinMingBound','ShiQianBound')
(base/'texture_bootstrap.py').write_text(bootstrap,encoding='utf-8')
print(json.dumps({'native_sha256':sha(dest),'size':im.size,'copied_original_bytes':True}))
