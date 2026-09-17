"""Prepare explicit nested spans for the unassigned Unit body remainder only."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import prepare_unit_remainder_diagnostic as base
import run_stabilization_performance as guard

BASELINE = ROOT / '.godot/stabilization_performance/20260907T053341Z_cd6e93a0'
METHODS = {key: list(value) for key, value in base.METHODS.items()}
METHODS['scripts/unit.gd'] += ['_gameplay_rng_fault', '_passive_regen', '_tick_ability_slots',
    '_queue_animated_redraw', '_queue_motion_redraw', '_request_redraw', '_spawn_dust', '_deal_hit']
METHODS['scripts/hero_inventory.gd'] = ['tick']
SPANS = [
    ('body.entry_building_dying', '\tif not _gameplay_rng_fault().is_empty(): return'),
    ('body.regen', '\t_cd = maxf(0.0, _cd - delta)'),
    ('body.ability_inventory', '\t# 技能冷却/充能（各槽）与临时增益计时'),
    ('body.timed_statuses', '\tif _temp_atk_t > 0.0:'),
    ('body.eject_target', '\t# 星际/红警式硬占位兜底：'),
    ('body.action_dispatch', '\t# 引导施法（凌振轰天连炮等）：'),
    ('body.animation_dust_hit', '\t# 动画状态推进：'),
    ('body.stuck_watchdog', '\t# 卡死看门狗：'),
]


def instrument_body(text):
    start = text.index('func _phys_body(')
    end = text.index('\nfunc ', start + 1) + 1
    original = text[start:end]
    guard.need('__bodydiag_' not in text and '\r' not in original, 'Unexpected body encoding or prior instrumentation')
    lines = original.splitlines(keepends=True)
    indices = []
    for _, marker in SPANS:
        found = [i for i, line in enumerate(lines) if line.startswith(marker)]
        # The first guard reappears later; the entry span is exactly the first body statement.
        if marker == SPANS[0][1]: found = found[:1]
        guard.need(len(found) == 1, 'Ambiguous inline marker: ' + marker)
        indices.append(found[0])
    guard.need(indices == sorted(set(indices)), 'Inline span order changed')
    transformed = ''.join(lines[:indices[0]]) + '\tvar __bodydiag_observer = Engine.get_meta("liangshan_unit_remainder_observer")\n'
    returns = []
    coverage = []
    for index, (scope, _) in enumerate(SPANS):
        token = '__bodydiag_token_' + str(index)
        stop = indices[index + 1] if index + 1 < len(indices) else len(lines)
        block = lines[indices[index]:stop]
        transformed += '\tvar ' + token + ': int = __bodydiag_observer.enter("' + scope + '")\n'
        return_count = 0
        for offset, line in enumerate(block):
            if re.match(r'^\s*#', line):
                transformed += line
                continue
            if line.strip() == '_dust = _dust.filter(func(d): return d.t > 0.0)':
                # This return belongs to the unchanged lambda, not _phys_body.
                transformed += line
                continue
            if re.search(r'\breturn\b', line):
                standalone = re.fullmatch(r'(\t+)return(?:\s*#[^\n]*)?\n', line)
                inline = re.fullmatch(r'(\t+)(if .+): return(?:\s*#[^\n]*)?\n', line)
                guard.need(standalone or inline, 'Unsupported return shape: ' + line)
                indent = (standalone or inline).group(1)
                if standalone:
                    transformed += indent + '__bodydiag_observer.leave(' + token + ')\n' + line
                else:
                    transformed += indent + inline.group(2) + ':\n' + indent + '\t__bodydiag_observer.leave(' + token + ')\n' + indent + '\treturn\n'
                returns.append({'scope': scope, 'original_function_line': indices[index] + offset + 1, 'original': line})
                return_count += 1
            else:
                transformed += line
        transformed += '\t__bodydiag_observer.leave(' + token + ')\n'
        coverage.append({'scope': scope, 'from_function_line': indices[index] + 1,
                         'to_function_line': stop, 'early_return_sites': return_count})
    # Every original executable line belongs to exactly one contiguous span. No
    # statements move across a boundary; only return-closing calls are inserted.
    guard.need(transformed.count('__bodydiag_observer.enter(') == len(SPANS), 'Span inventory mismatch')
    guard.need(sum(x['early_return_sites'] for x in coverage) == len(returns), 'Return coverage mismatch')
    return text[:start] + transformed + text[end:], [{'method': '_phys_body inline spans',
        'old': original, 'new': transformed, 'coverage': coverage, 'returns': returns}], [x[0] for x in SPANS]


def transform(raw, path):
    original = raw.decode('utf-8')
    text = original
    replacements, scopes = [], []
    if path == 'scripts/unit.gd':
        text, replacements, scopes = instrument_body(text)
    for method in METHODS[path]:
        pattern = re.compile(r'^func ' + re.escape(method) + r'\(([^\r\n]*)\)(?: -> ([^:\r\n]+))?:[^\r\n]*(?:\r?\n)', re.M)
        matches = list(pattern.finditer(text))
        guard.need(len(matches) == 1, 'Expected single synchronous method ' + method)
        match = matches[0]
        declaration = match.group(0)
        arguments = [x.strip().split(':', 1)[0].split('=', 1)[0].strip() for x in match.group(1).split(',') if x.strip()]
        guard.need(all(re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*', arg) for arg in arguments), 'Complex arguments require manual review')
        result_type = (match.group(2) or '').strip()
        guard.need(result_type in ('void', 'bool', 'float', 'Array', 'String'), 'Unsupported return type: ' + declaration)
        stop = text.find('\nfunc ', match.end())
        body = text[match.end():stop if stop >= 0 else len(text)]
        guard.need(not re.search(r'\bawait\b', body), 'Async function refused')
        scope = Path(path).stem + '.' + method
        scopes.append(scope)
        call = '__unitdiag_original_' + method + '(' + ', '.join(arguments) + ')'
        wrapper = declaration + '\tvar __unitdiag_observer = Engine.get_meta("liangshan_unit_remainder_observer")\n'
        wrapper += '\tvar __unitdiag_token: int = __unitdiag_observer.enter("' + scope + '")\n'
        if result_type == 'void':
            wrapper += '\t' + call + '\n\t__unitdiag_observer.leave(__unitdiag_token)\n\n'
        else:
            wrapper += '\tvar __unitdiag_result: ' + result_type + ' = ' + call + '\n\t__unitdiag_observer.leave(__unitdiag_token)\n\treturn __unitdiag_result\n\n'
        new = wrapper + declaration.replace('func ' + method + '(', 'func __unitdiag_original_' + method + '(', 1)
        text = text[:match.start()] + new + text[match.end():]
        replacements.append({'method': method, 'old': declaration, 'new': new})
    reversed_text = text
    for change in reversed(replacements):
        guard.need(reversed_text.count(change['new']) == 1, 'Ambiguous reversal')
        reversed_text = reversed_text.replace(change['new'], change['old'], 1)
    guard.need(reversed_text.encode('utf-8') == raw, 'Transformation not exactly reversible')
    return text.encode('utf-8'), replacements, scopes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--static-only', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    original_receipt = json.loads((BASELINE / 'receipt.json').read_text(encoding='utf-8'))
    guard.need(original_receipt['source_head'] == 'c0285f91d4131e7631707fa59903d4b61fd460bb', 'Wrong actual baseline')
    hashes = {x['path']: x['sha256'] for x in original_receipt['source_files']}
    static = {'baseline_head': original_receipt['source_head'], 'files': [], 'scopes': [], 'production_modified': False}
    for path in METHODS:
        raw = (BASELINE / 'project' / path).read_bytes()
        guard.need(guard.sha(raw) == hashes[path], 'Baseline source changed')
        changed, edits, scopes = transform(raw, path)
        static['files'].append({'path': path, 'before_sha256': guard.sha(raw), 'after_sha256': guard.sha(changed),
                                'reversible': True, 'edits': edits})
        static['scopes'] += scopes
    guard.need(len(static['scopes']) == len(set(static['scopes'])), 'Duplicate scopes')
    guard.save(HERE / 'static_preparation.json', static)
    print(json.dumps({'static_verified': True, 'files': len(static['files']), 'scopes': len(static['scopes'])}), flush=True)
    if args.static_only: return
    guard.need(args.output is not None, 'New private output required')
    base.METHODS = METHODS
    base.transform = transform
    sys.argv = [str(HERE / 'prepare.py'), '--baseline-run', str(BASELINE), '--output', str(args.output)]
    base.main()
    output = args.output.resolve()
    manifest = json.loads((output / 'preparation.json').read_text(encoding='utf-8'))
    observer = (HERE / 'observer.gd').read_bytes()
    (output / 'project/tools/unit_remainder_observer.gd').write_bytes(observer)
    manifest['observer_sha256'] = guard.sha(observer)
    manifest['scope'] = 'Unit unnamed body remainder; known scopes retained only for nested exclusion; no rule or frequency changes'
    manifest['body_tools_sha256'] = {name: guard.sha((HERE / name).read_bytes()) for name in ('prepare.py', 'run.py', 'observer.gd')}
    manifest['host_helpers_sha256'] = {name: guard.sha((ROOT / 'tools' / name).read_bytes()) for name in
        ('prepare_unit_remainder_diagnostic.py', 'run_unit_remainder_diagnostic.py', 'run_stabilization_performance.py')}
    manifest['inline_spans'] = [x[0] for x in SPANS]
    manifest['measured_ledger_is_not_subtractable'] = True
    guard.save(output / 'preparation.json', manifest)


if __name__ == '__main__': main()
