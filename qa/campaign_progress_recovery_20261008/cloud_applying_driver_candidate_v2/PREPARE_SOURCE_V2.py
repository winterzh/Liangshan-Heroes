"""Seal a real cloud-apply driver and ordered source checks; no Godot parse."""
from pathlib import Path
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[3]
QA = ROOT/'qa/campaign_progress_recovery_20261008'
HERE = Path(__file__).parent
sys.path.insert(0,str(ROOT/'tools'))
sys.dont_write_bytecode = True
from prepare_campaign_first_repeat_labels_v1 import build as parent_contract
from prepare_campaign_file_fault_labels_v3 import check_arguments


def pin(path):
    raw = path.read_bytes()
    return {'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}


def main():
    gd = HERE/'campaign_original19_cloud_applying_v2.gd'
    text = gd.read_text(encoding='utf-8')
    functions = {part.split('(')[0]:part[part.index('\n')+1:] for part in re.split(r'(?m)^func ',text)[1:]}
    assert set(functions) == {'_fresh','_write','_finish'}
    inventory = {name:check_arguments(body) for name,body in functions.items()}
    labels = {name:[row['label_prefix'] for row in rows] for name,rows in inventory.items()}
    parent = parent_contract()
    complete = parent['header_labels'] + labels['_fresh'] + labels['_finish']
    ready = parent['header_labels'] + labels['_fresh'][:8]
    before_apply = parent['header_labels'] + labels['_fresh'][:11]
    assert labels['_fresh'][7] == 'closed original payload and baseline before real cloud apply'
    assert len(labels['_fresh']) == 19 and len(labels['_finish']) == 2
    contract = {'schema':'cloud_applying_source_labels_v2','GD':pin(gd),'parent_GD':parent['GD'],
                'builder':pin(Path(__file__)),'parent_builder':parent['builder'],'parser':parent['parser'],
                'identity_fields_order':parent['identity_fields_order'],'complete_labels':complete,
                'driver_ready_labels':ready,'before_real_apply_labels':before_apply,'literal_check_inventory':inventory,
                'scope':'actual production local cloud apply and applying callback only, not natural victory or actual Steam upload',
                'GD_parsed':False,'native_started':False,'approved_stages':[]}
    recipe_path = QA/'NATURAL_CALLBACK_PRODUCER_SOURCE_RECIPE_V1.json'
    recipe = json.loads(recipe_path.read_bytes())['recipe']
    inputs = recipe['inputs']
    bridge = json.loads(Path(inputs['base_bridge']['path']).read_bytes())
    aliases = {row['runtime_path']:row for row in inputs['runtime_and_harness_overlays']}
    production = []
    for alias in ['project.godot','scripts/campaign.gd','scripts/steam_cloud.gd','scripts/settings.gd',
                  'scripts/localization.gd','scripts/steam_service.gd','scripts/continue_flow.gd',
                  'scripts/run_campaign_progress_gate.gd','scripts/run_campaign_cfg_transaction.gd','scripts/run_content_identity.gd']:
        if alias in aliases:
            row = {k:aliases[alias][k] for k in ['path','bytes','sha256']}
        else:
            base = next(row for row in inputs['base_identity']['files'] if row['path']==alias)
            row = {**base,'path':str(Path(bridge['candidate_root'])/alias)}
        assert pin(Path(row['path'])) == row
        production.append({**row,'runtime_path':alias})
    previous = QA/'cloud_applying_driver_candidate_v1'
    manifest = {'schema':'cloud_applying_native_driver_source_v2','candidate':pin(gd),
                'parent_GD':parent['GD'],'observer_GD':pin(HERE/'campaign_cloud_callback_observer_v2.gd'),
                'observer_parent_GD':pin(QA/'callback_observer_candidate_v1/campaign_callback_snapshot_v1.gd'),
                'previous_source':pin(previous/'SOURCE.json'),
                'previous_chain_review':pin(previous/'CLOUD_APPLYING_DRIVER_PRELIMINARY_REVIEW_V1.json'),
                'previous_observation_rejection':pin(previous/'CLOUD_APPLYING_DRIVER_PRELIMINARY_REVIEW_V1_ADDENDUM.json'),
                'source_map':pin(QA/'callback_observer_candidate_v1/ACTUAL_CALLBACK_SOURCE_MAP_V1.json'),
                'production_runtime_sources':production,'recipe_basis':pin(recipe_path),
                'ordered_labels':contract,'required_mode':'first','case':'cloud_applying_callback_no_upload_claim',
                'closed_exports':['callback_driver_ready.json','cloud_apply_ready.json','report.json'],
                'synthetic_local_owner':'1','SDK_disabled':True,'fake_production_node':False,
                'arm_contract':{'command':'lsh_callback19:arm','command_data':['owned PID','owned nonce','fixed case',0],
                                'reply':'lsh_callback19:armed','same_original_transport_after_breakpoint':True,
                                'driver_wait_seconds':30,'read_snapshot_sequence':1,'current_engine_ordering_verified':False},
                'host_phase_integrated':False,'complete_consumer_implemented':False,'producer_integrated':False,
                'GD_parsed':False,'native_started':False,'Steam_account_qualified':False,
                'upload_qualified':False,'original19_qualified':False,'overall_goal_qualified':False,'approved_stages':[]}
    for name,value in [('SOURCE.json',manifest),('COMPLETE_LABEL_CONTRACT_V2.json',contract)]:
        with (HERE/name).open('x',encoding='utf-8',newline='\n') as out:
            json.dump(value,out,ensure_ascii=False,indent=2)
            out.write('\n')
    print(json.dumps({'source_only':True,'complete_labels':len(complete),'driver_ready_labels':len(ready),'before_real_apply_labels':len(before_apply),'production_sources':len(production),'native_started':False}))


if __name__ == '__main__':
    main()
