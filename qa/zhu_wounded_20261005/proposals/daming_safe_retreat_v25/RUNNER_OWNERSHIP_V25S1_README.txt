Immutable v25s1 runner ownership correction (unexecuted)

This sibling preserves the original v25s files. Only _launch, _save, _restore,
finish and the ownership state declarations/header differ. All other functions,
including the five qualified-successor hold helpers, retain exact raw bytes.

The actual private menu launch and actual successful Session commit record their
own Battle before later checks can return null. finish frees only that recorded
scene and then disposes the caller's retained identity once. It never guesses a
menu/current_scene/tree child to delete.

The original save Session is held in a member. A failed pending writer's actual
result/status is recorded, its transaction remains owned until process exit,
and case success is false. There is no retry, replacement, or recovered-success
claim. The failed process still releases its own scene; it cannot resume or retry.

RUNNER_OWNERSHIP_SELFCHECK_V25S1.json is author selfcheck only. An independent
runner_cross_review prerequisite with these new candidate pins is required.
A-only exploration must keep full-consumer/overall qualification false.
No parser or native engine was run; natural rescue/path/combat/save acceptance
requires actual original native execution. B/C/D source cleanup corrections are
present but are outside this A exploration execution scope.
