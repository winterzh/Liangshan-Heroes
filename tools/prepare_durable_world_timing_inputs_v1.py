"""Source-only full V12 inputs with one passive world timing overlay."""
import re
from pathlib import Path

from prepare_durable_campaign_full_inputs_v7 import prepare as previous_prepare
from durable_campaign_full_runtime import read, sha
from durable_campaign_full_evidence_v2 import file_pin
from run_durable_campaign_chain_v12 import canonical, verify_pin

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/campaign_progress_recovery_20261008'
FOLDER = QA / 'world_matrix_timing_candidate_v1'


def prepare():
    old = previous_prepare()
    saved = read(QA / 'DURABLE_FULL_SOURCE_INPUTS_V7.json')
    assert old == saved['spec'] and canonical(old) == saved['source_inputs_sha256']
    manifest = read(FOLDER / 'SOURCE.json')
    assert manifest['schema'] == 'durable_world_passive_timing_source_v1'
    for row in [manifest['candidate'], manifest['predecessor'], *manifest['actual_timeout_evidence']]:
        verify_pin(row)
    runtime_path = 'tools/daming_campaign_world_negative_v1.gd'
    original = next(row for row in old['runtime_and_harness_overlays'] if row['runtime_path'] == runtime_path)
    assert {k: original[k] for k in ['path', 'bytes', 'sha256']} == manifest['predecessor']
    assert manifest['runtime_path'] == runtime_path and manifest['row_count_required'] == 264
    assert manifest['world_timeout_seconds_unchanged'] == 1200 and manifest['approved_stages'] == []
    assert manifest['native_started'] is False and manifest['full_goal_qualified'] is False
    candidate = Path(manifest['candidate']['path']).read_bytes()
    predecessor = Path(manifest['predecessor']['path']).read_bytes()
    newline = '\r\n' if b'\r\n' in predecessor else '\n'
    source = candidate.decode('utf-8')
    helper = ('func _timing_mark(stage: String, case_id: String = "", route_name: String = "") -> void:' + newline
              + '\tprint("DURABLE_WORLD_TIMING_V1 ", JSON.stringify({"schema": "durable_world_timing_v1", "pid": OS.get_process_id(), "nonce": nonce, "elapsed_usec": Time.get_ticks_usec() - _timing_started_usec, "stage": stage, "case": case_id, "route": route_name, "rows": rows.size(), "checks": checks.size()}))' + newline + newline)
    assert source.count(helper) == 1
    stripped = source.replace(helper, '', 1)
    retained = []
    calls = []
    for line in stripped.splitlines(keepends=True):
        body = line.strip()
        if body in ['var _timing_started_usec: int = 0', '_timing_started_usec = Time.get_ticks_usec()']:
            continue
        if body.startswith('_timing_mark('):
            assert re.fullmatch(r'_timing_mark\("[a-z_:]+"(?:, spec\.id, route_name)?\)|_timing_mark\("check:" \+ label\)', body)
            calls.append(body)
            continue
        retained.append(line)
    assert ''.join(retained).encode('utf-8') == predecessor
    assert len(calls) == 17 and calls.count('_timing_mark("core_prepare_begin")') == 2
    assert '_timing_mark("row_begin", spec.id, route_name)' in calls
    assert '_timing_mark("row_end", spec.id, route_name)' in calls
    new = dict(old)
    new['schema'] = 'daming_durable_full_world_timing_inputs_v1'
    new['runtime_and_harness_overlays'] = [
        {**manifest['candidate'], 'runtime_path': runtime_path} if row['runtime_path'] == runtime_path else row
        for row in old['runtime_and_harness_overlays']]
    assert len(new['runtime_and_harness_overlays']) == 26
    new['metadata_and_predecessor_reviews'] = old['metadata_and_predecessor_reviews'] + [
        file_pin(FOLDER / 'SOURCE.json'), file_pin(FOLDER / 'README.md'), file_pin(Path(__file__)),
        *manifest['actual_timeout_evidence']]
    new['passive_world_timing'] = manifest['candidate']
    new['original_world_predicates_retained'] = True
    new['new_full_producer_review_required'] = True
    assert new['execution_contract'] == old['execution_contract']
    return new
