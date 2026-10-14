"""One source-bound native primitive, never durable D/full chain qualification."""
import datetime as dt
import json
from pathlib import Path
import sys
import uuid
from durable_campaign_full_runtime import OwnedSerialBatch, no_links, sha, read, write_new
from durable_campaign_full_evidence_v2 import file_pin
ROOT=Path(__file__).resolve().parents[1]
FOLDER=ROOT/'qa/campaign_progress_recovery_20261008/terminal_steam_transport_candidate_v2'

def main():
    assert __debug__
    sys.dont_write_bytecode=True
    review_raw=(FOLDER/'PRELIMINARY_REVIEW.json').read_bytes()
    review_pin={'path':str((FOLDER/'PRELIMINARY_REVIEW.json').resolve()),'bytes':len(review_raw),'sha256':__import__('hashlib').sha256(review_raw).hexdigest()}
    review=json.loads(review_raw)
    assert file_pin(FOLDER/'PRELIMINARY_REVIEW.json')==review_pin
    assert review['independent'] is True and review['approved_stages']==['primitive_transport_diagnostic']
    pins=review['pins']
    for row in pins:
        assert file_pin(Path(row['path']))==row
    manifest_raw=(FOLDER/'SOURCE.json').read_bytes()
    manifest_pin={'path':str((FOLDER/'SOURCE.json').resolve()),'bytes':len(manifest_raw),'sha256':__import__('hashlib').sha256(manifest_raw).hexdigest()}
    assert manifest_pin in pins
    manifest=json.loads(manifest_raw)
    assert file_pin(FOLDER/'SOURCE.json')==manifest_pin
    required=[manifest[k] for k in ['predecessor','candidate','diagnostic','actual_failure','original_C']]
    assert all(row in pins for row in required)
    own_pin=file_pin(Path(__file__))
    assert own_pin in pins
    engine=Path('C:/Users/rsb/Desktop/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe')
    engine_sha='ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00'
    run=Path('D:/CodexTemp')/('lsh-terminal-steam-primitive-20261014_'+uuid.uuid4().hex[:8])
    no_links(run)
    run.mkdir(exist_ok=False)
    project=run/'scratch'
    project.mkdir()
    script=project/'probe.gd'
    source_raw=Path(manifest['diagnostic']['path']).read_bytes()
    assert len(source_raw)==manifest['diagnostic']['bytes'] and __import__('hashlib').sha256(source_raw).hexdigest()==manifest['diagnostic']['sha256']
    script.write_bytes(source_raw)
    script_pin=file_pin(script)
    assert script_pin['bytes']==manifest['diagnostic']['bytes'] and script_pin['sha256']==manifest['diagnostic']['sha256']
    receipt={'schema':'terminal_steam_transport_primitive_batch_v1','run':str(run),'complete':False,'full_chain_qualified':False,'overall_goal_qualified':False,'review':review_pin,'source_pins':pins}
    class Frozen:
        def __init__(self): self.project=project
        def check(self):
            assert not (project/'project.godot').exists()
            assert file_pin(script)==script_pin
            for row in [*pins,review_pin]: assert file_pin(Path(row['path']))==row
    def persist():
        receipt['steps']=batch.steps
        (run/'checkpoint.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    batch=OwnedSerialBatch(run,Frozen(),engine,engine_sha,persist,deadline_seconds=1800)
    code=0
    try:
        profile=batch.profile('primitive')
        def values(output,nonce):
            return {'TRANSPORT_OUT':str(output),'TRANSPORT_NONCE':nonce,'TRANSPORT_ORIGINAL_C':manifest['original_C']['path']}
        def validate(step,output,nonce):
            report=read(output/'report.json')
            assert report['schema']=='terminal_steam_transport_primitive_v1'
            assert report['pid']==step['pid'] and report['nonce']==nonce and report['all_passed'] is True
            assert len(report['checks'])==33 and all(r['passed'] is True for r in report['checks'])
            assert report['actual_C_direct_dictionary_equal'] is False
            assert report['original_active_run_type']==2 and report['parsed_active_run_type']==3
            receipt['report']=file_pin(output/'report.json')
        batch.phase('primitive',profile,['--headless','--script',str(script)],values,validate,120)
        receipt['complete']=True
    except BaseException as error:
        code=1
        receipt['failure']=repr(error)
    finally:
        try: batch.release()
        except BaseException as error:
            code=1;receipt['complete']=False;receipt['finalization_failure']=repr(error)
        receipt['lock_released']=not batch.locked
        receipt['finished_utc']=dt.datetime.now(dt.timezone.utc).isoformat()
        persist()
        write_new(run/'receipt.json',receipt)
        print(json.dumps({'run':str(run),'complete':receipt['complete'],'failure':receipt.get('failure')},ensure_ascii=False))
    return code

if __name__=='__main__': raise SystemExit(main())
