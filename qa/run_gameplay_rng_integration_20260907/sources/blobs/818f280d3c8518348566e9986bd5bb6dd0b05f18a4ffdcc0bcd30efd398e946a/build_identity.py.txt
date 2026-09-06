"""One input grammar shared with provider.gd; no Godot/Git/subprocess calls.

seed creates only the unique generated constant stub in private staging.
generate hashes the actual post-import staging, then replaces that exact stub.
snapshot is read-only. All output JSON is outside the project input roots.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
DERIVED = 'scripts/run_build_identity.gd'
STUB = b'extends RefCounted\n# Generated after private import; an empty identity never qualifies.\nconst IDENTITY: Dictionary = {}\n'


def need(ok, message):
    if not ok: raise RuntimeError(message)


def sha(raw): return hashlib.sha256(raw).hexdigest()


def no_links(path):
    for item in [path] + list(path.parents):
        if item.exists() or item.is_symlink():
            st = item.lstat()
            need(not item.is_symlink() and not getattr(st, 'st_file_attributes', 0) & 0x400, 'Link/reparse path: ' + str(item))


def relative_ok(path):
    return bool(path) and not path.startswith('/') and '\\' not in path and ':' not in path and all(p not in ('', '.', '..') for p in path.split('/')) and all(ord(c) >= 32 and ord(c) != 127 for c in path)


def rules_from(provider):
    raw = provider.read_bytes()
    matches = re.findall(rb'const INPUT_RULES_JSON := """([^\r\n]+)"""', raw)
    need(len(matches) == 1, 'Exact single normative rules constant required')
    text = matches[0].decode('utf-8')
    rules = json.loads(text)
    need(rules['schema'] == 1 and rules['derived'] == DERIVED and rules['import_ignore_is_exclusion'] is False, 'Unsupported rules')
    return rules, sha(text.encode('utf-8'))


def snapshot(project, provider_relative='scripts/run_content_identity.gd', _verify=None):
    project = Path(project).absolute()
    no_links(project)
    need(relative_ok(provider_relative), 'Provider relative path')
    provider = project / provider_relative
    no_links(provider)
    rules, rules_sha = rules_from(provider)
    files, directories, case_paths, stamps = {}, {}, {}, {}
    total = 0

    def register(name):
        need(relative_ok(name), 'Invalid input path: ' + name)
        folded = name.lower()
        need(folded not in case_paths or case_paths[folded] == name, 'Case collision: ' + name)
        case_paths[folded] = name

    def add(name):
        nonlocal total
        if name == rules['derived'] or name in files: return
        register(name)
        path = project / name
        no_links(path)
        before = path.stat()
        need(path.is_file(), 'Expected regular input: ' + name)
        need(len(files) < rules['max_files'] and before.st_size <= rules['max_bytes'] - total, 'Input budget')
        if _verify is None:
            digest = hashlib.sha256()
            with path.open('rb') as handle:
                for block in iter(lambda: handle.read(1024 * 1024), b''): digest.update(block)
            digest_text = digest.hexdigest()
        else:
            expected, expected_stamps = _verify
            need(name in expected and (before.st_size, before.st_mtime_ns) == expected_stamps[name], 'Input listing changed: ' + name)
            digest_text = expected[name]['sha256']
        after = path.stat()
        need((before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns), 'Input changed: ' + name)
        files[name] = {'path': name, 'bytes': before.st_size, 'sha256': digest_text}
        stamps[name] = (before.st_size, before.st_mtime_ns)
        total += before.st_size

    def walk(relative, depth):
        need(depth <= rules['max_depth'], 'Input depth')
        register(relative)
        path = project / relative
        no_links(path)
        need(path.is_dir(), 'Unreadable input directory: ' + relative)
        directories[relative] = True
        # Import ignore does not exclude explicitly readable script/data inputs.
        with os.scandir(path) as listing:
            entries = sorted(list(listing), key=lambda p: p.name)
        for entry in entries:
            child = path / entry.name
            no_links(child)
            if entry.is_dir(follow_symlinks=False):
                if entry.name not in rules['skip_directories']: walk(relative + '/' + entry.name, depth + 1)
            else:
                add(relative + '/' + entry.name)

    for name in rules['root_files']:
        if (project / name).is_file(): add(name)
        else:
            need(not (project / name).exists() and name not in rules['required_files'], 'Required input absent/wrong type: ' + name)
            directories['@file/' + name] = False
    for name in rules['roots']:
        if (project / name).is_dir(): walk(name, 0)
        else:
            need(not (project / name).exists() and name not in rules['required_roots'], 'Required directory absent/wrong type: ' + name)
            directories[name] = False
    add(provider_relative)
    optional = []
    for name in rules['optional_content']:
        if (project / name).is_file():
            add(name)
            optional.append(dict(files[name], present=True))
        else:
            need(not (project / name).exists(), 'Content input wrong type: ' + name)
            optional.append({'path': name, 'present': False, 'bytes': 0, 'sha256': ''})
    records = [files[name] for name in sorted(files)]
    canonical = rules['header'] + '\nrules\t' + rules_sha + '\n'
    canonical += ''.join('D\t%s\t%d\n' % (name, directories[name]) for name in sorted(directories))
    canonical += ''.join('F\t%s\t%d\t%s\n' % (row['path'], row['bytes'], row['sha256']) for row in records)
    canonical += ''.join('O\t%s\t%d\n' % (row['path'], row['present']) for row in optional)
    native = [row for row in records if row['path'].startswith('addons/') and Path(row['path']).suffix in {'.dll', '.so', '.dylib', '.gdextension'}]
    result = {'schema': 1, 'rules_sha256': rules_sha, 'source_sha256': sha(canonical.encode('utf-8')),
            'file_count': len(records), 'total_bytes': total, 'files': records, 'directories': directories,
            'optional_content': optional, 'native_files': native, 'provider_path': provider_relative,
            'provider_sha256': files[provider_relative]['sha256']}
    if _verify is None:
        need(snapshot(project, provider_relative, (files, stamps)) == result, 'Input enumeration changed')
    return result


def identity_constant(record):
    value = {k: v for k, v in record.items() if k not in ('files', 'directories')}
    return ('extends RefCounted\n# Generated from exact post-import inputs; no source reads are needed in PCK.\n'
            'const IDENTITY: Dictionary = ' + json.dumps(value, ensure_ascii=False, separators=(',', ':')) + '\n').encode('utf-8')


def seed(project):
    private_staging(project)
    target = Path(project) / DERIVED
    no_links(target)
    need(target.parent.is_dir(), 'Private scripts directory required')
    with target.open('xb') as out: out.write(STUB)
    return {'path': DERIVED, 'bytes': len(STUB), 'sha256': sha(STUB)}


def generate(project):
    private_staging(project)
    project = Path(project).absolute()
    target = project / DERIVED
    no_links(target)
    need(target.read_bytes() == STUB, 'Only the exact seeded private constant can be replaced; never overwrite an existing build identity')
    record = snapshot(project)
    constant = identity_constant(record)
    # No callback/engine work occurs between the input snapshot and this one derived-file write.
    need(target.read_bytes() == STUB, 'Derived stub changed')
    target.write_bytes(constant)
    need(snapshot(project) == record, 'Input changed during generation')
    return {'kind': 'content_identity_generation', 'identity': record, 'derived': {'path': DERIVED, 'bytes': len(constant), 'sha256': sha(constant)},
            'generator_sha256': sha(Path(__file__).read_bytes()), 'godot_run': False}


def private_staging(project):
    project = Path(project).absolute()
    no_links(project)
    roots = [p for p in [HERE] + list(HERE.parents) if (p / 'project.godot').is_file() and (p / 'scripts/battle.gd').is_file()]
    need(bool(roots), 'Cannot locate owning checkout')
    owner = roots[0]
    need(project != owner and owner in project.parents, 'Only private staging below the owning checkout may be written')
    parts = project.relative_to(owner).parts
    need(parts[0] in {'.godot', 'scratchpad'} and project.name == 'project' and not (project / '.git').exists(), 'Private staging project path required')


def verify_generated(project, receipt):
    need(snapshot(project) == receipt['identity'], 'Inputs no longer match generated identity')
    raw = (Path(project) / DERIVED).read_bytes()
    need(len(raw) == receipt['derived']['bytes'] and sha(raw) == receipt['derived']['sha256'], 'Generated constant changed')
    need(raw == identity_constant(receipt['identity']), 'Generated constant is not the canonical output')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['snapshot', 'seed', 'generate', 'verify'])
    parser.add_argument('--project', required=True, type=Path)
    parser.add_argument('--provider-rel', default='scripts/run_content_identity.gd')
    parser.add_argument('--receipt', type=Path)
    args = parser.parse_args()
    if args.command == 'snapshot': result = snapshot(args.project, args.provider_rel)
    elif args.command == 'seed': result = seed(args.project)
    elif args.command == 'generate': result = generate(args.project)
    else:
        need(args.receipt is not None, 'verify requires the generation receipt')
        verify_generated(args.project, json.loads(args.receipt.read_text(encoding='utf-8')))
        result = {'verified': True}
    if args.receipt and args.command != 'verify':
        no_links(args.receipt)
        need(args.project.absolute() not in args.receipt.absolute().parents, 'Receipt must stay outside project')
        with args.receipt.open('xb') as out: out.write((json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__': main()
