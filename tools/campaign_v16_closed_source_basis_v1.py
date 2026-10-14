"""Source preparation only; actual closed V16 evidence is a separate mandatory gate."""
import ast
import json
from pathlib import Path
from run_campaign_file_faults_v3 import pinned_document
from run_durable_campaign_chain_v16 import source_spec as durable_spec, canonical, verify_pin
from durable_campaign_full_evidence_v2 import file_pin
from durable_campaign_full_matrices import require

ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'qa/campaign_progress_recovery_20261008'

def source_basis(args):
    saved,basis_pin=pinned_document(QA/'DURABLE_CHAIN_SOURCE_SPEC_V16.json')
    current=durable_spec(args)
    require(current==saved['spec'] and canonical(current)==saved['source_spec_sha256'], 'Exact immutable current V16 full basis')
    review,review_pin=pinned_document(QA/'DURABLE_CHAIN_INDEPENDENT_REVIEW_V16.json')
    require(review['independent'] is True and review['static_api_closure_passed'] is True
            and review['approved_stages']==['durable_chain_and_matrices']
            and review['source_spec_sha256']==saved['source_spec_sha256']
            and review['source_spec_file_sha256']==basis_pin['sha256'], 'Exact limited V16 full source admission')
    folder=QA/'closed_v16_prior_consumer_v1'
    manifest,manifest_pin=pinned_document(folder/'SOURCE.json')
    closed,closed_pin=pinned_document(folder/'CLOSED_V16_PRIOR_CONSUMER_PRELIMINARY_REVIEW_V1.json')
    require(closed['independent'] is True and closed['source_review_passed'] is True
            and closed['static_api_closure_passed'] is True and closed['approved_stages']==[]
            and closed['source_manifest_pin']==manifest_pin
            and closed['candidate_pin']==manifest['candidate']==file_pin(ROOT/'tools/campaign_file_fault_prior_v5.py'), 'Exact closed V16 consumer preliminary admission')
    background,background_pin=pinned_document(manifest['background_source']['path'])
    require(background_pin==manifest['background_source'], 'Original background source metadata bytes')
    rows=[*current['pins'],*current['inputs']['metadata_and_predecessor_reviews'],*current['inputs']['runtime_and_harness_overlays'],
          basis_pin,review_pin,manifest_pin,closed_pin,file_pin(folder/'README.md'),file_pin(Path(__file__)),
          *closed['source_pins'].values(),*background['pins'].values()]
    pins={}
    for original in rows:
        row={k:original[k] for k in ['path','bytes','sha256']}
        verify_pin(row)
        require(row['path'] not in pins or pins[row['path']]==row, 'Conflicting original source pin')
        pins[row['path']]=row
    return {'current':current,'inputs':json.loads(json.dumps(current['inputs'])), 'pins':pins,
            'durable_basis_source_spec_file':basis_pin,'durable_basis_independent_review':review_pin,
            'durable_basis_logical_sha256':saved['source_spec_sha256'], 'prior_closed_checked':False}

def collect_sources(basis, extra):
    pins=dict(basis['pins'])
    pending=[Path(row['path']) for row in pins.values() if Path(row['path']).suffix=='.py']+[Path(p) for p in extra]
    checked=set();edges=set()
    while pending:
        path=pending.pop();row=file_pin(path)
        require(row['path'] not in pins or pins[row['path']]==row, 'Source pin rebaseline refused')
        pins[row['path']]=row
        if path.suffix!='.py' or row['path'] in checked:continue
        checked.add(row['path'])
        for node in ast.walk(ast.parse(path.read_bytes(),filename=str(path))):
            modules=[node.module] if isinstance(node,ast.ImportFrom) else [item.name for item in node.names] if isinstance(node,ast.Import) else []
            for module in modules:
                if module:
                    dependency=ROOT/'tools'/(module.split('.')[0]+'.py')
                    if dependency.is_file():edges.add((path.name,dependency.name));pending.append(dependency)
    for row in pins.values():verify_pin(row)
    return sorted(pins.values(),key=lambda row:row['path']),sorted([list(edge) for edge in edges])
