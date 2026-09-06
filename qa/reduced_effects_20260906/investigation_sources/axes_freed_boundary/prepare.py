"""Draft-only extraction. No Git/Godot and no production writes."""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
FROZEN = ROOT / 'scratchpad/physics_step_diag/frozen/battle_original.bin'
BATTLE_SHA = '784373eede18a82c24fc50a6e36a42b6c20516bf439cf200fe5be7d239db6e2c'
CLASS_SHA = '21cc35423a6485dd4271e8da05161552add4d938b501531fe06c2ed0e162de3f'
METHOD_SHA = {'resolve_hits': 'cc223b271a08adf2880493cf97521bf4c8d3a51659901843de2954e4a1d3b66a',
              '_draw': 'cfcc76f4a31056de0eb02ac7b92e056c809c3548e9340bde25c492f455d322e8'}
OLD = '\t\t\tvar target: Unit = hit.get("target")\n'
NEW = '\t\t\tvar target_value: Variant = hit.get("target")\n\t\t\tif not is_instance_valid(target_value):\n\t\t\t\tcontinue\n\t\t\tvar target: Unit = target_value\n'


def sha(raw): return hashlib.sha256(raw).hexdigest()
def need(ok, message):
    if not ok: raise RuntimeError(message)


def extract(raw):
    text = raw.replace(b'\r\n', b'\n').decode('utf-8')
    lines = text.splitlines(keepends=True)
    hits = [i for i, line in enumerate(lines) if line == 'class LiBrawnAxesFx extends Node2D:\n']
    need(len(hits) == 1, 'Expected one exact LiBrawnAxesFx class')
    start = hits[0]; end = start + 1
    while end < len(lines) and (lines[end].startswith('\t') or not lines[end].strip()): end += 1
    return ''.join(lines[start:end])


def method(text, name):
    hit = re.search(r'^\tfunc ' + re.escape(name) + r'\(', text, re.M)
    need(hit is not None, 'Missing method ' + name)
    next_method = re.search(r'^\tfunc ', text[hit.end():], re.M)
    end = hit.end() + next_method.start() if next_method else len(text)
    return text[hit.start():end]


def standalone(text):
    lines = text.splitlines(keepends=True)
    need(lines[0] == 'class LiBrawnAxesFx extends Node2D:\n', 'Unexpected class header')
    result = 'extends Node2D\n' + ''.join(line[1:] if line.startswith('\t') else line for line in lines[1:])
    reverse = 'class LiBrawnAxesFx extends Node2D:\n' + ''.join('\t' + line if line.strip() else line for line in result.splitlines(keepends=True)[1:])
    need(reverse == text, 'Dedent inverse did not reproduce class bytes')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate-battle', type=Path, help='Optional read-only check of root-applied production candidate class')
    args = parser.parse_args()
    raw = FROZEN.read_bytes().replace(b'\r\n', b'\n')
    need(sha(raw) == BATTLE_SHA, 'Frozen Battle digest mismatch')
    original = extract(raw)
    need(sha(original.encode()) == CLASS_SHA, 'Original class digest mismatch')
    for name, digest in METHOD_SHA.items(): need(sha(method(original, name).encode()) == digest, 'Original method digest mismatch: ' + name)
    need(original.count(OLD) == 2, 'Expected exactly two unsafe typed assignments')
    fixed = original.replace(OLD, NEW)
    need(fixed.replace(NEW, OLD) == original, 'Fix inverse mismatch')
    candidate_source = 'mechanical two-declaration fix from frozen original; production not modified'
    if args.candidate_battle:
        candidate = extract(args.candidate_battle.read_bytes())
        need(candidate == fixed, 'Applied candidate class differs from exactly the two prepared fixes; review/rebase explicitly')
        candidate_source = str(args.candidate_battle.resolve())
    generated = HERE / 'generated'; generated.mkdir(exist_ok=True)
    modes = {}
    for mode, text in [('original', original), ('fixed', fixed)]:
        output = standalone(text).encode('utf-8')
        path = generated / (mode + '_effect.gd.txt'); path.write_bytes(output)
        modes[mode] = {'class_lf_sha256': sha(text.encode()), 'standalone_sha256': sha(output),
                       'methods_lf_sha256': {name: sha(method(text, name).encode()) for name in METHOD_SHA},
                       'resource': 'res://scratchpad/axes_freed_boundary/generated/' + path.name}
    pins = {'schema': 1, 'frozen_battle_lf_sha256': BATTLE_SHA, 'modes': modes,
            'original_extraction_only': ['top-level extends Node2D', 'remove one indentation level'],
            'fixed_changes': 'exactly two declarations guarded as Variant before typed Unit; existing conditions retained',
            'candidate_source': candidate_source, 'production_modified': False, 'godot_run': False,
            'original_mode_must_be_reported_as_failure': True}
    (generated / 'pins.json').write_bytes((json.dumps(pins, ensure_ascii=False, indent=2) + '\n').encode())
    ast.parse(Path(__file__).read_text(encoding='utf-8'))
    need('Unit = hit.get' not in standalone(fixed), 'Unsafe declaration remained')
    receipt = {'passed': True, 'checks': ['frozen full source hash', 'class hash', 'two method hashes',
                'exactly two guarded replacements', 'fix inverse', 'original/fixed dedent inverse', 'Python AST'],
               'engine_validation': 'not run', 'godot_run': False, 'git_run': False, 'production_writes': 0}
    (HERE / 'preparation_receipt.json').write_bytes((json.dumps(receipt, indent=2) + '\n').encode())
    print(json.dumps({'prepared': str(generated), 'godot_run': False, 'modes': modes}, ensure_ascii=True))


if __name__ == '__main__': main()
