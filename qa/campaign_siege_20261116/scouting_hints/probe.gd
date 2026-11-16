extends "res://tools/zhujiazhuang_rts_test.gd"

const HINTS := [
	"拆掉外营可断新援；已出击的庄客仍在场。",
	"北矿守军。击退守军后派兵占住矿区，再调工人采金。",
	"正攻可先用投石车拆箭楼，再让步兵护撞车攻门。",
	"偏门可强攻，也可侦察外围寻找内应。",
	"孙立在阵。前往接应标记可开偏门，也可用器械强攻。",
	"选中孙立，右键接应标记打开偏门。",
	"内应已失。可带器械攻破偏门。",
]
var checked_panels := []

func _cell_visibility(b, u, seen: bool) -> void:
	var cell: Vector2i = b.map.world_to_cell(u.position)
	var index: int = cell.y * b.map.w + cell.x
	b._sight_now[index] = 1 if seen else 0
	b._reveal_t[index] = 0.0
	u.fog_visible = seen

func _inspect(b, u) -> void:
	_cell_visibility(b,u,true)
	b._click_select(b.to_screen(u.position),false)
	b.hud.update_selection_panel(b.selection)
	b.hud._refresh_panel()

func _verify_panel(b, u, source: String, catalog: Dictionary, friendly := false) -> bool:
	if friendly:
		b._click_select(b.to_screen(u.position),false)
	else:
		_inspect(b,u)
	var selected: bool = b.active_unit()==u if friendly else b._inspect_unit==u
	var all_locales := true
	var english_fits := false
	for locale in ["zh_CN","zh_TW","en","ja"]:
		root.get_node("Localize").set_language(locale,false)
		b.hud.update_selection_panel(b.selection)
		b.hud._refresh_panel()
		await process_frame
		var expected: String = source if locale=="zh_CN" else catalog[source][locale]
		var label: Label = b.hud._info_stats
		all_locales = all_locales and expected in label.text
		if locale=="en":
			await RenderingServer.frame_post_draw
			english_fits = b.hud._info_box.get_global_rect().encloses(label.get_global_rect()) 				and label.get_minimum_size().y <= label.size.y+1
	root.get_node("Localize").set_language("zh_CN",false)
	b.hud._refresh_panel()
	checked_panels.append({"source":source,"four_locales":all_locales,"selected_or_inspected":selected,"english_960_fits":english_fits})
	return all_locales and selected and english_fits

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	root.size=Vector2i(960,540)
	root.content_scale_size=root.size
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/zhujiazhuang_scouting_hints.json"))
	var b = await _start("",2)
	b.set_process(false)
	b.set_physics_process(false)
	b.camera.set_process(false)
	for unit in b.units:
		unit.set_physics_process(false)
	var l = b.level
	check(b.fog and not b.is_visible_world(l.outpost.position),
		"fixture starts with live fog and the enemy outpost hidden")
	_cell_visibility(b,l.outpost,false)
	b._click_select(b.to_screen(l.outpost.position),false)
	check(b._inspect_unit!=l.outpost and l.unit_tactical_hint(b,l.outpost)=="",
		"hidden outpost provides no tactical information")
	check(await _verify_panel(b,l.outpost,HINTS[0],catalog),
		"normal enemy inspect shows the outpost tradeoff in four languages")
	check(b.hud._info_stats.text==HINTS[0],
		"read-only outpost inspection omits player rally controls or enemy queue")
	_cell_visibility(b,l.outpost,false)
	b.hud._refresh_panel()
	check(l.unit_tactical_hint(b,l.outpost)=="" and HINTS[0] not in b.hud._info_stats.text,
		"losing fog sight clears the extra tactical text")
	check(await _verify_panel(b,l.resource_guards[0],HINTS[1],catalog),
		"north mine guard inspection explains how to secure the field")
	check(await _verify_panel(b,l.gate,HINTS[2],catalog) 		and "承伤25%" in b.hud._info_stats.text,
		"main gate offers siege advice and keeps the fortification damage rule")
	check(await _verify_panel(b,l.side_gate,HINTS[3],catalog),
		"side gate offers exploration or siege before Sun Li arrives")
	l.on_mission_action(b,"zhu_rts_recon",l.song)
	var sun = l.sun
	sun.set_physics_process(false)
	check(await _verify_panel(b,l.side_gate,HINTS[4],catalog),
		"side gate update reflects Sun Li's actual arrival and leaves siege available")
	check(await _verify_panel(b,sun,HINTS[5],catalog,true),
		"selecting Sun Li explains the original rendezvous right-click")
	sun.take_damage(100000.0,l.resource_guards[0],false,true)
	check(await _verify_panel(b,l.side_gate,HINTS[6],catalog),
		"actual Sun Li death switches the side gate to siege without blocking it")
	var barracks = b.units.filter(func(u):return u.faction==0 and u.key=="barracks")[0]
	b._click_select(b.to_screen(barracks.position),false)
	b.hud.update_selection_panel(b.selection)
	b.hud._refresh_panel()
	check(b.active_unit()==barracks and "右键设集结点" in b.hud._info_stats.text,
		"friendly production still shows its normal rally command")
	print("ZHU_SCOUTING_HINTS_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,
		"panels":checked_panels,"rendered_size":[root.size.x,root.size.y],
		"scope":"real click/inspection and Windows narrow layout, controlled fog and chapter states"}))
	b.hud.to_menu.emit()
	await scene_changed
	for frame in range(4):
		await process_frame
	if failures.is_empty():
		root.get_node("AppLifecycle").request_quit("zhu_scouting_hints_fixture")
	else:
		quit(1)
