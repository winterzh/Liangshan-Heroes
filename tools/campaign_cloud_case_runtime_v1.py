"""Actual ordinary restart appended to the reviewed owned cloud applying phase.

No CLI or execution admission. The inherited phase retains and cleans up its
actual Popen and lease; publication and validation run before the child clears.
"""
from pathlib import Path

from campaign_cloud_applying_runtime_v5 import CloudApplyingSerialBatch, sealed_document, CASE
from campaign_cloud_restart_exports_v1 import CallbackNativeExports as RestartNativeExports
from campaign_cloud_restart_evidence_v1 import CloudCaseEvidence
from campaign_callback_packets_v2 import same
from durable_campaign_full_runtime import no_links
from durable_campaign_full_matrices import require


class CloudCaseSerialBatch(CloudApplyingSerialBatch):
    def cloud_restart_phase(self,suite,manifest_path,manifest_sha256,profile,values,validator,timeout_seconds=180):
        require(suite.batch is self and self.child is None and type(timeout_seconds) is int and 0 < timeout_seconds <= 180
                and isinstance(suite.consumer,CloudCaseEvidence) and suite.consumer.suite is suite
                and suite.consumer.completed and suite.consumer.first_step is not None
                and suite.consumer.first_step['complete'] is True and suite.consumer.restart_step is None,
                'Only owned idle batch after actual full first-cloud evidence validation')
        manifest = sealed_document(suite,manifest_path,manifest_sha256)
        require(manifest == suite.consumer.restart_manifest and manifest['case'] == CASE
                and manifest['required_mode'] == 'restart_first'
                and Path(manifest['candidate']['path']).name == 'campaign_original19_cloud_restart_v1.gd',
                'Exact source-sealed ordinary restart manifest')
        for key in ['candidate','parent_GD']:
            pin = manifest[key]
            alias = 'tools/'+Path(pin['path']).name
            require(any(Path(row['path']).resolve() == Path(pin['path']).resolve() and row['sha256'] == pin['sha256']
                        and row['bytes'] == pin['bytes'] for row in suite.spec['pins'])
                    and any(row['runtime_path'] == alias and Path(row['path']).resolve() == Path(pin['path']).resolve()
                            and row['bytes'] == pin['bytes'] and row['sha256'] == pin['sha256']
                            for row in suite.spec['inputs']['runtime_and_harness_overlays']), 'Exact pinned installed restart/parent aliases')
            suite.freeze_bytes(pin['path'],pin['sha256'])
        profile = Path(profile)
        no_links(profile)
        first = suite.consumer.first_step
        require(profile == Path(first['profile']) and len(self.steps) == 2 and self.steps[1] is first
                and self.steps[0]['label'] == 'cold_import' and self.steps[0]['complete'] is True,
                'Only actual cold and first cloud phases before same-profile restart')
        first_path = Path(first['output'])/'report.json'
        first_pin = first['actual_native_exports']['report.json']
        first_report = suite.read_fixed(first_path,first_pin['sha256'])
        require(first_report['pid'] == first['pid'] and first_report['nonce'] == first['nonce']
                and first_report['passed'] is True and first_report['schema'] == 'campaign_original19_cloud_applying_probe_v3',
                'Immutable original validated first report before launching restart')

        def build(output,nonce):
            step = self.steps[-1]
            require(step['label'] == 'cloud_restart' and Path(step['output']) == output and step['nonce'] == nonce
                    and step['profile'] == str(profile), 'Current inherited owned restart step before Popen')
            step.update(mode='restart_first',case=CASE)
            identity = Path(suite.identity_path)
            no_links(identity)
            require(identity.resolve().is_relative_to(suite.run.resolve()), 'Owned original post-cold identity path')
            pin = suite.evidence_by_path[str(identity.resolve()).casefold()]
            document = suite.read_fixed(identity,pin['sha256'])
            require(type(document) is dict and set(document) == {'runtime_fields','complete_identity'}
                    and same(document['runtime_fields'],suite.runtime_fields)
                    and same(document['complete_identity'],suite.installed_identity), 'Complete original post-cold identity unchanged')
            actual = values(output,nonce) if callable(values) else values
            expected = {'CAMPAIGN_CALLBACK_CASE':CASE,'CAMPAIGN_TERMINAL_OUTPUT':str(output),'CAMPAIGN_TERMINAL_NONCE':nonce,
                        'CAMPAIGN_TERMINAL_MODE':'restart_first','CAMPAIGN_TERMINAL_PROFILE':str(profile),
                        'CAMPAIGN_TERMINAL_TOKEN':'','CAMPAIGN_TERMINAL_EXPECT_RECOVERY':'0',
                        'CAMPAIGN_TERMINAL_IDENTITY_FILE':str(identity),'CAMPAIGN_TERMINAL_IDENTITY_SHA256':pin['sha256'],
                        'CAMPAIGN_TERMINAL_PRIOR_HANDOFF_FILE':'','CAMPAIGN_TERMINAL_PRIOR_HANDOFF_SHA256':'',
                        'CAMPAIGN_TERMINAL_PRIOR_TOKEN':'','CAMPAIGN_CLOUD_PRIOR_REPORT_FILE':str(first_path),
                        'CAMPAIGN_CLOUD_PRIOR_REPORT_SHA256':first_pin['sha256']}
            require(type(actual) is dict and all(type(k) is str and type(v) is str for k,v in actual.items())
                    and actual == expected, 'Exact normal restart environment with no aliases/extras before Popen')
            suite.freeze_bytes(first_path,first_pin['sha256'])
            suite.integrity()
            return actual

        def completed(step,output,nonce):
            require(step is self.steps[-1] and step['case'] == CASE and step['mode'] == 'restart_first', 'Current original terminal restart step')
            exports = RestartNativeExports(suite,step)
            exports.require_complete(CASE)
            suite.freeze_bytes(output/'native.log',step['log_sha256'])
            validator(step,output,nonce)

        # Generic owned phase calls build before Popen, and completed while its
        # actual zero-exit Popen is still retained. All cleanup remains inherited.
        return self.phase('cloud_restart',profile,['--headless','--script','res://tools/'+Path(manifest['candidate']['path']).name],
                          build,completed,timeout_seconds)
