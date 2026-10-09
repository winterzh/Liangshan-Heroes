"""Close only the cancelled owned pre-import wrapper and its exact lock."""
from pathlib import Path
import hashlib,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[3];BASE=ROOT.parent/'qa-ordinary-posture-20261006';sys.path.insert(0,str(ROOT/'tools'))
import run_steam_integration_qa as shared
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    locator=json.loads((BASE/'campaign_units_v19_running.json').read_text(encoding='utf-8'));run=Path(locator['run']).resolve(strict=True)
    assert run.is_relative_to(BASE.resolve()) and locator['wrapper_pid']==186152
    ps="Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Godot|python' } | Select-Object ProcessId,CommandLine | ConvertTo-Json -Compress"
    raw=subprocess.check_output(['powershell','-NoProfile','-Command',ps],encoding='utf-8').strip();rows=json.loads(raw) if raw else [];rows=[rows] if isinstance(rows,dict) else rows
    assert all(r['ProcessId']!=locator['wrapper_pid'] for r in rows)
    assert all(str(run).replace('\\','/').lower() not in str(r.get('CommandLine','')).replace('\\','/').lower() for r in rows)
    assert not (run/'import.log').exists() and not (run/'skills.log').exists() and not (run/'receipt.json').exists()
    parent=json.loads((BASE/'campaign_foundation_v18b_3c7e0a25/receipt.json').read_text(encoding='utf-8'))
    inputs=[]
    for previous in parent['source_files']:
        name=previous['path'];p=ROOT/name;assert sha(p)==sha(run/'project'/name)
        inputs.append({'path':name,'sha256':sha(p),'bytes':p.stat().st_size})
    for name in ['scripts/run_level5_unit_contract.gd','scripts/run_level8_unit_contract.gd']:
        p=ROOT/name;assert sha(p)==sha(run/'project'/name);inputs.append({'path':name,'sha256':sha(p),'bytes':p.stat().st_size})
    harnesses=[]
    for name in ['campaign_units_v19.gd','run_campaign_units_v19.py']:
        p=ROOT/'qa/zhu_wounded_20261005/harness'/name;assert sha(p)==sha(run/'project'/name)
        harnesses.append({'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)})
    assert shared.LOCK.is_file() and shared.LOCK.read_text(encoding='utf-8')==str(run)
    shared.LOCK.unlink()
    record={'complete':False,'source_root':str(ROOT),'run':str(run),'project':str(run/'project'),'source_files':inputs,'harnesses':harnesses,'private_runtime_patches':0,
      'terminal_reason':'Owned wrapper cancelled during natural foreign-engine wait before import, to correct reviewed contracts. No engine command or result from this batch.','engine_started':False,'steps':[],'lock_released':True,'root_input_drift':0,'private_input_drift':0,'producer_sha256':sha(Path(__file__))}
    (run/'receipt.json').write_bytes((json.dumps(record,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    p=ROOT/'qa/zhu_wounded_20261005/campaign_units_preimport_cancelled_v19.json';assert not p.exists();p.write_bytes((json.dumps(record,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    print(json.dumps({'owned_preimport_wrapper_terminal':True,'engine_started':False,'inputs':len(inputs),'lock_released':True}))
if __name__=='__main__':main()
