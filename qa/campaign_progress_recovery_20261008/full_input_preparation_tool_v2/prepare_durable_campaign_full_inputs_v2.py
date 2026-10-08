"""Seal source inputs for the durable successor; this never grants or runs native QA."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/campaign_progress_recovery_20261008'


def sha(path):
    no_links(Path(path))
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    no_links(Path(path))
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def no_links(path):
    for item in [Path(path), *Path(path).parents]:
        if item.exists() or item.is_symlink():
            assert not item.is_symlink() and not getattr(item.lstat(), 'st_file_attributes', 0) & 0x400, str(item)


def pin(path):
    path = Path(path)
    no_links(path)
    path = path.resolve(strict=True)
    no_links(path)
    return {'path': str(path), 'bytes': path.stat().st_size, 'sha256': sha(path)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write-spec', type=Path)
    args = parser.parse_args()
    actual = QA / 'actual_scoped_recovery_r12_bai_v1/receipt.json'
    receipt = read(actual)
    assert receipt['complete'] and receipt['lock_released'] and len(receipt['scoped_groups']) == 3
    selected_spec = QA / 'NATURAL_TERMINAL_SOURCE_SPEC_R12_BAI_V1.json'
    source = read(selected_spec)['spec']
    for row in source['helpers'] + source['candidate_files'] + source['semantic_extra_sources'] + [v['source'] for v in source['fixed_dependencies']]:
        path = Path(row['path'])
        no_links(path)
        assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256'], str(path)
    bridge_row = next(v for v in source['helpers'] if Path(v['path']).name == 'complete_source_bridge_v1.json')
    bridge = read(bridge_row['path'])
    assert bridge['complete'] and bridge['schema'] == 'office_complete_candidate_source_bridge_v1'
    base = Path(bridge['candidate_root'])
    no_links(base)
    for row in bridge['candidate_identity']['files']:
        path = base / row['path']
        no_links(path)
        assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256'], str(path)
    full = QA / 'final_durable_retreat_consumer_v1_r2'
    admit = QA / 'final_executor_candidate_v1_r2'
    negative = QA / 'final_durable_negative_adapters_v1_r3'
    harnesses = [
        admit / 'daming_admit_campaign_v2_candidate_v1.gd',
        admit / 'daming_admit_campaign_v2_candidate_v1.tscn',
        full / 'daming_campaign_durable_cross_process_v1.gd',
        full / 'daming_campaign_durable_cross_process_v1.tscn',
        full / 'daming_safe_retreat_route_v26.gd',
        *[negative / f'daming_campaign_{kind}_negative_v1.{suffix}' for kind in ['world', 'component', 'capture'] for suffix in ['gd', 'tscn']],
    ]
    assert len(harnesses) == 11 and len({p.name for p in harnesses}) == 11
    overlays = [{**pin(Path(v['path'])), 'runtime_path': v['runtime_path']} for v in source['candidate_files']]
    overlays += [{**pin(p), 'runtime_path': 'tools/' + p.name} for p in harnesses]
    assert len(overlays) == 26 and len({v['runtime_path'] for v in overlays}) == 26
    reviews = [QA / 'INTEGRATION_SOURCE_REVIEW_V5_R12.json',
               QA / 'NATURAL_TERMINAL_INDEPENDENT_REVIEW_R12_BAI_V1.json',
               full / 'FINAL_DURABLE_RETREAT_CONSUMER_PRELIMINARY_REVIEW_V2.json']
    assert all(read(p)['independent'] and read(p)['static_api_closure_passed'] for p in reviews)
    metadata = [QA / 'SOURCE_AUDIT_V14.json', selected_spec, actual, *reviews,
                admit / 'SOURCE.json', full / 'SOURCE.json', negative / 'SOURCE.json', Path(__file__)]
    spec = {'schema': 'daming_durable_full_source_inputs_v2',
            'base_bridge': pin(Path(bridge_row['path'])), 'base_identity': bridge['candidate_identity'],
            'runtime_and_harness_overlays': overlays, 'metadata_and_predecessor_reviews': [pin(p) for p in metadata],
            'actual_semantic_Core_Contract': source['semantic_extra_sources'],
            'source_prepare_only': True, 'new_negative_review_required': True,
            'execution_contract': {'roles': ['lu', 'shi'], 'role_ABCD_processes': 8,
                                   'world_rows_per_role': 264, 'component_rows_per_role': 362,
                                   'live_cases_per_role': 24, 'negative_process_stages': 52,
                                   'original_fault_cases': 19, 'CAMPAIGN_QA': '',
                                   'slot_root': 'user://continue/v1', 'lifecycle_generations': [1, 2, 3]},
            'whole_producer_ready': False, 'approved_stages': [], 'native_started': False,
            'full_qualified': False}
    digest = hashlib.sha256(json.dumps(spec, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()).hexdigest()
    if args.write_spec:
        no_links(args.write_spec)
        with args.write_spec.open('x', encoding='utf-8', newline='\n') as stream:
            stream.write(json.dumps({'source_inputs_sha256': digest, 'spec': spec}, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'preflight': True, 'overlays': len(overlays), 'harnesses': len(harnesses),
                      'source_inputs_sha256': digest, 'native_started': False, 'full_qualified': False}))


if __name__ == '__main__':
    main()
