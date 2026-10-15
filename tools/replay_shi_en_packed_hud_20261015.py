"""Rerun excluded QA against a sealed full PCK, only if all production inputs match."""
import argparse,json,shutil,time,uuid,os
from pathlib import Path
import run_character_art_qa as common
from run_shi_en_packed_hud_20261015 import file_sha,ROOT,SCRIPT
SELF='tools/replay_shi_en_packed_hud_20261015.py'
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('export_receipt',type=Path);args=ap.parse_args()
    prior_path=args.export_receipt.resolve();prior=json.loads(prior_path.read_text(encoding='utf-8'))
    assert prior['complete'] and not prior['source_changes'] and not prior['private_source_changes']
    changed=[r['path'] for r in prior['source_files'] if common.sha(ROOT/r['path'])!=r['sha256']]
    assert changed==[SCRIPT],changed
    old_run=Path(prior['run']);pack_source=old_run/'clean_runtime/LiangshanShiEn.pck'
    assert file_sha(pack_source)==prior['pack_sha256'] and pack_source.stat().st_size==prior['pack_bytes']
    assert common.sha(old_run/'evidence/inputs.json')==prior['inputs_sha256']
    assert common.sha(old_run/'evidence/texture_references.json')==prior['texture_reference_sha256']
    shared,running=common.load_helpers(ROOT);engine=shared.resolve_godot(None)
    assert common.sha(engine)==prior['godot_sha256']
    if running() or shared.LOCK.exists():raise RuntimeError('Shared Godot slot occupied; no replay launched')
    work=shared.resolve_profile_root(Path('D:/CodexTemp/shi_en_packed_hud_20261015'))
    run=work/('replay_'+time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]);evidence=run/'evidence';runtime=run/'clean_runtime'
    receipt={'complete':False,'run':str(run),'steps':[],'original_export_receipt':str(prior_path),
        'original_export_receipt_sha256':common.sha(prior_path),'reused_pack_sha256':prior['pack_sha256'],
        'only_changed_export_input':SCRIPT,'pack_reexported':False,'production_source_match':True,'steam_updated':False}
    locked=False
    try:
        with shared.LOCK.open('x',encoding='utf-8') as lock:lock.write(str(run))
        locked=True
        if running():raise RuntimeError('Other engine appeared before replay')
        runtime.mkdir(parents=True);evidence.mkdir()
        # A read-only engine load reuses the exact same bytes, without rewriting
        # either path. Both linked paths are checked again after the process.
        pack=runtime/'LiangshanShiEn.pck';os.link(pack_source,pack)
        receipt['native_dependencies']=shared.install_native(runtime)
        assert receipt['native_dependencies']==prior['native_dependencies']
        for path in sorted((ROOT/'vendor').glob('*/provenance.json')):
            for row in json.loads(path.read_text(encoding='utf-8'))['files']:
                if row['path'].endswith('.dll'):
                    src=path.parent/row['path'];assert common.sha(src)==row['sha256']
                    dest=runtime/src.name
                    if not dest.exists():shutil.copyfile(src,dest)
                    assert common.sha(dest)==row['sha256']
        qa=run/'qa/shi_en_packed_hud_20261015.gd';qa.parent.mkdir();qa.write_bytes((ROOT/SCRIPT).read_bytes())
        rows=[{'path':r['path'],'sha256':common.sha(ROOT/r['path'])} for r in prior['source_files']]
        rows.append({'path':SELF,'sha256':common.sha(ROOT/SELF)});receipt['source_files']=rows
        profile=shared.create_private_profile(run,work/'profiles');env=common.private_environment(profile)
        receipt['private_profile']=str(profile)
        for name in ('inputs.json','texture_references.json'):(evidence/name).write_bytes((old_run/'evidence'/name).read_bytes())
        cmd=['--main-pack',str(pack),'--position','30000,30000','--script',str(qa)]
        common.process_step(engine,runtime,env|{'SHI_EN_ART_OUT':str(evidence/'visual'),'SHI_EN_PACK_INPUTS':str(evidence/'inputs.json'),'SHI_EN_TEXTURE_REFERENCE':str(evidence/'texture_references.json')},
            evidence,'packed_actions_hud',cmd,360,'gl_compatibility',running,receipt['steps'])
        report=json.loads((evidence/'visual/report.json').read_text(encoding='utf-8'))
        assert report['passed'] and not report['failures']
        receipt['checks']=len(report['checks']);receipt['screenshots']=len(report['screenshots'])
        receipt['source_changes']=common.source_changes(ROOT,rows);assert not receipt['source_changes']
        assert file_sha(pack)==file_sha(pack_source)==prior['pack_sha256']
        assert common.sha(qa)==common.sha(ROOT/SCRIPT)
        assert not any(p.suffix=='.png' for p in runtime.rglob('*'))
        receipt['complete']=True
    except Exception as error:receipt['error']=repr(error)
    finally:
        if locked and shared.LOCK.exists() and shared.LOCK.read_text(encoding='utf-8')==str(run) and not running():shared.LOCK.unlink()
        receipt['lock_released']=locked and not shared.LOCK.exists();evidence.mkdir(parents=True,exist_ok=True)
        (evidence/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:receipt.get(k) for k in ('complete','run','checks','screenshots','error')},ensure_ascii=False))
    if not receipt['complete']:raise SystemExit(1)
if __name__=='__main__':main()
