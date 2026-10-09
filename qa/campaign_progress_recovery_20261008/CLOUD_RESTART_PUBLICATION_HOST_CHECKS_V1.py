"""Synthetic publication files only; never construct native Popen or consumers."""
import hashlib
import json
from pathlib import Path
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
QA = Path(__file__).parent
sys.path.insert(0,str(ROOT/'tools'))
sys.dont_write_bytecode = True
from campaign_cloud_restart_exports_v1 import CallbackNativeExports


class FixtureSuite:
    def __init__(self,run,step):
        self.run = run
        self.batch = type('SyntheticBatch',(),{'steps':[step]})()
        self.pins = {}
    def freeze_bytes(self,path,expected):
        path = Path(path)
        raw = path.read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        assert digest == expected
        assert path not in self.pins or self.pins[path] == raw
        self.pins[path] = raw
        return raw
    def persist(self):pass


def main():
    run = Path('D:/CodexTemp')/('lsh-cloud-restart-publication-fixtures-'+uuid.uuid4().hex[:8])
    (run/'steps').mkdir(parents=True,exist_ok=False)
    payload = '{"synthetic_only":true,"text":"原始字节"}\n'.encode('utf-8')
    digest = hashlib.sha256(payload).hexdigest()
    results = []
    for name in ['valid','missing_marker','wrong_pid','wrong_nonce','extra_name','duplicate_marker','bad_marker','wrong_hash','missing_stage','existing_destination','malformed_JSON']:
        output = run/'steps'/name
        output.mkdir()
        step = {'pid':12345,'nonce':'a'*32,'output':str(output)}
        suite = FixtureSuite(run,step)
        stage = output/('report.json.native-'+step['nonce'])
        stage.write_bytes(b'not JSON' if name == 'malformed_JSON' else payload)
        marker = 'CAMPAIGN_FILE19_EXPORT 12345 %s report.json %s\n'%(step['nonce'],digest)
        if name == 'missing_marker':marker = ''
        if name == 'wrong_pid':marker = marker.replace('12345','12346')
        if name == 'wrong_nonce':marker = marker.replace('a'*32,'b'*32)
        if name == 'extra_name':marker = marker.replace('report.json','callback_driver_ready.json')
        if name == 'duplicate_marker':marker += marker
        if name == 'bad_marker':marker = marker.rstrip()+' trailing\n'
        if name == 'wrong_hash':marker = marker.replace(digest,'f'*64)
        if name == 'missing_stage':stage.unlink()
        if name == 'malformed_JSON':marker = marker.replace(digest,hashlib.sha256(stage.read_bytes()).hexdigest())
        (output/'native.log').write_bytes(marker.encode())
        destination = output/'report.json'
        if name == 'existing_destination':destination.write_bytes(b'{"existing":true}\n')
        old_destination = destination.read_bytes() if destination.exists() else None
        original_stage = stage.read_bytes() if stage.exists() else None
        accepted = False
        error = ''
        try:
            publisher = CallbackNativeExports(suite,step)
            publisher.require_complete('cloud_applying_callback_no_upload_claim')
            accepted = True
            if name == 'valid':
                publisher.require_complete('cloud_applying_callback_no_upload_claim')
                assert destination.read_bytes() == payload and stage.read_bytes() == payload
                assert step['actual_native_exports']['report.json']['sha256'] == digest
        except Exception as failure:error = repr(failure)
        assert accepted == (name == 'valid'),(name,accepted,error)
        if old_destination is not None:assert destination.read_bytes() == old_destination
        elif not accepted:assert not destination.exists()
        if original_stage is not None:assert stage.read_bytes() == original_stage
        results.append({'case':name,'expected_accepted':name == 'valid','accepted':accepted,'error':error,'passed':True})
    value = {'schema':'cloud_restart_publication_synthetic_host_checks_v1','fixture_run':str(run),'checks':results,
             'passed':True,'check_count':len(results),'actual_native_Popen_constructed':False,
             'actual_consumer_validate_executed':False,'GD_parsed':False,'native_started':False,
             'source_only':True,'ordinary_restart_qualified':False,'original19_qualified':False,'overall_goal_qualified':False}
    with (QA/'CLOUD_RESTART_PUBLICATION_HOST_CHECKS_V1.json').open('x',encoding='utf-8',newline='\n') as out:
        json.dump(value,out,ensure_ascii=False,indent=2)
        out.write('\n')
    print(json.dumps({'synthetic_checks_passed':len(results),'native_started':False,'actual_Popen':False}))


if __name__ == '__main__':main()
