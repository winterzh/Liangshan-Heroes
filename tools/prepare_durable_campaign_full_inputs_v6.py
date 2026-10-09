"""Seal the reviewed per-record component membership transport; never run native."""
import argparse
from pathlib import Path

from prepare_durable_campaign_full_inputs_v5 import prepare as previous_prepare, canonical, check_pin
from durable_campaign_full_runtime import read, write_new
from durable_campaign_full_evidence_v2 import file_pin

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/campaign_progress_recovery_20261008'


def prepare():
    predecessor_path = QA / 'DURABLE_FULL_SOURCE_INPUTS_V5.json'
    saved = read(predecessor_path)
    inputs = previous_prepare()
    assert inputs == saved['spec'] and canonical(inputs) == saved['source_inputs_sha256']
    root = QA / 'final_durable_component_transport_v1_r5'
    manifest_path = root / 'SOURCE.json'
    manifest = read(manifest_path)
    check_pin(manifest['candidate']); check_pin(manifest['predecessor']); check_pin(manifest['production_Codec_unchanged'])
    review_path = root / 'COMPONENT_MEMBERSHIP_TRANSPORT_PRELIMINARY_REVIEW_R5.json'
    review = read(review_path)
    assert review['independent'] is True and review['static_api_closure_passed'] is True and review['approved_stages'] == []
    assert review['component_sha256'] == manifest['candidate']['sha256']
    runtime_path = 'tools/daming_campaign_component_negative_v1.gd'
    old = next(row for row in inputs['runtime_and_harness_overlays'] if row['runtime_path'] == runtime_path)
    assert old['sha256'] == manifest['predecessor']['sha256']
    new = dict(inputs)
    new['schema'] = 'daming_durable_full_source_inputs_v6'
    new['runtime_and_harness_overlays'] = [{**manifest['candidate'], 'runtime_path':runtime_path} if row['runtime_path'] == runtime_path else row
                                         for row in inputs['runtime_and_harness_overlays']]
    assert len(new['runtime_and_harness_overlays']) == 26
    actual_path = QA / 'ACTUAL_COMPONENT_MEMBERSHIP_CODEC_FAILURE_V7.json'
    actual = read(actual_path)
    assert actual['host_terminal_exit'] == 1 and actual['lock_released'] is True and actual['negative52_qualified'] is False
    for row in actual['raw_files']: check_pin({'path':row['archive'],'bytes':row['bytes'],'sha256':row['sha256']})
    new['metadata_and_predecessor_reviews'] = inputs['metadata_and_predecessor_reviews'] + [file_pin(p) for p in
        [predecessor_path, manifest_path, review_path, actual_path, Path(__file__), ROOT / 'tools/prepare_durable_campaign_full_inputs_v5.py']]
    new['single_mapping_change'] = {'runtime_path':runtime_path,'before':old,'after':manifest['candidate']}
    new['new_full_producer_review_required'] = True
    assert new['execution_contract'] == inputs['execution_contract'] and new['native_started'] is False and new['full_qualified'] is False
    return new


if __name__ == '__main__':
    if not __debug__: raise SystemExit('Assertions must remain enabled')
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--write-spec',type=Path); args = parser.parse_args()
    spec = prepare(); digest = canonical(spec)
    if args.write_spec: write_new(args.write_spec, {'spec':spec,'source_inputs_sha256':digest})
    print({'source_preflight':True,'source_inputs_sha256':digest,'native_started':False})
