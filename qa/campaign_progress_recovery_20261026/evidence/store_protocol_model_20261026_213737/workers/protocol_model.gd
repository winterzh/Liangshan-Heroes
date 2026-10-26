extends RefCounted
## Synthetic naming/layout tests only; no files, engine launch or SDK calls.
## A later approved frozen bootstrap may call run_all(). Not executed yet.
const Store := preload("res://scripts/steam_receipt_store.gd")
const OWNER := "76561198000000001"
var checks: Array = []

func expect(condition: bool, label: String) -> void:
	checks.append({"label":label,"passed":condition})

func run_all() -> Dictionary:
	checks.clear()
	var store := Store.new(OWNER)
	var cleanup_nonce: String = "a".repeat(32)
	var claim_nonce: String = "b".repeat(32)
	var head: String = "c".repeat(64)
	var name: String = store._release_name(73,claim_nonce,51,cleanup_nonce,9,head)
	var marker: Dictionary = store._release_fields(name)
	expect(marker.ok and marker.cleanup == "cleanup_v1_51_" + cleanup_nonce, "marker names exact unique cleanup; never fixed writing")
	var claimed_name: String = store._release_name(97,"d".repeat(32),51,cleanup_nonce,9,head)
	var claimed: Dictionary = store._release_fields(claimed_name)
	expect(claimed.ok and claimed.cleanup == marker.cleanup and claimed.name != marker.name, "recovery changes claim identity without redirecting cleanup")
	expect(claimed.head_revision == marker.head_revision and claimed.head_sha256 == marker.head_sha256, "recovery marker keeps full original head binding")
	expect(not store._release_fields(name.replace(head,head.to_upper())).ok, "uppercase head digest rejected")
	expect(not store._release_fields(name.replace("_9_","_09_")).ok, "noncanonical generation rejected")
	expect(not store._release_fields(name + ".extra").ok, "extra marker suffix rejected")
	expect(not store._release_fields(name.replace(claim_nonce,"../writing")).ok, "path-like claim input rejected")
	expect(not store._cleanup_fields("writing").ok and not store._cleanup_fields("recovering").ok, "fixed legacy paths cannot parse as unique cleanup")
	expect(not store._cleanup_fields("cleanup_v1_0_" + cleanup_nonce).ok, "zero claim PID rejected")
	var row := {"kind":"cleanup","name":marker.cleanup,"has_owner":false}
	var foreign := {"kind":"legacy","name":"writing","has_owner":true}
	var layout := {"barrier":true,"markers":[marker],"locks":{marker.cleanup:row,"writing":foreign},"pending":false}
	var state: Dictionary = store._protocol_state(layout)
	expect(state.ok and state.kind == "release" and state.marker.cleanup != "writing", "delayed writer remains distinct from cleanup authorization")
	layout.locks[marker.cleanup].has_owner = true
	expect(not store._protocol_state(layout).ok, "marker cannot delete a cleanup containing a new owner")
	layout.locks[marker.cleanup].has_owner = false
	layout.pending = true
	expect(not store._protocol_state(layout).ok, "authoritative pending blocks release cleanup")
	layout.pending = false
	layout.markers.append(claimed)
	expect(not store._protocol_state(layout).ok, "two simultaneous markers fail closed")
	layout.markers = [marker]
	layout.locks["recovering"] = {"kind":"legacy","name":"recovering","has_owner":false}
	expect(not store._protocol_state(layout).ok, "legacy bare recovering remains an explicit unresolved boundary")
	var passed := true
	for check: Dictionary in checks: passed = passed and check.passed
	return {"schema":"steam_unique_release_model_v1","passed":passed,"checks":checks,
		"synthetic_model_only":true,"native_io_exercised":false,"sdk_qualified":false}
