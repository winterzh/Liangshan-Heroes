"""Seal ordinary cloud restart candidate/source labels; never launch Godot."""
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
    gd = HERE/'campaign_original19_cloud_restart_v1.gd'
    functions = {part.split('(')[0]:part[part.index('\n')+1:] for part in re.split(r'(?m)^func ',gd.read_text(encoding='utf-8'))[1:]}
    assert set(functions) == {'_restart','_cloud_journal_files','_empty_cloud_stage','_no_terminal_files','_write','_finish'}
    inventory = {name:check_arguments(body) for name,body in functions.items()}
    assert all(not rows for name,rows in inventory.items() if name != '_restart')
    parent = parent_contract()
    labels = parent['header_labels']+[row['label_prefix'] for row in inventory['_restart']]
    assert len(labels) == len(set(labels))
    previous = QA/'cloud_applying_driver_candidate_v3/SOURCE.json'
    first = json.loads(previous.read_bytes())
    production = first['production_runtime_sources']
    for row in production:
        assert pin(Path(row['path'])) == {k:row[k] for k in ['path','bytes','sha256']}
    extra = [QA/'integrated_v4_r12/scripts/run_campaign_startup_scan.gd',
             QA/'integrated_v4_r12/scripts/run_campaign_progress_gate.gd',
             QA/'integrated_v4_r12/scripts/run_campaign_cfg_transaction.gd']
    contract = {'schema':'cloud_restart_complete_label_contract_v1','GD':pin(gd),'parent_GD':parent['GD'],
                'builder':pin(Path(__file__)),'parent_builder':parent['builder'],'parser':parent['parser'],
                'identity_fields_order':parent['identity_fields_order'],'complete_labels':labels,
                'literal_check_inventory':inventory,'GD_parsed':False,'native_started':False,'approved_stages':[]}
    manifest = {'schema':'cloud_restart_native_driver_source_v1','candidate':pin(gd),'parent_GD':parent['GD'],
                'first_driver_source':pin(previous),'first_driver':first['candidate'],
                'production_runtime_sources':production,'startup_dependencies':[pin(path) for path in extra],
                'ordered_labels':contract,'case':'cloud_applying_callback_no_upload_claim','required_mode':'restart_first',
                'closed_exports':['report.json'],'first_report_environment_keys':['CAMPAIGN_CLOUD_PRIOR_REPORT_FILE','CAMPAIGN_CLOUD_PRIOR_REPORT_SHA256'],
                'same_raw_native_user_text_required':True,'same_real_private_profile_required':True,
                'ordinary_observation_frames':180,'Steam_disabled':True,'host_first_to_restart_physical_binding_implemented':False,
                'complete_cloud_producer_implemented':False,'successful_prior_bound':False,'GD_parsed':False,'native_started':False,
                'ordinary_restart_qualified':False,'original19_qualified':False,'overall_goal_qualified':False,'approved_stages':[]}
    for name,value in [('SOURCE.json',manifest),('COMPLETE_LABEL_CONTRACT_V1.json',contract)]:
        with (HERE/name).open('x',encoding='utf-8',newline='\n') as out:
            json.dump(value,out,ensure_ascii=False,indent=2)
            out.write('\n')
    print(json.dumps({'source_only':True,'complete_labels':len(labels),'native_started':False,'GD_parsed':False}))


if __name__ == '__main__':main()
