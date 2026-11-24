extends RefCounted
## Official Windows saves may finish their original battle after an update.
## An installing executable and a saved run have distinct identities. Only
## these exact published inputs may supply a historical battle scope.
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const BUILD_26735223_CONTENT := "source-v1:0d56b78b9a3132ef8ecec36c88c075ca080ce93f11f0b88c942f5ca0e72ff7e7"
const BUILD_26735223_EXE := "9b8ea12e40f81a9ba1be6ca1fecfcb48c9578cc92e6ddef314359f234dcac1ab"
const BUILD_26752476_CONTENT := "source-v1:a6f09b78fb3654a1c7293fa943ae6afa7eea35034f55c3934bcf69f0bd2dfc7d"
const BUILD_26752476_EXE := "fae95050c553dfd691e3beebca3eef7dd1d7490dfebf6e99fa50d310456b91a6"
const BUILD_26873421_CONTENT := "source-v1:37565f00004271ea77cff37359992333e141ea9d9c98805fa336887b8a89e585"
const BUILD_26873421_SPLIT_ID := "7c97301d45dbfc705cbb6c36cfee174d9f2dce71afa0518883ff67f33f466107"
const APPROVED_WINDOWS_ORIGINS := {
	BUILD_26735223_CONTENT: BUILD_26735223_EXE,
	BUILD_26752476_CONTENT: BUILD_26752476_EXE,
	BUILD_26873421_CONTENT: BUILD_26873421_SPLIT_ID,
}


static func resolve(context: Variant, content_version: Variant, engine_sha: Variant, installed: Dictionary) -> Dictionary:
	if not Profiles.trusted_identity(installed) or typeof(content_version) != TYPE_STRING or typeof(engine_sha) != TYPE_STRING:
		return {"ok": false, "code": "WORLD_CORE_IDENTITY"}
	if content_version == installed.content_version and engine_sha == installed.engine_binary_sha256:
		return {"ok": true, "identity": installed, "legacy": false}
	if OS.get_name() != "Windows" or APPROVED_WINDOWS_ORIGINS.get(content_version) != engine_sha:
		return {"ok": false, "code": "WORLD_CORE_IDENTITY"}
	var profile := Profiles.normalize_context(context)
	if not profile.ok:
		return {"ok": false, "code": "WORLD_CORE_IDENTITY"}
	var classic_from_release: bool = profile.context == Profiles.CLASSIC_CONTEXT and content_version == BUILD_26873421_CONTENT
	if profile.context.mode != "campaign" and not classic_from_release:
		return {"ok": false, "code": "WORLD_CORE_IDENTITY"}
	return {"ok": true, "legacy": true, "identity": {"ok": true, "save_eligible": true,
		"content_version": content_version, "engine_binary_sha256": engine_sha}}


static func for_battle(battle: Node, installed: Dictionary) -> Dictionary:
	var origin: Dictionary = battle._gameplay_content_identity
	var run := resolve(battle._official_context, origin.get("content_version"), origin.get("engine_binary_sha256"), installed)
	if run.ok and run.legacy and (battle._gameplay_rng_start_kind != "restored" or battle._continue_receipt == null):
		return {"ok": false, "code": "WORLD_CORE_IDENTITY"}
	return run
