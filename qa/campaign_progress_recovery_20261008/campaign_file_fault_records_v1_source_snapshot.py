"""Strict first-byte journal decoding shared by fault archive and result checks."""
import hashlib
import json
import re

from durable_campaign_full_matrices import require

CFG_FIELDS={'schema','generation','state','transaction','original_sha256','candidate_sha256','semantics_sha256',
            'original_owner','target_owner','content_version','engine_sha256','operation','run_token','intent_sha256'}
ENV_FIELDS={'magic','version','app','owner','revision','previous_sha256','payload_bytes','payload_sha256','payload'}
ZERO='0'*64


def hex_value(value,size=64):
    return type(value) is str and re.fullmatch('[0-9a-f]{'+str(size)+'}',value) is not None


def decode_envelope(raw,magic,generation,previous):
    require(type(raw) is bytes and 0<len(raw)<=65536, 'Bounded original journal bytes')
    env=json.loads(raw.decode('utf-8'))
    require(type(env) is dict and set(env)==ENV_FIELDS and all(type(v) is str for v in env.values()), 'Exact nine-string native envelope')
    require(env['magic']==magic and env['version']=='1' and env['app']=='5088120' and env['owner']=='1'
            and env['revision']==str(generation) and env['previous_sha256']==previous, 'Original journal identity/revision/previous chain')
    payload=env['payload'].encode('utf-8')
    require(env['payload_bytes']==str(len(payload)) and env['payload_sha256']==hashlib.sha256(payload).hexdigest(), 'Original native payload bytes/hash')
    document=json.loads(payload)
    require(type(document) is dict and type(document.get('generation')) is int and document['generation']==generation, 'Exact typed native document generation')
    return document


def cfg_document(document,generation,scope,operation,token,intent_sha,original_sha,candidate_sha):
    require(type(document) is dict and set(document)==CFG_FIELDS and type(document['generation']) is int
            and document['generation']==generation and all(type(v) is str for k,v in document.items() if k!='generation'), 'All14 typed CFG document fields')
    expected={'schema':'campaign_cfg_transaction_v1','state':'prepared' if generation%2 else 'applied','original_owner':'',
              'target_owner':'','content_version':scope['content_version'],'engine_sha256':scope['engine_binary_sha256'],
              'operation':operation,'run_token':token,'intent_sha256':intent_sha,
              'original_sha256':original_sha,'candidate_sha256':candidate_sha}
    require(all(document[k]==v for k,v in expected.items()), 'Exact native request/source/owner/physical CFG hashes')
    require(hex_value(document['transaction'],32) and hex_value(document['semantics_sha256'])
            and hex_value(original_sha) and hex_value(candidate_sha), 'Native CFG transaction/semantics hashes')
