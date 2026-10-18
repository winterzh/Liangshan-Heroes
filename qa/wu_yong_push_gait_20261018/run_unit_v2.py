"""A fresh native Unit fixture attempt over the exact verified imported source."""
from pathlib import Path
import datetime,hashlib,importlib.util,json,sys,uuid
R=Path(__file__).resolve().parents[2];Q=Path(__file__).resolve().parent;E=Path('D:/CodexEvidence/shuihu/wu_yong_push_gait_20261018/unit_v2')
sys.path.insert(0,str(R/'tools'));import run_character_art_qa as common
shared,running=common.load_helpers(R)
spec=importlib.util.spec_from_file_location('wu_v2_identity',R/'tools/contracts/run_content_identity_20260907/build_identity.py');identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
assert not (E/'actual_native').exists(),'Do not rerun an attempted successor'
assert not running() and not shared.LOCK.exists(),'shared Godot lane occupied'
binding=json.loads((E/'binding.json').read_text());assert binding['prepared'];P=Path(binding['project'])
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8];O=E/'actual_native'/stamp;O.mkdir(parents=True)
receipt={'complete':False,'project':str(P),'binding':str(E/'binding.json'),'prior_failure_receipt':binding['prior_failure_receipt'],'same_source_reused':True,'cold_import_repeated':False,'steps':[],'actual_unit_tested':False,'compiled_package_tested':False,'production_adopted':False,'full_wine_sequence_tested':False,'explicit_post_drug_fixture':True,'runner_sha256':sha(Path(__file__))};locked=False
try:
    with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(O))
    locked=True;assert not running()
    generation=json.loads((E/'generation.json').read_text());identity.verify_generated(P,generation);assert identity.snapshot(R)==json.loads((E/'root_before.json').read_text())
    for name in ['driver','bootstrap','runtime_inputs']:assert sha(E/({'driver':'unit_driver.gd','bootstrap':'bootstrap.gd','runtime_inputs':'runtime_inputs.json'}[name]))==binding[name+'_sha256']
    profile=shared.create_private_profile(O,Path('D:/CodexQA/wugait_unit_v2_profiles'));env=common.private_environment(profile);engine=shared.resolve_godot(None)
    receipt.update(profile=str(profile),engine_sha256=sha(engine),driver_sha256=binding['driver_sha256'],bootstrap_sha256=binding['bootstrap_sha256'],runtime_inputs_sha256=binding['runtime_inputs_sha256'])
    common.process_step(engine,P,env|{'WU_ART_OUT':str(O/'route'),'WU_ART_INPUTS':str(E/'runtime_inputs.json')},O,'actual_unit',['--resolution','1280x720','--position','30000,30000','--script',str(E/'bootstrap.gd')],600,'gl_compatibility',running,receipt['steps'])
    report=json.loads((O/'route/report.json').read_text());assert report['passed'] and not report['failures'];identity.verify_generated(P,generation);assert identity.snapshot(R)==json.loads((E/'root_before.json').read_text())
    receipt.update(complete=True,actual_unit_tested=True,checks=report['checks'],screenshots=len(report['screenshots']),source_sha256=generation['identity']['source_sha256'],root_unchanged=True)
except BaseException as error:receipt['error']=repr(error)
finally:
    receipt['preservation']=[]
    for rel in ['qa/chao_gai_layered_full_pack_20261018/runtime_after_adoption.json','qa/tribute_cart_wheel_unit_20261018/protected_next.json','qa/ruan_xiaoqi_walk_grips_20261018/preservation/unrelated_before.json']:
        rows=json.loads((R/rel).read_text());changed=common.source_changes(R,rows);receipt['preservation'].append({'manifest':rel,'files':len(rows),'changed':changed})
        if changed:receipt.update(complete=False,preservation_error=rel)
    if locked and not running() and shared.LOCK.exists() and shared.LOCK.read_text()==str(O):shared.LOCK.unlink()
    receipt['lock_released']=not shared.LOCK.exists();save(O/'receipt.json',receipt)
save(E/'latest.json',{'receipt':str(O/'receipt.json')});print(json.dumps({k:receipt.get(k) for k in ['complete','checks','screenshots','error','lock_released']}));assert receipt['complete']
