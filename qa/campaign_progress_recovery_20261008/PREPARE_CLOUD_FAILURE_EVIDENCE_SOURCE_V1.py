"""Source closure for a failure-boundary consumer; never executes a phase."""
import ast
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
QA = Path(__file__).parent
sys.path.insert(0,str(ROOT/'tools'))
sys.dont_write_bytecode = True
from run_durable_campaign_chain_v12 import canonical, verify_pin

def pin(path):
    raw = path.read_bytes()
    return {'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}

def main():
    candidate = QA/'cloud_write_failure_candidate_v2'
    manifest = json.loads((candidate/'SOURCE.json').read_bytes())
    preparation = json.loads((candidate/'PREPARATION_V2.json').read_bytes())
    assert canonical(manifest) == preparation['source_logical_sha256']
    review = candidate/'INDEPENDENT_SOURCE_REVIEW_V2.json'
    assert pin(review)['sha256'] == '04114d740d283ebcdd136620c51eaa00392578ba17abc074f88af27a778cee55'
    pins = {row['path']:row for row in manifest['pins']}
    module = ROOT/'tools/campaign_cloud_failure_evidence_v1.py'
    for path in [module,Path(__file__),candidate/'SOURCE.json',candidate/'LOCAL_BOUNDARY_LABEL_CONTRACT_V2.json',review,
                 QA/'CLOUD_FAILURE_EVIDENCE_DATA_CHECKS_V1.py',QA/'CLOUD_FAILURE_EVIDENCE_DATA_CHECKS_V1.json',
                 QA/'CLOUD_FAILURE_EVIDENCE_DATA_CHECKS_V1_INITIAL_FIXTURE.py',QA/'CLOUD_FAILURE_EVIDENCE_INITIAL_FIXTURE_FAILURE_V1.json']:
        row = pin(path);assert row['path'] not in pins or pins[row['path']] == row;pins[row['path']] = row
    checked,edges = set(),[]
    while True:
        pending = [Path(row['path']) for row in pins.values() if row['path'].endswith('.py') and row['path'] not in checked]
        if not pending:break
        for path in pending:
            checked.add(str(path))
            tree = ast.parse(path.read_bytes(),filename=str(path))
            for node in ast.walk(tree):
                modules = [node.module] if isinstance(node,ast.ImportFrom) and node.level == 0 else [v.name for v in node.names] if isinstance(node,ast.Import) else []
                for name in modules:
                    if not name:continue
                    dependency = ROOT/'tools'/(name.split('.')[0]+'.py')
                    if dependency.is_file():
                        edges.append({'source':str(path),'module':name,'target':str(dependency)})
                        row = pin(dependency);assert row['path'] not in pins or pins[row['path']] == row;pins[row['path']] = row
    for row in pins.values():verify_pin(row)
    source = {'schema':'cloud_failure_evidence_source_v1','helper':pin(module),'builder':pin(Path(__file__)),
              'candidate_manifest':pin(candidate/'SOURCE.json'),'candidate_review':pin(review),
              'label_contract':pin(candidate/'LOCAL_BOUNDARY_LABEL_CONTRACT_V2.json'),
              'pins':sorted(pins.values(),key=lambda row:row['path']),'Python_import_edges':edges,
              'consumer_implemented':True,'consumer_constructed_or_validate_called':False,
              'inherited_fixed_report_publisher_only':True,'host_phase_wrapper_implemented':False,
              'complete_producer_implemented':False,'successful_all61_prior_available':False,
              'authorized_account_retry_implemented':False,'same_profile_restart_implemented':False,
              'native_started':False,'original19_qualified':False,'UI_qualified':False,'SDK_qualified':False,
              'overall_goal_qualified':False,'approved_stages':[]}
    record = {'source_spec_sha256':canonical(source),'spec':source}
    destination = QA/'CLOUD_FAILURE_EVIDENCE_SOURCE_SPEC_V1.json'
    with destination.open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(record,stream,ensure_ascii=False,indent=2);stream.write('\n')
    snapshot = QA/'campaign_cloud_failure_evidence_v1_source_snapshot.py'
    with snapshot.open('xb') as stream:stream.write(module.read_bytes())
    assert snapshot.read_bytes() == module.read_bytes()
    print(json.dumps({'source_pins':len(pins),'all_pinned_import_edges':len(edges),
                      'source_spec_sha256':record['source_spec_sha256'],'native_started':False}))

if __name__ == '__main__':main()
