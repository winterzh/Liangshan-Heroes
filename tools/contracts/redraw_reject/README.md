# Redraw early-rejection validation contract

`before_e516c83.txt` contains the complete two pre-change helpers, preserved from
the e516c83 baseline. `methods.json` records its file SHA, each old method SHA, and
the two accepted production method SHAs. Method hashing normalizes CRLF to LF and
uses one trailing newline after stripping trailing whitespace. Do not update the
contract solely to make a changed helper pass; review its semantics first.

The Python preparation entry point checks only these two production methods
against fixed candidate hashes. Other Unit methods and project files may evolve;
they are freshly hashed for each run instead of being permanently pinned here.
The rendered candidate class inherits the actual production helpers. The timing
class copies their complete current bodies under separate names, with no request
override or dictionary instrumentation. The old classes use the frozen methods.
No tool applies, restores, or writes production Unit source.

## Run

Prepare from the project checkout:

```powershell
python tools/prepare_redraw_reject_validation.py
```

This creates a timestamped folder under `.godot/redraw_reject_validation/` and
prints JSON containing `manifest`, `render_output`, and `timing_output`. Set the
environment variables to those returned paths. `$godotExe` must come from the
local configured executable; the tool contains no machine-specific path.

```powershell
$env:CAMPAIGN_QA = '1'
$env:REDRAW_VALIDATION_MANIFEST = '<manifest returned by preparation>'
$env:REDRAW_VALIDATION_OUT = '<render_output returned by preparation>'
& $godotExe --path . --rendering-method forward_plus --rendering-driver vulkan --script res://tools/redraw_reject_qa.gd

# After the first process has fully exited:
$env:REDRAW_VALIDATION_OUT = '<timing_output returned by preparation>'
& $godotExe --path . --rendering-method forward_plus --rendering-driver vulkan --script res://tools/redraw_reject_timing.gd
```

Acquire an exclusive Godot time slot before running. Do not run against temporary
instrumentation or while another tool swaps reference/candidate source. Capture
the console and reject runs with script/engine errors, incomplete reports, or
source mismatch. This preparation tool does not launch a process or manage the
shared source lock. A new preparation is required after any source change.

Each run writes `source_before.json`, `source_after.json`, and `report.json`; render
QA also saves paired edge/reentry PNGs. Source receipts hash the actual scripts,
scenes, resources, assets, relevant QA tools/contracts, and generated classes.
Text is normalized to LF; binary data is hashed byte-for-byte. The prepared
snapshot is checked before any fixture starts, and the actual final snapshot is
checked after disposal. Preparation alone proves no GDScript/runtime result.

The schema-2 manifest explicitly lists the shared enumeration scope. Both Python
and Godot rescan `scripts`, `scenes`, `assets`, `shaders`, `resources`, `data`,
`addons`, `content`, and `scenarios`, plus `tools/contracts/redraw_reject`.
They also include root `icon.*` files (case-insensitive prefix), the six fixed
project/QA files declared in the preparation script, and this run's three
generated classes. Dot files, Windows-hidden files, and hidden directories are
included; links/reparse points are rejected instead of silently following them.
Godot uses absolute filesystem paths and
[DirAccess hidden-entry enumeration](https://docs.godotengine.org/en/stable/classes/class_diraccess.html#class-diraccess-property-include-hidden),
so this validation targets a source checkout, not an exported PCK.

Each production directory's initial presence is recorded. An optional production
root absent at preparation may remain absent; its later appearance is a mismatch.
A previously present root/subdirectory disappearing is also a mismatch, including
empty directories. Contracts, fixed files, and generated classes are required.
Open/enumeration/read errors fail validation. Runtime compares complete file and
directory path sets before hashing, then scans again to detect path changes during
hashing. It never limits enumeration to the manifest's old file keys. LF hashing
replaces CRLF bytes only, preserving BOM and other bytes consistently in both tools.

Old schema-1 manifests are rejected. After this tool change, any source change, or
any covered path addition/removal, run preparation again and use its new manifest
for both validation processes. Do not reuse a previously generated receipt.

## Scope retained from the experimental validation

Render QA uses actual heightfield projection and the Battle logical viewport
rectangle, with inside/outside edge classification checked for each case. Real
Unit IDs must match modulo 6; IDs are never replaced. It compares exact RGBA,
actual Canvas draw cadence, timer state, and queued/paused/hidden/detached/freed
lifecycles across the unchanged 260/261/500/501, selected, force, cooldown,
offscreen/reentry and 15/60 FPS-cap matrix. The paired observation viewports stay
visible while the real Battle query goes offscreen, so this is isolated helper
render validation rather than a full-world visual playthrough.

Timing uses one real Unit, actual production projection/request methods, the same
physics callback, alternating old/new order, six warmup ticks and three twelve-tick
windows per fixture. Equal timer assignment/dynamic-call overhead is reported in
an empty-helper control and is not blindly subtracted. Pending-signal resets
occur outside timed blocks to give both methods the same first-connect state;
actual Canvas drawing proceeds afterward and is excluded from method timings.
The matrix and original ID/frame semantics are unchanged. These are helper
microtimings, not FPS, combat balance, or human-experience acceptance.
