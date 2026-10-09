extends SceneTree
## Read-only audit equivalence and cost benchmark, never a matrix qualification.
var checks: Array=[]
var failures: Array=[]
var observations: Array=[]
var output: String=""
var nonce: String=""
var old: Node
var fresh: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String, detail: Variant=null) -> bool:
	checks.append({"label":label,"ok":ok,"detail":detail})
	if not ok: failures.append(label)
	return ok

func _compare(value: Variant, label: String) -> void:
	fresh.audit_leaf_cache.clear()
	check(fresh.audit_leaf_cache.is_empty(),"cold scalar cache initially empty "+label)
	var started: int=Time.get_ticks_usec()
	var original: String=JSON.stringify(old._typed(value))
	var old_us: int=Time.get_ticks_usec()-started
	started=Time.get_ticks_usec()
	var candidate: String=JSON.stringify(fresh._typed(value))
	var cold_us: int=Time.get_ticks_usec()-started
	started=Time.get_ticks_usec()
	var repeated: String=JSON.stringify(fresh._typed(value))
	var warm_us: int=Time.get_ticks_usec()-started
	check(original==candidate and original==repeated,"exact complete typed audit bytes "+label)
	check(old._fingerprint(value)==fresh._fingerprint(value) and original.sha256_text()==old._fingerprint(value),"original IEEE typed fingerprint unchanged "+label)
	check(fresh.audit_leaf_cache.size()<=8192,"bounded scalar cache "+label)
	var full_audit: Dictionary={"input":JSON.parse_string(original),"type_ieee_sha256":original.sha256_text()}
	started=Time.get_ticks_usec()
	var pretty: String=JSON.stringify(full_audit,"\t")+"\n"
	var pretty_us: int=Time.get_ticks_usec()-started
	started=Time.get_ticks_usec()
	var compact: String=JSON.stringify(full_audit)+"\n"
	var compact_us: int=Time.get_ticks_usec()-started
	check(JSON.parse_string(pretty)==JSON.parse_string(compact),"pretty and compact preserve all audit data "+label)
	observations.append({"label":label,"old_us":old_us,"candidate_cold_us":cold_us,"candidate_warm_us":warm_us,"canonical_bytes":original.to_utf8_buffer().size(),"pretty_bytes":pretty.to_utf8_buffer().size(),"compact_bytes":compact.to_utf8_buffer().size(),"pretty_serialize_us":pretty_us,"compact_serialize_us":compact_us,"sha256":original.sha256_text()})

func _run() -> void:
	output=OS.get_environment("AUDIT_BENCH_OUTPUT");nonce=OS.get_environment("AUDIT_BENCH_NONCE")
	var profile: String=OS.get_environment("AUDIT_BENCH_PROFILE").replace("\\","/").simplify_path().trim_suffix("/")
	if not output.is_absolute_path() or nonce.length()!=32 or not profile.is_absolute_path() or OS.get_environment("STEAM_DISABLED")!="1" or not OS.get_environment("CAMPAIGN_QA").is_empty(): quit(2);return
	for key in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		if OS.get_environment(key).replace("\\","/").simplify_path().to_lower()!=profile.path_join(key.to_lower()).to_lower(): quit(2);return
	check(Engine.time_scale==1.0 and Engine.physics_ticks_per_second==60,"normal simulation clock")
	if not check(change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))==OK,"configured menu initializes real autoloads"): _finish();return
	for frame in range(180): await process_frame
	while Engine.is_in_physics_frame(): await process_frame
	var original_script: Script=load("res://tools/audit_original_r5.gd")
	var candidate_script: Script=load("res://tools/audit_candidate_r6.gd")
	old=original_script.new();fresh=candidate_script.new()
	# These two audit Nodes are not added to the tree or given any gameplay state.
	var codec: Script=load("res://scripts/run_state_value_codec.gd")
	old.Codec=codec;fresh.Codec=codec
	var values: Array=[null,true,false,0,-1,9223372036854775807,-9223372036854775807,0.0,-0.0,INF,-INF,NAN,"","a:b","汉字",&"a:b",Vector2(1.25,-0.0),Vector2i(-1,2),Rect2(Vector2(-0.0,INF),Vector2(3,4)),Color(0.1,0.2,0.3,0.4),PackedFloat32Array([0.0,-0.0,INF,NAN])]
	_compare(values,"supported_scalar_IEEE_and_builtin_fixture")
	var mutable: Dictionary={"key":1,"nested":[true,1.0,"text"]}
	_compare(mutable,"mutable_before")
	mutable.key=2;mutable.nested[1]=-0.0
	_compare(mutable,"mutable_after")
	check(JSON.stringify(old._typed(mutable))!=JSON.stringify(old._typed({"key":1,"nested":[true,1.0,"text"]})),"container mutation never hidden by scalar cache")
	_compare(["a".repeat(256),"a".repeat(257),StringName("b".repeat(256)),StringName("b".repeat(257))],"text_256_257_boundary")
	check(fresh.audit_leaf_cache.has(str(TYPE_STRING)+":"+"a".repeat(256)) and not fresh.audit_leaf_cache.has(str(TYPE_STRING)+":"+"a".repeat(257)),"text boundary eligible and ineligible cache paths")
	var saturated: Array=[]
	for index in range(9000): saturated.append(index)
	_compare(saturated,"unique_scalar_9000_cache_saturation")
	check(fresh.audit_leaf_cache.size()==8192 and not fresh.audit_leaf_cache.has(str(TYPE_INT)+":8999"),"cache reaches exact8192 and preserves uncached miss path")
	var shared: Array=[1,{"value":2}]
	var aliases: Dictionary={"left":shared,"right":shared}
	_compare(aliases,"shared_container_before")
	shared[1].value=3
	_compare(aliases,"shared_container_after")
	check(is_same(aliases.left,aliases.right) and aliases.left[1].value==3 and JSON.stringify(old._typed(aliases))!=JSON.stringify(old._typed({"left":[1,{"value":2}],"right":[1,{"value":2}]})),"shared container alias mutation preserved without caching container")
	var fixture_path: String=OS.get_environment("AUDIT_BENCH_PACKET")
	if not check(FileAccess.file_exists(fixture_path) and FileAccess.get_sha256(fixture_path)==OS.get_environment("AUDIT_BENCH_PACKET_SHA256"),"original closed A packet read-only exact bytes"): _finish();return
	var packet: Variant=JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	if not check(packet is Dictionary and packet.world.sections is Dictionary,"original packet sections readable"): _finish();return
	for section in packet.world.sections:
		_compare(packet.world.sections[section],"actual_complete_section_"+section)
	var decoded_units: Dictionary={}
	for record in packet.world.sections.units.records:
		var opened: Dictionary=codec.new().decode(record.payload)
		if not check(opened.ok,"real complete original Unit codec "+str(record.entity_id)): _finish();return
		decoded_units[str(record.entity_id)]=opened.value
	_compare(decoded_units,"actual_complete_decoded_Units")
	var decoded_level: Dictionary=codec.new().decode(packet.world.sections.level.payload)
	if not check(decoded_level.ok,"real complete original Level codec"): _finish();return
	_compare(decoded_level.value,"actual_complete_decoded_Level")
	check(FileAccess.get_sha256(fixture_path)==OS.get_environment("AUDIT_BENCH_PACKET_SHA256"),"original packet bytes unchanged after complete audit")
	_finish()

func _finish() -> void:
	if is_instance_valid(old): old.free()
	if is_instance_valid(fresh): fresh.free()
	var path: String=output.path_join("report.json")
	if FileAccess.file_exists(path): quit(2);return
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: quit(2);return
	var report: Dictionary={"schema":"component_audit_benchmark_v2","pid":OS.get_process_id(),"nonce":nonce,"passed":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"time_scale":Engine.time_scale,"physics_ticks":Engine.physics_ticks_per_second,"actual_user_directory":OS.get_user_data_dir(),"scope":"read-only exact old/new typed representation and IEEE fingerprint CPU/serialization benchmark; old A is data only","physical_write_cost_measured":false,"matrix_runtime_speedup_qualified":false,"component_matrix_qualified":false,"full_chain_qualified":false,"SDK_qualified":false,"overall_goal_qualified":false}
	file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
	print("COMPONENT_AUDIT_BENCHMARK ",report.passed," ",checks.size())
	quit(0 if report.passed else 1)
