# Direct redraw reference

`direct_queue_57e2512.txt` models the existing immediate `CanvasItem.queue_redraw()` call at every replaced Unit call site in `57e2512db918498f2950c7669cd2bf6863e2265e`. It overrides only the new scheduling helper in a counted Unit subclass; both sides retain the identical production draw implementation and receive identical synthetic visual state changes from actual physics ticks.

This is a scheduling/pixel oracle, not a separately implemented gameplay simulator. The QA receipt records the baseline source hash and verifies that removing the helper and reversing the 55 call-site renames reconstructs the complete old Unit source after LF normalization. Runtime movement, hit/death and story/menu transitions are checked by separate existing tests.
