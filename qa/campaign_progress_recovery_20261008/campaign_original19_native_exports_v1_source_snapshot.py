"""Publish nonce-stage native JSON only after its owned stdout close/SHA marker.

No launcher. Native stage files and original packet/log sources stay retained.
"""
from pathlib import Path
import re
import time

from campaign_original19_atomic_files_v2 import publish_bytes_new
from durable_campaign_full_matrices import require
from durable_campaign_full_runtime import ANSI, no_links
from run_workstation_baseline import engines

NAMES={'ready_for_terminal.json','terminal_handoff.json','restart_handoff.json',
       'report.json','file_fault_ready.json','file_fault_pending.json'}
MARKER=re.compile(r'CAMPAIGN_FILE19_EXPORT ([1-9][0-9]*) ([0-9a-f]{32}) ([a-z_]+\.json) ([0-9a-f]{64})\Z')


class NativeExports:
    def __init__(self, suite, step):
        require(any(s is step for s in suite.batch.steps) and type(step['pid']) is int, 'Original owned phase object and PID')
        self.suite,self.step=suite,step; self.output=Path(step['output']); no_links(self.output)
        require(self.output.resolve().is_relative_to((suite.run/'steps').resolve()), 'Current owned phase output')
        self.rows={}

    def publish(self, terminal=False):
        log=self.output/'native.log'; no_links(log)
        raw=log.read_bytes()
        if not terminal: raw=raw[:raw.rfind(b'\n')+1]
        lines=ANSI.sub('',raw.decode('utf-8',errors='strict')).splitlines()
        markers=[]
        for line in lines:
            if not line.startswith('CAMPAIGN_FILE19_EXPORT '): continue
            match=MARKER.fullmatch(line); require(match is not None, 'Exact complete native JSON export marker')
            pid,nonce,name,digest=match.groups()
            require(int(pid)==self.step['pid'] and nonce==self.step['nonce'] and name in NAMES, 'Actual current native PID/nonce/fixed filename')
            markers.append((name,digest))
        require(len({name for name,_ in markers})==len(markers), 'Each native stage is exported once')
        changed=False
        for name,digest in markers:
            if name in self.rows:
                require(self.rows[name]['sha256']==digest, 'First native export SHA unchanged'); continue
            stage=self.output/(name+'.native-'+self.step['nonce']); destination=self.output/name
            no_links(stage); no_links(destination)
            require(stage.is_file() and 0<stage.stat().st_size<=2*1024*1024, 'Bounded closed native original stage')
            original=self.suite.freeze_bytes(stage,digest)
            published=publish_bytes_new(destination,original)
            self.suite.freeze_bytes(destination,digest)
            self.rows[name]={'native_stage':str(stage),'published_path':str(destination),'bytes':published['bytes'],
                             'sha256':digest,'pid':self.step['pid'],'nonce':self.step['nonce']}
            changed=True
        if changed:
            self.step['actual_native_exports']=self.rows.copy(); self.suite.persist()
        return self.rows

    def wait_for_ready(self, child, deadline):
        require(child is self.suite.batch.child and child.pid==self.step['pid'], 'Original owned live child during export observation')
        until=min(deadline,time.monotonic()+5)
        expected={'ready_for_terminal.json','file_fault_ready.json'}
        while not expected.issubset(self.rows):
            require(child.poll() is None and time.monotonic()<until and not (engines()-{child.pid}), 'Bounded owned ready-export observation; no foreign engine')
            self.publish()
            if not expected.issubset(self.rows): time.sleep(.05)

    def require_complete(self, mode):
        self.publish(terminal=True)
        expected={'report.json','restart_handoff.json'} if mode=='restart' else {
            'ready_for_terminal.json','file_fault_ready.json','file_fault_pending.json','terminal_handoff.json','report.json'}
        require(mode in ['fresh','restart'] and set(self.rows)==expected, 'Complete fixed actual native export set')
        for row in self.rows.values():
            self.suite.freeze_bytes(Path(row['native_stage']),row['sha256'])
            self.suite.freeze_bytes(Path(row['published_path']),row['sha256'])
