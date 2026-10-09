"""Host-only native user:// evidence resolution, including refusal boundaries."""
import copy
from pathlib import Path
import unittest

import durable_campaign_full_evidence_v2 as evidence
import test_durable_campaign_full_support as support


class UserEvidencePaths(support.SupportFaults):
    def freeze(self):
        return evidence.freeze_closed_a(self.step, self.report_path, self.identity, 'lu', self.root / 'frozen')

    def test_native_user_scheme_handoff_valid(self):
        self.report['evidence'][-1] = evidence.file_pin(self.out / 'saved_world.json')
        self.report['evidence'][0] = {'path': 'user://daming_safe_retreat_v25/handoff_A.json', 'sha256': evidence.sha(self.handoff)}
        self.write(self.report_path, self.report)
        frozen = self.freeze()
        self.assertEqual(frozen['a_handoff']['sha256'], evidence.sha(self.handoff))

    def test_absolute_and_user_alias_duplicate_refused(self):
        self.report['evidence'].append({'path': 'user://daming_safe_retreat_v25/handoff_A.json', 'sha256': evidence.sha(self.handoff)})
        self.write(self.report_path, self.report)
        with self.assertRaisesRegex(AssertionError, 'Duplicate'): self.freeze()

    def test_unapproved_user_path_and_drive_paths_refused(self):
        for value in ['user://../campaign.cfg', 'user://campaign.cfg', 'user://C:outside.json',
                      'user://daming_safe_retreat_v25/../handoff_A.json', 'res://scripts/battle.gd', 'C:relative.json']:
            with self.subTest(value=value):
                with self.assertRaises(AssertionError): evidence.resolve_evidence_path(value, self.user)

    def test_missing_native_evidence_refused(self):
        altered = copy.deepcopy(self.report)
        altered['evidence'][0]['path'] = str(self.out / 'missing.json')
        self.write(self.report_path, altered)
        with self.assertRaises((AssertionError, FileNotFoundError)): self.freeze()


if __name__ == '__main__':
    if not __debug__: raise SystemExit('Assertions must remain enabled')
    unittest.main(verbosity=2)
