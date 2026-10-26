# Projectile component startup failure — 2026-10-27 07:41:53

This archive preserves the first native component attempt before the QA API correction. PID 30272 exited 1 after 38.625 seconds. The external worker loaded and reached `run()`, then called absent `ContinueFlow.can_launch_new_run`; actual 3365 exposes `can_launch`. No component report was produced and capture/prepare/restore/recapture or the 12 negative cases were not reached. This is a tool startup failure, not a Graph rejection or a passed component run.

All 11 original run files are byte-exact under `raw/`, including the old worker, host, parent source manifests, loader, candidate Graph, bindings, log and receipt. `source_map.json` maps every receipt pin to embedded original bytes or its verified named original path; native binaries retain only their recorded hashes. Reference files are not a complete project archive. No profile, business payload, executable, DLL, assets or cache is copied.

The failed receipt remains `complete=false`. Its actual terminal child, unchanged named inputs, owned lock and idle-lane checks all passed and `lock_released=true`. No claim is made for full-source, combined cold freeze, natural gameplay, public entry, SDK, or human acceptance. The later repaired worker must be recorded in a different run.
