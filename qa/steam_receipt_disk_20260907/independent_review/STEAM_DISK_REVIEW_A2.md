# A2 follow-up: source-level fixes inspected

2026-09-07. Read-only follow-up to `STEAM_DISK_REVIEW_A1.md`. A2 was not yet
frozen at the time of this read. ROOT must match these bytes to the candidate
that actually runs, or obtain a fresh review of any later semantic changes.
No Godot or Steam API was invoked by this reviewer.

| File under `parallel_steam_store_20260907/attempt_a2/` | SHA-256 |
| --- | --- |
| receipt_host.gd | e49e16c7c6d4cb69e5d29b4f056f630be33b318367815473003e4b72d9d8705c |
| fake_sdk.gd | b0cbf089cc39847f3e1f797837161796483d64d8f07dbddec71a6f821aa4ca51 |
| worker.gd | 300f8af6bae03d2006f1d55d9a30b0398808f21f574b15e99f8fd8e65a045d72 |
| run_matrix.py | 97277cfb80d444fd5ffeb2341b702349e04815de057dde2024d549afbc43b9ff |
| receipt_disk.gd | 916fd83589a422309e4d8b48e066fa9c3d109a0bf0a8429b7e217e54ed47a60c |

## A1 findings addressed by the inspected source

1. The host now consumes a process-wide static publication lease after taking
   the committed one-shot SDK targets, before the first SDK mutator. Success
   does not reset that lease; a different Host/session shares the same lease.
   The worker now explicitly tries B after A's success, presents the late A
   success, and tries B through a new Host/session. These calls are required
   to reject while preserving the latest durable progress. This blocks the A1
   counterexample by prohibiting B, rather than inventing a Steam batch token.

2. Fake SDK trace writes now return a boolean; write/flush error prevents a
   mutator from reporting success. The parent runner adds `audit_trace()`:
   each event must match the owned worker PID, actual journal-record digest,
   owner/app/revision, payload digest/length, uncertain token and exact stat or
   unlocked-achievement target. Selected checkpoints require the expected
   trace presence/count; the second-stat-failure case requires exactly two
   events and the rejected second event. Contract requires exactly one
   StoreStats. Recovery must still leave trace bytes unchanged.

The A1 disk locking/forward recovery algorithm is byte-identical, so that part
of the earlier review remains applicable. The native interruption matrix is
still required before claiming these fixes passed runtime validation.

## Remaining limits that affect product interpretation

- At most one outbound batch per whole process is the tested restriction.
  Further local progress may be persisted, but periodic publication in a
  long-lived actual game process is not implemented by this approach.
- `accept_authoritative_fixture_read()` is intentionally synthetic. Its worker
  supplies the in-memory receipt's values as fake server data. This establishes
  the adapter's input gate, not a real fresh server read. In particular,
  requiring server equality with a receipt containing unsent local progress
  is not a production merge strategy; ordinary new local progress will often
  differ from the server. Production must distinguish acknowledged baseline,
  unsent deltas, session ownership and authoritative correction.
- Lock and account scope are controlled fixture paths and cooperating writers.
  Power failure, crash during recovery itself, missing lock metadata,
  cross-device merge and arbitrary hostile filesystem races remain outside
  the tested matrix. Torn or unknown state remains blocked without deletion.
- The trace audit is performed against preserved immutable journal records.
  It is stronger than trusting the fake SDK alone, but remains fake-SDK
  evidence. Production Steam callbacks and process-exit cache upload have not
  been exercised.

No further concrete defect was identified in the bounded A2 fixture policy
during this read. This is source-review acceptance of the described fixture
scope, not native PASS or approval to connect production SteamService.
