"""Seal the benchmark-qualified exact R6 audit representation for a new full run."""
import argparse
import re
from pathlib import Path
from prepare_durable_campaign_full_inputs_v6 import prepare as previous_prepare, canonical, check_pin
from durable_campaign_full_runtime import read, write_new
from durable_campaign_full_evidence_v2 import file_pin

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/campaign_progress_recovery_20261008'


def prepare():
    predecessor_path = QA / 'DURABLE_FULL_SOURCE_INPUTS_V6.json'
    saved = read(predecessor_path)
    inputs = previous_prepare()
    assert inputs == saved['spec'] and canonical(inputs) == saved['source_inputs_sha256']
    root = QA / 'final_durable_component_audit_v1_r6'
    manifest_path = root / 'SOURCE.json'
    manifest = read(manifest_path)
    for key in ['candidate', 'predecessor', 'actual_timeout_evidence']: check_pin(manifest[key])
    review_path = root / 'COMPONENT_AUDIT_PRELIMINARY_REVIEW_R6.json'
    review = read(review_path)
    assert review['independent'] is True and review['static_api_closure_passed'] is True and review['approved_stages'] == []
    assert review['component_sha256'] == manifest['candidate']['sha256']
    runtime_path = 'tools/daming_campaign_component_negative_v1.gd'
    old = next(row for row in inputs['runtime_and_harness_overlays'] if row['runtime_path'] == runtime_path)
    assert old['sha256'] == manifest['predecessor']['sha256']
    actual_path = QA / 'ACTUAL_COMPONENT_AUDIT_BENCHMARK_PASS_V4.json'
    actual = read(actual_path)
    assert actual['schema'] == 'actual_component_audit_benchmark_pass_v4' and actual['host_terminal_exit'] == 0
    assert actual['lock_released'] is True and actual['equivalence_benchmark_qualified'] is True
    assert actual['checks'] == 219 and actual['comparison_groups'] == 31
    assert actual['all_complete_typed_bytes_and_original_fingerprints_equal'] is True
    for key in ['physical_write_cost_measured', 'matrix_runtime_speedup_qualified', 'component_matrix_qualified',
                'full_chain_qualified', 'SDK_qualified', 'overall_goal_qualified', 'failed_V3_qualification_transferred']:
        assert actual[key] is False
    archive = QA / 'actual_passed_audit_benchmark_v4'
    expected_files = {'receipt.json', 'checkpoint.json', 'steps/cold_import/native.log',
                      'steps/audit_equivalence_cost/native.log', 'steps/audit_equivalence_cost/report.json'}
    assert {Path(row['archive_path']).relative_to(archive).as_posix() for row in actual['raw_files']} == expected_files
    assert len(actual['raw_files']) == len(expected_files)
    raw_pins = []
    for row in actual['raw_files']:
        pin = {'path':row['archive_path'], 'bytes':row['bytes'], 'sha256':row['sha256']}
        check_pin(pin); raw_pins.append(pin)
    receipt = read(archive / 'receipt.json'); report = read(archive / 'steps/audit_equivalence_cost/report.json')
    assert receipt['complete'] is True and receipt['equivalence_benchmark_qualified'] is True and receipt['lock_released'] is True
    assert receipt['source_spec_sha256'] == actual['source_spec_sha256']
    assert receipt['source_spec_file'] == actual['source_spec_file'] and receipt['independent_review'] == actual['independent_review']
    check_pin(receipt['source_spec_file']); check_pin(receipt['independent_review'])
    seal = read(receipt['source_spec_file']['path']); admission = read(receipt['independent_review']['path'])
    assert seal['source_spec_sha256'] == canonical(seal['spec']) == actual['source_spec_sha256']
    assert seal['spec'] == receipt['source_spec']
    assert admission['schema'] == 'component_audit_benchmark_independent_review_v1'
    assert admission['independent'] is True and admission['static_api_closure_passed'] is True
    assert admission['approved_stages'] == ['read_only_component_audit_equivalence_and_cost_benchmark']
    assert admission['source_spec_sha256'] == actual['source_spec_sha256']
    assert admission['source_spec_file_sha256'] == receipt['source_spec_file']['sha256']
    assert admission['producer_sha256'] == file_pin(ROOT / 'tools/run_component_audit_benchmark_v4.py')['sha256']
    assert admission['probe_sha256'] == file_pin(ROOT / 'tools/campaign_component_audit_benchmark_v3.gd')['sha256']
    candidate = next(row for row in seal['spec']['inputs']['runtime_and_harness_overlays'] if row['runtime_path'] == 'tools/audit_candidate_r6.gd')
    assert candidate['sha256'] == manifest['candidate']['sha256'] and candidate['bytes'] == manifest['candidate']['bytes']
    assert [row['label'] for row in receipt['steps']] == ['cold_import', 'audit_equivalence_cost']
    for step in receipt['steps']:
        assert type(step['pid']) is int and step['complete'] is True and step['process_terminal'] is True and step['exit_code'] == 0
        path = archive / 'steps' / step['label'] / 'native.log'
        assert file_pin(path)['sha256'] == step['log_sha256']
        assert not re.search(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)', path.read_text('utf-8'))
    assert report['schema'] == 'component_audit_benchmark_v3' and report['passed'] is True and report['failures'] == []
    assert report['pid'] == receipt['steps'][1]['pid'] and report['nonce'] == receipt['steps'][1]['nonce']
    assert len(report['checks']) == len({row['label'] for row in report['checks']}) == 219
    assert all(row['ok'] is True for row in report['checks']) and len(report['observations']) == 31
    assert report['time_scale'] == 1 and report['physics_ticks'] == 60
    assert 'COMPONENT_AUDIT_BENCHMARK true 219' in (archive / 'steps/audit_equivalence_cost/native.log').read_text('utf-8')
    for key in ['physical_write_cost_measured', 'matrix_runtime_speedup_qualified', 'component_matrix_qualified',
                'full_chain_qualified', 'SDK_qualified', 'overall_goal_qualified']:
        assert report[key] is False
    new = dict(inputs)
    new['schema'] = 'daming_durable_full_source_inputs_v7'
    new['runtime_and_harness_overlays'] = [{**manifest['candidate'], 'runtime_path':runtime_path} if row['runtime_path'] == runtime_path else row
                                         for row in inputs['runtime_and_harness_overlays']]
    assert len(new['runtime_and_harness_overlays']) == 26
    extra = [predecessor_path, manifest_path, review_path, actual_path, Path(__file__),
             ROOT / 'tools/prepare_durable_campaign_full_inputs_v6.py', ROOT / 'tools/run_component_audit_benchmark_v4.py',
             ROOT / 'tools/campaign_component_audit_benchmark_v3.gd', Path(receipt['source_spec_file']['path']),
             Path(receipt['independent_review']['path'])]
    new['metadata_and_predecessor_reviews'] = inputs['metadata_and_predecessor_reviews'] + [file_pin(p) for p in extra] + raw_pins
    new['single_mapping_change'] = {'runtime_path':runtime_path, 'before':old, 'after':manifest['candidate']}
    new['benchmark_is_read_only_data_not_full_chain_qualification'] = True
    new['benchmark_actual_pass'] = file_pin(actual_path)
    new['new_full_producer_review_required'] = True
    assert new['execution_contract'] == inputs['execution_contract'] and new['native_started'] is False and new['full_qualified'] is False
    return new


if __name__ == '__main__':
    if not __debug__: raise SystemExit('Assertions must remain enabled')
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--write-spec',type=Path); args = parser.parse_args()
    spec = prepare(); digest = canonical(spec)
    if args.write_spec: write_new(args.write_spec, {'spec':spec,'source_inputs_sha256':digest})
    print({'source_preflight':True,'source_inputs_sha256':digest,'native_started':False})
