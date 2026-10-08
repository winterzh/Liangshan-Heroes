"""Readonly actual failed-prior gates; no successful fixture or native process."""
import argparse,hashlib,json,sys,uuid
from pathlib import Path
from types import SimpleNamespace
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'));sys.dont_write_bytecode=True
from run_campaign_first_repeat_v1 import source_spec,Suite

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=Path(__file__).with_suffix('.json'));args=p.parse_args()
    recipe=json.loads((ROOT/'qa/campaign_progress_recovery_20261008/FIRST_REPEAT_PRODUCER_SOURCE_RECIPE_V1.json').read_bytes())['recipe'];checks=[]
    work_root=Path('D:/CodexTemp')/('lsh-first-repeat-refusal-'+uuid.uuid4().hex[:8]);assert not work_root.exists()
    fixed=SimpleNamespace(godot=Path('C:/Users/rsb/Desktop/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe'),baseline=Path('D:/CodexTemp/lsh-office-20261008/20261008_090824_88273489/receipt.json'),work_root=work_root)
    for run in ['durable_chain_fb1da6e0','durable_chain_6b31df47','durable_chain_6409dde9','durable_chain_8fe7b18b']:
        path=Path('D:/CodexTemp/lsh-durable-chain-20261009')/run/'receipt.json';raw=path.read_bytes();fixed.prior_durable=path
        for gate,call in [('source_spec',lambda:source_spec(fixed)),('Suite_constructor',lambda:Suite(fixed,{**recipe,'prior_durable_run':str(path.parent)}))]:
            try:call()
            except RuntimeError as e:assert str(e)=='Exact successful limited prior source seal';checks.append({'case':run,'gate':gate,'refused':True,'reason':str(e),'receipt_sha256':hashlib.sha256(raw).hexdigest()})
            else:raise AssertionError('Failed prior admitted: '+run+' '+gate)
            assert path.read_bytes()==raw and not work_root.exists()
    value={'schema':'first_repeat_producer_actual_failed_prior_checks_v1','script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'checks':checks,'count':len(checks),'all_passed':True,'source_seal_created':False,'work_root_created':False,'Popen_started':False,'Godot_started':False,'successful_prior_qualification_claimed':False,'approved_stages':[]}
    with args.output.open('x',encoding='utf-8',newline='\n') as f:json.dump(value,f,ensure_ascii=False,indent=2);f.write('\n')
    print(json.dumps({'actual_failed_prior_gate_checks':len(checks),'all_refused_before_mkdir':True,'native_started':False}))

if __name__=='__main__':main()
