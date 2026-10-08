"""Publish bounded closed owned binary evidence on Windows without replacement.

JSON handshakes retain their separate JSON-validating publisher. Failed
temporary evidence remains retained. This module has no process launcher.
"""
import hashlib
import os
from pathlib import Path
import uuid
from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import no_links

def publish_binary_new(path,raw):
    path=Path(path);no_links(path)
    require(os.name=='nt' and path.parent.is_dir() and not path.exists(), 'Windows fresh owned binary destination required')
    require(type(raw) is bytes and 0<len(raw)<=2*1024*1024, 'Bounded complete original binary bytes')
    pending=path.with_name(path.name+'.writing-'+uuid.uuid4().hex);no_links(pending)
    with pending.open('xb') as stream:
        stream.write(raw);stream.flush();os.fsync(stream.fileno())
    require(pending.read_bytes()==raw and not path.exists(), 'Closed original binary bytes and fresh destination')
    no_links(pending);no_links(path)
    pending.rename(path)
    require(path.read_bytes()==raw, 'Published bytes match original closed binary')
    return {'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
