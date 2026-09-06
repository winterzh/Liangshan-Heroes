"""Tiny private-import counterexamples. Never invokes Git or a real executable."""
import ast
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile

sys.dont_write_bytecode = True
import private_import as imp
import run_entry as entry


def main():
    checks = []
    def check(ok, name):
        if not ok: raise AssertionError(name)
        checks.append(name)
    def rejects(callback, name):
        try: callback()
        except (RuntimeError, OSError): checks.append(name); return
        raise AssertionError(name)
    for name in ('private_import.py', 'run_entry.py', 'import_static_checks.py'):
        ast.parse((imp.HERE / name).read_text(encoding='utf-8')); check(True, 'Python AST ' + name)
    base = Path(tempfile.mkdtemp(prefix='import_stub_', dir=imp.HERE))
    mirror = base / 'mirror'; mirror.mkdir()
    (mirror / 'scripts').mkdir()
    (mirror / 'scripts/a.gd').write_bytes(b'class_name A\nextends Node\n')
    before = imp.source_manifest(mirror)
    allowed = imp.missing_uids(before)
    check(allowed == {'scripts/a.gd.uid': 'scripts/a.gd'}, 'Missing UID list derives only from existing scripts without a sidecar')
    uid = mirror / 'scripts/a.gd.uid'; uid.write_bytes(b'uid://bc2\r\n')
    after, generated = imp.accept_sources(mirror, before, allowed)
    check(generated['scripts/a.gd.uid']['sha256'] == imp.sha(uid.read_bytes()), 'Generated UID records actual CRLF raw SHA')
    for raw in (b'uid://ab', b'uid://zz', b'uid://8888888888888', b'uid://b\nchanged'):
        uid.write_bytes(raw)
        rejects(lambda: imp.accept_sources(mirror, before, allowed), 'Reject noncanonical UID ' + repr(raw))
    uid.write_bytes(b'uid://bc2\n')
    unknown = mirror / 'unknown.gd.uid'; unknown.write_bytes(b'uid://b')
    rejects(lambda: imp.accept_sources(mirror, before, allowed), 'Unknown root UID source rejected'); unknown.unlink()
    unknown = mirror / 'scripts/extra.gd'; unknown.write_bytes(b'extends Node\n')
    rejects(lambda: imp.accept_sources(mirror, before, allowed), 'Unknown nested source rejected'); unknown.unlink()
    (mirror / 'new_empty_dir').mkdir()
    rejects(lambda: imp.accept_sources(mirror, before, allowed), 'Unknown empty source directory rejected'); (mirror / 'new_empty_dir').rmdir()
    script = mirror / 'scripts/a.gd'; original = script.read_bytes(); script.write_bytes(original + b'#drift\n')
    rejects(lambda: imp.accept_sources(mirror, before, allowed), 'Existing source byte drift rejected'); script.write_bytes(original)
    rejects(lambda: imp.accept_sources(mirror, before, {'unknown.uid':'scripts/a.gd'}), 'Forged UID allowance rejected')
    old_walk = imp.os.walk
    def failed_walk(*args, **kwargs):
        kwargs['onerror'](OSError('stub access denied'))
        return iter(())
    try:
        imp.os.walk = failed_walk
        rejects(lambda: imp.source_manifest(mirror), 'os.walk enumeration error fails closed')
    finally: imp.os.walk = old_walk
    cache = mirror / '.godot/global_script_class_cache.cfg'; cache.parent.mkdir()
    classraw = b'list=[{"path": "res://scripts/a.gd", "class": &"A", "base": &"Node"}]\n'
    cache.write_bytes(classraw)
    declarations = [{'path':'scripts/a.gd','class':'A','base':'Node'}]
    firstpin = imp.class_cache_pin(mirror, declarations)
    cache.write_bytes(classraw.replace(b'list=[', b'list = [\n'))
    newpin = imp.class_cache_pin(mirror, declarations)
    check(firstpin['sha256'] != newpin['sha256'], 'Engine class-cache reformat is semantically verified and records actual new bytes')
    for bad in (classraw.replace(b'&"A"',b'&"B"'), classraw.replace(b'&"Node"',b'&"Control"'), b'list=[]\n', classraw.replace(b'scripts/a.gd',b'scripts/unknown.gd')):
        cache.write_bytes(bad)
        rejects(lambda: imp.class_cache_pin(mirror,declarations), 'Changed/dropped/unknown frozen class rejected ' + imp.sha(bad)[:8])
    cache.write_bytes(classraw)
    icon = mirror / 'icon.svg'; icon.write_bytes(b'frozen-icon\n')
    dest = mirror / '.godot/imported/icon.ctex'; dest.parent.mkdir(); dest.write_bytes(b'new-cache')
    md5 = mirror / '.godot/imported/icon.md5'
    source_md5 = hashlib.md5(icon.read_bytes()).hexdigest(); dest_md5 = hashlib.md5(dest.read_bytes()).hexdigest()
    md5raw = ('source_md5="' + source_md5 + '"\ndest_md5="' + dest_md5 + '"\n').encode(); md5.write_bytes(md5raw)
    associations = [{'source':'icon.svg', 'source_md5':source_md5, 'destinations':['.godot/imported/icon.ctex'], 'md5_sidecars':['.godot/imported/icon.md5']}]
    rows, proofs = imp.cache_pins(mirror, associations)
    check(len(rows) == 2 and proofs[0]['destination_md5'] == dest_md5, 'New icon output and MD5 bytes frozen after both associations match')
    md5.write_bytes(md5raw.replace(source_md5.encode(),b'0'*32))
    rejects(lambda: imp.cache_pins(mirror,associations), 'Old icon source MD5 rejected'); md5.write_bytes(md5raw)
    dest.write_bytes(b'corrupt-new-cache')
    rejects(lambda: imp.cache_pins(mirror,associations), 'New cache bytes fail destination MD5'); dest.write_bytes(b'new-cache')
    normal = base / 'Godot.exe'; normal.write_bytes(b'MZ stub no executable code')
    console = base / 'Godot.console.exe'; console.write_bytes(b'MZ stub no executable code')
    check(imp.executable(normal) == normal.resolve(), 'Actual non-console filename accepted for stub validation')
    rejects(lambda: imp.executable(console), 'Console forwarding executable rejected')
    underscore_console = base / 'Godot_v4.6.3-stable_win64_console.exe'; underscore_console.write_bytes(b'MZ stub no executable code')
    rejects(lambda: imp.executable(underscore_console), 'Actual Godot underscore console wrapper filename rejected')
    original_env = dict(entry.os.environ)
    env = entry.environment(mirror, base / 'env', 'clockless')
    check(dict(entry.os.environ) == original_env, 'Parent environment unchanged')
    check(all(env.get(key) == original_env.get(key) for key in ('HOME','USERPROFILE','TMP','TEMP','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME')), 'HOME and unrelated user/temp environment no longer overridden')
    check(env['APPDATA'].startswith(str(base / 'env/profile')) and env['LOCALAPPDATA'].startswith(str(base / 'env/profile')), 'Only Windows app data paths redirected privately')
    # import_once itself, using Python stubs for all process and large-manifest operations.
    original_state = {name: getattr(imp,name) for name in ('HERE','ROOT','verify_plan','source_manifest','accept_sources','class_cache_pin','cache_pins','read_json')}
    old_entry = {name:getattr(entry,name) for name in ('godot_process_ids','mirror_sources')}
    original_popen = imp.subprocess.Popen
    shared = base / 'shared'; shared.mkdir(); (shared / '.godot').mkdir()
    lock = shared / '.godot/redraw_rejection_source.lock'
    children = []
    fixture_original = {'class_cache_frozen_declarations':declarations,'derived_cache_files':[firstpin], 'source_files':before['source_files']}
    class Child:
        pid = 434343
        def __init__(self,*args,**kwargs):
            self.exited=False; self.killed=False; self.waits=0; children.append(self)
        def wait(self,timeout):
            self.waits += 1
            if self.waits == 1: raise KeyboardInterrupt()
            self.exited=True; return -9
        def kill(self): self.killed=True
        def poll(self): return -9 if self.exited else None
    try:
        imp.HERE=base; imp.ROOT=shared
        imp.verify_plan=lambda plan:(mirror,copy.deepcopy(fixture_original))
        imp.source_manifest=lambda mirror:before
        imp.accept_sources=lambda *args:(before,{})
        entry.mirror_sources=lambda *args:'stub pinned'
        entry.godot_process_ids=lambda:[]
        imp.subprocess.Popen=Child
        def plan(value):
            return {'import_plan_sha256':value*64,'source_before':before,'missing_script_uids':allowed,'materialization_receipt_sha256':'m'*64}
        code = imp.import_once(plan('1'),normal,30)
        check(code == 1 and children[-1].killed and children[-1].exited and not lock.exists(), 'Interrupted exact import handle killed/waited; confirmed exit releases owned lock')
        class Unconfirmed(Child):
            def wait(self,timeout):
                self.waits += 1
                if self.waits == 1: raise KeyboardInterrupt()
                raise imp.subprocess.TimeoutExpired('stub',timeout)
        imp.subprocess.Popen=Unconfirmed
        code=imp.import_once(plan('2'),normal,30)
        check(code == 1 and lock.exists(), 'Unconfirmed owned import exit retains shared lock')
        receipt=json.loads((base/'imports'/('2'*12)/'import_receipt.json').read_text())
        check(not receipt['owned_child_exit_confirmed'] and not receipt['post_import_pins_written'], 'Unconfirmed import preserves failure and writes no completed pins')
        lock.unlink()  # Only this tiny stub-owned lock, never the real shared lock.
        scan=iter([[],[545454],[]]); entry.godot_process_ids=lambda:next(scan)
        count=len(children)
        code=imp.import_once(plan('3'),normal,30)
        check(code == 1 and len(children) == count and not lock.exists(), 'Foreign Godot at actual Popen boundary blocks child launch')
    finally:
        for name,value in original_state.items(): setattr(imp,name,value)
        for name,value in old_entry.items(): setattr(entry,name,value)
        imp.subprocess.Popen=original_popen
    report={'passed':True,'check_count':len(checks),'checks':checks,'stub':str(base),'actual_godot_processes':0,'actual_git_processes':0,'production_writes':0}
    imp.save(imp.HERE/'import_static_receipt.json',report)
    print(json.dumps({'passed':True,'checks':len(checks),'actual_godot_processes':0}))


if __name__ == '__main__': main()
