extends "res://scripts/levels/level1_huangnigang.gd"
## Current short chapter. Reuse the authored map, art and nonlethal convoy.
## All travel is player ordered; the wine handoff is one sustained team action.
const WU_STATION := Vector2i(23,23)
const BAI_STATION := Vector2i(24,24)
const TRIBUTE_ART := "tribute_load_alpha_20260906"
var team_t := 0.0
var distraction_serial := -1
var controls_generation := -1
var victory := false
var depart_requested := false

func story_contract_version() -> int: return 2
func campaign_story_goals() -> Array:
	var goals:=super.campaign_story_goals()
	goals[1].label="白胜卖酒，刘唐试酒引目，吴用与白胜配合下药"
	return goals
func apply_overrides(defs: Dictionary, abilities: Dictionary) -> void:
	super.apply_overrides(defs,abilities)
	defs.treasure_cart.campaign_object=TRIBUTE_ART
	for key in SEVEN+["bai_sheng"]: defs[key].campaign_tribute_object=TRIBUTE_ART

func deploy(b) -> void:
	super.deploy(b)
	for bundle in bundles:
		bundle.remove_meta("campaign_environment_route")
		bundle.art_variant=TRIBUTE_ART

func deploy_hint() -> String:
	return "押队上冈时让晁盖摆枣车、刘唐准备应答。酒计需刘唐引目，吴用和白胜在乙桶旁配合；可提前站位，失手还能重新引目。也可直接动武强夺。麻倒或击退守军后，任选空手同伴分运三担，其他人由你调度撤退。"

func intro_lines() -> Array:
	return [
		{"who":"旁白","key":"narrator","text":"六月黄泥冈，杨志催十一名军汉挑担上冈，两个虞候、老都管相随。七星扮作贩枣客，白胜另挑酒来。"},
		{"who":"吴用","key":"wu_yong","text":"先让他们看过好酒。刘唐争酒引目，我与白胜在桶旁配合；药入酒桶之后，分人挑担，莫再生枝节。"},
		{"who":"行前提示","key":"narrator","text":"查看只移镜头，人物由你选择并右键下令。酒计能免战保全众人；直接强夺则要保护搬运者。三担可以同时走，幸存同伴到齐便能出冈。"}]

func on_start(b) -> void:
	super.on_start(b)
	team_t=0; distraction_serial=-1; controls_generation=-1
	victory=false; depart_requested=false
	# The approaching convoy and the player's preparation happen together.
	_start_convoy(b)
	b.mission.set_title("押队正上冈 · 布置商客身份")
	b.mission.set_objective("晁盖摆好枣车，刘唐准备应答。押队正在上冈；可先查看西口退路，也可直接攻击押队，转为强夺。")
	_add_dates_action(b)
	b.mission.enable_scrolling()
	_sync_controls(b)

func _add_dates_action(b) -> void:
	if not b.mission.has_event("place_dates"):
		b.mission.add_action("place_dates","晁盖 · 摆枣车作商客",DATES,["chao_gai"],1.0,40.0)

func on_mission_action(b, action_id: String, actor) -> void:
	match action_id:
		"place_dates":
			if st not in [MARCH,INQUIRY] or actor.key!="chao_gai": return
			_place_jujube_carts(b)
			b.mission.mark("place_dates","晁盖在松阴摆好七辆枣车，七星作歇脚商客。")
		"taste_wine":
			if st!=WINE or wine_step!="trial": return
			if not _identity_ready(b):
				_retry_action(b,action_id,"先让露出破绽的人回枣车，等疑心低于40再试酒。")
				return
			clean_trial=true
			b.mission.mark("taste_wine","刘唐领头饮甲桶好酒，押队看见众人安然无事。")
			_set_sign(good_sign,"甲桶 · 已试好酒")
			_begin_team_setup(b,false)
		"distract_yang":
			if st!=WINE or wine_step!="attention" or not clean_trial: return
			if not _attention_valid(b) or not _identity_ready(b):
				_retry_action(b,action_id,"刘唐需在押队看得见的位置争酒；先收敛可疑举动。")
				return
			wine_step="cooperate"; attention_left=22.0; team_t=0
			distraction_serial=actor._order_serial
			b.mission.mark("distract_yang","刘唐佯讨半瓢酒，引住押队目光；吴用与白胜在乙桶交接。")
		"withdraw_now":
			if st==WITHDRAW and delivered==3: depart_requested=true
		_:
			super.on_mission_action(b,action_id,actor)
	_sync_controls(b)

func _begin_wine_trial(b, _retry: bool) -> void:
	wine_step="trial"; clean_trial=false; scoop_prepared=false; attention_left=0; team_t=0
	_set_sign(good_sign,"甲桶 · 先试好酒")
	_set_sign(sale_sign,"乙桶 · 吴用、白胜的配合处")
	b.mission.begin("wine_trial","先试好酒 · 提前安排两人", "刘唐先到甲桶试好酒；同时可让吴用与白胜走到乙桶旁，准备借瓢。查看只移动镜头，人物需要你下令。")
	b.mission.add_action("taste_wine","刘唐 · 试甲桶好酒",GOOD_WINE,["liu_tang"],1.2,40.0)
	_restore_cover_actions(b)

func _begin_team_setup(b, retry: bool) -> void:
	wine_step="attention"; attention_left=0; team_t=0; scoop_prepared=false
	b.mission.begin("wine_team_retry" if retry else "wine_team","重找争酒时机" if retry else "三人配合 · 借瓢下药", "吴用与白胜先在乙桶旁站好。再让刘唐右键争酒旗标；他引住目光后，两人在桶旁连续配合3秒。刘唐改令或离位会中断，22秒窗口与总歇脚时间都要留意。")
	b.mission.add_action("distract_yang","刘唐 · 争酒引住目光",DISTRACT,["liu_tang"],0.8,40.0)
	_restore_cover_actions(b)

func _restore_cover_actions(b) -> void:
	for u in actors:
		if is_instance_valid(u) and u.hp>0 and not u.get_meta("merchant_disguise",true):
			b.mission.add_action("return_"+u.key,u.display_name+" · 回枣车收敛",_cover_cell(u.key),[u.key],0.8,40.0)

func _reset_wine_attempt(b, reason: String) -> void:
	if sale_drugged or drug_done: return
	attention_missed=true
	b.mission.mark("missed_attention","配合中断，保留已试过的好酒，另找争酒时机。")
	_begin_team_setup(b,true)
	b.msg(reason+" 好酒不用重试，歇脚余时也不会重置。",5)

func _team_ready(b) -> bool:
	return _at(b,b.find_unit("wu_yong"),SALE_WINE,70) and _at(b,b.find_unit("bai_sheng"),SALE_WINE,70) and _identity_ready(b)

func _find_suspicious(b) -> Array[String]:
	var found: Array[String]=super._find_suspicious(b)
	if st!=WINE or not b.mission.has_event("merchant_identity_confirmed"): return found
	# The named merchants may walk between their legitimate wine stations.
	# Loitering beside cargo or entering the guard formation still raises suspicion.
	for route in [["wu_yong",SHADE,WU_STATION],["liu_tang",ANSWER,GOOD_WINE],["liu_tang",GOOD_WINE,DISTRACT]]:
		var u=b.find_unit(route[0])
		if not is_instance_valid(u): continue
		var nearest: Vector2=Geometry2D.get_closest_point_to_segment(u.position,b.map.cell_to_world(route[1]),b.map.cell_to_world(route[2]))
		if u.position.distance_to(nearest)<=52: found.erase(route[0])
	return found

func _wine_team_tick(b, delta: float) -> void:
	var liu=b.find_unit("liu_tang")
	if not _attention_valid(b) or liu._order_serial!=distraction_serial or liu.manual_order_active:
		_reset_wine_attempt(b,"刘唐已停止争酒或离开位置。")
		return
	attention_left=maxf(0,attention_left-delta)
	if attention_left<=0:
		_reset_wine_attempt(b,"争酒窗口已过。")
		return
	if not _team_ready(b):
		team_t=0
		b.mission.set_status("引目还剩%d秒：吴用%s，白胜%s。两人需在乙桶旁、身份未露。"%[ceili(attention_left),"到位" if _at(b,b.find_unit("wu_yong"),SALE_WINE,70) else "未到", "到位" if _at(b,b.find_unit("bai_sheng"),SALE_WINE,70) else "未到"])
		return
	team_t+=delta
	b.mission.set_status("刘唐引目，吴用借瓢、白胜夺回 · 配合 %d%%"%mini(100,int(team_t/3.0*100)))
	if team_t<3: return
	# One completed player-coordinated handoff; no new walking orders or actors.
	scoop_prepared=true; sale_drugged=true; drug_done=true; attention_left=0; wine_step="done"
	b.mission.mark("drug_scoop","吴用在乙桶旁以藏药的瓢佯作舀酒。")
	b.mission.mark("reclaim_scoop","白胜当场夺瓢倾回；押队看过试酒与争酒，放下戒心。")
	for guard in convoy:
		if is_instance_valid(guard) and guard.hp>0: guard.resolve_story("unconscious")
	b.mission.mark("drugged","白胜售酒，十五名押送者饮下药酒，麻倒松阴。")
	for sign_node in field_signs:
		if is_instance_valid(sign_node): sign_node.hide()
	st=CARRY
	_begin_cargo_choice(b)

func _begin_cargo_choice(b) -> void:
	cargo_plan="free"
	b.mission.begin("cargo","分派人手 · 三担各走一次", "任选三个空手同伴分别右键担旁旗标。挑起后右键西口送担，可同时行军；其余同伴也可往西口撤退。搬运者倒下，空手同伴可接力。")
	for i in range(3): _add_force_take(b,i)

func _add_force_take(b, index: int) -> void:
	if st not in [CARRY,FORCE] or index<0 or index>=bundles.size() or _cargo_was_delivered(b,index): return
	if not is_instance_valid(bundles[index]) or not b.units.has(bundles[index]): return
	var available:=_available_force_carriers()
	if available.is_empty(): available.append(NO_FORCE_CARRIER)
	b.mission.add_action("force_take_%d_%d"%[index,int(force_attempts.get(index,0))],"空手同伴 · 挑第%d担"%(index+1),_bundle_claim_cell(b,index),available,0.6,48)

func _add_force_deliver(b, index: int, actor) -> void:
	if st not in [CARRY,FORCE] or not is_instance_valid(actor): return
	b.mission.add_action("force_deliver_%d_%d"%[index,int(force_attempts.get(index,0))],actor.display_name+" · 送第%d担出冈"%(index+1),GATE_W+Vector2i(0,index-1),[actor.key],0.6,64)

func _force_take_cargo(b, action_id: String, actor, index: int) -> void:
	if st not in [CARRY,FORCE] or index<0 or index>=bundles.size() or _cargo_was_delivered(b,index) or cargo.has(index): return
	if not _mission_action_done(b,action_id) or not _at(b,actor,_bundle_claim_cell(b,index),50): return
	if actor.has_meta("carrying_tribute"):
		_retry_action(b,action_id,"此人已挑一担，请另选空手同伴。")
		return
	cargo[index]=actor
	_pick_up_bundle(b,bundles[index])
	actor.set_meta("carrying_tribute",index)
	actor.queue_redraw()
	_set_force_carrier_eligible(b,actor.key,false)
	actor.apply_slow(0.78,999)
	b.mission.mark("force_taken_%d_%d"%[index,int(force_attempts.get(index,0))],actor.display_name+"挑起第%d担，去路由玩家下令。"%(index+1))
	_add_force_deliver(b,index,actor)

func _force_deliver_cargo(b, action_id: String, actor, index: int) -> void:
	if st not in [CARRY,FORCE] or index<0 or index>=bundles.size() or _cargo_was_delivered(b,index): return
	if not _mission_action_done(b,action_id) or not cargo.has(index) or cargo[index]!=actor or actor.get_meta("carrying_tribute",-1)!=index: return
	if not _at(b,actor,GATE_W+Vector2i(0,index-1),66): return
	actor.remove_meta("carrying_tribute")
	actor.queue_redraw()
	_set_force_carrier_eligible(b,actor.key,true)
	actor.apply_slow(1,0)
	bundles[index].position=b.map.cell_to_world(GATE_W+Vector2i(0,index-1))
	bundles[index].faction=Unit.FACTION_LIANG
	_put_down_bundle(b,bundles[index])
	cargo.erase(index); delivered+=1
	b.mission.mark("force_delivered_%d"%index,"第%d担由%s送出黄泥冈。"%[index+1,actor.display_name])
	if delivered==3: _begin_free_withdraw(b)

func _begin_free_withdraw(b) -> void:
	if st==WITHDRAW: return
	st=WITHDRAW
	b.mission.begin("withdraw","三担已到 · 收拢同伴", "让七星与白胜一起到西口，可完成全员生还目标；也可由已到西口的人先行收队。两种选择都需你的实际指挥。")
	b.mission.add_action("withdraw_now","先行收队 · 未到者不计全员生还",GATE_W,[],0.6,64)

func _withdraw_tick(b) -> void:
	var living: Array=actors.filter(func(u): return is_instance_valid(u) and u.hp>0 and u.story_outcome=="")
	var survivors_out: bool=not living.is_empty() and living.all(func(u): return u.position.distance_to(b.map.cell_to_world(GATE_W))<=150)
	if delivered!=3 or living.is_empty() or not (survivors_out or depart_requested): return
	if survivors_out and living.size()==8: b.mission.mark("huangnigang_all_safe","七星与白胜全员生还，带三担财物撤出冈口。")
	else: _story_miss(b,"all_safe","已有同伴倒下。" if living.size()<8 else "先行收队，未等全员到达西冈口。")
	victory=true
	b.mission.mark("escaped","幸存好汉带三担生辰纲出冈。")
	b.win("七星与白胜巧施酒计，十五名押送者麻倒，三担生辰纲已运出黄泥冈。" if drug_done else "好汉击退押队，三担生辰纲已运出黄泥冈。")

func on_unit_died(b, u) -> void:
	if u in actors and drug_done:
		var index:=int(u.get_meta("carrying_tribute",-1))
		_drop_carried_bundle(b,u)
		b.mission.mark("huangnigang_actor_lost",u.display_name+"倒下；幸存者仍可接力搬担。")
		_story_miss(b,"all_safe","已有好汉阵亡。")
		if index>=0: _add_force_take(b,index)
		if _available_force_carriers().is_empty() and cargo.is_empty(): b.lose("所有同伴倒下，无人能够带走纲担。")
		return
	super.on_unit_died(b,u)

func process(b, delta: float) -> void:
	if st==WITHDRAW:
		_withdraw_tick(b)
	elif st==MARCH:
		_march_tick(b,delta)
	else:
		super.process(b,delta)
		if st==WINE and wine_step=="cooperate": _wine_team_tick(b,delta)
	_sync_controls(b)

func _march_tick(b, delta: float) -> void:
	for guard in convoy:
		if is_instance_valid(guard) and (guard.hp<guard.max_hp-0.5 or guard.story_outcome!=""):
			_begin_force_route(b,"押队受到攻击，七星转为强夺。",true)
			return
	for actor in actors:
		if is_instance_valid(actor) and (actor._target in convoy or actor._target in bundles):
			_begin_force_route(b,"玩家向押队动武，酒计转为强夺。",true)
			return
	var cargo_arrived:=true
	for i in range(bundles.size()):
		var destination: Vector2=b.map.cell_to_world(TOP+Vector2i(i,0))
		bundles[i].position=bundles[i].position.move_toward(destination,62*delta)
		cargo_arrived=cargo_arrived and bundles[i].position.distance_to(destination)<1
	if not is_instance_valid(yang) or yang.position.distance_to(b.map.cell_to_world(TOP))>=110 or not cargo_arrived: return
	st=INQUIRY
	for guard in convoy: guard.order_stop()
	yang.order_move(b.map.cell_to_world(INSPECT))
	# Keep the player's preparation task and its partially completed progress.
	# An NPC arrival must not consume that order by replacing the whole stage.
	b.mission.set_title("杨志到冈 · 当面应答")
	b.mission.set_objective("刘唐当面说明商客来历，其他人留在枣车旁。若晁盖尚未摆车，先完成布置；不要逼近押担队。")
	b.mission.add_action("answer_yang","刘唐 · 当面应答杨志",ANSWER,["liu_tang"],1.5,40)

func _sync_controls(b) -> void:
	if controls_generation==b.mission._generation: return
	controls_generation=b.mission._generation
	var keys: Array=[]
	if st in [MARCH,INQUIRY]: keys=["chao_gai","liu_tang"]
	elif st==ARRIVAL: keys=["bai_sheng"]
	elif st==WINE:
		keys=["liu_tang","wu_yong","bai_sheng"]
		b.mission.add_map_locator("吴用 · 乙桶旁站位",WU_STATION)
		b.mission.add_map_locator("白胜 · 乙桶旁站位",BAI_STATION)
	for key in keys:
		var button:=Button.new()
		button.text="选中 · "+String(b._defs[key].name)
		button.pressed.connect(func():
			var u=b.find_unit(key)
			if is_instance_valid(u) and u.hp>0: b.select_single(u,false); b.center_camera_cell(b.map.world_to_cell(u.position)))
		b.mission._buttons.add_child(button)
	if st in [CARRY,FORCE,WITHDRAW]:
		var button:=Button.new()
		button.text="选中 · 空手同伴"
		button.pressed.connect(func(): b.select_members(actors.filter(func(u): return is_instance_valid(u) and u.hp>0 and u.story_outcome=="" and not u.has_meta("carrying_tribute")),false))
		b.mission._buttons.add_child(button)
	b.mission.add_map_locator("西冈口 · 搬担退路",GATE_W)

func top_status(_b) -> String:
	var text: String=super.top_status(_b)
	if st==CARRY: text=text.replace("逐担派送","分队搬运")
	if st==WINE and wine_step=="cooperate": text+=" · 引目%d秒 · 配合%d%%"%[ceili(attention_left),mini(100,int(team_t/3.0*100))]
	return text
