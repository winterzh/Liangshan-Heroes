"""Generate new-schema validators from immutable full predicates, without native execution."""
import ast
from pathlib import Path
import textwrap

from durable_campaign_full_runtime import sha, no_links

ROOT = Path(__file__).resolve().parents[1]
OLD = ROOT / 'qa/zhu_wounded_20261005/proposals/daming_safe_retreat_v25'
FULL_SHA = 'e61b7e87a5c52792040fc9d6e84828c6fce2aec8f3496ec3bf883c78aab5fd79'
PARENT_SHA = '5941315849982fb73d4851c2fcb95a2369d498760a83801427d315dd6a229af5'


def generate():
    full = OLD / 'run_daming_safe_retreat_v25s_r2b2_full.py'
    parent = OLD / 'run_daming_safe_retreat_v25s.py'
    assert sha(full) == FULL_SHA and sha(parent) == PARENT_SHA
    text = full.read_text(encoding='utf-8-sig')
    tree = ast.parse(text)
    result = ['"""Strict fixed predicates retained from immutable r2b2; distinct durable report schemas."""',
              'import re', 'HEX64 = re.compile(r"[0-9a-f]{64}\\Z")',
              'CASES = ("A_single_save", "B_install_settle_resave", "C_install_finish", "D_read_terminal")',
              'RETREAT_CASES = CASES', 'def require(condition, message):',
              '    if not condition: raise RuntimeError(message)', '']
    for kind, method in [('world', 'run_world_dto_negatives'), ('component', 'run_component_negatives'), ('capture', 'run_live_negatives')]:
        owner = next(v for v in ast.walk(tree) if isinstance(v, ast.FunctionDef) and v.name == method)
        validate = next(v for v in ast.walk(owner) if isinstance(v, ast.FunctionDef) and v.name == 'validate')
        block = '\n'.join(text.splitlines()[validate.body[2].lineno - 1:validate.end_lineno])
        block = textwrap.dedent(block)
        block = block[:block.index('self.verify_manifest_sources')].rstrip()
        block = block.replace('base.require(', 'require(')
        if kind == 'capture':
            block = block.replace('"v25d1"', '"campaign_v2_r1"')
            block = block.replace('self.validate_retreat_hold_lifecycle(data, CASES[2])', 'validate_hold(data, CASES[2])')
            header = 'def validate_capture(data, interface, fixture, case, expected_code):'
        else:
            header = 'def validate_' + kind + '(data, interface):'
        result += [header, textwrap.indent(block, '    '), '']
    parent_text = parent.read_text(encoding='utf-8-sig')
    parent_tree = ast.parse(parent_text)
    installed = next(v for v in parent_tree.body if isinstance(v, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'INHERITED_INSTALL_LABELS' for t in v.targets))
    result += [ast.get_source_segment(parent_text, installed), '']
    method = next(v for v in ast.walk(parent_tree) if isinstance(v, ast.FunctionDef) and v.name == 'validate_retreat_case')
    lines = parent_text.splitlines()
    start = next(v.lineno for v in method.body if isinstance(v, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'labels' for t in v.targets))
    end = next(v.lineno for v in method.body if isinstance(v, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'slot' for t in v.targets))
    block = textwrap.dedent('\n'.join(lines[start - 1:end - 1])).replace('base.require(', 'require(')
    block = block.replace('new process reloads prior Campaign baseline because QA suppressed write', 'new process reloads confirmed Campaign records')
    result += ['def validate_case_labels(data, case):', textwrap.indent(block, '    '), '']
    method = next(v for v in ast.walk(parent_tree) if isinstance(v, ast.FunctionDef) and v.name == 'validate_retreat_hold_lifecycle')
    block = '\n'.join(parent_text.splitlines()[method.body[0].lineno - 1:method.end_lineno])
    block = textwrap.dedent(block).replace('base.require(', 'require(')
    result += ['def validate_hold(data, case):', textwrap.indent(block, '    '), '']
    output = '\n'.join(result)
    ast.parse(output)
    return output


if __name__ == '__main__':
    if not __debug__: raise SystemExit('Assertions must remain enabled')
    target = ROOT / 'tools/durable_campaign_full_matrices.py'
    no_links(target)
    with target.open('x', encoding='utf-8', newline='\n') as stream:
        stream.write(generate())
    print('Prepared retained fixed predicates; no native execution')
