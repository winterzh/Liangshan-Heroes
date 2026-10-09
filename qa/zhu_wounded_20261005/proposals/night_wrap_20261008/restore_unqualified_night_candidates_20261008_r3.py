"""Restore only this task's two candidates after the fixed night wrap deadline."""
from pathlib import Path
import argparse, datetime, hashlib, json, os, subprocess, sys

if sys.flags.optimize:
    raise RuntimeError("Optimized Python would disable restoration assertions; refusing execution")

ROOT = Path('E:/ChatGPT/水浒').resolve()
BACKUP = Path('E:/ChatGPT/daming_safe_retreat_v25_preapply_20261008')
PROPOSAL = ROOT / 'qa/zhu_wounded_20261005/proposals/daming_safe_retreat_v25'
DEADLINE = datetime.datetime(2026, 10, 7, 22, tzinfo=datetime.timezone.utc)
LATEST_RUN = Path('E:/ChatGPT/qa-world-restore-20261007/daming_safe_retreat_v25s_r2f_offline_prefix_c_71d4275a').resolve()
LATEST_RECEIPT_SHA = '8ef980467ddebaff0da48819f2771ff38713e20806a5469160a7c0c20a6613c4'
LATEST_PRODUCER_SHA = '2f077e7903cd94c69826eee5f171e2f341163268b91676cf6104a70cc5ca8c61'
CANDIDATE_SHA = 'aef6fdce01ecbce31537a40773ccb0608411d4ea9d73616557d41ac0d9b0fd02'
KNOWN_OWN_PIDS = {217168, 217012, 200340, 216520, 204192, 217676, 217440, 217628,
                  220144, 211072, 217300, 207108, 206868, 218264} 
EXPECTED = {
    'scripts/run_battle_world_core.gd': (
        '621426f2714207dd69fb66981dbf73f34b9b9a1637cd890b23fb53d4a39fd571',
        '92b2bdac0058f9e1642d1b991c3ca353e902481d8daff990388e377597df87b1'),
    'scripts/run_level8_unit_contract.gd': (
        'abfa6c3ddeede8116324880e44000639df4e2c2391ae1cd1e583e09fb220d37c',
        'b2f52bcce60b27507b498a6d32e45b5cadd3409030fcd2e1024c78dac90e90d5'),
}
JSON4 = {
    'scripts/run_snapshot_store.gd': '581e638b8f0ce7cb24d5533b03ee94b99732c5cffcbf373b1a5a69a1618d8251',
    'scripts/run_slot_store.gd': 'd67fe7794f23fe1bda3d74c7e284ba6b90d2cb488a5d35cb1a187eea77fa3532',
    'scripts/run_scenery_json_boundary.gd': '476ee2ee83a513d29a0db04b5dc08eb5a3dcd6895a036697ed368b28c5d5c6ea',
    'scripts/run_scenery_json_boundary.gd.uid': '9f13d4502be15ab7149a43832ca61aaa0622a47e769a72f55d23a6bc29c0523d',
}

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT).decode('utf-8').strip()

def owned_process_rows():
    code = ("[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); @(Get-CimInstance Win32_Process | Where-Object { "
            "$_.Name -match 'python|Godot' } | Select-Object ProcessId,ParentProcessId,Name,CommandLine) "
            "| ConvertTo-Json -Depth 3 -Compress")
    raw = subprocess.check_output(['powershell.exe', '-NoProfile', '-Command', code], encoding='utf-8', errors='strict').strip()
    rows = json.loads(raw) if raw else []
    if isinstance(rows, dict):
        rows = [rows]
    markers = ['run_daming_safe_retreat_v25', 'run_daming_admit_v24',
               'qa-world-restore-20261007', 'daming_safe_retreat_cross_process']
    return [row for row in rows if row.get('ProcessId') in KNOWN_OWN_PIDS or any(marker in (row.get('CommandLine') or '') for marker in markers)]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--terminal-receipt', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert datetime.datetime.now(datetime.timezone.utc) >= DEADLINE, '06:00 wrap not reached'
    assert args.output.is_absolute() and not args.output.exists(), 'fresh absolute output required'
    assert git('branch', '--show-current') == 'codex/sync-20260905-stable'
    assert git('remote', 'get-url', 'origin') == 'https://github.com/winterzh/Liangshan-Heroes.git'
    assert not git('diff', '--cached', '--name-only'), 'do not mix another index'
    terminal_path = args.terminal_receipt.resolve(strict=True)
    assert terminal_path == LATEST_RUN / 'receipt.json', 'not the exact latest task receipt'
    terminal_raw = terminal_path.read_bytes()
    assert sha(terminal_raw) == LATEST_RECEIPT_SHA, 'latest receipt drift'
    terminal = json.loads(terminal_raw.decode('utf-8'))
    assert terminal.get('schema') == 'daming_safe_retreat_prefix_c_exploration_batch_v25s_r2f'
    assert terminal.get('producer_sha256') == LATEST_PRODUCER_SHA and Path(terminal['run']).resolve() == LATEST_RUN
    assert terminal.get('complete') is False and terminal.get('failure') == {
        'type': 'BatchFailure', 'message': 'foreign_engine_resumed; entire batch/profile preserved, no retry'}
    assert not terminal.get('finalization_failures') and not terminal.get('lock_audit_failure')
    candidate_path = ROOT / 'qa/zhu_wounded_20261005/safe_retreat_candidate_v25x1.json'
    assert sha(candidate_path.read_bytes()) == CANDIDATE_SHA
    assert terminal['candidate_source_bridge']['receipt_sha256'] == CANDIDATE_SHA
    assert terminal['candidate_source_bridge']['files'] == json.loads(candidate_path.read_text(encoding='utf-8'))['files']
    pointer = json.loads(Path('E:/ChatGPT/gao_scenery_v20_handoff.json').read_text(encoding='utf-8'))
    assert pointer['backend_session'] is None and pointer['current_execution']['terminal'] is True
    assert Path(pointer['current_execution']['run']).resolve() == LATEST_RUN
    assert pointer['current_execution']['python_pid'] == 206868
    assert all(step.get('process_terminal') is True for step in terminal['steps'] if step.get('pid'))
    ended = datetime.datetime.fromisoformat(terminal['finished_utc'])
    assert ended.tzinfo is not None and ended <= datetime.datetime.now(datetime.timezone.utc)
    assert terminal.get('overall_v25_qualified') is False, 'full-qualified candidate must not be restored'
    assert terminal.get('lock_released') is True and terminal.get('finished_utc'), 'terminal receipt not flushed'
    assert not owned_process_rows(), 'a task producer or native input consumer is still live'
    applied = json.loads((BACKUP / 'applied.json').read_text(encoding='utf-8'))
    assert {row['path'] for row in applied['files']} == set(EXPECTED)
    for path, expected in JSON4.items():
        assert sha((ROOT / path).read_bytes()) == expected
        assert sha(subprocess.check_output(['git', 'show', 'HEAD:' + path], cwd=ROOT)) == expected
    replacements = []
    for path, (before, after) in EXPECTED.items():
        target = (ROOT / path).resolve(strict=True)
        assert target.is_relative_to(ROOT)
        original = (BACKUP / path).read_bytes()
        assert sha(original) == before
        assert (PROPOSAL / 'original' / path).read_bytes() == original
        assert sha(subprocess.check_output(['git', 'show', 'HEAD:' + path], cwd=ROOT)) == before
        proposed = (PROPOSAL / 'proposed' / path).read_bytes()
        assert sha(proposed) == after and target.read_bytes() == proposed
        replacements.append((path, target, original, before, after))
    # The result destination is created and flushed before either runtime file is written.
    args.output.parent.mkdir(parents=True, exist_ok=True)
    receipt = {'schema': 'night_unqualified_candidate_exact_restoration_r3_20261008',
               'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'base_commit': git('rev-parse', 'HEAD'), 'terminal_receipt': str(terminal_path),
               'terminal_receipt_sha256': sha(terminal_raw), 'complete': False,
               'mutations_started': False, 'restored_files': [], 'failures': [],
               'candidate_QA_preserved': True, 'original_failures_preserved': True,
               'git_reset_or_stash_used': False, 'full_v25_qualified': False}
    failure = None
    with args.output.open('x+', encoding='utf-8') as handle:
        json.dump(receipt, handle, ensure_ascii=False, indent=2)
        handle.flush(); os.fsync(handle.fileno())
        try:
            assert not owned_process_rows(), 'owned consumer resumed before mutation'
            receipt['mutations_started'] = True
            for path, target, original, before, after in replacements:
                assert sha(target.read_bytes()) == after, 'source changed after preflight: ' + path
                target.write_bytes(original)
                assert sha(target.read_bytes()) == before
            for path, expected in JSON4.items():
                assert sha((ROOT / path).read_bytes()) == expected
            receipt['qualified_JSON4_unchanged'] = True
            receipt['complete'] = True
        except BaseException as exc:
            failure = exc
            receipt['failures'].append({'type': type(exc).__name__, 'message': str(exc)})
        finally:
            for path, target, original, before, after in replacements:
                try:
                    actual = sha(target.read_bytes())
                    receipt['restored_files'].append({'path': path, 'candidate_sha256': after,
                        'expected_restored_sha256': before, 'actual_sha256': actual,
                        'restored': actual == before, 'candidate_retained_in_QA': sha((PROPOSAL / 'proposed' / path).read_bytes()) == after,
                        'original_retained_in_QA': sha((PROPOSAL / 'original' / path).read_bytes()) == before,
                        'original_backup_retained': sha((BACKUP / path).read_bytes()) == before})
                except BaseException as exc:
                    receipt['complete'] = False
                    receipt['failures'].append({'path': path, 'type': type(exc).__name__, 'message': str(exc)})
            receipt['complete'] = bool(receipt['complete'] and not receipt['failures']
                and len(receipt['restored_files']) == len(EXPECTED)
                and all(row.get('restored') is True and row.get('candidate_retained_in_QA') is True
                        and row.get('original_retained_in_QA') is True and row.get('original_backup_retained') is True
                        for row in receipt['restored_files']))
            receipt['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
            try:
                handle.seek(0); handle.truncate()
                json.dump(receipt, handle, ensure_ascii=False, indent=2)
                handle.flush(); os.fsync(handle.fileno())
            except BaseException as exc:
                emergency = args.output.with_name(args.output.name + '.finalization_failure.json')
                receipt['complete'] = False
                receipt['failures'].append({'type': type(exc).__name__, 'message': str(exc), 'stage': 'receipt_flush'})
                try:
                    with emergency.open('x', encoding='utf-8') as emergency_handle:
                        json.dump(receipt, emergency_handle, ensure_ascii=False, indent=2)
                finally:
                    print(json.dumps(receipt, ensure_ascii=False))
                raise
    print(json.dumps({'complete': receipt['complete'], 'restored_files': receipt['restored_files'], 'receipt': str(args.output)}))
    if failure is not None:
        raise failure
    assert receipt['complete'] is True and all(row['restored'] for row in receipt['restored_files'])

if __name__ == '__main__':
    main()
