# Gameplay RNG source-mode evidence, 2026-09-07

`runs/r1/` preserves successful run `20260906T182336421379Z`: writer137 checks, reader47 checks, 7 seeds and448 continued draws. WriterPID652 and readerPID31604 both exited0. `runs/original_failed/` preserves predecessor `20260906T180630045299Z`: writerPID20576 exited1 during script parsing; its12 environment/source checks are not successful RNG behavior coverage.

All copied files retain their original bytes. `archive_manifest.json` lists the source path, size, SHA256, archive path and original restore location. The archive excludes private profiles, copied projects, Godot caches, executables and real player file contents; player JSON files contain directory/file-name/hash summaries only.

## Restore the exact source layout before rerunning

Use a separate compatible checkout with the recorded production source and the same official Godot4.6.3 Windows executable. For each manifest entry with a non-null `restore_path`, restore its bytes there after validating SHA256. The `.gd.txt` and `.py.txt` suffixes are archival names; remove only the added final `.txt` by following the manifest's explicit destination. Do not overwrite a different existing file. R1 restores to `scratchpad/run_gameplay_rng_r1/`; the original failed sources remain separate in `scratchpad/run_gameplay_rng/`.

The runtime codec and two imported helpers are pinned under `dependencies/`. The RNG runner uses only the process helper's lifecycle functions and the source guard's receipt/project-name functions; it does not invoke their standalone development commands. Historical report directories are evidence inputs, not destinations for another run.

Run the restored `scratchpad/run_gameplay_rng_r1/run_qa.py` with Python3.9 or newer and `--godot <actual Godot executable path>` for read-only preflight. Its `--run` mode must be owned by the root task with an exclusive Godot slot; it creates a new timestamp, fresh private project and independent writer/reader user directories. Do not run it directly from the archived `.py.txt` path or reuse old reports as a new pass.

The prepared pins still say `FROZEN_PREPARED_NOT_ENGINE_TESTED` and `godot_runs: 0`; those are unchanged preparation facts. Current completed results are in `runs/r1/receipt.json`. The helper process receipt's inherited `scope` label describes its generic lifecycle helper, while the RNG reports and runner receipt identify the actual suite.

This is an isolated RNG stream and strict checkpoint restoration test. Production RNG migration, Battle resume, PCK source identity and menu continue remain unimplemented by this work. The broader ongoing goal remains open.
