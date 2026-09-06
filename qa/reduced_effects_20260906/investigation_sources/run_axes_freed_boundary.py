"""Run unchanged original and two-guard class separately; original failure is not PASS."""
from pathlib import Path
import datetime, hashlib, importlib.util, json, os, re, sys
ROOT=Path(__file__).resolve().parents[1]
HERE=ROOT/'scratchpad/axes_freed_boundary'
spec=importlib.util.spec_from_file_location('axes_process_guard',ROOT/'scratchpad/redraw_reject_diag/run_redraw_reject_diagnostics.py')
safe=importlib.util.module_from_spec(spec);spec.loader.exec_module(safe)
def save(path,value):path.write_bytes((json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode())
safe.require_exclusive_godot()
lock=ROOT/'.godot/redraw_rejection_source.lock'
assert not lock.exists()
stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
out=HERE/'runs'/stamp;out.mkdir(parents=True,exist_ok=False)
helpers=safe.baseline_helpers();sources=helpers['source_receipt']();env,controls=helpers['environment']()
save(out/'sources_before.json',sources)
freeze={p:p.read_bytes() for p in [HERE/'qa.gd',HERE/'generated/pins.json',HERE/'generated/original_effect.gd.txt',HERE/'generated/fixed_effect.gd.txt']}
for p,raw in freeze.items():
    target=out/'fixture_sources'/p.name;target.parent.mkdir(exist_ok=True);target.write_bytes(raw)
profile=out/'private_profile';(profile/'appdata').mkdir(parents=True);(profile/'localappdata').mkdir()
env.update(APPDATA=str(profile/'appdata'),LOCALAPPDATA=str(profile/'localappdata'),CAMPAIGN_QA='1')
save(out/'configuration.json',{'engine_sha256':hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest(),'controlled_environment':controls,'private_appdata':str(profile/'appdata'),'source_mutated':False,'original_failure_counted_as_green':False})
receipt={'complete':False,'samples':[],'lock_released':False}
with lock.open('x',encoding='utf-8') as stream:stream.write(str(out)+'\n')
print('OUTPUT '+str(out),flush=True)
try:
    for mode in ['original','fixed']:
        stage=out/mode;stage.mkdir()
        assert helpers['source_receipt']()==sources and all(p.read_bytes()==raw for p,raw in freeze.items())
        sample_env=env.copy();sample_env.update(AXES_BOUNDARY_MODE=mode,AXES_BOUNDARY_OUT=str(stage))
        report_path=stage/'report.json'
        failure=None
        try:
            report=safe.run_godot(sys.argv[1],HERE/'qa.gd',report_path,sample_env,90,validity_key='passed')
        except RuntimeError as exc:
            failure=str(exc)
            if mode!='original' or not report_path.exists():raise
            report=json.loads(report_path.read_bytes())
        assert helpers['source_receipt']()==sources and all(p.read_bytes()==raw for p,raw in freeze.items())
        process=json.loads((stage/'report_process.json').read_bytes())
        log=(stage/'report.log').read_text(encoding='utf-8',errors='replace')
        assert report['mode']==mode and process['child_exit_confirmed']
        if mode=='original':
            assert process['exit_code']==1 and report['passed'] is False and failure
            assert 'Trying to assign invalid previously freed instance' in log and 'resolve_hits' in log and '_draw' in log
            assert report['failures'] and all(label.startswith(('freed_head:', 'automatic:', 'draw:')) for label in report['failures']),report['failures']
            assert next(row for row in report['cases'] if row['name']=='valid_control')['tail_hp']==89.0
            assert next(row for row in report['cases'] if row['name']=='actual_canvas_draw')['clean_pixels']>0
            status='original_defect_reproduced_strict_failure'
        else:
            assert process['exit_code']==0 and report['passed'] is True and not report['failures'] and not process['matched_messages']
            status='fixed_strict_pass'
        receipt['samples'].append({'mode':mode,'status':status,'checks':report['checks'],'failures':report['failures'],'report':str(report_path.relative_to(out))})
        save(out/'running_receipt.json',receipt)
        print(json.dumps(receipt['samples'][-1],ensure_ascii=False),flush=True)
    receipt['complete']=True
except BaseException as exc:
    receipt['exception']=type(exc).__name__+': '+str(exc)
    raise
finally:
    try:
        safe.require_exclusive_godot()
        assert helpers['source_receipt']()==sources and all(p.read_bytes()==raw for p,raw in freeze.items())
        assert lock.read_text(encoding='utf-8').strip()==str(out)
        lock.unlink();receipt['lock_released']=True
    except BaseException as exc:receipt['final_guard_error']=type(exc).__name__+': '+str(exc)
    save(out/'exit_receipt.json',receipt)
    print(json.dumps({'complete':receipt['complete'],'lock_released':receipt['lock_released']}),flush=True)
