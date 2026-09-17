"""Keep recurring proper names consistent with the reviewed short-name glossary."""
from pathlib import Path
import argparse
import json
import re

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    folder = ROOT / 'assets/localization'
    shards = {path: json.loads(path.read_text(encoding='utf-8-sig')) for path in sorted(folder.glob('*.json')) if path.name not in ('catalog.json', 'exclusions.json')}
    merged = {}
    for path, data in shards.items():
        if path.name != 'glossary.json':
            merged.update(data)
    merged.update(shards[folder/'glossary.json'])
    code = (ROOT/'scripts/bios.gd').read_text(encoding='utf-8-sig').split('const STAR := {', 1)[1].split('\n}', 1)[0]
    names = [json.loads(line.rstrip().rstrip(','))[3] for line in re.findall(r': (\[\d+, [^\n]+\])', code)]
    assert len(names) == 108, 'Star roster extraction must include all 108 names'
    canonical = {name: merged[name]['ja'] for name in names if name in merged and name != merged[name]['ja']}
    changes = []
    for path, data in shards.items():
        touched = False
        for source, entry in data.items():
            old = dict(entry)
            if '聚义厅' in source:
                entry['en'] = entry['en'].replace('Gathering Hall', 'Hall of Brotherhood').replace('Assembly Hall', 'Hall of Brotherhood')
            for name, display in canonical.items():
                if name in source:
                    entry['ja'] = entry['ja'].replace(name, display)
            if old != entry:
                touched = True
                changes.append({'file': path.relative_to(ROOT).as_posix(), 'source': source, 'before': old, 'after': dict(entry)})
        if touched and args.apply:
            path.write_bytes((json.dumps(data, ensure_ascii=False, indent=2)+'\n').encode('utf-8'))
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_bytes((json.dumps({'applied': args.apply, 'count': len(changes), 'changes': changes}, ensure_ascii=False, indent=2)+'\n').encode('utf-8'))
    print(json.dumps({'applied': args.apply, 'count': len(changes)}))


if __name__ == '__main__':
    main()
