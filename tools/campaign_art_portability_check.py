"""Re-run the art audit in an isolated root with an exact read-input whitelist."""
from __future__ import annotations
import argparse
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

import campaign_direction4_coverage_audit as audit
import campaign_art_evidence as evidence

ROOT = Path(__file__).resolve().parents[1]


def run(output):
    reads = set()
    isolated_reads = set()
    external_reads = set()
    phase = {'name': 'capture', 'isolated_root': None}
    def hook(event, args):
        if event != 'open' or not args or not isinstance(args[0], (str, bytes, os.PathLike)): return
        path = Path(os.fsdecode(args[0])).resolve()
        if phase['name'] == 'capture' and path.is_relative_to(ROOT): reads.add(path)
        elif phase['name'] == 'isolated':
            if path.is_relative_to(ROOT): isolated_reads.add(path)
            if not path.is_relative_to(phase['isolated_root']): external_reads.add(path)
    sys.addaudithook(hook)
    baseline = audit.build_report()
    phase['name'] = 'copy'
    for relative in ['tools/campaign_direction4_coverage_audit.py', 'tools/campaign_art_evidence.py', 'tools/build_directional_spriteframes.py']:
        reads.add(ROOT / relative)
    inputs = [{'path': p.relative_to(ROOT).as_posix(), 'sha256': evidence.sha(p), 'bytes': p.stat().st_size}
              for p in sorted(reads) if p.is_file()]
    if any(row['path'].startswith('.godot/') for row in inputs): raise AssertionError('Cache unexpectedly read')
    with tempfile.TemporaryDirectory(prefix='campaign_art_portable_') as directory:
        target = Path(directory)
        for row in inputs:
            destination = target / row['path']
            if not destination.resolve().is_relative_to(target.resolve()): raise AssertionError('Copy path escape')
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / row['path'], destination)
            if evidence.sha(destination) != row['sha256']: raise AssertionError('Copied input drift')
        previous = audit.ROOT
        phase['isolated_root'] = target.resolve()
        phase['name'] = 'isolated'
        try:
            audit.ROOT = target
            isolated = audit.build_report()
        finally:
            audit.ROOT = previous
            phase['name'] = 'finished'
    unchanged = all(evidence.sha(ROOT / row['path']) == row['sha256'] for row in inputs)
    same = baseline['summary'] == isolated['summary']
    result = {'kind': 'campaign_art_portability_check', 'passed': same and unchanged and not external_reads,
              'baseline_summary': baseline['summary'], 'isolated_summary': isolated['summary'],
              'same_summary': same, 'source_inputs_unchanged': unchanged,
              'isolated_readback_to_original_root': [str(p) for p in sorted(isolated_reads)],
              'isolated_reads_outside_temporary_root': [str(p) for p in sorted(external_reads)],
              'input_count': len(inputs), 'input_bytes': sum(row['bytes'] for row in inputs),
              'inputs': inputs, 'godot_run': False, 'production_written': False,
              'scope': 'isolated local filesystem copy with no Godot cache, historical tree, Git or player state; not a clean Git checkout or runtime/visual acceptance'}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    result = run(args.out)
    print(json.dumps({key: value for key, value in result.items() if key != 'inputs'}, ensure_ascii=False, indent=2))
    return 0 if result['passed'] else 1


if __name__ == '__main__': raise SystemExit(main())
