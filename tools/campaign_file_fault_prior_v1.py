"""Recheck closed actual V12 61-stage source-bound evidence before successor use.

Adapted from the complete prior verifier; no native process or CLI.
"""
from pathlib import Path
import re
from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import no_links, read, sha
from durable_campaign_full_evidence_v2 import file_pin, envelope
from run_durable_campaign_chain_v12 import canonical, verify_pin

def verify_closed_prior_v12(path, spec):
    original = file_pin(path)
    prior = read(path)
    require(prior['schema'] == 'daming_durable_chain_batch_v12' and Path(prior['run']) == Path(spec['prior_durable_run'])
            and Path(path) == Path(prior['run']) / 'receipt.json', 'Exact prior schema/run/path')
    basis = read(spec['durable_basis_source_spec_file']['path'])
    require(prior['complete'] is True and prior['lock_released'] is True
            and prior['durable_chain_and_matrices_qualified'] is True and prior['overall_goal_qualified'] is False
            and prior['source_spec'] == basis['spec'] and prior['source_spec_sha256'] == basis['source_spec_sha256']
            == canonical(prior['source_spec']), 'Exact successful limited prior source seal')
    full_cases = ['A_single_save','B_install_settle_resave','C_install_finish','D_read_terminal']
    capture_path = next(Path(row['path']) for row in basis['spec']['pins'] if Path(row['path']).name == 'CAPTURE_NEGATIVE_INTERFACE_V25D1.json')
    capture_cases = read(capture_path)['required_cases']
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
                require(actual['sha256'] == row['sha256'] and actual['document'] == row['document'], 'Prior actual full journal chain bytes/document')
                previous = actual['sha256']
    for row in prior['negative_reports'].values(): verify_pin({k:row[k] for k in ['path','bytes','sha256']})
    require(file_pin(path) == original, 'Prior receipt changed during closed evidence verification')
    return original

