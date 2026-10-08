"""Qualify a real owned Windows opener wait and append; does not launch Godot."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import threading
import time
import uuid
from windows_owned_oplock import OwnedOplock

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',action='store_true')
    parser.add_argument('--work-root',type=Path,default=Path('D:/CodexTemp/lsh-campaign-faults-20261008'))
    args=parser.parse_args()
    helper=Path(__file__).with_name('windows_owned_oplock.py')
    digest=hashlib.sha256(helper.read_bytes()).hexdigest()
    if not args.run:
        print(json.dumps({'source_preflight':True,'helper_sha256':digest,'Windows_IO_started':False,'Godot_started':False}))
        return
    run=args.work_root.absolute()/('windows_oplock_'+uuid.uuid4().hex[:8])
    for path in [run,*run.parents]:
        if path.exists() and (path.is_symlink() or getattr(path.lstat(),'st_file_attributes',0)&0x400):
            raise RuntimeError('Owned probe reparse path refused')
    run.mkdir(parents=True,exist_ok=False)
    path=run/'owned.cfg'; before=b'[proof]\nvalue=11\n'; path.write_bytes(before)
    receipt={'schema':'windows_owned_oplock_actual_proof_v1','complete':False,'run':str(run),
        'pid':os.getpid(),'Godot_started':False,'ConfigFile_runtime_qualified':False,'source_sha256':digest}
    lock=None
    try:
        # Also verify cancellation of an unbroken request before native storage is released.
        cancellation=OwnedOplock(path,run); cancellation.close()
        receipt['unbroken_request_cancellation_completed']=True
        lock=OwnedOplock(path,run); observed={}; began=threading.Event(); done=threading.Event()
        def reader():
            observed['reader_native_thread_id']=threading.get_native_id(); began.set()
            try:
                observed['data']=path.read_bytes(); observed['read_completed_ns']=time.monotonic_ns()
            except BaseException as error: observed['failure']=repr(error)
            finally: done.set()
        thread=threading.Thread(target=reader,daemon=True); thread.start()
        if not began.wait(2): raise RuntimeError('Owned reader not started')
        end=time.monotonic()+5
        while not lock.poll_break():
            if time.monotonic()>end: raise RuntimeError('Actual read did not request exclusive oplock break')
            time.sleep(.005)
        held=not done.is_set()
        if not held: raise RuntimeError('Actual opener was not held')
        pause_ns=time.monotonic_ns()
        suffix=b'; real controlled change while native opener waits\n'
        lock.append_before_release(suffix)
        if not done.wait(5): raise RuntimeError('Actual owned reader did not finish after holder close')
        thread.join()
        if observed.get('data')!=before+suffix: raise RuntimeError('Actual native read did not observe real append')
        if hashlib.sha256(helper.read_bytes()).hexdigest()!=digest: raise RuntimeError('Native helper source drift')
        receipt.update(complete=True,actual_read_blocked_before_release=held,break_observed_ns=pause_ns,
            read_completed_ns=observed['read_completed_ns'],reader_native_thread_id=observed['reader_native_thread_id'],
            before_sha256=hashlib.sha256(before).hexdigest(),after_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            actual_native_read_saw_appended_bytes=True)
    except BaseException as error:
        receipt['failure']=repr(error)
        raise
    finally:
        if lock is not None: lock.close()
        (run/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(receipt),flush=True)

if __name__=='__main__':
    main()
