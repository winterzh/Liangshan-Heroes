extends "res://scripts/run_snapshot_store.gd"
## Steam receipt specialization. File layout and envelope remain version 1.
const Receipt = preload("res://scripts/steam_run_receipt.gd")

func _magic() -> String:
	return "LH_STEAM_RUN_SNAPSHOTS"

func _validate_document(value: Variant) -> Dictionary:
	var model := Receipt.new()
	var opened: Dictionary = model.open_record(value, owner)
	if not opened.ok: return opened
	return {"ok": true, "document": model.capture(), "revision": int(model.capture().generation) + 1}
