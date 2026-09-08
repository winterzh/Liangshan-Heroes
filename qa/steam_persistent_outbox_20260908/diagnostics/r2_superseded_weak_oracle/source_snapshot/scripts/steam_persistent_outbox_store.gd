extends "res://scripts/run_snapshot_store.gd"
## Distinct account directory/magic; never shares files with the run ledger.
const State = preload("res://scripts/steam_persistent_outbox_state.gd")

func _magic() -> String:
	return "LH_STEAM_PERSISTENT_OUTBOX"

func _validate_document(value: Variant) -> Dictionary:
	return State.validate(value, owner)
