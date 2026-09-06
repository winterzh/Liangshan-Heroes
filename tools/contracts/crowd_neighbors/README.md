# Buffered separation baseline

Both sources are from `5457de797678889ce606abb9468a2a994f634d51`, after the earlier separation buffer and Unit redraw changes.

- `solver_before_5457de7.txt` is the complete original `scripts/crowd_separation.gd`, normalized to LF. SHA256: `eb5870d97048a42ed0a89208e3da90b94396ed7aa43bcc996e61a0c15e9f443f`.
- `dispatch_before_5457de7.txt` contains the original Battle separation method. Its buffered call is redirected to that frozen solver, compiled once in the reference object's initializer. SHA256: `6e077651061a8c51448b09d443f8f963cb9746762d5a92a36c5b2271e528a5c7`.

The caller checks the dispatch hash; the initializer checks the solver hash. Reference compilation occurs outside timing windows. The original current-state map segment checks remain shared, so independent navigation regressions accompany the position comparison. These files are regression references, not production imports.
