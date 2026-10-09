"""Pin host arm/owned cloud phase source closure only; no native admission."""
from pathlib import Path
import ast
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]
QA = Path(__file__).parent
TOOLS = ['campaign_cloud_arm_packets_v1.py','campaign_cloud_arm_controller_v1.py',
         'campaign_cloud_arm_raw_receiver_v1.py','campaign_cloud_applying_exports_v1.py','campaign_cloud_applying_runtime_v1.py']


def pin(path):
    raw = path.read_bytes()
    return {'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}


def main():
    prior = QA/'NATURAL_CALLBACK_PRODUCER_SOURCE_RECIPE_V1.json'
    recipe = json.loads(prior.read_bytes())['recipe']
    pins = {row['path']:row for row in recipe['pins']}
    def adopt(path):
        row = pin(path)
        assert row['path'] not in pins or row == pins[row['path']], 'Source drift/rebaseline refused'
        pins[row['path']] = row
    for name in TOOLS:
        source = ROOT/'tools'/name
        snapshot = QA/(Path(name).stem+'_source_snapshot.py')
        with snapshot.open('xb') as out:
            out.write(source.read_bytes())
        adopt(source)
        adopt(snapshot)
    cloud = QA/'cloud_applying_driver_candidate_v2'
    manifest = json.loads((cloud/'SOURCE.json').read_bytes())
    for key in ['candidate','parent_GD','observer_GD','observer_parent_GD','previous_source','previous_chain_review',
                'previous_observation_rejection','source_map','recipe_basis']:
        row = manifest[key]
        assert pin(Path(row['path'])) == row
        adopt(Path(row['path']))
    for row in manifest['production_runtime_sources']:
        assert pin(Path(row['path'])) == {k:row[k] for k in ['path','bytes','sha256']}
        adopt(Path(row['path']))
    extra = [Path(__file__), prior, QA/'NATURAL_CALLBACK_PRODUCER_PRELIMINARY_REVIEW_V1.json',
             cloud/'SOURCE.json',cloud/'COMPLETE_LABEL_CONTRACT_V2.json',cloud/'PREPARE_SOURCE_V2.py',
             cloud/'CLOUD_APPLYING_DRIVER_PRELIMINARY_REVIEW_V2.json',cloud/'REVIEW_SCOPE.md']
    extra += [QA/name for name in ['CLOUD_ARM_HOST_CHECKS_V1.py','CLOUD_ARM_HOST_CHECKS_V1.json',
                                  'CLOUD_ARM_HOST_CHECKS_V2.py','CLOUD_ARM_HOST_CHECKS_V2.json',
                                  'CLOUD_ARM_HOST_CHECKS_V2_INITIAL_FIXTURE.py','CLOUD_ARM_INITIAL_FIXTURE_FAILURE_OBSERVATION_V1.json']]
    for path in extra:
        adopt(path)
    checked = set()
    edges = []
    while True:
        pending = [Path(row['path']) for row in pins.values() if row['path'].endswith('.py') and row['path'] not in checked]
        if not pending:
            break
        for path in pending:
            checked.add(str(path))
            for node in ast.walk(ast.parse(path.read_bytes(),filename=str(path))):
                modules = [node.module] if isinstance(node,ast.ImportFrom) and node.level == 0 else [v.name for v in node.names] if isinstance(node,ast.Import) else []
                for module in modules:
                    if not module:
                        continue
                    target = ROOT/'tools'/(module.split('.')[0]+'.py')
                    if target.is_file():
                        edges.append({'source':str(path),'module':module,'target':str(target)})
                        adopt(target)
    for row in pins.values():
        assert pin(Path(row['path'])) == row
    result = {'schema':'cloud_arm_host_owned_phase_source_spec_v1','pins':sorted(pins.values(),key=lambda v:v['path']),
              'all_pinned_local_import_edges':edges,'root_tools':TOOLS,
              'scope':'strict arm decoder, actual-owned controller, original raw receiver, three exports and integrated cloud applying phase',
              'source_only':True,'native_started':False,'actual_Popen_or_socket_constructed':False,
              'breakpoint_installation_verified':False,'complete_report_packet_CFG_consumer_implemented':False,
              'cloud_restart_implemented':False,'cloud_producer_implemented':False,
              'successful_prior_bound':False,'original19_qualified':False,'overall_goal_qualified':False,'approved_stages':[]}
    output = QA/'CLOUD_ARM_HOST_SOURCE_SPEC_V1.json'
    with output.open('x',encoding='utf-8',newline='\n') as out:
        json.dump(result,out,ensure_ascii=False,indent=2)
        out.write('\n')
    print(json.dumps({'pins':len(pins),'all_AST_local_import_edges':len(edges),'source_sha256':pin(output)['sha256'],'native_started':False}))


if __name__ == '__main__':
    main()
