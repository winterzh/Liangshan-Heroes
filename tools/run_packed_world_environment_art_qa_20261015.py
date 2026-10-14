"""Export current full game resources and inspect Level7 from a clean PCK runtime."""
import importlib.util,json,os,shutil,time,uuid
from pathlib import Path
import run_character_art_qa as common
ROOT=Path(__file__).resolve().parents[1]
SCRIPT='tools/packed_world_environment_art_qa_20261015.gd'
def main():
    shared,running=common.load_helpers(ROOT);engine=shared.resolve_godot(None)
    if running() or shared.LOCK.exists():raise RuntimeError('Shared Godot slot occupied')
    work=shared.resolve_profile_root(Path('D:/CodexTemp/packed_world_art_20261015'))
    run=work/(time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8])
    # The existing identity generator admits only ignored private staging under
    # its owning checkout. Keep external evidence/profile/runtime separate.
    project=ROOT/'.godot/packed_world_art_20261015'/run.name/'project'
    evidence,runtime=run/'evidence',run/'clean_runtime'
    helper_path=ROOT/'tools/contracts/run_content_identity_20260907/build_identity.py'
    spec=importlib.util.spec_from_file_location('art_export_identity',helper_path)
    identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
    names=sorted(set(shared.sources())|set(common.TOOLS)|{SCRIPT,'tools/run_packed_world_environment_art_qa_20261015.py','tools/run_character_art_qa.py'})
    assert identity.DERIVED not in names and not (ROOT/identity.DERIVED).exists()
    receipt={'complete':False,'run':str(run),'project':str(project),'source_files':[],'steps':[],'godot_sha256':common.sha(engine),'identity_generator_sha256':common.sha(helper_path),'scope':'Actual full-game resource PCK art rendering via isolated editor; no release EXE, live SDK, platform publication or full gameplay qualification.'}
    locked=False
    try:
        with shared.LOCK.open('x',encoding='utf-8') as lock:lock.write(str(run))
        locked=True
        run.mkdir(parents=True);project.mkdir(parents=True);evidence.mkdir();runtime.mkdir()
        for name in names:
            common.relative_source(ROOT,name)
            target=project/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((ROOT/name).read_bytes())
            receipt['source_files'].append({'path':name,'sha256':common.sha(target)})
        receipt['native_dependencies']=shared.install_native(project)
        profile=shared.create_private_profile(run,work/'profiles');env=common.private_environment(profile)
        receipt['private_profile']=str(profile)
        template=Path(os.environ['APPDATA'])/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe'
        target=Path(env['APPDATA'])/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe'
        target.parent.mkdir(parents=True);shutil.copyfile(template,target)
        receipt['template_sha256']=common.sha(template)
        receipt['identity_seed']=identity.seed(project)
        common.process_step(engine,project,env,evidence,'import',['--headless','--editor','--import','--quit'],300,'gl_compatibility',running,receipt['steps'])
        receipt['generated_identity']=identity.generate(project)
        assert not common.source_changes(project,receipt['source_files'])
        pack=runtime/'LiangshanArt.pck'
        common.process_step(engine,project,env,evidence,'export_pack',['--headless','--editor','--export-pack','Windows Steam',str(pack)],300,'gl_compatibility',running,receipt['steps'])
        identity.verify_generated(project,receipt['generated_identity'])
        receipt.update(pack_sha256=common.sha(pack),pack_bytes=pack.stat().st_size)
        # An editor loading a standalone PCK still resolves native libraries at
        # their declared addon paths; retain both those and exporter sidecars.
        runtime_dependencies=shared.install_native(runtime)
        assert runtime_dependencies==receipt['native_dependencies']
        for path in sorted((ROOT/'vendor').glob('*/provenance.json')):
            manifest=json.loads(path.read_text(encoding='utf-8'))
            for row in manifest['files']:
                if row['path'].endswith('.dll'):
                    source=path.parent/row['path'];assert common.sha(source)==row['sha256']
                    destination=runtime/source.name
                    if not destination.exists():shutil.copyfile(source,destination)
                    assert common.sha(destination)==row['sha256']
        assert pack.is_file() and not any(p.suffix=='.png' for p in runtime.rglob('*'))
        inputs=json.loads((ROOT/'qa/market_stall_art_20261015/source_manifest.json').read_text(encoding='utf-8'))
        inputs['taverns']=json.loads((ROOT/'qa/roadside_tavern_variants_20261015/source_manifest.json').read_text(encoding='utf-8'))['variants']
        input_path=evidence/'world_inputs.json';input_path.write_text(json.dumps(inputs,ensure_ascii=False,indent=2),encoding='utf-8')
        receipt['world_inputs_sha256']=common.sha(input_path)
        command=['--main-pack',str(pack),'--position','30000,30000','--script',str(project/SCRIPT)]
        common.process_step(engine,runtime,env|{'PACKED_WORLD_ART_OUT':str(evidence/'visual'),'PACKED_WORLD_ART_INPUTS':str(input_path)},evidence,'packed_world',command,240,'gl_compatibility',running,receipt['steps'])
        report=json.loads((evidence/'visual/report.json').read_text(encoding='utf-8'))
        assert report['passed'] and not report['failures']
        receipt['checks']=len(report['checks'])
        receipt['source_changes']=common.source_changes(ROOT,receipt['source_files'])
        receipt['private_source_changes']=common.source_changes(project,receipt['source_files'])
        assert not receipt['source_changes'] and not receipt['private_source_changes']
        identity.verify_generated(project,receipt['generated_identity'])
        receipt.update(pack_sha256=common.sha(pack),pack_bytes=pack.stat().st_size,complete=True)
    except Exception as exc:receipt['error']=repr(exc)
    finally:
        if locked and shared.LOCK.read_text(encoding='utf-8')==str(run):shared.LOCK.unlink()
        receipt['lock_released']=locked and not shared.LOCK.exists()
        evidence.mkdir(parents=True,exist_ok=True)
        (evidence/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:receipt.get(k) for k in ['complete','run','checks','error']},ensure_ascii=False))
    if not receipt['complete']:raise SystemExit(1)
if __name__=='__main__':main()
