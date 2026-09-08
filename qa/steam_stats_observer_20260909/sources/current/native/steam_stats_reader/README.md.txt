# Steam statistics reader

Read-only Windows x64 GDExtension for the pinned Steamworks 1.65 runtime. It
attaches to an already loaded and initialized `steam_api64.dll`. It never loads
Steam, initializes/shuts it down, pumps callbacks, or calls a write API.

The native `SteamStatsReader.query(command)` API returns JSON. The production
facade `scripts/steam_stats_reader.gd` validates types and assembles all four
statistics and 30 achievements. Use on the main thread, with one owner per
reader. The normal SteamService startup does not yet activate this reader.

Commands:

- `identity`: current app and account, with account changes permanently closing
  the reader. A missing/uninitialized Steam client never supplies an empty seed.
- `current_stat NAME`, `current_achievement NAME`: preserve each native getter's
  success flag. These are explicitly labelled `current_cache`.
- `request OWNER`: same-account RequestUserStats, returning the full unsigned
  SteamAPICall_t as a 16-character hexadecimal string; at most one pending read.
- `poll HANDLE`: IsAPICallCompleted and GetAPICallResult for that exact call,
  callback 1101, Windows 24-byte UserStatsReceived_t; validate app/result/account.
- `user_stat NAME`, `user_achievement NAME`: allowed only after that read
  succeeds. Return its handle and `requested_user_cache`, preserving getter
  failure separately from valid zero/false. A failed getter retires that read.

A request may stay pending indefinitely; callers must not relabel an old result
as a new request after a local timeout. Subsequent completed requests are allowed
in the same process. No local receipt, StoreStats generation, durable outbox,
acknowledgement or multi-device merge guarantee is implemented here. A correlated
read identifies a read operation, not a write batch. In particular the current
user's cache/server behavior still requires live validation before it is used
to retire a persistent publication attempt.

## Build and test

Run `py -3.14 -X utf8 -B tools/build_steam_stats_reader.py` from the repository.
Visual Studio C++ tools, its CMake/Ninja components and Python are required.
The compiler is discovered with vswhere; `--vcvars` overrides it. A pinned
Godot 4.4 godot-cpp archive is downloaded and hash-checked; it is build-only.
`RefCounted` and `OS` are the selected binding profile. The generated DLL links
the release binding and C++ runtime statically. No external C++ runtime installer
is required. The game engine remains the existing Godot 4.6.3.

Native build directories must use an ASCII path (`--work-root`, default
`D:/CodexTemp/lsh_reader_build`). Godot user profiles are separate, exclusive
directories (`--profile-root`, default `D:/CodexTemp/lsh_reader_profiles`). The
runner owns the shared Godot lock and uses an isolated minimal project. Extension
paths are registered before its first import to avoid the late-discovery crash
described in Godot issue #111645. This is not an engine patch.

The fake Steam DLL is a **test-only ABI fixture**. It has no Steam init/write
exports and never enters vendor or an export package. `reader_test.cpp` tests
the core using a fake API; `steam_stats_reader_qa.gd` exercises the actual compiled
DLL through Godot, both without Steam and against the synthetic ABI fixture.
These tests do not constitute live Steam account acceptance.

## Dependency sources

- Godot C++ bindings: https://github.com/godotengine/godot-cpp/tree/godot-4.4-stable
  (MIT; fixed archive SHA256 in the build runner and build receipt).
- `third_party/gdextension_interface.h`: unchanged Godot 4.4 header from
  https://raw.githubusercontent.com/godotengine/godot-cpp/godot-4.4-stable/gdextension/gdextension_interface.h
  SHA256 `355ff4c6254fdd434ea16d9a8ef0f18e3f95aeb3e3f00d98db10769ece3c7fe5`.
  Its copyright and MIT license remain in the file; used by the ABI fixture.
- Steam interface contract: https://partner.steamgames.com/doc/api/ISteamUserStats
  and https://partner.steamgames.com/doc/api/ISteamUtils#GetAPICallResult .
- First-import issue: https://github.com/godotengine/godot/issues/111645 .
