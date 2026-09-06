extends SceneTree
## Render the same live Unit silhouette through differently padded AtlasTextures.
var frame_unit_script: GDScript

var checks: Array=[]
var output: String="res://.godot/directional_frame_scale"
func check(name: String, ok: bool) -> void:
	checks.append({"name":name,"passed":ok})
	print("[frame-scale] ","PASS " if ok else "FAIL ",name)
func _initialize() -> void: _run.call_deferred()

func _capture(frame: Texture2D) -> Image:
	var viewport=SubViewport.new()
	viewport.size=Vector2i(320,320)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world=Node2D.new()
	world.transform=load("res://scripts/game_map.gd").ISO.scaled(Vector2.ONE*4.0)
	viewport.add_child(world)
	var u=frame_unit_script.new()
	u.fixture_frame=frame
	u.radius=13.0
	u.process_mode=Node.PROCESS_MODE_DISABLED
	u.position=world.transform.affine_inverse()*Vector2(160,260)
	world.add_child(u)
	u.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var result=viewport.get_texture().get_image()
	viewport.queue_free()
	await process_frame
	return result

func _run() -> void:
	# Compile Unit only after the project autoloads exist.
	frame_unit_script=GDScript.new()
	frame_unit_script.source_code='extends "res://scripts/unit.gd"\nvar fixture_frame: Texture2D\nfunc _anim_frame_for_state(_tex: Texture2D) -> Texture2D:\n\t_real_frames=true\n\t_frame_directional=true\n\treturn fixture_frame\nfunc _draw() -> void:\n\t_draw_sprite_animated(fixture_frame,Color.WHITE,0.0)\n'
	if frame_unit_script.reload()!=OK:
		quit(1)
		return
	var custom=OS.get_environment("FRAME_SCALE_OUT")
	if not custom.is_empty(): output=custom
	DirAccess.make_dir_recursive_absolute(output)
	var art=root.get_node("Art")
	var baseline: AtlasTexture=art.unit_anim_frames("lin_chong","idle","se")[0]
	var expanded: AtlasTexture=baseline.duplicate()
	var width: float=baseline.get_width()
	expanded.margin.position+=Vector2.ONE*width*0.5
	expanded.margin.size+=Vector2.ONE*width
	expanded.set_meta("draw_offset_px",baseline.get_meta("draw_offset_px")+Vector2(0,width*0.32))
	var corrected: AtlasTexture=expanded.duplicate()
	corrected.set_meta("draw_scale",2.0)
	var probe=frame_unit_script.new()
	check("legacy frame defaults to original size",probe._frame_draw_scale(baseline)==1.0)
	check("null frame defaults to original size",probe._frame_draw_scale(null)==1.0)
	check("expanded authored frame reports its declared size",probe._frame_draw_scale(corrected)==2.0)
	for value in ["2",0.0,-1.0,0.2,4.1,INF,NAN]:
		var invalid: AtlasTexture=expanded.duplicate()
		invalid.set_meta("draw_scale",value)
		check("invalid direct frame scale falls back safely "+str(value),probe._frame_draw_scale(invalid)==1.0)
	probe.free()
	for value in [0.25,1.0,2.0,4.0,0.0,0.2,4.1,"2"]:
		var test_frame: AtlasTexture=expanded.duplicate()
		test_frame.set_meta("draw_scale",value)
		var sf=SpriteFrames.new()
		sf.add_frame(&"default",test_frame)
		var path=output+"/fixture_"+str(checks.size())+".tres"
		check("save scale decoding fixture "+str(value),ResourceSaver.save(sf,path)==OK)
		var accepted: bool=(value is float or value is int) and float(value)>=0.25 and float(value)<=4.0
		check("resource decoder validates scale "+str(value),not art._load_generic_directional_frames(path).is_empty()==accepted)
	var visual=DisplayServer.get_name()!="headless"
	var pixels={}
	if visual:
		var original=await _capture(baseline)
		var uncorrected=await _capture(expanded)
		var restored=await _capture(corrected)
		var a=original.get_data();var b=restored.get_data()
		var max_error:=0;var changed:=0
		for i in range(a.size()):
			var error=absi(int(a[i])-int(b[i]))
			max_error=maxi(max_error,error)
			if error>0:changed+=1
		check("fixture contains an actual rendered Unit",original.get_used_rect().get_area()>5000)
		check("uncorrected padding reproduces body shrink",uncorrected.get_used_rect().get_area()<original.get_used_rect().get_area()*0.4)
		check("authored scale restores the original Unit bounds",restored.get_used_rect()==original.get_used_rect())
		check("authored scale restores real sprite pixels within one channel level",max_error<=1)
		pixels={"baseline_bounds":str(original.get_used_rect()),"uncorrected_bounds":str(uncorrected.get_used_rect()),"restored_bounds":str(restored.get_used_rect()),"max_channel_error":max_error,"changed_channels":changed}
		check("render comparisons saved",original.save_png(output+"/original.png")==OK and uncorrected.save_png(output+"/uncorrected.png")==OK and restored.save_png(output+"/restored.png")==OK)
	var passed=checks.all(func(c):return c.passed)
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":passed,"visual":visual,"pixels":pixels},"\t")+"\n")
	quit(0 if passed else 1)
