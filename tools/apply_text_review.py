"""Apply reviewed source/translation corrections by exact GDScript string tokens.

Default is read-only. Run --apply after the two 54-person audits and story review
are complete, then rebuild and validate the runtime localization catalogue.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re

from localization_catalog import strings, FORMAT

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/text_review_20260908'


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode('utf-8')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    changes = []
    audits = []
    for part in ('first54', 'last54'):
        rows = read_json(QA / ('lore_' + part + '_changes.json'))
        audited = read_json(QA / ('lore_' + part + '_audit.json'))
        assert len(audited) == 54, (part, 'incomplete audit', len(audited))
        for row in rows:
            row['files'] = ['scripts/lore_data.gd']
        changes.extend(rows)
        audits.extend(audited)
    changes.extend(read_json(QA / 'story_changes.json'))
    assert len({row['key'] for row in audits}) == 108
    assert all((row.get('checked') or row.get('status') == 'verified_revised') and row.get('chapters') for row in audits)
    replacements = {}
    translations = {}
    for row in changes:
        old, new = row['old_source'], row['source']
        assert old and new and row['en'].strip() and row['ja'].strip()
        for language in ('en', 'ja'):
            assert FORMAT.findall(new) == FORMAT.findall(row[language]), (old[:40], language, 'placeholders')
            assert new.count('\n') == row[language].count('\n'), (old[:40], language, 'newlines')
            assert re.findall(r'\{\w+\}', new) == re.findall(r'\{\w+\}', row[language])
        target = {'en': row['en'], 'ja': row['ja']}
        assert new not in translations or translations[new] == target, ('conflicting new translation', new[:50])
        translations[new] = target
        for filename in row['files']:
            path = (ROOT / filename).resolve()
            assert path.is_relative_to(ROOT / 'scripts') and path.suffix == '.gd'
            per_file = replacements.setdefault(path, {})
            assert old not in per_file or per_file[old] == new, ('conflicting replacement', old[:50])
            per_file[old] = new
    planned = {}
    occurrence_count = 0
    for path, replace in replacements.items():
        code = path.read_bytes().decode('utf-8-sig')
        tokens = list(strings(code))
        present = {value for _, _, value in tokens}
        for old, new in replace.items():
            assert old in present or new in present, (path.name, 'source drift', old[:80])
        for start, end, value in reversed(tokens):
            if value in replace:
                code = code[:start] + json.dumps(replace[value], ensure_ascii=False) + code[end:]
                occurrence_count += 1
        planned[path] = code.encode('utf-8')
    lore_path = ROOT / 'scripts/lore_data.gd'
    lore = planned.get(lore_path, lore_path.read_bytes()).decode('utf-8')
    chapter_map = {row['key']: sorted(set(row['chapters'])) for row in audits}
    assert all(isinstance(c, int) and 1 <= c <= 120 for row in chapter_map.values() for c in row)
    lore, count = re.subn(r'^const CHAPTERS := .*$', 'const CHAPTERS := ' + json.dumps(chapter_map, ensure_ascii=False), lore, count=1, flags=re.M)
    assert count == 1
    planned[lore_path] = lore.encode('utf-8')
    current_sources = set()
    for path in (ROOT / 'scripts').rglob('*.gd'):
        code = planned.get(path, path.read_bytes()).decode('utf-8-sig')
        current_sources.update(value for _, _, value in strings(code))
    migrated = set()
    folder = ROOT / 'assets/localization'
    for path in sorted(folder.glob('*.json')):
        if path.name in ('catalog.json', 'exclusions.json'):
            continue
        data = read_json(path)
        original = dict(data)
        for row in changes:
            old, new = row['old_source'], row['source']
            if old in data:
                if old not in current_sources and old != new:
                    del data[old]
                data[new] = translations[new]
                migrated.add(new)
            elif new in data:
                data[new] = translations[new]
                migrated.add(new)
        if data != original:
            planned[path] = json_bytes(data)
    if missing := translations.keys() - migrated:
        path = folder / 'text_review_content.json'
        data = json.loads(planned[path].decode('utf-8-sig')) if path in planned else (read_json(path) if path.exists() else {})
        data.update({source: translations[source] for source in sorted(missing)})
        planned[path] = json_bytes(data)
    written = []
    for path, payload in planned.items():
        if path.exists() and path.read_bytes() == payload:
            continue
        written.append({'path': path.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(payload).hexdigest(), 'bytes': len(payload)})
        if args.apply:
            path.write_bytes(payload)
    receipt = {'applied': args.apply, 'audited_biographies': len(audits), 'review_rows': len(changes), 'source_occurrences': occurrence_count, 'files': written}
    if args.apply:
        (QA / 'application_receipt.json').write_bytes(json_bytes(receipt))
    print(json.dumps(receipt, ensure_ascii=False))


if __name__ == '__main__':
    main()
