"""Read-only independent artifact verification; no Godot/Git/source imports."""
from pathlib import Path
import ast
import hashlib
import json
import re

root = Path(__file__).resolve().parent
manifest = json.loads((root / 'source_manifest.json').read_text(encoding='utf-8'))
checks = []

def check(name, passed):
    checks.append({'name': name, 'passed': bool(passed)})
    if not passed:
        raise AssertionError(name)

def digest(data):
    return hashlib.sha256(data).hexdigest()

def apply_unified(source, patch):
    """Mechanically reconstruct candidate from archived source and explicit patch."""
    lines = source.splitlines(True)
    diff = patch.splitlines(True)
    out, cursor, i = [], 0, 2
    while i < len(diff):
        match = re.fullmatch(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@.*\n', diff[i])
        if not match:
            raise AssertionError('bad unified hunk')
        start = int(match[1]) - 1
        check('patch hunk in order', start >= cursor)
        out.extend(lines[cursor:start]); cursor = start
        old, new = 0, 0
        i += 1
        while i < len(diff) and not diff[i].startswith('@@ '):
            prefix, body = diff[i][0], diff[i][1:]
            if prefix in ' -':
                check('patch old/context line exact', cursor < len(lines) and lines[cursor] == body)
                cursor += 1; old += 1
            if prefix in ' +':
                out.append(body); new += 1
            if prefix not in ' +-':
                raise AssertionError('unsupported patch line')
            i += 1
        check('patch old line count', old == int(match[2] or 1))
        check('patch new line count', new == int(match[4] or 1))
    out.extend(lines[cursor:])
    return ''.join(out)

for row in manifest['sources']:
    snapshot = (root / row['snapshot']).read_bytes()
    check('source snapshot bytes/SHA: ' + row['path'], len(snapshot) == row['bytes'] and digest(snapshot) == row['sha256'])
    check('current selected source unchanged: ' + row['path'], Path(manifest['source_root'], row['path']).read_bytes() == snapshot)
for row in manifest['candidates']:
    data = (root / row['path']).read_bytes()
    check('candidate bytes/SHA: ' + row['path'], len(data) == row['bytes'] and digest(data) == row['sha256'])
for name in ['run_scenery_state', 'run_map_state']:
    source = (root / f'source_snapshot/scripts/{name}.gd.txt').read_text(encoding='utf-8')
    patch = (root / f'{name}.patch').read_text(encoding='utf-8')
    candidate = (root / f'candidate/scripts/{name}.gd').read_text(encoding='utf-8')
    check('patch reconstructs exact candidate: ' + name, apply_unified(source, patch) == candidate)
    functions = re.findall(r'^func ([A-Za-z_][A-Za-z_0-9]*)\(', candidate, re.M)
    check('no duplicate top-level function: ' + name, len(functions) == len(set(functions)))
    check('no conflict markers: ' + name, not re.search(r'^(<<<<<<<|=======|>>>>>>>)', candidate, re.M))
for name in ['build_candidate.py', 'verify_bundle.py']:
    check('Python AST only: ' + name, ast.parse((root / name).read_text(encoding='utf-8')) is not None)
matrix = (root / 'TEST_MATRIX.md').read_text(encoding='utf-8')
ids = re.findall(r'^\| ([SN]\d{2}) \|', matrix, re.M)
check('28 separate unrun native cases', len(ids) == 28 and len(ids) == len(set(ids)) and '**NOT_RUN**' in matrix)
print(json.dumps({'status': 'CONSISTENT_STATIC_CANDIDATE', 'engine_parsed': False, 'godot_run': False, 'complete_world': False,
    'selected_source_files': len(manifest['sources']), 'candidate_files': len(manifest['candidates']),
    'native_cases_not_run': len(ids), 'checks': len(checks), 'failed_checks': [r for r in checks if not r['passed']]}, ensure_ascii=False, indent=2))
