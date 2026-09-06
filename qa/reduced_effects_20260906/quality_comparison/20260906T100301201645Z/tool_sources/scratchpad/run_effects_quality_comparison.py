"""Root-owned serial standard/reduced comparisons without production source swaps."""
from pathlib import Path
import argparse, datetime, hashlib, importlib.util, json, math, statistics, sys
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('effects_process_guard',ROOT/'scratchpad/redraw_reject_diag/run_redraw_reject_diagnostics.py')
safe=importlib.util.module_from_spec(spec);spec.loader.exec_module(safe)
sha=safe.sha;save=safe.save_json

def summary(samples,args):
    groups=[]
    for camera in args.cameras:
        part=[r for r in samples if r['camera_mode']==camera]
        complete=len(part)==args.repeats*2 and all(r['quality_metadata_valid'] and r['sample_complete'] and r['integrity_passed'] for r in part)
        pairs=[{r['effects_quality'] for r in part if r['repetition']==i}=={'standard','reduced'} for i in range(1,args.repeats+1)]
        same_deployment=bool(part) and len({r['initial_deployment_sha256'] for r in part})==1
        same_inputs=bool(part) and len({r['input_log_sha256'] for r in part})==1
        same_other_settings=bool(part) and len({r['other_settings_sha256'] for r in part})==1
        group={'camera_mode':camera,'samples':len(part),'paired_repetitions_complete':all(pairs),'same_deployment':same_deployment,'same_inputs':same_inputs,'same_other_settings':same_other_settings,
            'comparison_eligible':complete and all(pairs) and same_deployment and same_inputs and same_other_settings and args.seconds>=60 and args.repeats>=3 and not args.preflight and all(r['acceptance_eligible'] for r in part)}
        for quality in ['standard','reduced']:
            selected=[r for r in part if r['effects_quality']==quality]
            group[quality]={'samples':[r['report'] for r in selected],'median':{k:statistics.median(r[k] for r in selected) for k in ['fps','p95_ms','p99_ms']} if selected else {}}
        groups.append(group)
    return {'schema':2,'groups':groups,'comparison_eligible':bool(groups) and all(g['comparison_eligible'] for g in groups),'performance_gate_passed':False,
        'note':'Statistical quality comparison on the same code; acceptance eligibility is not a performance pass. Full wall-clock pressure segments must be analyzed separately.'}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot',required=True);p.add_argument('--cameras',nargs='+',choices=['fixed','auto'],default=['fixed','auto'])
    p.add_argument('--seconds',type=float,default=60);p.add_argument('--repeats',type=int,default=3);p.add_argument('--preflight',action='store_true')
    args=p.parse_args()
    if not math.isfinite(args.seconds) or args.seconds<1 or args.repeats<1 or len(set(args.cameras))!=len(args.cameras):p.error('Invalid sample specification')
    if (args.seconds<60 or args.repeats<3) and not args.preflight:p.error('Formal quality comparison needs at least 3 repeats x 60 seconds')
    safe.require_exclusive_godot()
    lock=ROOT/'.godot/redraw_rejection_source.lock'
    assert not lock.exists() and not (ROOT/'.godot/reduced_effects_legacy_source.lock').exists()
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out=ROOT/'.godot/effects_quality_comparison'/stamp;out.mkdir(parents=True,exist_ok=False)
    helpers=safe.baseline_helpers();sources=helpers['source_receipt']();env,controlled=helpers['environment']()
    save(out/'sources.json',sources)
    for path in ['tools/polish_performance_probe.gd','tools/run_polish_performance.py','tools/analyze_polish_performance.py',str(Path(__file__).relative_to(ROOT))]:
        target=out/'tool_sources'/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((ROOT/path).read_bytes())
    save(out/'configuration.json',{'seconds':args.seconds,'repeats':args.repeats,'cameras':args.cameras,'preflight':args.preflight,'seed':5088120,'warmup_ticks':300,'quality_sequence':'standard,reduced for odd repetitions; reduced,standard for even repetitions','source_mutated':False,'engine_sha256':sha(Path(args.godot).read_bytes()),'environment':controlled,'allowed_setting_difference':['effects_quality'],'camera_workloads_separate':True})
    receipt={'samples':[],'complete':False,'source_unchanged':False,'lock_released':False}
    with lock.open('x',encoding='utf-8') as stream:stream.write(str(out)+'\n')
    print('OUTPUT '+str(out),flush=True)
    try:
        for repetition in range(1,args.repeats+1):
            for camera in args.cameras:
                for quality in (['standard','reduced'] if repetition%2 else ['reduced','standard']):
                    assert helpers['source_receipt']()==sources,'Source or HEAD changed before quality sample'
                    report_path=out/(f'{quality}_{camera}_{repetition}.json')
                    sample_env=env.copy();sample_env.update(POLISH_CASE='defense200',POLISH_CAMERA=camera,POLISH_SECONDS=str(args.seconds),POLISH_OUT=str(report_path),POLISH_EFFECTS_QUALITY=quality)
                    report=safe.run_godot(args.godot,ROOT/'tools/polish_performance_probe.gd',report_path,sample_env,args.seconds+180,validity_key='integrity_passed')
                    assert helpers['source_receipt']()==sources,'Source or HEAD changed during quality sample'
                    valid=report.get('schema')==2 and report.get('effects_quality_verified') is True and report.get('effects_quality_violations')==0 and all(report.get(k)==quality for k in ['effects_quality','effects_quality_requested','effects_quality_initial','effects_quality_start','effects_quality_end']) and report.get('configured_settings',{}).get('effects_quality')==quality
                    assert valid and report['sample_complete'],'Incomplete sample or incorrect quality metadata'
                    settings={k:v for k,v in report['configured_settings'].items() if k!='effects_quality'}
                    row={k:report[k] for k in ['fps','p95_ms','p99_ms','sample_end','simulated_seconds','sample_complete','integrity_passed','acceptance_eligible','effects_quality','effects_quality_verified','effects_quality_violations']}
                    row.update(camera_mode=camera,repetition=repetition,report=report_path.name,source_sha256=sources['combined_sha256'],quality_metadata_valid=valid,
                        initial_deployment_sha256=sha(json.dumps(report['initial_units'],sort_keys=True).encode()),input_log_sha256=sha(json.dumps(report['inputs'],sort_keys=True).encode()),other_settings_sha256=sha(json.dumps(settings,sort_keys=True).encode()))
                    receipt['samples'].append(row);save(out/'running_receipt.json',receipt);save(out/'summary.json',summary(receipt['samples'],args));print(json.dumps(row),flush=True)
        receipt['complete']=True
    except BaseException as exc:
        receipt['exception']=type(exc).__name__+': '+str(exc)
        raise
    finally:
        try:
            safe.require_exclusive_godot()
            receipt['source_unchanged']=helpers['source_receipt']()==sources
            assert receipt['source_unchanged'],'Source drift; retain lock'
            assert lock.read_text(encoding='utf-8').strip()==str(out),'Lock ownership changed'
            lock.unlink();receipt['lock_released']=True
        except BaseException as exc:receipt['final_guard_error']=type(exc).__name__+': '+str(exc)
        save(out/'exit_receipt.json',receipt)
        print('EXIT '+json.dumps({k:v for k,v in receipt.items() if k!='samples'}),flush=True)
    return 0 if receipt['complete'] and receipt['lock_released'] else 2
if __name__=='__main__':sys.exit(main())
