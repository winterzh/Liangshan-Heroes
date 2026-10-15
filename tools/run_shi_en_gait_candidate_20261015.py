"""Serial private import/build/original Level7 candidate; no production adoption."""
import argparse,json,subprocess,sys,time,uuid,re,os
from pathlib import Path
import run_character_art_qa as common
import PIL
ROOT=Path(__file__).resolve().parents[1]
QA='qa/shi_en_gait_20261015/'
BUILDER='tools/build_shi_en_runtime_candidate_20261015.py'
IMPORT_PROBE='tools/shi_en_native_import_probe_20261015.gd'
SCENE_PROBE='tools/shi_en_gait_scene_qa_20261015.gd'
MANIFEST='assets/direction4/ordinary_shi_en_20261015_gait_v1.json'
def patch_route(path):
    raw=path.read_bytes();anchor=b'const ORDINARY_CHARACTER_FAMILIES := {\r\n'
    if anchor not in raw:anchor=b'const ORDINARY_CHARACTER_FAMILIES := {\n'
    assert raw.count(anchor)==1 and b'character_traits_v1_shi_en_gait' not in raw
    newline=b'\r\n' if anchor.endswith(b'\r\n') else b'\n'
    row=b'\t"shi_en": {"idle": "character_traits_v1_shi_en_gait", "walk": "character_traits_v1_shi_en_gait"},'+newline
    path.write_bytes(raw.replace(anchor,anchor+row,1))
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--run',action='store_true');args=ap.parse_args()
    shared,running=common.load_helpers(ROOT);engine=shared.resolve_godot(None)
    plan=json.loads((ROOT/QA/'runtime_plan.json').read_text(encoding='utf-8'))
    names=sorted(set(shared.sources())|set(common.TOOLS)|{BUILDER,IMPORT_PROBE,SCENE_PROBE,
        'tools/run_shi_en_gait_candidate_20261015.py','tools/build_directional_spriteframes.py','tools/run_character_art_qa.py',
        QA+'source_manifest.json',QA+'runtime_plan.json'})
    if not args.run:
        print(json.dumps({'planned_resources':len(plan['resources']),'native_sources':len(plan['sources']),
            'shared_engine_busy':bool(running()),'shared_lock_present':shared.LOCK.exists(),'native_launched':False}));return
    if running() or shared.LOCK.exists():raise RuntimeError('Shared Godot slot occupied; no candidate launched')
    work=shared.resolve_profile_root(Path('D:/CodexTemp/shi_en_gait_runtime_20261015'))
    run=work/(time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]);project=run/'project';evidence=run/'evidence'
    receipt={'complete':False,'source_root':str(ROOT),'run':str(run),'project':str(project),
        'source_files':[],'steps':[],'godot_sha256':common.sha(engine),
        'production_adopted':False,'visual_review_pending':True,'full_art_complete':False}
    locked=False
    try:
        with shared.LOCK.open('x',encoding='utf-8') as lock:lock.write(str(run))
        locked=True
        if running():raise RuntimeError('Other engine appeared before own native launch')
        project.mkdir(parents=True);evidence.mkdir()
        for name in names:
            common.relative_source(ROOT,name);dest=project/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes((ROOT/name).read_bytes())
            receipt['source_files'].append({'path':name,'sha256':common.sha(dest)})
        receipt['native_dependencies']=shared.install_native(project)
        profile=shared.create_private_profile(run,work/'profiles');env=common.private_environment(profile)
        receipt['private_profile']=str(profile)
        for row in plan['sources'].values():
            source=project/row['candidate_origin'];assert common.sha(source)==row['sha256']
            target=project/row['path'];assert not target.exists();target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(source.read_bytes())
        common.process_step(engine,project,env,evidence,'import',['--headless','--editor','--import','--quit'],300,'gl_compatibility',running,receipt['steps'])
        receipt['authored_imports']=[]
        for row in plan['sources'].values():
            path=Path(str(project/row['path'])+'.import');raw=path.read_text(encoding='utf-8')
            assert 'uid="uid://' in raw and ('source_file="res://'+row['path']+'"') in raw
            before_sha=common.sha(path)
            raw,count=re.subn(r'(?m)^mipmaps/generate=(?:true|false)$','mipmaps/generate=true',raw);assert count==1
            raw,count=re.subn(r'(?m)^process/size_limit=\d+$','process/size_limit=2048',raw);assert count==1
            path.write_text(raw,encoding='utf-8',newline='\n')
            receipt['authored_imports'].append({'path':row['path']+'.import','before_sha256':before_sha,'configured_sha256':common.sha(path)})
        common.process_step(engine,project,env,evidence,'import_mipmaps',['--headless','--editor','--import','--quit'],300,'gl_compatibility',running,receipt['steps'])
        report_path=evidence/'native_import.json'
        common.process_step(engine,project,env|{'SHI_EN_IMPORT_OUT':str(report_path)},evidence,'native_import_probe',
            ['--headless','--script','res://'+IMPORT_PROBE],60,'gl_compatibility',running,receipt['steps'])
        # APPDATA is intentionally private. Expose only the existing trusted
        # Python package directory, without restoring the player's profile.
        pillow_path=Path(PIL.__file__).resolve()
        receipt['pillow_dependency']={'version':PIL.__version__,'init_sha256':common.sha(pillow_path),'package_root':str(pillow_path.parent.parent)}
        build_env=env|{'PYTHONPATH':str(pillow_path.parent.parent)}
        completed=subprocess.run([sys.executable,'-X','utf8','-B',str(project/BUILDER),'--from-import',str(report_path)],
            cwd=project,env=build_env,capture_output=True,text=True,encoding='utf-8',timeout=30)
        (evidence/'build_resources.stdout.log').write_text(completed.stdout,encoding='utf-8')
        (evidence/'build_resources.stderr.log').write_text(completed.stderr,encoding='utf-8')
        receipt['build_resources_exit']=completed.returncode;assert completed.returncode==0,completed.stderr
        before_art_sha=common.sha(project/'scripts/art_db.gd');patch_route(project/'scripts/art_db.gd')
        receipt['art_route_before_sha256']=before_art_sha
        accepted=json.loads((project/MANIFEST).read_text(encoding='utf-8'))
        artifacts={MANIFEST,'scripts/art_db.gd'}|set(accepted['resources'])
        for row in accepted['sources'].values():artifacts.update((row['path'],row['path']+'.import'))
        receipt['candidate_artifacts']=[{'path':p,'sha256':common.sha(project/p)} for p in sorted(artifacts)]
        common.process_step(engine,project,env|{'SHI_EN_ART_OUT':str(evidence/'visual')},evidence,'original_level7',
            ['--position','30000,30000','--script','res://'+SCENE_PROBE],240,'gl_compatibility',running,receipt['steps'])
        report=json.loads((evidence/'visual/report.json').read_text(encoding='utf-8'));assert report['passed'] and not report['failures']
        receipt['checks']=len(report['checks']);receipt['source_changes']=common.source_changes(ROOT,receipt['source_files'])
        expected_private_change=[r for r in receipt['source_files'] if r['path']=='scripts/art_db.gd'][0]
        private_base=[r for r in receipt['source_files'] if r['path']!='scripts/art_db.gd']
        receipt['private_source_changes']=common.source_changes(project,private_base)
        assert not receipt['source_changes'] and not receipt['private_source_changes']
        assert expected_private_change['sha256']==receipt['art_route_before_sha256']
        assert not common.source_changes(project,receipt['candidate_artifacts'])
        receipt['complete']=True
    except Exception as error:receipt['error']=repr(error)
    finally:
        if locked and shared.LOCK.exists() and shared.LOCK.read_text(encoding='utf-8')==str(run):
            if not running() or not receipt['steps']:shared.LOCK.unlink()
        receipt['lock_released']=locked and not shared.LOCK.exists()
        evidence.mkdir(parents=True,exist_ok=True)
        (evidence/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:receipt.get(k) for k in ('complete','run','checks','error')},ensure_ascii=False))
    if not receipt['complete']:raise SystemExit(1)
if __name__=='__main__':main()
