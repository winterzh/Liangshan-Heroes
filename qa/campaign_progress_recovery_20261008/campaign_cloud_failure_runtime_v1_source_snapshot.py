"""Connect one cloud-write failure report to the original owned native phase.

No CLI, run-directory creation, source admission or simulated process. A future
producer must provide its sealed Suite and successful durable-chain prior.
"""
from pathlib import Path

from campaign_callback_packets_v2 import same
from campaign_cloud_failure_evidence_v2 import CASE, CloudFailureEvidence, CloudFailureNativeExports
from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import OwnedSerialBatch, no_links, sha


class CloudFailureSerialBatch(OwnedSerialBatch):
    def cloud_failure_phase(self, suite, profile, values, validator, timeout_seconds=180):
        require(suite.batch is self and self.child is None
                and getattr(self.phase, '__func__', None) is OwnedSerialBatch.phase
                and type(timeout_seconds) is int and 0 < timeout_seconds <= 180
                and isinstance(suite.consumer, CloudFailureEvidence)
                and suite.consumer.suite is suite and not suite.consumer.completed,
                'Original idle owned phase and its source-bound failure consumer')
        require(len(self.steps) == 1 and self.steps[0]['label'] == 'cold_import'
                and self.steps[0]['complete'] is True and callable(values) and callable(validator),
                'Only one successful actual cold phase before this failure boundary')
        profile = Path(profile)
        no_links(profile)
        require(profile.is_dir() and profile.resolve().is_relative_to((self.run/'profiles').resolve())
                and profile != Path(self.steps[0]['profile'])
                and {p.name for p in profile.iterdir()} == {'appdata', 'localappdata', 'temp', 'tmp'}
                and all((profile/key).is_dir() and not list((profile/key).iterdir())
                        for key in ['appdata', 'localappdata', 'temp', 'tmp']),
                'Fresh actual private profile, never a reused player or failed profile')
        for key in ['appdata', 'localappdata', 'temp', 'tmp']:
            no_links(profile/key)
        manifest = suite.consumer.manifest
        require(manifest['case'] == CASE and manifest['required_mode'] == 'first'
                and Path(manifest['candidate']['path']).name == 'campaign_original19_cloud_write_failure_v2.gd',
                'Only the reviewed V2 native failure driver')
        for key in ['candidate', 'parent_GD']:
            row = manifest[key]
            installed = self.frozen.project/'tools'/Path(row['path']).name
            no_links(installed)
            require(installed.is_file() and installed.stat().st_size == row['bytes']
                    and sha(installed) == row['sha256'], 'Source-sealed native aliases before launch')
        identity = Path(suite.identity_path)
        no_links(identity)
        require(identity.resolve().is_relative_to(suite.run.resolve()), 'Owned post-cold identity path')
        pin = suite.evidence_by_path[str(identity.resolve()).casefold()]
        original_identity = suite.read_fixed(identity, pin['sha256'])
        require(type(original_identity) is dict and set(original_identity) == {'runtime_fields', 'complete_identity'}
                and same(original_identity['runtime_fields'], suite.runtime_fields)
                and same(original_identity['complete_identity'], suite.installed_identity),
                'Complete actual immutable post-cold identity before launch')

        def build(output, nonce):
            step = self.steps[-1]
            require(step['label'] == 'cloud_write_failure' and step['output'] == str(output)
                    and step['nonce'] == nonce and step['profile'] == str(profile),
                    'Current original phase object before Popen')
            step.update(mode='first', case=CASE)
            actual = values(output, nonce)
            expected = {'CAMPAIGN_CALLBACK_CASE': CASE, 'CAMPAIGN_TERMINAL_OUTPUT': str(output),
                        'CAMPAIGN_TERMINAL_NONCE': nonce, 'CAMPAIGN_TERMINAL_MODE': 'first',
                        'CAMPAIGN_TERMINAL_PROFILE': str(profile), 'CAMPAIGN_TERMINAL_TOKEN': '',
                        'CAMPAIGN_TERMINAL_EXPECT_RECOVERY': '0', 'CAMPAIGN_TERMINAL_IDENTITY_FILE': str(identity),
                        'CAMPAIGN_TERMINAL_IDENTITY_SHA256': pin['sha256'],
                        'CAMPAIGN_TERMINAL_PRIOR_HANDOFF_FILE': '',
                        'CAMPAIGN_TERMINAL_PRIOR_HANDOFF_SHA256': '', 'CAMPAIGN_TERMINAL_PRIOR_TOKEN': ''}
            require(same(actual, expected), 'Exact private normal-mode SDK-disabled native environment')
            suite.integrity()
            return actual

        def terminal(step, output, nonce):
            require(step is self.steps[-1] and step['output'] == str(output) and step['nonce'] == nonce,
                    'Only the original retained terminal phase')
            exports = CloudFailureNativeExports(suite, step)
            exports.require_complete(CASE)
            suite.freeze_bytes(output/'native.log', step['log_sha256'])
            suite.integrity()
            validator(step, output, nonce)
            require(suite.consumer.completed, 'Whole actual consumer completes before owned child clears')
            suite.integrity()

        return self.phase('cloud_write_failure', profile,
                          ['--script', 'res://tools/'+Path(manifest['candidate']['path']).name],
                          build, terminal, timeout_seconds, expected_exit=0)
