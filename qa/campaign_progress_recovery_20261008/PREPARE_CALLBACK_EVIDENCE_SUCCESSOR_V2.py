"""Seal the finite ORDER-001 source correction; never starts native work."""
from pathlib import Path
import ast, hashlib, json

ROOT = Path(__file__).resolve().parents[2]
QA = Path(__file__).parent

def pin(path):
    raw = path.read_bytes()
    return {'path': str(path), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}

def imports(path):
    result = []
    for node in ast.walk(ast.parse(path.read_bytes(), filename=str(path))):
        modules = [node.module] if isinstance(node, ast.ImportFrom) and node.level == 0 else [v.name for v in node.names] if isinstance(node, ast.Import) else []
        for module in modules:
            if not module:
                continue
            target = ROOT / 'tools' / (module.split('.')[0] + '.py')
            if target.is_file():
                result.append({'source': str(path), 'module': module, 'target': str(target)})
    return result

def main():
    prior_path = QA / 'CALLBACK_EVIDENCE_SOURCE_SPEC_V1.json'
    prior = json.loads(prior_path.read_bytes())
    pins = {v['path']: v for v in prior['pins']}
    for old in pins.values():
        assert pin(Path(old['path'])) == old, 'Original V1 source changed'
    for name in ('campaign_callback_packet_evidence', 'campaign_natural_callback_evidence'):
        source = ROOT / 'tools' / (name + '_v2.py')
        snapshot = QA / (name + '_v2_source_snapshot.py')
        with snapshot.open('xb') as out:
            out.write(source.read_bytes())
        pins[str(source)] = pin(source)
        pins[str(snapshot)] = pin(snapshot)
    def class_body(path):
        return [ast.dump(n, include_attributes=False) for n in ast.parse(path.read_bytes()).body if isinstance(n, ast.ClassDef)]
    assert class_body(ROOT/'tools/campaign_natural_callback_evidence_v1.py') == class_body(ROOT/'tools/campaign_natural_callback_evidence_v2.py')
    for name in ('CALLBACK_EVIDENCE_SOURCE_SPEC_V1.json', 'CALLBACK_EVIDENCE_PRELIMINARY_REVIEW_V1.json', 'CALLBACK_EVIDENCE_ORDER_REGRESSION_V2.py', 'CALLBACK_EVIDENCE_ORDER_REGRESSION_V2.json', Path(__file__).name):
        path = QA / name
        pins[str(path)] = pin(path)
    while True:
        additions = {}
        for value in list(pins.values()):
            path = Path(value['path'])
            if path.suffix == '.py':
                for edge in imports(path):
                    if edge['target'] not in pins:
                        additions[edge['target']] = pin(Path(edge['target']))
        if not additions:
            break
        pins.update(additions)
    edges = [edge for v in sorted(pins.values(), key=lambda x:x['path']) if Path(v['path']).suffix == '.py' for edge in imports(Path(v['path']))]
    successor = dict(prior)
    successor.update(schema='campaign_natural_callback_evidence_source_spec_v2', pins=sorted(pins.values(), key=lambda x:x['path']), all_pinned_local_imports=edges,
                     root_local_imports=prior['root_local_imports']+[edge for name in ('campaign_callback_packet_evidence_v2.py','campaign_natural_callback_evidence_v2.py') for edge in imports(ROOT/'tools'/name)],
                     correction='CALLBACK-PACKET-ORDER-001: refused original prefix precedes tail and must enter reconstruction byte-exact',
                     complete_consumer_pipeline_qualified=False, approved_stages=[])
    destination = QA/'CALLBACK_EVIDENCE_SOURCE_SPEC_V2.json'
    with destination.open('x', encoding='utf-8', newline='\n') as out:
        json.dump(successor, out, ensure_ascii=False, indent=2)
        out.write('\n')
    print(json.dumps({'pins':len(pins),'all_local_import_edges':len(edges),'sha256':pin(destination)['sha256'],'native_started':False}))

if __name__ == '__main__':
    main()
