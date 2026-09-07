# Pure Steam receipt outbox draft

The exact native-tested source is sealed as `.gd.txt`. Restore the names listed
in SOURCE_PINS.json into a NEW ignored scratchpad/<name>/ directory and verify
every SHA. Keep run_outbox_tests.py unchanged at that depth so it resolves the
current project. Never run the contract directory directly.

After obtaining the shared Godot slot, run:
`py -3.14 -X utf8 -B scratchpad/<name>/run_outbox_tests.py --freeze-sha256 ca40bd4edc4ab40c4ccef719e34e87072750bd87a056002198f20cad9b77f835 --run`

Without --run the tool performs read-only preflight. It creates a minimal fresh
private project and user profile, runs the original 88 receipt checks and 62
outbox checks, verifies source/player/PID/lock receipts, and never calls Steam.
Production catalog/state dependencies are pinned again in each run; use the
archived native receipt when reproducing the exact historical source.

This is a pure transaction model. A real host must serialize preparation,
synchronous filesystem persistence/readback and commit without await/reentry or
SDK callback pumping. No atomic disk adapter, user receipt path, real SDK read,
cross-process gameplay or crash durability is delivered by these tests.
