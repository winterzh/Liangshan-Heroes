# Level 3 (三打祝家庄) World Restore QA Evidence

- **Execution Time**: `20260909_182841_56fa152b`
- **Runner**: `tools/run_level3_world_restore_qa.py`
- **Godot Scene Test**: `tools/level3_world_restore_qa.gd`
- **Status**: PASSED (Exit Code 0)
- **Total Assertions**: 39 / 39 PASSED

## Test Coverage
1. **Scene Preflight & Layout**: Chapter 3 RTS presentation layout stabilization.
2. **Dynamic World Mutation**: Hu Sanniang defeated, north gate broken, faction resources adjusted, unit HP damaged.
3. **Save Barrier Capture**: HELD barrier snapshot, canonical slot document creation and serialization.
4. **Clean Menu Transition**: Freeing battle instance, returning cleanly to main menu state.
5. **Slot Restoration**: Rebuilding battle tree from slot, mounting multi-frame layout, synchronizing presentation clock.
6. **Deep State Assertions**:
   - Defeat status & objective flags preserved.
   - Destroyed gate & obstacle structures preserved.
   - Resource balances for both Liangshan and enemies preserved.
   - Unit positions, orientations, health, and identity mappings preserved.
   - Save barrier restored to `State.IDLE` with `_scope().ok == true`.
7. **Negative Tamper Defense**: Hash, slot, and context mismatch rejections verified with strict error codes.
