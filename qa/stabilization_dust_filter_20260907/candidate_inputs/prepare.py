"""Freeze one dust-filter candidate and pure-data equivalence evidence.

No Godot, production edits, or performance claim. The candidate retains the
complete first decrement pass and creates a new ordered result Array.
"""
import copy
import difflib
import hashlib
import json
from pathlib import Path
import random
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / '.godot/stabilization_performance/20260907T053341Z_cd6e93a0'
HEAD = 'c0285f91d4131e7631707fa59903d4b61fd460bb'


def sha(raw): return hashlib.sha256(raw).hexdigest()


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes((json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))


def reference(dust, delta):
    if not dust: return dust, 0
    for particle in dust: particle['t'] -= delta
    return list(filter(lambda particle: particle['t'] > 0.0, dust)), 1


def candidate(dust, delta):
    if not dust: return dust, 0
    for particle in dust: particle['t'] -= delta
    alive = []
    for particle in dust:
        if particle['t'] > 0.0: alive.append(particle)
    return alive, 1


def wrong_fused(dust, delta):
    alive = []
    for particle in dust:
        particle['t'] -= delta
        if particle['t'] > 0.0: alive.append(particle)
    return alive


def check_case(label, original, delta):
    left = copy.deepcopy(original)
    right = copy.deepcopy(original)
    rng_before = random.getstate()
    old, old_redraws = reference(left, delta)
    new, new_redraws = candidate(right, delta)
    assert random.getstate() == rng_before
    assert left == right and old == new and old_redraws == new_redraws
    assert (old is left) == (new is right) == (len(original) == 0)
    old_aliases = [[item is source for source in left] for item in old]
    new_aliases = [[item is source for source in right] for item in new]
    assert old_aliases == new_aliases
    assert all(any(row) for row in old_aliases), 'Result must retain exact source Dictionary identities'
    return {'label': label, 'passed': True, 'input_count': len(original), 'output_count': len(old),
            'delta': delta, 'new_array_for_nonempty': True, 'dictionary_aliases_preserved': True,
            'order_and_values_equal': True, 'redraw_count_equal': True}


def main():
    receipt_raw = (BASE / 'receipt.json').read_bytes()
    receipt = json.loads(receipt_raw.decode('utf-8'))
    assert receipt['source_head'] == HEAD and receipt['complete'] and receipt['baseline_eligible']
    row = next(x for x in receipt['source_files'] if x['path'] == 'scripts/unit.gd')
    raw = (BASE / 'project/scripts/unit.gd').read_bytes()
    assert sha(raw) == row['sha256']
    assert hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest() == row['git_oid']
    old = b'\t\t_dust = _dust.filter(func(d): return d.t > 0.0)\n'
    new = (b'\t\tvar alive_dust: Array = []\n'
           b'\t\tfor dust_particle in _dust:\n'
           b'\t\t\tif dust_particle.t > 0.0:\n'
           b'\t\t\t\talive_dust.append(dust_particle)\n'
           b'\t\t_dust = alive_dust\n')
    assert raw.count(old) == 1 and b'alive_dust' not in raw and b'dust_particle' not in raw
    changed = raw.replace(old, new, 1)
    assert changed.replace(new, old, 1) == raw
    start = raw.index(b'\tif not _dust.is_empty():\n')
    end = raw.index(b'\tif _lunge > 0.0:\n', start)
    old_block = raw[start:end]
    new_block = old_block.replace(old, new, 1)
    assert old_block.startswith(b'\tif not _dust.is_empty():\n\t\tfor d in _dust:\n\t\t\td.t -= delta\n')
    assert old_block.endswith(b'\t\t_request_redraw()\n') and new_block.endswith(b'\t\t_request_redraw()\n')
    assert not re.search(rb'\b(?:seed|randomize|randf|randi|randf_range|randi_range|randfn)\s*\(|_gameplay_', old + new)
    text, changed_text = raw.decode('utf-8'), changed.decode('utf-8')
    def methods(source):
        positions = list(re.finditer(r'^func ([A-Za-z_0-9]+)\(', source, re.M))
        return {m.group(1): source[m.start():positions[i+1].start() if i+1 < len(positions) else len(source)] for i, m in enumerate(positions)}
    a, b = methods(text), methods(changed_text)
    changed_methods = [name for name in a if a[name] != b[name]]
    assert changed_methods == ['_phys_body']
    target = HERE / 'candidate/scripts/unit.gd'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(changed)
    diff = ''.join(difflib.unified_diff(text.splitlines(keepends=True), changed_text.splitlines(keepends=True),
                                      fromfile='a/scripts/unit.gd', tofile='b/scripts/unit.gd', n=8))
    (HERE / 'candidate.patch').write_bytes(diff.encode('utf-8'))
    cases = []
    fixed = [([], 0.0, 'empty retains input Array'),
             ([{'id': 0, 't': 0.0}], 0.0, 't exactly zero and delta zero'),
             ([{'id': 0, 't': 0.125}], 0.125, 'decrement reaches zero exactly'),
             ([{'id': 0, 't': -0.0}, {'id': 1, 't': 1e-12}], 0.0, 'signed zero and positive epsilon'),
             ([{'id': 0, 't': -1.0}, {'id': 1, 't': 0.5}, {'id': 2, 't': 2.0}], 0.5, 'negative expired survivor order')]
    shared = {'id': 0, 't': 0.015}
    fixed.append(([shared, {'id': 1, 't': 1.0}, shared], 0.01, 'duplicate reference crosses boundary on second decrement'))
    shared_alive = {'id': 0, 't': 1.0}
    fixed.append(([shared_alive, {'id': 1, 't': 0.5}, shared_alive], 0.1, 'surviving duplicated Dictionary preserves both aliases'))
    for values, delta, label in fixed: cases.append(check_case(label, values, delta))
    factory = random.Random(5088120)
    for index in range(1000):
        pool = [{'id': i, 't': factory.choice([0.0, -0.0, 0.125, 1e-12, -0.5, 2.0, factory.random()])} for i in range(factory.randrange(1, 6))]
        values = [pool[factory.randrange(len(pool))] for _ in range(factory.randrange(0, 9))]
        delta = factory.choice([0.0, 0.125, 1.0 / 60.0, 1e-12, 0.5])
        cases.append(check_case('seeded alias graph ' + str(index), values, delta))
    duplicate = {'id': 0, 't': 0.015}
    source = [duplicate, duplicate]
    old_result, _ = reference(copy.deepcopy(source), 0.01)
    fused_result = wrong_fused(copy.deepcopy(source), 0.01)
    assert len(old_result) == 0 and len(fused_result) == 1
    proof = {'passed': True, 'python_model_cases': len(cases), 'cases': cases,
             'wrong_fused_counterexample': {'reference_keeps': len(old_result), 'fused_keeps': len(fused_result)},
             'python_random_state_unchanged': True, 'godot_runtime_tested': False, 'performance_tested': False,
             'limits': 'Python pure-data model and exact source transformation only. Native GDScript and normal-game A/B remain pending.'}
    save(HERE / 'pure_data_review.json', proof)
    metadata = {'status': 'candidate_static_and_pure_data_only', 'source_head': HEAD,
        'baseline_receipt_sha256': sha(receipt_raw), 'path': 'scripts/unit.gd', 'git_blob_oid': row['git_oid'],
        'before_sha256': sha(raw), 'candidate_sha256': sha(changed), 'patch_sha256': sha(diff.encode('utf-8')),
        'changed_methods': changed_methods, 'all_other_methods_byte_identical': True,
        'rng_and_health_methods_byte_identical': True, 'replacement_contains_no_rng_or_health_calls': True,
        'original_decrement_pass_preserved': True, 'new_array_and_order_preserved': True,
        'old_block': old_block.decode('utf-8'), 'new_block': new_block.decode('utf-8'),
        'production_modified': False, 'godot_runtime_tested': False, 'normal_ab_tested': False}
    save(HERE / 'source_receipt.json', metadata)
    print(json.dumps({'candidate_prepared': True, 'pure_data_cases': len(cases), 'changed_methods': changed_methods,
                      'candidate_sha256': sha(changed)}), flush=True)


if __name__ == '__main__': main()
