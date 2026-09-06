"""No Git/Godot subprocess: reversible transforms and tiny isolated stub fixtures."""
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
import tempfile

sys.dont_write_bytecode = True
import prepare as prep
import transforms as tx

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def main():
    checks = []
    def check(ok, label):
        if not ok: raise AssertionError(label)
        checks.append(label)
    def rejects(callback, label):
        try: callback()
        except (RuntimeError, FileExistsError): checks.append(label); return
        raise AssertionError(label)
    for name in ('prepare.py', 'transforms.py', 'run_entry.py', 'static_checks.py'):
        ast.parse((HERE / name).read_text(encoding='utf-8'))
        check(True, 'Python AST ' + name)
    sources = {name: (ROOT / name).read_bytes() for name in tx.PINS if name not in ('scripts/unit.gd', 'scripts/battle.gd', 'tools/polish_performance_probe.gd')}
    sources['tools/polish_performance_probe.gd'] = (ROOT / 'scratchpad/separation_sections_diag/frozen/tools__polish_performance_probe.gd').read_bytes()
    sources['scripts/unit.gd'] = (ROOT / 'scratchpad/physics_step_diag/frozen/unit_original.bin').read_bytes()
    sources['scripts/battle.gd'] = (ROOT / 'scratchpad/physics_step_diag/frozen/battle_original.bin').read_bytes()
    for name, raw in sources.items(): check(tx.sha(tx.normalized(raw)) == tx.PINS[name], 'Source pin ' + name)
    preview = HERE / 'generated_preview'; preview.mkdir(exist_ok=True)
    method_receipts = {}
    for name, recipes in [('scripts/sfx.gd', tx.SFX), ('scripts/art_db.gd', tx.ART)]:
        output, receipts = tx.instrument(name, sources[name])
        method_receipts[name] = receipts
        restored = output.decode()
        for method in reversed(list(recipes)):
            lo, hi = tx.method_span(restored, method)
            restored = restored[:lo] + restored[hi:]
            renamed = '_first_use_original_' + method.lstrip('_')
            restored = restored.replace('func ' + renamed + '(', 'func ' + method + '(', 1)
        check(restored == tx.normalized(sources[name]).decode(), 'Whole-file inverse ' + name)
        check(all(row['original_call_sites'] == 1 for row in receipts), 'Exactly one call per wrapper ' + name)
        (preview / (Path(name).stem + '.gd.txt')).write_bytes(output)
    generated_driver = tx.driver(sources['tools/polish_performance_probe.gd'], (HERE / 'driver.gd.in').read_text(encoding='utf-8'))
    (preview / 'driver.gd').write_bytes(generated_driver)
    (preview / 'ledger.gd').write_bytes((HERE / 'ledger.gd.in').read_bytes())
    check(b'@@' not in generated_driver, 'Driver placeholders resolved')
    driver_text = generated_driver.decode()
    check(driver_text.count('await _new_battle()') == 1 and driver_text.count('while physics_tick < WARMUP_TICKS') == 1, 'Native fixture and warmup called once')
    recipes_text = '\n'.join(list(tx.SFX.values()) + list(tx.ART.values()))
    rng_pattern = r'\b(?:(?:randf|randi)(?:_range)?|randfn|rand_from_seed|seed|randomize)\s*\('
    check(re.search(rng_pattern, recipes_text) is None, 'No new random calls in wrappers')
    check(re.search(rng_pattern, 'randf_range(-1.0, 1.0)') is not None, 'Random-call guard includes range variants')
    check('.new(' not in recipes_text, 'No new Object allocations in wrappers')
    marker_name = 'assets/campaign/source/.gdignore'
    check(prep.ignored_by('assets/campaign/source/history/a.png', {marker_name: {}}) == marker_name, 'Ignored directory covers nested descendants')
    check(prep.ignored_by('assets/campaign/source_extra/a.png', {marker_name: {}}) is None, 'Similar sibling prefix remains a runtime import')
    check(prep.ignored_by('assets/campaign/source/history/a.png', {marker_name: {}, 'assets/campaign/source/history/.gdignore': {}}) == marker_name, 'Nested marker cannot negate ancestor ignored directory')
    rejects(lambda: prep.reject_ignored_reference('scripts/runtime.gd', 'load("res://assets/campaign/source/a.png")', {marker_name: {}}), 'Runtime reference into ignored provenance directory rejected')
    prep.reject_ignored_reference('scripts/runtime.gd', 'load("res://assets/campaign/source_extra/a.png")', {marker_name: {}})
    check(True, 'Runtime reference to similarly named sibling is not treated as ignored')
    rejects(lambda: tx.instrument('scripts/sfx.gd', sources['scripts/sfx.gd'] + b'\n'), 'Source drift rejects without refreshing pins')
    original_root, original_here, original_git = prep.ROOT, prep.HERE, prep.git
    # Kept under the authorized scratchpad root. No real Unit writes or actual Git.
    base = Path(tempfile.mkdtemp(prefix='stub_', dir=HERE))
    fake_root = base / 'source'; fake_here = base / 'output'; fake_root.mkdir(); fake_here.mkdir()
    try:
        prep.ROOT, prep.HERE = fake_root, fake_here
        for name in ('prepare.py', 'transforms.py', 'driver.gd.in', 'ledger.gd.in'):
            (fake_here / name).write_bytes((HERE / name).read_bytes())
        fake_sources = dict(sources)
        fake_sources['tools/zhujiazhuang_rts_test.gd'] = b'extends SceneTree\n'
        fake_sources['project.godot'] = b'config_version=5\n[application]\nconfig/name="stub"\n[autoload]\nArt="*res://scripts/art_db.gd"\n'
        asset = b'not-an-image-static-fixture'
        cache_base = '.godot/imported/a.png-' + '0' * 32
        fake_sources['assets/a.png'] = asset
        fake_sources['assets/a.png.import'] = ('[remap]\npath="res://' + cache_base + '.ctex"\n[deps]\nsource_file="res://assets/a.png"\ndest_files=["res://' + cache_base + '.ctex"]\n').encode()
        fake_sources[marker_name] = tx.normalized((ROOT / marker_name).read_bytes())
        check(prep.blob(fake_sources[marker_name]) == prep.IGNORE_MARKERS[marker_name], 'Stub marker LF bytes equal independently reviewed frozen Git blob')
        ignored_source = 'assets/campaign/source/stale.png'
        fake_sources[ignored_source] = b'provenance image with no imported cache'
        fake_sources['assets/campaign/source/history/unimported.png'] = b'nested provenance without remap'
        fake_sources[ignored_source + '.import'] = ('[remap]\npath="res://.godot/imported/stale.png-' + '1' * 32 + '.ctex"\n[deps]\nsource_file="res://' + ignored_source + '"\n').encode()
        objects = {prep.blob(raw): raw for raw in fake_sources.values()}
        modes = {name: '100644' for name in fake_sources}
        for name, raw in fake_sources.items():
            path = fake_root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
        cache = fake_root / (cache_base + '.ctex'); cache.parent.mkdir(parents=True); cache.write_bytes(b'cache-stub')
        md5 = fake_root / (cache_base + '.md5')
        md5.write_bytes(('source_md5="' + hashlib.md5(asset).hexdigest() + '"\ndest_md5="' + hashlib.md5(b'cache-stub').hexdigest() + '"\n').encode())
        class_cache = fake_root / '.godot/global_script_class_cache.cfg'
        class_bytes = b'list=[{"class": &"Unit", "base": &"Node2D", "path": "res://scripts/unit.gd"}, {"class": &"UnrelatedQA", "path": "res://scratchpad/excluded.gd"}]\n'
        class_cache.write_bytes(class_bytes)
        fake_commit = '4baafc1' + '0' * 33
        def fake_git(*args):
            if args[0] == 'rev-parse': return (fake_commit + '\n').encode()
            if args[0] == 'ls-tree':
                return b''.join((modes[name] + ' blob ' + prep.blob(raw) + ' ' + str(len(raw)) + '\t' + name + '\0').encode() for name, raw in fake_sources.items())
            if args[:2] == ('cat-file', 'blob'): return objects[args[2]]
            raise AssertionError('Unexpected Git request; no subprocess is allowed: ' + repr(args))
        prep.git = fake_git
        p = prep.plan()
        check(p['snapshot'] == fake_commit and len(p['cache_files']) == 2, 'Plan derives exact snapshot and referenced cache only')
        check(len(p['ignored_imports']) == 1 and p['ignored_imports'][0]['source'] == ignored_source, 'Ignored historical remap requires no nonexistent imported cache')
        check({row['path'] for row in p['ignored_source_files_retained']} == {name for name in fake_sources if name.startswith('assets/campaign/source/')}, 'All ignored provenance source files remain in planned copy')
        marker_file = fake_root / marker_name
        marker_raw = marker_file.read_bytes()
        marker_file.write_bytes(marker_raw.replace(b'\n', b'\r\n'))
        line_plan = prep.plan()
        check(line_plan['frozen_ignore_markers'][marker_name]['line_endings_only_difference'] and line_plan['frozen_ignore_markers'][marker_name]['live_lf_sha256'] == tx.sha(marker_raw), 'Marker-only CRLF comparison preserves both raw digests and frozen content')
        marker_file.write_bytes(marker_raw)
        p = prep.plan()
        marker_file.unlink()
        rejects(prep.plan, 'Deleted live frozen ignore marker rejected')
        marker_file.write_bytes(marker_raw)
        marker_file.write_bytes(marker_raw + b'changed')
        rejects(prep.plan, 'Live frozen marker byte drift rejected')
        marker_file.write_bytes(marker_raw)
        fake_sources[marker_name] = marker_raw + b'changed snapshot'
        rejects(prep.plan, 'Frozen marker blob drift rejected')
        fake_sources[marker_name] = marker_raw
        original_remap = fake_sources[ignored_source + '.import']
        fake_sources[ignored_source + '.import'] = original_remap.replace(ignored_source.encode(), b'assets/a.png')
        objects[prep.blob(fake_sources[ignored_source + '.import'])] = fake_sources[ignored_source + '.import']
        rejects(prep.plan, 'Ignored remap cannot suppress actual runtime resource import')
        fake_sources[ignored_source + '.import'] = original_remap
        untracked_marker = fake_root / 'assets/.gdignore'
        untracked_marker.write_bytes(b'untracked must not affect frozen mirror')
        cache.unlink()
        missing_plan = prep.plan()
        check(len(missing_plan['needs_reimport']) == 1 and not missing_plan['cache_files'] and missing_plan['needs_reimport'][0]['source'] == 'assets/a.png', 'Untracked marker cannot bypass missing runtime cache; explicit private reimport required')
        cache.write_bytes(b'cache-stub')
        untracked_marker.unlink()
        asset_path = fake_root / 'assets/a.png'
        asset_path.write_bytes(asset + b'changed live resource')
        changed_plan = prep.plan()
        check(len(changed_plan['needs_reimport']) == 1 and not changed_plan['cache_files'] and changed_plan['needs_reimport'][0]['expected']['sha256'] == tx.sha(asset), 'Changed live resource records frozen/live/cache evidence and never copies old cache')
        asset_path.write_bytes(asset)
        p = prep.plan()
        check('UnrelatedQA' not in p['class_cache_output'], 'Excluded class cache path filtered')
        check(p['class_cache_frozen_declarations'][0]['source_blob_oid'] == prep.blob(sources['scripts/unit.gd']), 'Class declaration proof points to frozen source blob')
        class_cache.write_bytes(class_bytes.replace(b'&"Unit"', b'&"WrongUnit"'))
        rejects(prep.plan, 'Same-path stale class name rejected against frozen source')
        class_cache.write_bytes(class_bytes.replace(b'&"Node2D"', b'&"Control"'))
        rejects(prep.plan, 'Same-path stale class base rejected against frozen source')
        class_cache.write_bytes(class_bytes)
        mirror = prep.materialize(fake_here / 'plan.json', p['plan_sha256'], 'timed01')
        check(mirror['complete'] and not mirror['production_mutated'], 'Tiny mirror materializes without source write')
        target = Path(mirror['mirror'])
        check((target / 'scripts/unit.gd').read_bytes() == sources['scripts/unit.gd'], 'Mirrored Unit remains original bytes')
        check((fake_root / 'scripts/sfx.gd').read_bytes() == sources['scripts/sfx.gd'], 'Source Sfx untouched')
        rejects(lambda: prep.materialize(fake_here / 'plan.json', p['plan_sha256'], 'timed01'), 'Existing mirror refuses overwrite')
        rejects(lambda: prep.materialize(fake_here / 'plan.json', '0' * 64, 'bad'), 'Wrong explicit plan acceptance rejected')
        rejects(lambda: prep.relative_safe('../scripts/unit.gd'), 'Path traversal rejected')
        cache.write_bytes(b'changed-cache')
        rejects(lambda: prep.materialize(fake_here / 'plan.json', p['plan_sha256'], 'changedcache'), 'Cache drift after plan rejected')
        failed = fake_here / ('mirror_' + p['plan_sha256'][:12] + '_changedcache/materialization_failed.json')
        check(failed.exists(), 'Failed partial mirror preserved with receipt')
        cache.write_bytes(b'cache-stub')
        md5.write_bytes(b'source_md5="00000000000000000000000000000000"\n')
        stale_plan = prep.plan()
        check(len(stale_plan['needs_reimport']) == 1 and not stale_plan['cache_files'] and stale_plan['needs_reimport'][0]['old_cache_copied'] is False, 'Stale source MD5 remains mismatch and old cache is excluded pending private reimport')
        md5.write_bytes(('source_md5="' + hashlib.md5(asset).hexdigest() + '"\ndest_md5="' + hashlib.md5(b'cache-stub').hexdigest() + '"\n').encode())
        p = prep.plan()
        modes['scripts/sfx.gd'] = '120000'
        rejects(prep.plan, 'Snapshot symlink rejected')
        modes['scripts/sfx.gd'] = '100644'
        # Launcher failure path uses a Python stub, not an executable or shell.
        import run_entry as launch
        launch.HERE = fake_here
        launch.ROOT = fake_root
        launch.godot_process_ids = lambda: []
        pending_import = dict(mirror)
        pending_import.update(needs_reimport=stale_plan['needs_reimport'], private_import_required_before_diagnostic=True)
        rejects(lambda: launch.mirror_sources(target, pending_import), 'Pending private import blocks diagnostic entry before process launch')
        falsely_complete = dict(pending_import)
        falsely_complete.update(private_import_required_before_diagnostic=False, private_import_completion={'complete':True,'owned_child_exit_confirmed':True,'exit_code':0,'engine_errors':False,'plan_sha256':mirror['plan_sha256']}, import_cache_files=[])
        rejects(lambda: launch.mirror_sources(target, falsely_complete), 'Completion flag cannot bypass missing newly frozen cache hashes')
        falsely_complete['import_cache_files'] = mirror['import_cache_files']
        target_md5 = target / (cache_base + '.md5')
        target_md5_raw = target_md5.read_bytes()
        target_md5.write_bytes(b'source_md5="00000000000000000000000000000000"\n')
        rejects(lambda: launch.mirror_sources(target, falsely_complete), 'Completed import still rejects cache source MD5 different from frozen raw source')
        target_md5.write_bytes(target_md5_raw)
        derived = target / '.godot/global_script_class_cache.cfg'
        derived_bytes = derived.read_bytes()
        check(mirror['derived_cache_files'][0]['sha256'] == tx.sha(derived_bytes), 'Materialization pins derived class cache raw bytes')
        derived.write_bytes(derived_bytes + b'\n')
        rejects(lambda: launch.mirror_sources(target, mirror), 'Derived class cache drift rejected by runtime verifier')
        derived.write_bytes(derived_bytes)
        no_pin = dict(mirror); no_pin.pop('derived_cache_files')
        rejects(lambda: launch.mirror_sources(target, no_pin), 'Old mirror without derived class cache pin rejected')
        shared_lock = fake_root / '.godot/redraw_rejection_source.lock'
        stub_exe = fake_here / 'fake.exe'; stub_exe.write_bytes(b'MZ never executed')
        old_popen, old_argv = launch.subprocess.Popen, sys.argv
        children = []
        class Child:
            pid = 424242
            def __init__(self, argv, **kwargs):
                self.killed = False; self.exited = False; self.waits = 0; children.append(self)
            def wait(self, timeout):
                self.waits += 1
                if self.waits == 1: raise KeyboardInterrupt()
                self.exited = True; return -9
            def kill(self): self.killed = True
            def poll(self): return -9 if self.exited else None
        try:
            launch.subprocess.Popen = Child
            sys.argv = ['run_entry.py', '--mirror', str(target), '--godot', str(stub_exe)]
            shared_lock.write_text('another formal window sequence', encoding='utf-8')
            rejects(launch.main, 'Shared lock blocks between-window entry even with no Godot PID')
            check(not children and shared_lock.read_text() == 'another formal window sequence', 'Occupied shared lock preserved and Popen not called')
            shared_lock.unlink()
            code = launch.main()
            check(code == 1 and children[0].killed and children[0].exited, 'KeyboardInterrupt kills/waits actual stub handle')
            check(not shared_lock.exists(), 'Confirmed exit releases only owned shared lock')
            completions = list((fake_here / 'runs').glob('*/completion_receipt.json'))
            result = json.loads(completions[0].read_text(encoding='utf-8'))
            check(result['source_unchanged'] and not result['passed'], 'Failed entry preserves source receipt and failure')
        finally:
            launch.subprocess.Popen = old_popen; sys.argv = old_argv
        # A process appearing after initial validation must be caught at the actual launch boundary.
        md5.write_bytes(('source_md5="' + hashlib.md5(asset).hexdigest() + '"\ndest_md5="' + hashlib.md5(b'cache-stub').hexdigest() + '"\n').encode())
        race_mirror = prep.materialize(fake_here / 'plan.json', p['plan_sha256'], 'beforepopen')
        scan_results = iter([[], [535353], []])
        old_count = len(children)
        try:
            launch.godot_process_ids = lambda: next(scan_results)
            launch.subprocess.Popen = Child
            sys.argv = ['run_entry.py', '--mirror', race_mirror['mirror'], '--godot', str(stub_exe)]
            code = launch.main()
            check(code == 1 and len(children) == old_count, 'New Godot before actual Popen rejects without spawning')
            check(not shared_lock.exists(), 'No child and confirmed idle cleanup releases owned shared lock')
        finally:
            launch.godot_process_ids = lambda: []
            launch.subprocess.Popen = old_popen; sys.argv = old_argv
        # A second fresh mirror proves uncertain-child handling keeps the lock.
        md5.write_bytes(('source_md5="' + hashlib.md5(asset).hexdigest() + '"\ndest_md5="' + hashlib.md5(b'cache-stub').hexdigest() + '"\n').encode())
        mirror2 = prep.materialize(fake_here / 'plan.json', p['plan_sha256'], 'unconfirmed')
        class UnconfirmedChild(Child):
            def wait(self, timeout):
                self.waits += 1
                if self.waits == 1: raise KeyboardInterrupt()
                raise launch.subprocess.TimeoutExpired('stub-child', timeout)
        try:
            launch.subprocess.Popen = UnconfirmedChild
            sys.argv = ['run_entry.py', '--mirror', mirror2['mirror'], '--godot', str(stub_exe)]
            code = launch.main()
            check(code == 1 and children[-1].killed and not children[-1].exited, 'Unconfirmed child is not claimed exited')
            check(shared_lock.exists(), 'Unconfirmed child preserves shared lock and mirror')
            completions = sorted((fake_here / 'runs').glob('*/completion_receipt.json'))
            result = json.loads(completions[-1].read_text(encoding='utf-8'))
            check(result['lock_preserved'] and not result['owned_child_exit_confirmed'], 'Unconfirmed child writes explicit failure receipt')
        finally:
            launch.subprocess.Popen = old_popen; sys.argv = old_argv
    finally:
        prep.ROOT, prep.HERE, prep.git = original_root, original_here, original_git
    report = {'schema': 1, 'passed': True, 'checks': checks, 'check_count': len(checks),
              'method_receipts': method_receipts, 'stub_fixture_preserved': str(base),
              'actual_git_processes': 0, 'actual_godot_processes': 0, 'production_writes': 0,
              'gdscript_parsed_by_engine': False, 'engine_result': 'pending explicit one-entry validation'}
    prep.save(HERE / 'static_checks_receipt.json', report)
    print(json.dumps({'passed': True, 'checks': len(checks), 'receipt': str(HERE / 'static_checks_receipt.json')}, ensure_ascii=True))


if __name__ == '__main__': main()
