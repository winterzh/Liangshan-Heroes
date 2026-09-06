# Death-remains and death-shadow focused verification

Date: 2026-09-05

Scope owned by this check:

- `scripts/battle.gd`
- `scripts/world_shadow.gd`
- `tools/skirmish_death_remains_test.gd`

Implemented contracts:

- Normal death remains still live for 45 seconds, fade for the final 8 seconds,
  and remain capped at 48 (lite mode remains 24/5/24).
- Blood and debris use per-frame scales: blood `0.65`, spear `0.45`, armor
  `0.25`, shield/arrows `0.38`, cloth/staff `0.30`.
- Remains stay hidden through `0.35s`, then fade in over `0.20s`.
- The generic four-direction position offset is zero. Direction provenance is
  retained, while the mark stays at the victim's logical foot point until an
  authored unit-by-direction contact table exists.
- A dead mobile unit is removed from `Battle.units` first, then retained only in
  `WorldShadowBatch` until its existing `Unit.DEATH_DUR` lifecycle frees it.
  Shadow opacity follows the existing death fraction. Retained entries are
  pruned in place, early-freed bodies are safe, and campaign-section cleanup
  clears the render-only list.

Verification:

- Godot editor parse: exit `0`, no script errors.
- Focused headless death-remains test: `28/28 PASS`.
- Focused graphical death-remains test: `31/31 PASS`; review captures are
  `skirmish_death_remains_1280.png` and `equipment_scale.png`. The latter forces
  all five frames beside real death-down Units rather than relying on random
  selection. Square-size ratios versus the adjacent Unit are `0.9135` blood,
  `0.6324` spear, `0.3514` armor, `0.5341` shield/arrows and `0.4216` cloth.
- Campaign core regression: PASS, including lifetime, fade, 48-node cap,
  eviction, exclusions, terrain binding and cross-section cleanup.
- The broader `world_shadow_visual_test.gd` was also routed into the `world_shadow`
  subdirectory. Its mobile shadow draw, batching, route exclusivity and rendered
  darkening checks passed. Its final report is FAIL only because four pre-existing
  fixture expectations still assume skirmish/custom-defense have no scenery and
  an identity ground basis; current maps now provide scenery and a nonzero height
  basis. That fixture was not changed in this scope.

Source hashes before this focused change:

- `scripts/battle.gd`: `018e97bfa4f6a2a2c00b33960e8c37dbbc4a6007507d942b39e4aeafae459a02`
- `scripts/world_shadow.gd`: `629bc58f07d6bbcf1e58f5414e9a7c47921d0a0b44562cac76a3d59279f1e254`
- `tools/skirmish_death_remains_test.gd`: `a46ac0bb2fbe4062cd52446865943c00af279e20fcf852e201e4b1c8327da676`

Source hashes at verification time:

- `scripts/battle.gd`: `2d15ed9f5bff9477361c9a33dae1f121b122f9bc28986c2d172e51f861096dfa`
- `scripts/world_shadow.gd`: `69a12b35c8f9e83051b790fec6f80a917ba6ebe96d8a1577a664b9bea0ce76c4`
- `tools/skirmish_death_remains_test.gd`: `baeb7b1733b5f7f00d71d5d5f9ceafe2e73e8b04be12ce970a096ec2b72c3c9d`

No production PNG, export, Steam upload or release action was performed by this
focused check.
