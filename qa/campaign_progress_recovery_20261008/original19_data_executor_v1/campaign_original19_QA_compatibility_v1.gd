extends SceneTree
## Each original QA compatibility case requires its own QA1 private process.
## These outcomes cannot qualify normal persistence, UI, recovery or SDK.
const IDS := ["QA_memory_only","QA_cloud_bool_compatibility"]
var checks: Array=[]
var failures: Array=[]
var output: String=""
var nonce: String=""
var mode: String=""
var identity: Dictionary={}
var campaign: Node
var cloud: Node
var sentinel_sha: String=""

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String, detail: Variant=null) -> bool:
	checks.append({"label":label,"ok":ok,"detail":detail})
	if not ok: failures.append(label)
	return ok

func _run() -> void:
	output=OS.get_environment("CAMPAIGN_COMPAT19_OUTPUT")
	nonce=OS.get_environment("CAMPAIGN_COMPAT19_NONCE")
	mode=OS.get_environment("CAMPAIGN_COMPAT19_CASE")
	var profile: String=OS.get_environment("CAMPAIGN_COMPAT19_PROFILE").replace("\\","/").simplify_path().trim_suffix("/")
	if mode not in IDS or not output.is_absolute_path() or nonce.length()!=32 or not profile.is_absolute_path() or OS.get_environment("CAMPAIGN_QA")!="1" or OS.get_environment("STEAM_DISABLED")!="1": quit(2);return
	for key in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		if OS.get_environment(key).replace("\\","/").simplify_path().to_lower()!=profile.path_join(key.to_lower()).to_lower(): quit(2);return
	if not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(profile.path_join("appdata").to_lower()+"/"): quit(2);return
	check(Engine.time_scale==1.0 and Engine.physics_ticks_per_second==60,"normal clock in explicitly QA-only process")
	if not check(change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))==OK,"actual configured menu opens"): _finish();return
	for frame in range(180): await process_frame
	while Engine.is_in_physics_frame(): await process_frame
	campaign=root.get_node("Campaign");cloud=root.get_node("SteamCloud")
	var provider: Script=load("res://scripts/run_content_identity.gd")
	identity=provider.new().resolve_runtime_identity()
	var identity_path: String=OS.get_environment("CAMPAIGN_COMPAT19_IDENTITY_FILE")
	var expected: Variant=JSON.parse_string(FileAccess.get_file_as_string(identity_path)) if FileAccess.file_exists(identity_path) else null
	if not check(expected is Dictionary and FileAccess.get_sha256(identity_path)==OS.get_environment("CAMPAIGN_COMPAT19_IDENTITY_SHA256"),"controller immutable post cold identity readable"): _finish();return
	for field in expected.runtime_fields: check(identity.get(field)==expected.runtime_fields[field],"complete installed identity field "+field)
	var flow:=root.get_node("ContinueFlow")
	if not check(identity.get("save_eligible",false) and flow.phase==flow.Phase.IDLE and flow.last_result.get("startup_checked",false),"actual source and startup eligible"): _finish();return
	if not check(cloud.get_script()==load("res://scripts/steam_cloud.gd") and campaign.get_script()==load("res://scripts/campaign.gd"),"actual production Campaign and Cloud nodes retained"): _finish();return
	var steam:=root.get_node("SteamService")
	check(not steam.available and steam._active_run==0,"SDK disabled with no active credited run")
	if not check(not FileAccess.file_exists(campaign.SAVE_PATH),"own fresh compatibility profile initially has no campaign CFG"): _finish();return
	var seed:=ConfigFile.new()
	seed.set_value("progress","schema",2);seed.set_value("progress","unlocked",1);seed.set_value("progress","records",{});seed.set_value("progress","owner","")
	seed.set_value("future]section","sentinel",nonce)
	if not check(seed.save(campaign.SAVE_PATH)==OK,"real private sentinel ConfigFile seed"): _finish();return
	sentinel_sha=FileAccess.get_sha256(campaign.SAVE_PATH)
	campaign._load()
	var before_dirty: bool=cloud.dirty
	var before_pending: bool=cloud._pending_upload
	var before_revision: int=cloud._revision
	if mode==IDS[0]:
		var full: Dictionary={"core_cleared":true,"story_complete":true,"story_done":3,"story_total":3,"done_ids":["daming_infiltration","daming_signal","daming_response"],"contract_version":2}
		var outcome: Dictionary=campaign.record_level_result("level8",full)
		check(outcome.get("accepted",false) and outcome.get("new_story_seal",false) and campaign.has_story_seal("level8"),"retained QA result applies in memory and marks first seal",outcome)
		check(campaign._save()==true,"retained QA legacy save bool remains true")
		check(campaign._cfg_writer==null and not campaign.persistence_busy(),"QA suppression creates no normal CFG writer")
	else:
		var owner: String="123456789"
		cloud._owner=owner
		var payload: Dictionary=cloud._default_payload(owner)
		payload.campaign={"schema":2,"unlocked":4,"records":{"level6":{"cleared":true}}}
		if not check(cloud._validate_payload(payload,owner),"original private cloud payload validates"): _finish();return
		var accepted: bool=cloud._apply_profile(payload)
		check(accepted and campaign.cloud_owner==owner and campaign.unlocked==4 and campaign.records.has("level6"),"actual Cloud QA bool and Campaign memory replacement retained")
		check(not cloud._applying and not cloud.shared_profile_pending() and campaign._cfg_writer==null,"actual QA apply completes without normal CFG writer")
	check(FileAccess.get_sha256(campaign.SAVE_PATH)==sentinel_sha,"actual campaign CFG sentinel bytes unchanged")
	check(cloud.dirty==before_dirty and cloud._pending_upload==before_pending and cloud._revision==before_revision,"actual Cloud dirty callback state unchanged")
	var readback:=ConfigFile.new()
	check(readback.load(campaign.SAVE_PATH)==OK and readback.get_value("future]section","sentinel")==nonce and readback.get_value("progress","records")=={},"real sentinel readback contains no QA campaign progress")
	_finish()

func _finish() -> void:
	var path: String=output.path_join("report.json")
	if FileAccess.file_exists(path): quit(2);return
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: quit(2);return
	var report: Dictionary={"schema":"campaign_original19_QA_compatibility_v1","case":mode,"pid":OS.get_process_id(),"nonce":nonce,"passed":failures.is_empty(),"checks":checks,"failures":failures,
		"identity":identity,"actual_user_directory":OS.get_user_data_dir(),"sentinel_sha256":sentinel_sha,"time_scale":Engine.time_scale,"physics_ticks":Engine.physics_ticks_per_second,
		"scope":"retained QA1-only Campaign compatibility; Cloud may retain its private settings/language apply behavior; Campaign CFG must not change",
		"CAMPAIGN_QA_enabled":true,"normal_persistence_qualified":false,"original19_qualified":false,"UI_qualified":false,"SDK_reward_once_qualified":false,"overall_goal_qualified":false}
	file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
	print("CAMPAIGN_ORIGINAL19_QA_COMPATIBILITY ",mode," ",report.passed," ",checks.size())
	quit(0 if report.passed else 1)
