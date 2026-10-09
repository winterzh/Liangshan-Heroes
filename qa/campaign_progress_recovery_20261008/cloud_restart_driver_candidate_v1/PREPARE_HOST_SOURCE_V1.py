"""Preserve exact new consumer bytes and direct local import sources only."""
from pathlib import Path
import ast
import hashlib
import json

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent


def pin(path):
    raw = path.read_bytes()
    return {'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}


def main():
    source = ROOT/'tools/campaign_cloud_restart_evidence_v1.py'
    raw = source.read_bytes()
    tree = ast.parse(raw,filename=str(source))
    snapshot = HERE/'campaign_cloud_restart_evidence_v1_source_snapshot.py'
    with snapshot.open('xb') as out:out.write(raw)
    assert snapshot.read_bytes() == raw
    paths = {source,snapshot,Path(__file__),HERE/'SOURCE.json',HERE/'COMPLETE_LABEL_CONTRACT_V1.json',HERE/'REVIEW_SCOPE_V1.md'}
    edges = []
    for node in ast.walk(tree):
        if isinstance(node,ast.ImportFrom) and node.level == 0 and node.module:
            target = ROOT/'tools'/(node.module.split('.')[0]+'.py')
            if target.is_file():
                ast.parse(target.read_bytes(),filename=str(target))
                paths.add(target)
                edges.append({'source':str(source),'module':node.module,'target':str(target)})
    value = {'schema':'cloud_restart_host_direct_source_v1','consumer':pin(source),'snapshot':pin(snapshot),
             'pins':[pin(path) for path in sorted(paths)],'direct_local_import_edges':edges,
             'recursive_import_closure_sealed':False,'Python_AST_parsed':True,'GD_parsed':False,
             'consumer_constructed':False,'consumer_validate_executed':False,'native_started':False,
             'complete_producer_implemented':False,'successful_prior_bound':False,
             'original19_qualified':False,'overall_goal_qualified':False,'approved_stages':[]}
    with (HERE/'HOST_SOURCE.json').open('x',encoding='utf-8',newline='\n') as out:
        json.dump(value,out,ensure_ascii=False,indent=2)
        out.write('\n')
    print(json.dumps({'source_only':True,'direct_local_import_edges':len(edges),'native_started':False}))


if __name__ == '__main__':main()
