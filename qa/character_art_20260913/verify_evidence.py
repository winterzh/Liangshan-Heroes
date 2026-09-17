"""Verify the frozen character-art receipt against this checkout and archive."""
from pathlib import Path
import argparse
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
QA = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', required=True, help='Archived native run directory name')
    args = parser.parse_args()
    run = (QA / 'native' / args.run).resolve()
    if run.parent != (QA / 'native').resolve():
        raise ValueError('Expected one archived run name')
    receipt = json.loads((run / 'receipt.json').read_text(encoding='utf-8'))
    errors = []

    def require(condition, message):
        if not condition:
            errors.append(message)

    require(receipt.get('complete') is True, 'native receipt incomplete')
    require(receipt.get('visual') is True, 'native renders required')
    for key in ('source_changes', 'private_source_changes', 'engines_remaining'):
        require(not receipt.get(key), key)
    for key in ('lock_released', 'runtime_inventory_unchanged', 'qa_unchanged', 'driver_unchanged', 'godot_unchanged'):
        require(receipt.get(key) is True, key)
    require(not (ROOT / '.godot/redraw_rejection_source.lock').exists(), 'current shared lock busy')
    for row in receipt['source_files']:
        path = ROOT / row['path']
        require(path.is_file() and sha(path) == row['sha256'], 'source drift: ' + row['path'])
    for row in receipt['artifacts']:
        path = run / row['path']
        require(path.is_file() and sha(path) == row['sha256'], 'archive drift: ' + row['path'])
    require(sha(ROOT / 'tools/art_character_direction4_qa.gd') == receipt['qa_sha256'], 'QA script drift')
    require(sha(ROOT / 'tools/run_character_art_qa.py') == receipt['driver_sha256'], 'driver drift')
    reports = {}
    for character, count in [('sun_li', 380), ('hu_sanniang', 259)]:
        report = json.loads((run / character / 'report.json').read_text(encoding='utf-8'))
        require(report.get('passed') is True and not report.get('failures'), character + ' failed')
        require(len(report.get('resources', [])) == 20, character + ' resource matrix incomplete')
        source = json.loads((QA / 'static' / (character + '_sources_final.json')).read_text(encoding='utf-8'))
        require(source.get('passed') is True and len(source.get('checks', [])) == count, character + ' source audit failed')
        reports[character] = {'checks': report['checks'], 'screenshots': len(report['screenshots'])}
    routing = json.loads((run / 'routing/report.json').read_text(encoding='utf-8'))
    require(routing.get('passed') is True and not routing.get('failures'), 'shared routing failed')
    inventory = json.loads((run / 'inventory/inventory.json').read_text(encoding='utf-8'))
    require(isinstance(inventory.get('units'), list), 'inventory missing')
    summary = {'passed': not errors, 'errors': errors, 'native_run': args.run,
               'receipt_sha256': sha(run / 'receipt.json'),
               'source_files_verified': len(receipt['source_files']),
               'archive_files_verified': len(receipt['artifacts']),
               'fresh_import': receipt['fresh_import'], 'character_results': reports,
               'routing_checks': len(routing.get('checks', [])),
               'scope': 'Character art source, native commands, renders and routing only. Visual review scope is recorded separately in README.md.'}
    (QA / 'validation_summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps(summary, ensure_ascii=False))
    return 0 if not errors else 1


if __name__ == '__main__':
    sys.exit(main())
