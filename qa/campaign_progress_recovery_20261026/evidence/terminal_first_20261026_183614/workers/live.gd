extends "base.gd"
## One natural wine route and actual asynchronous campaign terminal; no direct END or stage injection.
var cases: Array=[]
var visual:=false
var folder:="res://.godot/huangnigang_short"
var boundaries_done:=false
var ledger_samples: Array = []
const DISPLAY_LANGUAGES := ["zh_CN", "zh_TW", "en", "ja"]
const WINE_WIN_LINE := "七星与白胜巧施酒计，十五名押送者麻倒，七车十一担已运出黄泥冈。"
var display_catalog: Dictionary = {}
var report_catalog: Dictionary = {}
var intro_samples: Array = []
var result_samples: Array = []
var selector_samples: Array = []

func _catalog_text(source: String, language: String) -> String:
	var entry: Variant = display_catalog.get(source)
	var present: bool = typeof(entry) == TYPE_DICTIONARY
	if language != "zh_CN":
		present = present and typeof(entry.get(language)) == TYPE_STRING and not String(entry.get(language, "")).is_empty()
	check(present, language + ": installed story catalog contains " + source)
	if not present: return ""
	var expected: String = source if language == "zh_CN" else entry[language]
	check(root.get_node("Localize").text(source) == expected, language + ": story translator uses installed catalog")
	return expected

func _story_screenshot(name: String) -> Dictionary:
	check(visual, name + ": actual graphical runtime available")
	if not visual: return {}
	# No unbounded frame_post_draw wait: the actual static intro/result can
	# remain unchanged in an offscreen window. Two UI frames settle bindings.
	for frame in range(2): await get_tree().process_frame
	RenderingServer.force_draw(false)
	var image: Image = root.get_texture().get_image()
	var path := folder.path_join(name + ".png")
	var valid: bool = image != null and not image.is_empty()
	check(valid, name + ": actual viewport image available")
	if not valid: return {}
	var saved: bool = image.save_png(path) == OK
	check(saved, name + ": representative screenshot saved")
	return {"path": path, "sha256": FileAccess.get_sha256(path) if saved else "",
		"width": image.get_width(), "height": image.get_height()}

func _selector_button(battle: Variant, button_id: String) -> Button:
	var found: Button = null
	var count := 0
	for child: Node in battle.mission._buttons.get_children():
		if not child is Button: continue
		var candidate: Button = child as Button
		var descriptor: Dictionary = candidate.get_meta("campaign_presentation_v1", {})
		if descriptor.get("kind", "") != "level" or descriptor.get("button_id", "") != button_id: continue
		found = candidate
		count += 1
	check(count == 1, "actual chapter has exactly one selector " + button_id)
	return found if count == 1 else null

func _click_visible_selector(battle: Variant, button: Button, actor: Variant, label: String) -> void:
	var scroll: ScrollContainer = battle.mission._detail_scroll
	scroll.ensure_control_visible(button)
	for frame in range(2): await get_tree().process_frame
	var rect: Rect2 = button.get_global_rect()
	var visible: bool = button.is_visible_in_tree() and not button.disabled \
		and root.get_visible_rect().grow(1.0).encloses(rect) and scroll.get_global_rect().grow(1.0).encloses(rect)
	check(visible, label + ": real selector is scrolled fully into the visible task panel")
	if not visible: return
	var serial: int = actor._order_serial
	var activations := [0]
	var observer := func(): activations[0] += 1
	button.pressed.connect(observer)
	var point: Vector2 = rect.get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)
		await get_tree().process_frame
	if is_instance_valid(button) and button.pressed.is_connected(observer): button.pressed.disconnect(observer)
	check(activations[0] == 1 and battle.selection == [actor] and actor._order_serial == serial,
		label + ": viewport click selects the named actual actor once without issuing a movement order")

func _selector_languages(battle: Variant, phase_label: String, actor_keys: Array, expected_stage: int) -> bool:
	var localize: Variant = root.get_node("Localize")
	var original_language: String = localize.locale
	var original_expanded: bool = battle.mission._expanded
	var original_scroll: int = battle.mission._detail_scroll.scroll_vertical
	var original_selection: Array = battle.selection.duplicate()
	check(battle.phase == battle.Phase.FIGHT and battle.level.st == expected_stage,
		phase_label + ": selector audit starts in the naturally reached live chapter stage")
	if battle.phase != battle.Phase.FIGHT or battle.level.st != expected_stage: return false
	# Presentation changes only. Never reset a stage, actor position, order, clock
	# or wine flag. The actual scene continues running through this short audit.
	battle.mission._toggle.button_pressed = true
	for language: String in DISPLAY_LANGUAGES:
		check(localize.set_language(language, false), phase_label + ": selector language switched without saving preferences")
		for frame in range(2): await get_tree().process_frame
		var rows: Array = []
		for actor_key: String in actor_keys:
			var button_id := "hg_" + actor_key
			var button: Button = _selector_button(battle, button_id)
			var actor: Variant = battle.find_unit(actor_key)
			check(is_instance_valid(button) and alive(actor), phase_label + ": actual selector and actor exist for " + button_id)
			if not is_instance_valid(button) or not alive(actor): continue
			var actor_name: String = battle._defs[actor_key].name
			# Independent catalog expectation. Do not call Localize.format_text or
			# register phrases here: either could conceal a missing production alias.
			var expected: String = _catalog_text("选中 · %s", language) % _catalog_text(actor_name, language)
			var raw: String = button.text
			# Default Godot controls may retain a Chinese source property while
			# rendering a translation. Compare the engine translation, not raw text.
			var rendered: String = String(button.tr(raw))
			var expected_tip := _catalog_text("只选中并定位人物；移动与交互由你下令。", language)
			var rendered_tip: String = String(button.tr(button.tooltip_text))
			check(rendered == expected and not expected.is_empty(),
				"%s %s: complete actual selector caption translates prefix and person for %s" % [phase_label, language, actor_key])
			check(rendered_tip == expected_tip, "%s %s: selector tooltip translates for %s" % [phase_label, language, actor_key])
			await _click_visible_selector(battle, button, actor, "%s %s %s" % [phase_label, language, actor_key])
			rows.append({"button_id": button_id, "actor": actor_key, "source_name": actor_name,
				"raw_caption": raw, "engine_translated_caption": rendered, "expected_caption": expected,
				"raw_tooltip": button.tooltip_text, "engine_translated_tooltip": rendered_tip,
				"expected_tooltip": expected_tip})
		var screenshot: Dictionary = {}
		if language == "en": screenshot = await _story_screenshot("selectors_" + phase_label + "_en")
		check(battle.phase == battle.Phase.FIGHT and battle.level.st == expected_stage,
			phase_label + ": selector audit retains the naturally reached gameplay stage")
		selector_samples.append({"phase": phase_label, "language": language,
			"stage": battle.mission.stage_id, "buttons": rows, "screenshot": screenshot})
	check(localize.set_language(original_language, false), phase_label + ": original live route language restored")
	battle.mission._toggle.button_pressed = original_expanded
	battle.mission._detail_scroll.scroll_vertical = original_scroll
	battle.select_members(original_selection, false)
	for frame in range(2): await get_tree().process_frame
	return failures.is_empty()

func _show_start_intro(battle: Variant) -> bool:
	var localize: Variant = root.get_node("Localize")
	var original_language: String = localize.locale
	var lines: Array = battle.level.intro_lines()
	check(lines.size() == 3 and battle.phase == battle.Phase.INTRO and battle.hud._intro_root.visible,
		"actual opening presents the three authored segments before gameplay")
	if lines.size() != 3 or battle.phase != battle.Phase.INTRO or not battle.hud._intro_root.visible:
		return false
	for segment in range(lines.size()):
		for language: String in DISPLAY_LANGUAGES:
			check(localize.set_language(language, false), "opening language switched without persisting preference")
			for frame in range(2): await get_tree().process_frame
			var line: Dictionary = lines[segment]
			var expected_text := _catalog_text(String(line.text), language)
			# The shared speaker punctuation is intentionally language-neutral.
			var expected_name := "【%s】" % _catalog_text(String(line.who), language)
			var expected_button := _catalog_text("继续 ▸", language)
			check(battle.phase == battle.Phase.INTRO and battle.hud._intro_i == segment
				and battle.hud._intro_root.visible, "%s opening segment %d is the real current segment" % [language, segment + 1])
			check(battle.hud._intro_text.text == expected_text and battle.hud._intro_name.text == expected_name
				and battle.hud._intro_btn.text == expected_button, "%s opening segment %d actual name/body/button translate" % [language, segment + 1])
			var screenshot: Dictionary = {}
			if segment == 0: screenshot = await _story_screenshot("opening_" + language)
			intro_samples.append({"language": language, "segment": segment + 1, "source": line.text,
				"body": battle.hud._intro_text.text, "speaker": battle.hud._intro_name.text,
				"button": battle.hud._intro_btn.text, "screenshot": screenshot})
		# Use the existing continue button once per segment. Do not reset the
		# intro index, replay show_intro or manufacture deployment/gameplay.
		battle.hud._intro_btn.pressed.emit()
	check(not battle.hud._intro_root.visible and battle.phase == battle.Phase.DEPLOY,
		"three ordinary intro button presses reach actual deployment once")
	localize.set_language(original_language, false)
	return true

func _plain_report_translations(source: String) -> Dictionary:
	if report_catalog.has(source): return report_catalog[source]
	var entry: Variant = display_catalog.get(source)
	var present: bool = typeof(entry) == TYPE_DICTIONARY
	if present:
		for language: String in ["zh_TW", "en", "ja"]:
			present = present and typeof(entry.get(language)) == TYPE_STRING and not String(entry.get(language, "")).is_empty()
	check(present, "complete report source has four installed translations: " + source)
	if not present: return {}
	var translated: Dictionary = {}
	for language: String in DISPLAY_LANGUAGES:
		translated[language] = source if language == "zh_CN" else entry[language]
	report_catalog[source] = translated
	return translated

func _add_report_phrase(lookup: Dictionary, source: String, args: Array) -> void:
	# Independently render installed templates with plain %, deliberately never
	# filling Localize.format_text history or borrowing production phrase aliases.
	var templates: Dictionary = _plain_report_translations(source)
	if templates.is_empty(): return
	var translations: Dictionary = {}
	for language: String in DISPLAY_LANGUAGES:
		var values: Array = []
		for value: Variant in args:
			values.append(_plain_report_translations(String(value)).get(language, "") if value is String else value)
		translations[language] = String(templates[language]) % values
	for language: String in DISPLAY_LANGUAGES:
		var display: String = translations[language]
		check(not lookup.has(display) or lookup[display] == translations, "complete report finite phrase has an unambiguous translation")
		lookup[display] = translations

func _report_expectations(battle: Variant) -> Array:
	var lookup: Dictionary = {}
	var owners: Array = ["chao_gai", "wu_yong", "gongsun_sheng", "liu_tang", "ruan_xiaoer", "ruan_xiaowu", "ruan_xiaoqi"]
	for index in range(7):
		var actor_name: String = battle._defs[owners[index]].name
		var cart := index + 1
		var weight := 2 if index < 4 else 1
		_add_report_phrase(lookup, "%s · 第%d车（%d担）%s", [actor_name, cart, weight, "取车"])
		_add_report_phrase(lookup, "%s · 推第%d车装入%d担", [actor_name, cart, weight])
		_add_report_phrase(lookup, "%s · 推第%d车（%d担）出冈", [actor_name, cart, weight])
		_add_report_phrase(lookup, "%s接过第%d辆枣车，等你下令推到财物旁。", [actor_name, cart])
		_add_report_phrase(lookup, "第%d车弃枣，装入%d担财物并遮盖。", [cart, weight])
		_add_report_phrase(lookup, "%s推起第%d车，载%d担财物。", [actor_name, cart, weight])
		_add_report_phrase(lookup, "第%d车由%s推出黄泥冈，共载%d担。", [cart, actor_name, weight])
	var expected: Array = []
	for row: String in battle.mission.report:
		if lookup.has(row):
			expected.append(lookup[row])
		elif display_catalog.has(row):
			expected.append(_plain_report_translations(row))
		else:
			var translated: Dictionary = {}
			for source: String in display_catalog:
				if row not in display_catalog[source].values(): continue
				var candidate: Dictionary = _plain_report_translations(source)
				check(translated.is_empty() or translated == candidate, "actual static report entry has an unambiguous source")
				translated = candidate
			check(not translated.is_empty(), "actual report entry resolves without format history: " + row)
			expected.append(translated)
	check(expected.size() == 71 and battle.kills == 0 and battle._hero_end_tally().is_empty(),
		"the natural wine result has all 71 authored report entries and no invented kill tally")
	return expected

func _result_languages(battle: Variant, result: Dictionary) -> void:
	var localize: Variant = root.get_node("Localize")
	var original_language: String = localize.locale
	check(battle.phase == battle.Phase.END and battle.level.victory and battle.hud._end_root.visible,
		"language audit starts only after the actual natural victory result is visible")
	if battle.phase != battle.Phase.END or not battle.level.victory or not battle.hud._end_root.visible: return
	var initial_subtitle: String = battle.hud._end_sub.text
	var first_seal: bool = initial_subtitle.contains(localize.text("首次获得演义印"))
	var existing_seal: bool = initial_subtitle.contains(localize.text("演义印已收录"))
	check(first_seal != existing_seal, "actual settlement records exactly one first-or-existing story seal status")
	var seal_source := "首次获得演义印" if first_seal else "演义印已收录"
	var events: Array = battle.mission.events.keys().duplicate()
	var original_result: String = JSON.stringify(result)
	var score: int = battle.level.delivered
	var expected_rows: Array = _report_expectations(battle)
	for language: String in DISPLAY_LANGUAGES:
		check(localize.set_language(language, false), "result language switched without persisting preference")
		for frame in range(2): await get_tree().process_frame
		var campaign_line: String = _catalog_text("\n基础通关：%s", language) % _catalog_text("完成", language)
		campaign_line += _catalog_text("\n演义复现：%d/%d", language) % [int(result.story_done), int(result.story_total)]
		campaign_line += " · " + _catalog_text(seal_source, language)
		var expected_subtitle: String = _catalog_text("%s\n此役歼灭敌军 %d 人。%s", language) % [
			_catalog_text(WINE_WIN_LINE, language), battle.kills, campaign_line]
		var expected_report: String = _catalog_text("基础通关：%s", language) % _catalog_text("完成", language)
		expected_report += "\n" + (_catalog_text("演义复现：%d/%d%s", language) % [
			int(result.story_done), int(result.story_total), _catalog_text(" · 获得演义印", language)])
		var tally: String = battle.hud._end_tally.text
		var goal_rows: Array[String] = []
		var expected_goal_ids: Array = ["merchant_cover", "wine_scheme", "no_bloodshed", "all_safe"]
		check(result.goals.size() == 4 and result.done_ids == expected_goal_ids and result.contract_version == 3,
			language + ": full current contract retains four same-run goal records")
		for goal: Dictionary in result.goals:
			check(goal.id in expected_goal_ids and goal.state == "done" and goal.note.is_empty() and goal.reason.is_empty(),
				language + ": actual frozen goal is complete " + String(goal.id))
			goal_rows.append("✓ " + _catalog_text(String(goal.label), language))
		var expected_goal_text: String = _catalog_text("演义目标（可选） %d/%d\n%s", language) % [4, 4, "\n".join(goal_rows)]
		check(battle.mission._story.text == expected_goal_text, language + ": real Mission control rebuilds all four translated goal labels")
		check(battle.hud._end_title.text == _catalog_text("旗开得胜！", language)
			and battle.hud._end_sub.text == expected_subtitle, language + ": actual victory title/narrative/kills/core/progress/seal translate")
		check(tally.begins_with(_catalog_text("⚔ 各路好汉战绩 ⚔\n", language) + _catalog_text("任务战报\n", language))
			and tally.contains(expected_report)
			and tally.contains(_catalog_text("七辆江州车载十一担生辰纲出冈。", language)),
			language + ": actual task report includes translated core/progress/final departure")
		var actual_rows: PackedStringArray = tally.split("\n").slice(4)
		var row_mismatches: Array = []
		check(actual_rows.size() == expected_rows.size(), language + ": actual report retains all 71 rows in their original order")
		for index in range(expected_rows.size()):
			var expected_row: String = expected_rows[index].get(language, "")
			var actual_row: String = actual_rows[index] if index < actual_rows.size() else ""
			check(not expected_row.is_empty() and actual_row == expected_row,
				"%s: actual complete report row %d translates independently of recent format history" % [language, index + 1])
			if expected_row.is_empty() or actual_row != expected_row:
				row_mismatches.append({"row": index + 1, "expected": expected_row, "actual": actual_row})
		check(battle.hud._end_next.text == _catalog_text("下一关 ▸", language), language + ": actual next-chapter button translates")
		var screenshot: Dictionary = await _story_screenshot("result_" + language)
		check(battle.phase == battle.Phase.END and battle.level.delivered == score
			and battle.mission.events.keys() == events
			and JSON.stringify(battle.mission.result_snapshot(true)) == original_result,
			language + ": language and screenshot preserve the frozen natural result")
		result_samples.append({"language": language, "title": battle.hud._end_title.text,
			"subtitle": battle.hud._end_sub.text, "expected_subtitle": expected_subtitle,
			"report": tally, "expected_report_core": expected_report, "report_rows_checked": expected_rows.size(),
			"report_row_mismatches": row_mismatches, "full_goals":result.goals.duplicate(true),
			"goal_control_text":battle.mission._story.text, "goal_control_visible_at_settlement":battle.mission._story.is_visible_in_tree(), "screenshot": screenshot})
	localize.set_language(original_language, false)

func until(predicate: Callable, seconds: float) -> bool:
	var t:=0.0
	while not predicate.call() and t<seconds:
		await _wait(0.1); t+=0.1
	return bool(predicate.call())

func action(b,u,key: String,seconds:=35.0) -> bool:
	if not alive(u) or not b.mission.actions.has(key): return false
	var event:="action:%s:%s"%[b.mission.stage_id,key]
	# Carts now exist at entry. A fresh optional care order must really complete;
	# the already-recorded merchant setup event is not evidence of this order.
	if key=="place_dates": event="dates_checked" if b.mission.has_event("place_dates") else "place_dates"
	_action(b,u,key)
	var ok:=await until(func(): return b.mission.has_event(event) or b.phase==b.Phase.END,seconds)
	if not b.mission.has_event(event): print("[hns-action] timeout ",key," stage=",b.mission.stage_id," actor=",u.position," exposure=",b.level.exposure," controls=",b.mission.actions.keys())
	return ok and b.mission.has_event(event)

func shot(b,name: String,cell: Vector2i) -> void:
	if not visual: return
	b.camera.zoom=Vector2.ONE
	b.center_camera_cell(cell)
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	if b.phase==b.Phase.FIGHT:
		check(b.mission._panel.get_global_rect().end.y<=b.hud._bottom_panel.get_global_rect().position.y-6,"short chapter task panel avoids command cards")
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"saved "+name)

func _live(name: String) -> void:
	var b=await _start("",0)
	if b == null: return
	var l=b.level
	var original_load_ids: Array=l.bundles.map(func(u): return u.entity_id)
	var original_carts: Array=l.jujube_carts.duplicate()
	check(l.bundles.size()==11 and original_load_ids.size()==11,"eleven independent tribute loads deployed before live march")
	var start_orders:=orders
	var combat: Dictionary={}
	check(l.st==l.MARCH and l.convoy.size()>0 and l.convoy.size()<15 and not b._smoke and not b.economy,"convoy starts entering in sequence while merchants already rest")
	check(l.jujube_carts.size()==7 and l.actors.size()==7 and b.mission.has_event("place_dates") and b.find_unit("bai_sheng")==null,"seven merchants and original carts are present before Bai appears")
	if name == "wine":
		if not await _selector_languages(b, "opening", ["chao_gai", "liu_tang"], l.MARCH):
			cases.append({"route": name, "failed_stage": "opening_selectors"}); await _dispose(b); return
	var chao=b.find_unit("chao_gai")
	var before: Vector2=chao.position
	var serial: int=chao._order_serial
	var select_button=b.mission._buttons.get_children().filter(func(n): return n is Button and n.text==root.get_node("Localize").format_text("选中 · %s", [root.get_node("Localize").text("晁盖")]))
	if not select_button.is_empty(): select_button[0].pressed.emit()
	check(select_button.size()==1 and b.selection==[chao] and before==chao.position and serial==chao._order_serial,"selection shortcut selects without issuing movement")
	await shot(b,name+"_start",l.TOP)
	if name=="wine":
		check(await action(b,chao,"place_dates"),"Chao completes the optional cart care command without creating new carts")
		check(await until(func(): return l.st==l.INQUIRY,60) and l.convoy.size()==15 and b.mission.has_event("convoy_rested"),"all fifteen convoy members finish real arrival before inquiry")
		check(await until(func(): return b.mission.has_event("yang_inquired"),12),"Yang actually approaches the merchants before they answer")
		check(await action(b,b.find_unit("liu_tang"),"answer_yang"),"Liu answers Yang at the actual inquiry point")
		var bai=b.find_unit("bai_sheng")
		var bai_origin: Vector2=bai.position if is_instance_valid(bai) else Vector2.ZERO
		var arrival_orders:=orders
		check(is_instance_valid(bai) and l.bai_arrival_auto and bai._order_serial==l.bai_arrival_serial,"answer starts one automatic Bai arrival order")
		check(await until(func(): return is_instance_valid(bai) and bai.position.distance_to(bai_origin)>120,15) and l.st==l.ARRIVAL and bai.get_meta("carrying_wine",false),"Bai really carries wine along the road without a player bring-wine order")
		check(await until(func(): return l.st==l.WINE and b.mission.has_event("bai_unloaded"),50) and orders==arrival_orders and not l.bai_arrival_auto and l.bai_unload_t==0.0,"Bai automatically arrives and unloads without new player orders")
		if l.st!=l.WINE:
			var nearby: Array=[]
			for u in b.units:
				if is_instance_valid(bai) and u!=bai and u.position.distance_to(bai.position)<180:
					nearby.append({"key":u.key,"entity_id":u.entity_id,"cell":str(b.map.world_to_cell(u.position)),"radius":u.radius,"building":u.is_building,"hp":u.hp,"story":u.story_outcome})
			print("BAI_BASIC_STATE position=",bai.position," cell=",b.map.world_to_cell(bai.position)," auto=",l.bai_arrival_auto," state=",bai._state," serial=",bai._order_serial," owned_serial=",l.bai_arrival_serial," manual=",bai.manual_order_active," manual_t=",bai.manual_order_t," unload_t=",l.bai_unload_t)
			var facts: Dictionary={"route":name,"failed_stage":l.st,"bai_auto":l.bai_arrival_auto,"unload_t":l.bai_unload_t,"rest_t":l.rest_t,"exposure":l.exposure,"position":str(bai.position),"cell":str(b.map.world_to_cell(bai.position)),"goal":str(bai._home),"state":bai._state,"queue":str(bai._queue),"manual_active":bai.manual_order_active,"manual_t":bai.manual_order_t,"order_serial":bai._order_serial,"arrival_serial":l.bai_arrival_serial,"distance_to_unload":bai.position.distance_to(b.map.cell_to_world(l.WINE_UNLOAD)),"segment_open":b.map._segment_open(bai.position,b.map.cell_to_world(l.WINE_UNLOAD),bai.movement_profile),"ordinary_path_points":b.map.find_path(bai.position,b.map.cell_to_world(l.WINE_UNLOAD),bai.faction,bai.movement_profile).size(),"nearby":nearby,"events":b.mission.events.keys(),"rng_issue":b._gameplay_rng_issue}
			print("LIVE_ARRIVAL_DIAGNOSTIC ",facts)
			await shot(b,"wine_arrival_failed",l.WINE_UNLOAD)
			cases.append(facts); await _dispose(b); return
		if not await _selector_languages(b, "wine", ["liu_tang", "wu_yong", "bai_sheng"], l.WINE):
			cases.append({"route": name, "failed_stage": "wine_selectors"}); await _dispose(b); return
		_click(b,[b.find_unit("wu_yong")],l.WU_STATION)
		_click(b,[b.find_unit("bai_sheng")],l.BAI_STATION)
		check(await action(b,b.find_unit("liu_tang"),"taste_wine"),"first wine trial uses real Liu movement")
		check(await until(func(): return l._team_ready(b),20),"Wu and Bai can preposition without false suspicion")
		await shot(b,"wine_ready",l.SALE_WINE)
		check(await action(b,b.find_unit("liu_tang"),"distract_yang"),"Liu initiates the actual cooperative distraction")
		check(await until(func(): return l.drug_done or l.force_started,8) and l.drug_done,"three real participants complete one wine handoff")
		check(b.kills==0 and l.convoy.all(func(u): return u.hp>0 and u.story_outcome=="unconscious"),"all fifteen convoy members survive unconscious")
	if b.phase==b.Phase.END:
		cases.append({"route":name,"failed_phase":true}); await _dispose(b); return
	check(not b.mission.actions.has("cargo_group_plan") and not b.mission.actions.has("stage_0"),"cargo needs no planning or staging chores")
	var owners: Array=["chao_gai","wu_yong","gongsun_sheng","liu_tang","ruan_xiaoer","ruan_xiaowu","ruan_xiaoqi"]
	var carriers: Array=owners.map(func(key): return b.find_unit(key))
	if not carriers.all(func(u): return alive(u)):
		check(false,"all seven original Stars survive the live wine route"); await _dispose(b); return
	for i in range(7):
		check(b.mission.actions["force_take_%d_0"%i].actors==[owners[i]],"cart %d belongs to its Star, not Bai"%i)
		_action(b,carriers[i],"force_take_%d_0"%i)
	check(await until(func(): return l.empty_cargo.size()==7 or b.phase==b.Phase.END,55) and l.empty_cargo.size()==7,"seven Stars physically reach and take their seven original empty carts")
	if l.empty_cargo.size()!=7:
		print("EMPTY_TAKE_TIMEOUT ", l.empty_cargo, " actions=", b.mission.actions.keys()); await _dispose(b); return
	check(l.cargo.is_empty() and l.cargo_ready.is_empty() and l.delivered == 0,"taking empty carts does not load or credit cargo")
	check(l.jujube_carts==original_carts and l.jujube_carts.all(func(u): return u.visible),"taking empty carts preserves all seven original visible nodes")
	var empty_start: Vector2 = carriers[6].position
	var empty_cart_start: Vector2 = l.jujube_carts[6].position
	_action(b, carriers[6], "force_load_6_0")
	check(await until(func(): return carriers[6].position.distance_to(empty_start)>8.0 and l.jujube_carts[6].position.distance_to(empty_cart_start)>5.0, 6.0),"seventh original empty cart genuinely moves with its walking owner")
	check(l.empty_cargo.size()==7 and l.cargo.is_empty() and not l.cargo_ready.has(6),"empty in-transit checkpoint precedes actual loading")
	if not await checkpoint_save(b, "seventh_empty_cart_in_transit", true): await _dispose(b); return
	empty_checkpoint = checkpoint.duplicate(true)
	for i in range(7): _action(b,carriers[i],"force_load_%d_0"%i)
	check(await until(func(): return l.cargo.size()==7 or b.phase==b.Phase.END,75) and l.cargo.size()==7,"seven actual carts reach eleven tribute loads and finish real loading")
	if l.cargo.size()!=7:
		print("LOADING_TIMEOUT ",l.cargo," empty=",l.empty_cargo," actions=",b.mission.actions.keys()); await _dispose(b); return
	check(l.empty_cargo.is_empty() and l.jujube_carts==original_carts,"real loading clears empty ownership and preserves the same original cart objects")
	check(l.bundles.map(func(u): return u.entity_id)==original_load_ids and l.bundles.all(func(u): return not b.units.has(u) and not u.visible and u.get_parent()==b.units_root),"all eleven original loads are scene-owned and stowed without replacement")
	var idle_positions: Array=carriers.map(func(u): return u.position)
	await _wait(1)
	check(range(7).all(func(i): return carriers[i].position.distance_to(idle_positions[i])<3),"loaded Stars wait for a separate player exit order")
	await shot(b,"wine_seven_loaded",l.TOP)
	# The seventh cart starts via its actual marker order; the remaining six
	# stay idle. Freeze this naturally reached in-transit state for a new PID.
	_action(b, carriers[6], "force_deliver_6_0")
	check(await until(func(): return carriers[6].position.distance_to(idle_positions[6]) > 8.0, 4.0), "seventh cart is physically in transit before checkpoint")
	check(l.delivered == 0 and l.cargo.size() == 7, "checkpoint remains seven carried carts with no credited delivery")
	if not await checkpoint_save(b, "seventh_cart_in_transit", true): await _dispose(b); return
	for i in range(7): _action(b,carriers[i],"force_deliver_%d_0"%i)
	await _wait(0.5)
	check(carriers.all(func(u): return u._state==u.ST_MOVE),"seven loaded carts move concurrently on player orders")
	var bai=b.find_unit("bai_sheng")
	_click(b,[bai],l.GATE_W)
	var wait_seconds:=0.0
	var last_score:=-1
	while l.delivered<11 and b.phase==b.Phase.FIGHT and wait_seconds<85:
		var delivered_carts: Array=l._delivered_cart_indices(b)
		var actual_score:=0
		for index in delivered_carts: actual_score+=2 if int(index)<4 else 1
		var physical: int=l.jujube_carts.filter(func(u): return is_instance_valid(u) and u.visible).size()+l.cargo.size()
		for i in range(7):
			if bool(l.cargo_ready.get(i,false)) and b.units.has(l.bundles[i]): physical+=1
		if l.delivered!=last_score:
			ledger_samples.append({"game_seconds":b.mission.total_game_seconds,"delivered_loads":l.delivered,"cart_events":delivered_carts.duplicate(),"expected_weighted_score":actual_score,"physical_carts":physical,"stage":l.st})
			check(l.delivered==actual_score and physical==7,"live delivered score %d matches independent cart weights and preserves seven carts"%l.delivered)
			check(l.delivered==11 or l.st==l.CARRY,"partial live cargo never enters withdrawal early")
			last_score=l.delivered
		await _wait(0.1);wait_seconds+=0.1
	check(l.delivered==11 and l._delivered_cart_indices(b).size()==7,"all seven carts physically reach their west markers with exactly eleven loads")
	if l.delivered!=11:
		print("[seven-live-exit] cargo=",l.cargo," actors=",carriers.map(func(u): return [u.key,b.map.world_to_cell(u.position),u._state,u.mission_order_active])," actions=",b.mission.actions.keys());await _dispose(b);return
	if b.phase==b.Phase.FIGHT:_click(b,l.actors.filter(func(u): return alive(u)),l.GATE_W+Vector2i(-2,0))
	check(await until(func(): return l.victory or b.phase==b.Phase.END,40) and l.victory,"all eight surviving companions regroup through actual movement")
	var terminal_ready: bool = await wait_natural_terminal(b)
	if not terminal_ready: return
	var result: Dictionary=b.mission.result_snapshot(l.victory)
	check(l.delivered==11 and range(7).all(func(i): return b.units.has(l.bundles[i]) and l.bundles[i].visible) and range(7,11).all(func(i): return not b.units.has(l.bundles[i]) and not l.bundles[i].visible),"seven original ground carts visible, four packed secondary loads stay hidden")
	check(l.bundles.map(func(u): return u.entity_id)==original_load_ids,"all eleven original IDs survive full natural wine and cargo flow")
	if name=="wine": check(result.story_complete,"wine route earns all four optional story goals")
	else: check(not result.story_complete and b.mission.has_event("huangnigang_all_safe")==l.actors.all(func(u): return alive(u)),"force route credits actual survivors without inventing wine or all-safe goals")
	if not verify_terminal(b, result): return
	if name == "wine": await _result_languages(b, result)
	else: await shot(b,name+"_result",l.GATE_W)
	check(cfg_snapshot() == terminal_checkpoint.cfg and lifecycle_row(b._continue_receipt) == terminal_checkpoint.lifecycle
		and rewards_snapshot() == terminal_checkpoint.rewards, "four language rebuilds preserve CFG lifecycle and rewards")
	cases.append({"route":name,"orders":orders-start_orders,"seconds":b.mission.total_game_seconds,"result":result,"events":b.mission.events.keys(),"alive":l.actors.filter(func(u): return alive(u)).size(),"combat":combat})
	# Keep the actual terminal scene until reporting; no replay or next chapter.

func _run() -> void:
	check(OS.get_environment("CH_MODE") == "natural_terminal", "natural terminal worker mode")
	AudioServer.set_bus_mute(0, true)
	root.get_node("Settings").edge_scroll = false
	Engine.time_scale = 1.0
	root.get_node("Settings").game_speed = 1.0
	visual = DisplayServer.get_name() != "headless"
	check(visual, "real graphical renderer is required for production texture capture")
	var output: String = OS.get_environment("CH_OUTPUT_ROOT").replace("\\", "/").simplify_path()
	check(output.is_absolute_path(), "stage output directory is absolute")
	if not failures.is_empty(): report(); return
	folder = output.path_join("screenshots")
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "stage screenshot directory created")
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	root.get_node("Localize").set_language("zh_CN", false)
	if not identity(OS.get_environment("CH_SOURCE_MODE") != "0"): report(); return
	var startup_ok: bool = await wait_startup()
	if not startup_ok: report(); return
	var initial_slot: Dictionary = Store.new(SLOT).inspect_slot()
	check(initial_slot.ok and not initial_slot.exists and int(initial_slot.revision) == 0, "fresh private profile starts without a continue slot")
	var campaign: Node = root.get_node("Campaign")
	check(campaign.records.is_empty() and campaign.unlocked == 1 and campaign.cloud_owner.is_empty(), "fresh offline profile has no prior chapter record or seal")
	initial_progress = cfg_snapshot()
	initial_rewards = rewards_snapshot()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
	check(typeof(parsed) == TYPE_DICTIONARY, "actual installed four-language catalog is readable")
	if not failures.is_empty(): report(); return
	display_catalog = parsed
	await _live("wine")
	var identity_ok: bool = identity(OS.get_environment("CH_SOURCE_MODE") != "0")
	check(cases.size() == 1 and cases[0].get("result", {}).get("core_cleared", false)
		and cases[0].result.story_complete, "one natural seven-cart wine route completes core and four current goals")
	check(checkpoint.get("generation") == 2 and empty_checkpoint.get("generation") == 1
		and checkpoint.get("binding", {}) == empty_checkpoint.get("binding", {}), "both checkpoints retain the fixed slot and campaign token")
	check(not terminal_checkpoint.is_empty() and terminal_checkpoint.get("lifecycle", {}).get("generation") == 3,
		"same-token campaign transaction reaches durable applied generation three")
	check(intro_samples.size() == 12 and result_samples.size() == 4, "one natural route covers opening and actual end HUD in all four languages")
	check(selector_samples.size() == 8, "opening and wine selectors retain four-language actual input coverage")
	report({"scope":"Natural seven-cart wine ending, full current goals and context-bound gen1/gen2/CFG/gen3 only",
		"cases":cases, "ledger_samples":ledger_samples, "empty_checkpoint":empty_checkpoint,
		"opening_language_samples":intro_samples, "result_language_samples":result_samples, "selector_language_samples":selector_samples,
		"full_frozen_goals_preserved":not terminal_checkpoint.is_empty(), "display_route_replays":0,
		"result_or_story_state_injected":false, "actor_or_convoy_position_injected":false, "cargo_or_drug_state_injected":false,
		"slot_or_profile_copied":false, "full_art_accepted":false, "identity_gate_passed":identity_ok,
		"second_process_rejection_verified_by_this_worker":false})
