extends RefCounted
## Actual component calls with synthetic scope labels. No battle, SDK or dead-lock recovery claims.
var tree: SceneTree
var checks: Array = []
var queries: Array = []
var model: Dictionary = {}
var paths: Dictionary = {}

func check(value: bool, label: String) -> bool:
	checks.append({"passed": value, "label": label})
	print("LIVENESS_INTEGRATION ", "PASS " if value else "FAIL ", label)
	return value

func provider_count() -> int:
	var root := ProjectSettings.globalize_path("user://process_liveness/v2")
	if not DirAccess.dir_exists_absolute(root): return 0
	return DirAccess.open(root).get_directories().size()

func observation(result: Dictionary) -> Dictionary:
	return result.get("observation", result.get("liveness_detail", {}))

func run(scene_tree: SceneTree) -> void:
	tree = scene_tree
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PLI_FIXTURES")))
	if not check(typeof(fixture) == TYPE_DICTIONARY and fixture.nonce == OS.get_environment("PLI_NONCE"), "host fixture nonce matches"): finish(); return
	var compiled: Dictionary = {}
	for name in ["process_liveness_oracle", "run_process_liveness_manager", "run_snapshot_store", "steam_receipt_store"]:
		var script: Script = load("res://scripts/" + name + ".gd")
		if not check(script != null and script.can_instantiate(), "actual candidate compiles: " + name): finish(); return
		compiled[name] = script
	var oracle: Script = compiled.process_liveness_oracle
	var manager: Script = compiled.run_process_liveness_manager
	var strict: Script = load("res://report_model.gd")
	if not check(strict != null and strict.can_instantiate(), "strict report model compiles"): finish(); return
	model = strict.new().run(oracle)
	if not check(model.ok and model.checks.size() == 22, "v2 independently passes all 22 synthetic strict report cases"): finish(); return
	check(not tree.root.has_meta(manager.META_KEY), "loading Store scripts alone creates no manager instance")
	for kind in ["run_snapshot_store", "steam_receipt_store"]:
		var empty: RefCounted = compiled[kind].new("90000000000000001", "user://component_empty/" + kind)
		var initialized: Dictionary = empty.initialize_directory()
		var head: Dictionary = empty.open_head()
		check(initialized.ok and head.ok and int(head.revision) == 0, "normal empty directory opens: " + kind)
	check(not tree.root.has_meta(manager.META_KEY) and provider_count() == 0, "normal empty Store path starts no helper or manager")
	var helper: String = ProjectSettings.globalize_path(manager.HELPER_PATH)
	var private_root: String = fixture.real_private
	paths = {"helper": helper, "junction": fixture.junction, "junction_helper": fixture.junction_helper, "real_private": private_root}
	check(FileAccess.get_sha256(helper) == manager.HELPER_SHA and manager.HELPER_SHA == fixture.helper_sha256, "real helper matches fixed manager pin")
	check(oracle.guard_native_path(helper, false) and oracle.guard_native_path(private_root, true), "real local non-reparse parent chains accepted")
	check(not oracle.guard_native_path(fixture.junction, true), "actual Windows directory junction rejected")
	check(not oracle.guard_native_path(fixture.junction_helper, false), "helper reached through junction ancestor rejected")
	var rejected: RefCounted = oracle.new()
	var denied_path: Dictionary = rejected.configure(helper, manager.HELPER_SHA, fixture.junction)
	check(not denied_path.ok and denied_path.code == "PATH_REPARSE_OR_MISSING", "configure refuses private root junction before launching")
	denied_path = rejected.configure(fixture.junction_helper, manager.HELPER_SHA, private_root)
	check(not denied_path.ok and denied_path.code == "PATH_REPARSE_OR_MISSING", "configure refuses helper ancestor junction despite matching bytes")
	var configured: Dictionary = rejected.configure(helper, manager.HELPER_SHA, private_root)
	check(configured.ok, "v2 oracle configures exact actual helper")
	var deadline_refused: Dictionary = rejected.begin(int(fixture.targets[0].pid), "", Time.get_ticks_msec() - 1)
	check(deadline_refused.state == "unknown" and deadline_refused.provider_pid == 0 and deadline_refused.code == "PROVIDER_SCOPE_TIMEOUT", "expired supplied scope starts no helper")
	var opened: Dictionary = manager.open_scope("synthetic component labels; actual native PIDs")
	if not check(opened.ok, "first synchronous manager scope opens"): finish(); return
	var scope_id: int = opened.scope_id
	var retained: RefCounted = tree.root.get_meta(manager.META_KEY)
	var temporary_scene := Node.new()
	tree.root.add_child(temporary_scene)
	tree.current_scene = temporary_scene
	tree.current_scene = null
	temporary_scene.free()
	check(tree.root.get_meta(manager.META_KEY) == retained and manager.status().scope_count == 1, "synthetic current-scene lifetime preserves root manager and active scope")
	check(not Engine.has_meta(manager.META_KEY), "Engine retains no scripted manager object")
	var binding := JSON.stringify({"fixture": fixture.nonce, "scope": "component"}).sha256_text()
	var first: Dictionary = {}
	for index in range(fixture.targets.size()):
		var target: Dictionary = fixture.targets[index]
		var result: Dictionary = manager.query_dead(scope_id, int(target.pid), binding, "inspect")
		queries.append(result.duplicate(true))
		var observed: Dictionary = observation(result)
		check(observed.get("state") == target.expected and observed.get("code") == target.code, "actual manager classifies " + str(target.label))
		check(bool(result.ok) == (target.expected == "dead"), "only confirmed-dead admits " + str(target.label))
		check(observed.get("helper_cleanup_confirmed", false) and not observed.get("pending", true), "manager closes its actual helper: " + str(target.label))
		if observed.get("evidence", {}).get("handle_opened", false):
			check(observed.evidence.creation_filetime == target.creation_filetime, "native target creation FILETIME retained: " + str(target.label))
		if index == 0: first = result.duplicate(true)
		var count := provider_count()
		check(manager.query_dead(scope_id, int(target.pid), binding, "inspect") == result, "completed result is non-consuming within scope: " + str(target.label))
		check(provider_count() == count, "same phase binding cache launches no extra helper: " + str(target.label))
	var live: Dictionary = fixture.targets[0]
	var count_before_claim := provider_count()
	var claim: Dictionary = manager.query_dead(scope_id, int(live.pid), binding, "claim")
	queries.append(claim.duplicate(true))
	check(claim.get("code") == "WRITER_ALIVE" and provider_count() == count_before_claim + 1, "claim phase obtains a fresh native observation")
	check(observation(claim).get("probe_directory") != observation(first).get("probe_directory"), "claim phase does not reuse inspect helper evidence")
	check(manager.close_scope(scope_id).ok and manager.status().scope_count == 0, "closing scope releases cache while retaining process manager")
	check(not manager.query_dead(scope_id, int(live.pid), binding, "inspect").ok, "closed scope cannot reuse old death evidence")
	var second: Dictionary = manager.open_scope("second independent scope")
	if not check(second.ok and second.scope_id != scope_id, "new public scope has independent identity"): finish(); return
	var fresh: Dictionary = manager.query_dead(second.scope_id, int(live.pid), binding, "inspect")
	queries.append(fresh.duplicate(true))
	check(fresh.code == "WRITER_ALIVE" and observation(fresh).get("probe_directory") != observation(first).get("probe_directory"), "new scope does not permanently cache old alive result")
	check(manager.close_scope(second.scope_id).ok, "second scope closes")
	var bounded: Dictionary = manager.open_scope("real wall-clock budget expiry")
	if not check(bounded.ok, "deadline scope opens"): finish(); return
	var dead: Dictionary = fixture.targets[1]
	var before_expiry: Dictionary = manager.query_dead(bounded.scope_id, int(dead.pid), binding, "inspect")
	queries.append(before_expiry.duplicate(true))
	check(before_expiry.ok, "deadline scope first obtains genuine dead handle result")
	var count_before_expiry := provider_count()
	var remaining: int = int(bounded.deadline_ms) - Time.get_ticks_msec()
	if remaining >= 0: OS.delay_msec(remaining + 10)
	var expired: Dictionary = manager.query_dead(bounded.scope_id, int(dead.pid), binding, "inspect")
	check(not expired.ok and expired.code == "PROCESS_LIVENESS_TIMEOUT", "expired shared budget rejects even an existing completed cache entry")
	check(provider_count() == count_before_expiry, "expired scope launches no new helper")
	check(manager.close_scope(bounded.scope_id).ok, "expired scope closes without losing process manager")
	var status: Dictionary = manager.status()
	check(status.ok and status.scope_count == 0 and not status.in_query and not status.quarantined, "normal test completion leaves no pending query or quarantine")
	check(provider_count() == queries.size(), "real helper count equals uncached native query evidence")
	finish()

func finish() -> void:
	var passed := not checks.is_empty()
	for row: Dictionary in checks: passed = passed and row.passed
	var report := {"schema": "process_liveness_integration_component_v1", "passed": passed, "checks": checks,
		"model": model, "queries": queries, "paths": paths, "pid": OS.get_process_id(), "nonce": OS.get_environment("PLI_NONCE"),
		"engine": Engine.get_version_info(), "fixture_scope_labels": true, "actual_native_helper": true,
		"store_dead_writer_recovery_qualified": false, "timeout_termination_qualified": false,
		"gameplay_qualified": false, "production_integrated": false, "sdk_qualified": false}
	var file := FileAccess.open(OS.get_environment("PLI_REPORT"), FileAccess.WRITE)
	if file == null: tree.quit(2); return
	file.store_string(JSON.stringify(report, "\t")); file.flush(); file.close()
	tree.quit(0 if passed else 1)
