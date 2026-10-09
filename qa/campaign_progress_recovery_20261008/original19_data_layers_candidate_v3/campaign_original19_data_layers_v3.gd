extends SceneTree
## Six original data-layer cases using current projection and real CFG writer.
## Pure intent fixtures never provide a live Battle or settlement capability.
const IDS := ["true_new_missing_cfg", "best_single_run_no_union", "invalid_no_unlock",
	"legal_unknown_variant_preservation", "unsupported_object_or_script_container", "cycle_or_overdepth"]
class ScriptTypedFixture extends RefCounted:
	pass
var Intent: Script
var ProgressProjection: Script
var Values: Script
var Transaction: Script
var identity: Dictionary = {}
var expected: Dictionary = {}
var checks: Array = []
var failures: Array = []
var cases: Array = []
var campaign: Node
var output := ""
var nonce := ""
var case_id := ""
var start_checks := 0
var original_memory: Dictionary = {}
var invalid_refusals: Array = []
var commits: Array = []
var case_before: Dictionary = {}
var original_unknown_expectation: Dictionary = {}
var final_cfg_evidence: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String, detail: Variant = null) -> bool:
	checks.append({"case":case_id,"label":label,"ok":ok,"detail":detail})
	if not ok: failures.append(case_id+":"+label)
	return ok

func _memory() -> Dictionary:
	return {"records":campaign.records.duplicate(true),"unlocked":campaign.unlocked,"owner":campaign.cloud_owner}

func _request(intent: Dictionary = {}) -> Dictionary:
	return {"operation":"prefs" if intent.is_empty() else "progress", "run_token":"" if intent.is_empty() else intent.token,
		"intent_sha256":"" if intent.is_empty() else JSON.stringify(intent).sha256_text(), "target_owner":campaign.cloud_owner,
		"content_version":identity.content_version,"engine_sha256":identity.engine_binary_sha256}

func _intent(ids: Array) -> Dictionary:
	return {"schema":"campaign_progress_intent_v1","token":Crypto.new().generate_random_bytes(16).hex_encode(),
		"context":expected.context.duplicate(),"profile_id":expected.profile_id,"owner":expected.scope.owner,
		"content_version":expected.scope.content_version,"engine_sha256":expected.scope.engine_sha256,"victory":true,
		"result":{"core_cleared":true,"story_complete":ids.size()==3,"story_done":ids.size(),"story_total":3,
			"done_ids":ids.duplicate(),"contract_version":2}}

func _evidence_bad(label: String) -> Dictionary:
	failures.append("evidence:"+label)
	return {"ok":false,"code":label}

func _copy_raw(source: String, label: String) -> Dictionary:
	if not FileAccess.file_exists(source): return _evidence_bad(label+":source_missing")
	var sha: String=FileAccess.get_sha256(source)
	var raw: PackedByteArray=FileAccess.get_file_as_bytes(source)
	var destination: String=output.path_join("cfg_evidence").path_join(label)
	if FileAccess.file_exists(destination) or DirAccess.dir_exists_absolute(destination): return _evidence_bad(label+":destination_exists")
	if DirAccess.make_dir_recursive_absolute(destination.get_base_dir())!=OK: return _evidence_bad(label+":parent")
	var file:=FileAccess.open(destination,FileAccess.WRITE)
	if file==null: return _evidence_bad(label+":open")
	file.store_buffer(raw);file.flush();file.close()
	if FileAccess.get_sha256(source)!=sha or FileAccess.get_sha256(destination)!=sha: return _evidence_bad(label+":changed")
	return {"ok":true,"source_path":ProjectSettings.globalize_path(source),"copy_path":destination,"bytes":raw.size(),"sha256":sha}

func _value_types(value: Variant) -> Dictionary:
	var tag: Dictionary={"variant_type":typeof(value),"variant_name":type_string(typeof(value))}
	if value is Array:
		tag.array_builtin=value.get_typed_builtin()
		tag.array_class=String(value.get_typed_class_name())
		tag.array_script_null=value.get_typed_script()==null
	elif value is Dictionary:
		tag.key_builtin=value.get_typed_key_builtin();tag.value_builtin=value.get_typed_value_builtin()
		tag.key_class=String(value.get_typed_key_class_name());tag.value_class=String(value.get_typed_value_class_name())
		tag.key_script_null=value.get_typed_key_script()==null;tag.value_script_null=value.get_typed_value_script()==null
	return tag

func _cfg_types(cfg: ConfigFile) -> Dictionary:
	var types: Dictionary={}
	for section in cfg.get_sections():
		var keys: Dictionary={}
		for key in cfg.get_section_keys(section): keys[key]=_value_types(cfg.get_value(section,key))
		types[section]=keys
	return types

func _journal_evidence(label: String) -> Dictionary:
	var reader: RefCounted=Transaction.new()
	var directory: String=reader.directory
	if not DirAccess.dir_exists_absolute(directory): return {"ok":true,"exists":false,"directory":directory,"files":[],"directories":[],"head_generation":0}
	var folder:=DirAccess.open(directory)
	if folder==null: return _evidence_bad(label+":journal_open")
	var directories: Array=Array(folder.get_directories())
	if not directories.is_empty(): return _evidence_bad(label+":journal_unclosed_directory")
	var names: Array=Array(folder.get_files());names.sort()
	var entries: Array=[]
	for name in names:
		if folder.is_link(name) or not String(name).begins_with("record_") or not String(name).ends_with(".json"): return _evidence_bad(label+":journal_foreign_file")
		var opened: Dictionary=reader._verified(name)
		if not opened.ok or name!="record_%010d.json" % int(opened.revision): return _evidence_bad(label+":journal_actual_decode")
		var copied: Dictionary=_copy_raw(directory.path_join(name),label+"_"+name)
		if not copied.get("ok",false) or copied.sha256!=opened.file_sha256: return _evidence_bad(label+":journal_original_sha")
		entries.append({"name":name,"copy":copied,"document":opened.document.duplicate(true),"revision":opened.revision,"previous_sha256":opened.previous,"file_sha256":opened.file_sha256})
	var head: Dictionary=reader._chain()
	if not head.ok or entries.size()!=2 or entries.back().revision!=head.revision: return _evidence_bad(label+":journal_exact_retained_pair")
	return {"ok":true,"exists":true,"directory":directory,"files":entries,"directories":directories,"head_generation":head.revision,"head_sha256":head.file_sha256}

func _stage_evidence() -> Dictionary:
	var path: String=ProjectSettings.globalize_path(Transaction.STAGES)
	if not DirAccess.dir_exists_absolute(path): return {"ok":true,"exists":false,"path":path,"files":[],"directories":[]}
	var folder:=DirAccess.open(path)
	if folder==null or not folder.get_files().is_empty() or not folder.get_directories().is_empty(): return _evidence_bad("candidate_stages_not_empty")
	return {"ok":true,"exists":true,"path":path,"files":[],"directories":[]}

func _cfg_evidence(label: String) -> Dictionary:
	var journal: Dictionary=_journal_evidence(label)
	var stages: Dictionary=_stage_evidence()
	if not journal.get("ok",false) or not stages.get("ok",false): return _evidence_bad(label+":unclosed_inventory")
	if not FileAccess.file_exists(campaign.SAVE_PATH):
		return {"ok":true,"exists":false,"sha256":Transaction.ZERO,"bytes":0,"copy":{},"semantics":{"ok":true,"sections":{}},"type_metadata":{},"progress":{},"journal":journal,"stages":stages}
	var sha: String=FileAccess.get_sha256(campaign.SAVE_PATH)
	var cfg:=ConfigFile.new()
	if cfg.load(campaign.SAVE_PATH)!=OK: return _evidence_bad(label+":cfg_fresh_load")
	var semantics: Dictionary=Values.semantics(cfg)
	var copied: Dictionary=_copy_raw(campaign.SAVE_PATH,label+"_campaign.cfg")
	if not semantics.ok or not copied.get("ok",false) or copied.sha256!=sha or FileAccess.get_sha256(campaign.SAVE_PATH)!=sha: return _evidence_bad(label+":cfg_stable_original_bytes")
	var progress: Dictionary={}
	if cfg.has_section("progress"):
		for key in cfg.get_section_keys("progress"): progress[key]=cfg.get_value("progress",key)
	return {"ok":true,"exists":true,"sha256":sha,"bytes":copied.bytes,"copy":copied,"semantics":semantics,"type_metadata":_cfg_types(cfg),"progress":progress,"journal":journal,"stages":stages}

func _record_commit(tag: String, intent: Dictionary, request: Dictionary, before_sha: String, receipt: Dictionary) -> void:
	if not receipt.get("ok",false) or not receipt.get("persisted",false) or receipt.get("suppressed",true):
		_evidence_bad(tag+":not_actual_confirmed_commit");return
	var snapshot: Dictionary=_cfg_evidence("commit_"+tag)
	if not snapshot.get("ok",false) or snapshot.sha256!=receipt.get("file_sha256",""): _evidence_bad(tag+":actual_receipt_sha");return
	commits.append({"tag":tag,"case":case_id,"request":request.duplicate(true),"intent":intent.duplicate(true),"original_sha256":before_sha,"receipt":receipt.duplicate(true),"actual":snapshot})

func _begin(id: String) -> void:
	case_id=id; start_checks=checks.size()
	case_before=_cfg_evidence(id+"_before")

func _end() -> void:
	check(_memory()==original_memory,"pure data tests do not publish Campaign memory")
	var after: Dictionary=_cfg_evidence(case_id+"_after")
	cases.append({"id":case_id,"checks":checks.slice(start_checks),"passed":checks.slice(start_checks).all(func(row):return row.ok) and case_before.get("ok",false) and after.get("ok",false),"before_CFG":case_before,"after_CFG":after})

func _new_cfg() -> void:
	_begin(IDS[0])
	if not check(not FileAccess.file_exists(campaign.SAVE_PATH),"genuinely new private CFG absent"): _end();return
	var writer: RefCounted=Transaction.new()
	var intent: Dictionary=_intent(["daming_infiltration"])
	if not check(Intent.validate(intent,intent.token,expected).ok,"first missing CFG valid typed partial intent"): _end();return
	var opened: Dictionary=writer.begin_write(_request(intent))
	if not check(opened.ok and opened.original_sha256==writer.ZERO,"real transaction identifies missing prior"): _end();return
	var projected: Dictionary=ProgressProjection.project(intent,intent.token,expected,opened.cfg)
	if not check(projected.ok and not projected.new_story_seal,"first missing CFG actual progress projection"):
		writer.abort_unprepared();_end();return
	opened.cfg.set_value("future]section","sentinel",11)
	var saved: Dictionary=writer.commit_prepared(opened.cfg)
	check(saved.ok and saved.persisted and not saved.suppressed and saved.code=="CAMPAIGN_CFG_READBACK_VERIFIED","real new CFG save and acknowledgement",saved)
	_record_commit("first_progress",intent,_request(intent),opened.original_sha256,saved)
	var readback:=ConfigFile.new()
	check(readback.load(campaign.SAVE_PATH)==OK and readback.get_value("future]section","sentinel")==11,"actual new CFG fresh read")
	_end()

func _best_single_run() -> void:
	_begin(IDS[1])
	var operation_index: int=0
	for ids in [["daming_infiltration"],["daming_signal","daming_response"],["daming_infiltration","daming_response"],["daming_infiltration"]]:
		var intent: Dictionary=_intent(ids)
		var validated: Dictionary=Intent.validate(intent,intent.token,expected)
		if not check(validated.ok,"current typed partial intent validates "+str(cases.size())+":"+str(checks.size())): break
		var writer: RefCounted=Transaction.new()
		var opened: Dictionary=writer.begin_write(_request(intent))
		if not check(opened.ok,"actual projection transaction opens "+str(checks.size())): break
		var projected: Dictionary=ProgressProjection.project(intent,intent.token,expected,opened.cfg)
		if not check(projected.ok and not projected.new_story_seal,"current single-run projection accepted "+str(checks.size())):
			writer.abort_unprepared();break
		var saved: Dictionary=writer.commit_prepared(opened.cfg)
		if not check(saved.ok and saved.persisted and not saved.suppressed,"actual projected CFG confirmed "+str(checks.size()),saved): break
		_record_commit("best_"+str(operation_index),intent,_request(intent),opened.original_sha256,saved)
		operation_index+=1
	var cfg:=ConfigFile.new()
	if check(cfg.load(campaign.SAVE_PATH)==OK,"best-run actual CFG loads"):
		var records: Dictionary=cfg.get_value("progress","records",{})
		check(records.has("level8") and records.level8.best_goal_ids==["daming_signal","daming_response"] and records.level8.best_done==2 and not records.level8.story_complete,"no union and no worse or tied replacement")
		check(cfg.get_value("progress","unlocked")==9,"valid level8 projection persists required unlock")
	_end()

func _invalid() -> void:
	_begin(IDS[2])
	var before_sha: String=FileAccess.get_sha256(campaign.SAVE_PATH)
	var cfg:=ConfigFile.new()
	if not check(cfg.load(campaign.SAVE_PATH)==OK,"invalid-case actual prior loads"): _end();return
	var before: Dictionary=Values.semantics(cfg)
	var requests: Array=[]
	var custom: Dictionary=_intent(["daming_signal"]);custom.context.mode="custom";requests.append(custom)
	var unknown: Dictionary=_intent(["daming_signal"]);unknown.context.level_id="unknown";requests.append(unknown)
	var core: Dictionary=_intent(["daming_signal"]);core.result.core_cleared=false;requests.append(core)
	var bad_goal: Dictionary=_intent(["d"]);requests.append(bad_goal)
	var expected_codes: Array=["CAMPAIGN_INTENT_CONTEXT","CAMPAIGN_INTENT_CONTEXT","CAMPAIGN_INTENT_OUTCOME_MISMATCH","CAMPAIGN_INTENT_IDS"]
	for index in range(requests.size()):
		var rejected: Dictionary=ProgressProjection.project(requests[index],requests[index].token,expected,cfg)
		check(not rejected.ok and rejected.code==expected_codes[index],"invalid current context level core or goal exact refusal "+str(index),rejected)
		invalid_refusals.append({"index":index,"request":requests[index].duplicate(true),"refusal":rejected.duplicate(true),"before_CFG_sha256":before_sha,"after_CFG_sha256":FileAccess.get_sha256(campaign.SAVE_PATH)})
		check(Values.semantics(cfg)==before and FileAccess.get_sha256(campaign.SAVE_PATH)==before_sha,"invalid request performs no CFG mutation or disk write "+str(index))
	_end()

func _legal_unknown() -> void:
	_begin(IDS[3])
	var typed_array: Array[String]=["known","future"]
	var typed_dict: Dictionary[String,Vector2]={"position":Vector2(2.25,-3.5)}
	var legal: Dictionary={"vector":Vector2(1.25,-2.5),"transform":Transform3D.IDENTITY,"projection":Projection.IDENTITY,
		"bytes":PackedByteArray([1,128,255]),"integers":PackedInt64Array([9223372036854775807]),
		"vectors":PackedVector4Array([Vector4(1,2,3,4)]),"colors":PackedColorArray([Color(0.1,0.2,0.3)]),
		"typed_array":typed_array,"typed_dict":typed_dict,"string_name":&"future_name","node_path":NodePath("root/child"),
		"nan":NAN,"inf":INF,"negative_zero":-0.0}
	var writer: RefCounted=Transaction.new()
	var opened: Dictionary=writer.begin_write(_request())
	if not check(opened.ok,"legal unknown real transaction opens"): _end();return
	for key in legal: opened.cfg.set_value("future]section",key,legal[key])
	var before: Dictionary=Values.semantics(opened.cfg)
	original_unknown_expectation={"semantics":before.duplicate(true),"type_metadata":_cfg_types(opened.cfg)}
	if not check(before.ok,"all original legal built-in data semantics valid"):
		writer.abort_unprepared();_end();return
	var saved: Dictionary=writer.commit_prepared(opened.cfg)
	check(saved.ok and saved.persisted and not saved.suppressed,"real legal unknown ConfigFile transaction confirms",saved)
	_record_commit("legal_seed",{},_request(),opened.original_sha256,saved)
	var cfg:=ConfigFile.new()
	if check(cfg.load(campaign.SAVE_PATH)==OK,"actual legal unknown fresh read"):
		var after: Dictionary=Values.semantics(cfg)
		check(after.ok and after.sections==before.sections,"all sections keys and ConfigFile value semantics retained")
	# Unknown values now exist in a confirmed physical CFG before progress update.
	var progress_intent: Dictionary=_intent(["daming_infiltration","daming_signal","daming_response"])
	if not check(Intent.validate(progress_intent,progress_intent.token,expected).ok,"legal prior valid typed progress intent"): _end();return
	var progress_writer: RefCounted=Transaction.new()
	var begun: Dictionary=progress_writer.begin_write(_request(progress_intent))
	if not check(begun.ok and begun.original_sha256==FileAccess.get_sha256(campaign.SAVE_PATH),"legal unknown existing prior progress transaction opens"): _end();return
	var prior: Dictionary=Values.semantics(begun.cfg)
	var projected: Dictionary=ProgressProjection.project(progress_intent,progress_intent.token,expected,begun.cfg)
	if not check(projected.ok and projected.new_story_seal,"actual progress projection updates previously partial record"):
		progress_writer.abort_unprepared();_end();return
	var persisted: Dictionary=progress_writer.commit_prepared(begun.cfg)
	check(persisted.ok and persisted.persisted and not persisted.suppressed,"actual progress update confirms existing unknown CFG",persisted)
	_record_commit("legal_progress",progress_intent,_request(progress_intent),begun.original_sha256,persisted)
	var after_progress:=ConfigFile.new()
	if check(after_progress.load(campaign.SAVE_PATH)==OK,"unknown-preserving actual progress CFG fresh read"):
		var final: Dictionary=Values.semantics(after_progress)
		if check(final.ok,"unknown-preserving progress semantics readable"):
			for section in prior.sections:
				if section!="progress": check(final.sections.has(section) and final.sections[section]==prior.sections[section],"all original unknown section and value semantics preserved "+section)
		check(Intent.cfg_dominates(after_progress,progress_intent),"actual CFG dominates full pure progress fixture")
	_end()

func _refuse(value: Variant, label: String) -> void:
	var prior_sha: String=FileAccess.get_sha256(campaign.SAVE_PATH)
	var writer: RefCounted=Transaction.new()
	var opened: Dictionary=writer.begin_write(_request())
	if not check(opened.ok,label+" owned transaction opens"): return
	opened.cfg.set_value("unsafe","value",value)
	check(not Values.supported(value) and not Values.semantics(opened.cfg).ok,label+" current value guard rejects before encoder")
	var result: Dictionary=writer.commit_prepared(opened.cfg)
	check(not result.ok and result.code=="CAMPAIGN_CFG_UNSUPPORTED_VALUE" and not writer.busy(),label+" actual transaction refuses and releases unprepared",result)
	check(FileAccess.get_sha256(campaign.SAVE_PATH)==prior_sha,label+" original CFG unchanged")

func _unsupported() -> void:
	_begin(IDS[4])
	var scripted: Array[ScriptTypedFixture]=[]
	var object_array: Array[Node]=[]
	var object_dict: Dictionary[String,Node]={}
	var object:=RefCounted.new()
	var values: Array=[object,RID(),Callable(self,"check"),process_frame,scripted,object_array,object_dict]
	for index in range(values.size()): _refuse(values[index],"unsupported original value "+str(index))
	check(scripted.is_empty() and object_array.is_empty() and object_dict.is_empty() and is_instance_valid(object),"unsupported fixture inputs remain intact")
	_end()

func _depth_cycle() -> void:
	_begin(IDS[5])
	var allowed: Variant=1
	for _depth in range(128): allowed=[allowed]
	check(Values.supported(allowed),"root depth0 scalar leaf at128 allowed")
	var too_deep: Variant=[allowed]
	_refuse(too_deep,"scalar leaf depth129")
	var key_boundary: Dictionary={"leaf":1}
	for _depth in range(127): key_boundary={"next":key_boundary}
	check(Values.supported(key_boundary),"dictionary key scalar leaf at128 allowed")
	var key_too_deep: Dictionary={"next":key_boundary}
	_refuse(key_too_deep,"dictionary key scalar leaf depth129")
	var cycle: Array=[];cycle.append(cycle)
	_refuse(cycle,"alias cycle")
	check(cycle.size()==1 and is_same(cycle[0],cycle),"cycle refusal leaves original alias intact")
	cycle.clear()
	_end()

func _run() -> void:
	output=OS.get_environment("CAMPAIGN_DATA19_OUTPUT");nonce=OS.get_environment("CAMPAIGN_DATA19_NONCE")
	var profile: String=OS.get_environment("CAMPAIGN_DATA19_PROFILE").replace("\\","/").simplify_path().trim_suffix("/")
	if not output.is_absolute_path() or nonce.length()!=32 or not profile.is_absolute_path() or OS.get_environment("STEAM_DISABLED")!="1" or not OS.get_environment("CAMPAIGN_QA").is_empty(): quit(2);return
	for key in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		if OS.get_environment(key).replace("\\","/").simplify_path().to_lower()!=profile.path_join(key.to_lower()).to_lower(): quit(2);return
	if not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(profile.path_join("appdata").to_lower()+"/"): quit(2);return
	check(Engine.time_scale==1.0 and Engine.physics_ticks_per_second==60,"normal clock")
	if not check(change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))==OK,"actual configured menu opens"): _finish();return
	for frame in range(180): await process_frame
	while Engine.is_in_physics_frame(): await process_frame
	var provider: Script=load("res://scripts/run_content_identity.gd")
	Intent=load("res://scripts/run_campaign_progress_intent.gd");ProgressProjection=load("res://scripts/run_campaign_progress_projection.gd")
	Values=load("res://scripts/run_campaign_cfg_values.gd");Transaction=load("res://scripts/run_campaign_cfg_transaction.gd")
	identity=provider.new().resolve_runtime_identity();campaign=root.get_node("Campaign")
	var identity_path: String=OS.get_environment("CAMPAIGN_DATA19_IDENTITY_FILE")
	var controlled: Variant=JSON.parse_string(FileAccess.get_file_as_string(identity_path)) if FileAccess.file_exists(identity_path) else null
	if not check(controlled is Dictionary and FileAccess.get_sha256(identity_path)==OS.get_environment("CAMPAIGN_DATA19_IDENTITY_SHA256"),"controller immutable post cold identity readable"): _finish();return
	for field in controlled.runtime_fields:
		check(identity.get(field)==controlled.runtime_fields[field],"complete installed identity field "+field)
	var flow:=root.get_node("ContinueFlow")
	if not check(identity.get("save_eligible",false) and flow.phase==flow.Phase.IDLE and flow.last_result.get("startup_checked",false),"current installed identity and actual startup eligible"): _finish();return
	expected=Intent.scope({"mode":"campaign","level_id":"level8","waves":0},identity,campaign.cloud_owner)
	if not check(expected.ok,"current trusted pure data context scope"): _finish();return
	original_memory=_memory()
	_new_cfg()
	if failures.is_empty(): _best_single_run()
	if failures.is_empty(): _invalid()
	if failures.is_empty(): _legal_unknown()
	if failures.is_empty(): _unsupported()
	if failures.is_empty(): _depth_cycle()
	final_cfg_evidence=_cfg_evidence("final")
	check(cases.size()==IDS.size(),"all six original data case IDs executed")
	_finish()

func _finish() -> void:
	var path: String=output.path_join("report.json")
	if FileAccess.file_exists(path): quit(2);return
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: quit(2);return
	var report: Dictionary={"schema":"campaign_original19_data_layers_v3","passed":failures.is_empty(),"cases":cases,"checks":checks,"failures":failures,
		"pid":OS.get_process_id(),"nonce":nonce,"identity":identity,"actual_user_directory":OS.get_user_data_dir(),"time_scale":Engine.time_scale,"physics_ticks":Engine.physics_ticks_per_second,
		"scope":"six pure current projection/CFG/Variant data layers only; fixtures are not a live Battle result","invalid_refusals":invalid_refusals,"trusted_scope":expected,"commits":commits,"original_unknown_expectation":original_unknown_expectation,"final_CFG":final_cfg_evidence,
		"natural_battle_qualified":false,"original19_qualified":false,"UI_qualified":false,"SDK_reward_once_qualified":false,"overall_goal_qualified":false}
	file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
	print("CAMPAIGN_ORIGINAL19_DATA_LAYERS ",report.passed," ",cases.size()," ",checks.size())
	quit(0 if report.passed else 1)
