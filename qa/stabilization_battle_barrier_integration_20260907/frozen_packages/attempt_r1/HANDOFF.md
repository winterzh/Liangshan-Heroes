# Actual classic Battle barrier candidate

Four-file isolated overlay: Battle, run_battle_root_state v3, two new clock/gate
modules. No production changes. Uses accepted 2e40c4a modules as its base.

The complete-step serial and legacy cache phase are separate. New-game cache
queries remain equal to the current process Engine frame including INTRO, input
queries and ordinary user pause. Capture holds that phase; source release catches
up its existing anchor, while restored activation establishes a fresh anchor at
the saved phase. Existing AI/sep counters, passes, RNG and 60Hz remain unchanged.

The controller disables all current HUD nodes/signals and camera input, clears
only uncommitted gestures, gates Battle navigation/input callbacks, and pauses
after current physics callbacks. The next process boundary follows a paused
deferred/free drain; health rejects live processing, queued nodes, foreign thread
groups, physics priority edges, unsupported modes and faults. Full captures are
synchronous. Only official classic 30-wave FIGHT is supported here.

Driver barrier_smoke.gd -> tools/stabilization_battle_barrier/barrier_smoke.gd;
suite actual-classic-battle-barrier-candidate;
prefix [actual classic barrier QA] followed by a space.

Native validation remains pending. The driver runs the actual Battle and checks
root v3 JSON/detached binds and actual gate/release, but does not yet cover real
Projectile/LiBrawnAxes damage or campaign deferred tasks. Full world construction,
all effects, rendering state, disk transactions and player menu still need work.
Do not promote based on this preparation or the earlier scheduler fixture alone.
