#!/bin/bash
# Smoke-win runner for the 3 new levels + regression on existing 5 + skirmish.
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
cd /Users/dztdash/Antigravity/ra-aa
run() {
  local L="$1"; local FR="$2"
  echo "===== LEVEL $L (cap $FR) ====="
  local out
  out=$(SMOKE_TEST=1 LEVEL=$L "$GODOT" --headless --path . --quit-after "$FR" 2>&1)
  echo "$out" | grep -iE "SCRIPT ERROR|Parse Error|res://scripts/levels|nil instance|Invalid (get|set|call|access)|Trying to|Attempt to" | head -8
  echo "$out" | grep -E "\[end\]" | head -3
  if echo "$out" | grep -q "\[end\] victory=true"; then echo "L$L => WIN ✓";
  elif echo "$out" | grep -q "\[end\] victory=false"; then echo "L$L => LOSE ✗ (smoke could not win)";
  else echo "L$L => NO END within $FR frames (timeout)"; echo "$out" | grep "\[smoke\]" | tail -2; fi
}
for L in 6 7 8; do run "$L" 8000; done
echo "########## REGRESSION (existing) ##########"
for L in 1 2 3 4 5; do run "$L" 9000; done
echo "########## SKIRMISH ##########"
echo "===== SKIRMISH ====="
SKIRMISH=1 SMOKE_TEST=1 "$GODOT" --headless --path . --quit-after 4000 2>&1 | grep -iE "SCRIPT ERROR|Parse Error|nil instance|\[end\]" | head -4
echo "########## SMOKE_NEW DONE ##########"
