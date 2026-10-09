"""Seal linked failure consumer and inherited phase source; no native launcher."""
import ast
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
QA = Path(__file__).parent
sys.path.insert(0, str(ROOT/'tools'))
sys.dont_write_bytecode = True
from run_durable_campaign_chain_v12 import canonical, verify_pin


def pin(path):
    raw = path.read_bytes()
    return {'path': str(path), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def main():
    basis_path = QA/'CLOUD_FAILURE_EVIDENCE_SOURCE_SPEC_V1.json'
    basis = json.loads(basis_path.read_bytes())
    assert canonical(basis['spec']) == basis['source_spec_sha256']
    pins = {row['path']: row for row in basis['spec']['pins']}
    consumer = ROOT/'tools/campaign_cloud_failure_evidence_v2.py'
    wrapper = ROOT/'tools/campaign_cloud_failure_runtime_v1.py'
    additions = [consumer, wrapper, Path(__file__), basis_path,
                 QA/'campaign_cloud_failure_evidence_v1_source_snapshot.py',
                 QA/'CLOUD_FAILURE_JOURNAL_DATA_CHECKS_V2.py',
                 QA/'CLOUD_FAILURE_JOURNAL_DATA_CHECKS_V2.json',
                 QA/'CLOUD_FAILURE_RUNTIME_SOURCE_API_CHECKS_V1.json']

    def adopt(path):
        row = pin(path)
        assert row['path'] not in pins or pins[row['path']] == row
        pins[row['path']] = row

    for path in additions:
        adopt(path)
    checked, edges = set(), []
    while True:
        pending = [Path(row['path']) for row in pins.values() if row['path'].endswith('.py') and row['path'] not in checked]
        if not pending:
            break
        for path in pending:
            checked.add(str(path))
            for node in ast.walk(ast.parse(path.read_bytes(), filename=str(path))):
                modules = [node.module] if isinstance(node, ast.ImportFrom) and node.level == 0 else [v.name for v in node.names] if isinstance(node, ast.Import) else []
                for module in modules:
                    if not module:
                        continue
                    target = ROOT/'tools'/(module.split('.')[0]+'.py')
                    if target.is_file():
                        edges.append({'source': str(path), 'module': module, 'target': str(target)})
                        adopt(target)
    for row in pins.values():
        verify_pin(row)
    spec = {'schema': 'cloud_failure_runtime_source_v2', 'basis': pin(basis_path),
            'basis_logical_sha256': basis['source_spec_sha256'], 'consumer': pin(consumer),
            'wrapper': pin(wrapper), 'builder': pin(Path(__file__)),
            'candidate_manifest': basis['spec']['candidate_manifest'],
            'candidate_review': basis['spec']['candidate_review'],
            'label_contract': basis['spec']['label_contract'],
            'pins': sorted(pins.values(), key=lambda row: row['path']), 'Python_import_edges': edges,
            'consumer_implemented': True, 'host_phase_wrapper_implemented': True,
            'parent_phase_modified': False, 'complete_producer_implemented': False,
            'consumer_constructed_or_validate_called': False, 'host_phase_called': False,
            'successful_all61_prior_available': False, 'authorized_account_retry_implemented': False,
            'same_profile_restart_implemented': False, 'native_started': False,
            'original19_qualified': False, 'UI_qualified': False, 'SDK_qualified': False,
            'overall_goal_qualified': False, 'approved_stages': []}
    with (QA/'CLOUD_FAILURE_RUNTIME_SOURCE_SPEC_V2.json').open('x', encoding='utf-8', newline='\n') as stream:
        json.dump({'source_spec_sha256': canonical(spec), 'spec': spec}, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
    for path in [consumer, wrapper]:
        with (QA/(path.stem+'_source_snapshot.py')).open('xb') as stream:
            stream.write(path.read_bytes())
    print(json.dumps({'source_pins': len(pins), 'all_pinned_import_edges': len(edges),
                      'source_spec_sha256': canonical(spec), 'native_started': False}))


if __name__ == '__main__':
    main()
