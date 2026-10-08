"""Seal the fixed handoff-directory consumer replacement; source preparation never runs Godot."""
import argparse
import hashlib
import json
from pathlib import Path

from durable_campaign_full_runtime import no_links, read, sha, write_new
from durable_campaign_full_evidence import file_pin

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/campaign_progress_recovery_20261008'
ROUTE = ROOT / 'qa/office_campaign_route_20261008/v34'


def canonical(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def check_pin(row):
    path = Path(row['path'])
    no_links(path)
    assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256'], str(path)


def prepare():
    old_path = QA / 'DURABLE_FULL_SOURCE_INPUTS_V4.json'
    old = read(old_path)
    assert canonical(old['spec']) == old['source_inputs_sha256']
    inputs = old['spec']
    assert inputs['schema'] == 'daming_durable_full_source_inputs_v4'
    bridge = read(inputs['base_bridge']['path'])
    check_pin(inputs['base_bridge'])
    assert bridge['complete'] is True and bridge['candidate_identity'] == inputs['base_identity']
    for row in inputs['base_identity']['files']:
        check_pin({**row, 'path': str(Path(bridge['candidate_root']) / row['path'])})
    for row in inputs['runtime_and_harness_overlays'] + inputs['metadata_and_predecessor_reviews'] + inputs['actual_semantic_Core_Contract']:
        check_pin(row)
    predecessor = read(QA / 'DURABLE_FULL_INPUTS_PREPARATION_REVIEW_V3.json')
    assert predecessor['independent'] is True and predecessor['static_input_closure_passed'] is True
    manifest = read(ROUTE / 'SOURCE.json')
    check_pin(manifest['candidate'])
    route = ROUTE / 'daming_safe_retreat_route_v26.gd'
    assert Path(manifest['candidate']['path']) == route and manifest['old_costs_guards_deadlines_and_route_rest_unchanged'] is True
    review_path = ROUTE / 'ROUTE_V34_GROUND_INDEPENDENT_REVIEW.json'
    review = read(review_path)
    assert review['independent'] is True and review['static_api_closure_passed'] is True
    assert review['route_sha256'] == sha(route) and review['approved_stages'] == []
    diagnosis = read(QA / 'PRISON_FOCUS_ROUTE_DIAGNOSIS_V1.json')
    assert diagnosis['batch_terminal_exit_code'] == 1 and diagnosis['actual_A_save_qualified'] is False
    for row in diagnosis['raw_files']:
        check_pin({'path': row['archive'], 'bytes': row['bytes'], 'sha256': row['sha256']})
    consumer_root = QA / 'final_durable_retreat_consumer_v1_r3'
    consumer_manifest_path = consumer_root / 'SOURCE.json'
    consumer_manifest = read(consumer_manifest_path)
    consumer = consumer_root / 'daming_campaign_durable_cross_process_v1.gd'
    check_pin(next(v for v in consumer_manifest['candidate_files'] if Path(v['path']) == consumer))
    consumer_review_path = consumer_root / 'CONSUMER_HANDOFF_DIRECTORY_INDEPENDENT_REVIEW_V3.json'
    consumer_review = read(consumer_review_path)
    assert consumer_review['independent'] is True and consumer_review['static_api_closure_passed'] is True
    assert consumer_review['consumer_sha256'] == sha(consumer) and consumer_review['negative_adapters_compatibility_passed'] is True
    assert consumer_review['approved_stages'] == []
    actual = read(QA / 'ACTUAL_SINGLE_SAFE_SAVE_CHECKPOINT_V3.json')
    assert actual['native_batch_terminal_exit'] == 1 and actual['qualified_A_fixture'] is False
    for row in actual['raw_files']:
        check_pin({'path': row['archive'], 'bytes': row['bytes'], 'sha256': row['sha256']})
    replaced = [row for row in inputs['runtime_and_harness_overlays'] if row['runtime_path'] == 'tools/daming_campaign_durable_cross_process_v1.gd']
    assert len(replaced) == 1 and replaced[0]['sha256'] == consumer_manifest['predecessor']['sha256']
    new = json.loads(json.dumps(inputs))
    new['schema'] = 'daming_durable_full_source_inputs_v5'
    new['runtime_and_harness_overlays'] = [{**file_pin(consumer), 'runtime_path': row['runtime_path']}
                                         if row['runtime_path'] == 'tools/daming_campaign_durable_cross_process_v1.gd' else row
                                         for row in inputs['runtime_and_harness_overlays']]
    assert len(new['runtime_and_harness_overlays']) == 26
    new['metadata_and_predecessor_reviews'] += [file_pin(p) for p in [old_path, consumer_manifest_path, consumer_review_path,
        QA / 'ACTUAL_SINGLE_SAFE_SAVE_CHECKPOINT_V3.json', Path(__file__)]]
    new['single_mapping_change'] = {'runtime_path': 'tools/daming_campaign_durable_cross_process_v1.gd', 'before': replaced[0], 'after': file_pin(consumer)}
    new['new_negative_review_required'] = False
    new['new_full_producer_review_required'] = True
    assert new['execution_contract'] == inputs['execution_contract'] and new['native_started'] is False and new['full_qualified'] is False
    return new


if __name__ == '__main__':
    if not __debug__: raise SystemExit('Assertions must remain enabled')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write-spec', type=Path)
    args = parser.parse_args()
    spec = prepare()
    digest = canonical(spec)
    if args.write_spec: write_new(args.write_spec, {'source_inputs_sha256': digest, 'spec': spec})
    print(json.dumps({'source_preflight': True, 'changed_mappings': 1, 'overlays': 26, 'source_inputs_sha256': digest, 'native_started': False}))
