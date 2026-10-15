extends SceneTree
var checks: Array=[]
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failures.append(label)
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var out:=OS.get_environment("SHI_EN_IMPORT_OUT")
	if out.is_empty() or OS.get_environment("STEAM_DISABLED")!="1":quit(2);return
	var plan_path:="res://qa/shi_en_full_actions_20261015/runtime_plan.json"
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(plan_path))
	var rows: Dictionary={}
	for key in plan.sources:
		var row: Dictionary=plan.sources[key]
		var path: String="res://"+String(row.path)
		check(FileAccess.get_sha256(path)==String(row.sha256),"native PNG bytes "+key)
		var texture: Texture2D=load(path)
		check(texture!=null,"actual imported texture "+key)
		if texture==null:continue
		var actual: Array=[texture.get_width(),texture.get_height()]
		check(float(actual[0])==float(row.native_size[0]) and float(actual[1])==float(row.native_size[1]),"actual native dimensions "+key)
		var image:=texture.get_image()
		check(image!=null,"actual imported image "+key)
		if image!=null:
			if image.is_compressed():check(image.decompress()==OK,"texture decompression "+key)
			var zero: Array=row.transparent_probe_xy
			check(image.get_pixel(int(zero[0]),int(zero[1])).a==0.0,"source-proven transparent pixel "+key)
			var corners: Array=[Vector2i.ZERO,Vector2i(image.get_width()-1,0),Vector2i(0,image.get_height()-1),Vector2i(image.get_width()-1,image.get_height()-1)]
			for i in range(4):check(roundi(image.get_pixelv(corners[i]).a*255.0)==int(row.native_corner_alphas[i]),"original alpha byte retained "+key+str(i))
		rows[key]={"sha256":FileAccess.get_sha256(path),"imported_size":actual}
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"sources":rows,
		"plan_sha256":FileAccess.get_sha256(plan_path),"candidate_source_manifest_sha256":plan.candidate_source_manifest_sha256,
		"scope":"Actual private Godot import source bytes/dimensions/transparency; no scene or action acceptance."}
	FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("SHI_EN_NATIVE_IMPORT ",checks.size()," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
