"""Seal raw native user-directory text successors; no native execution."""
from pathlib import Path
import ast
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]
QA = Path(__file__).parent
NAMES = ['campaign_cloud_cfg_semantics_v2.py','campaign_cloud_arm_packet_evidence_v2.py',
         'campaign_cloud_apply_first_evidence_v4.py','campaign_cloud_applying_runtime_v5.py']


def pin(path):
    raw = path.read_bytes()
    return {'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}


def main():
    previous = QA/'CLOUD_CFG_SEMANTICS_SOURCE_SPEC_V1.json'
    old = json.loads(previous.read_bytes())
    pins = {row['path']:row for row in old['pins']}
    def adopt(path):
        row = pin(path)
        assert row['path'] not in pins or row == pins[row['path']], 'Original source rebaseline refused'
        pins[row['path']] = row
    for row in pins.values():assert pin(Path(row['path'])) == row
    for name in NAMES:
        source = ROOT/'tools'/name
        snapshot = QA/(Path(name).stem+'_source_snapshot.py')
        with snapshot.open('xb') as out:out.write(source.read_bytes())
        adopt(source)
        adopt(snapshot)
    for path in [Path(__file__),previous,QA/'CLOUD_CFG_SEMANTICS_PRELIMINARY_REVIEW_V1.json',
                 QA/'CLOUD_NATIVE_USER_TEXT_REJECTION_V1.json',QA/'CLOUD_NATIVE_USER_TEXT_HOST_CHECKS_V1.py',
                 QA/'CLOUD_NATIVE_USER_TEXT_HOST_CHECKS_V1.json',QA/'CLOUD_NATIVE_USER_TEXT_HOST_CHECKS_INITIAL_V1.py',
                 QA/'CLOUD_NATIVE_USER_TEXT_INITIAL_FIXTURE_FAILURE_V1.json',
                 QA/'actual_durable_chain_v12_r4_lu_a/report.json',QA/'ACTUAL_FOREIGN_INTERRUPTION_FULL_V12_R4.json']:
        adopt(path)
    checked = set()
    edges = []
    while True:
        pending = [Path(row['path']) for row in pins.values() if row['path'].endswith('.py') and row['path'] not in checked]
        if not pending:break
        for path in pending:
            checked.add(str(path))
            for node in ast.walk(ast.parse(path.read_bytes(),filename=str(path))):
                modules = [node.module] if isinstance(node,ast.ImportFrom) and node.level == 0 else [v.name for v in node.names] if isinstance(node,ast.Import) else []
                for module in modules:
                    if not module:continue
                    target = ROOT/'tools'/(module.split('.')[0]+'.py')
                    if target.is_file():
                        edges.append({'source':str(path),'module':module,'target':str(target)})
                        adopt(target)
    result = {'schema':'cloud_original_native_user_text_source_spec_v1','pins':sorted(pins.values(),key=lambda v:v['path']),
              'all_pinned_local_import_edges':edges,'root_tools':NAMES,'source_only':True,
              'correction':'CLOUD-NATIVE-USER-TEXT-001: original raw native user text for protocol equality; separate Path for private physical boundaries',
              'native_started':False,'actual_Godot_CFG_semantics_executed':False,'actual_first_consumer_executed':False,
              'ordinary_cloud_restart_implemented':False,'complete_cloud_producer_implemented':False,'successful_prior_bound':False,
              'representation_evidence_only_from_Lu_A':True,'failed_full_prior_promoted':False,
              'original19_qualified':False,'overall_goal_qualified':False,'approved_stages':[]}
    output = QA/'CLOUD_NATIVE_USER_TEXT_SOURCE_SPEC_V1.json'
    with output.open('x',encoding='utf-8',newline='\n') as out:
        json.dump(result,out,ensure_ascii=False,indent=2)
        out.write('\n')
    print(json.dumps({'pins':len(pins),'all_AST_edges':len(edges),'sha256':pin(output)['sha256'],'native_started':False}))


if __name__ == '__main__':main()
