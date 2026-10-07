"""Restore only this task's two candidates after the fixed night wrap deadline."""
from pathlib import Path
import argparse, datetime, hashlib, json, subprocess

ROOT = Path('E:/ChatGPT/水浒').resolve()
BACKUP = Path('E:/ChatGPT/daming_safe_retreat_v25_preapply_20261008')
PROPOSAL = ROOT / 'qa/zhu_wounded_20261005/proposals/daming_safe_retreat_v25'
DEADLINE = datetime.datetime(2026, 10, 7, 22, tzinfo=datetime.timezone.utc)
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
    code = ("@(Get-CimInstance Win32_Process | Where-Object { "
            "$_.Name -match 'python|Godot' } | Select-Object ProcessId,ParentProcessId,Name,CommandLine) "
            "| ConvertTo-Json -Depth 3 -Compress")
    raw = subprocess.check_output(['powershell.exe', '-NoProfile', '-Command', code], text=True).strip()
    rows = json.loads(raw) if raw else []
    if isinstance(rows, dict):
        rows = [rows]
    markers = ['run_daming_safe_retreat_v25', 'run_daming_admit_v24',
               'qa-world-restore-20261007', 'daming_safe_retreat_cross_process']
    return [row for row in rows if any(marker in (row.get('CommandLine') or '') for marker in markers)]

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
    assert terminal_path.is_relative_to(Path('E:/ChatGPT/qa-world-restore-20261007').resolve())
    terminal_raw = terminal_path.read_bytes()
    terminal = json.loads(terminal_raw.decode('utf-8'))
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
    # All byte and live-process conditions close before either file is written.
    for path, target, original, before, after in replacements:
        target.write_bytes(original)
        assert sha(target.read_bytes()) == before
    for path, expected in JSON4.items():
        assert sha((ROOT / path).read_bytes()) == expected
    receipt = {
        'schema': 'night_unqualified_candidate_exact_restoration_20261008',
        'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'base_commit': git('rev-parse', 'HEAD'), 'terminal_receipt': str(terminal_path),
        'terminal_receipt_sha256': sha(terminal_raw), 'owned_consumers_live_at_restore': [],
        'restored_files': [{'path': path, 'candidate_sha256': after, 'restored_sha256': before}
                           for path, target, original, before, after in replacements],
        'qualified_JSON4_unchanged': True, 'candidate_QA_preserved': True,
        'original_failures_preserved': True, 'git_reset_or_stash_used': False,
        'full_v25_qualified': False,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('x', encoding='utf-8') as handle:
        json.dump(receipt, handle, ensure_ascii=False, indent=2)
    print(json.dumps({'restored_files': 2, 'qualified_JSON4_unchanged': True, 'receipt': str(args.output)}))

if __name__ == '__main__':
    main()
