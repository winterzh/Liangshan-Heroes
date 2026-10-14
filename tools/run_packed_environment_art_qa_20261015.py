"""Observe current art calibration in an isolated, genuine Godot resource export."""
import json,os,shutil,time,uuid
from pathlib import Path
import run_character_art_qa as common
from environment_png_calibration_inputs_20261015 import inputs
ROOT=Path(__file__).resolve().parents[1]
SCRIPT='tools/packed_environment_art_probe_20261015.gd'
def main():
    shared,running=common.load_helpers(ROOT);engine=shared.resolve_godot(None)
    if running() or shared.LOCK.exists():raise RuntimeError('Shared Godot slot occupied')
    work=shared.resolve_profile_root(Path('D:/CodexTemp/packed_environment_art_20261015'))
    run=work/(time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8])
    project,evidence,runtime=run/'project',run/'evidence',run/'clean_runtime'
    manifests=['qa/roadside_tavern_variants_20261015/source_manifest.json','qa/market_stall_art_20261015/source_manifest.json']
    variants=inputs()
    names=manifests+['scripts/campaign_environment_art.gd',SCRIPT,'tools/run_packed_environment_art_qa_20261015.py','tools/environment_png_calibration_inputs_20261015.py']+[row['path'] for row in variants]
    receipt={'complete':False,'run':str(run),'source_files':[],'steps':[],'godot_sha256':common.sha(engine),'scope':'Minimal exported PCK art calibration only; no Steam upload or SDK qualification.'}
    locked=False
    try:
        with shared.LOCK.open('x',encoding='utf-8') as lock:lock.write(str(run))
        locked=True
        project.mkdir(parents=True);evidence.mkdir();runtime.mkdir()
        for name in names:
            common.relative_source(ROOT,name)
            target=project/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((ROOT/name).read_bytes())
            receipt['source_files'].append({'path':name,'sha256':common.sha(target)})
        (project/'project.godot').write_text('[application]\nconfig/name="Isolated Art Calibration Probe"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
        (project/'export_presets.cfg').write_text('[preset.0]\nname="Art Probe"\nplatform="Windows Desktop"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter="probe_inputs.json"\nexclude_filter="qa/*,tools/*.py"\n[preset.0.options]\ntexture_format/bptc=false\ntexture_format/s3tc=true\n',encoding='utf-8')
        (project/'probe_inputs.json').write_text(json.dumps({'variants':variants},ensure_ascii=False),encoding='utf-8')
        profile=shared.create_private_profile(run,work/'profiles');env=common.private_environment(profile)
        receipt['private_profile']=str(profile)
        template=Path(os.environ['APPDATA'])/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe'
        assert template.is_file()
        target=Path(env['APPDATA'])/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe'
        target.parent.mkdir(parents=True);shutil.copyfile(template,target)
        receipt['template_sha256']=common.sha(template)
        common.process_step(engine,project,env,evidence,'import',['--headless','--editor','--import','--quit'],120,'gl_compatibility',running,receipt['steps'])
        common.process_step(engine,project,env|{'PACKED_ART_OUT':str(evidence/'source')},evidence,'source_probe',['--position','30000,30000','--script','res://'+SCRIPT],60,'gl_compatibility',running,receipt['steps'])
        pack=runtime/'art.pck'
        common.process_step(engine,project,env,evidence,'export_pack',['--headless','--editor','--export-pack','Art Probe',str(pack)],120,'gl_compatibility',running,receipt['steps'])
        assert pack.is_file() and not any(p.suffix=='.png' for p in runtime.rglob('*'))
        common.process_step(engine,runtime,env|{'PACKED_ART_OUT':str(evidence/'packed')},evidence,'packed_probe',['--main-pack',str(pack),'--position','30000,30000','--script','res://'+SCRIPT],60,'gl_compatibility',running,receipt['steps'])
        source=json.loads((evidence/'source/report.json').read_text(encoding='utf-8'))
        packed=json.loads((evidence/'packed/report.json').read_text(encoding='utf-8'))
        assert source['all_loaded'] and source['all_calibrated'] and packed['all_loaded']
        if source['all_calibrated'] and packed['all_calibrated']:
            assert source['guards_passed'] and packed['guards_passed'] and len(source['guards'])==6 and len(packed['guards'])==4
        assert all(not row['raw_png_available'] for row in packed['rows'])
        assert [(r['key'],r['imported_pixel_sha256']) for r in source['rows']]==[(r['key'],r['imported_pixel_sha256']) for r in packed['rows']]
        receipt.update(source_calibrated=source['all_calibrated'],packed_calibrated=packed['all_calibrated'],pack_sha256=common.sha(pack),pack_bytes=pack.stat().st_size,source_changes=common.source_changes(ROOT,receipt['source_files']),private_source_changes=common.source_changes(project,receipt['source_files']))
        assert not receipt['source_changes'] and not receipt['private_source_changes']
        receipt['complete']=True
    except Exception as exc:receipt['error']=repr(exc)
    finally:
        if locked and shared.LOCK.read_text(encoding='utf-8')==str(run):shared.LOCK.unlink()
        receipt['lock_released']=locked and not shared.LOCK.exists()
        evidence.mkdir(parents=True,exist_ok=True)
        (evidence/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:receipt.get(k) for k in ['complete','run','source_calibrated','packed_calibrated','error']},ensure_ascii=False))
    if not receipt['complete']:raise SystemExit(1)
if __name__=='__main__':main()
