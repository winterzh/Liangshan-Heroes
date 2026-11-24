extends "res://scripts/levels/level7_kuaihuolin.gd"
## Current short duel: optional road preparation and a live, finite counter window.
const ATTACK_PER_DRINK := 5
const HEAVY_RADIUS := 78.0
const RUSH_WIDTH := 92.0
const MIN_RUSH_TRAVEL := 0.01
const ROAD_DRINK_BUTTON := "forest_road_drink"
const ROAD_PROVOKE_BUTTON := "forest_road_provoke"
const DUEL_FOOTWORK_STATUS := "玉环步加速后仍需下令换位。看清起手，避开后靠近用鸳鸯脚。"
var controls_generation:=-1
var charge_running:=false
var opening_serial:=-1
var step_serial:=-1
var step_origin:=Vector2.ZERO
var counter_hits:=0
var victory:=false

func paint_map(map: GameMap) -> void:
	super.paint_map(map)
	# The open east gate and the heroes share the same road axis. Carry the road
	# through its threshold instead of leaving four unconnected courtyard cells.
	map.paint_path([Vector2(2,19),Vector2(START_E.x,START_E.y)],1,T.ROAD)

func story_contract_version() -> int: return 2
func deploy_hint() -> String:
	return "可沿途饮酒，也可直接向蒋门神下达攻击令。玉环步加速后还需下移动令，躲开重拳或冲撞，再靠近用鸳鸯脚反击。用「稳住酒势」可回血，施恩宜留在安全处。"

func apply_overrides(defs: Dictionary, abilities: Dictionary) -> void:
	super.apply_overrides(defs,abilities)
	abilities.mengzhou_step.desc="短时加速，仍需下移动令换位。躲开重拳或冲撞后，趁破绽靠近用鸳鸯脚反击。"
	abilities.mengzhou_punch.desc="近身直拳，造成伤害并短暂僵直；蓄力重拳和冲撞仍需看预警走位。"
	abilities.mengzhou_kick.desc="近身连踢。当前破绽期间，玉环步实际换位后踢中，才能完成招牌拳路。"

func on_start(b) -> void:
	super.on_start(b)
	if not b._gameplay_rng_issue.is_empty(): return
	controls_generation=-1; charge_running=false; opening_serial=-1; step_serial=-1
	counter_hits=0; victory=false
	_road_actions(b)
	b.mission.enable_scrolling()
	_sync_controls(b)

func _road_actions(b) -> void:
	b.mission.begin("road_choice","沿途准备 · 饮酒或径赴快活林", "每处可饮三碗，增强拳力，但步速和出手会波动。饮满四处可得演义印。第二家旁可练玉环步：用技能加速，再下令移动。")
	for i in range(taverns.size()):
		if not taverns[i].drunk: b.mission.add_action("drink_%d"%i,Localize.format_text("武松 · 第%d家三碗", (i+1)),TAVERN_CELLS[i]+Vector2i(0,2),["wu_song"],0.8,48)
	if not b.mission.has_event("road_step_practiced"):
		b.mission.add_action("practice_step","可选 · 官道旁试一次换步",Vector2i(25,19),["wu_song"],0.5,40)
	b.mission.add_action("provoke",Localize.text("武松 · 店前佯醉换酒"),KUAIHUO+Vector2i(-2,1),["wu_song"],0.8,48)
	refresh_road_controls(b)

func on_mission_action(b, action_id: String, actor) -> void:
	if action_id.begins_with("drink_"):
		var i:=int(action_id.trim_prefix("drink_"))
		if st!=ROAD or actor!=wu or i<0 or i>=taverns.size() or taverns[i].drunk: return
		taverns[i].drunk=true; drunk+=1
		wu._base_atk+=ATTACK_PER_DRINK; wu.atk+=ATTACK_PER_DRINK; wu.heal(35)
		if steady_left<=0: _apply_wine_speed()
		b.mission.mark(action_id,Localize.format_text("第%d家酒望吃足三碗；现共%d家，拳力增强，酒势也更不稳。", [i+1,drunk]))
		b.mission.set_status(Localize.format_text("已饮%d/4家：可继续沿路，或直接去快活林。", drunk))
		refresh_road_controls(b)
	elif action_id=="practice_step":
		if st!=ROAD or actor!=wu: return
		_start_step_drill(b)
	elif action_id=="provoke":
		if st==ROAD and actor==wu: _open_showdown(b,true)
	else:
		super.on_mission_action(b,action_id,actor)
		if not b._gameplay_rng_issue.is_empty(): return
		if action_id=="restore_shop" and b.mission.has_event("restore_shop"): victory=true
	_sync_controls(b)
	_sync_shop_controls(b)

func _start_step_drill(b) -> void:
	st=STEP_DRILL
	drill_origin=wu.position
	drill_marker=DuelTell.new()
	drill_marker.position=drill_origin
	drill_marker.z_index=3449
	b.fx_root.add_child(drill_marker); b.map.sync_render_position(drill_marker)
	b.mission.begin("road_step_drill","试一次横移 · 此处不受伤","让武松走出圆圈。玉环步可加速，移动方向由你指定。练过后可继续饮酒或直接去挑战。")

func _complete_step_drill(b, source: String) -> void:
	if st!=STEP_DRILL or wu.position.distance_to(drill_origin)<=94: return
	st=ROAD
	if is_instance_valid(drill_marker): drill_marker.queue_free()
	drill_marker=null
	b.mission.mark("road_step_practiced",Localize.format_text("武松实际离开重拳落点，试过横移（%s）。", source))
	_road_actions(b)

func _open_showdown(b, original_provocation:=false) -> void:
	if st in [SHOWDOWN,RETURN_SHOP]: return
	if is_instance_valid(drill_marker): drill_marker.queue_free()
	drill_marker=null
	super._open_showdown(b,original_provocation)
	if not b._gameplay_rng_issue.is_empty(): return
	charge_running=false; opening_serial=-1; step_serial=-1
	fist_cd=3.0
	b.mission.set_objective("重拳蓄力时离开圆圈，冲撞起手时横移让路。用玉环步加速后下令换位，再趁破绽靠近使出鸳鸯脚。迎面直拳适合近身，「稳住酒势」可回血。让施恩留在后方。")
	_sync_controls(b)

func on_ability(b, caster, ability_id: String, lp: Vector2) -> bool:
	if caster!=wu: return false
	if ability_id=="mengzhou_step":
		step_serial=special_index if st==SHOWDOWN else -1
		step_origin=wu.position
		b.mission.mark("mengzhou_step_used","武松踏玉环步；接着下令换位。")
		return false
	if ability_id in ["mengzhou_punch","mengzhou_kick"]:
		var spec: Dictionary=b._scaled_ability(b._abilities[ability_id],b._hero_rb(wu),b._hero_db(wu))
		var in_range: bool=is_instance_valid(menshen) and menshen.story_outcome=="" and wu.position.distance_to(menshen.position)<=float(spec.radius)
		if in_range:
			var signature: bool=ability_id=="mengzhou_kick" and _signature_footwork_ready()
			_verify_hit.call_deferred(b,menshen,menshen.hp+menshen._shield,signature,exposed_left>0,ability_id)
		else:
			b.msg("拳脚落空：先靠近蒋门神再出招。",2.5)
		return false
	if ability_id=="mengzhou_breath": return super.on_ability(b,caster,ability_id,lp)
	return false

func _signature_footwork_ready() -> bool:
	return exposed_left > 0 and step_serial == opening_serial and wu.position.distance_to(step_origin) >= 24

## Derived from the live duel; drawing adds no nodes, timers or saved state.
func counter_window_state(b) -> Dictionary:
	if st != SHOWDOWN or exposed_left <= 0 or not is_instance_valid(wu) or wu.hp <= 0 or not is_instance_valid(menshen) or menshen.hp <= 0 or menshen.story_outcome != "": return {}
	var spec: Dictionary=b._scaled_ability(b._abilities["mengzhou_kick"],b._hero_rb(wu),b._hero_db(wu))
	var kick_remaining := maxf(0.0, float(wu.ability_slots[2].get("cd_t",0.0))) if wu.slot_count() > 2 else 0.0
	return {"remaining":exposed_left,"fraction":clampf(exposed_left/(2.8 if special_kind=="rush" else 2.2),0,1),
		"footwork":_signature_footwork_ready(),"in_range":wu.position.distance_to(menshen.position)<=float(spec.radius),
		"kick_cooldown":kick_remaining,"position":menshen.position}

func _counter_status(b) -> String:
	if not is_instance_valid(wu) or not is_instance_valid(menshen) or not b.is_visible_world(menshen.position):
		return Localize.format_text("当前破绽 %.1f秒 · 反击命中%d次", [exposed_left, counter_hits])
	var slot := 2
	if not wu.slot_ready(slot):
		slot = 0
		if not wu.slot_ready(slot):
			return Localize.format_text("破绽 %.1f秒 · 拳脚暂不可用", exposed_left)
	var ability_id: String = wu.ability_slots[slot].id
	var spec: Dictionary = b._scaled_ability(b._abilities[ability_id], b._hero_rb(wu), b._hero_db(wu))
	var key := "" if b.hud.touch_ui else Settings.key_label("command_%d" % slot) + " "
	var source := "破绽 %.1f秒 · %s%s反击" if wu.position.distance_to(menshen.position) <= float(spec.radius) else "破绽 %.1f秒 · 靠近后用%s%s"
	return Localize.format_text(source, [exposed_left, key, String(spec.name)])

func _apply_wine_speed() -> void:
	if drunk>0: wu.start_drunk(maxf(0.64,1.0-0.09*drunk),1.08,999)

func _wine_hint() -> String:
	if drunk<=0 or st not in [ROAD,STEP_DRILL,SHOWDOWN]: return ""
	var bonus := drunk*ATTACK_PER_DRINK
	if steady_left>0:
		return Localize.format_text("饮酒%d/4家 · 普攻+%d · 步履已稳 %.1f秒",[drunk,bonus,steady_left])
	return Localize.format_text("饮酒%d/4家 · 普攻+%d · 酒势速度倍率%d–%d%%",
		[drunk,bonus,roundi(wu._drunk_lo*100),roundi(wu._drunk_hi*100)])

func unit_tactical_hint(b, actor) -> String:
	if actor != wu and actor != menshen: return ""
	var state := counter_window_state(b)
	if state.is_empty() or not b.is_visible_world(menshen.position):
		return _wine_hint() if actor==wu else ""
	var next_step := "本次尚未踏玉环步" if step_serial != opening_serial else ("玉环步后还需实际换位" if not state.footwork else "本次换步已完成")
	var reach := "已在出脚距离" if state.in_range else "先靠近蒋门神"
	var cooldown := Localize.format_text("鸳鸯脚冷却 %.1f秒",state.kick_cooldown) if state.kick_cooldown>0 else Localize.text("鸳鸯脚已就绪")
	return Localize.text(next_step)+" · "+Localize.text(reach)+" · "+cooldown

func draw_tactical_overlay(b, canvas: Node2D) -> void:
	if b.phase != b.Phase.FIGHT or not is_instance_valid(menshen) or not b.is_visible_world(menshen.position): return
	var state := counter_window_state(b)
	if state.is_empty(): return
	var point: Vector2 = b.to_screen(state.position)
	var color := Color("90efb0")
	canvas.draw_arc(point,32,0,TAU,40,Color(0.04,0.12,0.08,0.9),5)
	canvas.draw_arc(point,32,-PI/2,-PI/2+TAU*state.fraction,40,color,3)
	# Inward brackets distinguish an opening from the outward attack warning.
	for angle in [0.0,PI/2,PI,PI*1.5]:
		var direction := Vector2.from_angle(angle)
		var side := direction.orthogonal()
		canvas.draw_polyline(PackedVector2Array([point+direction*43+side*5,point+direction*37,point+direction*43-side*5]),color,2)
	var label := Localize.format_text("反击窗口 %.1f秒",state.remaining)
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
	canvas.draw_rect(Rect2(point+Vector2(-width/2-6,-94),Vector2(width+12,23)),Color(0.025,0.06,0.035,0.94))
	canvas.draw_string(font,point+Vector2(-width/2,-77),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)

func _verify_hit(b, target, before: float, signature: bool, counter: bool, ability_id: String) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree() or b.level!=self or not is_instance_valid(target): return
	# The nonlethal outcome clamps the finishing hit back to one HP. It is
	# still a real hit even when the target already had exactly one HP.
	if target.hp+target._shield>=before and target.story_outcome!="subdued": return
	if counter:
		counter_hits+=1
		b.mission.mark("counter_hit","拳脚实际击中当前破绽。")
		b.msg("反击命中！",1.8)
	if signature:
		step_serial=-1
		b.mission.mark("mengzhou_signature","趁这次失势，武松实际踏步换位，再以鸳鸯脚踢中蒋门神。")
		b.msg("玉环步接鸳鸯脚！",3)
	elif ability_id=="mengzhou_kick" and counter:
		b.msg("鸳鸯脚击中破绽；招牌拳路还需在这次攻防中用W实际换位。",3)

func process(b, delta: float) -> void:
	if not is_instance_valid(wu) or wu.hp<=0 or not is_instance_valid(shi) or shi.hp<=0:
		b.lose("武松或施恩倒下，夺回酒店失败。")
		return
	if steady_left>0:
		steady_left=maxf(0,steady_left-delta)
		if steady_left<=0: _apply_wine_speed()
	if st==STEP_DRILL and wu.position.distance_to(drill_origin)>94: _complete_step_drill(b,"manual_step")
	if st in [ROAD,STEP_DRILL]:
		if menshen.story_outcome=="subdued": _set_menshen_subdued(b)
		elif menshen.hp<menshen.max_hp-0.5 or wu._target==menshen: _open_showdown(b,false)
	elif st==SHOWDOWN and menshen.story_outcome=="":
		_duel_tick(b,delta)
	_sync_controls(b)
	_sync_shop_controls(b)

func _duel_tick(b, delta: float) -> void:
	if charge_running:
		if menshen._charge_dash>0 or menshen._charge_t>0: return
		charge_running=false
		_finish_special(b,not menshen._charge_hit.has(wu) and not menshen._charge_hit.has(shi))
		menshen.order_attack(wu)
		return
	if exposed_left>0:
		exposed_left=maxf(0,exposed_left-delta)
		if exposed_left<=0:
			opening_serial=-1; step_serial=-1
			menshen.apply_damage_reduction(0.5,999,BRACE_SOURCE)
			b.mission.set_status(DUEL_FOOTWORK_STATUS)
		else:
			b.mission.set_status(_counter_status(b))
		return
	if fist_windup>0:
		fist_windup=maxf(0,fist_windup-delta)
		if is_instance_valid(fist_marker):
			fist_marker.progress=1.0-fist_windup/(1.6 if special_kind=="heavy" else 1.25)
			fist_marker.queue_redraw()
		if fist_windup>0: return
		if special_kind=="rush":
			var travel: Vector2=rush_end-rush_from
			if travel.length()<=MIN_RUSH_TRAVEL:
				_finish_special(b,true,false)
				menshen.order_attack(wu)
				return
			menshen.remove_meta("story_pose")
			menshen._begin_charge(travel,64,0,travel.length(),RUSH_WIDTH,0.65,0.9,false,"mengzhou_menshen_rush")
			charge_running=true
		else:
			var hit:=false
			for actor in [wu,shi]:
				if actor.position.distance_to(fist_at)<=HEAVY_RADIUS and b.map._segment_open(menshen.position,actor.position,"land"):
					hit=true; actor.take_damage(56,menshen); actor.apply_stun(0.9)
			_finish_special(b,not hit)
		return
	fist_cd-=delta
	b.mission.set_status(DUEL_FOOTWORK_STATUS)
	if fist_cd<=0 and menshen.position.distance_to(wu.position)<145 and b.map._segment_open(menshen.position,wu.position,"land"):
		_begin_special(b)

func _begin_special(b) -> void:
	fist_cd=6.2; special_index+=1
	special_kind="heavy" if special_index%2==1 else "rush"
	step_serial=-1; opening_serial=-1
	fist_at=wu.position; rush_from=menshen.position
	rush_end=b.map.limit_displacement(rush_from,rush_from+rush_from.direction_to(wu.position)*190,"land")
	fist_windup=1.6 if special_kind=="heavy" else 1.25
	menshen.apply_stun(fist_windup+0.1)
	menshen._face_dir(wu.position-menshen.position,true)
	menshen.set_meta("story_pose","windup" if special_kind=="heavy" else "rush_windup")
	fist_marker=DuelTell.new()
	fist_marker.kind=special_kind
	fist_marker.extent=rush_from.distance_to(rush_end)
	fist_marker.set_meta("tell_kind",special_kind)
	fist_marker.position=fist_at if special_kind=="heavy" else rush_from
	if special_kind=="rush": fist_marker.rotation=(rush_end-rush_from).angle()
	fist_marker.z_index=3449
	b.fx_root.add_child(fist_marker); b.map.sync_render_position(fist_marker)
	b.msg("沉肩重拳：离开圆圈！" if special_kind=="heavy" else "俯身冲撞：横移让路！",2)

func _finish_special(b, missed: bool, record_dodge := true) -> void:
	_clear_tell()
	menshen.remove_meta("story_pose")
	if missed:
		opening_serial=special_index
		exposed_left=2.8 if special_kind=="rush" else 2.2
		menshen._damage_reduction_sources.erase(BRACE_SOURCE)
		menshen._refresh_damage_reduction()
		menshen.apply_stun(exposed_left)
		b.mission.set_status(_counter_status(b))
		if record_dodge:
			dodged=true
			if special_kind=="heavy": heavy_dodges+=1
			else: rush_dodges+=1
			b.mission.mark("dodge_"+special_kind,Localize.text("蒋门神本次招式落空，架势松动。"))
			b.msg("招式落空！",2)
		else:
			b.msg("冲撞被地形挡住，趁机反击。",2)
	else:
		step_serial=-1
		menshen.apply_stun(0.55)
		b.msg("重拳命中：下次离开圆圈。" if special_kind=="heavy" else "冲撞命中：下次横移让路。",2.5)

func _clear_tell() -> void:
	if is_instance_valid(fist_marker): fist_marker.queue_free()
	fist_marker=null

func _set_menshen_subdued(b) -> void:
	charge_running=false; opening_serial=-1; fist_windup=0; exposed_left=0
	step_serial=-1
	menshen._charge_t=0; menshen._charge_dash=0
	menshen.remove_meta("story_pose")
	_clear_tell()
	super._set_menshen_subdued(b)
	_sync_controls(b)
	_sync_shop_controls(b)

func _sync_controls(b) -> void:
	if controls_generation==b.mission._generation: return
	controls_generation=b.mission._generation
	b.mission.add_level_button("forest_wu",Localize.format_text("选中 · %s",wu.display_name))
	b.mission.add_level_button("forest_shi",Localize.format_text("选中 · %s",shi.display_name))
	b.mission.add_map_locator("快活林酒肉店",SIGN)
	b.mission.add_map_locator("施恩安全候场处",Vector2i(44,25))

func _sync_shop_controls(b) -> void:
	if st != RETURN_SHOP or b.phase != b.Phase.FIGHT or b.hud.touch_ui:
		return
	var terms_done: bool = b.mission.has_event("terms")
	var changed := false
	var shop_button: Button = b.mission.find_level_button("forest_order_shop")
	if shop_button == null:
		shop_button = b.mission.add_level_button("forest_order_shop", "让施恩接店",
			"派施恩到酒店旗标接管。可直接接店，也可等武松先说清条件。")
		shop_button.get_parent().move_child(shop_button, 0)
		changed = true
	var terms_button: Button = b.mission.find_level_button("forest_order_terms")
	if not terms_done and terms_button == null:
		terms_button = b.mission.add_level_button("forest_order_terms", "让武松说清条件",
			"派武松到退店旗标，与蒋门神说清三项条件。谈完后再让施恩接店。")
		terms_button.get_parent().move_child(terms_button, 0)
		changed = true
	elif terms_done and terms_button != null:
		terms_button.get_parent().remove_child(terms_button)
		terms_button.queue_free()
		changed = true
	var prompt := "退店条件已谈妥。点「让施恩接店」，待施恩到场交割。" if terms_done \
		else "可点「让施恩接店」结束本关。若要完成原著演义，先点「让武松说清条件」，谈完再接店。"
	if b.mission.objective != prompt:
		b.mission.set_objective(prompt)
	if changed:
		# Reveal the lower of the two nearby controls so both are visible in a short window.
		b.mission.reveal_primary_level_button()

func _next_road_drink() -> String:
	for index in range(taverns.size()):
		if not taverns[index].drunk:
			return "drink_%d" % index
	return ""


func refresh_road_controls(b) -> void:
	if st != ROAD or b.phase != b.Phase.FIGHT or b.hud.touch_ui:
		return
	var changed := false
	var challenge: Button = b.mission.find_level_button(ROAD_PROVOKE_BUTTON)
	if challenge == null:
		challenge = b.mission.add_level_button(ROAD_PROVOKE_BUTTON, "到店挑衅",
			"派武松到快活林店前佯醉换酒。走到旗标后才会引蒋门神出店。")
		challenge.get_parent().move_child(challenge, 0)
		changed = true
	var drink: Button = b.mission.find_level_button(ROAD_DRINK_BUTTON)
	if _next_road_drink().is_empty():
		if drink != null:
			drink.get_parent().remove_child(drink)
			drink.queue_free()
	elif drink == null:
		drink = b.mission.add_level_button(ROAD_DRINK_BUTTON, "去下一家饮酒",
			"派武松走到下一处未饮过的酒望。每次只派一家，也可随时去酒店。")
		drink.get_parent().move_child(drink, 0)
		changed = true
	if changed:
		b.mission.reveal_primary_level_button()


func _has_task_order(b, actor: Unit, action_id: String) -> bool:
	return is_instance_valid(actor) and (b.mission.active_action_id == action_id or (
		(actor.mission_order_active or actor.mission_order_arrival_t > 0.0)
		and b.mission._nearest_clicked_action(actor.mission_order_target) == action_id))

func _order_shop_task(b, actor: Unit, action_id: String) -> void:
	if st != RETURN_SHOP or b.hud.touch_ui or not b._gameplay_rng_issue.is_empty():
		return
	_order_task(b, actor, action_id, "武松已前往退店旗标。" if action_id == "terms" else "施恩已前往酒店旗标。")


func _order_task(b, actor: Unit, action_id: String, feedback: String) -> void:
	var action: Dictionary = b.mission.actions.get(action_id, {})
	if action.is_empty() or action.done or not b.mission._valid_action_actor(actor, action) or _has_task_order(b, actor, action_id):
		return
	if action_id == "restore_shop" and not b.mission.has_event("terms") and _has_task_order(b, wu, "terms"):
		b.mission.set_feedback("武松正在去谈退店条件。谈完后再让施恩接店。")
		return
	var target: Vector2 = b.map.cell_to_world(action.cell)
	var path: PackedVector2Array = b.map.find_path(actor.position, target, actor.faction, actor.movement_profile)
	if not String(action.get("blocked_reason", "")).is_empty() or path.is_empty() \
			or b.mission._nearest_clicked_action(target) != action_id or path[-1].distance_to(target) > float(action.reach) \
			or not b.map._segment_open(path[-1], target, actor.movement_profile):
		b.mission.set_feedback("暂时走不到旗标。请清开道路或手动改道。")
		return
	var group := [actor]
	b._stamp_manual(group)
	actor.order_move(target)
	b._stamp_mission_move(group, target)
	Sfx.play("order")
	b.mission.set_feedback(feedback)

func activate_mission_button(b, button_id: String) -> void:
	if button_id in [ROAD_DRINK_BUTTON, ROAD_PROVOKE_BUTTON]:
		if st == ROAD and not b.hud.touch_ui and b._gameplay_rng_issue.is_empty():
			if button_id == ROAD_DRINK_BUTTON:
				_order_task(b, wu, _next_road_drink(), "武松正前往下一处酒望。")
			else:
				_order_task(b, wu, "provoke", "武松正前往快活林店前。")
		return
	if button_id == "forest_order_terms":
		_order_shop_task(b, wu, "terms")
		return
	if button_id == "forest_order_shop":
		_order_shop_task(b, shi, "restore_shop")
		return
	var actor = wu if button_id == "forest_wu" else (shi if button_id == "forest_shi" else null)
	if is_instance_valid(actor) and actor.hp>0:
		b.select_single(actor,false)
		b.center_camera_cell(b.map.world_to_cell(actor.position))

func campaign_debrief(mission) -> Array[Dictionary]:
	var shop := "尚未交还施恩"
	if mission.has_event("restore_shop"):
		shop = "已交还施恩"
	elif mission.has_event("menshen_subdued"):
		shop = "蒋门神已败，酒店尚未交还"
	return [
		{"source": "酒望 · 饮酒 %d/4 处", "args": [drunk]},
		{"source": "反击命中 %d 次 · %s", "args": [counter_hits,
			"玉环步接鸳鸯脚命中" if mission.has_event("mengzhou_signature") else "未完成玉环步接鸳鸯脚"]},
		{"source": "酒店 · %s", "args": [shop]},
	]

func top_status(b) -> String:
	if charge_running: return "蒋门神冲撞中 · 横移让开"
	if exposed_left>0: return _counter_status(b)
	if fist_windup>0:
		if special_kind=="heavy":
			return Localize.format_text("重拳 %.1f秒后落下 · 离开圆圈",fist_windup)
		if rush_from.distance_to(rush_end)<=MIN_RUSH_TRAVEL:
			return Localize.format_text("冲撞受阻 · %.1f秒后可反击",fist_windup)
		return Localize.format_text("冲撞 %.1f秒后出招 · 横移出警戒区",fist_windup)
	return super.top_status(b)

class DuelTell extends Node2D:
	var kind:="heavy"
	var progress:=0.0
	var extent:=190.0
	func _rush_outline(radius: float) -> PackedVector2Array:
		var outline := PackedVector2Array()
		for step in range(17):
			outline.append(Vector2.from_angle(PI/2+step*PI/16)*radius)
		for step in range(17):
			outline.append(Vector2(extent,0)+Vector2.from_angle(-PI/2+step*PI/16)*radius)
		return outline

	func _draw() -> void:
		var color:=Color("efb94a").lerp(Color("ef492b"),clampf(progress,0,1))
		if kind=="heavy":
			draw_circle(Vector2.ZERO,HEAVY_RADIUS,Color(color,0.12+progress*0.12))
			draw_arc(Vector2.ZERO,HEAVY_RADIUS,0,TAU,64,color,2.5)
			draw_arc(Vector2.ZERO,HEAVY_RADIUS-8,-PI/2,-PI/2+maxf(0.01,progress)*TAU,64,color,4)
		elif extent>MIN_RUSH_TRAVEL:
			# Duel tells live under Battle/World/FX, with the same logical axes
			# as charge movement. Use the larger player's body for the warning.
			var battle = get_parent().get_parent().get_parent()
			var radius := RUSH_WIDTH*0.5
			for actor in [battle.level.wu,battle.level.shi]:
				if is_instance_valid(actor):
					radius=maxf(radius,RUSH_WIDTH*0.5+actor.radius)
			var shape:=_rush_outline(radius)
			draw_colored_polygon(shape,Color(color,0.14))
			shape.append(shape[0])
			draw_polyline(shape,color,2.5)
			draw_line(Vector2(0,0),Vector2(extent*progress,0),color,5)
