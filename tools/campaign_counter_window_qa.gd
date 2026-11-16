extends "res://tools/kuaihuolin_short_test.gd"
var observations: Array=[]
func _fixture():
	var b=await _start("",6)
	b.set_process(false); b.set_physics_process(false)
	for u in b.units: u.set_physics_process(false)
	return b
func _dispatch(b,slot: int) -> void:
	var u=b.level.wu
	u._stun_t=0; u._cast_t=0; u.ability_slots[slot].cd_t=0
	b._do_ability(u,slot,u.position)
	await process_frame
func _render_window(b,name: String) -> void:
	b.hud.set_process(false)
	b.hud._clear_info_toasts()
	b.hud.set_top(b.level.top_status(b))
	b.hud.update_selection_panel(b.selection)
	b.hud._refresh_panel()
	b.camera.set_process(false)
	b.camera.zoom=Vector2.ONE*1.25
	b.center_camera_cell(b.map.world_to_cell(b.level.menshen.position))
	for i in range(8):
		b.hud._refresh_hero_bar(); b.hud._layout_desktop_hero(); b.hud._layout_info_panel(); b.mission.tick(0)
		await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,name+" rendered")
func _window_fixture() -> void:
	var b=await _fixture()
	var l=b.level
	b.fog=false # Frozen visibility fixture, not live exploration.
	l._open_showdown(b,true)
	check(l.counter_window_state(b).is_empty(),"no opening marker while normally braced")
	l.menshen.position=b.map.cell_to_world(Vector2i(48,20))
	l.wu.position=l.menshen.position+Vector2(80,0)
	l._begin_special(b)
	check(l.counter_window_state(b).is_empty(),"attack windup is not mislabeled a counter opening")
	l.wu.position=l.fist_at+Vector2(0,130)
	l._duel_tick(b,l.fist_windup+0.01)
	var state: Dictionary=l.counter_window_state(b)
	check(is_equal_approx(state.remaining,2.2) and is_equal_approx(state.fraction,1.0),"missed heavy shows full original 2.2-second window")
	check(not state.footwork and not state.in_range,"readout identifies missing step and approach")
	b.fog=true
	b._sight_now.resize(b.map.w*b.map.h); b._reveal_t.resize(b.map.w*b.map.h)
	b._sight_now.fill(0); b._reveal_t.fill(0)
	check(l.unit_tactical_hint(b,l.wu)=="","unseen opponent does not reveal readiness through selected Wu")
	b.fog=false
	b.select_single(l.wu,false)
	root.get_node("Localize").set_language("zh_CN",false)
	await _render_window(b,"heavy_open")
	var serial: int=l.special_index
	var hp: float=l.menshen.hp
	l._duel_tick(b,1.1)
	state=l.counter_window_state(b)
	check(is_equal_approx(state.fraction,0.5) and is_equal_approx(state.remaining,1.1),"ring fraction follows the actual half-expired window")
	check(l.special_index==serial and l.menshen.hp==hp and not b.mission.has_event("mengzhou_signature"),"rendering/readout does not deal damage or grant signature credit")
	await _dispatch(b,1)
	check(not l.counter_window_state(b).footwork,"stationary W is still incomplete")
	l.wu.position=l.menshen.position+Vector2(64,0)
	check(l.counter_window_state(b).footwork and l.counter_window_state(b).in_range,"actual displacement and range appear in readout")
	for locale in ["zh_CN","zh_TW","en","ja"]:
		root.get_node("Localize").set_language(locale,false)
		var hint: String=l.unit_tactical_hint(b,l.wu)
		check(not hint.is_empty(),locale+" has a translated readiness hint")
		observations.append({"language":locale,"hint":hint})
	root.get_node("Localize").set_language("en",false)
	root.size=Vector2i(960,540);root.content_scale_size=root.size
	await _render_window(b,"half_ready_en")
	hp=l.menshen.hp
	await _dispatch(b,2)
	check(l.menshen.hp<hp and b.mission.has_event("mengzhou_signature"),"real E damage still earns original current-step signature")
	check(l.counter_window_state(b).kick_cooldown>0,"readiness reports actual E cooldown")
	l._duel_tick(b,2.3)
	check(l.counter_window_state(b).is_empty() and l.unit_tactical_hint(b,l.wu)=="" and l.menshen._damage_reduction_sources.has(l.BRACE_SOURCE),"expiry removes feedback and restores original brace")
	await _render_window(b,"expired_en")
	l.special_kind="rush";l.special_index+=1
	l._finish_special(b,true)
	check(is_equal_approx(l.counter_window_state(b).remaining,2.8),"rush keeps its original 2.8-second window")
	await process_frame
	var visual_contract=load("res://scripts/run_level7_visual_state.gd")
	var nodes: Dictionary=visual_contract.tokens(l,b.fx_root)
	check(nodes.ok and nodes.tokens.is_empty(),"counter overlay adds no tell nodes to saved visual graph")
	l._set_menshen_subdued(b)
	check(l.counter_window_state(b).is_empty() and l.exposed_left==0,"subdual clears opening feedback")
	await _dispose(b)
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1");AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	folder="res://.godot/campaign-counter-window"
	DirAccess.make_dir_recursive_absolute(folder)
	await _window_fixture()
	root.get_node("Localize").set_language("zh_CN",false)
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	Engine.time_scale=4
	if OS.get_environment("CW_FIXTURE_ONLY")!="1": await _live("direct")
	Engine.time_scale=1
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"fixture_observations":observations,"live_cases":cases,"scope":"frozen counter readout/rendering; executed live routes are listed in live_cases; not full restore, human fun or performance/device acceptance"},"\t"))
	quit(0 if failures.is_empty() else 1)
