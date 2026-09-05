extends "res://scripts/levels/level7_kuaihuolin.gd"
## Current short duel: optional road preparation and a live, finite counter window.
var controls_generation:=-1
var charge_running:=false
var opening_serial:=-1
var step_serial:=-1
var step_origin:=Vector2.ZERO
var counter_hits:=0
var victory:=false

func story_contract_version() -> int: return 2
func deploy_hint() -> String:
	return "沿途饮酒可选，每店三碗增加拳力，也会让步速和出手波动。右键蒋门神直接挑战，或到酒望前佯醉换酒。Q近身直拳；W玉环步后仍需右键移动；避开圆圈重拳或横移让开真实冲撞，再靠近用E鸳鸯脚反击。R可恢复气血、暂稳步履；让施恩留在安全处。"

func apply_overrides(defs: Dictionary, abilities: Dictionary) -> void:
	super.apply_overrides(defs,abilities)
	abilities.mengzhou_step.desc="短时加速；按W后仍需右键下令换位。躲开本次重拳或冲撞后，趁破绽靠近接E。"
	abilities.mengzhou_punch.desc="近身直拳，造成伤害并短暂僵直；蓄力重拳和冲撞仍需看预警走位。"
	abilities.mengzhou_kick.desc="近身连踢。当前破绽期间，玉环步实际换位后踢中，才能完成招牌拳路。"

func on_start(b) -> void:
	super.on_start(b)
	controls_generation=-1; charge_running=false; opening_serial=-1; step_serial=-1
	counter_hits=0; victory=false
	_road_actions(b)
	b.mission.enable_scrolling()
	_sync_controls(b)

func _road_actions(b) -> void:
	b.mission.begin("road_choice","沿途准备 · 饮酒或径赴快活林", "每处酒望可吃一次三碗：拳力更强，步速与出手也更不稳。可以择店饮酒，也可直接挑战；四处都饮过另计演义。第二家旁有可选练步，W只是加速，方向仍由右键决定。")
	for i in range(taverns.size()):
		if not taverns[i].drunk: b.mission.add_action("drink_%d"%i,"武松 · 第%d家三碗"%(i+1),TAVERN_CELLS[i]+Vector2i(0,2),["wu_song"],0.8,48)
	if not b.mission.has_event("road_step_practiced"):
		b.mission.add_action("practice_step","可选 · 官道旁试一次换步",Vector2i(25,19),["wu_song"],0.5,40)
	b.mission.add_action("provoke","武松 · 店前佯醉换酒",KUAIHUO+Vector2i(-2,1),["wu_song"],0.8,48)

func on_mission_action(b, action_id: String, actor) -> void:
	if action_id.begins_with("drink_"):
		var i:=int(action_id.trim_prefix("drink_"))
		if st!=ROAD or actor!=wu or i<0 or i>=taverns.size() or taverns[i].drunk: return
		taverns[i].drunk=true; drunk+=1
		wu._base_atk+=5; wu.atk+=5; wu.heal(35)
		wu.start_drunk(maxf(0.64,1.0-0.09*drunk),1.08,999)
		b.mission.mark(action_id,"第%d家酒望吃足三碗；现共%d家，拳力增强，酒势也更不稳。"%[i+1,drunk])
		b.mission.set_status("已饮%d/4家：可继续沿路，或直接去快活林。"%drunk)
	elif action_id=="practice_step":
		if st!=ROAD or actor!=wu: return
		_start_step_drill(b)
	elif action_id=="provoke":
		if st==ROAD and actor==wu: _open_showdown(b,true)
	else:
		super.on_mission_action(b,action_id,actor)
		if action_id=="restore_shop" and b.mission.has_event("restore_shop"): victory=true
	_sync_controls(b)

func _start_step_drill(b) -> void:
	st=STEP_DRILL
	drill_origin=wu.position
	drill_marker=DuelTell.new()
	drill_marker.position=drill_origin
	drill_marker.z_index=3449
	b.fx_root.add_child(drill_marker); b.map.sync_render_position(drill_marker)
	b.mission.begin("road_step_drill","试一次横移 · 此处不受伤","右键圈外地面，让武松实际走出圆圈。W提供短时加速，仍需右键指定方向。离开后可继续择店饮酒或直接挑战。")

func _complete_step_drill(b, source: String) -> void:
	if st!=STEP_DRILL or wu.position.distance_to(drill_origin)<=94: return
	st=ROAD
	if is_instance_valid(drill_marker): drill_marker.queue_free()
	drill_marker=null
	b.mission.mark("road_step_practiced","武松实际离开重拳落点，试过横移（%s）。"%source)
	_road_actions(b)

func _open_showdown(b, original_provocation:=false) -> void:
	if st in [SHOWDOWN,RETURN_SHOP]: return
	if is_instance_valid(drill_marker): drill_marker.queue_free()
	drill_marker=null
	super._open_showdown(b,original_provocation)
	charge_running=false; opening_serial=-1; step_serial=-1
	fist_cd=3.0
	b.mission.set_objective("圆形重拳：离开落点。直线冲撞：横移让路，蒋门神会实际冲过去。Q近身出拳；W加速后右键换位；趁招式落空的短窗口靠近按E，R可回血稳酒。保护留在后方的施恩。")
	_sync_controls(b)

func on_ability(b, caster, ability_id: String, lp: Vector2) -> bool:
	if caster!=wu: return false
	if ability_id=="mengzhou_step":
		step_serial=special_index if st==SHOWDOWN else -1
		step_origin=wu.position
		b.mission.mark("mengzhou_step_used","武松踏玉环步；接着右键移动换位。")
		return false
	if ability_id in ["mengzhou_punch","mengzhou_kick"]:
		var spec: Dictionary=b._scaled_ability(b._abilities[ability_id],b._hero_rb(wu),b._hero_db(wu))
		var in_range: bool=is_instance_valid(menshen) and menshen.story_outcome=="" and wu.position.distance_to(menshen.position)<=float(spec.radius)
		if in_range:
			var signature: bool=ability_id=="mengzhou_kick" and exposed_left>0 and step_serial==opening_serial and wu.position.distance_to(step_origin)>=24
			_verify_hit.call_deferred(b,menshen,menshen.hp+menshen._shield,signature,exposed_left>0,ability_id)
		else:
			b.msg("拳脚落空：先靠近蒋门神再出招。",2.5)
		return false
	if ability_id=="mengzhou_breath": return super.on_ability(b,caster,ability_id,lp)
	return false

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
		if steady_left<=0: wu.start_drunk(maxf(0.64,1.0-0.09*drunk),1.08,999)
	if st==STEP_DRILL and wu.position.distance_to(drill_origin)>94: _complete_step_drill(b,"manual_step")
	if st in [ROAD,STEP_DRILL]:
		if menshen.story_outcome=="subdued": _set_menshen_subdued(b)
		elif menshen.hp<menshen.max_hp-0.5 or wu._target==menshen: _open_showdown(b,false)
	elif st==SHOWDOWN and menshen.story_outcome=="":
		_duel_tick(b,delta)
	_sync_controls(b)

func _duel_tick(b, delta: float) -> void:
	if charge_running:
		if menshen._charge_dash>0 or menshen._charge_t>0: return
		charge_running=false
		_finish_special(b,not menshen._charge_hit.has(wu) and not menshen._charge_hit.has(shi))
		menshen.order_attack(wu)
		return
	if exposed_left>0:
		exposed_left=maxf(0,exposed_left-delta)
		b.mission.set_status("破绽还剩 %.1f秒 · 靠近E反击，或R稳住酒势。"%exposed_left)
		if exposed_left<=0:
			opening_serial=-1; step_serial=-1
			menshen.apply_damage_reduction(0.5,999,BRACE_SOURCE)
		return
	if fist_windup>0:
		fist_windup=maxf(0,fist_windup-delta)
		if is_instance_valid(fist_marker):
			fist_marker.progress=1.0-fist_windup/(1.6 if special_kind=="heavy" else 1.25)
			fist_marker.queue_redraw()
		if fist_windup>0: return
		if special_kind=="rush":
			menshen.remove_meta("story_pose")
			menshen._begin_charge(rush_end-rush_from,42,0,rush_from.distance_to(rush_end),92,0.65,0.55,false,"mengzhou_menshen_rush")
			charge_running=true
		else:
			var hit:=false
			for actor in [wu,shi]:
				if actor.position.distance_to(fist_at)<=78 and b.map._segment_open(menshen.position,actor.position,"land"):
					hit=true; actor.take_damage(32,menshen); actor.apply_stun(0.55)
			_finish_special(b,not hit)
		return
	fist_cd-=delta
	b.mission.set_status("Q出拳 · W后右键换位 · E近身连踢 · R稳酒。等他起手再判断方向。")
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

func _finish_special(b, missed: bool) -> void:
	_clear_tell()
	menshen.remove_meta("story_pose")
	if missed:
		dodged=true; opening_serial=special_index
		exposed_left=2.8 if special_kind=="rush" else 2.2
		menshen._damage_reduction_sources.erase(BRACE_SOURCE)
		menshen._refresh_damage_reduction()
		menshen.apply_stun(exposed_left)
		if special_kind=="heavy": heavy_dodges+=1
		else: rush_dodges+=1
		b.mission.mark("dodge_"+special_kind,"蒋门神本次招式落空，架势松动。")
		b.msg("招式落空！靠近E反击。",2)
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

func _sync_controls(b) -> void:
	if controls_generation==b.mission._generation: return
	controls_generation=b.mission._generation
	for actor in [wu,shi]:
		var button:=Button.new()
		button.text="选中 · "+actor.display_name
		button.pressed.connect(func():
			if is_instance_valid(actor) and actor.hp>0: b.select_single(actor,false); b.center_camera_cell(b.map.world_to_cell(actor.position)))
		b.mission._buttons.add_child(button)
	b.mission.add_map_locator("快活林酒肉店",SIGN)
	b.mission.add_map_locator("施恩安全候场处",Vector2i(44,25))

func top_status(b) -> String:
	if charge_running: return "蒋门神冲撞中 · 横移让开"
	if exposed_left>0: return "当前破绽 %.1f秒 · 反击命中%d次"%[exposed_left,counter_hits]
	return super.top_status(b)

class DuelTell extends Node2D:
	var kind:="heavy"
	var progress:=0.0
	var extent:=190.0
	func _draw() -> void:
		var color:=Color("efb94a").lerp(Color("ef492b"),clampf(progress,0,1))
		if kind=="heavy":
			draw_circle(Vector2.ZERO,78,Color(color,0.12+progress*0.12))
			draw_arc(Vector2.ZERO,78,0,TAU,64,color,2.5)
			draw_arc(Vector2.ZERO,70,-PI/2,-PI/2+maxf(0.01,progress)*TAU,64,color,4)
		else:
			var shape:=PackedVector2Array([Vector2(0,-46),Vector2(extent,-46),Vector2(extent,46),Vector2(0,46),Vector2(0,-46)])
			draw_colored_polygon(shape,Color(color,0.14))
			draw_polyline(shape,color,2.5)
			draw_line(Vector2(0,0),Vector2(extent*progress,0),color,5)
