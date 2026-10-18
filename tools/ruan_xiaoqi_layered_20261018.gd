extends Node
const GroundCart=preload("res://scripts/campaign_tribute_cart_visual.gd")
const CampaignArt=preload("res://scripts/campaign_art.gd")
class WalkProbe extends Node:
	var actor
	var frames: Array=[]
	var seen: Array=[]
	var captured:=false
	var wheel_last_angle:=0.0
	var wheel_angular_distance:=0.0
	func _physics_process(_delta: float) -> void:
		if captured or not is_instance_valid(actor):return
		wheel_angular_distance+=fposmod(float(actor._tribute_wheel_angle)-wheel_last_angle,TAU);wheel_last_angle=actor._tribute_wheel_angle
		var art=get_tree().root.get_node("Art")
		var index: int=frames.find(actor._anim_frame_for_state(art.unit_texture(actor.key,actor.visual_art_variant(),actor.animation_direction)))
		if index>=0 and not seen.has(index):seen.append(index)
		if seen.size()==4:captured=true;actor.set_physics_process(false)
var out:=""
var checks: Array=[]
var failures: Array=[]
var shots: Array=[]
var observations: Array=[]
var startup_zoom:=Vector2.ONE
var art
var root: Window:
	get:return get_tree().root
func _ready() -> void:run.call_deferred()
func quit(code: int=0) -> void:get_tree().quit(code)
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failures.append(label)
func settle() -> void:
	for i in range(4):await get_tree().process_frame
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
	check(refs.size()==JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_PACK_INPUTS"))).textures.size(),"all declared carrier/cart native textures referenced")
	for path in refs:
		check(not FileAccess.file_exists("res://"+String(path)),"PNG absent in mounted base+patch PCK "+path)
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
func run() -> void:
	out=OS.get_environment("SHI_EN_ART_OUT")
	if out.is_empty() or OS.get_environment("STEAM_DISABLED")!="1":quit(2);return
	DirAccess.make_dir_recursive_absolute(out);root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true);art=root.get_node("Art");root.get_node("Settings").edge_scroll=false;root.get_node("Settings").auto_micro_level=0
	native_textures()
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_PACK_INPUTS"))).manifest
	for d in ["se","sw","ne","nw"]:
		for state in ["push_idle","push_walk","parked_cart"]:
			var fs: Array=art.unit_anim_frames("ruan_xiaoqi",state,d,"hn_ruan_xiaoqi")
			check(fs.size()==(4 if state=="push_walk" else 1),"dedicated cart frame count "+state+d)
			check(art.campaign_variant_has_animation("hn_ruan_xiaoqi",state,d) and art.unit_anim_uses_directional_source("ruan_xiaoqi",state,d,"hn_ruan_xiaoqi"),"true directional cart route "+state+d)
		check(CampaignArt.native_tribute_push_path("bai_sheng","hn_ruan_xiaoqi","push_walk",d).is_empty(),"foreign owner rejected "+d)
		check(CampaignArt.native_tribute_push_path("ruan_xiaoqi","","push_walk",d).is_empty(),"ordinary identity rejects chapter cart "+d)
		check(CampaignArt.native_tribute_push_path("liu_tang","hn_ruan_xiaoqi","push_walk",d).is_empty() and CampaignArt.native_tribute_push_path("ruan_xiaoqi","hn_liu_tang","push_walk",d).is_empty(),"Ruan Xiaoqi and Liu cannot borrow each other's push identity "+d)
		check(art.unit_anim_frames("liu_tang","push_walk",d,"hn_liu_tang").size()==4 and art.unit_anim_frames("liu_tang","push_idle",d,"hn_liu_tang").size()==1,"retained Liu cart family "+d)
		check(art.unit_anim_frames("bai_sheng","carry_walk",d,"hn_bai_sheng").size()==4,"Bai wine gait remains separate "+d)
		check(art.unit_anim_frames("wu_yong","push_walk",d,"hn_wu_yong").size()==4 and art.unit_anim_frames("wu_yong","push_idle",d,"hn_wu_yong").size()==1,"retained Wu cart family "+d)
		check(CampaignArt.native_tribute_push_path("wu_yong","hn_ruan_xiaoqi","push_walk",d).is_empty() and CampaignArt.native_tribute_push_path("ruan_xiaoqi","hn_wu_yong","push_walk",d).is_empty(),"Ruan Xiaoqi and Wu cannot borrow push identities "+d)
		check(art.unit_anim_frames("chao_gai","push_walk",d,"hn_chao_gai").size()==4 and art.unit_anim_frames("chao_gai","push_idle",d,"hn_chao_gai").size()==1,"retained Chao cart family "+d)
		check(CampaignArt.native_tribute_push_path("ruan_xiaoqi","hn_chao_gai","push_walk",d).is_empty() and CampaignArt.native_tribute_push_path("chao_gai","hn_ruan_xiaoqi","push_walk",d).is_empty(),"Ruan Xiaoqi and Chao cannot borrow push identities "+d)
		check(art.unit_anim_frames("gongsun_sheng","push_walk",d,"hn_gongsun_sheng").size()==4 and art.unit_anim_frames("gongsun_sheng","push_idle",d,"hn_gongsun_sheng").size()==1,"retained Gongsun cart family "+d)
		check(art.unit_anim_frames("ruan_xiaoer","push_walk",d,"hn_ruan_xiaoer").size()==4 and art.unit_anim_frames("ruan_xiaoer","push_idle",d,"hn_ruan_xiaoer").size()==1,"retained Ruan Xiaoer cart family "+d)
		check(art.unit_anim_frames("ruan_xiaowu","push_walk",d,"hn_ruan_xiaowu").size()==4 and art.unit_anim_frames("ruan_xiaowu","push_idle",d,"hn_ruan_xiaowu").size()==1,"retained Ruan Xiaowu cart family "+d)
		for foreign in ["ruan_brother","ruan_xiaoer","ruan_xiaowu","gongsun_sheng"]:
			check(CampaignArt.native_tribute_push_path(foreign,"hn_ruan_xiaoqi","push_walk",d).is_empty() and CampaignArt.native_tribute_push_path("ruan_xiaoqi","hn_"+foreign,"push_walk",d).is_empty(),"Ruan Xiaoqi strict alias/other brother/body isolation "+foreign+d)
	check(CampaignArt.native_tribute_push_path("ruan_xiaoqi","hn_ruan_xiaoqi","death","se").is_empty() and CampaignArt.native_tribute_push_path("ruan_xiaoqi","hn_ruan_xiaoqi","push_walk","bad").is_empty(),"terminal and malformed paths reject cart body")
	var campaign=root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","custom_defense","scenario","scale_on","ai_friendly"]:campaign.set(mode,false)
	campaign.current=0;seed(5088120)
	var b=load("res://scenes/main.tscn").instantiate();root.add_child(b);get_tree().current_scene=b;await get_tree().process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await get_tree().process_frame;startup_zoom=b.camera.zoom;freeze(b);b.fog=false
	check(b.level.get_script().resource_path=="res://scripts/levels/level1_huangnigang_short.gd" and b._gameplay_rng_issue.is_empty(),"real current Huangnigang chapter and RNG")
	var u=b.find_unit("ruan_xiaoqi");check(is_instance_valid(u) and u.art_variant=="hn_ruan_xiaoqi","original Ruan Xiaoqi merchant actor")
	if not is_instance_valid(u):finish();return
	var old_idle: Array=art.unit_anim_frames(u.key,"idle","se",u.art_variant)
	var old_walk: Array=art.unit_anim_frames(u.key,"walk","se",u.art_variant)
	var portrait: Texture2D=u.ui_portrait_texture()
	var stats: Array=[u.max_hp,u.atk,u.atk_cd,u.base_speed,u.setup_def.abilities]
	var grid: Array=Array(b.map.grid).duplicate();var decor: Array=b.map.decor.duplicate(true)
	u.animation_direction="se"
	check(not u._campaign_tribute_push_active() and frame(u)==old_idle[0],"unloaded Ruan Xiaoqi keeps adopted merchant body")
	check(not load("res://scripts/tribute_cart_wheel_visual.gd").enabled(u),"unloaded actor does not draw rolling cart")
	var own_layer: Texture2D=art.unit_anim_frames(u.key,"push_idle","se",u.art_variant)[0]
	check(not u._campaign_tribute_layered_frame(own_layer),"unloaded actor rejects even its own layered frame")
	for bundle in b.level.bundles:
		check(not GroundCart.enabled(bundle) and bundle._campaign_environment_texture()!=art.campaign_tribute_cart_texture("se"),"original escort remains shoulder cargo before seizure "+str(b.level.bundles.find(bundle)))
	stage_camera(b,b.level.bundles[0]);await snap("original_escort_shoulder_load")
	b.level.drug_done=true
	for bundle in b.level.bundles:check(not GroundCart.enabled(bundle),"wine alone cannot change unclaimed escort load "+str(b.level.bundles.find(bundle)))
	var impostor=b.spawn_at("treasure_cart",1,Vector2i(12,12))
	impostor.art_variant=b.level.bundles[0].art_variant;impostor.remove_meta("campaign_environment_route");impostor.set_physics_process(false)
	check(not GroundCart.enabled(impostor),"same key and route cannot impersonate actual mission cargo")
	b.unregister_building_footprint(impostor);b.units.erase(impostor);impostor.queue_free();await get_tree().process_frame
	check(art.campaign_tribute_cart_texture("bad")==null,"ground prop rejects malformed direction")
	# Explicit post-drug/cargo-stage fixture, not a complete wine-sequence pass.
	b.level.st=b.level.CARRY;b.level.drug_done=true;b.level._begin_cargo_choice(b)
	await take(b,u,0);stage_camera(b,u);u._move_blend=0;await snap("original_pickup")
	check(u._campaign_tribute_push_active(),"real pickup enables only Ruan Xiaoqi loaded-cart art")
	check(u._campaign_tribute_layered_frame(frame(u)),"actual pickup opts into actor plus fixed cart")
	var retained_liu=b.find_unit("liu_tang")
	retained_liu.set_meta("carrying_tribute",2);retained_liu._move_blend=0;retained_liu.animation_direction="se"
	check(retained_liu._campaign_tribute_push_active() and frame(retained_liu)==art.unit_anim_frames("liu_tang","push_idle","se","hn_liu_tang")[0],"actual retained Liu still selects own loaded pose")
	check(not retained_liu._campaign_tribute_layered_frame(own_layer),"foreign actual carrier cannot request Ruan7 separate layer")
	retained_liu.remove_meta("carrying_tribute");retained_liu.queue_redraw();check(not retained_liu._campaign_tribute_push_active(),"retained Liu returns to ordinary merchant state")
	var retained_chao=b.find_unit("chao_gai")
	retained_chao.set_meta("carrying_tribute",2);retained_chao._move_blend=0;retained_chao.animation_direction="se"
	check(retained_chao._campaign_tribute_push_active() and frame(retained_chao)==art.unit_anim_frames("chao_gai","push_idle","se","hn_chao_gai")[0],"actual retained Chao selects own loaded pose")
	retained_chao.remove_meta("carrying_tribute");retained_chao.queue_redraw();check(not retained_chao._campaign_tribute_push_active(),"retained Chao returns to own merchant body")
	var retained_wu=b.find_unit("wu_yong")
	retained_wu.set_meta("carrying_tribute",2);retained_wu._move_blend=0;retained_wu.animation_direction="se"
	check(retained_wu._campaign_tribute_push_active() and frame(retained_wu)==art.unit_anim_frames("wu_yong","push_idle","se","hn_wu_yong")[0],"actual retained Wu selects own loaded pose")
	retained_wu.remove_meta("carrying_tribute");retained_wu.queue_redraw();check(not retained_wu._campaign_tribute_push_active(),"retained Wu returns to own merchant body")
	var retained_gongsun=b.find_unit("gongsun_sheng")
	retained_gongsun.set_meta("carrying_tribute",2);retained_gongsun._move_blend=0;retained_gongsun.animation_direction="se"
	check(retained_gongsun._campaign_tribute_push_active() and frame(retained_gongsun)==art.unit_anim_frames("gongsun_sheng","push_idle","se","hn_gongsun_sheng")[0],"actual retained Gongsun selects own loaded pose")
	retained_gongsun.remove_meta("carrying_tribute");retained_gongsun.queue_redraw();check(not retained_gongsun._campaign_tribute_push_active(),"retained Gongsun returns to own merchant body")
	var retained_xiaoer=b.find_unit("ruan_xiaoer")
	retained_xiaoer.set_meta("carrying_tribute",2);retained_xiaoer._move_blend=0;retained_xiaoer.animation_direction="se"
	check(retained_xiaoer._campaign_tribute_push_active() and frame(retained_xiaoer)==art.unit_anim_frames("ruan_xiaoer","push_idle","se","hn_ruan_xiaoer")[0],"actual retained Ruan Xiaoer selects own loaded pose")
	retained_xiaoer.remove_meta("carrying_tribute");retained_xiaoer.queue_redraw();check(not retained_xiaoer._campaign_tribute_push_active(),"retained Ruan Xiaoer returns to own merchant body")
	var retained_xiaowu=b.find_unit("ruan_xiaowu")
	retained_xiaowu.set_meta("carrying_tribute",2);retained_xiaowu._move_blend=0;retained_xiaowu.animation_direction="se"
	check(retained_xiaowu._campaign_tribute_push_active() and frame(retained_xiaowu)==art.unit_anim_frames("ruan_xiaowu","push_idle","se","hn_ruan_xiaowu")[0],"actual retained Ruan Xiaowu selects own loaded pose")
	retained_xiaowu.remove_meta("carrying_tribute");retained_xiaowu.queue_redraw();check(not retained_xiaowu._campaign_tribute_push_active(),"retained Ruan Xiaowu returns to own merchant body")
	var cell:=clear_cell(b);check(cell!=Vector2i(-1,-1),"open original scenery sample location")
	if cell==Vector2i(-1,-1):finish();return
	var origin: Vector2=b.map.cell_to_world(cell);u.position=origin;u.order_stop();u.auto_micro=false
	for size in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size;stage_camera(b,u)
		for d in ["se","sw","ne","nw"]:
			u.animation_direction=d;u.face_left=d in ["sw","nw"]
			for state in ["push_idle","push_walk"]:
				var fs: Array=art.unit_anim_frames(u.key,state,d,u.art_variant)
				for i in range(fs.size()):
					u._move_blend=1.0 if state=="push_walk" else 0.0;u._anim_t=TAU*(float(i)+.1)/float(fs.size());u._idle_t=0
					var pose: Dictionary=manifest.poses[String(manifest.states[state][i])+"_"+d]
					check(frame(u)==fs[i] and u._frame_directional and u._real_frames,"Unit selects authored cart body without mirror "+str(size.x)+state+d+str(i))
					check(fs[i].atlas.resource_path=="res://"+String(manifest.sources[pose.source].path) and fs[i].region==Rect2(pose.region[0],pose.region[1],pose.region[2],pose.region[3]),"exact cart source region "+str(size.x)+state+d+str(i))
					check(u._campaign_tribute_push_state()==state,"explicit loaded pose suppresses old shoulder cargo "+str(size.x)+state+d+str(i))
					check(u._campaign_tribute_layered_frame(fs[i]) and bool(fs[i].get_meta("independent_cart",false)),"own loaded body requests exactly one separate cart "+str(size.x)+state+d+str(i))
					var layer: AtlasTexture=art.unit_anim_frames(u.key,"parked_cart",d,u.art_variant)[0]
					var parked_pose: Dictionary=manifest.poses["cart_only_"+d]
					var wheel: Array=manifest.sources.cart_only.wheel_contacts[d]
					var rendered_offset: Vector2=(Vector2(wheel[0],wheel[1])-layer.region.position+layer.margin.position-Vector2(layer.get_width()*.5,layer.get_height()*.82))*float(layer.get_meta("draw_scale",1.0))/float(layer.get_width())
					var expected: Array=manifest.wheel_offsets_per_body_size[d]
					check(rendered_offset.distance_to(Vector2(expected[0],expected[1]))<.00001,"separate cart wheel contact fixed for every body phase "+str(size.x)+state+d+str(i))
					check(layer.atlas.resource_path=="res://"+String(manifest.sources.cart_only.path) and not bool(layer.get_meta("independent_cart",true)),"one unchanged cart source, no recursive cart layer "+str(size.x)+state+d+str(i))
					var depth: float=float(parked_pose.cart_depth_pixels)*float(layer.get_meta("draw_scale",1.0))/float(layer.get_width())
					check(absf(depth-float(parked_pose.cart_depth_pixels)/float(parked_pose.virtual_canvas_reference))<.00001,"separate cart retains rigid source depth "+str(size.x)+state+d+str(i))
					var actor_size: float=u.radius*3.7*u.visual_scale*float(fs[i].get_meta("draw_scale",1.0))
					var cart_size: float=u.radius*3.7*u.visual_scale*float(layer.get_meta("draw_scale",1.0))
					var visible_top: float=(float(fs[i].get_meta("visible_top",0.0))-.82)*actor_size+u._frame_draw_offset(fs[i],actor_size).y
					var cart_top: float=(float(layer.get_meta("visible_top",0.0))-.82)*cart_size+u._frame_draw_offset(layer,cart_size).y
					check(fs[i].has_meta("visible_top") and u._campaign_tribute_label_y(0.0)<minf(visible_top,cart_top),"loaded label clears both actor and independent cart "+str(size.x)+state+d+str(i))
					u.queue_redraw();await snap("cart_"+str(size.x)+"_"+state+"_"+d+"_"+str(i))
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	for row in [{"d":"se","delta":Vector2.RIGHT},{"d":"sw","delta":Vector2.DOWN},{"d":"ne","delta":Vector2.UP},{"d":"nw","delta":Vector2.LEFT}]:
		u.position=origin;u.order_stop();stage_camera(b,u)
		var probe:=WalkProbe.new();probe.actor=u;probe.wheel_last_angle=u._tribute_wheel_angle;probe.frames=art.unit_anim_frames(u.key,"push_walk",row.d,u.art_variant);probe.process_physics_priority=1000;root.add_child(probe)
		var wheel_phase_start: float=u._anim_t
		u.set_physics_process(true);u.order_move(origin+row.delta*82.0)
		var deadline:=Time.get_ticks_msec()+6000
		while not probe.captured and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
		u.set_physics_process(false)
		check(probe.captured and probe.seen.size()==4 and u.position.distance_to(origin)>2 and u.animation_direction==row.d,"real physics traverses four push phases "+String(row.d))
		observations.append({"actual_push_direction":row.d,"phase_indices":probe.seen,"distance":u.position.distance_to(origin)})
		check(u._anim_t>wheel_phase_start and probe.wheel_angular_distance>0.0,"actual displacement advances wheel/gait phase "+String(row.d))
		observations.append({"wheel_actual_movement":row.d,"gait_phase_delta":u._anim_t-wheel_phase_start,"independent_wheel_angle_traveled":probe.wheel_angular_distance,"distance":u.position.distance_to(origin)})
		stage_camera(b,u);await snap("actual_push_walk_"+String(row.d));probe.queue_free();await get_tree().process_frame
		# Keep residual walk blend while stopped: elapsed time and camera motion
		# must not advance the wheel even before the body blend decays to zero.
		u.order_stop();var stopped_phase: float=u._tribute_wheel_angle;var residual_gait_phase: float=u._anim_t;var stopped_position: Vector2=u.position
		var before_zoom: Vector2=b.camera.zoom;b.camera.zoom=before_zoom*1.1;b.camera.position+=Vector2(9,-7);b.camera.force_update_scroll()
		u.set_physics_process(true)
		for tick in range(36):await get_tree().physics_frame
		u.set_physics_process(false);b.camera.zoom=before_zoom;stage_camera(b,u)
		check(u.position.is_equal_approx(stopped_position) and is_equal_approx(u._tribute_wheel_angle,stopped_phase),"actual stop and camera motion do not spin wheel "+String(row.d))
		check(u._anim_t>residual_gait_phase,"original residual gait clock continues independently of stopped wheel "+String(row.d))
		await snap("wheel_actual_stopped_"+String(row.d))
		# Actual Unit damage/attack mechanics; a separate cart remains grounded.
		u.order_stop();u._move_blend=0;u.animation_direction=row.d
		var before_hurt_phase: float=u._tribute_wheel_angle
		var before_hp: float=u.hp;u.take_damage(7,b.level.yang,false,true)
		var hurt: Array=art.unit_anim_frames(u.key,"hurt",row.d,u.art_variant)
		check(u.hp<before_hp and u._campaign_tribute_push_state().is_empty() and frame(u)==hurt[0],"real recoil uses original body with parked cart "+String(row.d))
		check(not u._campaign_tribute_layered_frame(frame(u)),"hurt body does not request duplicate cart "+String(row.d))
		var cart_frames: Array=art.unit_anim_frames(u.key,"parked_cart",row.d,u.art_variant)
		check(cart_frames.size()==1 and cart_frames[0].atlas.resource_path=="res://"+String(manifest.sources.cart_only.path),"interrupted push retains independent cart prop "+String(row.d))
		await snap("parked_hurt_"+String(row.d))
		u.set_physics_process(true);deadline=Time.get_ticks_msec()+2000
		while u._shi_en_hurt_t>0 or u._flinch.length_squared()>1:
			if Time.get_ticks_msec()>deadline:break
			await get_tree().physics_frame
		u.set_physics_process(false);check(is_equal_approx(u._tribute_wheel_angle,before_hurt_phase),"actual parked recoil keeps wheel phase "+String(row.d))
		check(not u._campaign_tribute_push_state().is_empty(),"recoil returns to loaded push pose "+String(row.d))
		var enemy=b.spawn_unit("guan_dao",1,u.position+row.delta*20.0);enemy.set_physics_process(false);var enemy_hp: float=enemy.hp
		u.set_physics_process(true);u.order_attack(enemy,false,true);deadline=Time.get_ticks_msec()+4000
		while u._lunge<=0 and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
		u.set_physics_process(false)
		check(u._lunge>0 and u._campaign_tribute_push_state().is_empty() and u._campaign_tribute_push_active(),"actual attack keeps cart and leaves push-hand body "+String(row.d))
		await snap("parked_attack_"+String(row.d));u.set_physics_process(true)
		while enemy.hp>=enemy_hp and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
		check(enemy.hp<enemy_hp,"loaded merchant actual attack still hits "+String(row.d))
		u.order_stop()
		while u._lunge>0 and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
		u.set_physics_process(false);b.units.erase(enemy);enemy.queue_free();await get_tree().process_frame
	await natural_matrix(b,u,origin)
	# Actual movement plus original mission tick resolves the original delivery.
	u.order_stop();u.position=origin;b.select_single(u,false);u.set_physics_process(true)
	var delivery:="force_deliver_0_0";check(b.mission.request_action(delivery),"original mission accepts loaded delivery")
	var deadline:=Time.get_ticks_msec()+30000
	while b.level.delivered<1 and Time.get_ticks_msec()<deadline:
		await get_tree().physics_frame;b.mission.tick(1.0/60.0)
	u.set_physics_process(false);u._move_blend=0;u.animation_direction="se";stage_camera(b,u);await snap("original_delivery_unloaded")
	check(b.level.delivered==1 and not u.has_meta("carrying_tribute") and not b.level.cargo.has(0),"original real path and callback unload once")
	check(not u._campaign_tribute_push_active() and frame(u)==old_idle[0],"delivery restores original empty-handed body")
	check(not load("res://scripts/tribute_cart_wheel_visual.gd").enabled(u),"actual delivery disables rolling cart renderer")
	check(art.unit_anim_frames(u.key,"walk","se",u.art_variant)==old_walk and u.ui_portrait_texture()==portrait,"unloaded walk and portrait retained")
	b.camera.zoom=startup_zoom;stage_camera(b,u);await snap("default_unloaded_body");b.camera.zoom=Vector2.ONE*2.8
	var ground=b.level.bundles[0]
	check(GroundCart.enabled(ground),"real delivered cargo selects ground cart")
	check(not GroundCart.enabled(b.level.bundles[1]) and not GroundCart.enabled(b.level.bundles[2]),"delivery does not convert other unclaimed loads")
	await ground_matrix(b,ground)
	for locale in ["zh_CN","zh_TW","en","ja"]:
		root.get_node("Localize").set_language(locale,false);b.select_single(u,false);await snap("unloaded_hud_"+locale)
		check(b.hud._port_tex.texture==portrait,"original portrait HUD "+locale)
	root.get_node("Localize").set_language("zh_CN",false)
	await take(b,u,1);await wheel_render_matrix(b,u);await ground_range_matrix(b,u);var prior_cargo: int=b.level.cargo.size();u.take_damage(u.max_hp*20.0,null,false,true);await get_tree().process_frame
	check(u._dying and not u.has_meta("carrying_tribute") and not u._campaign_tribute_push_active(),"actual defeat drops cart metadata before death art")
	check(b.level.cargo.size()==prior_cargo-1 and is_instance_valid(b.level.bundles[1]),"original death callback restores dropped mission cargo")
	var dropped=b.level.bundles[1]
	check(GroundCart.enabled(dropped) and b.units.has(dropped) and dropped.visible,"actual carrier defeat restores claimed cargo as a ground cart")
	check(dropped._campaign_environment_texture()==art.campaign_tribute_cart_texture(dropped.animation_direction),"dropped cargo uses same cart-only original")
	stage_camera(b,dropped);await snap("original_defeat_drop")
	check([u.max_hp,u.atk,u.atk_cd,u.base_speed,u.setup_def.abilities]==stats,"original Ruan Xiaoqi definitions and abilities retained")
	check(Array(b.map.grid)==grid and b.map.decor==decor,"original map and scenery unchanged")
	finish()
func natural_matrix(b,u,origin: Vector2) -> void:
	u.order_stop();u.position=origin;u._move_blend=0;b.camera.zoom=startup_zoom;stage_camera(b,u)
	observations.append({"startup_camera_zoom":[startup_zoom.x,startup_zoom.y]})
	for d in ["se","sw","ne","nw"]:
		u.animation_direction=d;u.face_left=d in ["sw","nw"]
		for state in ["push_idle","push_walk"]:
			var fs: Array=art.unit_anim_frames(u.key,state,d,u.art_variant)
			for i in range(fs.size()):
				u._move_blend=1.0 if state=="push_walk" else 0.0;u._anim_t=TAU*(float(i)+.1)/float(fs.size());u._idle_t=0
				check(frame(u)==fs[i] and u._frame_directional,"startup zoom selects authored pose "+state+d+str(i))
				u.queue_redraw();await snap("default_"+state+"_"+d+"_"+str(i))
	b.camera.zoom=Vector2.ONE*1.6;stage_camera(b,u)
	for d in ["se","sw","ne","nw"]:
		u.animation_direction=d;u.face_left=d in ["sw","nw"];u._move_blend=1.0;u._anim_t=TAU*3.1/4.0;u.queue_redraw();await snap("medium_passing_b_"+d)
	b.camera.zoom=Vector2.ONE*2.8;u.order_stop();u._move_blend=0
func ground_matrix(b,ground) -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_PACK_INPUTS"))).ground_manifest
	var origin: Vector2=ground.position
	ground.position=b.map.cell_to_world(clear_cell(b));b.map.sync_render_position(ground)
	for size in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1920,1080)]:
		root.size=size;root.content_scale_size=size
		for d in ["se","sw","ne","nw"]:
			ground.animation_direction=d;ground.face_left=d in ["sw","nw"];ground.queue_redraw();stage_camera(b,ground)
			var texture: Texture2D=ground._campaign_environment_texture()
			check(texture!=null,"ground prop texture present "+str(size.x)+d)
			if texture==null:continue
			var pose: Dictionary=data.poses["cart_only_"+d];var wheel: Array=data.sources.cart_only.wheel_contacts[d]
			check(texture==art.campaign_tribute_cart_texture(d) and texture is AtlasTexture,"dedicated true-direction prop "+str(size.x)+d)
			check(texture.atlas.resource_path=="res://"+String(data.sources.cart_only.path) and texture.region==Rect2(pose.region[0],pose.region[1],pose.region[2],pose.region[3]),"ground prop preserves untouched original region "+str(size.x)+d)
			var contact: Vector2=(Vector2(wheel[0],wheel[1])-texture.region.position+texture.margin.position-Vector2(texture.get_width()*.5,texture.get_height()*.82))*GroundCart.visual_size(texture)/texture.get_width()
			check(contact.length()<.0001,"wheel contacts ground anchor without mirror or floating "+str(size.x)+d)
			check(ground.ui_portrait_texture()==texture,"selection preview follows ground role "+str(size.x)+d)
			check(texture.has_meta("visible_top") and absf(float(texture.get_meta("visible_top",0.0))-float(pose.visible_top))<.000001,"authored alpha top anchors unobscured label "+str(size.x)+d)
			await snap("ground_cart_"+str(size.x)+"_"+d)
			check(is_equal_approx(float(ground.get_meta("campaign_environment_label_y",0.0)),GroundCart.visual_size(texture)*(float(pose.visible_top)-.82)-8.0),"real draw places bar above cart cargo "+str(size.x)+d)
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;ground.position=origin;b.map.sync_render_position(ground);ground.animation_direction="se"
	stage_camera(b,ground);ground.queue_redraw();await snap("actual_delivered_ground_cart")
	var variant: String=ground.art_variant;ground.art_variant="";check(not GroundCart.enabled(ground),"ordinary treasure_cart excluded");ground.art_variant=variant
	var prior_route=String(ground.get_meta("campaign_environment_route",""))
	ground.set_meta("campaign_environment_route","jujube_cart");check(not GroundCart.enabled(ground),"dates route cannot borrow tribute cart")
	if prior_route.is_empty():ground.remove_meta("campaign_environment_route")
	else:ground.set_meta("campaign_environment_route",prior_route)
	var member_index: int=b.level.bundles.find(ground);b.level.bundles.remove_at(member_index);check(not GroundCart.enabled(ground),"nonmember cannot borrow claimed mission state");b.level.bundles.insert(member_index,ground)
	check(GroundCart.enabled(ground),"actual mission ownership restored after negative probes")
func finish() -> void:
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"screenshots":shots,"observations":observations,
		"scope":"Claimed tribute ground prop in current Huangnigang, strict pre-seizure negatives, three sizes/four directions and actual delivered/defeat-drop callbacks; retained real Ruan Xiaoqi merchant loaded-cart art, actual mission pickup/movement/delivery/drop, interrupted hurt/attack; four directions and three sizes, actual startup camera and1.6 passing-B views. CARRY/drug prerequisites and sampling positions are explicit QA fixtures, unrelated actors frozen and fog off. Includes selected attack-range ground ordering with real opaque actor/cart/companion pixel comparisons, three sizes/four directions, old-top-layer negative control and canvas lifecycle. No full wine sequence, original seven carts/eleven loads migration, other carriers, all-art/campaign/save/performance/Steam qualification. Runtime is the retained full base PCK plus hash-verified exported patch, not a newly exported monolithic full PCK."}
	var f:=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();quit(0 if failures.is_empty() else 1)

# Extra real packed-game probes. Existing carrier/mission checks remain intact.
var _range_alpha_cache: Dictionary={}

func _range_core_data(texture: Texture2D) -> Dictionary:
	var key: int=texture.get_instance_id()
	if _range_alpha_cache.has(key):return _range_alpha_cache[key]
	var image:=texture.get_image()
	if image.is_compressed():image.decompress()
	if image.get_format()!=Image.FORMAT_RGBA8:image.convert(Image.FORMAT_RGBA8)
	var width:=image.get_width();var height:=image.get_height();var pitch:=width+1
	var data:=image.get_data();var prefix:=PackedInt32Array();prefix.resize(pitch*(height+1))
	# Prefix sums reject ANY alpha<253 in the full25x25 native neighborhood.
	# The old sparse25-sample alpha255 mask had zero samples on these originals,
	# whose painted interiors are predominantly253/255, not255/255.
	for y in range(height):
		var row_total:=0
		for x in range(width):
			if data[(y*width+x)*4+3]<253:row_total+=1
			prefix[(y+1)*pitch+x+1]=prefix[y*pitch+x+1]+row_total
	var result: Dictionary={"pitch":pitch,"prefix":prefix,"size":Vector2i(width,height)}
	_range_alpha_cache[key]=result
	return result

func _range_blend_bound(before: Color) -> float:
	# Maximum composite ring alpha: fill .045 then edge .72. The residual
	# contribution through alpha>=253/255 is bounded by (1-alpha)*.7326.
	# Cover either direct RGB or linear blending followed by sRGB encoding,
	# including half a8-bit quantum at each capture. Never infer exact opacity.
	var quantum:=1.0/255.0;var epsilon: float=(2.0/255.0)*(1.0-(1.0-.045)*(1.0-.72))
	var low:=Color(maxf(0,before.r-quantum*.5),maxf(0,before.g-quantum*.5),maxf(0,before.b-quantum*.5)).srgb_to_linear()
	var high:=Color(minf(1,before.r+quantum*.5),minf(1,before.g+quantum*.5),minf(1,before.b+quantum*.5)).srgb_to_linear()
	low=Color(maxf(0,low.r-epsilon),maxf(0,low.g-epsilon),maxf(0,low.b-epsilon)).linear_to_srgb()
	high=Color(minf(1,high.r+epsilon),minf(1,high.g+epsilon),minf(1,high.b+epsilon)).linear_to_srgb()
	var gamma_bound: float=maxf(maxf(maxf(before.r-low.r,high.r-before.r),maxf(before.g-low.g,high.g-before.g)),maxf(before.b-low.b,high.b-before.b))
	return maxf(epsilon+quantum,gamma_bound+quantum*.5)+.00001

func _range_chain_opacity(unit) -> float:
	var result: float=unit.self_modulate.a
	var node: Node=unit
	while node is CanvasItem:
		var canvas:=node as CanvasItem;result*=canvas.modulate.a;node=node.get_parent()
	return result

func _range_pixels(before: Image, after: Image, map_owner, unit, frames: Array) -> Dictionary:
	var covered:=0;var altered:=0;var raw_changed:=0;var max_delta:=0.0;var max_bound:=0.0
	var to_view: Transform2D=unit.get_global_transform_with_canvas()*map_owner.map.ISO_INV
	# GameMap.sync_render_position applies terrain lift only to RenderingServer.
	# Node2D transforms remain logical; reproduce the actual stored paint lift.
	var parent_to_view: Transform2D=unit.get_parent().get_global_transform_with_canvas()
	to_view.origin-=(parent_to_view.x+parent_to_view.y)*float(unit.get_meta("render_height",0.0))
	var inverse:=to_view.affine_inverse();var body_size: float=unit.radius*3.7*unit.visual_scale
	for frame_texture: AtlasTexture in frames:
		var core:=_range_core_data(frame_texture.atlas);var pitch: int=core.pitch;var prefix: PackedInt32Array=core.prefix
		var size: float=body_size*float(frame_texture.get_meta("draw_scale",1.0))
		var rect:=Rect2(Vector2(-size*.5,-size*.82)+Vector2(frame_texture.get_meta("draw_offset_px",Vector2.ZERO))*size/float(frame_texture.get_height()),Vector2.ONE*size)
		var region: Rect2=frame_texture.region
		var corner0:=to_view*rect.position;var corner1:=to_view*rect.end
		var bounds:=Rect2i(Vector2i(corner0.floor()),Vector2i((corner1-corner0).ceil())).intersection(Rect2i(Vector2i.ZERO,before.get_size()))
		for y in range(bounds.position.y,bounds.end.y):
			for x in range(bounds.position.x,bounds.end.x):
				var local:=inverse*Vector2(x+.5,y+.5)
				var native: Vector2=(local-rect.position)/rect.size*Vector2(frame_texture.get_width(),frame_texture.get_height())-frame_texture.margin.position+region.position
				var p:=Vector2i(native.floor())
				if not Rect2i(region).grow(-12).has_point(p):continue
				var left:=p.x-12;var top:=p.y-12;var right:=p.x+13;var bottom:=p.y+13
				if prefix[bottom*pitch+right]-prefix[top*pitch+right]-prefix[bottom*pitch+left]+prefix[top*pitch+left]!=0:continue
				covered+=1
				var original:=before.get_pixel(x,y);var current:=after.get_pixel(x,y)
				var delta: float=maxf(maxf(absf(original.r-current.r),absf(original.g-current.g)),absf(original.b-current.b))
				var bound:=_range_blend_bound(original);max_delta=maxf(max_delta,delta);max_bound=maxf(max_bound,bound)
				if delta>0.0:raw_changed+=1
				if delta>bound:altered+=1
	return {"near_opaque_samples":covered,"exceeded_blend_bound":altered,"raw_changed_samples":raw_changed,"max_channel_delta":max_delta,"max_allowed_blend_bound":max_bound,"minimum_native_alpha":253.0/255.0,"full_native_core_radius":12}

func _range_capture(b, enabled: bool, label: String) -> Image:
	root.get_node("Settings").show_range_rings=enabled
	b.overlay._update_ground_range();b.overlay.queue_redraw()
	await snap(label)
	return root.get_texture().get_image()

func ground_range_matrix(b,u) -> void:
	var settings=root.get_node("Settings");var old_setting: bool=settings.show_range_rings
	var old_mode: int=b.process_mode;var old_pos: Vector2=u.position;var old_direction: String=u.animation_direction;var old_zoom: Vector2=b.camera.zoom
	var other=b.find_unit("liu_tang");var other_pos: Vector2=other.position;var other_direction: String=other.animation_direction
	var visual_fields: Array=["_idle_t","_move_blend","_flinch","_flash","_lunge","_shi_en_hurt_t","_cast_t","face_left"]
	var own_visual: Dictionary={};var other_visual: Dictionary={}
	for field in visual_fields:own_visual[field]=u.get(field);other_visual[field]=other.get(field)
	var old_height: Dictionary={"own_present":u.has_meta("render_height"),"own_value":u.get_meta("render_height",0.0),"other_present":other.has_meta("render_height"),"other_value":other.get_meta("render_height",0.0)}
	for actor in [u,other]:
		actor._flinch=Vector2.ZERO;actor._flash=0.0;actor._lunge=0.0;actor._shi_en_hurt_t=0.0;actor._cast_t=0.0
	var origin: Vector2=b.map.cell_to_world(clear_cell(b));u.position=origin;u.order_stop();u._move_blend=0;u._idle_t=0;other.position=origin-Vector2(14,14);other.animation_direction="se";other._move_blend=0;other._idle_t=0;other.queue_redraw()
	b.map.sync_render_position(u);b.map.sync_render_position(other)
	b.process_mode=Node.PROCESS_MODE_DISABLED;b.camera.zoom=Vector2.ONE*2.8;b.select_single(u,false)
	check(is_equal_approx(_range_chain_opacity(u),1.0) and is_equal_approx(_range_chain_opacity(other),1.0),"range fixture actor/ancestor modulations have unit alpha")
	var stats: Array=[u.atk,u.atk_range,u.radius,u.hp,b.level.cargo.duplicate()]
	check(b.overlay.get_child_count(true)==0,"ground range keeps overlay scene-child schema unchanged")
	check(load("res://scripts/run_environment_state.gd").new()._environment_safe(b.overlay),"ground range retains trusted overlay node safety")
	for row in [{"size":Vector2i(1280,720),"d":"se"},{"size":Vector2i(1280,720),"d":"sw"},{"size":Vector2i(1280,720),"d":"ne"},{"size":Vector2i(1280,720),"d":"nw"},{"size":Vector2i(960,540),"d":"se"},{"size":Vector2i(1920,1080),"d":"se"}]:
		root.size=row["size"];root.content_scale_size=root.size;u.animation_direction=row.d;u.face_left=row.d in ["sw","nw"];u.queue_redraw();stage_camera(b,u)
		var body: Texture2D=frame(u);var cart: Texture2D=art.unit_anim_frames(u.key,"parked_cart",row.d,u.art_variant)[0]
		check(u._campaign_tribute_layered_frame(body),"range probe uses actual separated carrier "+str(root.size.x)+row.d)
		var tag: String="range_"+str(root.size.x)+"_"+row.d
		var off: Image=await _range_capture(b,false,tag+"_off");var on: Image=await _range_capture(b,true,tag+"_ground")
		var own:=_range_pixels(off,on,b,u,[body]+wheel_cart_mask_frames(u));var rear:=_range_pixels(off,on,b,other,[frame(other)])
		check(own.near_opaque_samples>100 and own.exceeded_blend_bound==0,"range stays within paint-opacity blend bound on carrier and cart "+tag)
		check(rear.near_opaque_samples>50 and rear.exceeded_blend_bound==0,"range stays within paint-opacity blend bound on rear companion "+tag)
		var difference:=0
		var center: Vector2=b.get_canvas_transform()*b.to_screen(u.position)
		var r: float=(u.atk_range+u.radius)*b.camera.zoom.x
		var bounds:=Rect2i(Vector2i(center-Vector2(r*1.42+6,r*.72+6)),Vector2i(r*2.84+12,r*1.44+12)).intersection(Rect2i(Vector2i.ZERO,on.get_size()))
		for y in range(bounds.position.y,bounds.end.y):
			for x in range(bounds.position.x,bounds.end.x):
				if off.get_pixel(x,y)!=on.get_pixel(x,y):difference+=1
		check(difference>30,"ground range remains visible around units "+tag)
		observations.append({"ground_range":tag,"carrier":own,"rear_companion":rear,"changed_ground_region_pixels":difference})
		if root.size.x==1280 and row.d=="se":
			# A deliberately topmost copy of the OLD projected ring validates that
			# the solid-pixel oracle catches the original occlusion symptom.
			await _range_capture(b,false,tag+"_negative_off")
			var bad:=RenderingServer.canvas_item_create();RenderingServer.canvas_item_set_parent(bad,b.overlay.get_canvas_item())
			var pts:=PackedVector2Array()
			for i in range(49):pts.append(b.to_screen(u.position+Vector2(cos(TAU*i/48.0),sin(TAU*i/48.0))*(u.atk_range+u.radius)))
			RenderingServer.canvas_item_add_polyline(bad,pts,PackedColorArray([Color(1,.82,.28,.72)]),1.6,false)
			await snap(tag+"_top_negative");var wrong:=root.get_texture().get_image();var hit:=_range_pixels(off,wrong,b,u,[body]+wheel_cart_mask_frames(u));var rear_hit:=_range_pixels(off,wrong,b,other,[frame(other)])
			check(hit.exceeded_blend_bound+rear_hit.exceeded_blend_bound>0,"negative top-layer control reproduces body occlusion")
			observations.append({"top_layer_negative_carrier":hit,"top_layer_negative_companion":rear_hit});RenderingServer.free_rid(bad)
	var overlay_index: int=b.overlay.get_index();var overlay=b.overlay;b.remove_child(overlay)
	check(not overlay._ground_ranges._item.is_valid(),"leaving scene releases derived ground canvas")
	b.add_child(overlay);b.move_child(overlay,overlay_index);settings.show_range_rings=true;overlay._update_ground_range()
	check(overlay._ground_ranges._item.is_valid() and overlay.get_child_count(true)==0,"reattaching reconstructs ground canvas without scene children")
	check(stats==[u.atk,u.atk_range,u.radius,u.hp,b.level.cargo.duplicate()],"range presentation preserves combat/cargo state")
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;u.position=old_pos;u.animation_direction=old_direction;other.position=other_pos;other.animation_direction=other_direction;u.queue_redraw();other.queue_redraw();b.map.sync_render_position(u);b.map.sync_render_position(other);b.camera.zoom=old_zoom;settings.show_range_rings=old_setting;b.process_mode=old_mode;stage_camera(b,u);overlay._update_ground_range();_range_alpha_cache.clear()
	for field in visual_fields:u.set(field,own_visual[field]);other.set(field,other_visual[field])
	if old_height.own_present:u.set_meta("render_height",old_height.own_value)
	elif is_zero_approx(float(u.get_meta("render_height",0.0))):u.remove_meta("render_height")
	if old_height.other_present:other.set_meta("render_height",old_height.other_value)
	elif is_zero_approx(float(other.get_meta("render_height",0.0))):other.remove_meta("render_height")
	u.queue_redraw();other.queue_redraw()


# Real Unit tests; the independent CartPaint preview is not used here.
func wheel_cart_mask_frames(unit) -> Array:
	var wheel=load("res://scripts/tribute_cart_wheel_visual.gd")
	var row: Dictionary=wheel.FIT[unit.animation_direction]
	var result: Array=[]
	var pivot:=Vector2(row.pose.pivot_native[0],row.pose.pivot_native[1])
	var tr:=Vector2(row.rim_translation_original_native[0],row.rim_translation_original_native[1])
	for part in [{"texture":wheel.BODY,"region":row.body_region,"scale":1.0,"translation":Vector2.ZERO},{"texture":wheel.RIM,"region":row.region,"scale":float(row.rim_uniform_scale),"translation":tr}]:
		var values: Array=part.region
		var region:=Rect2(values[0],values[1],values[2],values[3])
		var side: float=maxf(region.size.x,region.size.y)
		var source_scale: float=part.scale
		var frame_texture:=AtlasTexture.new();frame_texture.atlas=part.texture;frame_texture.region=region
		frame_texture.margin=Rect2(Vector2.ZERO,Vector2.ONE*side-region.size)
		frame_texture.set_meta("draw_scale",source_scale*side/float(row.pose.virtual_canvas_reference))
		frame_texture.set_meta("draw_offset_px",region.position+(part.translation-pivot)/source_scale+Vector2(.5,.82)*side)
		result.append(frame_texture)
	return result

func wheel_clip_view_bounds(b,unit) -> Rect2i:
	var wheel=load("res://scripts/tribute_cart_wheel_visual.gd")
	var row: Dictionary=wheel.FIT[unit.animation_direction]
	var scale_native: float=unit.radius*3.7*unit.visual_scale/float(row.pose.virtual_canvas_reference)
	var tr:=Vector2(row.rim_translation_original_native[0],row.rim_translation_original_native[1])
	var rc:=Vector2(row.rim_plane_center[0],row.rim_plane_center[1])
	var ar: Transform2D=wheel._matrix(row.rim_inner_plane_axes)
	var to_view: Transform2D=unit.get_global_transform_with_canvas()*b.map.ISO_INV
	var parent_to_view: Transform2D=unit.get_parent().get_global_transform_with_canvas()
	to_view.origin-=(parent_to_view.x+parent_to_view.y)*float(unit.get_meta("render_height",0.0))
	var center: Vector2=to_view*wheel._point(row,tr+float(row.rim_uniform_scale)*rc,scale_native)
	var result:=Rect2(center,Vector2.ZERO)
	for i in range(64):
		var angle:=TAU*float(i)/64.0
		var q:=Vector2(cos(angle),sin(angle))*float(row.clip_inner_radius)
		result=result.expand(to_view*wheel._point(row,tr+float(row.rim_uniform_scale)*(rc+ar*q),scale_native))
	return Rect2i(result.position.floor(),result.size.ceil()).grow(3).intersection(Rect2i(Vector2i.ZERO,root.size))

func wheel_render_matrix(b,u) -> void:
	var wheel=load("res://scripts/tribute_cart_wheel_visual.gd")
	var saved: Dictionary={}
	var fields: Array=["_tribute_wheel_angle","_anim_t","_idle_t","_move_blend","animation_direction","face_left","_flinch","_flash","_lunge","_shi_en_hurt_t","_cast_t"]
	for field in fields:saved[field]=u.get(field)
	var old_mode: int=b.process_mode;var old_pos: Vector2=u.position;var old_zoom: Vector2=b.camera.zoom
	var old_size: Vector2i=root.size;var old_scale: Vector2i=root.content_scale_size
	var settings=root.get_node("Settings");var old_ring: bool=settings.show_range_rings;settings.show_range_rings=false
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;b.process_mode=Node.PROCESS_MODE_DISABLED
	u.position=b.map.cell_to_world(clear_cell(b));u._idle_t=0;u._move_blend=1.0;u._flinch=Vector2.ZERO;u._flash=0;u._lunge=0;u._shi_en_hurt_t=0;u._cast_t=0
	b.map.sync_render_position(u);b.camera.zoom=Vector2.ONE*2.8;b.select_single(u,false);stage_camera(b,u)
	for direction in ["se","sw","ne","nw"]:
		u.animation_direction=direction;u.face_left=direction in ["sw","nw"];u._anim_t=.1;u._tribute_wheel_angle=.1;u.queue_redraw()
		check(wheel.enabled(u),"wheel renderer selects actual loaded chapter16 Ruan7 "+direction)
		var first_frame: Texture2D=frame(u)
		await snap("wheel_actual_"+direction+"_phase_a");var before:=root.get_texture().get_image()
		u._tribute_wheel_angle=.8;u.queue_redraw();await snap("wheel_actual_"+direction+"_phase_b");var after:=root.get_texture().get_image()
		check(frame(u)==first_frame,"wheel phase comparison keeps same authored body frame "+direction)
		var bounds:=wheel_clip_view_bounds(b,u);var changed:=0
		for y in range(bounds.position.y,bounds.end.y):
			for x in range(bounds.position.x,bounds.end.x):
				if before.get_pixel(x,y)!=after.get_pixel(x,y):changed+=1
		check(changed>4,"actual Unit polygon wheel changes rendered pixels "+direction)
		observations.append({"actual_unit_wheel":direction,"wheel_clip_changed_pixels":changed,"clip":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]})
	var codec=load("res://scripts/run_unit_state.gd").new(null,null,null)
	var raw: Dictionary=codec._read_explicit(u)
	check(codec.OMITTED_VISUAL_FIELDS.has("_tribute_wheel_angle") and not raw.has("_tribute_wheel_angle"),"independent wheel is explicitly classified outside saved unit values")
	var gait_before: float=u._anim_t;u._tribute_wheel_angle=1.27;codec._assign_values(u,raw)
	check(u._tribute_wheel_angle==0.0 and u._anim_t==gait_before,"explicit unit assignment rebuilds visual wheel at zero and preserves saved gait")
	for actor in b.units:
		if actor!=u:check(not wheel.enabled(actor),"wheel renderer rejects actual foreign actor "+str(actor.key))
	u.position=old_pos
	for field in fields:u.set(field,saved[field])
	b.map.sync_render_position(u);b.process_mode=old_mode;b.camera.zoom=old_zoom;root.size=old_size;root.content_scale_size=old_scale;settings.show_range_rings=old_ring;stage_camera(b,u);u.queue_redraw()
