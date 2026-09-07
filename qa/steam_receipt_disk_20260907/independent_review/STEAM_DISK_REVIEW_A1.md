# Steam disk/outbox fixture: independent static review of A1

2026-09-07. Scope: `scratchpad/parallel_steam_store_20260907/` root files
listed below, plus the referenced committed pure outbox model. No Godot run,
SDK call, production edit, or Git mutation was performed by this reviewer.
All conclusions below are source analysis; native execution remains ROOT's
exclusive queue. Agent `steam_disk` has acknowledged finding 1 and is making
an isolated `attempt_a2`; A1 is retained as evidence.

## Input pins

| A1 file | SHA-256 |
| --- | --- |
| receipt_disk.gd | 916fd83589a422309e4d8b48e066fa9c3d109a0bf0a8429b7e217e54ed47a60c |
| receipt_host.gd | 97a54e1ce117fde4a2b022cc7fdfe202224af6cfa2d0a19a514f96c4902e4ca4 |
| fake_sdk.gd | 1de717965d0eac36e86ccd2c7291b749cd7b7eb6d2b144af88cef4cf35c0f921 |
| worker.gd | 9d000e8e7a3917ad6540b6902ba9cf149fc7e1803b7abaeba061dc20a86fef75 |
| run_matrix.py | ea69f8abd3cdd6b99458c863a341019c3c85aad732ec5fcf96335b11885cf6f1 |

## Findings

### 1. Late success from A can acknowledge B in the same host session

Severity: blocks any claim of safe repeated publication/callback attribution
for the A1 host. `receipt_host.gd:103-109` validates application, account and
host session, then `transaction("stored")` passes the **current** `_inflight`
to the model. It does not receive an observable callback batch token.

Concrete sequence:

1. Publish batch A and receive success 1. A's marker is cleared and `_inflight`
   becomes empty.
2. Persist newer progress, then publish batch B under the same Host/session.
   B's uncertain marker is now on disk and `_inflight` is B.
3. A delayed duplicate success 1 from A arrives with the same application,
   account and session. The host calls `prepare_stored(owner, B, 1)` and
   clears B's uncertain marker without observing B's own result.

`worker.gd:120` labels a test “duplicate success cannot clear another batch”,
but that test only repeats success while no batch is in flight. It does not
execute step 2. This is a concrete source-level attribution defect plus an
overstated test label, not an arbitrary hostile input scenario.

The Steam branch owner acknowledged the issue and proposed a conservative A2
fixture restriction: one publication lease per process, shared across Host
instances/sessions and never reset by an acknowledgement. Thus B cannot be
issued in that process. The additional required test is A → success → B
rejected → late A success rejected → another Host/session still cannot issue
B. This is a limited safe fixture policy; it is not evidence of a complete
production Steam callback strategy. Real SDK process startup, authoritative
read and later publication cadence remain separate work.

### 2. Trace evidence is weaker than its possible interpretation

`fake_sdk.gd:_log` silently returns when opening the trace fails, but its
caller can still return success. `run_matrix.py` preserves crash evidence and
requires no trace byte changes during recovery, but does not independently
parse each original trace event and correlate `marker_sha256`/revision to the
corresponding committed uncertain journal record. The fake mutators themselves
do reopen the journal before touching their fake cache; that source check is
valuable, but is not a second observer validating a stored trace.

Recommended bounded correction: trace-write failure makes the fake SDK call
fail, and normal/selected crash cases assert trace presence, event identity,
marker SHA/revision and exact intended target. This does not require extending
the task to arbitrary malicious filesystem attacks. Agent `steam_disk` was
notified. Until checked in the subsequent attempt, avoid claiming independent
trace auditing or that a missing trace establishes no attempted SDK work.

## Supported static design conclusions

### Serialized writes and CAS

- `receipt_disk.gd:164-174` reserves `writing/` with a filesystem directory
  creation and writes an owner/PID/random-token identity. Existing writing or
  recovery state blocks another normal opener.
- `receipt_host.gd:37-80` holds its own non-reentrant busy state, acquires the
  disk lock, checks the opened revision/hash against the host head, prepares
  the model, completes synchronous disk close/readback, commits the exact
  model preparation, and only then releases the disk lock.
- `receipt_disk.gd:184-209` rechecks the actual chain revision/hash under its
  lock before creating `receipt.pending`; an intervening completed writer
  between `open_head()` and `mkdir()` cannot silently overwrite data. It either
  wins the directory race or fails the subsequent CAS.
- Any disk/model/lock-release failure latches the host fault or leaves lock
  evidence. The host does not proceed to SDK mutation on that failed write.
- The checkpoint instrumentation performs synchronous file writes and waits
  for an external kill without pumping SceneTree frames or callbacks. There is
  no intentional yield/reentrant callback inside the critical section.

### Uncertain marker before first fake SDK mutation

- `publish()` first commits the dispatch document, closes/reopens it, commits
  the in-memory model and releases the lock. Only then does it take the
  one-shot targets and call any fake `SetStat` or `SetAchievement`.
- Each fake mutator independently calls `open_head()` and requires a matching
  committed uncertain token and uncorrected receipt before fake cache writes.
- Partial `SetStat` failure and rejected `StoreStats` retain uncertainty and
  block another ordinary in-flight publication. Process restart cannot take
  ownership of the old token through model `open_document()`.
- These are fake adapter properties. No production `SteamService` or actual
  account is connected by this harness.

### Recovery and callback crash windows

- Journal records form a contiguous revision/hash chain. Complete valid
  pending state can move forward only if its revision and previous SHA extend
  the verified head. Torn/invalid pending data is retained and blocks recovery.
- Recovery requires a known writing owner record and a PID no longer running.
  PID reuse can conservatively block recovery; the code does not steal a
  possibly live writer. A `recovering/` directory serializes recovery and the
  complete inventory is rechecked before mutation.
- After dispatch-marker persistence but before/during fake SDK calls,
  recovery invalidates old run tokens and uses a synthetic exact server
  correction instead of replaying the old send.
- For result 1/8, the matrix cuts execution before preparation, during the
  pending write, after a complete pending write/rename, between disk/model
  commits and before unlock. A complete valid pending acknowledgement or
  invalidation can be adopted forward; a half-written record remains blocked.
- A process dying before writing lock-owner metadata, or during recovery's
  own sequence, is not automatically repaired. Unknown/missing owner metadata
  or surviving recovery directory is deliberately blocked. These windows are
  not exercised by the current 26-point matrix and should stay stated limits.
- File flush/close/readback plus process termination does not prove power-loss
  durability or storage-controller ordering. The fixture explicitly states
  `power_loss_tested=false`.

### The interruption matrix really terminates an owned process

`run_matrix.py:149-205` creates each Godot child with `Popen` and keeps its
process handle. A crash case must produce a checkpoint whose exact name and
PID match that child while it is still alive. The parent then calls
`active.kill()`, waits for exit and requires a nonzero exit code. Normal worker
`quit(0)` is rejected as an expected crash. A child that exits before the
checkpoint also fails. Each raw checkpoint, log and pre-recovery account
directory is preserved.

The normal importer/worker phases separately require exit 0, matching suite,
phase, PID and profile, and a nonempty all-passing check list. Engine errors
or warnings fail the run. Final cleanup only terminates the outstanding
owned child; it does not kill an arbitrary discovered Godot PID.

### Real player path protections

- The minimal test project has a private custom user directory and does not
  load production Autoloads or gameplay scenes. APPDATA, LOCALAPPDATA, TEMP and
  TMP are redirected under the unique run's private profile.
- Before any engine phase, the runner snapshots the actual production
  app-userdata directory and the real APPDATA location that the test project
  name would otherwise use. After each phase and finally, both full snapshots
  must remain identical.
- The worker and parent each compare actual user-data path against the private
  expected path. Source/dependency/frozen-project hashes and the current Git
  head are checked; Godot processes and the shared lock must be clear at
  completion.
- Fixture directory, owner names and ancestor paths reject links/reparse
  points. Corruption inputs are only copied fixture files. This review does
  not claim protection against arbitrary malicious filesystem races or an
  uncooperative external actor changing directories while a syscall runs.

## Handoff

A1 has a concrete repeated-publication callback-attribution defect. Preserve
its frozen package. Review A2's actual code and resulting native matrix before
acceptance, specifically the cross-Host lease tests and the trace checks. Even
after that, describe the result as a process-crash-tested local journal with a
fake SDK and a bounded publication policy, not production Steam exactly-once
delivery or real power-failure durability.
