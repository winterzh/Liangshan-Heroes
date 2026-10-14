"""Source-only successor; full original V14 inputs retained except terminal consumer."""
from pathlib import Path
from prepare_durable_terminal_file_row_inputs_v1 import prepare as previous_prepare
from durable_campaign_full_runtime import read
from durable_campaign_full_evidence_v2 import file_pin
from run_durable_campaign_chain_v12 import verify_pin
ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/campaign_progress_recovery_20261008'
FOLDER = QA / 'terminal_steam_transport_candidate_v2'

def prepare():
    old = previous_prepare()
    manifest = read(FOLDER / 'SOURCE.json')
    assert manifest['schema'] == 'terminal_steam_transport_candidate_v2'
    assert manifest['native_started'] is False and manifest['full_chain_qualified'] is False
    assert manifest['original_phase_startup_settlement_completion_guards_retained'] is True
    assert manifest['retained_aggregate_label'] == 'restart startup has no replay or completion capability'
    for key in ['candidate', 'predecessor', 'diagnostic', 'actual_failure', 'original_C']: verify_pin(manifest[key])
    runtime_path = 'tools/daming_campaign_durable_cross_process_v1.gd'
    matched = [r for r in old['runtime_and_harness_overlays'] if r['runtime_path'] == runtime_path]
    assert len(matched) == 1 and {k:matched[0][k] for k in ['path','bytes','sha256']} == manifest['predecessor']
    before = Path(manifest['predecessor']['path']).read_bytes()
    after = Path(manifest['candidate']['path']).read_bytes()
    start = b'func _read_terminal_in_new_process() -> void:'
    helper = b'func _json_transport_equal('
    end = b'\tvar menu: Node = load("res://scenes/menu.tscn").instantiate()'
    assert before.count(start) == after.count(start) == 1
    assert after.count(helper) == 1 and before.split(start)[0] == after.split(helper)[0]
    # Everything after the original startup guard and before D, including file-size fix, is unchanged.
    assert before.split(start)[1].split(end,1)[1] == after.split(start)[1].split(end,1)[1]
    guard = b'\tvar recovered_flow: Node = get_node("/root/ContinueFlow")'
    assert before.split(start)[1].split(guard)[0] == after.split(start)[1].split(guard)[0]
    probe = Path(manifest['diagnostic']['path']).read_bytes()
    assert probe.split(helper)[1] == after.split(helper)[1].split(start)[0]
    new = dict(old)
    new['schema'] = 'daming_durable_terminal_steam_inputs_v1'
    new['runtime_and_harness_overlays'] = [{**manifest['candidate'],'runtime_path':runtime_path} if r['runtime_path'] == runtime_path else r for r in old['runtime_and_harness_overlays']]
    assert len(new['runtime_and_harness_overlays']) == 26
    new['metadata_and_predecessor_reviews'] = old['metadata_and_predecessor_reviews'] + [file_pin(FOLDER/'SOURCE.json'),file_pin(FOLDER/'README.md'),file_pin(Path(__file__)),manifest['actual_failure'],manifest['original_C'],manifest['diagnostic']]
    new['terminal_steam_transport_successor'] = manifest['candidate']
    new['new_full_producer_review_required'] = True
    assert new['execution_contract'] == old['execution_contract']
    return new
