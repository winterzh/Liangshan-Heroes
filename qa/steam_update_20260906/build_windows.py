"""Import/export the immutable-snapshot copy with isolated user data; no upload."""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,time
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[1]
GODOT=Path(os.environ.get('GODOT_PATH') or (ROOT/'godot.local.txt').read_text(encoding='utf8').strip())
DATA=BASE/'userdata'/'export'
TEMPLATE=Path(os.environ['APPDATA'])/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe'
target=DATA/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe'
target.parent.mkdir(parents=True,exist_ok=True)
shutil.copy2(TEMPLATE,target)
env=os.environ.copy();env['APPDATA']=str(DATA);env['CONTENT_UPDATE_NO_AUTO']='1'
env.pop('SMOKE_TEST',None);env.pop('LEVEL',None);env.pop('SKIRMISH',None)
output=BASE/'windows'/'LiangshanHeroes.exe';output.parent.mkdir(parents=True,exist_ok=True)
assert not output.exists(),'No overwriting a previously exported build'
rows=[]
for name,args in [('import',['--headless','--path',str(BASE/'project'),'--editor','--quit']),
                  ('export',['--headless','--path',str(BASE/'project'),'--export-release','Windows Desktop',str(output)])]:
    command=[str(GODOT)]+args
    started=time.time()
    with (BASE/(name+'.log')).open('wb') as log:
        proc=subprocess.run(command,env=env,cwd=BASE,stdout=log,stderr=subprocess.STDOUT,timeout=900,creationflags=subprocess.CREATE_NO_WINDOW)
    log=(BASE/(name+'.log')).read_text(encoding='utf8',errors='replace')
    errors=re.findall(r'^.*(?:SCRIPT ERROR|Parse Error|ERROR:|Failed loading resource|Assertion failed).*$',log,re.M)
    warnings=re.findall(r'^.*WARNING:.*$',log,re.M)
    row={'name':name,'command':command,'exit_code':proc.returncode,'elapsed_seconds':round(time.time()-started,3),'errors':errors,'warnings':warnings}
    rows.append(row);print(json.dumps(row,ensure_ascii=False),flush=True)
    (BASE/'build_progress.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    assert proc.returncode==0 and not errors,row
subprocess.run(['py','-3','-X','utf8','-B',str(BASE/'freeze_snapshot.py'),'verify'],check=True)
d=json.loads((BASE/'source_manifest.json').read_text(encoding='utf8'))
r={'passed':True,'source_commit':d['source_commit'],'source_tree_sha256':d['source_tree_sha256'],'godot':str(GODOT),
   'godot_version':subprocess.check_output([str(GODOT),'--version'],creationflags=subprocess.CREATE_NO_WINDOW).decode().strip(),
   'template_sha256':hashlib.sha256(TEMPLATE.read_bytes()).hexdigest(),'template_copy_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
   'executable':str(output),'size_bytes':output.stat().st_size,'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'steps':rows}
(BASE/'build_receipt.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps(r,ensure_ascii=False,indent=2),flush=True)
