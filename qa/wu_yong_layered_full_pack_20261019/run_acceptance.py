"""Export the exact Unit-qualified private source, then probe the compiled PCK."""
from pathlib import Path
import datetime,hashlib,importlib.util,json,os,shutil,sys,uuid
Q=Path(__file__).resolve().parent;R=Q.parents[1]
E=Path('D:/CodexEvidence/shuihu/wu_yong_layered_full_pack_20261019')
U=Path('D:/CodexEvidence/shuihu/wu_yong_push_gait_20261018/unit_v2')
sys.path.insert(0,str(R/'tools'));import run_character_art_qa as common
from release_step import run_release_step
shared,running=common.load_helpers(R)
spec=importlib.util.spec_from_file_location('wu_pck_identity',R/'tools/contracts/run_content_identity_20260907/build_identity.py')
identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
assert not (E/'attempts').exists(),'Never repeat an attempted candidate'
assert not running() and not shared.LOCK.exists(),'shared engine lane occupied'
source_receipt=Path(json.loads((U/'latest.json').read_text())['receipt'])
passed=json.loads(source_receipt.read_text());assert passed['complete'] and passed['actual_unit_tested']
P=Path(passed['project']);generation=json.loads((U/'generation.json').read_text());root_before=json.loads((U/'root_before.json').read_text())
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]
O=E/'attempts'/stamp;O.mkdir(parents=True);runtime=O/'runtime';runtime.mkdir();W=O/'qa';W.mkdir()
receipt={'complete':False,'project':str(P),'qualified_unit_receipt':str(source_receipt),'qualified_unit_receipt_sha256':sha(source_receipt),'steps':[],'runner_sha256':sha(Path(__file__)),'identity_regenerated':False,'production_adopted':False,'full_goal_complete':False,'scope':'Exact Unit-qualified source exported to full compiled PCK; compiled identity/actual Unit art/ownership/three viewport probes. Separate normal release-template startup/exit smoke. No full wine/save/Steam/whole gait/performance/human acceptance.'};locked=False
try:
    with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(O))
    locked=True;assert not running()
    identity.verify_generated(P,generation);assert identity.snapshot(R)==root_before
    rows=json.loads((Q/'worker_bindings.json').read_text())['files']
    for row in rows:
        src=E/'workers'/row['path'];assert sha(src)==row['sha256'];shutil.copyfile(src,W/row['path'])
    save(W/'bindings.json',{x['path']:x['sha256'] for x in rows if x['path'] in ['base.gd','identity.gd','live.gd']})
    shutil.copyfile(U/'generation.json',O/'generation.json');assert sha(O/'generation.json')==sha(U/'generation.json')
    save(O/'expected_identity.json',{k:v for k,v in generation['identity'].items() if k not in ['files','directories']})
    engine=shared.resolve_godot(None);template=Path(os.environ['APPDATA'])/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe'
    phase=O/'export_profile';phase.mkdir();profile=shared.create_private_profile(phase,Path('D:/CodexQA/wu_full_export')/stamp);env=common.private_environment(profile)
    target=Path(env['APPDATA'])/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe';target.parent.mkdir(parents=True);shutil.copyfile(template,target);assert sha(target)==sha(template)
    pck=runtime/'LiangshanHeroes.pck'
    common.process_step(engine,P,env,O,'full_export',['--headless','--editor','--export-pack','Windows Steam',str(pck)],900,'gl_compatibility',running,receipt['steps'])
    assert pck.stat().st_size>1000000
    exe=runtime/'LiangshanHeroes.exe';shutil.copyfile(template,exe);assert sha(exe)==sha(template)
    receipt['native_runtime_provenance']=shared.install_native(runtime)
    for name,manifest in shared.native_dependencies().items():
        for row in manifest['files']:
            source=R/'vendor'/name/row['path']
            if source.suffix.lower()=='.dll':
                dest=runtime/source.name;shutil.copyfile(source,dest);assert sha(dest)==row['sha256']
    loader=runtime/engine.name;shutil.copyfile(engine,loader);assert sha(loader)==sha(engine)
    receipt['pck']={'path':str(pck),'sha256':sha(pck),'bytes':pck.stat().st_size}
    receipt['release_exe']={'path':str(exe),'sha256':sha(exe)}
    receipt['pck_loader']={'path':str(loader),'sha256':sha(loader),'kind':'unchanged_editor_copy_beside_canonical_DLLs'}
    for kind,worker in [('identity','identity.gd'),('visual','live.gd')]:
        phase=O/(kind+'_profile');phase.mkdir();profile=shared.create_private_profile(phase,Path('D:/CodexQA/wu_full_'+kind)/stamp);env=common.private_environment(profile)
        env.update(HG_WORKER=str(W/worker),HG_WORKER_ROOT=str(W),HG_QA_BINDINGS=str(W/'bindings.json'),HG_EXPECTED_IDENTITY=str(O/'expected_identity.json'),HG_EXPECTED_EXE_SHA=sha(loader),HG_REPORT=str(O/'identity_report.json'),HG_OUTPUT_ROOT=str(O),WU_ART_OUT=str(O/'visual'),WU_ART_INPUTS=str(W/'runtime_inputs.json'))
        args=['--main-pack',str(pck),'--script',str(W/'bootstrap.gd')]+(['--headless'] if kind=='identity' else ['--resolution','1280x720','--position','30000,30000'])
        common.process_step(loader,runtime,env,O,'compiled_'+kind,args,360,'gl_compatibility',running,receipt['steps'])
        report=json.loads((O/('identity_report.json' if kind=='identity' else 'visual/report.json')).read_text());assert report['passed'] and not report['failures']
        receipt[kind+'_checks']=len(report['checks']) if kind=='identity' else report['checks']
        if kind=='visual':receipt['screenshots']=len(report['screenshots'])
    phase=O/'normal_release';phase.mkdir();profile=shared.create_private_profile(phase,Path('D:/CodexQA/wu_full_release')/stamp);env=common.private_environment(profile)|{'LEVEL':'1'}
    run_release_step(exe,runtime,env,phase,'normal_release_480_frames',['--resolution','1280x720','--position','30000,30000','--fixed-fps','60','--quit-after','480'],180,common,running,receipt['steps'])
    identity.verify_generated(P,generation);assert identity.snapshot(R)==root_before
    assert sha(pck)==receipt['pck']['sha256'] and sha(exe)==receipt['release_exe']['sha256']
    receipt.update(complete=True,root_unchanged=True,private_export_source_unchanged=True,source_sha256=generation['identity']['source_sha256'],normal_release_exit_passed=True)
except BaseException as error:receipt['error']=repr(error)
finally:
    receipt['preservation']=[]
    for rel in ['qa/chao_gai_layered_full_pack_20261018/runtime_after_adoption.json','qa/tribute_cart_wheel_unit_20261018/protected_next.json','qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json']:
        rows=json.loads((R/rel).read_text());changed=common.source_changes(R,rows);receipt['preservation'].append({'manifest':rel,'files':len(rows),'changed':changed})
        if changed:receipt.update(complete=False,preservation_error=rel)
    if locked and not running() and shared.LOCK.exists() and shared.LOCK.read_text()==str(O):shared.LOCK.unlink()
    receipt['lock_released']=not shared.LOCK.exists();save(O/'receipt.json',receipt)
save(E/'latest.json',{'receipt':str(O/'receipt.json')})
print(json.dumps({k:receipt.get(k) for k in ['complete','identity_checks','visual_checks','screenshots','normal_release_exit_passed','error','lock_released']}));assert receipt['complete']
