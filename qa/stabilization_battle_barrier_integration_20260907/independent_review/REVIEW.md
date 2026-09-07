# Actual Battle capture barrier: independent static QA preparation

Reviewed on 2026-09-07 against the archived candidate under
`qa/stabilization_battle_barrier_draft_20260907/original/` and the actual
production scripts in this checkout. The parent supplied HEAD
`b074ba91c28a9e24a32b1ad2469522094f8267cd`; this branch did not mutate Git,
production scripts, candidate archives, shared documentation, or launch Godot.

## Immediate findings and disposition

1. **Original driver timing can fail without a product defect.**
   `original/barrier_smoke.gd.txt:376-378` waits five `process_frame` signals
   and requires `Engine.get_physics_frames()` to increase. Five unconstrained
   headless render iterations do not establish that a physics interval elapsed.
   Keep the first failing receipt; test Engine progress by awaiting actual
   `physics_frame` signals. The parent reports R2 already made this correction
   without changing the four product candidate scripts.

2. **Root fixture mutations must be unwound before live engine resume.**
   `original/barrier_smoke.gd.txt` installs cache and negative-extent Rect2 test
   values directly in the actual Battle before its final release. A value-codec
   fidelity test can intentionally preserve a Rect2 that is unsuitable for
   `unit_visual_active()` / renderer geometry calls in a running world. Save and
   restore all 105 original root fixture values before release; keep every
   strict roundtrip assertion. The parent reports the first live continuation
   reached a WorldShadow negative-size Rect2 error, and R2 restores the original
   fixture state and passes 6,482 checks. These run results are parent-reported,
   not an independent engine run by this branch.

3. **A successful root v3 detached bind is not an attachable restored Battle.**
   Candidate `battle.gd.txt:391-407` unconditionally creates and initializes a
   new clock and gate before testing restore RNG state. Root
   `run_battle_root_state.gd.txt:526-595` installs the saved clock into a
   detached, disabled Battle, but its returned contract explicitly requires an
   outer install/activate transaction. Attaching that object through the
   current `_ready()` would overwrite the saved clock and hit the existing
   `RESTORE_FACTORY_REQUIRED` fail-stop. This is an explicit remaining product
   gate, not a newly introduced failure of the supported new-game path.
   The outer factory must preserve the bound clock, configure the gate with
   that same object, suppress normal deploy/on_start, and activate only once
   after all world references are valid.

4. **Paused tree traversal is a limited quiescence check.**
   Candidate `run_battle_barrier.gd.txt:106-156` examines queued/deleted nodes,
   thread groups, process priorities, and enabled callbacks inside Battle.
   It cannot enumerate pending SceneTreeTimer continuations, arbitrary
   `process_frame` signal continuations, or Autoload callbacks outside Battle.
   Actual classic production source inspected here has no gameplay deferred
   coroutine in `Projectile`, `LiBrawnAxesFx`, or `skirmish`; Unit schedules
   a one-shot redraw, and HUD schedules layout/scroll work. Thus no concrete
   gameplay write escaping HELD was established for this restricted case.
   Do not extend the gate's claim to arbitrary campaigns or future async
   gameplay merely because `health().ok` is true.

5. **The true damage paths require both callback families.**
   `scripts/projectile.gd:69-135`: physics advances flight, calls real
   `take_damage`, triggers normal hit consequences, then `queue_free`.
   `scripts/battle.gd:15415-15460`: LiBrawnAxesFx advances `elapsed` in
   `_process`, resolves its stored hit list, calls real `take_damage`, spawns
   impact effects, then `queue_free`. A physics-only harness or a hand-invoked
   `resolve_hits()` does not prove either pause boundary end to end.

No additional confirmed product defect in the supported new-game gate was
established by this static review. Native error-free parsing or the existing
root smoke pass must not be reported as a full saved-game implementation.

## Prepared executable additions

- `actual_damage_driver_fragment.gd.txt`
  SHA-256 `ebc425d91a686fc3d98c12ddb91ffff6d867453130c92913160451a4d049ba31`.
  Insert after the original root values have been restored and its first
  capture released. Creates two actual Battle Units, turns off only their
  autonomous physics, and lets real Battle callbacks populate the spatial
  grid. Uses real user pause and real effect creation. Checks live Projectile
  and LiBrawnAxesFx remain unchanged through five real physics frames in HELD;
  releases through actual gate/UI callbacks; waits for real engine damage and
  self-deletion; cross-checks exact target HP and hero damage deltas and a
  further 12/30 physics frames with no repeated hit.
- `actual_drain_fragment.gd.txt`
  SHA-256 `7060dd52eaddfb8191c1b8af53366d19d29ab5e605ff329e25c58f29fc11b2c8`.
  Call `_qa_exit_capture_cases(caster, victim)` before the first fragment's
  final return. Each real effect's `tree_exiting` callback requests capture
  exactly once. At HELD, the original object must actually be freed and the
  nonlethal HP/stat delta must already be present once. Five held physics
  frames and 12 resumed physics frames must retain exact damage and healthy
  source cache/RNG state. Records the queue-free flush's actual Engine phase;
  does not mislabel it as the originating damage callback's phase.

Both fragments pass gdtoolkit grammar parsing with the existing isolated
parser runtime. This is static syntax evidence only. ROOT owns source pinning,
the existing native runner, real engine scheduling, and receipt evaluation.
The original fragments are immutable inputs once ROOT freezes a run; adjust
any failed test in a new attempt and preserve the failure.

## Fixture assumptions to review from native evidence

- Actual open land pair 128 pixels apart, at least 480 pixels from existing
  combatants/buildings. If the restricted land layout cannot provide one, the
  fragment fails explicitly. Any relaxed isolation needs a new recorded
  attempt and an actual weapon-range/non-interference justification.
- The two test Units remain alive and registered until the existing driver's
  final `battle.free()`. Do not manually free them behind Battle's registries.
- Plain enemy target has no active shield, immunity, damage amplification, or
  damage reduction. The first fragment checks these conditions rather than
  clearing production status fields to force expected damage.
- Effect time/position/lifetime and damage consumers are never manually
  advanced. The axes expected damage is read from the actual creator's hit
  plan, with a required positive nonlethal bound.
- The original 105-field root assertions and field inventory stay unchanged.
- No real Steam account is called by this branch; native runs still require
  the existing isolated profile and portable/test environment guards.

## Follow-on matrix and uncovered scope

| Case | Required observation | Status in this branch |
| --- | --- | --- |
| Projectile pending during HELD | HP, position, lifetime frozen; real resumed damage once; self-free | Fragment prepared |
| Axes pending during HELD | HP, elapsed, resolved false held; actual idle damage once; self-free | Fragment prepared |
| Capture requested by each real effect exit | Exactly one request, queued object absent by ready, HP already debited once | Fragment prepared |
| Request from actual lethal `Unit.died` callback | Physics and idle request phases; registry removal, rewards and death strips consistent | Design only; needs fresh non-interfering lethal fixtures |
| Nested deferred creator and cleanup | Actual nested deferred work drains before ready, successor effect captured or explicit rejection | Not exercised; needs owned test continuation plus real creator |
| HUD/camera direct input and pause transitions | Commands blocked while HELD, original modes/signals restored, preexisting pause retained | Original ROOT driver; no independent run |
| Changed processing modes or reserved physics edge priorities | Reject unsupported active world without a partial saved snapshot | Static contract only |
| Whole world attach and restored clock activation | No new deploy, correct clock object shared by gate/root, one activation | Factory not implemented |
| Other effects, death remains, building collapse, continued queues | Every live node/reference either fully represented or rejected | Incomplete world graph |
| Cross-process restore and replay | Exit/restart, actual continued damage/production/settlement equivalence | Not covered |
| Persistent disk slot, interrupted writes, menu | Transaction integrity and user-visible continue behavior | Not covered |
| Campaign/AI/custom/Workshop and variable settings | Explicit supported contract and per-mode runtime coverage | Outside current classic-only gate |

Before production promotion, ROOT should use actual receipts for the first
three new rows, keep the full earlier checks, and document the remaining
factory/disk/world-effect limits. Passing these additions proves a stronger
capture boundary in a running new game; it does not prove Continue Game.
