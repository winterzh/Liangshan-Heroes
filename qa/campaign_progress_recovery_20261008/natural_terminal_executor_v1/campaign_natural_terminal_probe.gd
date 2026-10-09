extends SceneTree
## Normal-mode player orders and production terminal/startup paths only.
## This scope is one fresh Huangnigang campaign; it does not replace Lu/Shi ABCD.
const Gate := preload("res://scripts/run_campaign_progress_gate.gd")
const Provider := preload("res://scripts/run_content_identity.gd")
const Intent := preload("res://scripts/run_campaign_progress_intent.gd")
const Lifecycle := preload("res://scripts/run_campaign_local_lifecycle.gd")
var checks: Array = []
var failures: Array = []
var orders := 0
var output := ""
var nonce := ""
var mode := ""
var identity: Dictionary = {}
var b: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String, detail: Variant = null) -> bool:
	checks.append({"label":label,"ok":ok,"detail":detail})
	if not ok: failures.append(label); print("NATURAL_TERMINAL_FAIL ",label," ",detail)
	return ok

func _write(name: String, value: Dictionary) -> bool:
	var path := output.path_join(name)
	if FileAccess.file_exists(path): return false
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value,"\t")+"\n"); file.close()
	return true

func _run() -> void:
	output = OS.get_environment("CAMPAIGN_TERMINAL_OUTPUT")
	nonce = OS.get_environment("CAMPAIGN_TERMINAL_NONCE")
	mode = OS.get_environment("CAMPAIGN_TERMINAL_MODE")
	var profile := OS.get_environment("CAMPAIGN_TERMINAL_PROFILE").replace("\\","/").simplify_path().trim_suffix("/")
	if output.is_empty() or nonce.length()!=32 or mode not in ["fresh","restart"] or not profile.is_absolute_path(): quit(2); return
	for key in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		if OS.get_environment(key).replace("\\","/").simplify_path().to_lower()!=profile.path_join(key.to_lower()).to_lower(): quit(2);return
	if not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(profile.path_join("appdata").to_lower()+"/") \
		or OS.get_environment("STEAM_DISABLED")!="1" or not OS.get_environment("CAMPAIGN_QA").is_empty(): quit(2);return
	check(Engine.time_scale==1.0 and Engine.physics_ticks_per_second==60,"normal simulation clock")
	check(change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))==OK,"actual configured menu opens")
	for frame in range(180): await process_frame
	while Engine.is_in_physics_frame(): await process_frame
	identity = Provider.new().resolve_runtime_identity()
	var flow := root.get_node("ContinueFlow")
	check(identity.get("save_eligible",false),"actual installed source identity is eligible")
	check(current_scene!=null and current_scene.scene_file_path=="res://scenes/menu.tscn","actual menu remains current")
	check(flow.phase==flow.Phase.IDLE and flow.last_result.get("startup_checked",false) and Gate.background_allowed(),"production startup finishes and opens gate",flow.last_result.duplicate(true))
	if failures.is_empty():
		if mode=="fresh": await _fresh()
		else: await _restart()
	_finish()

func _until(predicate: Callable, seconds: float) -> bool:
	var started: int = Time.get_ticks_msec()
	var tick: int = b._run_clock._next_tick
	while not predicate.call() and b.phase==b.Phase.FIGHT and (b._run_clock._next_tick-tick)/60.0<seconds and Time.get_ticks_msec()-started<int(maxf(30,seconds*3)*1000):
		await process_frame
	return predicate.call()

func _move(actor: Node, cell: Vector2i) -> bool:
	if not is_instance_valid(actor) or actor.hp<=0.0 or actor.story_outcome!="": return check(false,"ordinary order actor alive")
	b.select_single(actor,false)
	b.minimap_order(b.map.cell_to_world(cell),false)
	orders+=1
	return check(actor.manual_order_active or actor.mission_order_active,"ordinary player minimap order "+actor.key)

func _action(actor: Node, action: String, seconds := 50.0) -> bool:
	if not check(b.mission.actions.has(action),"actual action available "+action): return false
	var event: String = "action:%s:%s" % [b.mission.stage_id,action]
	if not _move(actor,b.mission.actions[action].cell): return false
	return check(await _until(func(): return b.mission.has_event(event),seconds),"native walking/action completes "+action,{"stage":b.mission.stage_id,"position":actor.position,"phase":b.phase})

func _fresh() -> void:
	var campaign := root.get_node("Campaign")
	var flow := root.get_node("ContinueFlow")
	check(not FileAccess.file_exists(campaign.SAVE_PATH) and not DirAccess.dir_exists_absolute("user://continue/v1/local_runs"),"fresh group has no CFG or lifecycle fixture")
	check(campaign.current==0 and not campaign.skirmish and not campaign.skirmish_ai and not campaign.arena and not campaign.custom_defense and not campaign.scenario and not campaign.scale_on and not campaign.ai_friendly,"ordinary default first campaign selection")
	if not failures.is_empty(): return
	current_scene._launch()
	for frame in range(300):
		await process_frame
		if current_scene!=null and current_scene.scene_file_path=="res://scenes/main.tscn": break
	b=current_scene
	if not check(b!=null and b.scene_file_path=="res://scenes/main.tscn" and b.level.id()=="level1","menu launches real campaign Battle"): return
	for line in range(16):
		if not b.hud._intro_root.visible: break
		b.hud._advance_intro()
	await process_frame
	if b.phase==b.Phase.DEPLOY: b.hud.start_battle.emit()
	for frame in range(12): await physics_frame
	await process_frame
	if not check(b.phase==b.Phase.FIGHT and b._official_context=={"mode":"campaign","level_id":"level1","waves":0},"production Battle context and FIGHT",b._official_context.duplicate(true)): return
	if not check(Engine.time_scale==1.0 and Engine.physics_ticks_per_second==60 and b.gameplay_rng_fault().is_empty() and b._run_clock.fault().is_empty(),"normal native Battle clock and random source healthy"): return
	if not check(await _until(func(): return b.mission.has_event("yang_inquired"),100),"fifteen convoy members naturally arrive and inquire"): return
	if not await _action(b.find_unit("liu_tang"),"answer_yang"): return
	if not check(await _until(func(): return b.mission.has_event("bai_unloaded"),60),"Bai walks in and unloads naturally"): return
	var l = b.level
	if not _move(b.find_unit("wu_yong"),l.WU_STATION) or not _move(b.find_unit("bai_sheng"),l.BAI_STATION): return
	if not await _action(b.find_unit("liu_tang"),"taste_wine"): return
	if not check(await _until(func(): return l._team_ready(b),25),"actual wine partners at stations"): return
	if not await _action(b.find_unit("liu_tang"),"distract_yang"): return
	if not check(await _until(func(): return l.drug_done,15),"natural three person wine scheme completes"): return
	if not check(l.convoy.size()==15 and l.convoy.all(func(u): return is_instance_valid(u) and u.hp>0.0 and u.story_outcome=="unconscious") and b.kills==0,"all fifteen real guards unconscious without kills"): return
	for index in range(3):
		var carrier = b.find_unit(["liu_tang","ruan_xiaowu","ruan_xiaoqi"][index])
		if not await _action(carrier,"force_take_%d_0" % index): return
		if not await _action(carrier,"force_deliver_%d_0" % index,60): return
	if not check(l.delivered==3 and l.st==l.WITHDRAW and not l.depart_requested,"all original loads delivered by ordinary orders"): return
	if not check(_write("ready_for_terminal.json",{"schema":"campaign_natural_terminal_ready_v1","pid":OS.get_process_id(),"nonce":nonce,"checks":checks.duplicate(true),"orders":orders,"identity":identity,"actual_user_directory":OS.get_user_data_dir(),"phase":b.phase,"delivered":l.delivered,"clock":b._run_clock._next_tick,"fresh_context":b._official_context.duplicate(true)}),"immutable preterminal actual state handshake"): return
	var gathering: Vector2i = l.GATE_W+Vector2i(2,1)
	for actor in l.actors:
		if not _move(actor,gathering): return
	if not check(await _until(func(): return l.victory,80),"eight survivors naturally reach victory"): return
	for frame in range(180): await process_frame
	while Engine.is_in_physics_frame(): await process_frame
	if not check(b.phase==b.Phase.END and flow.phase==flow.Phase.IDLE and flow.last_result.get("campaign_progress_committed",false),"production deferred terminal confirms progress",flow.last_result.duplicate(true)): return
	check(l.actors.size()==8 and l.actors.all(func(u):return is_instance_valid(u) and u.hp>0 and u.position.distance_to(b.map.cell_to_world(l.GATE_W))<=150) and b.mission.has_event("huangnigang_all_safe"),"all eight survive natural withdrawal")
	check(b.mission._result_frozen and b.mission._result_cache.story_complete,"production Mission frozen full story result",b.mission._result_cache.duplicate(true))
	check(b.hud._end_root.visible,"actual end HUD appears after confirmation")
	if not check(b._continue_receipt!=null and b._continue_receipt.get_script()==Lifecycle,"production campaign v2 lifecycle retained"): return
	var head: Dictionary = b._continue_receipt.open_head()
	if not check(head.ok and head.revision==3 and head.document.progress_state=="applied","actual third generation acknowledgement",head): return
	var cfg := ConfigFile.new()
	check(cfg.load(campaign.SAVE_PATH)==OK and Intent.cfg_dominates(cfg,head.document.intent),"actual CFG dominates frozen natural intent")
	var frozen: Dictionary = _terminal_files(b._continue_receipt.directory)
	var cfg_sha: String = FileAccess.get_sha256(campaign.SAVE_PATH)
	check(not flow.claim_campaign_completion(b,true).ok,"consumed presentation capability rejects repeat claim")
	for frame in range(120): await process_frame
	check(_terminal_files(b._continue_receipt.directory)==frozen and FileAccess.get_sha256(campaign.SAVE_PATH)==cfg_sha and b.mission._metrics_closed,"ordinary post terminal frames do not replay persistence or metrics")
	check(_write("terminal_handoff.json",{"schema":"campaign_natural_terminal_handoff_v1","pid":OS.get_process_id(),"nonce":nonce,"token":b._continue_receipt.token,"context":b._official_context,"identity":identity,"files":frozen,"cfg_sha256":cfg_sha,"intent":head.document.intent}),"actual immutable terminal handoff")

func _terminal_files(directory: String) -> Dictionary:
	var files: Dictionary = {}
	for revision in range(1,4):
		var path := directory.path_join("record_%010d.json" % revision)
		files[path.get_file()] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	return files

func _restart() -> void:
	var token := OS.get_environment("CAMPAIGN_TERMINAL_TOKEN")
	var recovery := OS.get_environment("CAMPAIGN_TERMINAL_EXPECT_RECOVERY")=="1"
	if not check(Intent.hex(token,32),"controller binds actual preceding natural run token"): return
	var context := {"mode":"campaign","level_id":"level1","waves":0}
	var campaign := root.get_node("Campaign")
	var flow := root.get_node("ContinueFlow")
	var life := Lifecycle.new(token,"user://continue/v1",context,identity,campaign.cloud_owner)
	var head: Dictionary = life.open_head()
	if not check(head.ok and head.revision==3 and head.document.progress_state=="applied" and head.document.intent.result.story_complete,"startup reads/recoveries actual natural third generation",head): return
	check(int(flow.last_result.get("progress_recovered",-1))==(1 if recovery else 0) and not flow.last_result.get("settlement_authorized",true),"startup recovery count and settlement denial",flow.last_result.duplicate(true))
	var cfg := ConfigFile.new()
	check(cfg.load(campaign.SAVE_PATH)==OK and Intent.cfg_dominates(cfg,head.document.intent),"restart actual CFG confirms same intent")
	check(current_scene.scene_file_path=="res://scenes/menu.tscn" and not flow.last_result.get("terminal_completed",false) and flow._campaign_completion.is_empty(),"restart creates no Battle or presentation capability")
	var steam := root.get_node("SteamService")
	check(not steam.available and steam._active_run==0,"isolated disabled Steam has no restarted active run")
	var frozen: Dictionary = _terminal_files(life.directory)
	var cfg_sha: String = FileAccess.get_sha256(campaign.SAVE_PATH)
	for frame in range(180): await process_frame
	check(_terminal_files(life.directory)==frozen and FileAccess.get_sha256(campaign.SAVE_PATH)==cfg_sha,"restart ordinary frames keep exact confirmed files")
	check(_write("restart_handoff.json",{"schema":"campaign_natural_terminal_restart_v1","pid":OS.get_process_id(),"nonce":nonce,"token":token,"files":frozen,"cfg_sha256":cfg_sha,"intent":head.document.intent,"startup_result":flow.last_result.duplicate(true)}),"actual immutable restart handoff")

func _finish() -> void:
	var report := {"schema":"campaign_natural_terminal_probe_v1","passed":failures.is_empty(),"checks":checks,"failures":failures,"pid":OS.get_process_id(),"nonce":nonce,"mode":mode,"orders":orders,"identity":identity,"user_directory":OS.get_user_data_dir(),"time_scale":Engine.time_scale,"physics_ticks":Engine.physics_ticks_per_second,"scope":"One ordinary fresh Huangnigang natural terminal and production startup recovery; isolated Steam disabled.","all_roles_ABCD_qualified":false,"original19_faults_qualified":false,"pending_failure_UI_qualified":false,"Steam_rewards_qualified":false}
	if not _write("report.json",report): quit(2);return
	print("CAMPAIGN_NATURAL_TERMINAL_PROBE ",mode," ",report.passed," ",checks.size())
	quit(0 if report.passed else 1)
