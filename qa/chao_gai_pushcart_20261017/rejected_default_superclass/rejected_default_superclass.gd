extends "res://tools/chao_gai_pushcart_20261017.gd"
var default_zoom:=Vector2.ONE
func run() -> void:
	out=OS.get_environment("SHI_EN_ART_OUT")
	if out.is_empty() or OS.get_environment("STEAM_DISABLED")!="1":quit(2);return
	DirAccess.make_dir_recursive_absolute(out);root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true);art=root.get_node("Art");root.get_node("Settings").edge_scroll=false;root.get_node("Settings").auto_micro_level=0
	var campaign=root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","custom_defense","scenario","scale_on","ai_friendly"]:campaign.set(mode,false)
	campaign.current=0;seed(5088120)
	var b=load("res://scenes/main.tscn").instantiate();root.add_child(b);current_scene=b;await process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame
	default_zoom=b.camera.zoom;freeze(b);b.fog=false
	check(b._gameplay_rng_issue.is_empty(),"default-zoom original game RNG")
	var u=b.find_unit("chao_gai");check(is_instance_valid(u),"real Chao actor at natural camera zoom")
	b.level.st=b.level.CARRY;b.level.drug_done=true;b.level._begin_cargo_choice(b);await take(b,u,0)
	var cell:=clear_cell(b);check(cell!=Vector2i(-1,-1),"open natural-zoom sample site")
	u.position=b.map.cell_to_world(cell);u.order_stop();u.auto_micro=false
	b.camera.zoom=default_zoom;stage_camera(b,u)
	for d in ["se","sw","ne","nw"]:
		u.animation_direction=d;u.face_left=d in ["sw","nw"]
		for state in ["push_idle","push_walk"]:
			var fs: Array=art.unit_anim_frames(u.key,state,d,u.art_variant)
			for i in range(fs.size()):
				u._move_blend=1.0 if state=="push_walk" else 0.0;u._anim_t=TAU*(float(i)+.1)/float(fs.size());u._idle_t=0
				check(frame(u)==fs[i] and u._frame_directional,"natural zoom true authored pose "+state+d+str(i))
				u.queue_redraw();await snap("default_"+state+"_"+d+"_"+str(i))
	b.camera.zoom=Vector2.ONE*1.6;stage_camera(b,u)
	for d in ["se","sw","ne","nw"]:
		u.animation_direction=d;u.face_left=d in ["sw","nw"];u._move_blend=1.0;u._anim_t=TAU*3.1/4.0;u.queue_redraw();await snap("medium_passing_b_"+d)
	u.remove_meta("carrying_tribute");u._move_blend=0;u.animation_direction="se";u.queue_redraw();b.camera.zoom=default_zoom;stage_camera(b,u)
	check(not u._campaign_tribute_push_active(),"metadata-only visual fixture returns to own original body")
	await snap("default_unloaded_body")
	finish()
func finish() -> void:
	var result:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":shots,"startup_camera_zoom":[default_zoom.x,default_zoom.y],
		"scope":"Same unchanged qualified Chao PCK. Natural startup zoom all20 authored idle/gait views, plus1.6x passing-B four directions and unloaded body. Actual pickup callback with explicit CARRY/drug/sample/freeze/fog fixtures; final unloaded state is a metadata-only visual fixture, not another delivery. No full UI or performance qualification."}
	var f:=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close();quit(0 if failures.is_empty() else 1)
