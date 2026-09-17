# Independent-account statistics observer (internal, 2026-09-09)

This source adds `SteamStatsObserver.observer_query(command)` beside the existing
`SteamStatsReader.query(command)`. It does not change the current-user reader,
SteamService, persistent outbox, achievements, Steam configuration, or the vendor
DLL. Until the rebuilt DLL is separately validated and promoted, the new facade
returns `OBSERVER_UNSUPPORTED` for the old installed runtime.

## Purpose and limits

An observer is the Steam account already logged into this process. A target is
a different, explicitly supplied account. The observer requests the target's
statistics and achievements through `RequestUserStats(target)` and uses only
`GetUserStat` / `GetUserAchievement` for that target. It does not initialize Steam,
dispatch callbacks, load libraries, request credentials, or invoke any write API.

Valve documents that `RequestUserStats` downloads the specified user's data from
the server and must be called again to refresh it:
[official API](https://partner.steamgames.com/doc/api/ISteamUserStats#RequestUserStats).
The resulting data still comes from Steam's requested-user cache. A successful
snapshot is labelled `independent_requested_user_cache` and
`write_confirmation: false`. It is not a transaction snapshot or proof that a
particular StoreStats call, local intent, or generation was accepted. No outbox
confirmation or target comparison is implemented here.

Use the observer **only on the main thread**, and route all reads of its target
in this process through this observer. The registry and Steam cache are not
protected against another integration making independent `RequestUserStats`
calls for the same target outside this interface. No multi-account real Steam
acceptance has been performed for this code.

## Protocol 1

- `bind OBSERVER TARGET`: decimal uint64 strings, distinct and nonzero. Bind the
  expected observer to the actual account and AppID 5088120. One target per
  instance; an in-process lease rejects a second observer for that target.
- `identity`: returns protocol, app, observer, target and explicit cache source.
  Observer/app changes permanently close the instance; switching back cannot
  reopen it.
- `request`: requests only the bound target; returns the full unsigned SDK
  handle as 16 lowercase hexadecimal characters and `timeout_ms: 30000`.
- `poll HANDLE`: consumes only that outstanding `SteamAPICall_t`, using callback
  1101 and the existing verified Windows ABI. App, target, result, I/O status and
  the current observer are checked. A pending result contains no snapshot.
- `stat HANDLE NAME`, `achievement HANDLE NAME`: require the exact completed
  handle and no newer pending read. Getter failure retires the completed read;
  zero and false remain valid values. There are no current-cache commands.

All successful data responses carry both identities, app, protocol, source and
the applicable read handle. The facade validates every response and assembles
all four integer counters and 30 achievement booleans, then checks identity once
more. It never returns a partially valid snapshot. Native failures permanently
retire that facade. Unsupported native classes/methods fail explicitly; the
facade never calls the older `query` method as a fallback.

The monotonic 30-second native deadline is checked before and after the SDK's
request/completion/result calls. Timeout, clock regression, uncertain I/O/result,
an unexpected result identity, or destruction while a request is still pending
fences the target for the remainder of this process. A new observer cannot bypass
the fence: a late request may still mutate Steam's shared cache, so restart the
isolated observer process before retrying. This does not shut down Steam or cancel
SDK work. A duplicate handle is rejected; one instance has a 512-request limit.

## Isolated validation and next integration step

`py -3.14 -X utf8 -B tools/test_steam_stats_observer_native.py` discovers the MSVC
x64 compiler and builds/runs **only synthetic C++ test executables**. It records
source/compiler/executable/log hashes under `.godot/steam_observer_native/` and
runs the unchanged legacy reader tests alongside observer tests. It neither
invokes Git/Godot nor builds or installs a production DLL.

`tools/steam_stats_observer_qa.gd` is prepared for a separate isolated Godot run:

- Default mode uses supplied synthetic native objects, including the old-method
  compatibility rejection, corrupted identities/handles/source, getter failures,
  invalid value types, duplicate/late reads and timeout responses.
- `LSH_OBSERVER_NATIVE=1`, `LSH_READER_ABSENT=1` checks the compiled class without
  an initialized Steam DLL.
- `LSH_OBSERVER_NATIVE=1`, `LSH_MOCK_TARGET_OFFSET=1` exercises the compiled class
  using the repository's synthetic Steam ABI DLL; clear `LSH_READER_ABSENT`, set
  `LSH_MOCK_DONE=0` initially and clear other `LSH_MOCK_*` variables. This mode must
  use a fresh process because the final wrong-owner case intentionally fences
  its synthetic target. The mock's default target offset is zero, preserving the
  old reader test contract. The synthetic fixture is never installed in vendor.

`tools/validate_steam_stats_observer.py` coordinates that next validation:

```powershell
# Read-only preflight; it does not start Godot or a compiler.
py -3.14 -X utf8 -B tools/validate_steam_stats_observer.py
# Root runs this only after the shared engine slot is free.
py -3.14 -X utf8 -B tools/validate_steam_stats_observer.py --run
```

With `--run`, it first runs the native tests above, then invokes the existing
`build_steam_stats_reader.py` to compile the extension/mock and execute the
legacy absent/mock QA. That builder owns the existing shared Godot lock for its
engine phase. The wrapper next acquires the same lock for the three observer
cases, pre-registers native extensions before first import, and creates separate
minimal projects and exclusive private profiles. It hashes the observer inputs,
DLLs and logs and checks the mock's complete PE export allowlist before staging.
The checked-in vendor inventory must remain unchanged.

The wrapper writes evidence under `.godot/steam_observer_validation/`; the
existing builder retains its own receipts. A completed, source-identical builder
receipt can be supplied as `--build-receipt PATH` after an observer-only fixture
failure to avoid rebuilding it. It is rejected if native inputs were added or
changed, either legacy QA failed, the DLL hash differs, the engine differs, or
the mock export set does not match. Its mock DLL hash is captured in the new
validation receipt. `--work-root` and `--profile-root` retain the existing
no-reparse-point profile rules. Neither tool promotes files to vendor.

Native unit-test success alone does not validate class registration, GDScript
parsing, the rebuilt DLL, an export package, or real accounts. At this source
handoff, only native tests and wrapper preflight have run; root must complete the
controlled `--run` before DLL promotion. Persistent synchronization remains
`BLOCKED` even if every observer test passes.
