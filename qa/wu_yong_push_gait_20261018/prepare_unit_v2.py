"""Preserve the failed fixture, reuse only verified exact source and fix optional metadata lookup."""
from pathlib import Path
import hashlib,importlib.util,json,shutil
R=Path(__file__).resolve().parents[2];Q=Path(__file__).resolve().parent
old=Path('D:/CodexEvidence/shuihu/wu_yong_push_gait_20261018/unit');E=old.with_name('unit_v2')
assert not E.exists();E.mkdir()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
    with p.open('x',encoding='utf-8') as f:f.write(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
state=json.loads((old/'queue/state.json').read_text());assert state['state']=='terminal' and state['exit_code']==1
prior_path=Path(json.loads((old/'latest.json').read_text())['receipt']);prior=json.loads(prior_path.read_text());assert not prior['complete'] and prior['lock_released']
P=Path(prior['project']);generation=json.loads(prior_path.with_name('generation.json').read_text())
spec=importlib.util.spec_from_file_location('wu_fixed_fixture_identity',R/'tools/contracts/run_content_identity_20260907/build_identity.py');identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
identity.verify_generated(P,generation)
root_before=json.loads((old/'preparation/root_before.json').read_text());assert identity.snapshot(R)==root_before
driver=(old/'unit_driver.gd').read_text();needle='var prior_meta=other.get_meta("carrying_tribute",null)';replacement='var prior_meta=other.get_meta("carrying_tribute") if had_meta else null';assert driver.count(needle)==1
driver=driver.replace(needle,replacement);(E/'unit_driver.gd').write_text(driver,encoding='utf-8');(Q/'unit_driver_v2.gd.txt').write_text(driver,encoding='utf-8')
bootstrap=(old/'bootstrap.gd').read_text();needle=str(old/'unit_driver.gd').replace('\\','/');assert bootstrap.count(needle)==1
bootstrap=bootstrap.replace(needle,str(E/'unit_driver.gd').replace('\\','/'));(E/'bootstrap.gd').write_text(bootstrap,encoding='utf-8');(Q/'unit_bootstrap_v2.gd.txt').write_text(bootstrap,encoding='utf-8')
shutil.copyfile(old/'runtime_inputs.json',E/'runtime_inputs.json');shutil.copyfile(prior_path.with_name('generation.json'),E/'generation.json');shutil.copyfile(old/'preparation/root_before.json',E/'root_before.json')
binding={'prepared':True,'native_executed':False,'project':str(P),'prior_failure_receipt':str(prior_path),'prior_queue_terminal':state,'source_identity_reverified_exact':True,'source_sha256':generation['identity']['source_sha256'],'root_unchanged':True,'driver_sha256':sha(E/'unit_driver.gd'),'bootstrap_sha256':sha(E/'bootstrap.gd'),'runtime_inputs_sha256':sha(E/'runtime_inputs.json'),'fix':'Only inspect carrying_tribute metadata after has_meta. Godot null fallback still logs missing-meta ERROR; no gameplay/art assertion removed.','original_failed_driver_sha256':sha(old/'unit_driver.gd'),'production_changes':False,'reuse_scope':'Same exact imported/generated private source and native textures, new external fixture and fresh player profile. Not a new cold-import/export/SDK pass.'}
save(E/'binding.json',binding);save(Q/'unit_v2_binding.json',binding)
archive=Q/'unit_attempt_1';archive.mkdir();rows=[]
for src in sorted(prior_path.parent.iterdir()):
    if not src.is_file():continue
    dst=archive/src.name;shutil.copyfile(src,dst);assert sha(src)==sha(dst);rows.append({'original':str(src),'archive':src.name,'bytes':dst.stat().st_size,'sha256':sha(dst)})
for name in ['unit_driver.gd','bootstrap.gd']:
    src=old/name;dst=archive/(name+'.txt');shutil.copyfile(src,dst);rows.append({'original':str(src),'archive':dst.name,'bytes':dst.stat().st_size,'sha256':sha(dst)})
save(archive/'archive_index.json',rows)
save(Q/'unit_attempt_1_diagnosis.json',{'actual_engine_executed':True,'cold_import_passed':True,'actual_unit_passed':False,'failure':'Two missing carrying_tribute metadata errors from external owner-regression fixture. Observer stopped process before route report/captures.','gameplay_or_art_pass_not_inferred':True,'private_source_identity_reverified':True,'production_runtime_unchanged':True,'successor':'unit_v2_binding.json','old_failure_unchanged':True})
print(json.dumps({'prepared':True,'same_source_identity':True,'driver_only_optional_meta_fix':True,'old_failed_attempt_archived':True}))
