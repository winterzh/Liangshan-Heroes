# Root state R1: Rect2 transport only

This candidate has **not been parsed or run in Godot**. The original root candidate and template remain unchanged. The existing value codec does not support native Rect2, so the original root candidate would reject its always-present `_unit_draw_rect` during capture.

R1 adds three insertion sites to each frozen GD/template: two local helpers, the capture wire conversion, and the validation native reconstruction. `_unit_draw_rect` stays a native Rect2 in the declared field table, validation of root authority and actual bind. Its wire representation alone is an exact two-key dictionary `{position: Vector2, size: Vector2}` passed through the existing real value codec. The two components must be finite Vector2 values; no clipping, reordering, clamping or fresh viewport calculation occurs. Negative sizes and fractional/zero components remain representable. A malformed/missing rectangle is rejected before any bind assignment. No codec/production/old root module change occurs.

The candidate schema name remains `battle_root_state_v1`: the old unexecuted draft could not produce its intended snapshot because that required field was unencodable; no released-format compatibility is claimed. The root module still depends on the external factory, true paused/deferred/input barrier, entity graph and phase requirements documented in the frozen parent README. The existing 169-field classification (104 root, 65 external/diagnostic) is unchanged; this patch is not a general save/continue implementation or proof of engine phase equivalence.

`build.py` verifies exact frozen parent hashes, performs exactly three unique byte replacements for each of `root_state.gd` and `.gd.in`, then reverses them in reverse order and requires byte-for-byte equality to the original. It emits the two candidates, readable diffs, pins and a static receipt. It neither imports a runtime nor changes production or the parent source. A reviewed final provider correction requires fresh external source pins; version trust is still supplied by the parent transaction, never by the saved rectangle.

```powershell
& $python -X utf8 scratchpad/run_battle_root_state_r1/build.py
```

Parent's actual integration QA should capture the real root `_unit_draw_rect` at an ordinary nonzero viewport extent, JSON roundtrip and restore it before the original `unit_visual_active` consumer, comparing both rectangle components and representative inside/outside results. Include zero and fractional/negative components and malformed wire type/key rejection. This is an actual execution requirement, not a claimed static success.
