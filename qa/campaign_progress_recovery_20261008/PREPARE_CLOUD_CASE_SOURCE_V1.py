"""Preserve prepared recipe and new source bytes; check failed-prior refusal."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
QA = Path(__file__).parent
sys.path.insert(0,str(ROOT/'tools'))
sys.dont_write_bytecode = True
from run_durable_campaign_chain_v12 import canonical, verify_pin


def pin(path):
    raw = path.read_bytes()
    return {'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}


def main():
    original = Path('D:/CodexTemp/lsh_cloud_case_recipe_v1_20261009.json')
    raw = original.read_bytes()
    document = json.loads(raw)
    recipe = document['recipe']
    assert canonical(recipe) == document['recipe_sha256']
    for row in recipe['pins']:verify_pin(row)
    target = QA/'CLOUD_CASE_PRODUCER_SOURCE_RECIPE_V1.json'
    with target.open('xb') as out:out.write(raw)
    snapshots = []
    for name in ['campaign_cloud_restart_exports_v1.py','campaign_cloud_case_runtime_v1.py','run_campaign_cloud_case_v1.py']:
        source = ROOT/'tools'/name
        snapshot = QA/(Path(name).stem+'_source_snapshot.py')
        with snapshot.open('xb') as out:out.write(source.read_bytes())
        assert source.read_bytes() == snapshot.read_bytes()
        snapshots.append({'source':pin(source),'snapshot':pin(snapshot)})
    seal = Path('D:/CodexTemp/lsh_cloud_case_refused_spec_v1_20261009.json')
    work = Path('D:/CodexTemp/lsh-cloud-case-refused-v1-20261009')
    prior = Path('D:/CodexTemp/lsh-durable-chain-20261009/durable_chain_8fe7b18b/receipt.json')
    assert not seal.exists() and not work.exists()
    command = [sys.executable,'-B',str(ROOT/'tools/run_campaign_cloud_case_v1.py'),
               '--godot',recipe['engine']['path'],'--baseline',
               'D:/CodexTemp/lsh-office-20261008/20261008_090824_88273489/receipt.json',
               '--prior-durable',str(prior),'--write-spec',str(seal),'--work-root',str(work)]
    result = subprocess.run(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    log = QA/'CLOUD_CASE_ACTUAL_FAILED_PRIOR_STDOUT_V1.txt'
    with log.open('xb') as out:out.write(result.stdout)
    assert result.returncode == 1 and b'Exact successful limited prior source seal' in result.stdout
    assert not seal.exists() and not work.exists()
    rejection = {'schema':'cloud_case_actual_failed_prior_refusal_v1','command':command,'exit_code':result.returncode,
                 'original_prior':pin(prior),'original_stdout':pin(log),'source_seal_created':False,'work_root_created':False,
                 'native_started':False,'failed_prior_promoted':False,'original19_qualified':False,'overall_goal_qualified':False}
    value = {'schema':'cloud_case_source_preparation_v1','recipe':pin(target),'recipe_logical_sha256':document['recipe_sha256'],
             'recipe_pin_count':len(recipe['pins']),'all_pinned_local_import_edges':len(recipe['Python_import_edges']),
             'runtime_overlays':len(recipe['inputs']['runtime_and_harness_overlays']),'exact_new_snapshots':snapshots,
             'publisher_synthetic_checks':pin(QA/'CLOUD_RESTART_PUBLICATION_HOST_CHECKS_V1.json'),
             'source_only':True,'GD_parsed':False,'actual_three_process_case_executed':False,
             'successful_prior_bound':False,'native_started':False,'complete_case_qualified':False,
             'original19_qualified':False,'overall_goal_qualified':False,'approved_stages':[]}
    for name,record in [('CLOUD_CASE_ACTUAL_FAILED_PRIOR_REFUSAL_V1.json',rejection),('CLOUD_CASE_SOURCE_PREPARATION_V1.json',value)]:
        with (QA/name).open('x',encoding='utf-8',newline='\n') as out:
            json.dump(record,out,ensure_ascii=False,indent=2)
            out.write('\n')
    print(json.dumps({'recipe_pins':len(recipe['pins']),'all_import_edges':len(recipe['Python_import_edges']),
                      'overlays':len(recipe['inputs']['runtime_and_harness_overlays']),
                      'actual_failed_prior_exit':result.returncode,'native_started':False}))


if __name__ == '__main__':main()
