"""Build the runtime catalogue from reviewed translation shards.

Build dependency: opencc-python-reimplemented==0.1.7 (runtime has no Python dependency).
"""
from pathlib import Path
import argparse
import json
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--opencc-path', type=Path)
    parser.add_argument('--ui-source', type=Path)
    parser.add_argument('--ui-translations', type=Path)
    parser.add_argument('--report', type=Path)
    parser.add_argument('--strict', action='store_true')
    args = parser.parse_args()
    if args.opencc_path:
        sys.path.insert(0, str(args.opencc_path.resolve()))
    from opencc import OpenCC
    folder = ROOT / 'assets/localization'
    if args.ui_source and args.ui_translations:
        sources = json.loads(args.ui_source.read_text(encoding='utf-8'))
        ui = {}
        for line in args.ui_translations.read_text(encoding='utf-8').splitlines():
            if not line.strip():
                continue
            index, en, ja = line.split('|', 2)
            source = sources[int(index)]
            if source in ui:
                raise ValueError('Duplicate UI translation: ' + source)
            ui[source] = {'en': en.replace('\\n', '\n'), 'ja': ja.replace('\\n', '\n')}
        (folder/'ui.json').write_text(json.dumps(ui, ensure_ascii=False, indent=2)+'\n', encoding='utf-8', newline='\n')
    merged, conflicts, counts = {}, [], {}
    for path in sorted(folder.glob('*.json')):
        if path.name in ('catalog.json', 'exclusions.json', 'glossary.json'):
            continue
        data = json.loads(path.read_text(encoding='utf-8'))
        counts[path.name] = len(data)
        for source, entry in data.items():
            if source in merged and merged[source] != entry:
                conflicts.append({'source': source, 'winner': path.name,
                                  'before': merged[source], 'after': entry})
            merged[source] = entry
    converter = OpenCC('s2twp')
    glossary = json.loads((folder/'glossary.json').read_text(encoding='utf-8'))
    merged.update(glossary)
    unresolved = [c for c in conflicts if c['source'] not in glossary]
    if args.strict and unresolved:
        raise ValueError('Unresolved conflicting translations: ' + ', '.join(c['source'] for c in unresolved))
    for source, entry in merged.items():
        entry['zh_TW'] = converter.convert(source)
    (folder/'catalog.json').write_text(json.dumps(merged, ensure_ascii=False, indent=2)+'\n', encoding='utf-8', newline='\n')
    report = {'entries': len(merged), 'shards': counts, 'conflicts': conflicts,
              'glossary_resolved': len(conflicts) - len(unresolved), 'unresolved': unresolved}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'entries': len(merged), 'shards': counts, 'conflicts': len(conflicts)}))


if __name__ == '__main__':
    main()
