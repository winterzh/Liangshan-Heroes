"""Run prepared body spans using the reviewed isolated diagnostic lifecycle."""
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import run_unit_remainder_diagnostic as runner
import run_stabilization_performance as guard


def main():
    guard.need('--prepared' in sys.argv, 'Explicit prepared private project required')
    requested = Path(sys.argv[sys.argv.index('--prepared') + 1])
    guard.no_links(requested)
    prepared = requested.resolve()
    guard.need((ROOT / '.godot/stabilization_performance').resolve() in prepared.parents,
               'Prepared project outside dedicated private root')
    manifest = json.loads((prepared / 'preparation.json').read_text(encoding='utf-8'))
    guard.need(manifest['source_head'] == 'c0285f91d4131e7631707fa59903d4b61fd460bb', 'Only frozen original baseline allowed')
    for name, expected in manifest['body_tools_sha256'].items():
        guard.need(guard.sha((HERE / name).read_bytes()) == expected, 'Prepared body tool drift: ' + name)
    for name, expected in manifest['host_helpers_sha256'].items():
        guard.need(guard.sha((ROOT / 'tools' / name).read_bytes()) == expected, 'Prepared helper drift: ' + name)
    if '--run' in sys.argv:
        guard.need(not (prepared / 'receipt.json').exists(), 'Never overwrite an existing native attempt')
        for name in manifest['body_tools_sha256']:
            with (prepared / ('executed_' + name + '.txt')).open('xb') as stream: stream.write((HERE / name).read_bytes())
        for name in manifest['host_helpers_sha256']:
            with (prepared / ('executed_' + name + '.txt')).open('xb') as stream: stream.write((ROOT / 'tools' / name).read_bytes())
    code = runner.main()
    if code != 0 or '--run' not in sys.argv: return code
    receipt_bytes = (prepared / 'receipt.json').read_bytes()
    receipt = json.loads(receipt_bytes.decode('utf-8'))
    guard.need(receipt['complete'] and receipt['player_unchanged'] and receipt['lock_released'], 'All native guards required')
    result = {'native_receipt_sha256': guard.sha(receipt_bytes), 'source_head': manifest['source_head'],
              'body_tools_sha256': manifest['body_tools_sha256'], 'modes': {}, 'production_optimization_adopted': False}
    for mode in ('timed', 'clockless'):
        observed = json.loads((prepared / (mode + '_observer.json')).read_text(encoding='utf-8'))
        analysis = json.loads((prepared / (mode + '_analysis.json')).read_text(encoding='utf-8'))
        calls = sum(x['calls'] for x in analysis['scope_rows'])
        guard.need(observed['observer_hook_calls'] == 2 * calls, 'Every entered measured scope must close once')
        for step in observed['steps']:
            counts = [step['scopes'].get(scope, [0])[0] for scope in manifest['inline_spans']]
            guard.need(counts[0] == step['scopes']['unit._phys_body'][0], 'Entry span does not cover every Unit invocation')
            guard.need(counts == sorted(counts, reverse=True), 'Sequential inline spans skipped or repeated')
        result['modes'][mode] = {'physics_steps': analysis['physics_steps'], 'presented_frames': analysis['presented_frames'],
            'hooks': observed['observer_hook_calls'], 'all_scope_pairs_closed': True,
            'all_root_entries_covered': True, 'inline_span_count_order_valid': True,
            'ledger_observed_us_per_step': observed['observer_measured_ledger_us'] / analysis['physics_steps'] if mode == 'timed' else None,
            'nested_time_conservation': analysis['nested_time_conservation'],
            'scope_rows': analysis['scope_rows']}
    result['cost_note'] = 'Ledger intervals are observed instrumentation work, not a complete overhead estimate and not subtractable. Timed and clockless are separate combat runs. No FPS benefit claim.'
    guard.save(prepared / 'body_analysis.json', result)
    print(json.dumps({'body_analysis': True, 'path': str(prepared / 'body_analysis.json')}), flush=True)
    return 0


if __name__ == '__main__': raise SystemExit(main())
