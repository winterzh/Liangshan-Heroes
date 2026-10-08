"""Fresh isolated read-only old/new audit comparison, not a campaign matrix."""
import argparse
import ast
import datetime as dt
import json
from pathlib import Path
import sys
import uuid
from PIL import Image

from run_campaign_pending_terminal_ui_v5 import Suite as FixedEvidenceSuite, require, load_fixed_document
from run_durable_campaign_chain_v9 import source_spec as durable_spec, canonical, verify_pin, identity_module
from durable_campaign_full_runtime import FrozenProject, OwnedSerialBatch, inventory, no_links, read, sha, write_new
from durable_campaign_full_evidence_v2 import file_pin
import run_steam_integration_qa as native

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'qa/campaign_progress_recovery_20261008'
R5 = QA / 'final_durable_component_transport_v1_r5/daming_campaign_component_negative_v1.gd'
R6 = QA / 'final_durable_component_audit_v1_r6/daming_campaign_component_negative_v1.gd'
PRELIMINARY = R6.parent / 'COMPONENT_AUDIT_PRELIMINARY_REVIEW_R6.json'
PROBE = ROOT / 'tools/campaign_component_audit_benchmark_v2.gd'
PACKET = QA / 'actual_timed_out_durable_chain_v9/steps/lu_a_single_save/A_single_save/saved_packet.json'
SCOPE = 'read_only_component_audit_equivalence_and_cost_benchmark'


def source_spec(args):
    spec = durable_spec(args)
    review = read(PRELIMINARY)
    require(review['independent'] is True and review['static_api_closure_passed'] is True and review['approved_stages'] == [], 'Exact preliminary R6 source admission')
    manifest = read(R6.parent / 'SOURCE.json')
    require(manifest['candidate'] == file_pin(R6) and manifest['predecessor'] == file_pin(R5), 'Exact original and candidate audit sources')
    inputs = json.loads(json.dumps(spec['inputs']))
    for path, relative in [(R5, 'tools/audit_original_r5.gd'), (R6, 'tools/audit_candidate_r6.gd'), (PROBE, 'tools/' + PROBE.name)]:
        require(relative not in {row['runtime_path'] for row in inputs['runtime_and_harness_overlays']}, 'Unique read-only audit alias')
        inputs['runtime_and_harness_overlays'].append({**file_pin(path), 'runtime_path': relative})
    helpers = [Path(__file__), PROBE, R5, R6, PRELIMINARY, R6.parent / 'SOURCE.json', PACKET,
               ROOT / 'tools/run_campaign_pending_terminal_ui_v5.py', QA / 'PENDING_TERMINAL_UI_SOURCE_SPEC_V5.json',
               QA / 'PENDING_TERMINAL_UI_INDEPENDENT_REVIEW_V5.json', QA / 'ACTUAL_COMPONENT_EXECUTION_TIMEOUT_V9.json', ROOT / 'tools/run_component_audit_benchmark_v1.py', QA / 'COMPONENT_AUDIT_BENCHMARK_SOURCE_SPEC_V1.json', ROOT / 'tools/run_component_audit_benchmark_v2.py', ROOT / 'tools/campaign_component_audit_benchmark_v1.gd', QA / 'COMPONENT_AUDIT_BENCHMARK_SOURCE_SPEC_V2.json', QA / 'COMPONENT_AUDIT_BENCHMARK_INDEPENDENT_REVIEW_V2.json']
    pins = {row['path']: row for row in spec['pins']}
    for path in helpers:
        row = file_pin(path)
        require(row['path'] not in pins or pins[row['path']] == row, 'Conflicting benchmark source pin')
        pins[row['path']] = row
    pending = [Path(row['path']) for row in pins.values() if Path(row['path']).suffix == '.py']
    seen = set()
    while pending:
        path = pending.pop()
        if path in seen: continue
        seen.add(path)
        for node in ast.walk(ast.parse(path.read_text(encoding='utf-8-sig'))):
            modules = [node.module] if isinstance(node, ast.ImportFrom) and node.module else [row.name for row in node.names] if isinstance(node, ast.Import) else []
            for module in modules:
                dependency = ROOT / 'tools' / (module.split('.')[0] + '.py')
                if dependency.is_file():
                    pin = file_pin(dependency)
                    require(pin['path'] not in pins or pins[pin['path']] == pin, 'Conflicting imported helper pin')
                    pins[pin['path']] = pin
                    pending.append(dependency)
    inputs['schema'] = 'component_audit_read_only_benchmark_inputs_v1'
    inputs['execution_contract'] = {'native_processes': 2, 'scope': SCOPE, 'normal_CAMPAIGN_QA_empty': True,
                                   'Steam_disabled': True, 'old_A_is_read_only_data_not_future_fixture': True}
    spec.update(schema='component_audit_benchmark_source_spec_v3', inputs=inputs, pins=list(pins.values()),
                execution_scope=SCOPE, native_processes=2, ABCD_processes=0, negative_process_stages=0,
                original_packet=file_pin(PACKET), component_matrix_included=False, full_chain_included=False,
                png_decoder={'package': 'Pillow', 'version': Image.__version__}, overall_goal_qualified=False)
    for row in spec['pins']: verify_pin(row)
    return spec


class Suite(FixedEvidenceSuite):
    def __init__(self, args, spec):
        self.args, self.spec = args, spec
        no_links(args.work_root)
        require(not args.work_root.resolve().is_relative_to(ROOT.resolve()), 'Fresh private benchmark root')
        self.run = args.work_root / ('audit_benchmark_' + uuid.uuid4().hex[:8])
        no_links(self.run); self.run.mkdir(parents=True, exist_ok=False)
        self.frozen = FrozenProject(self.run / 'project', spec['inputs'])
        self.batch = OwnedSerialBatch(self.run, self.frozen, args.godot, spec['engine']['sha256'], self.persist, 3600)
        self.evidence, self.evidence_by_path = [], {}
        self.installed_identity = None
        self.remember(spec['original_packet'])
        self.receipt = {'schema': 'component_audit_benchmark_batch_v3', 'run': str(self.run), 'complete': False,
                        'source_spec': spec, 'source_spec_sha256': canonical(spec), 'source_spec_file': args.fixed_source_spec_pin,
                        'independent_review': args.fixed_independent_review_pin, 'steps': [],
                        'equivalence_benchmark_qualified': False, 'component_matrix_qualified': False,
                        'full_chain_qualified': False, 'SDK_qualified': False, 'overall_goal_qualified': False}
        self.original_integrity = self.batch.integrity
        self.batch.integrity = self.integrity

    def validate(self, step, output, nonce):
        path = output / 'report.json'; report = self.read_fixed(path)
        log = self.freeze_bytes(output / 'native.log', step['log_sha256']).decode('utf-8', errors='replace')
        require(report['schema'] == 'component_audit_benchmark_v2' and type(report['pid']) is int and report['pid'] == step['pid']
                and report['nonce'] == nonce and report['passed'] is True and report['failures'] == []
                and report['component_matrix_qualified'] is False and report['full_chain_qualified'] is False
                and report['SDK_qualified'] is False and report['overall_goal_qualified'] is False, 'Actual limited benchmark report')
        user = Path(report['actual_user_directory']); no_links(user)
        require(user.resolve().is_relative_to(Path(step['profile']).resolve()), 'Fresh owned benchmark userdata')
        checks = report['checks']; observations = report['observations']
        packet = self.read_fixed(Path(self.spec['original_packet']['path']), self.spec['original_packet']['sha256'])
        labels = ['supported_scalar_IEEE_and_builtin_fixture', 'mutable_before', 'mutable_after', 'actual_complete_decoded_Units', 'actual_complete_decoded_Level', 'text_256_257_boundary', 'unique_scalar_9000_cache_saturation', 'shared_container_before', 'shared_container_after'] + ['actual_complete_section_' + name for name in packet['world']['sections']]
        require(type(observations) is list and {row['label'] for row in observations} == set(labels) and len(observations) == len(labels), 'Every original complete section benchmarked')
        expected = {'normal simulation clock', 'configured menu initializes real autoloads', 'container mutation never hidden by scalar cache',
                    'original closed A packet read-only exact bytes', 'original packet sections readable', 'original packet bytes unchanged after complete audit', 'text boundary eligible and ineligible cache paths', 'cache reaches exact8192 and preserves uncached miss path', 'shared container alias mutation preserved without caching container'}
        expected.add('real complete original Level codec')
        for record in packet['world']['sections']['units']['records']: expected.add('real complete original Unit codec ' + str(record['entity_id']))
        for label in labels:
            for prefix in ['cold scalar cache initially empty ', 'exact complete typed audit bytes ', 'original IEEE typed fingerprint unchanged ', 'bounded scalar cache ', 'pretty and compact preserve all audit data ']: expected.add(prefix + label)
        require(type(checks) is list and len(checks) == len(expected) and {row['label'] for row in checks} == expected and all(row['ok'] is True for row in checks), 'All exact mandatory old/new checks')
        require(report['time_scale'] == 1 and report['physics_ticks'] == 60 and log.count(f'COMPONENT_AUDIT_BENCHMARK true {len(checks)}') == 1, 'Normal benchmark clock and native terminal marker')
        require(report['physical_write_cost_measured'] is False and report['matrix_runtime_speedup_qualified'] is False, 'CPU/stringify-only cost boundary')
        for row in observations:
            for field in ['old_us', 'candidate_cold_us', 'candidate_warm_us', 'canonical_bytes', 'pretty_bytes', 'compact_bytes', 'pretty_serialize_us', 'compact_serialize_us']:
                require(type(row[field]) is int and row[field] >= 0, 'Actual typed cost observations')
            require(row['compact_bytes'] <= row['pretty_bytes'], 'Compact representation retains data with bounded bytes')
        self.receipt['report'] = self.evidence_by_path[str(path.resolve()).casefold()]
        self.receipt['observations'] = observations

    def execute(self):
        self.frozen.prepare()
        require(native.install_native(self.frozen.project) == self.spec['native_dependencies'], 'Exact current native dependency installation')
        self.frozen.before = inventory(self.frozen.project)
        self.batch.phase('cold_import', self.batch.profile('cold'), ['--headless', '--editor', '--import'], {}, lambda *args: None, 600)
        self.frozen.freeze_cold()
        self.installed_identity = identity_module().installed_identity(self.frozen.project)
        self.receipt['post_cold_runtime_identity'] = self.installed_identity; self.receipt['post_cold_installed_files'] = self.frozen.cold
        profile = self.batch.profile('benchmark')
        def values(output, nonce):
            return {'AUDIT_BENCH_OUTPUT': str(output), 'AUDIT_BENCH_NONCE': nonce, 'AUDIT_BENCH_PROFILE': str(profile),
                    'AUDIT_BENCH_PACKET': self.spec['original_packet']['path'], 'AUDIT_BENCH_PACKET_SHA256': self.spec['original_packet']['sha256']}
        self.batch.phase('audit_equivalence_cost', profile, ['--headless', '--script', 'res://tools/' + PROBE.name], values, self.validate, 1200)
        self.integrity(); self.receipt.update(complete=True, equivalence_benchmark_qualified=True)


def main():
    require(__debug__, 'Assertions must remain enabled'); sys.dont_write_bytecode = True
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, required=True); parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--work-root', type=Path, default=Path('D:/CodexTemp/lsh-component-audit-benchmark-20261009'))
    parser.add_argument('--write-spec', type=Path); parser.add_argument('--source-spec', type=Path); parser.add_argument('--independent-review', type=Path)
    parser.add_argument('--run', action='store_true'); args = parser.parse_args(); spec = source_spec(args); digest = canonical(spec)
    if not args.run:
        if args.write_spec: write_new(args.write_spec, {'spec': spec, 'source_spec_sha256': digest})
        print(json.dumps({'preflight': True, 'source_spec_sha256': digest, 'native_started': False})); return 0
    require(args.write_spec is None and args.source_spec and args.independent_review, 'Exact new benchmark source seal and independent review')
    saved, args.fixed_source_spec_pin = load_fixed_document(args.source_spec)
    review, args.fixed_independent_review_pin = load_fixed_document(args.independent_review)
    require(saved['spec'] == spec and saved['source_spec_sha256'] == digest and review['schema'] == 'component_audit_benchmark_independent_review_v1'
            and review['independent'] is True and review['static_api_closure_passed'] is True and review['approved_stages'] == [SCOPE]
            and review['producer_sha256'] == sha(Path(__file__)) and review['probe_sha256'] == sha(PROBE)
            and review['source_spec_sha256'] == digest and review['source_spec_file_sha256'] == args.fixed_source_spec_pin['sha256'], 'Exact limited benchmark admission')
    suite = Suite(args, spec); code = 0
    try: suite.execute()
    except BaseException as error:
        code = 1; suite.receipt.update(complete=False, equivalence_benchmark_qualified=False, failure=repr(error))
    finally:
        try: suite.batch.release()
        except BaseException as error:
            code = 1; suite.receipt.update(complete=False, equivalence_benchmark_qualified=False, release_failure=repr(error))
        suite.receipt['lock_released'] = not suite.batch.locked; suite.receipt['finished_utc'] = dt.datetime.now(dt.timezone.utc).isoformat()
        suite.persist(); write_new(suite.run / 'receipt.json', suite.receipt)
    print(json.dumps({'run': str(suite.run), 'complete': suite.receipt['complete'], 'failure': suite.receipt.get('failure'), 'full_chain_qualified': False})); return code


if __name__ == '__main__':
    raise SystemExit(main())
