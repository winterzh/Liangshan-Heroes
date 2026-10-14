"""Hold the unchanged, independently admitted V16 host and record its real exit."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/campaign_progress_recovery_20261008'


def require(ok, message):
    if not ok:
        raise ValueError(message)


def plain(path):
    path = Path(os.path.abspath(path))
    for candidate in (path, *path.parents):
        try:
            info = candidate.lstat()
        except FileNotFoundError:
            continue
        require(not stat.S_ISLNK(info.st_mode) and not
                (getattr(info, 'st_file_attributes', 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT),
                'No linked paths: ' + str(candidate))
    return path


def pin(path):
    path = plain(path)
    data = path.read_bytes()
    return {'path': str(path), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}


def pinned_json(path):
    path = plain(path)
    raw = path.read_bytes()
    original_pin = {'path': str(path), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}
    document = json.loads(raw)
    require(pin(path) == original_pin, 'Document changed during read: ' + str(path))
    return document, original_pin


def new_json(path, value):
    path = plain(path)
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())


def main():
    require(__debug__ and os.name == 'nt', 'Windows with assertions enabled required')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-recipe', type=Path, required=True)
    parser.add_argument('--independent-review', type=Path)
    parser.add_argument('--work-root', type=Path, required=True)
    parser.add_argument('--observation-root', type=Path, required=True)
    parser.add_argument('--run', action='store_true')
    args = parser.parse_args()
    recipe, source_pin = pinned_json(args.source_recipe)
    require(recipe['schema'] == 'durable_v16_background_host_source_v1', 'Source recipe schema')
    for row in recipe['pins'].values():
        require(pin(row['path']) == row, 'Source drift: ' + row['path'])
    pins = recipe['pins']
    require(pins['launcher'] == pin(__file__) and pins['python'] == pin(sys.executable), 'Exact launcher and Python')
    require(plain(pins['producer']['path']) == ROOT / 'tools/run_durable_campaign_chain_v16.py', 'Original V16 producer')
    require(plain(pins['native_spec']['path']) == QA / 'DURABLE_CHAIN_SOURCE_SPEC_V16.json', 'Original V16 spec')
    require(plain(pins['native_review']['path']) == QA / 'DURABLE_CHAIN_INDEPENDENT_REVIEW_V16.json', 'Original V16 admission')
    work, observation = plain(args.work_root), plain(args.observation_root)
    require(not work.is_relative_to(ROOT) and not observation.is_relative_to(ROOT), 'External private directories')
    require(not work.exists() and not observation.exists() and not work.is_relative_to(observation)
            and not observation.is_relative_to(work), 'Two distinct fresh directories required')
    command = [pins['python']['path'], '-X', 'utf8', '-B', pins['producer']['path'],
               '--godot', pins['engine']['path'], '--baseline', pins['baseline']['path'],
               '--work-root', str(work), '--source-spec', pins['native_spec']['path'],
               '--independent-review', pins['native_review']['path'], '--run']
    if not args.run:
        print(json.dumps({'source_preflight': True, 'native_started': False, 'command': command}, ensure_ascii=False))
        return 0
    require(args.independent_review is not None, 'Exact independent launcher review required')
    review, review_pin = pinned_json(args.independent_review)
    require(review['schema'] == 'durable_v16_background_host_independent_review_v1'
            and review['independent'] is True and review['source_review_passed'] is True
            and review['approved_stages'] == ['launch_existing_v16_full_batch']
            and review['launcher_sha256'] == pins['launcher']['sha256']
            and review['source_recipe_sha256'] == source_pin['sha256'], 'Exact limited launcher admission')
    for row in [*pins.values(), source_pin, review_pin]:
        require(pin(row['path']) == row, 'Source drift immediately before launch: ' + row['path'])
    observation.mkdir(parents=True, exist_ok=False)
    started = dt.datetime.now(dt.timezone.utc).isoformat()
    with (observation / 'producer.stdout.log').open('xb') as stdout, (observation / 'producer.stderr.log').open('xb') as stderr:
        process = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr,
                                   shell=False, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            new_json(observation / 'host_started.json', {
                'schema': 'durable_v16_background_host_started_v1', 'started_utc': started,
                'wrapper_pid': os.getpid(), 'producer_pid': process.pid, 'command': command,
                'source_recipe': source_pin, 'independent_review': review_pin,
                'work_root': str(work), 'observation_root': str(observation),
                'owns_live_producer_Popen': True, 'overall_goal_qualified': False})
        finally:
            code = process.wait()
    new_json(observation / 'host_exit.json', {
        'schema': 'durable_v16_background_host_exit_v1', 'started_utc': started,
        'ended_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
        'wrapper_pid': os.getpid(), 'producer_pid': process.pid, 'command': command,
        'producer_exit_code': code, 'producer_process_terminal': True,
        'real_Popen_wait_completed': True, 'source_recipe': source_pin,
        'independent_review': review_pin, 'overall_goal_qualified': False})
    return 0 if code == 0 else 1


if __name__ == '__main__':
    raise SystemExit(main())
