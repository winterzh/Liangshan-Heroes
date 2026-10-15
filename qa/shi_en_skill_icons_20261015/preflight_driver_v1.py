"""Resume the disk-full icon export using an exact retained import snapshot.

Keeps the prior failure untouched. New pack, logs and isolated profile use C:.
Refuses production/source differences or a noncanonical generated identity.
"""
import argparse, importlib.util, json, os, shutil, time, uuid
from pathlib import Path
import run_character_art_qa as common
from run_shi_en_packed_hud_20261015 import ROOT, SCRIPT, REFERENCE, SELF, file_sha

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('prior_run',type=Path)
    ap.add_argument('--work-root',type=Path,required=True)
    args=ap.parse_args()
    prior=args.prior_run.resolve()
    project=ROOT/'.godot/shi_en_packed_hud_20261015'/prior.name/'project'
    shared,running=common.load_helpers(ROOT);engine=shared.resolve_godot(None)
    if running() or shared.LOCK.exists():raise RuntimeError('Shared engine occupied')
    helper=ROOT/'tools/contracts/run_content_identity_20260907/build_identity.py'
    spec=importlib.util.spec_from_file_location('shi_en_icon_recovery_identity',helper)
    identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
    identity.private_staging(project)
    names=sorted(set(shared.sources())|set(common.TOOLS)|{SCRIPT,REFERENCE,SELF,'tools/run_character_art_qa.py'})
    original_path=ROOT/'qa/shi_en_skill_icons_20261015/native_import_prior/receipt.json'
    original=json.loads(original_path.read_text())
    assert set(names)=={row['path'] for row in original['source_files']},'Original freeze input scope changed'
    rows=[{'path':p,'sha256':common.sha(ROOT/p)} for p in names]
    assert not common.source_changes(project,rows),'Retained import snapshot differs from current sources'
    record=identity.snapshot(project)
    # The installed snapshot additionally binds verified DLLs and import-generated
    # metadata/UIDs. Compare every original frozen source above; the installed
    # identity is deliberately not the unimported checkout identity.
    raw=(project/identity.DERIVED).read_bytes()
    assert raw==identity.identity_constant(record),'Retained identity is not canonical'
    generated={'identity':record,'derived':{'bytes':len(raw),'sha256':identity.sha(raw)}}
    identity.verify_generated(project,generated)
    inputs=json.loads((prior/'evidence/inputs.json').read_text())
    assert set(inputs['skill_icons'])=={'shi_en_'+s for s in 'qwer'} and len(inputs['textures'])==29
    work=shared.resolve_profile_root(args.work_root)
    run=work/('recovered_'+time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8])
    evidence=run/'evidence';runtime=run/'clean_runtime'
    receipt={'complete':False,'run':str(run),'project':str(project),'source_files':rows,'steps':[],
        'recovered_from_disk_full_run':str(prior),'generated_identity':generated,
        'original_freeze_receipt_sha256':common.sha(original_path),
        'godot_sha256':common.sha(engine),'identity_generator_sha256':common.sha(helper),
        'recovery_driver_sha256':common.sha(Path(__file__)),'steam_updated':False,
        'scope':'Retained identical full import snapshot, warm import then new full PCK export to C:, actual packed actions/HUD/icons. No release EXE, live SDK, Steam or full art acceptance.'}
    locked=False
    try:
        with shared.LOCK.open('x',encoding='utf-8') as lock:lock.write(str(run))
        locked=True
        if running():raise RuntimeError('Foreign engine appeared')
        evidence.mkdir(parents=True);runtime.mkdir()
        receipt['native_dependencies']=shared.install_native(project)
        profile=shared.create_private_profile(run,work/'profiles');env=common.private_environment(profile)
        receipt['private_profile']=str(profile)
        template=Path(os.environ['APPDATA'])/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe'
        dest=Path(env['APPDATA'])/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe'
        dest.parent.mkdir(parents=True);shutil.copyfile(template,dest)
        input_path=evidence/'inputs.json';shutil.copyfile(prior/'evidence/inputs.json',input_path)
        receipt['inputs_sha256']=common.sha(input_path)
        common.process_step(engine,project,env,evidence,'warm_import',['--headless','--editor','--import','--quit'],300,'gl_compatibility',running,receipt['steps'])
        common.process_step(engine,project,env,evidence,'parse_scene_probe',['--headless','--check-only','--script','res://'+SCRIPT],60,'gl_compatibility',running,receipt['steps'])
        reference=evidence/'texture_references.json'
        common.process_step(engine,project,env|{'SHI_EN_PACK_INPUTS':str(input_path),'SHI_EN_TEXTURE_REFERENCE_OUT':str(reference)},evidence,'source_texture_reference',['--headless','--script','res://'+REFERENCE],90,'gl_compatibility',running,receipt['steps'])
        assert json.loads(reference.read_text())==json.loads((prior/'evidence/texture_references.json').read_text())
        receipt['texture_reference_sha256']=common.sha(reference)
        identity.verify_generated(project,generated)
        assert not common.source_changes(project,rows) and not common.source_changes(ROOT,rows)
        pack=runtime/'LiangshanShiEn.pck'
        common.process_step(engine,project,env,evidence,'export_pack',['--headless','--editor','--export-pack','Windows Steam',str(pack)],300,'gl_compatibility',running,receipt['steps'])
        receipt.update(pack_sha256=file_sha(pack),pack_bytes=pack.stat().st_size)
        assert shared.install_native(runtime)==receipt['native_dependencies']
        for path in sorted((ROOT/'vendor').glob('*/provenance.json')):
            for row in json.loads(path.read_text())['files']:
                if row['path'].endswith('.dll'):
                    source=path.parent/row['path'];assert common.sha(source)==row['sha256']
                    dest=runtime/source.name
                    if not dest.exists():shutil.copyfile(source,dest)
                    assert common.sha(dest)==row['sha256']
        assert not any(p.suffix=='.png' for p in runtime.rglob('*'))
        common.process_step(engine,runtime,env|{'SHI_EN_ART_OUT':str(evidence/'visual'),'SHI_EN_PACK_INPUTS':str(input_path),'SHI_EN_TEXTURE_REFERENCE':str(reference)},evidence,'packed_actions_hud',['--main-pack',str(pack),'--position','30000,30000','--script',str(project/SCRIPT)],360,'gl_compatibility',running,receipt['steps'])
        report=json.loads((evidence/'visual/report.json').read_text())
        assert report['passed'] and not report['failures']
        receipt.update(checks=len(report['checks']),screenshots=len(report['screenshots']))
        receipt['source_changes']=common.source_changes(ROOT,rows);receipt['private_source_changes']=common.source_changes(project,rows)
        assert not receipt['source_changes'] and not receipt['private_source_changes']
        identity.verify_generated(project,generated);assert file_sha(pack)==receipt['pack_sha256']
        assert receipt['recovery_driver_sha256']==common.sha(Path(__file__))
        receipt['complete']=True
    except Exception as error:receipt['error']=repr(error)
    finally:
        if locked and shared.LOCK.exists() and shared.LOCK.read_text(encoding='utf-8')==str(run) and not running():shared.LOCK.unlink()
        receipt['lock_released']=locked and not shared.LOCK.exists();evidence.mkdir(parents=True,exist_ok=True)
        (evidence/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:receipt.get(k) for k in ['complete','run','checks','screenshots','error']},ensure_ascii=False))
    if not receipt['complete']:raise SystemExit(1)

if __name__=='__main__':main()
