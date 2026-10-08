"""Strict actual native data and closed-A custody helpers; no executable entry point."""
import hashlib
import json
from pathlib import Path
import re
import shutil

from durable_campaign_full_runtime import no_links, read, sha, write_new

CONTEXT = {'mode': 'campaign', 'level_id': 'level8', 'waves': 0}
ENVELOPE_FIELDS = {'magic', 'version', 'app', 'owner', 'revision', 'previous_sha256', 'payload_bytes', 'payload_sha256', 'payload'}


def file_pin(path):
    path = Path(path)
    no_links(path)
    return {'path': str(path), 'bytes': path.stat().st_size, 'sha256': sha(path)}


def envelope(path, magic, generation, previous):
    no_links(path)
    raw = Path(path).read_bytes()
    value = json.loads(raw.decode('utf-8-sig'))
    assert set(value) == ENVELOPE_FIELDS and all(type(v) is str for v in value.values())
    assert value['magic'] == magic and value['version'] == '1' and value['app'] == '5088120' and value['owner'] == '1'
    assert value['revision'] == str(generation) and value['previous_sha256'] == previous
    payload = value['payload'].encode('utf-8')
    assert value['payload_bytes'] == str(len(payload)) and value['payload_sha256'] == hashlib.sha256(payload).hexdigest()
    document = json.loads(value['payload'])
    assert type(document) is dict and type(document.get('generation')) is int and document['generation'] == generation
    pin = file_pin(path)
    assert pin['sha256'] == hashlib.sha256(raw).hexdigest(), 'Envelope changed after validation'
    return {**pin, 'document': document, 'raw_envelope': value}


def resolve_evidence_path(value, user):
    assert type(value) is str
    user = Path(user)
    no_links(user)
    if value.startswith('user://'):
        relative = value.removeprefix('user://')
        assert relative in {'daming_safe_retreat_v25/handoff_A.json', 'daming_safe_retreat_v25/handoff_B.json', 'daming_safe_retreat_v25/terminal_C.json'}, 'Unknown user evidence path'
        path = user / relative
        assert path.resolve().is_relative_to(user.resolve()), 'User evidence outside owned userdata'
    else:
        path = Path(value)
        assert path.is_absolute() and not value.startswith(('res://', 'http://', 'https://')), 'Absolute native evidence required'
    no_links(path)
    return path


def native_report(step, path, schema, case, expected_identity, role=None):
    assert step['process_terminal'] is True and type(step['exit_code']) is int and step['exit_code'] == 0
    assert type(step['engine_errors']) is int and step['engine_errors'] == 0
    assert type(step['pid']) is int and step['pid'] > 0 and re.fullmatch('[0-9a-f]{32}', step['nonce'])
    original = file_pin(path)
    report = read(path)
    assert type(report['pid']) is int and report['pid'] == step['pid']
    assert report['schema'] == schema and report['case'] == case and report['nonce'] == step['nonce']
    assert type(report['passed']) is bool and report['passed'] and type(report['checks']) is list and report['checks']
    assert all(type(v) is dict and type(v.get('passed')) is bool and v['passed'] for v in report['checks'])
    for key, value in expected_identity.items():
        assert type(report['trusted'].get(key)) is type(value) and report['trusted'][key] == value
    if role is not None:
        assert role in ['lu', 'shi'] and report['first_role'] == role
    for key in ['teleports', 'fixture_ticks', 'progress_injections']:
        assert type(report[key]) is int and report[key] == 0
    assert report['clock_acceleration'] is False and report['steam_reward_once_qualified'] is False
    user = Path(report['actual_user_data_dir'])
    no_links(user)
    profile = Path(step['profile'])
    no_links(profile)
    assert user.is_dir() and user.resolve().is_relative_to((profile / 'appdata').resolve())
    assert Path(report['private_profile']).resolve() == profile.resolve()
    report_path = Path(path)
    assert report_path.resolve().is_relative_to(Path(step['output']).resolve())
    assert type(report['evidence']) is list and report['evidence']
    seen = set()
    for row in report['evidence']:
        assert type(row) is dict and type(row.get('path')) is str and type(row.get('sha256')) is str
        assert re.fullmatch('[0-9a-f]{64}', row['sha256'])
        path = resolve_evidence_path(row['path'], user)
        assert path.is_file(), 'Native evidence file missing'
        assert path.resolve() not in seen, 'Duplicate evidence'
        seen.add(path.resolve())
        assert path.resolve().is_relative_to(Path(step['output']).resolve()) or path.resolve().is_relative_to(user.resolve())
        assert sha(path) == row['sha256']
    assert file_pin(original['path']) == original, 'Native report changed during validation'
    return report


def data_tree(scope):
    scope = Path(scope)
    no_links(scope)
    rows = []
    for path in sorted(scope.rglob('*')):
        no_links(path)
        if path.is_file():
            rows.append({**file_pin(path), 'relative': path.relative_to(scope).as_posix()})
    return rows


def data_directories(scope):
    no_links(scope)
    result = set()
    for path in Path(scope).rglob('*'):
        no_links(path)
        if path.is_dir(): result.add(path.relative_to(scope).as_posix())
    return result


def freeze_closed_a(step, report_path, expected_identity, role, destination):
    out = Path(report_path).parent
    packet_path, world_path = out / 'saved_packet.json', out / 'saved_world.json'
    original_pins = [file_pin(p) for p in [report_path, packet_path, world_path]]
    report = native_report(step, report_path, 'daming_campaign_durable_cross_process_report_v1',
                           'A_single_save', expected_identity, role)
    assert report['single_safe_disk_case_qualified'] is True and report['natural_victory_qualified'] is False
    assert report['local_terminal_readback_qualified'] is False and report['campaign_persistence_qualified'] is False
    user = Path(report['actual_user_data_dir'])
    scope = user / 'continue/v1'
    slot = envelope(scope / '5088120/1/record_0000000001.json', 'LH_CLASSIC_CONTINUE_SLOT', 1, '0' * 64)
    packet = slot['document']
    assert packet['context'] == CONTEXT and packet['resume_paused'] is True
    assert type(packet['binding']) is dict and packet['binding']['kind'] == 'uncredited'
    token = packet['binding']['token']
    assert type(token) is str and re.fullmatch('[0-9a-f]{32}', token)
    journal = envelope(scope / 'local_runs' / token / '5088120/1/record_0000000001.json',
                       'LH_LOCAL_CONTINUE_LIFECYCLE', 1, '0' * 64)
    active = journal['document']
    assert set(active) == {'schema', 'generation', 'token', 'context', 'scope', 'state', 'victory', 'progress_state', 'intent', 'progress_receipt'}
    assert active['schema'] == 'local_campaign_continue_lifecycle_v2' and active['token'] == token
    assert active['context'] == CONTEXT and active['state'] == 'active' and active['progress_state'] == 'none'
    assert active['victory'] is False and active['intent'] == {} and active['progress_receipt'] == {}
    assert journal['sha256'] == packet['binding']['receipt_sha256']
    assert active['scope'] == {'owner': '', 'engine_sha256': expected_identity['engine_binary_sha256'], 'content_version': expected_identity['content_version']}
    handoff_path = user / 'daming_safe_retreat_v25/handoff_A.json'
    handoff_pin = file_pin(handoff_path)
    handoff = read(handoff_path)
    assert handoff['schema'] == 'daming_safe_retreat_cross_process_handoff_v25' and handoff['mode'] == 'A_single_save'
    assert type(handoff['pid']) is int and handoff['pid'] == step['pid'] and handoff['nonce'] == step['nonce'] and handoff['first_role'] == role
    assert type(handoff['generation']) is int and handoff['generation'] == 1 and handoff['file_sha256'] == slot['sha256'] and handoff['packet'] == packet
    assert handoff['content_version'] == expected_identity['content_version'] and handoff['engine_sha256'] == expected_identity['engine_binary_sha256']
    assert handoff['ancestor_pids'] == [] and handoff['ancestor_nonces'] == []
    assert read(packet_path) == packet and read(world_path) == packet['world']
    destination = Path(destination)
    no_links(destination)
    before = data_tree(scope)
    assert {row['relative'] for row in before} == {'5088120/1/record_0000000001.json', 'local_runs/' + token + '/5088120/1/record_0000000001.json'}, 'A scope has pending/lock/foreign or extra generation files'
    expected_dirs = {'5088120', '5088120/1', 'local_runs', 'local_runs/' + token,
                     'local_runs/' + token + '/5088120', 'local_runs/' + token + '/5088120/1'}
    assert data_directories(scope) == expected_dirs, 'A scope has empty pending/foreign directories'
    destination.mkdir(parents=True, exist_ok=False)
    rows = []
    for row in before:
        source = Path(row['path'])
        target = destination / 'slot_scope' / row['relative']
        no_links(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        assert sha(target) == row['sha256'] and target.stat().st_size == row['bytes']
        rows.append({**file_pin(target), 'relative': row['relative']})
    frozen_handoff = destination / 'handoff_A.json'
    shutil.copyfile(handoff_path, frozen_handoff)
    assert file_pin(handoff_path) == handoff_pin and sha(frozen_handoff) == handoff_pin['sha256'] and before == data_tree(scope)
    assert data_directories(scope) == expected_dirs, 'Actual A directory shape changed during freeze'
    assert [file_pin(p) for p in [report_path, packet_path, world_path]] == original_pins, 'Actual A source evidence changed during freeze'
    value = {'schema': 'daming_durable_actual_a_frozen_v1', 'actual_pid': step['pid'], 'actual_nonce': step['nonce'],
             'user_relative_to_appdata': user.relative_to(Path(step['profile']) / 'appdata').as_posix(),
             'first_role': role, 'token': token, 'content_version': expected_identity['content_version'],
             'engine_sha256': expected_identity['engine_binary_sha256'], 'profile_files': rows,
             'a_report': original_pins[0], 'a_handoff': file_pin(frozen_handoff),
             'a_packet': original_pins[1], 'a_world': original_pins[2], 'a_slot': file_pin(destination / 'slot_scope/5088120/1/record_0000000001.json'),
             'actual_active_journal': journal, 'bare_CFG_or_profile_cache_copied': False,
             'source_process_successfully_closed': True, 'full_qualified': False}
    write_new(destination / 'manifest.json', value)
    return value


def copy_frozen_a_to_profile(frozen, user):
    user = Path(user)
    no_links(user)
    assert user.is_dir()
    scope = user / 'continue/v1'
    assert not scope.exists()
    expected = {v['relative']: v['sha256'] for v in frozen['profile_files']}
    assert len(expected) == len(frozen['profile_files']) == 2
    token = frozen['token']
    assert type(token) is str and re.fullmatch('[0-9a-f]{32}', token)
    assert set(expected) == {'5088120/1/record_0000000001.json', 'local_runs/' + token + '/5088120/1/record_0000000001.json'}
    for row in frozen['profile_files']:
        relative = Path(row['relative'])
        assert not relative.is_absolute() and not relative.drive and not relative.root and '..' not in relative.parts and relative.as_posix() == row['relative']
        assert (scope / relative).resolve().is_relative_to(scope.resolve())
        assert file_pin(row['path']) == {k: row[k] for k in ['path', 'bytes', 'sha256']}
    assert file_pin(frozen['a_handoff']['path']) == frozen['a_handoff']
    for row in frozen['profile_files']:
        source = Path(row['path'])
        no_links(source)
        assert sha(source) == row['sha256'] and source.stat().st_size == row['bytes']
        relative = Path(row['relative'])
        assert not relative.is_absolute() and not relative.drive and not relative.root and '..' not in relative.parts and relative.as_posix() == row['relative']
        target = scope / relative
        no_links(target)
        assert not target.exists()
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        assert sha(target) == row['sha256']
    target = user / 'daming_safe_retreat_v25/handoff_A.json'
    no_links(target)
    assert not target.exists()
    target.parent.mkdir(parents=True, exist_ok=True)
    source = Path(frozen['a_handoff']['path'])
    assert file_pin(source) == frozen['a_handoff']
    shutil.copyfile(frozen['a_handoff']['path'], target)
    assert sha(target) == frozen['a_handoff']['sha256']
    assert {v['relative']: v['sha256'] for v in data_tree(scope)} == expected
    for row in frozen['profile_files']:
        assert sha(row['path']) == row['sha256'] and Path(row['path']).stat().st_size == row['bytes']
    assert file_pin(source) == frozen['a_handoff']
