extends RefCounted
## Read-only geometry/interaction-contract audit. Run after three settled UI frames.
## The caller owns isolated profiles, scenario setup, viewport sizes and screenshots.

func audit(hud: HUD) -> Dictionary:
	var checks: Array = []
	var failures: Array = []
	var geometry := {}
	var record := func(name: String, ok: bool, detail = "") -> void:
		var entry := {"name": name, "ok": ok, "detail": str(detail)}
		checks.append(entry)
		if not ok:
			failures.append(entry)
	if not is_instance_valid(hud) or hud.battle == null:
		return {"ok": false, "checks": [], "failures": ["HUD_UNAVAILABLE"], "geometry": {}}
	var vp := hud.get_viewport().get_visible_rect().size
	var safe := hud._logical_safe_insets()
	var safe_rect := Rect2(Vector2(safe.x, safe.y), vp - Vector2(safe.x + safe.z, safe.y + safe.w))
	geometry["viewport"] = str(vp)
	geometry["safe"] = str(safe_rect)
	var card := hud._skill_rail_contract()
	if hud.touch_ui:
		var fps: Label = hud._fps_label
		record.call("fps_exists", is_instance_valid(fps))
		if is_instance_valid(fps):
			var fps_rect := fps.get_global_rect()
			geometry["fps"] = str(fps_rect)
			record.call("fps_visible", fps.is_visible_in_tree() and fps.modulate.a > 0.01 and fps.self_modulate.a > 0.01)
			record.call("fps_text_present", fps.text.begins_with("FPS ") and fps_rect.size.x > 0.0 and fps_rect.size.y > 0.0, fps.text)
			record.call("fps_in_safe_area", safe_rect.grow(0.5).encloses(fps_rect), fps_rect)
			for named in [["menu", hud._menu_btn], ["rail", hud._skill_rail],
				["resources", hud._res_bar], ["top_status", hud.top_label]]:
				var control: Control = named[1]
				if is_instance_valid(control) and control.is_visible_in_tree() and control.get_global_rect().has_area():
					record.call("fps_avoids_" + String(named[0]), not fps_rect.intersects(control.get_global_rect()), control.get_global_rect())
		for row in [hud._touch_actions, hud._touch_groups]:
			if not is_instance_valid(row) or not row.is_visible_in_tree():
				continue
			for control in row.get_children():
				if control.is_visible_in_tree():
					record.call("touch_button_safe_" + str(control.get_instance_id()), safe_rect.grow(0.5).encloses(control.get_global_rect()), control.get_global_rect())
		if hud._touch_actions.is_visible_in_tree() and hud._touch_groups.is_visible_in_tree():
			record.call("touch_groups_and_actions_separate", not hud._touch_actions.get_global_rect().intersects(hud._touch_groups.get_global_rect()))
		for named in [["menu", hud._menu_btn], ["actions", hud._touch_actions],
			["items", hud._inventory_popup], ["messages", hud._info_panel],
			["items_toggle", hud._inventory_toggle], ["messages_toggle", hud._info_toggle],
			["stats_toggle", hud._combat_stats_toggle]]:
			var control: Control = named[1]
			if is_instance_valid(control) and control.is_visible_in_tree():
				var rect := control.get_global_rect()
				record.call(String(named[0]) + "_in_safe_area", safe_rect.grow(0.5).encloses(rect), rect)
		record.call("all_hero_slots_visible", bool(card.all_slots), card)
		record.call("pure_passives_not_castable", bool(card.passives_read_only), card)
		var rail: Rect2 = hud._skill_rail.get_global_rect()
		geometry["rail"] = str(rail)
		# A portrait plus four skill targets must retain 48px hit areas. On
		# unusually narrow safe rectangles this floor takes priority over 25%.
		var target_floor := 48.0 * 5.0 + 4.0 * 4.0
		var rail_width_limit := maxf(safe_rect.size.x * 0.25, target_floor)
		geometry["rail_width_fraction"] = rail.size.x / maxf(1.0, safe_rect.size.x)
		geometry["rail_width_limit"] = rail_width_limit
		record.call("rail_quarter_safe_width", rail.size.x <= rail_width_limit + 1.0, [rail.size.x, rail_width_limit])
		record.call("rail_in_safe_area", safe_rect.encloses(rail), rail)
		record.call("rail_right_pinned", absf(rail.end.x - (vp.x - safe.z - 10.0)) < 1.1, rail.end.x)
		var blockers := hud._skill_rail_avoidance_contract()
		record.call("rail_avoids_overlays", bool(blockers.avoids), blockers.collisions)
		if is_instance_valid(hud._menu_btn):
			record.call("rail_below_menu", rail.position.y >= hud._menu_btn.get_global_rect().end.y + 7.5)
		var action_top := vp.y - safe.w - 166.0 - 72.0
		record.call("rail_above_action_band", rail.end.y <= action_top - 7.5, rail.end.y)
		var slot_count := 0
		var portraits := 0
		for row in hud._skill_rail.get_children():
			for child in row.get_children():
				if child is HUD.HeroSlotButton:
					slot_count += 1
					var r: Rect2 = child.get_global_rect()
					record.call("skill_%d_inside_rail" % slot_count, rail.grow(0.5).encloses(r), r)
					record.call("skill_%d_touch_target" % slot_count, r.size.x >= 48.0 and r.size.y >= 48.0, r.size)
					record.call("skill_%d_hotkey" % slot_count, child.hotkey != "", child.hotkey)
					if is_instance_valid(child.hero) and child.hero.can_learn(child.slot):
						record.call("skill_%d_upgrade_hit_matches_draw" % slot_count, child._is_learn_hit(child._learn_plus_center()))
				else:
					portraits += 1
		geometry["slots"] = slot_count
		geometry["portraits"] = portraits
		record.call("one_portrait_per_row", portraits == hud._skill_rail.get_child_count(), portraits)
		if portraits == 6:
			record.call("six_hero_twenty_four_slots", slot_count == 24, slot_count)
		if hud._inventory_popup.visible and hud._info_panel.visible:
			record.call("items_and_messages_separate", not hud._inventory_popup.get_global_rect().intersects(hud._info_panel.get_global_rect()))
		var active: Unit = hud.battle.active_unit()
		if is_instance_valid(active) and active.is_hero:
			var duplicate_skills := 0
			for child in hud._skill_bar.get_children():
				if child is HUD.HeroSlotButton:
					duplicate_skills += 1
			record.call("touch_bottom_no_duplicate_skills", duplicate_skills == 0, duplicate_skills)
	else:
		var active: Unit = hud.battle.active_unit()
		if is_instance_valid(active) and active.is_hero:
			var slots := 0
			for child in hud._skill_bar.get_children():
				if child is HUD.HeroSlotButton:
					slots += 1
			record.call("desktop_skills_preserved", slots == active.slot_count(), slots)
	return {"ok": failures.is_empty(), "checks": checks, "failures": failures, "geometry": geometry}
