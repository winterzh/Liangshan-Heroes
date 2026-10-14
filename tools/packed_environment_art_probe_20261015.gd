extends SceneTree
const EnvironmentArt := preload("res://scripts/campaign_environment_art.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var output := OS.get_environment("PACKED_ART_OUT")
	if output.is_empty(): quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	var inputs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://probe_inputs.json"))
	var rows: Array = []
	var all_loaded := true
	var all_calibrated := true
	for source in inputs.variants:
		var path: String = "res://"+source.path
		var resolver: String = source.get("resolver","object")
		var level: String = source.get("level_id","level7")
		var tex = EnvironmentArt.object(level,source.key) if resolver=="object" else EnvironmentArt.static_flag(level,source.key)
		var row := {"key":source.key,"resolver":resolver,"level_id":level,"raw_png_available":FileAccess.file_exists(path),"source_sha256":FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "","loaded":tex!=null,"visual_metrics":EnvironmentArt.calibrated_visual_metrics(resolver,level,source.key),"text_rect":null,"imported_pixel_sha256":""}
		if tex!=null:
			var pixels: Image = tex.get_image()
			pixels.convert(Image.FORMAT_RGBA8)
			var digest := HashingContext.new()
			digest.start(HashingContext.HASH_SHA256);digest.update(pixels.get_data())
			row.imported_pixel_sha256=digest.finish().hex_encode()
			row["size"]=[pixels.get_width(),pixels.get_height()]
			row["resource_path"]=tex.resource_path
		if source.has("text_surface"):
			row.text_rect=EnvironmentArt.calibrated_text_rect(resolver,level,source.key,"default",source.text_surface)
		all_loaded=all_loaded and row.loaded
		all_calibrated=all_calibrated and not row.visual_metrics.is_empty() and (not source.has("text_surface") or row.text_rect!=null)
		rows.append(row)
	var guards: Array = []
	var resolver_script: GDScript = load("res://scripts/campaign_environment_art.gd")
	if resolver_script.get_script_constant_map().has("PNG_TEXTURE_CALIBRATIONS"):
		var a: Dictionary = inputs.variants[0]
		var b: Dictionary = inputs.variants[1]
		var a_path: String = "res://"+a.path
		var original_a = EnvironmentArt.object(a.level_id,a.key)
		var alternate_b = EnvironmentArt.object(b.level_id,b.key)
		guards.append({"name":"wrong_level_rejected","passed":EnvironmentArt.calibrated_visual_metrics(a.resolver,"skirmish",a.key).is_empty()})
		guards.append({"name":"wrong_state_rejected","passed":EnvironmentArt.calibrated_visual_metrics(a.resolver,a.level_id,a.key,"unknown").is_empty()})
		alternate_b.take_over_path(a_path)
		guards.append({"name":"wrong_real_imported_texture_rejected","passed":EnvironmentArt.calibrated_visual_metrics(a.resolver,a.level_id,a.key).is_empty() and EnvironmentArt.calibrated_text_rect(a.resolver,a.level_id,a.key,"default",a.text_surface)==null})
		original_a.take_over_path(a_path)
		guards.append({"name":"original_texture_restored","passed":not EnvironmentArt.calibrated_visual_metrics(a.resolver,a.level_id,a.key).is_empty()})
		if FileAccess.file_exists(a_path):
			var original_bytes := FileAccess.get_file_as_bytes(a_path)
			var changed := original_bytes.duplicate()
			changed[changed.size()-1] = changed[changed.size()-1]^1
			var writer := FileAccess.open(a_path,FileAccess.WRITE)
			writer.store_buffer(changed);writer.close()
			guards.append({"name":"changed_raw_bytes_rejected_even_with_cached_pixels","passed":EnvironmentArt.calibrated_visual_metrics(a.resolver,a.level_id,a.key).is_empty()})
			writer=FileAccess.open(a_path,FileAccess.WRITE)
			writer.store_buffer(original_bytes);writer.close()
			guards.append({"name":"original_raw_bytes_restored","passed":FileAccess.get_file_as_bytes(a_path)==original_bytes and not EnvironmentArt.calibrated_visual_metrics(a.resolver,a.level_id,a.key).is_empty()})
	var guards_passed := true
	for guard in guards: guards_passed=guards_passed and guard.passed
	var report := {"all_loaded":all_loaded,"all_calibrated":all_calibrated,"rows":rows,"guards":guards,"guards_passed":guards_passed,"executable":OS.get_executable_path(),"scope":"Current source-bound PNG visual/text calibrations in a minimal genuine Godot PCK; no full game/SDK/release acceptance."}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("PACKED_ART_OBSERVATION loaded=",all_loaded," calibrated=",all_calibrated)
	quit(0 if all_loaded and guards_passed else 1)
