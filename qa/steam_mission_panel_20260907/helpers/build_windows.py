from hotfix_runtime import run_child, private_env
import sys
"""Import/export the immutable-snapshot copy with isolated user data; no upload."""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,time
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[1]
GODOT=Path(os.environ.get('GODOT_PATH') or (ROOT/'godot.local.txt').read_text(encoding='utf8').strip())
DATA=Path(os.environ['HOTFIX_PROFILE'])/'export'/'appdata'
TEMPLATE=Path(os.environ['GODOT_RELEASE_TEMPLATE'])
target=DATA/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe'
target.parent.mkdir(parents=True,exist_ok=True)
shutil.copy2(TEMPLATE,target)
env=private_env('export');env['CONTENT_UPDATE_NO_AUTO']='1'
env.pop('SMOKE_TEST',None);env.pop('LEVEL',None);env.pop('SKIRMISH',None)
output=BASE/'windows'/'LiangshanHeroes.exe';output.parent.mkdir(parents=True,exist_ok=True)
assert not output.exists(),'No overwriting a previously exported build'
rows=[]
for name,args in [('import',['--headless','--path',str(BASE/'project'),'--editor','--quit']),
                  ('export',['--headless','--path',str(BASE/'project'),'--export-release','Windows Desktop',str(output)])]:
    command=[str(GODOT)]+args
    started=time.time()
    with (BASE/(name+'.log')).open('wb') as log:
        proc=run_child(command,env=env,cwd=BASE,stdout=log,stderr=subprocess.STDOUT,timeout=900,creationflags=subprocess.CREATE_NO_WINDOW)
    log=(BASE/(name+'.log')).read_text(encoding='utf8',errors='replace')
    errors=re.findall(r'^.*(?:SCRIPT ERROR|Parse Error|ERROR:|Failed loading resource|Assertion failed).*$',log,re.M)
    warnings=re.findall(r'^.*WARNING:.*$',log,re.M)
    row={'name':name,'command':command,'exit_code':proc.returncode,'elapsed_seconds':round(time.time()-started,3),'errors':errors,'warnings':warnings}
    rows.append(row);print(json.dumps(row,ensure_ascii=False),flush=True)
    (BASE/'build_progress.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    assert proc.returncode==0 and not errors and not warnings,row
import runpy
runpy.run_path(str(BASE/'freeze_snapshot.py'),run_name='snapshot_verify')['verify']()
d=json.loads((BASE/'source_manifest.json').read_text(encoding='utf8'))
r={'passed':True,'source_commit':d['source_commit'],'source_tree_sha256':d['source_tree_sha256'],'godot':str(GODOT),'godot_sha256':hashlib.sha256(GODOT.read_bytes()).hexdigest(),
   'godot_version':run_child([str(GODOT),'--version'],env=env,capture_output=True,timeout=30).stdout.decode().strip(),
   'overlay_commit':d['overlay_commit'],'overlays':d['overlays'],'source_manifest_sha256':hashlib.sha256((BASE/'source_manifest.json').read_bytes()).hexdigest(),
   'template_sha256':hashlib.sha256(TEMPLATE.read_bytes()).hexdigest(),'template_copy_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
   'executable':str(output),'size_bytes':output.stat().st_size,'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'steps':rows}
(BASE/'build_receipt.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps(r,ensure_ascii=False,indent=2),flush=True)
