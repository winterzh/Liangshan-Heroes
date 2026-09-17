"""Extract source strings and validate the four-language catalogue. No game writes."""
from __future__ import annotations

import argparse
import ast
import collections
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CJK = re.compile(r"[\u3400-\u9fff]")
FORMAT = re.compile(r"%(?:[-+0#]*\d*(?:\.\d+)?[sdifxXovc]|%)")


def strings(source: str):
    """GDScript quoted tokens, skipping comments; offsets support audited rewrites."""
    i = 0
    while i < len(source):
        c = source[i]
        if c == '#':
            end = source.find('\n', i)
            i = len(source) if end < 0 else end + 1
        elif c in "\"'":
            start = i
            quote = c * (3 if source.startswith(c * 3, i) else 1)
            i += len(quote)
            while i < len(source):
                if source[i] == '\\':
                    i += 2
                elif source.startswith(quote, i):
                    i += len(quote)
                    break
                else:
                    i += 1
            token = source[start:i]
            try:
                value = ast.literal_eval(token)
            except (ValueError, SyntaxError):
                value = token[len(quote):-len(quote)].replace('\\n', '\n').replace('\\t', '\t').replace('\\"', '"').replace("\\'", "'")
            yield start, i, value
        else:
            i += 1


def inventory():
    found = {}
    for file in sorted((ROOT / 'scripts').rglob('*.gd')):
        if file.name == 'localization.gd':
            continue
        code = file.read_text(encoding='utf-8-sig')
        for start, _, value in strings(code):
            if not CJK.search(value):
                continue
            found.setdefault(value, []).append({
                'file': file.relative_to(ROOT).as_posix(),
                'line': code.count('\n', 0, start) + 1,
            })
    return found


def validate(catalog, sources, exclusions=None):
    errors = []
    exclusions = exclusions or {}
    for source, entry in catalog.items():
        for locale in ('en', 'ja', 'zh_TW'):
            target = entry.get(locale)
            if not isinstance(target, str) or not target.strip():
                errors.append([source, locale, 'empty'])
                continue
            if FORMAT.findall(source) != FORMAT.findall(target):
                errors.append([source, locale, 'format placeholders', FORMAT.findall(source), FORMAT.findall(target)])
            if re.findall(r'\{[a-zA-Z_][a-zA-Z_0-9]*\}', source) != re.findall(r'\{[a-zA-Z_][a-zA-Z_0-9]*\}', target):
                errors.append([source, locale, 'named placeholders'])
            if source.count('\n') != target.count('\n'):
                errors.append([source, locale, 'newlines'])
    excluded = []
    for source, rule in exclusions.items():
        if source not in sources:
            errors.append([source, 'exclusion', 'source no longer exists'])
        elif set(x['file'] for x in sources[source]).issubset(set(rule['files'])) and rule.get('reason'):
            excluded.append(source)
        else:
            errors.append([source, 'exclusion', 'new occurrence requires review'])
    display = [s for s in sources if s not in excluded]
    missing = [s for s in display if s not in catalog]
    return {'source_unique': len(sources), 'catalog_entries': len(catalog),
            'excluded_count': len(excluded), 'display_source_count': len(display),
            'translated_display_sources': len(display) - len(missing),
            'missing_count': len(missing), 'missing': missing, 'errors': errors}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--inventory', type=Path)
    parser.add_argument('--validate', type=Path)
    parser.add_argument('--report', type=Path)
    parser.add_argument('--require-complete', action='store_true')
    args = parser.parse_args()
    sources = inventory()
    if args.inventory:
        args.inventory.parent.mkdir(parents=True, exist_ok=True)
        args.inventory.write_text(json.dumps(sources, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    if args.validate:
        exclusion_path = ROOT / 'assets/localization/exclusions.json'
        exclusions = json.loads(exclusion_path.read_text(encoding='utf-8')) if exclusion_path.exists() else {}
        result = validate(json.loads(args.validate.read_text(encoding='utf-8')), sources, exclusions)
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({k: v for k, v in result.items() if k not in ('missing', 'errors')}, ensure_ascii=False))
        print('validation_errors', len(result['errors']))
        return bool(result['errors'] or args.require_complete and result['missing_count'])
    print('unique', len(sources), 'characters', sum(len(s) for s in sources))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
