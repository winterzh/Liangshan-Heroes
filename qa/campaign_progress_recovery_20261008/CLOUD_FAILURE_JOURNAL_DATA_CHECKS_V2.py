"""Pure decoded-data counterexamples, not native execution or byte custody."""
import copy
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools'))
sys.dont_write_bytecode = True
from campaign_cloud_failure_evidence_v2 import retained_cfg_links


def main():
    def pair(generation, transaction, prior, candidate):
        proposal = {'schema': 'campaign_cfg_transaction_v1', 'generation': generation, 'state': 'prepared',
                    'transaction': transaction, 'original_sha256': prior, 'candidate_sha256': candidate,
                    'semantics_sha256': 'a'*64, 'original_owner': '', 'target_owner': '',
                    'content_version': 'synthetic-source', 'engine_sha256': 'b'*64,
                    'operation': 'prefs', 'run_token': '', 'intent_sha256': ''}
        applied = {**proposal, 'generation': generation+1, 'state': 'applied'}
        return [{'document': proposal}, {'document': applied}]
    first = pair(7, '1'*32, '0'*64, '2'*64)
    second = pair(9, '3'*32, '2'*64, '4'*64)
    assert retained_cfg_links([], '')['last_applied_physical_CFG_verified'] is False
    assert retained_cfg_links([], '2'*64)['last_applied_physical_CFG_verified'] is False
    assert retained_cfg_links(first, '2'*64)['last_applied_physical_CFG_verified'] is True
    assert retained_cfg_links(first+second, '4'*64)['last_applied_physical_CFG_verified'] is True
    counterexamples = []
    for key in first[0]['document']:
        if key in ['generation', 'state']:
            continue
        rows = copy.deepcopy(first)
        rows[1]['document'][key] += 'changed'
        counterexamples.append((rows, '2'*64, 'applied proposal '+key))
    counterexamples += [(first, '', 'missing physical CFG'), (first, '5'*64, 'wrong physical CFG'),
                       (first[:1], '2'*64, 'incomplete pair')]
    rows = copy.deepcopy(first+second)
    for row in rows[2:]:
        row['document']['transaction'] = first[0]['document']['transaction']
    counterexamples.append((rows, '4'*64, 'reused subsequent transaction'))
    refused = 0
    for rows, digest, label in counterexamples:
        try:
            retained_cfg_links(rows, digest)
        except RuntimeError:
            refused += 1
        else:
            raise AssertionError('Counterexample accepted: '+label)
    assert refused == len(counterexamples) == 16
    record = {'schema': 'cloud_failure_journal_pure_data_checks_v2', 'counterexamples_refused': refused,
              'valid_retained_shapes_checked': 4, 'synthetic_decoded_data_only': True,
              'actual_Popen_created': False, 'full_consumer_constructed_or_called': False,
              'original_physical_journal_or_CFG_checked': False, 'native_started': False,
              'original19_qualified': False, 'overall_goal_qualified': False}
    with Path(__file__).with_suffix('.json').open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(record, stream, indent=2)
        stream.write('\n')
    print(json.dumps(record))


if __name__ == '__main__':
    main()
