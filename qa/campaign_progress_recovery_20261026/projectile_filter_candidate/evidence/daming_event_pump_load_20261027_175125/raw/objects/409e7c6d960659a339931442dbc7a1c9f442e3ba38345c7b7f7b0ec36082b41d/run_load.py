from __future__ import annotations
import argparse, ast, importlib.util, json, subprocess, time, uuid
from pathlib import Path
R=Path(__file__).resolve().parents[2]
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
D=load('combined_daming',R/'qa/campaign_progress_recovery_20261026/daming_continue_candidate/tests/daming_negative_v2/run_negative.py')
p,h=D.p,D.h
ap=argparse.ArgumentParser();ap.add_argument('--run',action='store_true');args=ap.parse_args()
pins=D.source_pins()
for name in [str(Path(__file__).resolve()),*[n for n in pins if Path(n).suffix=='.py']]:ast.parse(p.fs(name).read_text(encoding='utf-8-sig'),filename=name)
groups={'negative_timing':(D.HERE,D.a.WORKERS)}
if not args.run:
    print(json.dumps({'named_pins':len(pins),'groups':{k:list(v[1]) for k,v in groups.items()},'engine_started':False,'full_source_qualified':False}));raise SystemExit(0)
S=Path(__file__).parent/h.stamp();p.fs(S).mkdir()
project=R/'.godot/campaign_progress_recovery_20261026/20261027_075456_3e4a48ab/project'
engine=Path('C:/Users/rsb/Desktop/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe')
engine_sha='ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00'
receipt={'schema':'daming_negative_event_pump_load_only_v1','complete':False,'steps':[],'worker_instantiated':False,'full_source_qualified':False,'runtime_qualified':False,'desktop_os_input':False,'battle_instantiated':False,'source_flow_chain_passed':False,'source_victory_chain_passed':False,'source_loss_chain_passed':False,'both_routes_qualified':False,'full_61_qualified':False,'native_sdk_qualified':False,'human_acceptance':False,'published':False,'named_source_count':len(pins)}
locked=False;owner=str(S);child=None
try:
    assert h.sha(engine)==engine_sha and not h.shared.LOCK.exists() and not h.running()
    with h.shared.LOCK.open('x',encoding='utf-8') as f:f.write(owner)
    locked=True;assert not h.running()
    p.pin(Path(__file__).resolve(),pins)
    for name,digest in list(pins.items()):
        original=Path(name);assert original.is_relative_to(R) and original.suffix.lower() not in ('.exe','.dll')
        frozen=S/'source_inputs'/original.relative_to(R)
        p.copy(original,frozen,digest);p.pin(frozen,pins,digest)
    p.copy(Path(__file__),S/'run_load.py',h.sha(__file__));p.pin(S/'run_load.py',pins)
    scripts=[]
    for label,(source,names) in groups.items():
        target=S/'workers'/label;p.fs(target).mkdir(parents=True)
        for name in names:
            p.copy(source/name,target/name,pins[str(source/name)]);p.pin(target/name,pins)
            scripts.append(str(target/name))
    loader=S/'loader.gd'
    loader.write_text('''extends SceneTree
func _initialize() -> void:
    check.call_deferred()
func check() -> void:
    var paths: Variant = JSON.parse_string(OS.get_environment("LOAD_SCRIPT_PATHS"))
    if not paths is Array or paths.size() != 8:
        push_error("INVALID_LOAD_ONLY_INVENTORY")
        quit(2)
        return
    for path: String in paths:
        var script: Script = load(path)
        if script == null or not script.can_instantiate():
            push_error("LOAD_ONLY_INVALID: " + path)
            quit(2)
            return
        print("LOAD_ONLY_PASS " + path)
    print("EIGHT_SCRIPTS_LOADED_WITHOUT_INSTANTIATION")
    quit(0)
''',encoding='utf-8')
    p.pin(loader,pins)
    profile=Path('D:/CodexQA/routereplayload')/uuid.uuid4().hex[:12]
    h.identity.no_links(profile);profile.mkdir(parents=True,exist_ok=False)
    env=h.common.private_environment(profile)
    for key in list(env):
        if key.startswith(('LT_','LL_','DF_','DN_','UST_','UCR_','USR_','URF_','UTR_','P19_','GVT_','GT_','LSH_CONTINUE_FLOW_')):env.pop(key)
    env.update(STEAM_DISABLED='1',CAMPAIGN_QA='',LSH_CONTINUE_FLOW_QA='',LOAD_SCRIPT_PATHS=json.dumps(scripts))
    command=[str(engine),'--headless','--path',str(project),'--script',str(loader)]
    started=time.monotonic(); child=subprocess.Popen(command,cwd=R,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    stopped=None
    try:stdout=child.communicate(timeout=150)[0]
    except subprocess.TimeoutExpired:
        stopped='timeout';child.kill();stdout=child.communicate()[0]
    log=S/'load.log';log.write_bytes(stdout);lines=stdout.decode('utf-8',errors='replace').splitlines()
    errors=[line for line in lines if 'ERROR:' in line or 'SCRIPT ERROR' in line]
    step={'pid':child.pid,'command':command,'exit_code':child.returncode,'seconds':round(time.monotonic()-started,3),'errors':errors,'stopped_for':stopped,'log_sha256':h.sha(log),'loaded_lines':[x for x in lines if x.startswith('LOAD_ONLY_PASS ')]}
    receipt['steps'].append(step);receipt['groups']={k:list(v[1]) for k,v in groups.items()}
    assert child.returncode==0 and stopped is None and not errors and len(step['loaded_lines'])==8
    receipt['native_load_passed']=True
except BaseException as error:receipt['error']=repr(error)
finally:
    post=[]
    if child is not None and child.poll() is None:
        try:
            child.terminate()
            try:child.wait(timeout=10)
            except subprocess.TimeoutExpired:child.kill();child.wait(timeout=10)
        except BaseException as e:post.append({'phase':'owned_child_cleanup','error':repr(e)})
    try:p.verify_pins(pins);receipt['final_pins_passed']=True
    except BaseException as e:post.append({'phase':'pins','error':repr(e)})
    try:assert h.sha(engine)==engine_sha;receipt['engine_unchanged']=True
    except BaseException as e:post.append({'phase':'engine','error':repr(e)})
    receipt.update(pinned_files=pins,runner_sha256=h.sha(__file__),engine_sha256=engine_sha,project=str(project),post_errors=post,
        child_terminal=child is None or child.poll() is not None,lane_idle=not h.running(),owner_confirmed=bool(locked and h.shared.LOCK.is_file() and h.shared.LOCK.read_text(encoding='utf-8')==owner))
    if receipt['owner_confirmed'] and receipt['child_terminal'] and receipt['lane_idle']:h.shared.LOCK.unlink()
    receipt['lock_released']=bool(locked and not h.shared.LOCK.exists())
    receipt['complete']=bool(receipt.get('native_load_passed') and not receipt.get('error') and not post and receipt['lock_released'])
    h.save(S/'receipt.json',receipt)
print(json.dumps({'output':str(S),'complete':receipt['complete'],'steps':receipt['steps'],'error':receipt.get('error')},ensure_ascii=False),flush=True)
raise SystemExit(0 if receipt['complete'] else 1)
