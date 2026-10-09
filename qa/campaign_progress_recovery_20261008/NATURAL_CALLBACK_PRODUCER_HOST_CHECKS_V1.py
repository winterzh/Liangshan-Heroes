"""Source/prior refusal checks only. No Godot, socket or native batch."""
from pathlib import Path
from types import SimpleNamespace
import ast
import hashlib
import json
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
QA = Path(__file__).parent
sys.path.insert(0, str(ROOT/'tools'))
sys.dont_write_bytecode = True
import run_campaign_natural_callback_v1 as producer
from campaign_file_fault_prior_v2 import verify_closed_prior_v12


def main():
    recipe_path = QA/'NATURAL_CALLBACK_PRODUCER_SOURCE_RECIPE_V1.json'
    original = recipe_path.read_bytes()
    document = json.loads(original)
    recipe = document['recipe']
    assert producer.canonical(recipe) == document['recipe_sha256']
    checks = []
    def passed(label):
        checks.append({'label':label,'passed':True})
    for pin in recipe['pins']:
        producer.verify_pin(pin)
    passed('all175 original recipe pins unchanged')
    overlays = {v['runtime_path']:v for v in recipe['inputs']['runtime_and_harness_overlays']}
    for pin in recipe['manifest']['pins'][:3]:
        assert overlays['tools/'+Path(pin['path']).name] == {**pin,'runtime_path':'tools/'+Path(pin['path']).name}
    passed('native child/parent/read-only observer all sealed as actual overlays')
    passed('recipe logical hash equals original bytes-derived document')
    args = SimpleNamespace(prior_durable=None)
    try:
        producer.prior_receipt_path(args)
    except RuntimeError as error:
        assert str(error) == 'Explicit absolute terminal prior receipt required'
    else:
        raise AssertionError('Missing prior accepted')
    passed('missing explicit prior refused')
    root = Path(tempfile.mkdtemp(prefix='lsh-callback-producer-host-',dir='D:/CodexTemp'))
    receipts = []
    for suffix in ['fb1da6e0','6b31df47','6409dde9','8fe7b18b']:
        path = Path('D:/CodexTemp/lsh-durable-chain-20261009')/('durable_chain_'+suffix)/'receipt.json'
        raw = path.read_bytes()
        prior = json.loads(raw)
        assert prior['complete'] is False
        spec = {**recipe,'prior_durable_run':str(path.parent)}
        try:
            verify_closed_prior_v12(path,spec)
        except RuntimeError as error:
            assert str(error) == 'Exact successful limited prior source seal'
        else:
            raise AssertionError('Failed prior accepted')
        receipts.append({'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'refused':True})
        passed('actual failed prior '+suffix+' refused, no partial A promotion')
    path = Path(receipts[-1]['path'])
    work_root = root/'must_not_create'
    args = SimpleNamespace(prior_durable=path,work_root=work_root)
    spec = {**recipe,'prior_durable_run':str(path.parent),'prior_durable_receipt':receipts[-1]}
    try:
        producer.Suite(args,spec)
    except RuntimeError as error:
        assert str(error) == 'Exact successful limited prior source seal'
    else:
        raise AssertionError('Suite accepted failed prior')
    assert not work_root.exists() and list(root.iterdir()) == []
    passed('actual Suite rejects failed prior before mkdir/batch/profile construction')
    tree = ast.parse((ROOT/'tools/run_campaign_natural_callback_v1.py').read_bytes())
    main_source = ast.get_source_segment((ROOT/'tools/run_campaign_natural_callback_v1.py').read_text(encoding='utf-8'),next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='main'))
    assert main_source.index('spec = source_spec(args)') < main_source.index('suite = Suite(args,spec)')
    assert "review['complete_consumer_and_phase_reviewed'] is True" in main_source
    assert "review['approved_stages'] == [SCOPE]" in main_source
    passed('static main sequence requires successful prior and new complete admission before Suite')
    result = {'schema':'natural_callback_producer_host_checks_v1','script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'recipe_pin':{'path':str(recipe_path),'bytes':len(original),'sha256':hashlib.sha256(original).hexdigest()},
              'producer_pin':producer.file_pin(ROOT/'tools/run_campaign_natural_callback_v1.py'),
              'checks':checks,'count':len(checks),'all_passed':True,'actual_failed_priors':receipts,'work':str(root),
              'classification':'source/actual failed-prior and pre-mkdir Suite refusal only',
              'native_started':False,'socket_opened':False,'complete_consumer_validate_called':False,
              'successful_prior_verified':False,'approved_stages':[],'overall_goal_qualified':False}
    with Path(__file__).with_suffix('.json').open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(result,stream,ensure_ascii=False,indent=2)
        stream.write('\n')
    print(json.dumps({'checks':len(checks),'all_passed':True,'native_started':False}))


if __name__ == '__main__':
    main()
