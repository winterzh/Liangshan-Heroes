from hotfix_runtime import run_child, private_env
import sys
"""Exercise a frozen EXE and its embedded PCK without touching player data."""
from pathlib import Path
import hashlib,json,os,re,subprocess,time
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[1]
build=json.loads((BASE/'build_receipt.json').read_text(encoding='utf8'))
EXE=Path(build['executable']);GODOT=Path(build['godot'])
assert hashlib.sha256(EXE.read_bytes()).hexdigest()==build['sha256']
resources=[];sources=set()
for path in sorted((BASE/'source/assets/anim').glob('*.tres')):
    if not path.name.startswith(('song_jiang_','lin_chong_')):continue
    match=re.fullmatch(r'(song_jiang|lin_chong)_(idle|walk|attack|hurt|death)_(se|sw|ne|nw)\.tres',path.name)
    assert match,path
    key,state,direction=match.groups();text=path.read_text(encoding='utf8')
    sources.update(re.findall(r'path="(res://assets/characters/[^\"]+)"',text))
    resources.append({'path':'res://assets/anim/'+path.name,'key':key,'state':state,'direction':direction,
                      'frames':text.count('"duration":')})
expected={'source_commit':build['source_commit'],'sha256':build['sha256'],'project':str(BASE/'project'),
          'resources':resources,'sources':sorted(sources)}
(BASE/'package_expected.json').write_text(json.dumps(expected,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
env=os.environ.copy()
for key in ('SMOKE_TEST','LEVEL','SKIRMISH','SKIRMISH_AI','SCREENSHOT_DIR','DEFENSE_HARD_FIX_TEST','FINAL_CLEANUP_TEST'):
    env.pop(key,None)
env.update(CONTENT_UPDATE_NO_AUTO='1',PACKAGE_EXPECTED=str(BASE/'package_expected.json'),
           PACKAGE_MOUNTED_PACK=str(EXE),PACKAGE_REPORT=str(BASE/'package_contract.json'))
rows=[]
def execute(name,command,extra=None,timeout=300):
    case_env=private_env(name,env)
    case_env.update(extra or {});started=time.time()
    with (BASE/(name+'.console.log')).open('wb') as log:
        result=run_child(command,cwd=EXE.parent,env=case_env,stdout=log,stderr=subprocess.STDOUT,
                              timeout=timeout,creationflags=subprocess.CREATE_NO_WINDOW)
    text=(BASE/(name+'.console.log')).read_text(encoding='utf8',errors='replace')
    errors=re.findall(r'^.*(?:SCRIPT ERROR|Parse Error|ERROR:|Failed loading resource|Assertion failed).*$',text,re.M)
    warnings=re.findall(r'^.*WARNING:.*$',text,re.M)
    row={'name':name,'command':command,'exit_code':result.returncode,'elapsed_seconds':round(time.time()-started,3),
         'errors':errors,'warnings':warnings,'passed':result.returncode==0 and not errors and not warnings}
    rows.append(row);(BASE/'package_verification_progress.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps(row,ensure_ascii=False),flush=True);assert row['passed'],row

execute('contract',[str(GODOT),'--headless','--main-pack',str(EXE),'--script',str(BASE/'package_contract.gd')])

# Preserve the historical QA input as a new standalone helper. Never overwrite old receipts.
smoke=(BASE/'frozen_run_package_smoke.py').read_text(encoding='utf8')
smoke=smoke.replace('QA = Path(__file__).resolve().parent','QA = Path(__file__).resolve().parent / "smoke"\nQA.mkdir(exist_ok=True)')
(BASE/'run_package_smoke.py').write_text(smoke,encoding='utf8')
from hotfix_runtime import run_smoke
run_smoke(BASE/'run_package_smoke.py', EXE, env)

visual=(BASE/'frozen_package_visual_capture.gd').read_text(encoding='utf8')
visual=visual.replace('Godot console mounts', 'Godot 4.6.3 mounts')
visual=re.sub(r'const FROZEN_EXE_SHA256 := "[a-f0-9]+"','const FROZEN_EXE_SHA256 := "'+build['sha256']+'"',visual)
(BASE/'package_visual_capture.gd').write_text(visual,encoding='utf8')
execute('visual',[str(GODOT),'--main-pack',str(EXE),'--rendering-method','forward_plus','--rendering-driver','vulkan',
                  '--script',str(BASE/'package_visual_capture.gd')],{'PACKAGE_VISUAL_OUT':str(BASE/'visual')},timeout=600)

reports={'contract':json.loads((BASE/'package_contract.json').read_text(encoding='utf8')),
         'smoke':json.loads((BASE/'smoke/package_smoke.json').read_text(encoding='utf8')),
         'visual':json.loads((BASE/'visual/package_visual_capture.json').read_text(encoding='utf8'))}
assert all(r['passed'] for r in reports.values())
assert hashlib.sha256(EXE.read_bytes()).hexdigest()==build['sha256']
import runpy
runpy.run_path(str(BASE/'freeze_snapshot.py'),run_name='snapshot_verify')['verify']()
r={'passed':True,'source_commit':build['source_commit'],'overlay_commit':build['overlay_commit'],
   'source_tree_sha256':build['source_tree_sha256'],'source_manifest_sha256':build['source_manifest_sha256'],'executable':str(EXE),'size_bytes':EXE.stat().st_size,
   'sha256':build['sha256'],'steps':rows,'contract_checks':reports['contract']['check_count'],
   'smoke_cases':len(reports['smoke']['cases']),'visual_captures':len(reports['visual']['captures']),
   'visual_review_pending':True,'scope':'Short actual release EXE smoke and embedded PCK checks; not full human campaign or 30-wave/long-duration acceptance.'}
(BASE/'package_verification.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps(r,ensure_ascii=False,indent=2),flush=True)
