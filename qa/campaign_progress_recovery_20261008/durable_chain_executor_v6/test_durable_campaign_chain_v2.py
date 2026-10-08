"""Host-only fixed Campaign CFG custody and acknowledgement type refusal."""
import copy
from pathlib import Path
import tempfile
import unittest

from run_durable_campaign_chain_v2 import validate_cfg_ack
from durable_campaign_full_evidence import file_pin


class CfgAcknowledgementFaults(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='lsh_cfg_ack_')
        self.addCleanup(self.temp.cleanup)
        self.user = Path(self.temp.name)
        path = self.user / 'campaign.cfg'
        path.write_text('[host_fixture_only]\nvalue=true\n', encoding='utf-8')
        pin = file_pin(path)
        self.row = {'relative_user_path': 'campaign.cfg', 'bytes': pin['bytes'], 'sha256': pin['sha256']}
        self.ack = {'schema': 'campaign_progress_ack_v1', 'code': 'CAMPAIGN_CFG_READBACK_VERIFIED',
                    'persisted': True, 'suppressed': False, 'file_sha256': pin['sha256']}

    def test_exact_cfg_and_ack(self):
        self.assertEqual(validate_cfg_ack(self.user, self.row, self.ack), self.user / 'campaign.cfg')

    def test_noncanonical_cfg_paths_and_fields_refused(self):
        for path in ['other.cfg', '../campaign.cfg', '/campaign.cfg', 'C:campaign.cfg', '\\campaign.cfg']:
            with self.subTest(path=path):
                row = {**self.row, 'relative_user_path': path}
                with self.assertRaises(RuntimeError): validate_cfg_ack(self.user, row, self.ack)
        for row in [{**self.row, 'bytes': True}, {**self.row, 'extra': 1}]:
            with self.assertRaises(RuntimeError): validate_cfg_ack(self.user, row, self.ack)

    def test_ack_boolean_alias_and_extra_fields_refused(self):
        for key, value in [('persisted', 1), ('suppressed', 0), ('schema', True), ('file_sha256', '0' * 64), ('extra', 1)]:
            with self.subTest(key=key):
                ack = copy.deepcopy(self.ack)
                ack[key] = value
                with self.assertRaises(RuntimeError): validate_cfg_ack(self.user, self.row, ack)


if __name__ == '__main__':
    if not __debug__: raise SystemExit('Assertions must remain enabled')
    unittest.main(verbosity=2)
