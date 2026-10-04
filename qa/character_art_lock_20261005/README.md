# Character-art QA pre-import lock fix

A different Godot starting during source freeze can refuse import before any child launches. The driver now releases only that exact run's lock in this proven pre-import case. Other owners are untouched; after any engine step the existing busy-engine protection remains.

Five real temporary-file checks passed, without touching the actual shared lock or controlling a process. Reproduce with `python -X utf8 -B tools/character_art_lock_selftest.py`. No runtime art, gameplay, packages or platform publication in this commit. Han Tao capture candidates remain local pending final visual QA.
