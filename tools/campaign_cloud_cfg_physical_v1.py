"""Original cloud CFG/retained-journal capture and typed physical checks.

No launcher/admission or ConfigFile parser. Full native semantics and restart
still need the complete consumer. A pruned ancestor is never invented.
"""
import hashlib
from pathlib import Path
import subprocess

from campaign_callback_packets_v2 import json_value, same
from campaign_file_fault_records_v1 import decode_envelope, CFG_FIELDS, ZERO, hex_value
from campaign_original19_binary_files_v1 import publish_binary_new
from campaign_original19_atomic_files_v2 import publish_bytes_new
from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import no_links


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def original_copy(suite,source,destination,expected=None,journal=False):
    source,destination = Path(source),Path(destination)
    no_links(source)
    no_links(destination)
    require(destination.resolve().is_relative_to((suite.run/'steps').resolve()), 'Current owned immutable physical copy')
    raw = source.read_bytes()
    require(0 < len(raw) <= (65536 if journal else 2097152) and source.read_bytes() == raw
            and (expected is None or sha(raw) == expected), 'Original bounded stable physical bytes/SHA')
    (publish_bytes_new if journal else publish_binary_new)(destination,raw)
    require(source.read_bytes() == raw, 'Physical source changed during closed copy')
    suite.freeze_bytes(destination,sha(raw))
    return {'original_path':str(source),'copy_path':str(destination),'bytes':len(raw),'sha256':sha(raw)}


def strict_journal(raw,generation,previous):
    envelope = json_value(raw.decode('utf-8'))
    require(type(envelope) is dict and type(envelope.get('payload')) is str, 'Strict duplicate-free journal envelope')
    document = json_value(envelope['payload'])
    decoded = decode_envelope(raw,'LH_CAMPAIGN_CFG_TRANSACTION',generation,previous)
    require(same(document,decoded) and set(document) == CFG_FIELDS and type(document['generation']) is int
            and document['generation'] == generation and all(type(v) is str for k,v in document.items() if k != 'generation')
            and document['schema'] == 'campaign_cfg_transaction_v1' and hex_value(document['transaction'],32)
            and all(hex_value(document[k]) for k in ['original_sha256','candidate_sha256','semantics_sha256']),
            'Complete fourteen typed original CFG fields')
    return document


def journal_names(directory,missing_allowed=False):
    directory = Path(directory)
    no_links(directory)
    if not directory.exists():
        require(missing_allowed, 'Required actual retained journal directory')
        return []
    require(directory.is_dir(), 'Actual journal directory type')
    names = sorted(p.name for p in directory.iterdir())
    if not names:
        require(missing_allowed, 'Required actual retained pair')
        return []
    require(len(names) == 2, 'Exactly the original retained prepared/applied pair')
    numbers = []
    for name in names:
        require(name.startswith('record_') and name.endswith('.json') and len(name) == 22
                and name[7:17].isdigit(), 'Exact retained journal names')
        numbers.append(int(name[7:17]))
    require(numbers[0] >= 1 and numbers[0] % 2 == 1 and numbers[1] == numbers[0]+1, 'Complete consecutive prepared/applied generations')
    return list(zip(names,numbers))


def source_fields(document,suite,operation,owner):
    require(document['content_version'] == suite.runtime_fields['content_version']
            and document['engine_sha256'] == suite.runtime_fields['engine_binary_sha256']
            and document['operation'] == operation and document['original_owner'] == ''
            and document['target_owner'] == owner and document['run_token'] == '' and document['intent_sha256'] == '',
            'Exact current source and local prefs/cloud request/owner scope')


def capture_cloud_pre_apply(suite,step,controller):
    child = suite.batch.child
    require(isinstance(child,subprocess.Popen) and child is controller.child and child.poll() is None
            and child.pid == step['pid'] and any(s is step for s in suite.batch.steps)
            and controller.arm_request_sent is False and controller.packets.ready is None,
            'Actual retained live owned process before ready processing or arm send')
    controller.live()
    user,output = Path(controller.user),Path(step['output'])
    no_links(user)
    no_links(output)
    require(user.resolve().is_relative_to((Path(step['profile'])/'appdata').resolve())
            and output.resolve().is_relative_to((suite.run/'steps').resolve()), 'Current actual private user and output')
    copies = output/'cloud_cfg_before'
    no_links(copies)
    copies.mkdir(exist_ok=False)
    source = user/'campaign.cfg'
    no_links(source)
    declared = controller.apply_ready['original_cfg_sha256']
    if declared:
        cfg = original_copy(suite,source,copies/'campaign_cfg.bin',declared)
    else:
        require(not source.exists(), 'Declared absent original CFG must be physically absent')
        cfg = None
    directory = user/'campaign_cfg_transactions/v1/5088120/1'
    names = journal_names(directory,missing_allowed=True)
    rows = []
    previous = ZERO
    ancestor_available = True
    for index,(name,generation) in enumerate(names):
        row = original_copy(suite,directory/name,copies/name,journal=True)
        raw = suite.freeze_bytes(row['copy_path'],row['sha256'])
        if index == 0 and generation != 1:
            previous = json_value(raw.decode('utf-8'))['previous_sha256']
            require(hex_value(previous), 'Original declared pruned predecessor hash')
            ancestor_available = False
        document = strict_journal(raw,generation,previous)
        source_fields(document,suite,'prefs','')
        require(document['state'] == ('prepared' if index == 0 else 'applied'), 'Original prefs pair states')
        row.update(generation=generation,document=document)
        rows.append(row)
        previous = row['sha256']
    if rows:
        require(cfg is not None and rows[-1]['document']['candidate_sha256'] == cfg['sha256'], 'Original current CFG is last retained applied candidate')
        require(same({k:v for k,v in rows[0]['document'].items() if k not in ['generation','state']},
                     {k:v for k,v in rows[1]['document'].items() if k not in ['generation','state']}), 'Original fourteen-field prefs proposal unchanged')
    require(journal_names(directory,missing_allowed=True) == names, 'Original retained journal set stable during capture')
    if cfg:
        require(sha(source.read_bytes()) == cfg['sha256'], 'Original CFG stays unchanged before arm')
    else:
        require(not source.exists(), 'Absent original CFG stays absent before arm')
    result = {'schema':'cloud_cfg_original_before_apply_v1','cfg':cfg,'journals':rows,
              'pruned_ancestor_bytes_available':ancestor_available,'native_semantics_independently_verified':False}
    step['cloud_cfg_before'] = result
    suite.persist()
    return result


def validate_cloud_post_cfg(suite,step,user,expected_cfg_sha):
    before = step['cloud_cfg_before']
    require(before['schema'] == 'cloud_cfg_original_before_apply_v1' and hex_value(expected_cfg_sha), 'Original before snapshot and candidate CFG SHA')
    for row in ([before['cfg']] if before['cfg'] else [])+before['journals']:
        suite.freeze_bytes(row['copy_path'],row['sha256'])
    user,output = Path(user),Path(step['output'])
    copies = output/'cloud_cfg_after'
    no_links(copies)
    copies.mkdir(exist_ok=False)
    cfg = original_copy(suite,user/'campaign.cfg',copies/'campaign_cfg.bin',expected_cfg_sha)
    directory = user/'campaign_cfg_transactions/v1/5088120/1'
    names = journal_names(directory)
    last = before['journals'][-1]['generation'] if before['journals'] else 0
    require([g for _,g in names] == [last+1,last+2], 'Real cloud write appends exact next prepared/applied pair')
    previous = before['journals'][-1]['sha256'] if before['journals'] else ZERO
    original = before['cfg']['sha256'] if before['cfg'] else ZERO
    rows = []
    for index,(name,generation) in enumerate(names):
        row = original_copy(suite,directory/name,copies/name,journal=True)
        raw = suite.freeze_bytes(row['copy_path'],row['sha256'])
        document = strict_journal(raw,generation,previous)
        source_fields(document,suite,'cloud','1')
        require(document['state'] == ('prepared' if index == 0 else 'applied')
                and document['original_sha256'] == original and document['candidate_sha256'] == expected_cfg_sha,
                'Real cloud pair exact state and physical before/candidate CFG hashes')
        row.update(generation=generation,document=document)
        rows.append(row)
        previous = row['sha256']
    require(same({k:v for k,v in rows[0]['document'].items() if k not in ['generation','state']},
                 {k:v for k,v in rows[1]['document'].items() if k not in ['generation','state']}), 'Whole fourteen-field cloud proposal unchanged')
    stage = user/'campaign_cfg_candidates/v1'
    no_links(stage)
    require(stage.is_dir() and not list(stage.iterdir()), 'Actual successful candidate stage closes empty')
    require(journal_names(directory) == names and sha((user/'campaign.cfg').read_bytes()) == expected_cfg_sha,
            'Actual retained pair and public candidate CFG stay unchanged')
    return {'cfg':cfg,'journals':rows,'native_semantics_independently_verified':False,
            'restart_qualified':False,'whole_suite_qualified':False}
