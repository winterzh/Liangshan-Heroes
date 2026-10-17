extends SceneTree
const GroundCart=preload("res://scripts/campaign_tribute_cart_visual.gd")
const CampaignArt=preload("res://scripts/campaign_art.gd")
class WalkProbe extends Node:
	var actor
	var frames: Array=[]
	var seen: Array=[]
	var captured:=false
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(actor):return
		var art=get_tree().root.get_node("Art")
		var index: int=frames.find(actor._anim_frame_for_state(art.unit_texture(actor.key,actor.visual_art_variant(),actor.animation_direction)))
		if index>=0 and not seen.has(index):seen.append(index)
		if seen.size()==4:captured=true;actor.set_physics_process(false)
var out:=""
var checks: Array=[]
var failures: Array=[]
var shots: Array=[]
var observations: Array=[]
var art
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failures.append(label)
func settle() -> void:
	for i in range(4):await process_frame
func snap(label: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	var path:=out.path_join(label+".png")
	check(root.get_texture().get_image().save_png(path)==OK,"capture "+label)
	shots.append({"path":label+".png","sha256":FileAccess.get_sha256(path),"size":[root.size.x,root.size.y]})
func freeze(b) -> void:
	for u in b.units:u.set_physics_process(false)
	b.set_process(false);b.set_physics_process(false);b.camera.set_process(false);b.camera.set_physics_process(false);b.camera.position_smoothing_enabled=false;b.camera.zoom=Vector2.ONE*2.8
func stage_camera(b,u) -> void:
	b.camera.position=b.to_screen(u.position)+Vector2(0,-22);b.camera.force_update_scroll()
func clear_cell(b) -> Vector2i:
	for x in range(8,b.map.w-8):
		for y in range(8,b.map.h-8):
			var cell:=Vector2i(x,y);var valid:=true
			for dx in range(-3,4):
				for dy in range(-3,4):
					if not b.map.is_open_world(b.map.cell_to_world(cell+Vector2i(dx,dy))) or b.map.t_at(x+dx,y+dy) in [b.map.T.FOREST,b.map.T.REEDS,b.map.T.MARSH]:valid=false
			if valid:
				var p: Vector2=b.map.cell_to_world(cell)
				if b.map.decor.any(func(row):return b.map.cell_to_world(row[1]).distance_to(p)<maxf(220.0,float(row[2]))):continue
				if not b.units.any(func(u):return is_instance_valid(u) and u.position.distance_to(p)<180):return cell
	return Vector2i(-1,-1)
func frame(u) -> Texture2D:
	return u._anim_frame_for_state(art.unit_texture(u.key,u.visual_art_variant(),u.animation_direction))
func native_textures() -> void:
	var refs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_TEXTURE_REFERENCE")))
	check(refs.size()==JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_PACK_INPUTS"))).textures.size(),"all declared Chao/cart/Liu/Bai native textures referenced")
	for path in refs:
		check(not FileAccess.file_exists("res://"+String(path)),"PNG absent in full PCK "+path)
		var texture: Texture2D=load("res://"+String(path));check(texture!=null,"PCK texture loads "+path)
		if texture==null:continue
		var image:=texture.get_image()
		if image.is_compressed():check(image.decompress()==OK,"decompress "+path)
		var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(image.get_data())
		check(digest.finish().hex_encode()==String(refs[path].data_sha256),"native pixels and mipmaps exact "+path)
		check(image.get_width()==int(refs[path].size[0]) and image.get_height()==int(refs[path].size[1]),"native texture dimensions "+path)
func take(b,u,index: int) -> void:
	var action_id:="force_take_%d_%d"%[index,int(b.level.force_attempts.get(index,0))]
	u.order_stop();u.position=b.map.cell_to_world(b.level._bundle_claim_cell(b,index));b.select_single(u,false)
	check(b.mission.request_action(action_id),"original mission accepts pickup "+str(index))
	b.mission.tick(1.0);u.set_physics_process(false)
	check(b.level.cargo.get(index)==u and u.get_meta("carrying_tribute",-1)==index and b.mission.actions[action_id].done,"original callback assigns real cargo "+str(index))
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
