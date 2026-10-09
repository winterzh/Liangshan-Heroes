"""Explicit seed -> imported -> generated identity transition in private staging.

No native launcher. Uses the original readonly identity grammar/constant writer
while admitting one exact derived-file transition rather than rebasing a tree.
"""
from pathlib import Path

from campaign_real_sdk_bootstrap_contract_v4 import no_links, require
from campaign_file_fault_prior_v2 import verify_closed_prior_v12
from durable_campaign_full_runtime import FrozenProject, OwnedSerialBatch, inventory, sha
from run_workstation_baseline import engines
from run_steam_integration_qa import LOCK
from contracts.run_content_identity_20260907 import build_identity as identity


def replace_derived_row(cold, derived):
    """Pure inventory transformation, never ownership or actual generation proof."""
    require(type(cold) is list and type(derived) is dict
            and set(derived)=={'path','bytes','sha256'}
            and derived['path']==identity.DERIVED, 'ONLY_FIXED_DERIVED_ROW')
    paths=[r['path'] for r in cold]
    require(len(paths)==len(set(paths)) and paths.count(identity.DERIVED)==1,
            'ONE_ORIGINAL_DERIVED_ROW')
    return [dict(derived) if r['path']==identity.DERIVED else dict(r) for r in cold]


class SDKExportFrozenProject(FrozenProject):
    def __init__(self, project, inputs, prior_receipt, prior_spec):
        # The old failed/scoped receipts cannot create or seed any staging tree.
        _,self.prior_pin=verify_closed_prior_v12(prior_receipt,prior_spec)
        require(inputs['schema']=='real_sdk_bootstrap_export_inputs_v2'
                and len(inputs['runtime_and_harness_overlays'])==29,
                'EXACT_REVIEWED_PRIVATE_EXPORT_INPUTS')
        no_links(Path(project))
        super().__init__(project,inputs)
        self.identity_receipt=None
        self.seed_pin=None

    def _all_original_paths(self):
        no_links(self.project)
        if self.project.exists():
            for path in self.project.rglob('*'):no_links(path)
        for row in self.inputs['runtime_and_harness_overlays']:no_links(Path(row['path']))

    def prepare(self):
        super().prepare()
        require(not any(r['path']==identity.DERIVED for r in self.before),
                'NO_EXISTING_DERIVED_SOURCE_CAN_BE_REPLACED')
        path=self.project/identity.DERIVED;no_links(path)
        with path.open('xb') as stream:stream.write(identity.STUB)
        self.seed_pin={'path':identity.DERIVED,'bytes':len(identity.STUB),'sha256':identity.sha(identity.STUB)}
        expected=sorted([*self.before,self.seed_pin],key=lambda row:Path(row['path']))
        require(inventory(self.project)==expected,'ONLY_ONE_DECLARED_SEED_ADDITION')
        self.before=expected
        return self.before

    def check(self):
        self._all_original_paths()
        require(sha(self.prior_pin['path'])==self.prior_pin['sha256'],
                'ORIGINAL_SUCCESSFUL_PRIOR_RECEIPT_UNCHANGED')
        super().check()
        if self.identity_receipt is not None:
            identity.verify_generated(self.project,self.identity_receipt)

    def generate_identity(self,batch):
        require(isinstance(batch,OwnedSerialBatch) and batch.frozen is self
                and batch.child is None and batch.locked and batch.lease_ready
                and self.project==batch.run/'project' and self.cold is not None
                and self.identity_receipt is None and self.seed_pin is not None,
                'ORIGINAL_IDLE_OWNED_BATCH_AND_ONE_GENERATION')
        no_links(LOCK)
        lock_stat=LOCK.stat()
        require((lock_stat.st_dev,lock_stat.st_ino)==batch.lease_identity
                and LOCK.read_text(encoding='utf-8')==str(batch.run) and not engines(),
                'REAL_GLOBAL_LEASE_AND_NO_FOREIGN_ENGINE')
        self.check()
        path=self.project/identity.DERIVED;no_links(path)
        require(path.read_bytes()==identity.STUB,'ORIGINAL_EXACT_SEED_BYTES')
        record=identity.snapshot(self.project)
        constant=identity.identity_constant(record)
        # Last check occurs immediately before the single permitted source write.
        self.check()
        require(not engines() and path.read_bytes()==identity.STUB,'NO_ENGINE_OR_STUB_DRIFT_BEFORE_WRITE')
        path.write_bytes(constant)
        derived={'path':identity.DERIVED,'bytes':len(constant),'sha256':identity.sha(constant)}
        expected=replace_derived_row(self.cold,derived)
        require(inventory(self.project)==expected and not engines(),
                'ONLY_DERIVED_BYTES_CHANGED_NO_FOREIGN_ENGINE')
        require(identity.snapshot(self.project)==record,'ORIGINAL_INPUT_GRAMMAR_UNCHANGED')
        receipt={'kind':'content_identity_generation','identity':record,'derived':derived,
                 'generator_sha256':identity.sha(Path(identity.__file__).read_bytes()),'godot_run':False}
        identity.verify_generated(self.project,receipt)
        # An explicit singleton-row transition; never accept the current tree wholesale.
        self.cold=expected
        self.identity_receipt=receipt
        self.check()
        return receipt
