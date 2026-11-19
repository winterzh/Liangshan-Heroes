extends RefCounted
## Official Windows saves may finish their original battle after an update.
## An installing executable and a saved run have distinct identities. Only
## these exact published inputs may supply a historical campaign scope.
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const BUILD_26735223_CONTENT := "source-v1:0d56b78b9a3132ef8ecec36c88c075ca080ce93f11f0b88c942f5ca0e72ff7e7"
const BUILD_26735223_EXE := "9b8ea12e40f81a9ba1be6ca1fecfcb48c9578cc92e6ddef314359f234dcac1ab"
const BUILD_26752476_CONTENT := "source-v1:a6f09b78fb3654a1c7293fa943ae6afa7eea35034f55c3934bcf69f0bd2dfc7d"
const BUILD_26752476_EXE := "fae95050c553dfd691e3beebca3eef7dd1d7490dfebf6e99fa50d310456b91a6"
const APPROVED_WINDOWS_ORIGINS := {
	BUILD_26735223_CONTENT: BUILD_26735223_EXE,
	BUILD_26752476_CONTENT: BUILD_26752476_EXE,
}


static func resolve(context: Variant, content_version: Variant, engine_sha: Variant, installed: Dictionary) -> Dictionary:
	if not Profiles.trusted_identity(installed) or typeof(content_version) != TYPE_STRING or typeof(engine_sha) != TYPE_STRING:
		return {"ok": false, "code": "WORLD_CORE_IDENTITY"}
	if content_version == installed.content_version and engine_sha == installed.engine_binary_sha256:
		return {"ok": true, "identity": installed, "legacy": false}
	if OS.get_name() != "Windows" or not Profiles.is_official_campaign_context(context) \
			or APPROVED_WINDOWS_ORIGINS.get(content_version) != engine_sha:
		return {"ok": false, "code": "WORLD_CORE_IDENTITY"}
	return {"ok": true, "legacy": true, "identity": {"ok": true, "save_eligible": true,
		"content_version": content_version, "engine_binary_sha256": engine_sha}}


static func for_battle(battle: Node, installed: Dictionary) -> Dictionary:
	var origin: Dictionary = battle._gameplay_content_identity
	var run := resolve(battle._official_context, origin.get("content_version"), origin.get("engine_binary_sha256"), installed)
	if run.ok and run.legacy and (battle._gameplay_rng_start_kind != "restored" or battle._continue_receipt == null):
		return {"ok": false, "code": "WORLD_CORE_IDENTITY"}
	return run
