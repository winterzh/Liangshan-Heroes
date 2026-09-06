"""Archive the completed separation diagnostic; does not run an engine or change sources."""
from pathlib import Path
import argparse
import json
from archive_polish_m2c import Archive, ROOT


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    source = Path('scratchpad/separation_sections_diag')
    completed = source / 'resume_runs/20260906T110413889769Z'
    receipt = json.loads((ROOT / completed / 'receipt.json').read_bytes())
    assert receipt['complete'] and receipt['lock_released']
    assert receipt['live_before'] == receipt['live_after']
    assert receipt['protected_player_before'] == receipt['protected_player_after']
    assert receipt['old_failure_records_unchanged']
    assert all(item['analysis_valid'] for item in receipt['stages'])
    archive = Archive('separation_sections_20260906', args.apply)
    archive.tree(source, 'tool_sources', tools=True, images=False)
    archive.tree(source / 'generated', 'generated', tools=True, images=False)
    # Only source text from frozen/, never the private imported Godot project/cache.
    archive.tree(source / 'frozen', 'frozen_sources', tools=True, images=False)
    archive.tree(source / 'runs/20260906T104036739951Z', 'failed_import', recursive=True, tools=True, images=False)
    archive.tree(completed, 'completed', recursive=True, tools=True, images=False)
    for name in ('archive_separation_sections.py', 'archive_polish_m2c.py'):
        archive.add('scratchpad/' + name, 'archive_tools/' + name)
    result = archive.finish()
    assert result['bytes'] < 32 * 1024**2
    print(json.dumps(result))


if __name__ == '__main__':
    main()
