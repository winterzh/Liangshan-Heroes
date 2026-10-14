"""Retain full V3 acceptance and additionally prove real signed-zero physical snapshots."""
from pathlib import Path
from campaign_original19_data_evidence_v3 import DataEvidence as OriginalDataEvidence, typed_equal
from durable_campaign_full_matrices import require

class DataEvidence(OriginalDataEvidence):
    def run(self):
        result=super().run()
        proof=self.report['signed_zero_evidence']
        require(type(proof) is dict and set(proof)=={'fixture','snapshots'},'Exact additional signed-zero evidence')
        fixture=proof['fixture']
        require(type(fixture) is dict and set(fixture)=={'variant_type','ieee_hex'}
                and type(fixture['variant_type']) is int and fixture['variant_type']==3
                and type(fixture['ieee_hex']) is str and fixture['ieee_hex']=='0000000000000080','Actual runtime negative-zero fixture bytes')
        snapshots=[self.report['commits'][5]['actual'],self.report['commits'][6]['actual']]
        snapshots += [self.report['cases'][3]['after_CFG']]
        snapshots += [self.report['cases'][index][side] for index in [4,5] for side in ['before_CFG','after_CFG']]
        snapshots += [self.report['final_CFG']]
        actual=proof['snapshots']
        require(type(actual) is list and len(actual)==len(snapshots)==8,'All eight full original signed-zero physical snapshots')
        require(len({snapshot['copy']['copy_path'] for snapshot in snapshots})==8,'Distinct original snapshot copies')
        for row,snapshot in zip(actual,snapshots):
            require(type(row) is dict and set(row)=={'copy','variant_type','ieee_hex'}
                    and typed_equal(row['copy'],snapshot['copy'])
                    and type(row['variant_type']) is int and row['variant_type']==3
                    and type(row['ieee_hex']) is str and row['ieee_hex']=='0000000000000080','Fresh native ConfigFile load preserves negative-zero bits with exact original copy binding')
            copy=snapshot['copy']
            path=Path(copy['copy_path'])
            require(path.resolve() in self.files,'Original full physical consumer already verified this signed-zero copy')
            raw=self.suite.freeze_bytes(path,copy['sha256'])
            require(len(raw)==copy['bytes'],'Same first original signed-zero physical copy bytes')
        result.update(actual_signed_zero_fixture_verified=True,actual_signed_zero_CFG_snapshots=8)
        return result
