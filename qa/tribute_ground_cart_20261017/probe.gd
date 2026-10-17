extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var art=root.get_node("Art")
	for d in ["se","sw","ne","nw"]:
		var resource=load("res://assets/anim/tribute_ground_cart_20261017_idle_"+d+".tres")
		var f=resource.get_frame_texture("default",0)
		print("PROP ",d," size=",f.get_size()," scale=",f.get_meta("draw_scale")," generic=",art._load_generic_directional_frames(resource.resource_path).size()," route=",art.campaign_tribute_cart_texture(d))
	var campaign=root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","custom_defense","scenario","scale_on","ai_friendly"]:campaign.set(mode,false)
	campaign.current=0;seed(5088120)
	var b=load("res://scenes/main.tscn").instantiate();root.add_child(b);current_scene=b;await process_frame
	b.hud._intro_root.hide();b._on_intro_done();b._on_start_battle();await process_frame
	b.set_process(false);b.set_physics_process(false)
	for u in b.units:u.set_physics_process(false)
	var u=b.level.bundles[0];var helper=load("res://scripts/campaign_tribute_cart_visual.gd")
	print("CARGO key=",u.key," variant=",u.art_variant," route=",u.get_meta("campaign_environment_route")," script=",b.level.get_script().resource_path," id=",b.level.id()," member=",b.level.bundles.find(u)," world=",b.units.has(u)," before=",helper.enabled(u))
	b.mission.mark("force_delivered_0","QA derived-route diagnostic only")
	print("AFTER event=",b.mission.has_event("force_delivered_0")," enabled=",helper.enabled(u)," texture=",u._campaign_environment_texture())
	quit()
