import ast, copy, hashlib, json, runpy, subprocess
from pathlib import Path
from types import SimpleNamespace
ROOT=Path(__file__).resolve().parents[1]
analyzer=runpy.run_path(str(ROOT/'tools/analyze_polish_performance.py'))
runner=runpy.run_path(str(ROOT/'tools/run_polish_performance.py'))
old={'__name__':'old_analyzer'}
exec(compile(subprocess.check_output(['git','show','HEAD:tools/analyze_polish_performance.py'],cwd=ROOT).decode(),'old_analyzer','exec'),old)
rows=[]
def check(value,label):
    assert value,label
    rows.append({'check':label,'passed':True})
legacy_path=next((ROOT/'qa/polish_baseline_20260906').rglob('defense200_fixed_1.json'))
legacy=json.loads(legacy_path.read_bytes())
check(analyzer['quality_metadata'](legacy)=={'effects_quality':None,'effects_quality_provenance':'legacy_unrecorded'},'historical real report retains unknown quality')
check(analyzer['segments'](legacy['raw_frame_ms'])==old['segments'](legacy['raw_frame_ms']),'historical real raw-frame segments stay exactly unchanged')
modern={**legacy,'schema':2,'effects_quality':'standard','effects_quality_requested':'standard','effects_quality_initial':'standard','effects_quality_start':'standard','effects_quality_end':'standard','effects_quality_verified':True,'effects_quality_violations':0,'configured_settings':{**legacy['configured_settings'],'effects_quality':'standard'}}
check(analyzer['quality_metadata'](modern)['effects_quality']=='standard','matching explicit quality accepted')
for key,value in [('effects_quality_requested','reduced'),('effects_quality',None),('effects_quality_end','invalid')]:
    corrupt={**modern,key:value}
    try: analyzer['quality_metadata'](corrupt)
    except ValueError: check(True,'reject metadata corruption '+key)
    else: raise AssertionError('accepted '+key)
missing={**legacy,'schema':2}
try: analyzer['quality_metadata'](missing)
except ValueError: check(True,'new schema cannot silently become legacy unknown')
else: raise AssertionError('accepted missing quality')
sample={**modern,'scenario':'defense200','camera_mode':'fixed','exit_code':0,'script_errors':[],'source_unchanged':True,'quality_metadata_valid':True,'sample_complete':True,'integrity_passed':True,'acceptance_eligible':True,'initial_deployment_sha256':'same','input_log_sha256':'same'}
args=SimpleNamespace(camera=['fixed'],cases=['defense200'],effects_quality='standard',label='metadata_check',repeats=3)
check(runner['summarize']([sample]*3,args)['baseline_eligible'],'three matched eligible reports retain eligibility')
for change in [{'effects_quality':'reduced'},{'quality_metadata_valid':False}]:
    mixed=[sample,sample,{**sample,**change}]
    check(not runner['summarize'](mixed,args)['baseline_eligible'],'mixed quality or missing verification prevents eligible group '+str(change))
for file in ['tools/run_polish_performance.py','tools/analyze_polish_performance.py']:
    ast.parse((ROOT/file).read_text(encoding='utf-8-sig'))
receipt={'passed':True,'checks':rows,'historical_input':legacy_path.relative_to(ROOT).as_posix(),'historical_input_sha256':hashlib.sha256(legacy_path.read_bytes()).hexdigest(),'godot_run':False,'original_reports_mutated':False}
(ROOT/'scratchpad/effects_quality_metadata_checks.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
print(json.dumps({'passed':True,'checks':len(rows)}))
