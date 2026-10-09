"""Publish complete owned JSON handshakes on Windows without replacing a target.

No process launcher or native admission. A failed temporary file is retained.
"""
import hashlib
import json
import os
from pathlib import Path
import uuid

from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import no_links


def publish_new(path, payload):
    path=Path(path); no_links(path)
    require(os.name=='nt' and path.parent.is_dir() and not path.exists(), 'Windows fresh owned JSON destination required')
    raw=(json.dumps(payload,ensure_ascii=False,indent=2)+'\n').encode('utf-8')
    require(0<len(raw)<=2*1024*1024, 'Bounded complete owned handshake')
    pending=path.with_name(path.name+'.writing-'+uuid.uuid4().hex); no_links(pending)
    with pending.open('xb') as stream:
        stream.write(raw); stream.flush(); os.fsync(stream.fileno())
    require(pending.read_bytes()==raw and not path.exists(), 'Closed first complete JSON bytes and no existing target')
    no_links(pending); no_links(path)
    # Windows rename fails if the destination already exists; no overwrite.
    pending.rename(path)
    require(path.read_bytes()==raw, 'Published bytes equal original closed bytes')
    return {'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
