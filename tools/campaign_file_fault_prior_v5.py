"""Recheck closed actual V16 61-stage source-bound evidence before successor use.

Adapted from the complete prior verifier; no native process or CLI.
"""
from pathlib import Path
import hashlib
import json
import re
from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import no_links, read, sha
from durable_campaign_full_evidence_v2 import file_pin, envelope
from run_durable_campaign_chain_v12 import canonical, verify_pin
from campaign_original19_debug_faults_v5 import typed_equal

def original_document(path,expected=None):
    path=Path(path);no_links(path);raw=path.read_bytes()
    original={'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
    require(expected is None or original==expected, 'Exact first original document pin')
    value=json.loads(raw.decode('utf-8-sig'));verify_pin(original);return value,original


def verify_closed_prior_v16(path, spec):
    prior,original = original_document(path)
    require(prior['schema'] == 'daming_durable_chain_batch_v16' and Path(prior['run']) == Path(spec['prior_durable_run'])
            and Path(path) == Path(prior['run']) / 'receipt.json', 'Exact prior schema/run/path')
    basis,_ = original_document(spec['durable_basis_source_spec_file']['path'],spec['durable_basis_source_spec_file'])
    require(prior['complete'] is True and prior['lock_released'] is True
            and prior['durable_chain_and_matrices_qualified'] is True and prior['overall_goal_qualified'] is False
            and prior['source_spec'] == basis['spec'] and prior['source_spec_sha256'] == basis['source_spec_sha256']
            == canonical(prior['source_spec']), 'Exact successful limited prior source seal')
    require(prior['source_spec']['schema'] == 'daming_durable_chain_source_spec_v16', 'Exact V16 source schema')
    native_review,review_pin = original_document(prior['independent_review']['path'],prior['independent_review'])
    require(native_review['schema'] == 'daming_durable_chain_independent_review_v1'
            and native_review['independent'] is True and native_review['static_api_closure_passed'] is True
            and native_review['approved_stages'] == ['durable_chain_and_matrices']
            and native_review['source_spec_sha256'] == prior['source_spec_sha256']
            and native_review['source_spec_file_sha256'] == spec['durable_basis_source_spec_file']['sha256'], 'Exact V16 limited native admission')
    require(prior['source_spec_file'] == spec['durable_basis_source_spec_file'], 'Same actual prior source file original bytes')
    producer_path = Path(native_review['producer_path']) if 'producer_path' in native_review else Path(__file__).resolve().parent / 'run_durable_campaign_chain_v16.py'
    require(producer_path.resolve() == (Path(__file__).resolve().parent / 'run_durable_campaign_chain_v16.py').resolve()
            and sha(producer_path) == native_review['producer_sha256'], 'Exact V16 producer original bytes')
    for source_pin in prior['source_spec']['pins']: verify_pin(source_pin)
    for source_pin in prior['source_spec']['inputs']['runtime_and_harness_overlays'] + prior['source_spec']['inputs']['metadata_and_predecessor_reviews']: verify_pin(source_pin)
    host,host_pin = original_document(spec['prior_background_host_exit_file']['path'],spec['prior_background_host_exit_file'])
    require(host['schema'] == 'durable_v16_background_host_exit_v1' and host['real_Popen_wait_completed'] is True
            and host['producer_process_terminal'] is True and type(host['producer_exit_code']) is int
            and host['producer_exit_code'] == 0 and type(host['producer_pid']) is int and host['producer_pid'] > 0,
            'Actual original background producer terminal success')
    host_recipe,host_recipe_pin = original_document(host['source_recipe']['path'],host['source_recipe'])
    host_review,host_review_pin = original_document(host['independent_review']['path'],host['independent_review'])
    qa = Path(__file__).resolve().parents[1] / 'qa/campaign_progress_recovery_20261008'
    require(Path(host_recipe_pin['path']).resolve() == (qa / 'BACKGROUND_HOST_SOURCE_V16_V1.json').resolve()
            and Path(host_review_pin['path']).resolve() == (qa / 'BACKGROUND_HOST_INDEPENDENT_REVIEW_V16_V1.json').resolve(), 'Fixed original V16 background source and review paths')
    require(host_recipe['schema'] == 'durable_v16_background_host_source_v1'
            and host_review['schema'] == 'durable_v16_background_host_independent_review_v1'
            and host_review['independent'] is True and host_review['source_review_passed'] is True
            and host_review['approved_stages'] == ['launch_existing_v16_full_batch']
            and host_review['source_recipe_sha256'] == host_recipe_pin['sha256'], 'Exact original limited background admission')
    host_pins = host_recipe['pins']
    require(type(host_pins) is dict and len(host_pins) == 12
            and set(host_pins) == {'launcher','producer','native_spec','native_review','engine','python','baseline','readme',
                                 'previous_launcher','previous_recipe','previous_readme','previous_rejection'}, 'Exact original background source pin set')
    for row in host_pins.values(): verify_pin(row)
    require(host_pins['producer'] == file_pin(producer_path)
            and host_pins['native_spec'] == spec['durable_basis_source_spec_file'] and host_pins['native_review'] == review_pin
            and host_pins['engine'] == prior['source_spec']['engine']
            and host_review['launcher_sha256'] == host_pins['launcher']['sha256']
            and Path(host_pins['launcher']['path']).resolve() == (Path(__file__).resolve().parent / 'run_durable_v16_background_host_v1.py').resolve()
            and host_recipe['original_source_spec_logical_sha256'] == prior['source_spec_sha256'], 'Complete source-bound original V16 background inputs')
    expected_command = [host_pins['python']['path'], '-X', 'utf8', '-B', host_pins['producer']['path'],
                        '--godot', host_pins['engine']['path'], '--baseline', host_pins['baseline']['path'],
                        '--work-root', str(Path(prior['run']).parent), '--source-spec', host_pins['native_spec']['path'],
                        '--independent-review', host_pins['native_review']['path'], '--run']
    require(type(host['command']) is list and all(type(v) is str for v in host['command'])
            and host['command'] == expected_command, 'Exact complete original V16 producer command sequence')
    full_cases = ['A_single_save','B_install_settle_resave','C_install_finish','D_read_terminal']
    capture_path = next(Path(row['path']) for row in basis['spec']['pins'] if Path(row['path']).name == 'CAPTURE_NEGATIVE_INTERFACE_V25D1.json')
    capture_pin=next(row for row in basis['spec']['pins'] if Path(row['path'])==capture_path)
    capture_document,_=original_document(capture_path,capture_pin)
    capture_cases = capture_document['required_cases']
    require(len(capture_cases) == len(set(capture_cases)) == 24, 'Exact prior capture cases')
    labels = {'cold_import'} | {role + '_' + case.lower() for role in ['lu','shi'] for case in full_cases}
    labels |= {role + '_' + kind for role in ['lu','shi'] for kind in ['world','component']}
    labels |= {role + '_capture_' + case.lower() for role in ['lu','shi'] for case in capture_cases}
    steps = prior['steps']
    require(type(steps) is list and len(steps) == len(labels) == 61
            and {row['label'] for row in steps} == labels, 'Exact61 prior native labels')
    require(len({row['pid'] for row in steps}) == len({row['nonce'] for row in steps}) == 61, 'Distinct prior actual PID/nonces')
    for row in steps:
        require(type(row['pid']) is int and row['pid'] > 0 and type(row['nonce']) is str
                and re.fullmatch('[0-9a-f]{32}',row['nonce']) and row['complete'] is True and row['process_terminal'] is True
                and type(row['exit_code']) is int and row['exit_code'] == 0
                and type(row['engine_errors']) is int and row['engine_errors'] == 0, 'Actual prior process terminal/errors')
        output = Path(row['output']); no_links(output)
        require(output.resolve().is_relative_to(Path(prior['run']).resolve()), 'Prior output custody')
        require(sha(output / 'native.log') == row['log_sha256'], 'Prior native log drift')
    require(set(prior['roles']) == {'lu','shi'} and all(set(prior['roles'][role]) == set(full_cases) | {'C_install_finish_journal','D_read_terminal_journal'} for role in ['lu','shi'])
            and set(prior['negative_reports']) == labels - {'cold_import'} - {role + '_' + case.lower() for role in ['lu','shi'] for case in full_cases}, 'Prior exact8+52 report coverage')
    require(type(prior['all_evidence_pins']) is list and prior['all_evidence_pins'], 'Prior complete evidence pin inventory')
    for row in prior['all_evidence_pins']: verify_pin(row)
    for role in ['lu','shi']:
        for case in full_cases:
            row = prior['roles'][role][case]
            verify_pin({k:row[k] for k in ['path','bytes','sha256']})
        for name in ['C_install_finish_journal','D_read_terminal_journal']:
            records = prior['roles'][role][name]
            require(type(records) is list and len(records) == 3, 'Prior complete generation1/2/3 journal rows')
            previous = '0' * 64
            for generation, row in enumerate(records, 1):
                verify_pin({k:row[k] for k in ['path','bytes','sha256']})
                actual = envelope(Path(row['path']), 'LH_LOCAL_CONTINUE_LIFECYCLE', generation, previous)
                require(actual['sha256'] == row['sha256'] and typed_equal(actual['document'],row['document']), 'Prior actual full typed journal chain bytes/document')
                previous = actual['sha256']
    for row in prior['negative_reports'].values(): verify_pin({k:row[k] for k in ['path','bytes','sha256']})
    require(file_pin(path) == original, 'Prior receipt changed during closed evidence verification')
    verify_pin(review_pin); verify_pin(host_pin); verify_pin(host_recipe_pin); verify_pin(host_review_pin)
    for row in host_pins.values(): verify_pin(row)
    return prior,original

