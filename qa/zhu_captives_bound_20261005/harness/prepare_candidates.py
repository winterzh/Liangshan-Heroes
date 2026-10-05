"""Retain raw built-in output bytes, exact requests, references and deterministic metadata."""
from pathlib import Path
import json,shutil,hashlib,subprocess,sys,re
from PIL import Image
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
rawbase=Path('C:/Users/Administrator/.codex/generated_images/01a1009d-487a-7213-8be1-dacfb17540a0')
ids={'yang_lin':'b312ccf6-55c9-4b90-9c64-315ba453c0ee','huang_xin':'8f06184d-8e3d-4b2c-a771-737161279412','wang_ying':'7becccb8-3706-4fbe-90ee-fcb7bd57e6e7','deng_fei':'8a61c659-de5d-4e4c-a8d1-97406e768539'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def call(args):
 r=subprocess.run([sys.executable,'-X','utf8','-B',*map(str,args)],cwd=repo,capture_output=True,text=True,encoding='utf-8');assert r.returncode==0,r.stdout+r.stderr;print(r.stdout.strip())
candidates=[]
for s in json.loads((base/'specs.json').read_text(encoding='utf-8')):
 key=s['key'];tag='bound_'+key+'_20261005';folder=repo/f'assets/characters/{key}_bound_20261005';contract=repo/f'tools/contracts/{key}_bound_20261005'
 assert not folder.exists() and not contract.exists();folder.mkdir();contract.mkdir(parents=True)
 raw=rawbase/('exec-'+ids[key]+'.png');dest=folder/'bound.png';shutil.copyfile(raw,dest);assert sha(raw)==sha(dest)
 im=Image.open(dest);assert im.mode=='RGBA' and max(im.size)<=1536
 request=s['request'] if key!='huang_xin' else json.loads((base/'huang_edit_request.json').read_text(encoding='utf-8'))
 write(contract/'generation_request.json',request)
 jobs=[{'key':'bound','method':'built_in_imagegen','generation_id':ids[key],'selected':True,'repository_input':dest.relative_to(repo).as_posix(),'sha256':sha(dest),'references':['original','body']+(['first_candidate'] if key=='huang_xin' else []),'prompt':request['prompt'],'original_reference_paths':request['referenced_image_paths'],'transparent_background':True,'request_file':(contract/'generation_request.json').relative_to(repo).as_posix(),'request_sha256':sha(contract/'generation_request.json')}]
 for ref,p in [('original','assets/'+s['sheet']),('body','assets/anim/'+key+'_walk.png')]:
  jobs.append({'key':ref,'method':'existing_project_reference','selected':False,'repository_input':p,'sha256':sha(repo/p),'references':[],'prompt':s['cell']+' only. '+s['identity'] if ref=='original' else 'Current existing '+key+' walking body and clothing reference only.'})
 if key=='huang_xin':
  parent=folder/'native_references';parent.mkdir();(parent/'.gdignore').write_bytes(b'')
  initial=parent/'first_candidate.png';src=rawbase/'exec-4d1eb336-a5e0-4064-871b-e1169eb76290.png';shutil.copyfile(src,initial);assert sha(src)==sha(initial)
  write(contract/'initial_request.json',s['request'])
  jobs.append({'key':'first_candidate','method':'built_in_imagegen','generation_id':'4d1eb336-a5e0-4064-871b-e1169eb76290','selected':False,'repository_input':initial.relative_to(repo).as_posix(),'sha256':sha(initial),'references':['original','body'],'prompt':s['request']['prompt'],'request_file':(contract/'initial_request.json').relative_to(repo).as_posix(),'request_sha256':sha(contract/'initial_request.json'),'rejection':'Initial top-right view faced right rather than SW. Required edit parent only; not qualified runtime art.'})
 write(contract/'jobs.json',jobs)
 template=(repo/'tools/contracts/shi_qian_bound_20261005/prepare.py').read_text(encoding='utf-8').replace('bound-Shi-Qian','bound-'+key).replace('bound_shi_qian','bound_'+key)
 template=template.replace('Current Shi Qian portraits18 middle-right: black headwrap/mask, charcoal plain cloth and wrapped boots. Standing captive with front wrist and torso rope; no bag, armor or weapon.',s['cell']+' '+s['identity']+' Front wrist-bound unarmed standing foot captive.')
 template=template.replace('virtual*.78/(b-t)',f"virtual*{s['height']}/(b-t)")
 (contract/'prepare.py').write_text(template,encoding='utf-8')
 old='assets/characters/shi_qian_bound_20261005/bound.png';new=dest.relative_to(repo).as_posix()
 meta=(repo/(old+'.import')).read_text(encoding='utf-8');meta=re.sub(r'^uid=.*\n','',meta,flags=re.M).replace(old,new).replace(hashlib.md5(('res://'+old).encode()).hexdigest(),hashlib.md5(('res://'+new).encode()).hexdigest());(folder/'bound.png.import').write_text(meta,encoding='utf-8')
 call([contract/'prepare.py']);call([repo/'tools/build_directional_spriteframes.py','assets/direction4/'+tag+'.json','--write']);call([repo/'tools/directional_character_sources.py','assets/direction4/'+tag+'.json',str((contract/'generation.json').relative_to(repo)),'--out','qa/'+tag+'/source_audit.json'])
 candidates.append({'key':key,'native_path':str(raw),'repository_path':new,'sha256':sha(dest),'size':im.size,'method':'built_in_imagegen','native_pixels_edited':False,'direct_review':'Full four separately drawn front/back standing captive views, current headwear/clothes/beard, empty front wrist binding and torso rope, no weapon/banner/background. Huang corrected SW faces left. Runtime qualification pending.'})
write(base/'candidates.json',candidates)
# A single isolated import probe checks all four real dimensions and persists engine UIDs.
bootstrap=Path('E:/ChatGPT/qa-shi-qian-bound-20261005/texture_bootstrap.py').read_text(encoding='utf-8')
bootstrap=bootstrap.replace("inputs=list(json.loads((repo/'assets/direction4/bound_shi_qian_20261005.json').read_text(encoding='utf-8'))['sources'].values())","inputs=[]\nfor key in ['yang_lin','huang_xin','wang_ying','deng_fei']:\n inputs+=list(json.loads((repo/f'assets/direction4/bound_{key}_20261005.json').read_text(encoding='utf-8'))['sources'].values())").replace('ShiQianBoundNativeTextureProbe','ZhuCaptivesBoundNativeTextureProbe')
(base/'texture_bootstrap.py').write_text(bootstrap,encoding='utf-8')
p=repo/'scripts/campaign_art.gd';content=p.read_bytes();old=b'const NATIVE_BOUND_VARIANTS := {"bound_qin_ming": "qin_ming", "bound_shi_qian": "shi_qian"}'
assert content.count(old)==1
new=old[:-1]+b', "bound_yang_lin": "yang_lin", "bound_huang_xin": "huang_xin", "bound_wang_ying": "wang_ying", "bound_deng_fei": "deng_fei"}'
p.write_bytes(content.replace(old,new))
p=repo/'.gitattributes';text='\n# Exact native remaining Zhu captives and verified evidence bytes.\n'
for key in ids:
 text+=f'assets/characters/{key}_bound_20261005/** -text -whitespace\nassets/direction4/bound_{key}_20261005.json -text -whitespace\nassets/anim/bound_{key}_idle_*.tres -text -whitespace\ntools/contracts/{key}_bound_20261005/** -text -whitespace\nqa/bound_{key}_20261005/** -text -whitespace\n'
text+='tools/zhu_captives_bound_qa.gd -text -whitespace\ntools/run_zhu_captives_bound_qa.py -text -whitespace\nqa/zhu_captives_bound_20261005/** -text -whitespace\n';p.write_bytes(p.read_bytes()+text.encode())
print(json.dumps({'candidates':len(candidates),'PNG_pixels_edited':False}))
