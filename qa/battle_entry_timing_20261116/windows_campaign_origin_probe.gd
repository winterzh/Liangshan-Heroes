extends SceneTree
## Verify the published Windows campaign origin rules without opening a slot.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_name() != "Windows" or OS.get_environment("STEAM_DISABLED") != "1":
		quit(2)
		return
	var version := load("res://scripts/run_campaign_save_version.gd") as Script
	var profiles := load("res://scripts/run_official_restore_profile.gd") as Script
	var installed := {"ok": true, "save_eligible": true, "content_version": "source-v1:current",
		"engine_binary_sha256": "c".repeat(64)}
	var failures: Array[String] = []
	var checks := 0
	for context: Dictionary in profiles.PLAYER_CAMPAIGN_CONTEXTS:
		for pair: Array in [[version.BUILD_26735223_CONTENT, version.BUILD_26735223_EXE],
				[version.BUILD_26752476_CONTENT, version.BUILD_26752476_EXE]]:
			var resolved: Dictionary = version.resolve(context, pair[0], pair[1], installed)
			checks += 1
			if not resolved.ok or not resolved.get("legacy") or resolved.identity.content_version != pair[0] \
					or resolved.identity.engine_binary_sha256 != pair[1]:
				failures.append(context.level_id + " rejected or rewrote an exact published origin")
	var campaign: Dictionary = profiles.ZHU_CONTEXT
	var cases := [
		[version.BUILD_26735223_CONTENT, version.BUILD_26752476_EXE, campaign, installed],
		[version.BUILD_26752476_CONTENT, version.BUILD_26735223_EXE, campaign, installed],
		["source-v1:unknown", "", campaign, installed],
		[version.BUILD_26752476_CONTENT, version.BUILD_26752476_EXE, profiles.CLASSIC_CONTEXT, installed],
		[version.BUILD_26752476_CONTENT, version.BUILD_26752476_EXE, campaign, {}],
	]
	for entry: Array in cases:
		checks += 1
		if version.resolve(entry[2], entry[0], entry[1], entry[3]).ok:
			failures.append("Unexpected legacy match in case %d" % checks)
	var current: Dictionary = version.resolve(campaign, installed.content_version, installed.engine_binary_sha256, installed)
	checks += 1
	if not current.ok or current.legacy or current.identity != installed:
		failures.append("Current installed identity was not preserved")
	print("WINDOWS_CAMPAIGN_ORIGINS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
