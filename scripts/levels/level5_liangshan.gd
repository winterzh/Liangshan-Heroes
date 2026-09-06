extends LevelBase
## 第七十八至八十回：三次进兵分别部署，真实水路与山前陆路并用。
const T := GameMap.T
const Layout := preload("res://scripts/liangshan_layout.gd")
const Landscape := preload("res://scripts/liangshan_environment.gd")
const HALL_CELL := Vector2i(16,30)
const AMBUSH_E := Vector2i(36,25)
const AMBUSH_S := Vector2i(34,40)
const PRISONER_DOCK_LAND := Layout.DOCK+Vector2i(2,1)
const PRISONER_DOCK_WATER := PRISONER_DOCK_LAND+Vector2i(1,0)
const MAIN_LURE_CELL := Vector2i(41,26)
const MAIN_RETURN_CELL := Vector2i(41,41)
const SIDE_LURE_CELL := Vector2i(36,24)
const SIDE_AMBUSH_CELL := Vector2i(34,29)
const SIDE_RETURN_CELL := Vector2i(39,36)
const FIRE_PREP_CELL := Vector2i(41,39)
const FIRE_WIND_CELL := Vector2i(31,36)
const FIRE_LEADER_CELL := Vector2i(36,39)
const FIRE_NORTH_CELL := Vector2i(40,23)
const FIRE_SOUTH_CELL := Vector2i(40,30)
const FIRE_SAFE_CELL := Vector2i(42,47)
const FINAL_FLAG_CELL := Vector2i(34,51)
const FINAL_SEAL_CELL := Vector2i(39,48)
const FINAL_SCUTTLE_CELL := Vector2i(34,51)
const SCUTTLE_RANGE := 192.0
var stage := ""
var hall: Unit
var gao: Unit
var flagship: Unit
var vanguard_headship: Unit
var fleet: Array = []
var enemy_fleet: Array = []
var land_enemies: Array = []
var commanders: Array = []
var lure_started := false
var lure_complete := false
var transfer_done := false
var recovered_gao := false
var land_started := false
var elapsed := 0.0
var lure_route := ""
var fireboat: Unit
var fire_escorts: Array = []
var fire_leader: Unit
var wind_leader: Unit
var fire_wind_ready := false
var fire_prepared := false
var fire_point := ""
var fire_lit := false
var fire_withdrawn := false
var port_sealed := false
var escort_suppressed := false
var hard_rushes := 0
var first_direct := false
var fire_direct := false
var final_direct := false
var final_direct_victory := false

func id() -> String: return "level5"
func title() -> String: return "三败高太尉"
func subtitle() -> String: return "港汊诱舰·火船破连舰·封港凿船"
func campaign_core_goal() -> String: return "守住忠义堂与中军，击退三次进兵。末战击退或击沉高俅座船即可；生擒押堂为演义目标。"
func story_contract_version() -> int: return 2
func campaign_story_goals() -> Array:
	return [
		{"id":"gao_lure","label":"先诱官船深入港汊，再以伏兵合击","required_events":["fleet_in_ambush"],"forbidden_events":["gao_first_direct"]},
		{"id":"gao_fire","label":"公孙胜祭风，刘唐领火船贴近相连官船举火，并护接应船撤出","required_events":["gongsun_wind","liu_tang_fire_leader","fireboat_prepared","fire_escort_safe"],"forbidden_events":["gao_fire_direct"]},
		{"id":"gao_land","label":"火攻后以岸上伏兵守住山前来路","required_events":["second_defeat"],"forbidden_events":[]},
		{"id":"gao_capture","label":"封港后由张顺凿船，生擒高俅并押回忠义堂","required_events":["port_sealed","flagship_scuttled","gao_captured"],"forbidden_events":["gao_escaped"]},
	]
func map_w() -> int: return 60
func map_h() -> int: return 60
func map_base() -> int: return T.WATER
func camera_start_cell() -> Vector2i: return Vector2i(32,39)
func deploy_hint() -> String: return "三次进兵都可按演义布置，也可直接迎战。诱舰、公孙胜祭风与刘唐举火、岸军追击、封港凿船和生擒押堂分别计演义印；专用人物或船只损失不会立即判负，现存兵力仍可正面击退官军。陆军不能下水，战船不能登岸。"
func intro_lines() -> Array:
	return [{"who":"旁白","key":"narrator","text":"童贯败归之后，高俅请命征讨梁山，调集水陆军马，拘刷船只。芦苇遮住了港汊，也藏住了梁山水军。"},
		{"who":"吴用","key":"wu_yong","text":"官船虽多，却不识这泊里的深浅。阮家兄弟先引他深入，水军伏在芦苇中，等号炮一响便合击；岸上人马守住来路。"},
		{"who":"宋江","key":"song_jiang","text":"众兄弟分守水陆，莫教官军逼近山寨。若拿住高俅，须留他性命，我还有话问他。"}]

func apply_overrides(defs: Dictionary, _abilities: Dictionary) -> void:
	for record in [["ruan_xiaoqi_boat","阮小七·哨船",760.0,85.0,26.0],["liu_tang_fireboat","刘唐·举火小船",760.0,85.0,26.0],["ruan_xiaoer_boat","阮小二·战船",950.0,62.0,34.0],
		["ruan_xiaowu_boat","阮小五·战船",950.0,62.0,34.0],["zhang_shun_boat","张顺·凿船小艇",720.0,80.0,24.0],
		["liangshan_warship","梁山水军战船",800.0,62.0,34.0],
		["imperial_warship","官军战船",600.0,45.0,30.0],["official_vanguard","丘岳、徐京、梅展·先锋头船",600.0,45.0,30.0],
		["gao_flagship","高俅座船",2100.0,38.0,42.0]]:
		var d: Dictionary = defs["guan_gong"].duplicate(true)
		d["name"]=record[1]; d["hp"]=record[2]; d["speed"]=record[3]; d["atk"]=record[4]
		d["range"]=180; d["radius"]=25; d["hero"]=false; d["building"]=false
		var vessel_key := String(record[0])
		var vessel_art := "liangshan_boat"
		if vessel_key == "gao_flagship": vessel_art = "gao_flagship"
		elif vessel_key == "imperial_warship": vessel_art = "official_warship"
		elif vessel_key == "official_vanguard": vessel_art = "official_vanguard"
		d["movement_profile"]="water"; d["art_variant"]=vessel_art; d["campaign_object"]=vessel_art
		d["ability"]=""; d["abilities"]=[]
		defs[record[0]]=d

func _spawn_command(b) -> void:
	hall=b.spawn_at("hall",0,HALL_CELL)
	hall.display_name="忠义堂"
	hall.set_meta("campaign_environment_route","zhongyi_hall")
	hall.set_meta("campaign_environment_state","default")
	hall.set_meta("campaign_environment_text_surface_id","level5_hall_plaque")
	hall.set_meta("campaign_environment_runtime_text","忠义堂")
	hall.set_meta("campaign_environment_static_visual",true)
	commanders=[b.spawn_at("song_jiang",0,Vector2i(18,34)),b.spawn_at("wu_yong",0,Vector2i(19,36))]
	for h in commanders:
		h.stance=Unit.STANCE_HOLD

func deploy(b) -> void:
	first_direct=false; fire_direct=false; final_direct=false; final_direct_victory=false
	lure_started=false; lure_complete=false; transfer_done=false; recovered_gao=false
	land_started=false; elapsed=0.0; lure_route=""; port_sealed=false; escort_suppressed=false
	fire_wind_ready=false; fire_prepared=false; fire_leader=null; wind_leader=null
	_spawn_command(b)
	fleet=[b.spawn_at("ruan_xiaoqi_boat",0,Vector2i(41,33)),b.spawn_at("ruan_xiaoer_boat",0,Vector2i(41,39)),
		b.spawn_at("ruan_xiaowu_boat",0,Vector2i(43,42)),b.spawn_at("liangshan_warship",0,Vector2i(41,45)),b.spawn_at("liangshan_warship",0,Vector2i(43,48))]
	for ship in fleet: ship.visual_scale=1.2
	for cell in [Vector2i(31,25),Vector2i(31,28),Vector2i(31,31),Vector2i(32,34)]:
		var archer=b.spawn_at("liang_gong",0,cell)
		archer.stance=Unit.STANCE_HOLD
	for i in range(5):
		var ship=b.spawn_at("imperial_warship",1,Vector2i(40+i%3,5+i*3))
		ship.stance=Unit.STANCE_PASSIVE; ship.passive=true; ship.visual_scale=1.4
		enemy_fleet.append(ship)

func on_start(b) -> void:
	stage="water_lure"
	b.mission.begin(stage,"第一败·两路诱舰","刘梦龙为头统制，党世雄率精兵上船监战。阮小七可从主港直退，也可转入东岸侧汊。主港集中敌舰，侧汊让官船分向转弯并进入岸弓射界；两路都必须把活官船引入伏区。")
	b.mission.add_action("lure","阮小七：主港直退",MAIN_LURE_CELL,["ruan_xiaoqi_boat"],2.0)
	b.mission.add_action("lure_side","阮小七：侧汊迂回",SIDE_LURE_CELL,["ruan_xiaoqi_boat"],2.0)
	# Deliberate branch markers stay away from authored bait routes; otherwise a
	# retreating ship's manual-order timer could claim the alternative by proximity.
	b.mission.add_action("first_direct","水军：正面迎击（放弃诱舰印）",Vector2i(43,48),["ruan_xiaoqi_boat","ruan_xiaoer_boat","ruan_xiaowu_boat","liangshan_warship"],0.8,48.0)

func on_mission_action(b, action_id: String, _actor) -> void:
	match action_id:
		"lure":
			if stage!="water_lure" or lure_started: return
			lure_started=true; lure_route="main"
			_disable_action(b,"lure_side")
			_disable_action(b,"first_direct")
			b.lit_cells[MAIN_RETURN_CELL] = 18.0
			for ship in enemy_fleet:
				ship.stance=Unit.STANCE_AGGRO
				ship.passive=false
				ship.set_meta("lure_lane","main")
				ship.order_amove(b.map.cell_to_world(Vector2i(41,34)))
			b.mission.mark("lure_route_main","阮小七沿主港直退，官船集中追入正面水道。")
			b.mission.set_objective("主港敌舰正面压入。请玩家命阮小七退回主港，让至少一艘活官船驶到伏区，再以水军合击。")
		"lure_side":
			if stage!="water_lure" or lure_started: return
			lure_started=true; lure_route="side"
			_disable_action(b,"lure")
			_disable_action(b,"first_direct")
			b.lit_cells[SIDE_RETURN_CELL] = 18.0
			for i in range(enemy_fleet.size()):
				var ship=enemy_fleet[i]
				ship.stance=Unit.STANCE_AGGRO
				ship.passive=false
				if i<3:
					ship.set_meta("lure_lane","side")
					ship.order_amove(b.map.cell_to_world(SIDE_AMBUSH_CELL))
				else:
					ship.set_meta("lure_lane","main")
					ship.order_amove(b.map.cell_to_world(Vector2i(41,34)))
			b.mission.mark("lure_route_side","阮小七转入东岸侧汊，前部官船被迫转弯，后船仍压主港。")
			b.mission.set_objective("侧汊已把官船分向。请玩家命阮小七退入侧汊，让至少一艘活官船进入岸弓伏区，再以两路水军合击。")
		"first_direct":
			_start_first_direct(b,"梁山水军主动驶出伏港迎战")
		"raise_wind":
			if stage!="fire_prepare" or fire_wind_ready or _actor!=wind_leader: return
			fire_wind_ready=true
			b.mission.mark("gongsun_wind","公孙胜在山边祭风，风势转向相连官船。")
			_actor.resolve_story("retreated")
			b.mission.begin(stage,"第二败·刘唐受计","风势已成。吴用命刘唐掌管水路，把引火物装入小船后亲自登船；也可放弃火攻，直接迎战连船。")
			b.mission.add_action("prepare_fireboat","刘唐：检点引火物并登船",FIRE_LEADER_CELL,["liu_tang"],1.5,48.0)
			b.mission.add_action("fire_direct","水军：正面破舰（放弃火攻印）",Vector2i(41,35),["liu_tang_fireboat","ruan_xiaoer_boat","ruan_xiaowu_boat","liangshan_warship"],0.8,64.0)
		"prepare_fireboat":
			if stage!="fire_prepare" or not fire_wind_ready or _actor!=fire_leader: return
			fire_prepared=true
			b.mission.mark("liu_tang_fire_leader","吴用所授火船之计由刘唐掌管。")
			b.mission.mark("fireboat_prepared","刘唐检点火具后登上举火小船；本幕只有这一条火船。")
			_actor.resolve_story("embarked")
			fireboat.set_meta("story_commander","liu_tang")
			stage="fire_position"
			b.mission.begin(stage,"第二败·刘唐驶近连船","官船首尾相连。刘唐的火船必须真的驶到北段或南段旁边，只能选择一个火点；两艘接应船留在退路。")
			b.mission.add_action("fire_north","刘唐火船驶近北段",FIRE_NORTH_CELL,["liu_tang_fireboat"],1.0,36.0)
			b.mission.add_action("fire_south","刘唐火船驶近南段",FIRE_SOUTH_CELL,["liu_tang_fireboat"],1.0,36.0)
		"fire_north", "fire_south":
			if stage!="fire_position" or not fire_prepared or _actor!=fireboat: return
			fire_point="north" if action_id=="fire_north" else "south"
			stage="fire_ignite"
			var point: Vector2i=FIRE_NORTH_CELL if fire_point=="north" else FIRE_SOUTH_CELL
			b.mission.begin(stage,"第二败·择点举火","火船已贴近%s连船。现在点火，火势只会沿相连的这一段蔓延；接应船随后必须撤出险水。"%("北段" if fire_point=="north" else "南段"))
			b.mission.add_action("ignite_fireboat","刘唐：点燃火船",point,["liu_tang_fireboat"],1.5,40.0)
		"ignite_fireboat":
			if stage!="fire_ignite" or fire_lit or _actor!=fireboat: return
			var point: Vector2i=FIRE_NORTH_CELL if fire_point=="north" else FIRE_SOUTH_CELL
			if not fire_prepared or _actor.position.distance_to(b.map.cell_to_world(point))>48.0 or not _official_chain_connected(b):
				b.mission.mark("fire_ignite_blocked","火船没有贴住仍相连的官船，隔水举火未能生效。")
				_retry_action(b,action_id,"火船尚未贴住相连官船，不能隔水点火。把火船驶回选定火点后再试。")
				return
			fire_lit=true
			var affected: Array=[0,1,2] if fire_point=="north" else [2,3,4]
			for i in affected:
				var ship=enemy_fleet[i]
				if is_instance_valid(ship) and ship.hp>0.0 and ship.story_outcome=="":
					ship.set_meta("ship_state","disabled")
					ship.resolve_story("subdued")
			fireboat.set_meta("ship_state","disabled")
			fireboat.resolve_story("retreated")
			b.mission.mark("fire_point_"+fire_point,"刘唐在%s段举火，火势沿三艘相连官船蔓延；另两艘已经解缆逼向接应队。"%("北" if fire_point=="north" else "南"))
			for ship in enemy_fleet:
				if _effective(ship):
					ship.passive=false; ship.stance=Unit.STANCE_AGGRO
					var target=_nearest_effective(ship,fire_escorts)
					if target!=null: ship.order_attack(target)
			for ship in fleet:
				if _effective(ship) and ship!=fireboat and ship not in fire_escorts:
					ship.passive=false; ship.stance=Unit.STANCE_AGGRO
			stage="fire_withdraw"
			b.mission.begin(stage,"第二败·接应撤离","火点已成。阮小二、阮小五两艘接应船都要活着撤到南侧安全水域；若余下官船逼近，先压退再撤。")
			b.mission.add_action("fire_withdraw","接应船撤出险水",FIRE_SAFE_CELL,["ruan_xiaoer_boat","ruan_xiaowu_boat"],1.0,56.0)
			b.mission.set_status("两艘接应船均由玩家指挥；先压住追船，再亲自撤到南侧安全水域。")
		"fire_withdraw":
			if stage!="fire_withdraw" or fire_withdrawn: return
			if not fire_escorts.all(func(ship): return _effective(ship) and ship.position.distance_to(b.map.cell_to_world(FIRE_SAFE_CELL))<=96.0):
				b.mission.mark("fire_withdraw_split","两艘接应船没有一同撤出险水，撤离暂缓。")
				_retry_action(b,action_id,"两艘接应船尚未一起撤到安全水域；收拢阮小二、阮小五后再试。")
				return
			for enemy in enemy_fleet:
				if _effective(enemy) and enemy.position.distance_to(b.map.cell_to_world(FIRE_SAFE_CELL))<210.0:
					b.mission.mark("fire_withdraw_pursued","余下官船追进撤离水域，接应队必须先压退追船。")
					_retry_action(b,action_id,"仍有官船追进安全水域。先压退或逼停追船，再完成接应撤离。")
					return
			fire_withdrawn=true
			b.mission.mark("fire_escort_safe","两艘接应船都撤出火势与追船范围，有限火船任务完成。")
			_start_land_closure(b)
		"fire_direct":
			_start_fire_direct(b,"梁山水军放弃举火，改以现存战船正面破舰")
		"land_ambush":
			if stage!="land_ambush": return
			land_started=true
			for i in range(24):
				land_enemies.append(b.spawn_at("guan_qi" if i%4==0 else "guan_dao",1,Vector2i(17+i%3,2+i/3)))
			for enemy in land_enemies: enemy.order_amove(hall.position)
			b.mission.set_objective("官军沿岸路逼近山寨。守住林口与忠义堂，以伏兵迎击。")
		"sortie":
			if stage!="final_fleet": return
			for ship in enemy_fleet:
				ship.stance=Unit.STANCE_AGGRO
				ship.passive=false
				ship.order_amove(b.map.cell_to_world(Vector2i(41,45)))
			flagship.order_move(b.map.cell_to_world(FINAL_FLAG_CELL))
			_actor.set_meta("bait_withdrawing", true)
			b.lit_cells[Vector2i(41,47)] = 18.0
			b.mission.add_action("scuttle","张顺：靠近凿船",FINAL_SCUTTLE_CELL,["zhang_shun_boat"],2.5,72.0)
			b.mission.set_objective("请玩家命哨船撤回南港。先压制至少三艘前列官船，封港任务才会出现；张顺现在硬冲会被前列官船围攻，但可在补救后重试。")
			lure_started=true
		"final_direct":
			_start_final_direct(b,"梁山水军不等诱船，直接迎击前列官船与高俅座船")
		"seal_port":
			if stage!="final_fleet" or port_sealed: return
			if not lure_started or not escort_suppressed or not is_instance_valid(flagship) or flagship.position.distance_to(b.map.cell_to_world(FINAL_FLAG_CELL))>144.0:
				_retry_action(b,action_id,"座船还未进入南港，或前列官船尚未压住。先击退至少三艘前列官船，再到港口封住退路。")
				return
			port_sealed=true
			flagship.order_stop(); flagship.base_speed=0.0; flagship.passive=true; flagship.stance=Unit.STANCE_PASSIVE
			if flagship.story_outcome=="": flagship.resolve_story("subdued")
			flagship.set_meta("ship_state","damaged"); flagship.queue_redraw()
			for ship in enemy_fleet:
				if _effective(ship): ship.resolve_story("retreated")
			b.mission.mark("port_sealed","前列官船已受压，阮氏水军封住南港；残余官船解缆退走，高俅座船失去机动。")
			stage="scuttle"
			b.mission.begin(stage,"第三败·安全靠船","座船已失去机动。张顺小艇现在可以沿南港靠近凿船，不必磨尽座船船身。")
			b.mission.add_action("scuttle","张顺凿破座船",FINAL_SCUTTLE_CELL,["zhang_shun_boat"],2.5,72.0)
		"scuttle":
			if transfer_done or not is_instance_valid(flagship): return
			if stage=="final_fleet":
				hard_rushes+=1
				for ship in enemy_fleet:
					if _effective(ship): ship.order_attack(_actor)
				b.mission.mark("scuttle_hard_rush","张顺未等前列官船受压、港口封住便硬冲，现存官船立即围向小艇；先撤回并压制前列官船，仍可补救。")
				_retry_action(b,action_id,"小艇硬冲正被前列官船围攻。先让主力压制三艘前列官船并封住港口，再让张顺靠船。")
				return
			if stage!="scuttle" or not port_sealed or flagship.story_outcome!="subdued" or not is_instance_valid(_actor) or _actor.position.distance_to(flagship.position)>SCUTTLE_RANGE:
				_retry_action(b,action_id,"张顺尚未安全贴近失去机动的座船，沿南港把小艇靠上去后再凿。")
				return
			flagship.set_meta("ship_state","flooding")
			flagship.queue_redraw()
			b.mission.mark("flagship_scuttled","张顺凿破海鳅船底，舱中涌进水来。快把小艇靠上去，活捉高俅！")
			stage="water_rescue"
			b.mission.begin(stage,"凿船后·水上擒俘","座船正在下沉。命张顺小艇靠近座船，接起落水高俅，再沿水道押回主码头。")
			b.mission.add_action("recover_gao","张顺：接起落水高俅",FINAL_SCUTTLE_CELL,["zhang_shun_boat"],2.0,72.0)
		"recover_gao":
			if stage!="water_rescue" or recovered_gao or transfer_done: return
			if not is_instance_valid(_actor) or not is_instance_valid(flagship) or _actor.position.distance_to(flagship.position)>SCUTTLE_RANGE:
				_retry_action(b,action_id,"小艇尚未贴近进水座船，沿南港凿船位靠近后再接起高俅。")
				return
			recovered_gao=true
			flagship.set_meta("ship_state","disabled")
			flagship.queue_redraw()
			_actor.set_meta("carried_story_person","高俅")
			_actor.display_name="张顺·押送高俅"
			b.mission.mark("flagship_sunk","座船沉陷，张顺把高俅救上小艇。押送艇须沿水道返抵主码头。")
			stage="return_prisoner"
			b.mission.begin(stage,"押俘返航·主码头交接","高俅已在张顺小艇上。沿南港返航，到寨门外的主码头停靠，再交给岸上军士。")
			b.mission.add_action("land_gao","押送小艇返回主码头",PRISONER_DOCK_WATER,["zhang_shun_boat"],1.0,24.0)
		"land_gao":
			if stage!="return_prisoner" or not recovered_gao or transfer_done: return
			if not is_instance_valid(_actor) or _actor.key!="zhang_shun_boat" or _actor.hp<=0.0: return
			if _actor.position.distance_to(b.map.cell_to_world(PRISONER_DOCK_WATER))>24.0: return
			if b.map.t_at(PRISONER_DOCK_LAND.x,PRISONER_DOCK_LAND.y)!=T.DOCK or not b.map.is_open_world(_actor.position,"water"): return
			# Lock before spawning: a repeated callback can never create another prisoner.
			transfer_done=true
			_actor.remove_meta("carried_story_person")
			_actor.display_name="张顺·凿船小艇"
			b.mission.mark("gao_landed","押送艇抵主码头，水军把高俅交给岸上军士。")
			gao=b.spawn_at("gao_qiu",1,PRISONER_DOCK_LAND)
			gao.art_variant="gao_qiu_captured"
			gao.is_cavalry=false
			gao.atk=0; gao.base_speed=0; gao.is_captive=true; gao.defeat_outcome="captured"
			var rescuer=b.spawn_at("zhang_shun",0,PRISONER_DOCK_LAND+Vector2i(-1,0))
			rescuer.stance=Unit.STANCE_PASSIVE
			stage="capture_gao"
			b.mission.begin(stage,"第三败·生擒太尉","高俅已被押到岸上。让张顺前去交接，留下俘虏性命，送往忠义堂。")
			b.mission.add_action("capture_gao","张顺：交接俘虏",b.map.world_to_cell(gao.position),["zhang_shun"],2.0)
		"capture_gao":
			if stage=="capture_gao" and is_instance_valid(gao): gao.resolve_story("captured")

func _alive(arr: Array) -> int:
	return arr.filter(func(u): return is_instance_valid(u) and u.hp>0 and u.story_outcome=="").size()

func _effective(u) -> bool:
	return is_instance_valid(u) and u.hp>0.0 and u.story_outcome==""

func _nearest_effective(origin, choices: Array):
	var best=null
	var best_distance:=INF
	for candidate in choices:
		if not _effective(candidate): continue
		var distance: float=origin.position.distance_squared_to(candidate.position)
		if distance<best_distance:
			best=candidate; best_distance=distance
	return best

func _official_chain_connected(b) -> bool:
	if enemy_fleet.size()!=5 or not enemy_fleet.all(func(ship): return _effective(ship)):
		return false
	var ordered:=enemy_fleet.duplicate()
	ordered.sort_custom(func(a,c): return a.position.y<c.position.y)
	for i in range(1,ordered.size()):
		if ordered[i-1].position.distance_to(ordered[i].position)>116.0:
			return false
		if not b.map._segment_open(ordered[i-1].position,ordered[i].position,"water"):
			return false
	return true

func _retry_action(b,action_id: String,reason: String) -> void:
	if b.mission.actions.has(action_id):
		var action: Dictionary=b.mission.actions[action_id]
		action.done=false
		action.button.disabled=false
		action.marker.show()
		b.mission._refresh_marker_captions()
	b.mission.set_objective(reason)
	b.msg(reason,4.0)

func _disable_action(b,action_id: String) -> void:
	if not b.mission.actions.has(action_id): return
	var action: Dictionary=b.mission.actions[action_id]
	action.done=true
	action.button.disabled=true
	action.marker.hide()
	b.mission._refresh_marker_captions()

func _miss_story(b,goal_id: String,reason: String) -> void:
	if b.mission.has_method("miss_story_goal"):
		b.mission.miss_story_goal(goal_id,reason)

func _complete_story(b,goal_id: String,note: String) -> void:
	if b.mission.has_method("complete_story_goal"):
		b.mission.complete_story_goal(goal_id,note)

func _fleet_has_damage(arr: Array) -> bool:
	for ship in arr:
		if not is_instance_valid(ship) or ship.story_outcome != "" or ship.hp < ship.max_hp:
			return true
	return false

func _activate_fleet(arr: Array,target: Vector2) -> void:
	for ship in arr:
		if not _effective(ship): continue
		ship.passive=false
		if ship.faction == Unit.FACTION_GUAN:
			ship.stance=Unit.STANCE_AGGRO
			ship.order_amove(target)
		else:
			# 梁山舰船只解除剧情待机，不替玩家选择目标或航线。
			ship.stance=Unit.STANCE_DEFEND

func _start_first_direct(b,reason: String, allow_started_route := false) -> void:
	if stage!="water_lure" or lure_route=="direct" or lure_complete or (lure_started and not allow_started_route): return
	first_direct=true
	lure_started=true
	lure_route="direct"
	b.mission.mark("gao_first_direct",reason+"；伏港诱舰不再计演义印")
	_miss_story(b,"gao_lure","没有先诱官船深入港汊")
	_activate_fleet(enemy_fleet,b.map.cell_to_world(Vector2i(41,38)))
	_activate_fleet(fleet,b.map.cell_to_world(Vector2i(41,24)))
	b.mission.begin("water_direct","第一败·正面水战","官船未入伏港便已接战。击退现存官船仍可进入第二次进兵，但本次诱舰演义印已经失效。")

func _start_fire_direct(b,reason: String) -> void:
	if stage not in ["fire_prepare","fire_position","fire_ignite","fire_withdraw"] or fire_direct: return
	fire_direct=true
	stage="fire_direct"
	b.mission.mark("gao_fire_direct",reason)
	_miss_story(b,"gao_fire","未完成小船举火并护接应船撤出的演义过程")
	_activate_fleet(enemy_fleet,b.map.cell_to_world(FIRE_SAFE_CELL))
	_activate_fleet(fleet,b.map.cell_to_world(Vector2i(41,24)))
	b.mission.begin(stage,"第二败·正面破连舰","火船章法已经中断。现存梁山战船可直接击退官船；代价是失去举火接应演义印，不会因此判整关失败。")

func _start_final_direct(b,reason: String) -> void:
	if stage!="final_fleet" or final_direct: return
	final_direct=true
	lure_started=true
	b.mission.mark("gao_final_direct",reason)
	_activate_fleet(enemy_fleet,b.map.cell_to_world(Vector2i(41,45)))
	_activate_fleet(fleet,b.map.cell_to_world(Vector2i(41,25)))
	if _effective(flagship):
		flagship.passive=false
		flagship.stance=Unit.STANCE_AGGRO
		flagship.order_move(b.map.cell_to_world(FINAL_FLAG_CELL))
	b.mission.begin("final_fleet","第三败·自由水战","可正面压退或击沉高俅座船取得基础胜利。若阮氏封港船与张顺小艇仍在，也可继续压前列官船、封港凿船，争取生擒押堂演义印。")

func _capture_route_available() -> bool:
	var zhang_ok := fleet.any(func(ship): return _effective(ship) and ship.key=="zhang_shun_boat")
	var seal_ok := fleet.any(func(ship): return _effective(ship) and ship.key in ["ruan_xiaoer_boat","ruan_xiaowu_boat"])
	return zhang_ok and seal_ok

func _mark_capture_route_lost(b,reason: String) -> void:
	if b.mission.has_event("gao_capture_route_lost"): return
	b.mission.mark("gao_capture_route_lost",reason+"；仍可正面击退或击沉座船")
	_miss_story(b,"gao_capture",reason)

func _finish_final_direct(b,result: String) -> void:
	if final_direct_victory: return
	if not is_instance_valid(hall) or hall.hp<=0.0 or not commanders.all(func(h): return is_instance_valid(h) and h.hp>0.0 and h.story_outcome==""):
		b.lose("中军或忠义堂已经失守，第三次水战不能结算为胜利。")
		return
	final_direct_victory=true
	stage="final_complete"
	var event_id := "flagship_sunk_direct" if result=="sunk" else "flagship_repelled"
	var event_text := "高俅座船在正面水战中沉没" if result=="sunk" else "高俅座船失去战力，被官军残部拖离战场"
	b.mission.mark(event_id,event_text)
	b.mission.mark("gao_escaped","高俅没有被生擒押回忠义堂")
	_miss_story(b,"gao_capture","末战已经取胜，但没有完成封港、凿船、生擒与押堂")
	for ship in enemy_fleet:
		if _effective(ship): ship.resolve_story("retreated")
	if result=="sunk":
		b.win("高俅座船在正面水战中沉没，残余官船溃退，第三次进兵被击败。高俅没有被生擒押回忠义堂，因此本局取得基础胜利，不计生擒演义印。")
	else:
		b.win("高俅座船被压退，残余官船退出梁山水泊，第三次进兵被击败。高俅随残部退去，没有被押上忠义堂，因此本局取得基础胜利，不计生擒演义印。")

func process(b, delta: float) -> void:
	elapsed+=delta
	for ship in fleet:
		if is_instance_valid(ship) and ship.hp > 0.0 and bool(ship.get_meta("bait_withdrawing", false)) and ship.position.distance_to(b.map.cell_to_world(Vector2i(41,47))) < 112.0:
			ship.set_meta("bait_withdrawing", false)
	if not is_instance_valid(hall) or hall.hp<=0:
		b.lose("忠义堂失守，水陆部署失败。")
		return
	for h in commanders:
		if not is_instance_valid(h) or h.hp<=0:
			b.lose("宋江、吴用必须存活，才能继续统领水陆军。")
			return
	# Damage was previously the only implicit signal for abandoning the third
	# lure.  A player-issued focus attack can cross the nearby "sortie" marker
	# before its first shot; the mission zone would then reinterpret that attack as
	# the authored lure.  Respect the still-live manual target immediately.  AI and
	# scripted orders do not carry the manual stamp and cannot select this branch.
	if stage=="final_fleet" and not lure_started:
		for ship in fleet:
			if not _effective(ship) or not (ship.manual_order_active or ship.manual_order_t>0.0): continue
			if ship._target==flagship or ship._target in enemy_fleet:
				_start_final_direct(b,"梁山水军收到玩家命令，主动攻击前列官船与高俅座船")
				break
	if stage=="water_lure" and not lure_started and (_fleet_has_damage(enemy_fleet) or not fleet.any(func(ship): return _effective(ship) and ship.key=="ruan_xiaoqi_boat")):
		_start_first_direct(b,"官船已在伏区外接战")
	if stage=="fire_prepare":
		if not fire_wind_ready and not _effective(wind_leader):
			_start_fire_direct(b,"公孙胜未能祭风，现存战船改为正面作战")
		elif fire_wind_ready and not fire_prepared and not _effective(fire_leader):
			_start_fire_direct(b,"刘唐未能登上火船，现存战船改为正面作战")
	if stage in ["fire_prepare","fire_position","fire_ignite"]:
		if not _effective(fireboat):
			_start_fire_direct(b,"唯一火船损失，现存战船接替正面作战")
		elif _alive(enemy_fleet)<5 or _fleet_has_damage(enemy_fleet):
			_start_fire_direct(b,"相连官船在举火前已被打散，水军顺势正面接战")
	if stage in ["fire_prepare","fire_position","fire_ignite","fire_withdraw"] and not fire_escorts.all(func(ship): return _effective(ship)):
		_start_fire_direct(b,"接应船未能全身而退，现存战船继续正面破舰")
	if stage=="final_fleet" and not lure_started and (_fleet_has_damage(enemy_fleet) or (is_instance_valid(flagship) and flagship.hp<flagship.max_hp) or not fleet.any(func(ship): return _effective(ship) and ship.key=="ruan_xiaoqi_boat")):
		_start_final_direct(b,"官军已在诱船前接战")
	if stage in ["final_fleet","scuttle","water_rescue","return_prisoner"] and not _capture_route_available():
		_mark_capture_route_lost(b,"封港船或张顺小艇损失，生擒押堂路线已经中断")
		if stage=="final_fleet":
			_start_final_direct(b,"生擒所需专用船损失，现存水军改为正面迎击高俅座船")
		elif stage in ["scuttle","water_rescue","return_prisoner"]:
			_finish_final_direct(b,"sunk" if b.mission.has_event("flagship_scuttled") else "repelled")
			return
	if stage=="water_lure" and lure_started:
		if not lure_complete and lure_route!="direct":
			for ship in enemy_fleet:
				if not _effective(ship): continue
				var cell: Vector2i=b.map.world_to_cell(ship.position)
				var entered: bool=cell.y>=31 if lure_route=="main" else cell.x<=37 and cell.y>=25
				if entered:
					lure_complete=true
					b.mission.mark("fleet_in_ambush","官军舰队从%s深入伏区，岸上弓手与水军形成夹击。"%("主港" if lure_route=="main" else "侧汊"))
					break
		if _alive(enemy_fleet)==0:
			# Destroying the fleet before a living ship reaches the ambush remains a
			# valid free-play clear, but it is the direct route and earns no lure seal.
			if not lure_complete and lure_route!="direct":
				_start_first_direct(b,"官船未入伏区即全部失去战力",true)
			_start_land(b)
		elif _alive(fleet)==0: b.lose("第一路水军战船尽失，且仍有官船在水面；已无兵力击退本次进兵。")
	elif stage=="fire_direct":
		if _alive(enemy_fleet)==0: _start_land_closure(b)
		elif _alive(fleet)==0: b.lose("第二路水军战船尽失，且仍有官船在水面；正面破舰已无可用兵力。")
	elif stage=="land_ambush" and land_started and _alive(land_enemies)==0:
		_start_final_fleet(b)
	elif stage=="final_fleet" and lure_started:
		if is_instance_valid(flagship) and flagship.story_outcome!="" and not port_sealed:
			_finish_final_direct(b,"sunk" if String(flagship.get_meta("ship_state","")) in ["flooding","disabled"] else "repelled")
			return
		if _alive(fleet)==0:
			b.lose("第三路水军战船尽失，高俅座船仍能作战，已无兵力击退本次进兵。")
		elif not escort_suppressed and _alive(enemy_fleet)<=2:
			escort_suppressed=true
			b.mission.mark("escort_suppressed","五船压缩官船队已有三艘失去战力，南港封锁窗口出现。")
			if _capture_route_available():
				b.mission.add_action("seal_port","阮氏水军：封住南港",FINAL_SEAL_CELL,["ruan_xiaoer_boat","ruan_xiaowu_boat"],2.0,56.0)
				b.mission.set_objective("前列官船已受压。让阮小二或阮小五到南港封口；张顺继续留后，封港后再靠船。也可直接攻击座船取得基础胜利。")
			else:
				b.mission.set_objective("前列官船已受压，但生擒所需专用船已经损失。集中现存战船击退或击沉高俅座船。")

func _reset_section(b) -> void:
	b.clear_campaign_section()
	fleet.clear(); enemy_fleet.clear(); land_enemies.clear(); commanders.clear()
	fireboat=null; fire_escorts.clear(); fire_leader=null; wind_leader=null; vanguard_headship=null
	_spawn_command(b)

func _start_land(b) -> void:
	b.mission.mark("first_defeat",("【再战·刘唐举火破连舰】梁山正面击退第一路官船，高俅收拢船只再来。" if first_direct else "【再战·刘唐举火破连舰】官船被诱入港汊，第一次水战失利，高俅收拢船只再来。")+"牛邦喜与刘梦龙、党世英掌管水路再进；吴用命刘唐掌管火船，公孙胜祭风。梁山只备一条举火小船，两艘水军船负责接应。也可承担代价改用正面战。")
	_reset_section(b)
	stage="fire_prepare"
	fire_direct=false; fire_wind_ready=false; fire_prepared=false; fire_point=""; fire_lit=false; fire_withdrawn=false
	fleet=[b.spawn_at("liu_tang_fireboat",0,Vector2i(41,38)),b.spawn_at("ruan_xiaoer_boat",0,Vector2i(40,34)),
		b.spawn_at("ruan_xiaowu_boat",0,Vector2i(43,35)),b.spawn_at("liangshan_warship",0,Vector2i(40,39)),b.spawn_at("liangshan_warship",0,Vector2i(43,40))]
	for ship in fleet:
		ship.visual_scale=1.2; ship.passive=true; ship.stance=Unit.STANCE_PASSIVE
	fireboat=fleet[0]
	fireboat.display_name="刘唐·举火小船"
	fire_escorts=[fleet[1],fleet[2]]
	wind_leader=b.spawn_at("gongsun_sheng",0,FIRE_WIND_CELL)
	fire_leader=b.spawn_at("liu_tang",0,FIRE_LEADER_CELL)
	wind_leader.stance=Unit.STANCE_PASSIVE; fire_leader.stance=Unit.STANCE_PASSIVE
	for i in range(5):
		var ship=b.spawn_at("imperial_warship",1,Vector2i(42,19+i*3))
		ship.visual_scale=1.4; ship.passive=true; ship.stance=Unit.STANCE_PASSIVE
		ship.set_meta("chain_index",i)
		enemy_fleet.append(ship)
	b.mission.begin(stage,"第二败·公孙胜祭风","吴用已把火船任务交给刘唐。先让公孙胜在山边祭风，再由刘唐检点引火物登船；也可直接迎战，但不会获得本幕演义印。")
	b.mission.add_action("raise_wind","公孙胜：祭风",FIRE_WIND_CELL,["gongsun_sheng"],1.5,48.0)
	b.mission.add_action("fire_direct","水军：正面破舰（放弃火攻印）",Vector2i(41,35),["liu_tang_fireboat","ruan_xiaoer_boat","ruan_xiaowu_boat","liangshan_warship"],0.8,64.0)
	b.camera.position=b.to_screen(b.map.cell_to_world(FIRE_WIND_CELL))

func _start_land_closure(b) -> void:
	if fire_direct:
		b.mission.mark("second_water_direct","现存水军正面击退相连官船；第二次进兵只剩岸上来路需要收束。")
	else:
		b.mission.mark("fireboat_complete","举火小船破坏相连官船，水军接应脱险；第二次进兵只剩岸上来路需要收束。")
	_reset_section(b)
	stage="land_ambush"
	for i in range(18):
		b.spawn_at("liang_qiang" if i%2==0 else "liang_gong",0,Vector2i(24+i%5,25+i/5))
	b.spawn_at("lin_chong",0,Vector2i(25,24))
	b.spawn_at("hua_rong",0,Vector2i(27,26))
	b.mission.begin(stage,"第二败·岸路收束",("正面水战已经结束。" if fire_direct else "举火接应已经完成。")+"命岸军到林口布置伏兵，收束山前来路；陆军沿北侧山路迎敌，不能渡过港水。")
	b.mission.add_action("land_ambush","岸军：布置山前伏兵",Vector2i(23,22),["lin_chong","hua_rong","liang_qiang","liang_gong"],3.0)
	b.camera.position=b.to_screen(b.map.cell_to_world(Vector2i(23,22)))

func _start_final_fleet(b) -> void:
	b.mission.mark("second_defeat","【入冬·海鳅船来犯】到了十一月，高俅坐镇中军亲来；丘岳、徐京、梅展管领三十只大海鳅船为先锋，杨温、长史王瑾、船匠叶春管领五十只小海鳅船开路。当前关卡压缩为一艘先锋头船与四艘普通官船，梁山水军整装出港迎战。")
	_reset_section(b)
	stage="final_fleet"; lure_started=false; port_sealed=false; escort_suppressed=false; hard_rushes=0
	final_direct=false; final_direct_victory=false; transfer_done=false; recovered_gao=false; gao=null
	for record in [["ruan_xiaoqi_boat",Vector2i(41,43)],["ruan_xiaoer_boat",Vector2i(40,46)],
		["ruan_xiaowu_boat",Vector2i(43,46)],["zhang_shun_boat",Vector2i(31,51)],
		["liangshan_warship",Vector2i(40,49)],["liangshan_warship",Vector2i(43,50)]]:
		var ship=b.spawn_at(record[0],0,record[1]); ship.visual_scale=1.2; fleet.append(ship)
	for i in [4,5]: fleet[i].display_name="梁山水军战船"
	for i in range(5):
		var ship_key := "official_vanguard" if i == 0 else "imperial_warship"
		var ship=b.spawn_at(ship_key,1,Vector2i(40+i%3,8+i*3))
		ship.visual_scale=1.8 if ship_key == "official_vanguard" else 1.4
		ship.passive=true; ship.stance=Unit.STANCE_PASSIVE
		if ship_key == "official_vanguard":
			vanguard_headship=ship
			ship.set_meta("campaign_flag_context","chapter80_vanguard_headship")
		enemy_fleet.append(ship)
	flagship=b.spawn_at("gao_flagship",1,Vector2i(42,5)); flagship.visual_scale=1.8; flagship.defeat_outcome="subdued"
	flagship.set_meta("campaign_flag_context","chapter80_gao_flagship")
	flagship.stance=Unit.STANCE_PASSIVE; flagship.passive=true
	b.mission.begin(stage,"第三败·压前列官船再封港","高俅中军在后，丘岳、徐京、梅展所领先锋头船在前。先用哨船诱敌，主力压住至少三艘前列官船，再由阮氏水军封住南港。张顺硬冲会被围攻，封港后才有安全靠船窗口。")
	b.mission.add_action("sortie","水军引大船深入",Vector2i(41,35),["ruan_xiaoqi_boat"],2.0)
	b.mission.add_action("final_direct","水军：正面迎击（保留基础胜利）",Vector2i(39,28),["ruan_xiaoqi_boat","ruan_xiaoer_boat","ruan_xiaowu_boat","zhang_shun_boat","liangshan_warship"],0.8,48.0)
	b.camera.position=b.to_screen(b.map.cell_to_world(Vector2i(39,43)))

func on_unit_resolved(b, u, outcome: String) -> void:
	if u==vanguard_headship and outcome in ["subdued","retreated","destroyed"]:
		u.set_meta("ship_state","disabled" if outcome in ["subdued","retreated"] else "damaged")
		u.queue_redraw()
	if u==flagship and outcome in ["subdued","destroyed"]:
		u.set_meta("ship_state","damaged")
		if port_sealed:
			b.mission.mark("flagship_disabled","高俅座船已被封港压住，护住张顺小艇，继续凿船生擒。")
		else:
			_finish_final_direct(b,"sunk" if outcome=="destroyed" else "repelled")
	if u==gao and outcome=="captured" and transfer_done and recovered_gao and b.mission.has_event("gao_landed"):
		# Task callbacks run after damage zones in a frame. Re-check living command now,
		# not only in the later level.process, so a simultaneous loss cannot become a win.
		if not is_instance_valid(hall) or hall.hp<=0.0 or not commanders.all(func(h): return is_instance_valid(h) and h.hp>0.0 and h.story_outcome==""):
			b.lose("中军或忠义堂已失守，梁山未能守住。")
			return
		b.mission.mark("gao_captured","高俅被生擒，送往忠义堂。")
		_complete_story(b,"gao_capture","封港凿船后生擒高俅，并押回忠义堂")
		b.win("高俅三次进兵失利，终于被生擒上山。张顺押他到忠义堂，宋江仍以礼相待，盼借此求得招安；林冲、杨志却怒目而视。")

func on_unit_died(b, u) -> void:
	if u==hall or u in commanders:
		b.lose("忠义堂或中军首领阵亡，水陆指挥失败。")
		return
	if u.key=="zhang_shun" and stage=="capture_gao":
		_mark_capture_route_lost(b,"张顺未能完成岸上俘虏交接")
		_finish_final_direct(b,"sunk")
		return
	if u==gao:
		_mark_capture_route_lost(b,"高俅未能以活俘身份押堂")
		_finish_final_direct(b,"sunk")
		return
	if u==flagship and stage in ["final_fleet","scuttle","water_rescue","return_prisoner"]:
		_finish_final_direct(b,"sunk")
		return
	if u.key=="ruan_xiaoqi_boat" and not lure_started and stage in ["water_lure","final_fleet"]:
		if stage=="water_lure": _start_first_direct(b,"阮小七哨船损失，余船被迫正面迎击")
		else: _start_final_direct(b,"阮小七哨船损失，余船直接迎击第三路官军")
	if stage in ["fire_prepare","fire_position","fire_ignite","fire_withdraw"] and (u==fireboat or u in fire_escorts):
		_start_fire_direct(b,"举火或接应所需船只损失，余船改为正面作战")
	if stage in ["final_fleet","scuttle","water_rescue","return_prisoner"] and u.key in ["zhang_shun_boat","ruan_xiaoer_boat","ruan_xiaowu_boat"] and not _capture_route_available():
		_mark_capture_route_lost(b,"封港凿船所需专用船损失")

func top_status(_b) -> String:
	var names := {"water_lure": "第一败·水战", "fire_prepare":"第二败·准备举火", "fire_position":"第二败·驶近连船", "fire_ignite":"第二败·择点举火", "fire_withdraw":"第二败·接应撤离", "fire_direct":"第二败·正面破舰", "land_ambush": "第二败·岸路收束", "final_fleet": "第三败·水战", "scuttle": "第三败·凿船", "water_rescue":"第三败·水上擒俘", "return_prisoner":"第三败·押俘返航", "capture_gao": "第三败·生擒高俅", "final_complete":"第三败·基础胜利"}
	return "三败高太尉 · %s | 舰船走水道，陆军走岸路" % names.get(stage, "水陆布阵")

func paint_map(map: GameMap) -> void:
	map.fill_ellipse(Vector2(20, 30), 19, 16, T.MARSH)
	map.fill_ellipse(Vector2(20, 30), 14, 11, T.GRASS)
	map.scatter(T.MARSH, T.REEDS, 6)
	map.fill_ellipse(Vector2(AMBUSH_E.x, AMBUSH_E.y), 3, 2, T.REEDS, [T.MARSH])
	map.fill_ellipse(Vector2(AMBUSH_S.x, AMBUSH_S.y), 3, 2, T.REEDS, [T.MARSH])
	map.paint_path([Vector2(59, 22), Vector2(42, 22), Vector2(38, 27), Vector2(34, 29), Vector2(20, 30)], 1, T.ROAD)
	map.paint_path([Vector2(59, 46), Vector2(46, 46), Vector2(38, 39), Vector2(33, 36), Vector2(22, 32)], 1, T.ROAD)
	map.fill_ellipse(Vector2(14, 24), 3, 2, T.FOREST, [T.GRASS])
	map.fill_ellipse(Vector2(13, 37), 3, 2, T.FOREST, [T.GRASS])
	map.fill_ellipse(Vector2(25, 22), 2, 2, T.FOREST, [T.GRASS])
	if Layout.enabled():
		Landscape.paint(map)
		Layout.paint(map)
	# Remove the former two cross-water causeways. The northern mountain road carries land forces.
	map.fill_rect(39,0,6,54,T.WATER)
	map.fill_rect(20,50,25,4,T.WATER)
	# A real, connected side channel: water movement can loop out of and back into the
	# main harbor, while the adjoining reed/grass banks remain land-only bow positions.
	map.paint_path([Vector2(42,21),Vector2(38,21),Vector2(35,24),Vector2(34,29),Vector2(36,34),Vector2(40,36)],1,T.WATER)
	map.paint_path([Vector2(18,0),Vector2(18,6),Vector2(21,11),Vector2(19,17),Vector2(23,22),Vector2(29,28)],1,T.ROAD)
	for y in range(HALL_CELL.y - 1, HALL_CELL.y + 2):
		for x in range(HALL_CELL.x - 1, HALL_CELL.x + 2):
			map.set_cell_t(x, y, T.HALL)


func decorate(map: GameMap) -> void:
	map.decor = [
		["tower", Vector2i(33, 32), 76.0], ["tower", Vector2i(31, 38), 76.0],
		# 第七十一回：忠义堂前两面绣字红旗。west/east 只用于当前地图落位，
		# 原文没有把两句分别指定在左右哪一面。
		["banner", Vector2i(18, 33), 220.0, "zhongyi_hall_standard_east"],
		["banner", Vector2i(14, 33), 220.0, "zhongyi_hall_standard_west"],
		# 山顶杏黄主旗放在后山主脊的 cliff 格；移除同格石块，避免旗杆插进岩石。
		["banner", Vector2i(10, 15), 220.0, "liangshan_hilltop_standard"],
		["tent", Vector2i(55, 21), 68.0], ["tent", Vector2i(58, 23), 68.0],
		["tent", Vector2i(55, 45), 68.0], ["tent", Vector2i(58, 47), 68.0],
		["boat", Vector2i(24, 14), 56.0], ["boat", Vector2i(42, 34), 56.0], ["boat", Vector2i(28, 46), 56.0],
		["bridge", Vector2i(24, 16), 72.0], ["rocks", Vector2i(22, 26), 48.0], ["rocks", Vector2i(10, 33), 48.0],
	]
	if Layout.enabled():
		# 移除厅后孤立桥头；船只停在新主码头两侧的水面。
		map.decor = map.decor.filter(func(d): return d[0] != "bridge" and not (d[0] == "boat" and d[1] == Vector2i(24, 14)))
		map.decor.append(["boat", Vector2i(13, 49), 68.0])
		map.decor.append(["boat", Vector2i(20, 50), 68.0])
		map.decor.append(["boat", Vector2i(44, 24), 56.0])
		map.decor.append(["boat", Vector2i(34, 53), 52.0])
		for cell in [Vector2i(7,23),Vector2i(26,12)]:
			map.decor.append(["rocks",cell,128.0])
	map.enable_liangshan_sample()
