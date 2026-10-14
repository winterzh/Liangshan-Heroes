"""Freeze current production sources; capture four original Level7 taverns privately."""
import argparse
import json
from pathlib import Path
import time
import uuid
import run_character_art_qa as common

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = 'tools/roadside_tavern_variants_qa_20261015.gd'
MANIFEST = 'qa/roadside_tavern_variants_20261015/source_manifest.json'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    args = parser.parse_args()
    shared, running = common.load_helpers(ROOT)
    engine = shared.resolve_godot(None)
    names = sorted(set(shared.sources()) | set(common.TOOLS) | {
        SCRIPT, MANIFEST, 'tools/run_character_art_qa.py',
        'tools/prepare_roadside_tavern_variants_20261015.py',
        'tools/run_roadside_tavern_art_qa_20261015.py'})
    if not args.run:
        print(json.dumps({'files':len(names),'lock_busy':shared.LOCK.exists(),'engine_busy':running()}))
        return
    if running() or shared.LOCK.exists():
        raise RuntimeError('Shared Godot slot occupied')
    work = shared.resolve_profile_root(Path('D:/CodexTemp/roadside_tavern_art_20261015'))
    run = work/(time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8])
    project, evidence = run/'project', run/'evidence'
    receipt = {'complete':False,'source_root':str(ROOT),'run':str(run),
               'godot_sha256':common.sha(engine),'source_files':[],'steps':[]}
    locked = False
    try:
        with shared.LOCK.open('x',encoding='utf-8') as lock: lock.write(str(run))
        locked = True
        project.mkdir(parents=True)
        evidence.mkdir()
        for name in names:
            common.relative_source(ROOT,name)
            dest = project/name
            dest.parent.mkdir(parents=True,exist_ok=True)
            dest.write_bytes((ROOT/name).read_bytes())
            receipt['source_files'].append({'path':name,'sha256':common.sha(dest)})
        receipt['native_dependencies'] = shared.install_native(project)
        profile = shared.create_private_profile(run,work/'profiles')
        receipt['private_profile'] = str(profile)
        env = common.private_environment(profile)
        common.process_step(engine,project,env,evidence,'import',
            ['--headless','--editor','--import','--quit'],300,'gl_compatibility',running,receipt['steps'])
        assert not common.source_changes(project,receipt['source_files']), 'Frozen source drift after import'
        common.process_step(engine,project,env|{'TAVERN_ART_OUT':str(evidence/'visual')},evidence,'visual',
            ['--position','30000,30000','--script','res://'+SCRIPT],240,'gl_compatibility',running,receipt['steps'])
        report = json.loads((evidence/'visual/report.json').read_text(encoding='utf-8'))
        assert report['passed'] and not report['failures']
        receipt['checks'] = len(report['checks'])
        receipt['source_changes'] = common.source_changes(ROOT,receipt['source_files'])
        receipt['private_source_changes'] = common.source_changes(project,receipt['source_files'])
        assert not receipt['source_changes'] and not receipt['private_source_changes']
        receipt['complete'] = True
    except Exception as exc:
        receipt['error'] = repr(exc)
    finally:
        if locked and shared.LOCK.read_text(encoding='utf-8')==str(run): shared.LOCK.unlink()
        receipt['lock_released'] = locked and not shared.LOCK.exists()
        evidence.mkdir(parents=True,exist_ok=True)
        receipt['artifacts'] = [{'path':p.relative_to(evidence).as_posix(),'sha256':common.sha(p)}
                                for p in sorted(evidence.rglob('*')) if p.is_file()]
        (evidence/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'complete':receipt['complete'],'run':str(run),'error':receipt.get('error')},ensure_ascii=False))
    if not receipt['complete']: raise SystemExit(1)

if __name__=='__main__': main()
