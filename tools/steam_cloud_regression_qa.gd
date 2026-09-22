extends SceneTree
## Actual production Cloud/Settings/Campaign regression with a SDK-contract fake.
## Activation uses Cloud's internal _attach_account seam only after this suite
## proves a frozen project and a new, explicit private profile. No live Steam.

var checks: Array = []
var failures: Array = []
var cloud = null
var fake = null
var settings = null
var campaign = null
var localize = null
var service = null
var key_notifications := 0
var language_notifications := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "passed": ok})
	print("[steam-cloud] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)


func _private_ok() -> bool:
	var project := ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	var expected := OS.get_environment("LSH_RTS_QA_PROJECT").simplify_path().trim_suffix("/")
	var profile := OS.get_environment("LSH_RTS_QA_PROFILE").simplify_path().trim_suffix("/")
	var output := OS.get_environment("LSH_RTS_QA_OUT").simplify_path().trim_suffix("/")
	return expected.is_absolute_path() and profile.is_absolute_path() and output.is_absolute_path() \
		and project == expected and not output.begins_with(project + "/") and output != project \
		and OS.get_user_data_dir().simplify_path().trim_suffix("/") == profile \
		and bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)) \
		and String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("LSH-") \
		and FileAccess.file_exists("res://override.cfg") \
		and not FileAccess.file_exists("res://.git") and not DirAccess.dir_exists_absolute(project.path_join(".git")) \
		and not Engine.has_singleton("Steam") \
		and OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1"


func _dispose() -> void:
	service.available = false
	if is_instance_valid(cloud):
		cloud.dirty = false
		cloud.cloud_ready = false
		cloud.free()
	cloud = null
	service.native = null


func _fresh(owner := 111) -> void:
	_dispose()
	# Only enumerated fixture files in the asserted private user directory.
	for name in ["steam_cloud_owner.cfg", "steam_cloud_profile.json", "steam_cloud_profile_111.json",
		"steam_cloud_profile_222.json", "steam_legacy_import.cfg", "settings.cfg", "language.cfg", "campaign.cfg"]:
		var path: String = "user://" + name
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	campaign.unlocked = 1
	campaign.records = {}
	campaign.cloud_owner = ""
	settings.apply_cloud_text(settings.default_cloud_text())
	localize.set_language("zh_CN", false)
	fake = load("res://tools/steam_fake_api.gd").new()
	fake.owner = owner
	service.native = fake
	service.account = str(owner)
	service.available = true
	cloud = load("res://scripts/steam_cloud.gd").new()
	cloud.name = "SteamCloud"
	root.add_child(cloud)
	cloud.set_process(false)


func _settings_text(bgm: float, legacy := false) -> String:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "bgm", bgm)
	cfg.set_value("audio", "sfx", 0.3)
	cfg.set_value("audio", "muted", true)
	if legacy:
		cfg.set_value("keys", "select_army", KEY_F2)
		cfg.set_value("keys", "command_0", KEY_F2)
		cfg.set_value("keys", "alert", KEY_Q)
		cfg.set_value("keys", "stop", KEY_J)
		cfg.set_value("keys", "hold", KEY_F5)
	return cfg.encode_to_text()


func _payload(owner := "111", unlocked := 1, bgm := 0.2) -> Dictionary:
	return {"schema": 1, "owner": owner, "updated_at": 100,
		"campaign": {"schema": 2, "unlocked": unlocked, "records": {}},
		"settings_text": _settings_text(bgm), "language_text": "[language]\nlocale=\"en\"\n"}


func _remote(payload: Dictionary) -> void:
	fake.cloud_files[cloud.CLOUD_FILE] = JSON.stringify(payload).to_utf8_buffer()


func _remote_payload() -> Dictionary:
	var parsed: Variant = JSON.parse_string(fake.cloud_files.get(cloud.CLOUD_FILE, PackedByteArray()).get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


func _write_fixture(path: String, value: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(value)
	file.close()
	return true


func _record(ids: Array, cleared := true, complete := false) -> Dictionary:
	return {"cleared": cleared, "story_complete": complete, "best_done": ids.size(),
		"story_total": 3, "best_goal_ids": ids, "contract_version": 1}


func _no_op_and_sdk_cases() -> void:
	_fresh()
	check(not cloud.cloud_ready and fake.file_reads == 0 and fake.file_writes == 0,
		"normal _ready under STEAM_DISABLED/CAMPAIGN_QA never calls cloud storage")
	cloud._attach()
	cloud.mark_dirty()
	cloud._process(60.0)
	check(not cloud.cloud_ready and fake.file_reads == 0 and fake.file_writes == 0,
		"public attach, dirty, timer paths remain inert in ordinary/test startup")
	var payload := _payload()
	_remote(payload)
	var length: int = fake.getFileSize(cloud.CLOUD_FILE)
	var zero: Dictionary = fake.fileRead(cloud.CLOUD_FILE, 0)
	var actual: Dictionary = fake.fileRead(cloud.CLOUD_FILE, length)
	check(zero.ret is int and zero.ret == 0 and zero.buf.is_empty(), "SDK fake honors zero requested bytes, not full file")
	check(actual.ret is int and actual.ret == length and actual.buf is PackedByteArray \
		and not actual.has("content") and not actual.has("buffer"), "SDK fake exposes exact ret byte count and buf")
	var overread: Dictionary = fake.fileRead(cloud.CLOUD_FILE, length + 2)
	check(overread.ret == length and overread.buf.size() == length + 2,
		"SDK fake keeps requested-size buffer separate from actual returned byte count")
	cloud._attach_account()
	check(cloud.cloud_ready and fake.file_size_reads >= 2 and fake.read_sizes.back() == length,
		"actual production cloud reads getFileSize bytes using SDK buf contract")
	check(fake.cloud_account_checks > 0 and fake.cloud_app_checks > 0, "production checks both account and app Cloud enablement")
	check(campaign.unlocked == 1 and campaign.cloud_owner == "111", "first successful pull binds campaign to verified account")
	check(not fake.has_method("fileWriteAsync"), "fake has no boolean async fallback to mask a synchronous write failure")
	_fresh()
	fake.cloud_enabled_account = false
	cloud._attach_account()
	check(fake.file_reads == 0 and fake.file_writes == 0, "account-level Cloud opt-out prevents read/write")
	_fresh()
	fake.cloud_enabled_app = false
	cloud._attach_account()
	check(fake.file_reads == 0 and fake.file_writes == 0, "app-level Cloud opt-out prevents read/write")


func _ownership_cases() -> void:
	for existing_remote in [false, true]:
		_fresh(222)
		campaign.unlocked = 8
		campaign.cloud_owner = "111"
		check(_write_fixture(cloud.MIRROR_PATH, JSON.stringify(_payload("111", 8, 0.9))), "write private foreign legacy mirror fixture")
		if existing_remote: _remote(_payload("222", 1, 0.2))
		cloud._attach_account()
		cloud.mark_dirty()
		cloud._process(60.0)
		var uploaded := _remote_payload()
		check(campaign.unlocked == 1 and campaign.cloud_owner == "222",
			"foreign legacy/local progress cannot enter B (%s remote)" % ("existing" if existing_remote else "empty"))
		check(uploaded.get("owner") == "222" and uploaded.get("campaign", {}).get("unlocked") == 1,
			"B cloud never receives A's unlock 8 (%s remote)" % ("existing" if existing_remote else "empty"))
		check(not is_equal_approx(settings.bgm, 0.9), "foreign account preferences are not relabeled")
	_fresh()
	_remote(_payload("111", 8, 0.9))
	cloud._attach_account()
	check(campaign.unlocked == 8, "A fixture is actually loaded before switching accounts")
	var writes: int = fake.file_writes
	fake.owner = 222
	cloud.mark_dirty()
	cloud._process(60.0)
	check(fake.file_writes == writes, "native owner change blocks writes before service account is rebound")
	service.account = "222"
	service.available = true
	_remote(_payload("222", 1, 0.2))
	cloud._attach_account()
	check(campaign.unlocked == 1 and campaign.cloud_owner == "222" and is_equal_approx(settings.bgm, 0.2),
		"live account switch exactly replaces A runtime progress/settings with B")
	cloud.mark_dirty()
	cloud._process(60.0)
	check(_remote_payload().campaign.unlocked == 1, "post-switch B upload stays at B's progress")
	check(FileAccess.file_exists(cloud._mirror_path("111")) and FileAccess.file_exists(cloud._mirror_path("222")),
		"local cloud mirrors are physically partitioned by owner")
	_fresh(222)
	campaign.unlocked = 8
	var migration := ConfigFile.new()
	migration.set_value("migration", "owner", "111")
	check(migration.save("user://steam_legacy_import.cfg") == OK, "write private pre-upgrade Steam ownership proof")
	_remote(_payload("222", 1))
	cloud._attach_account()
	check(campaign.cloud_owner == "222" and campaign.unlocked == 1 and _remote_payload().campaign.unlocked == 1,
		"pre-upgrade migration.owner prevents untagged A progress being adopted by B")
	var old_profile: Variant = JSON.parse_string(FileAccess.get_file_as_string(cloud._mirror_path("111")))
	check(old_profile is Dictionary and old_profile.campaign.unlocked == 8,
		"pre-upgrade A progress remains recoverable in A's scoped mirror")
	_fresh(222)
	campaign.unlocked = 8
	check(_write_fixture(cloud._mirror_path("111"), JSON.stringify(_payload("111", 8))),
		"write private orphaned scoped-mirror ownership fixture")
	_remote(_payload("222", 1))
	cloud._attach_account()
	cloud.mark_dirty()
	cloud._process(60.0)
	check(not cloud.cloud_ready and fake.file_reads == 0 and fake.file_writes == 0,
		"missing binding plus an orphaned scoped mirror blocks first-account adoption")
	check(FileAccess.file_exists(cloud._mirror_path("111")) and _remote_payload().campaign.unlocked == 1,
		"orphaned ownership evidence and B's remote progress are preserved unchanged")


func _read_retry_cases() -> void:
	_fresh()
	_remote(_payload("111", 8))
	fake.file_read_ok = false
	cloud._attach_account()
	var remote_before: PackedByteArray = fake.cloud_files[cloud.CLOUD_FILE].duplicate()
	check(fake.file_reads == 1 and fake.file_writes == 0, "initial read failure performs no upload")
	settings.bgm = 0.6
	cloud.mark_dirty()
	cloud._flush()
	check(fake.file_writes == 0 and fake.cloud_files[cloud.CLOUD_FILE] == remote_before,
		"dirty and explicit flush cannot overwrite unread newer remote data")
	cloud._process(1.0)
	check(fake.file_reads == 1, "failed pull respects retry backoff")
	cloud._process(60.0)
	check(fake.file_reads > 1 and fake.file_writes == 0, "timer retries actual fileRead, not an unsafe upload")
	fake.file_read_ok = true
	cloud._process(60.0)
	check(campaign.unlocked == 8 and _remote_payload().campaign.unlocked == 8,
		"successful retry merges remote progress before permitting upload")
	check(is_equal_approx(settings.bgm, 0.6), "edits made while awaiting a failed pull survive the successful retry")
	for failure in ["partial_bytes", "wrong_ret"]:
		_fresh()
		_remote(_payload("111", 8))
		if failure == "partial_bytes": fake.short_read_by = 1
		else: fake.file_read_ret_override = 1
		cloud._attach_account()
		cloud.mark_dirty()
		cloud._process(60.0)
		check(fake.file_writes == 0 and campaign.unlocked == 1, "incomplete SDK read fails closed: " + failure)


func _write_retry_and_offline_cases() -> void:
	_fresh()
	fake.file_write_ok = false
	cloud._attach_account()
	check(fake.file_writes == 1 and cloud.dirty, "failed synchronous seed write stays dirty")
	cloud._process(1.0)
	check(fake.file_writes == 1, "write retry observes backoff")
	fake.file_write_ok = true
	cloud._process(60.0)
	check(fake.file_writes >= 2 and not cloud.dirty and _remote_payload().owner == "111",
		"successful synchronous retry alone clears pending write")
	_fresh()
	_remote(_payload("111", 1, 0.2))
	cloud._attach_account()
	service.available = false
	settings.bgm = 0.6
	campaign.unlocked = 8
	localize.set_language("ja", false)
	cloud.mark_dirty()
	var writes: int = fake.file_writes
	cloud._process(60.0)
	check(fake.file_writes == writes, "offline dirty changes do not call remote storage")
	check(cloud.dirty, "offline changes retain pending dirty state")
	service.available = true
	cloud._attach_account()
	cloud._process(60.0)
	var uploaded := _remote_payload()
	check(campaign.unlocked == 8 and uploaded.campaign.unlocked == 8,
		"same-owner reconnect uses current offline progress, not stale mirror")
	check(is_equal_approx(settings.bgm, 0.6) and uploaded.settings_text.contains("0.6"),
		"same-owner reconnect preserves and uploads current offline settings")
	check(localize.locale == "ja" and uploaded.language_text.contains("ja"),
		"same-owner reconnect preserves and uploads current offline language")
	check(not cloud.dirty, "reconnect clears dirty only after the merged payload is written")
	_fresh()
	_remote(_payload("111", 1))
	cloud._attach_account()
	campaign.unlocked = 3
	cloud.mark_dirty()
	fake.file_write_ok = false
	cloud._flush()
	check(cloud.dirty, "write-failure concurrency fixture retains pending local progress")
	# Another device can advance remote storage while this write is in backoff.
	_remote(_payload("111", 8))
	var reads: int = fake.file_reads
	fake.file_write_ok = true
	cloud._process(60.0)
	check(fake.file_reads > reads and campaign.unlocked == 8 and _remote_payload().campaign.unlocked == 8,
		"failed-write retry re-reads and merges concurrently advanced remote progress before overwriting")
	_fresh()
	_remote(_payload("111", 1, 0.2))
	fake.file_write_ok = false
	cloud._attach_account()
	check(is_equal_approx(settings.bgm, 0.2) and cloud.dirty and fake.file_writes == 1,
		"failed-write preference fixture first downloads 0.2 over untouched local default 0.8")
	# A successfully downloaded preference is not a local edit. A newer remote
	# value must win when a failed write forces the next read-before-write cycle.
	_remote(_payload("111", 8, 0.3))
	fake.file_write_ok = true
	cloud._process(60.0)
	var preference := ConfigFile.new()
	var uploaded_after_retry := _remote_payload()
	check(is_equal_approx(settings.bgm, 0.3) and campaign.unlocked == 8 \
		and preference.parse(uploaded_after_retry.settings_text) == OK \
		and is_equal_approx(float(preference.get_value("audio", "bgm", -1)), 0.3),
		"retry does not mistake downloaded 0.2 for a local edit and overwrite newer remote 0.3")


func _account_transition_write_failure_case() -> void:
	_fresh()
	_remote(_payload("111", 8, 0.9))
	cloud._attach_account()
	check(campaign.unlocked == 8 and campaign.cloud_owner == "111", "transition-failure fixture starts as verified A")
	fake.owner = 222
	service.account = "222"
	service.available = true
	_remote(_payload("222", 1, 0.2))
	var writes: int = fake.file_writes
	var blocked := ProjectSettings.globalize_path("user://settings.cfg.tmp")
	var made := DirAccess.make_dir_absolute(blocked) == OK
	check(made, "create an empty private directory to force an actual atomic settings write failure")
	if not made: return
	cloud._attach_account()
	cloud.mark_dirty()
	cloud._flush()
	cloud._process(60.0)
	check(fake.file_writes == writes and _remote_payload().owner == "222" and _remote_payload().campaign.unlocked == 1,
		"failed A-to-B local transition cannot upload retained A runtime progress as B")
	check(DirAccess.remove_absolute(blocked) == OK, "remove only the empty private fault-injection directory")
	cloud._attach_account()
	cloud._process(60.0)
	check(not cloud.cloud_ready and fake.file_writes == writes and _remote_payload().campaign.unlocked == 1,
		"ambiguous partial ownership transition remains fail-closed after the I/O fault is removed")
	_dispose()
	service.native = fake
	service.available = true
	cloud = load("res://scripts/steam_cloud.gd").new()
	cloud.name = "SteamCloud"
	root.add_child(cloud)
	cloud.set_process(false)
	cloud._attach_account()
	cloud.mark_dirty()
	cloud._process(60.0)
	check(not cloud.cloud_ready and fake.file_writes == writes and _remote_payload().campaign.unlocked == 1,
		"new Cloud instance rejects the durable pending-owner marker instead of adopting mixed files")
	check(FileAccess.file_exists(cloud._mirror_path("111")) and FileAccess.file_exists(cloud._mirror_path("222")),
		"torn-transition safety latch preserves both owner-scoped recovery copies")


func _runtime_settings_cases() -> void:
	_fresh()
	var payload := _payload("111", 4)
	payload.settings_text = _settings_text(0.2, true)
	_remote(payload)
	var before_keys := key_notifications
	var before_language := language_notifications
	cloud._attach_account()
	check(is_equal_approx(settings.bgm, 0.2) and is_equal_approx(root.get_node("Music").user_vol, 0.2) \
		and is_equal_approx(root.get_node("Sfx").user_vol, 0.3) and AudioServer.is_bus_mute(0),
		"download immediately reloads runtime settings and both audio paths")
	check(key_notifications > before_keys and language_notifications > before_language and localize.locale == "en",
		"download emits keybind/language signals and updates runtime language")
	check(settings.key_for("command_0") == KEY_Q and settings.key_for("alert") == KEY_SPACE \
		and settings.key_for("stop") == KEY_J and settings.key_for("hold") == KEY_H,
		"cloud settings use production legacy F2 and collision-chain migration")
	check(not settings.keybinds.has("select_army"), "cloud settings cannot revive removed legacy F2 army action")
	for key in range(KEY_F1, KEY_F8 + 1):
		check(not settings.can_bind_key(key), "cloud-loaded settings retain F%d reserved hero key" % (key - KEY_F1 + 1))
	var persisted := ConfigFile.new()
	check(persisted.load("user://settings.cfg") == OK and is_equal_approx(float(persisted.get_value("audio", "bgm", -1)), 0.2),
		"downloaded settings are persisted in the verified private profile")
	var disk_before := FileAccess.get_file_as_string("user://settings.cfg")
	settings.save()
	check(FileAccess.get_file_as_string("user://settings.cfg") == disk_before,
		"ordinary Settings.save remains disabled under CAMPAIGN_QA without a global bypass")
	settings.bgm = 0.9
	settings.sfx = 0.1
	check(settings.apply_cloud_text("[audio]\nbgm=0.4\n") and is_equal_approx(settings.bgm, 0.4) \
		and is_equal_approx(settings.sfx, 0.9), "partial legacy cloud settings reset omitted fields to defaults, not prior account")
	for value in ["[audio]\nbgm=\"bad\"\n", "[audio]\nbgm=0.5\nsfx=8\n", "[game]\nauto_micro=\"two\"\n", "[keys]\nstop=\"S\"\n"]:
		var before: String = settings.cloud_text()
		var notifications := key_notifications
		check(not settings.apply_cloud_text(value) and settings.cloud_text() == before \
			and key_notifications == notifications, "malformed settings reject atomically: " + value.replace("\n", "/"))
	var previous: String = localize.locale
	check(not localize.apply_cloud_text("[language]\nlocale=\"invalid\"\n") and localize.locale == previous,
		"invalid language rejects without changing runtime locale")


func _merge_and_malformed_cases() -> void:
	_fresh()
	var left := {"schema": 2, "unlocked": 3, "records": {"level1": _record(["a"])}}
	var right := {"schema": 2, "unlocked": 5, "records": {"level1": _record(["b"])}}
	var merged: Dictionary = cloud._merged_campaign(left, right)
	check(merged.unlocked == 5, "actual production campaign merge keeps maximum unlocked chapter")
	check(merged.records.level1.best_done == 1 and merged.records.level1.best_goal_ids in [["a"], ["b"]],
		"distinct equal-scoring runs never union disjoint goal IDs into false completion")
	right.records.level1 = _record(["b", "c"], false)
	merged = cloud._merged_campaign(left, right)
	check(merged.records.level1.best_goal_ids == ["b", "c"] and merged.records.level1.best_done == 2 \
		and merged.records.level1.cleared, "better single run wins intact while cleared flag remains monotonic")
	var invalids: Array = []
	for field in ["owner", "schema", "campaign", "updated_at", "settings_text", "language_text"]:
		var value := _payload()
		value[field] = {} if field != "campaign" else []
		invalids.append({"label": "wrong type " + field, "payload": value})
	for owner in ["", "222"]:
		invalids.append({"label": "ownerless/foreign owner " + owner, "payload": _payload(owner, 8)})
	var malformed_record := _payload()
	malformed_record.campaign.records = {"level1": {"best_done": "bad", "best_goal_ids": {}}}
	invalids.append({"label": "malformed nested campaign record", "payload": malformed_record})
	var invalid_settings := _payload("111", 8)
	invalid_settings.settings_text = "[audio]\nbgm=8\n"
	invalids.append({"label": "invalid settings prevents partial campaign apply", "payload": invalid_settings})
	var invalid_language := _payload("111", 8)
	invalid_language.language_text = "[language]\nlocale=\"bogus\"\n"
	invalids.append({"label": "invalid language prevents partial campaign apply", "payload": invalid_language})
	for item in invalids:
		_fresh()
		_remote(item.payload)
		var before: PackedByteArray = fake.cloud_files[cloud.CLOUD_FILE].duplicate()
		cloud._attach_account()
		cloud.mark_dirty()
		cloud._process(60.0)
		check(fake.file_writes == 0 and fake.cloud_files[cloud.CLOUD_FILE] == before and campaign.unlocked == 1,
			"malformed remote fails closed: " + String(item.label))


func _campaign_persistence_cases() -> void:
	_fresh()
	var payload := _payload("111", 7)
	payload.campaign.records = {"level1": _record(["a", "b"])}
	_remote(payload)
	cloud._attach_account()
	var cfg := ConfigFile.new()
	cfg.set_value("future", "preserved", "private-fixture")
	check(cfg.save("user://campaign.cfg") == OK, "write private campaign unknown-section fixture")
	# Exercise normal persistence once, synchronously, inside the private profile.
	# The project/profile/no-native boundary was verified above; STEAM_DISABLED
	# stays 1, and a nonempty CAMPAIGN_QA still makes SteamRunPolicy reject Steam.
	# No frame, callback, network call, or await can occur inside this scope.
	var qa := OS.get_environment("CAMPAIGN_QA")
	OS.set_environment("CAMPAIGN_QA", "0")
	campaign._save()
	OS.set_environment("CAMPAIGN_QA", qa)
	cfg = ConfigFile.new()
	check(cfg.load("user://campaign.cfg") == OK and cfg.get_value("progress", "owner", "") == "111" \
		and cfg.get_value("progress", "unlocked", 0) == 7,
		"actual Campaign._save persists bound owner and downloaded unlock progress")
	check(cfg.get_value("future", "preserved", "") == "private-fixture",
		"normal campaign persistence preserves unrelated future sections")
	check(cloud.dirty and cloud._read_mirror().campaign.unlocked == 7,
		"actual Campaign._save routes dirty notification into the tested /root/SteamCloud")
	campaign.cloud_owner = ""
	campaign.unlocked = 1
	campaign.records = {}
	campaign._load()
	check(campaign.cloud_owner == "111" and campaign.unlocked == 7 \
		and campaign.records.get("level1", {}).get("best_goal_ids", []) == ["a", "b"],
		"actual Campaign._load restores account ownership and intact best-run goal set")
	cloud._flush()
	settings.bgm = 0.47
	OS.set_environment("CAMPAIGN_QA", "0")
	settings.save()
	OS.set_environment("CAMPAIGN_QA", qa)
	check(cloud.dirty and cloud._read_mirror().settings_text == settings.cloud_text(),
		"actual Settings.save persists and notifies the tested Cloud fixture through the production root path")
	cloud._flush()
	var language_override: bool = localize._test_override
	localize._test_override = false
	localize.set_language("ja", true)
	localize._test_override = language_override
	var language_disk := ConfigFile.new()
	check(cloud.dirty and cloud._read_mirror().language_text == localize.cloud_text() \
		and language_disk.load("user://language.cfg") == OK and language_disk.get_value("language", "locale", "") == "ja",
		"actual language persistence notifies Cloud and stores the new locale only in the private profile")
	cloud._flush()
	var revision: int = cloud._revision
	OS.set_environment("CAMPAIGN_QA", "0")
	var applied: bool = cloud._apply_profile(_payload("111", 7))
	OS.set_environment("CAMPAIGN_QA", qa)
	check(applied and cloud._revision == revision and not cloud.dirty,
		"real Campaign save callback during cloud apply is suppressed by the production reentrancy guard")
	check(OS.get_environment("CAMPAIGN_QA") == "1" and OS.get_environment("STEAM_DISABLED") == "1",
		"scoped private persistence probe immediately restores the QA guard")


func _run() -> void:
	if not _private_ok():
		print("[steam-cloud-result] ", JSON.stringify({"passed": false, "checks": [], "failures": ["private project/profile guard"]}))
		quit(2)
		return
	settings = root.get_node("Settings")
	campaign = root.get_node("Campaign")
	localize = root.get_node("Localize")
	service = root.get_node("SteamService")
	service.set_process(false)
	# Replace only the disabled test-process node, never source autoload config.
	# Production Settings/Campaign hooks now reach the instance under test.
	root.get_node("SteamCloud").free()
	root.get_node("SteamPresence").set_process(false)
	settings.keybinds_changed.connect(func(): key_notifications += 1)
	localize.language_changed.connect(func(_locale): language_notifications += 1)
	check(service.native == null and not service.available, "production startup did not initialize or load real Steam")
	_no_op_and_sdk_cases()
	_ownership_cases()
	_read_retry_cases()
	_write_retry_and_offline_cases()
	_account_transition_write_failure_case()
	_runtime_settings_cases()
	_merge_and_malformed_cases()
	_campaign_persistence_cases()
	_dispose()
	check(OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA") == "1",
		"Steam stayed disabled and the player-persistence environment guard is restored")
	var result_file := FileAccess.open(OS.get_environment("LSH_RTS_QA_OUT").path_join("steam-cloud-result.json"), FileAccess.WRITE)
	check(result_file != null, "write cloud regression receipt outside the frozen project")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"profile": OS.get_user_data_dir(), "native_steam": false, "production_scripts": true}
	if result_file != null:
		result_file.store_string(JSON.stringify(report, "\t"))
		result_file.close()
	print("[steam-cloud-result] ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
