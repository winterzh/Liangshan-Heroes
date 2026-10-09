"""Correct recorder output labels without changing successful native receipt/snapshots."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    receipt=QA/'campaign_units_qualified_v19c.json';r=json.loads(receipt.read_text(encoding='utf-8'))
    assert r['complete'] and r['result']['character']=='campaign_units_v19d' and r['result']['checks']==767
    review=json.loads((QA/'campaign_units_review_v19c.json').read_text(encoding='utf-8'));assert review['receipt_sha256']==sha(receipt)
    before=[dict(row) for row in review['cases']]
    for row in before:assert sha(ROOT/row['path'])==row['sha256']
    pairs=[('campaign_units_qualified_v19c.json','campaign_units_qualified_v19d.json'),('campaign_units_verified_log_v19c.txt','campaign_units_verified_log_v19d.txt'),('campaign_units_review_v19c.json','campaign_units_review_v19d.json'),('campaign_units_native_snapshots_v19c','campaign_units_native_snapshots_v19d')]
    for old,new in pairs:
        source=QA/old;target=QA/new
        assert source.resolve(strict=True).is_relative_to(QA.resolve(strict=True)) and target.parent.resolve(strict=True)==QA.resolve(strict=True) and not target.exists()
    for old,new in pairs:(QA/old).rename(QA/new)
    for row in review['cases']:
        row['path']=row['path'].replace('campaign_units_native_snapshots_v19c/','campaign_units_native_snapshots_v19d/');assert sha(ROOT/row['path'])==row['sha256']
    p=QA/'campaign_units_review_v19d.json';p.write_bytes((json.dumps(review,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    for name in ['WORKLOG.md','SOURCE_SETUP.md','PROJECT_STATUS.md','DEVELOPMENT_PLAN.md','DIRECTORY_INDEX.md','CHARACTER_POSTURE_20261006.md','DEVELOPMENT_AUDIT_20261006.md']:
        p=ROOT/'docs'/name;s=p.read_text(encoding='utf-8')
        for old,new in pairs[:3]:assert s.count(old)==1;s=s.replace(old,new)
        p.write_bytes(s.encode('utf-8'))
    record={'reason':'The v19d recorder locator/harness names were updated but three evidence output labels still said v19c. Correct labels only; original executed recorder retained.',
      'renames':pairs,'receipt_sha256':sha(QA/'campaign_units_qualified_v19d.json'),'native_snapshot_hash_drift':0,'reviewed_cases':7,'producer_sha256':sha(Path(__file__))}
    p=QA/'campaign_units_evidence_names_v19d.json';assert not p.exists();p.write_bytes((json.dumps(record,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    print(json.dumps({'label_corrected':'v19d','checks':767,'native_snapshot_hash_drift':0}))
if __name__=='__main__':main()
