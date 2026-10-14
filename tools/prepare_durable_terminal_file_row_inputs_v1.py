"""Source-only terminal file row numeric comparison inputs; preserves all V13 inputs."""
from pathlib import Path
from prepare_durable_world_timing_inputs_v1 import prepare as previous_prepare
from durable_campaign_full_runtime import read
from durable_campaign_full_evidence_v2 import file_pin
from run_durable_campaign_chain_v12 import verify_pin
ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/campaign_progress_recovery_20261008'
FOLDER = QA / 'terminal_file_row_candidate_v1'
def prepare():
    old = previous_prepare()
    manifest = read(FOLDER / 'SOURCE.json')
    assert manifest['schema'] == 'terminal_file_row_candidate_v1'
    assert manifest['only_changed_function'] == '_verify_relative_profile_file'
    assert manifest['native_started'] is False and manifest['full_chain_qualified'] is False
    for key in ['candidate', 'predecessor', 'diagnostic', 'actual_failure']: verify_pin(manifest[key])
    runtime_path = 'tools/daming_campaign_durable_cross_process_v1.gd'
    matched = [row for row in old['runtime_and_harness_overlays'] if row['runtime_path'] == runtime_path]
    assert len(matched) == 1 and {k: matched[0][k] for k in ['path','bytes','sha256']} == manifest['predecessor']
    before = Path(manifest['predecessor']['path']).read_bytes()
    after = Path(manifest['candidate']['path']).read_bytes()
    start = b'func _verify_relative_profile_file(row: Dictionary) -> bool:'
    stop = b'func _read_terminal_in_new_process() -> void:'
    assert before.count(start) == after.count(start) == before.count(stop) == after.count(stop) == 1
    assert before.split(start)[0] == after.split(start)[0] and before.split(stop)[1] == after.split(stop)[1]
    new = dict(old)
    new['schema'] = 'daming_durable_terminal_file_row_inputs_v1'
    new['runtime_and_harness_overlays'] = [{**manifest['candidate'],'runtime_path':runtime_path} if row['runtime_path'] == runtime_path else row for row in old['runtime_and_harness_overlays']]
    assert len(new['runtime_and_harness_overlays']) == 26
    new['metadata_and_predecessor_reviews'] = old['metadata_and_predecessor_reviews'] + [file_pin(FOLDER / 'SOURCE.json'),file_pin(FOLDER / 'README.md'),file_pin(Path(__file__)),manifest['actual_failure']]
    new['single_terminal_file_row_comparison_change'] = manifest['candidate']
    new['new_full_producer_review_required'] = True
    assert new['execution_contract'] == old['execution_contract']
    return new
