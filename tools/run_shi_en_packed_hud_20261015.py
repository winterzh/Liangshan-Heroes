"""Export the real full resource PCK and verify Shi En textures/actions and hero HUD."""
import argparse,hashlib,importlib.util,json,os,shutil,time,uuid
from pathlib import Path
import run_character_art_qa as common
ROOT=Path(__file__).resolve().parents[1]
SCRIPT='tools/shi_en_packed_hud_20261015.gd'
REFERENCE='tools/shi_en_texture_reference_20261015.gd'
SELF='tools/run_shi_en_packed_hud_20261015.py'
def file_sha(p):
    with p.open('rb') as source:return hashlib.file_digest(source,'sha256').hexdigest()
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--run',action='store_true');args=parser.parse_args()
    shared,running=common.load_helpers(ROOT);engine=shared.resolve_godot(None)
    inputs={key:json.loads((ROOT/path).read_text(encoding='utf-8')) for key,path in {
        'gait':'assets/direction4/ordinary_shi_en_20261015_gait_v1.json',
        'combat':'assets/direction4/ordinary_shi_en_20261015_combat_v1.json'}.items()}
    inputs['textures']=sorted({row['path'] for key in ('gait','combat') for row in inputs[key]['sources'].values()})
    assert len(inputs['textures'])==25
    inputs['skill_icons']={f'shi_en_{slot}':f'assets/ui/shi_en_skills_20261015/shi_en_{slot}.png' for slot in 'qwer'}
    inputs['textures']+=list(inputs['skill_icons'].values())
    for key in ('gait','combat'):
        for row in inputs[key]['sources'].values():assert common.sha(ROOT/row['path'])==row['sha256']
    if not args.run:
        print(json.dumps({'runtime_textures':len(inputs['textures']),'shared_engine_busy':bool(running()),'lock_present':shared.LOCK.exists(),'native_launched':False}));return
    if running() or shared.LOCK.exists():raise RuntimeError('Shared Godot slot occupied; no pack launched')
    work=shared.resolve_profile_root(Path('D:/CodexTemp/shi_en_packed_hud_20261015'))
    run=work/(time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8])
    project=ROOT/'.godot/shi_en_packed_hud_20261015'/run.name/'project'
    evidence,runtime=run/'evidence',run/'clean_runtime'
    helper=ROOT/'tools/contracts/run_content_identity_20260907/build_identity.py'
    spec=importlib.util.spec_from_file_location('shi_en_pack_identity',helper)
    identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
    names=sorted(set(shared.sources())|set(common.TOOLS)|{SCRIPT,REFERENCE,SELF,'tools/run_character_art_qa.py'})
    assert identity.DERIVED not in names and not (ROOT/identity.DERIVED).exists()
    receipt={'complete':False,'run':str(run),'project':str(project),'source_files':[],'steps':[],
        'godot_sha256':common.sha(engine),'identity_generator_sha256':common.sha(helper),'steam_updated':False,
        'scope':'Actual full-game resource PCK through isolated editor, native texture/action and hero HUD cases. No release EXE, live SDK, platform, full chapter or full art acceptance.'}
    locked=False
    try:
        with shared.LOCK.open('x',encoding='utf-8') as lock:lock.write(str(run))
        locked=True
        if running():raise RuntimeError('Foreign engine appeared before launch')
        run.mkdir(parents=True);project.mkdir(parents=True);evidence.mkdir();runtime.mkdir()
        for name in names:
            common.relative_source(ROOT,name);dest=project/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes((ROOT/name).read_bytes())
            receipt['source_files'].append({'path':name,'sha256':common.sha(dest)})
        receipt['native_dependencies']=shared.install_native(project)
        profile=shared.create_private_profile(run,work/'profiles');env=common.private_environment(profile)
        receipt['private_profile']=str(profile)
        template=Path(os.environ['APPDATA'])/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe'
        target=Path(env['APPDATA'])/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe'
        target.parent.mkdir(parents=True);shutil.copyfile(template,target);receipt['template_sha256']=file_sha(template)
        input_path=evidence/'inputs.json';input_path.write_text(json.dumps(inputs,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        receipt['inputs_sha256']=common.sha(input_path)
        receipt['identity_seed']=identity.seed(project)
        common.process_step(engine,project,env,evidence,'import',['--headless','--editor','--import','--quit'],300,'gl_compatibility',running,receipt['steps'])
        common.process_step(engine,project,env,evidence,'parse_scene_probe',['--headless','--check-only','--script','res://'+SCRIPT],60,'gl_compatibility',running,receipt['steps'])
        reference=evidence/'texture_references.json'
        common.process_step(engine,project,env|{'SHI_EN_PACK_INPUTS':str(input_path),'SHI_EN_TEXTURE_REFERENCE_OUT':str(reference)},evidence,
            'source_texture_reference',['--headless','--script','res://'+REFERENCE],90,'gl_compatibility',running,receipt['steps'])
        references=json.loads(reference.read_text(encoding='utf-8'));assert set(references)==set(inputs['textures'])
        receipt['texture_reference_sha256']=common.sha(reference)
        receipt['generated_identity']=identity.generate(project)
        assert not common.source_changes(project,receipt['source_files'])
        pack=runtime/'LiangshanShiEn.pck'
        common.process_step(engine,project,env,evidence,'export_pack',['--headless','--editor','--export-pack','Windows Steam',str(pack)],300,'gl_compatibility',running,receipt['steps'])
        identity.verify_generated(project,receipt['generated_identity'])
        receipt.update(pack_sha256=file_sha(pack),pack_bytes=pack.stat().st_size)
        assert shared.install_native(runtime)==receipt['native_dependencies']
        for path in sorted((ROOT/'vendor').glob('*/provenance.json')):
            manifest=json.loads(path.read_text(encoding='utf-8'))
            for row in manifest['files']:
                if row['path'].endswith('.dll'):
                    source=path.parent/row['path'];assert common.sha(source)==row['sha256']
                    dest=runtime/source.name
                    if not dest.exists():shutil.copyfile(source,dest)
                    assert common.sha(dest)==row['sha256']
        assert pack.is_file() and not any(p.suffix=='.png' for p in runtime.rglob('*'))
        cmd=['--main-pack',str(pack),'--position','30000,30000','--script',str(project/SCRIPT)]
        common.process_step(engine,runtime,env|{'SHI_EN_ART_OUT':str(evidence/'visual'),'SHI_EN_PACK_INPUTS':str(input_path),'SHI_EN_TEXTURE_REFERENCE':str(reference)},evidence,
            'packed_actions_hud',cmd,360,'gl_compatibility',running,receipt['steps'])
        report=json.loads((evidence/'visual/report.json').read_text(encoding='utf-8'));assert report['passed'] and not report['failures']
        receipt['checks']=len(report['checks']);receipt['screenshots']=len(report['screenshots'])
        receipt['source_changes']=common.source_changes(ROOT,receipt['source_files']);receipt['private_source_changes']=common.source_changes(project,receipt['source_files'])
        assert not receipt['source_changes'] and not receipt['private_source_changes']
        identity.verify_generated(project,receipt['generated_identity'])
        assert file_sha(pack)==receipt['pack_sha256'];receipt['complete']=True
    except Exception as error:receipt['error']=repr(error)
    finally:
        if locked and shared.LOCK.exists() and shared.LOCK.read_text(encoding='utf-8')==str(run) and not running():shared.LOCK.unlink()
        receipt['lock_released']=locked and not shared.LOCK.exists();evidence.mkdir(parents=True,exist_ok=True)
        (evidence/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:receipt.get(k) for k in ('complete','run','checks','screenshots','error')},ensure_ascii=False))
    if not receipt['complete']:raise SystemExit(1)
if __name__=='__main__':main()
