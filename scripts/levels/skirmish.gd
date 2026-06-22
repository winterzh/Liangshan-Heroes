extends LevelBase
## 自由「遭遇战」模式（仿帝国时代经营 + 仿魔兽英雄）。
## Phase 0 地基：开放地图 + 聚义厅基地 + 起始喽啰/资源 + 金矿/树林资源点 + 资源条/人口。
## 采集、建造、生产、英雄祭坛/升级、Tab 子组、敌军波次将在后续阶段逐步接入。

const T := GameMap.T
const HALL := Vector2i(16, 46)
const GOLD := Vector2i(1, 32)   # 聚义厅左上方·拉到地图左缘——农民单程步行约 9.5 秒（受左缘所限，已是「左上」方向可达最远）
# 聚义厅在地图左侧(16,46)，官军一律自「右侧」三条分路压来——绝不从左/后方出现：
const GATE_A := Vector2i(62, 40)   # 正东（右缘·与基地同高）
const GATE_B := Vector2i(62, 26)   # 东北（右上·避开右上角水泊）
const GATE_C := Vector2i(50, 62)   # 东南（右下）
const GATES := [GATE_A, GATE_B, GATE_C]

# 官军围剿波次（30 波·步步紧逼）：t=距上一波秒数，groups=[key, 数量, 门(0=东/1=北/2=西)]
# 定时来袭、不等清场 → 波次叠加；里程碑波出「地方英雄」boss（自动学满技能、会放招）。
# 难度曲线：1-9 立寨练兵期 → 10-20 三面围攻 → 21-30 群英压境·多将合围，第 30 波三帅决死。
const WAVES := [
	{"t": 120.0, "msg": "官军探马杀到——头一拨人马已近寨门！",
		"groups": [["guan_dao", 6, 0], ["guan_gong", 3, 0]]},
	{"t": 32.0, "msg": "马军突进，小心骑兵冲阵！",
		"groups": [["guan_dao", 7, 0], ["guan_qi", 3, 1], ["guan_gong", 3, 0]]},
	{"t": 30.0, "msg": "官军大队压上，寨子吃紧！",
		"groups": [["guan_dao", 8, 0], ["guan_gong", 4, 1], ["guan_qi", 4, 0]]},
	{"t": 30.0, "msg": "两路夹攻，弓马齐至！",
		"groups": [["guan_dao", 9, 0], ["guan_gong", 5, 1], ["guan_qi", 5, 0]]},
	{"t": 32.0, "msg": "祝家庄教师栾廷玉，铁棒开路！",
		"groups": [["luan_tingyu", 1, 0], ["guan_dao", 9, 0], ["guan_qi", 4, 1], ["guan_gong", 4, 0]]},
	{"t": 30.0, "msg": "东南方向也竖起了官军旗号——分路合围！",
		"groups": [["guan_dao", 10, 2], ["guan_gong", 6, 1], ["guan_qi", 5, 0]]},
	{"t": 28.0, "msg": "官军精骑压境，铁蹄隆隆！",
		"groups": [["guan_jingqi", 5, 0], ["guan_dao", 10, 2], ["guan_gong", 6, 1]]},
	{"t": 30.0, "msg": "百胜将韩滔、天目将彭玘双骑齐到！",
		"groups": [["han_tao", 1, 0], ["peng_qi", 1, 2], ["guan_qi", 6, 0], ["guan_gong", 6, 1], ["guan_dao", 6, 2]]},
	{"t": 28.0, "msg": "刽子手压阵，鬼头刀凶悍异常！",
		"groups": [["guan_zhanzi", 4, 2], ["guan_dao", 12, 0], ["guan_gong", 7, 1]]},
	{"t": 32.0, "msg": "双鞭呼延灼，连环铁骑踏寨而来！",
		"groups": [["hu_yanzhuo", 1, 0], ["guan_jingqi", 6, 0], ["guan_qi", 5, 1], ["guan_gong", 6, 2]]},
	{"t": 28.0, "msg": "三面齐攻，箭如骤雨！",
		"groups": [["guan_dao", 12, 2], ["guan_gong", 8, 1], ["guan_qi", 6, 0], ["guan_jingqi", 4, 0]]},
	{"t": 28.0, "msg": "刽子手成群，杀气腾腾！",
		"groups": [["guan_zhanzi", 6, 2], ["guan_dao", 12, 0], ["guan_gong", 8, 1], ["guan_qi", 6, 0]]},
	{"t": 30.0, "msg": "祝家庄祝虎、祝彪领庄兵杀到！",
		"groups": [["zhu_hu", 1, 0], ["zhu_biao", 1, 1], ["zhu_qi", 6, 0], ["zhu_gong", 6, 1], ["guan_dao", 8, 2]]},
	{"t": 28.0, "msg": "精骑铁蹄、弓弩蔽野！",
		"groups": [["guan_jingqi", 7, 0], ["guan_qi", 7, 2], ["guan_gong", 8, 1]]},
	{"t": 32.0, "msg": "快活林蒋门神，赤膊巨汉压阵！",
		"groups": [["jiang_menshen", 1, 0], ["jiang_thug", 8, 0], ["guan_dao", 12, 2], ["guan_gong", 8, 1]]},
	{"t": 28.0, "msg": "刽子手与精骑齐压而上！",
		"groups": [["guan_zhanzi", 8, 2], ["guan_jingqi", 6, 0], ["guan_gong", 9, 1]]},
	{"t": 28.0, "msg": "弓马蔽野，三门皆敌！",
		"groups": [["guan_qi", 8, 0], ["guan_qi", 8, 2], ["guan_gong", 10, 1], ["guan_dao", 8, 1]]},
	{"t": 30.0, "msg": "一丈青扈三娘、祝龙双将临阵！",
		"groups": [["hu_sanniang", 1, 2], ["zhu_long", 1, 0], ["zhu_qi", 8, 0], ["guan_jingqi", 6, 2], ["guan_gong", 8, 1]]},
	{"t": 28.0, "msg": "精骑刽子手轮番冲阵不止！",
		"groups": [["guan_jingqi", 8, 0], ["guan_zhanzi", 8, 2], ["guan_gong", 10, 1]]},
	{"t": 34.0, "msg": "没羽箭张清携龚旺、丁得孙，飞石如雨！",
		"groups": [["zhang_qing", 1, 1], ["gong_wang", 1, 0], ["ding_desun", 1, 0], ["guan_qi", 8, 0], ["guan_gong", 10, 1], ["guan_dao", 10, 2]]},
	{"t": 28.0, "msg": "三路猛攻，势不可挡！",
		"groups": [["guan_jingqi", 9, 0], ["guan_qi", 8, 2], ["guan_gong", 10, 1], ["guan_dao", 8, 2]]},
	{"t": 28.0, "msg": "刽子手列阵，势如铁壁！",
		"groups": [["guan_zhanzi", 10, 2], ["guan_jingqi", 7, 0], ["guan_gong", 12, 1]]},
	{"t": 30.0, "msg": "张团练、蔡九知府督战压境！",
		"groups": [["zhang_tuanlian", 1, 0], ["cai_jiu", 1, 1], ["guan_jingqi", 8, 0], ["guan_qi", 8, 2], ["guan_gong", 10, 1]]},
	{"t": 28.0, "msg": "铁骑洪流，三面倾轧！",
		"groups": [["guan_jingqi", 10, 0], ["guan_zhanzi", 10, 2], ["guan_gong", 12, 1], ["guan_qi", 6, 1]]},
	{"t": 34.0, "msg": "曾头市教师史文恭，画戟无双！",
		"groups": [["shi_wengong", 1, 0], ["guan_jingqi", 9, 0], ["guan_qi", 9, 2], ["guan_gong", 12, 1]]},
	{"t": 28.0, "msg": "倾巢精锐，三面围寨！",
		"groups": [["guan_jingqi", 10, 0], ["guan_jingqi", 8, 2], ["guan_zhanzi", 8, 1], ["guan_gong", 12, 1]]},
	{"t": 30.0, "msg": "呼延灼、栾廷玉卷土重来！",
		"groups": [["hu_yanzhuo", 1, 0], ["luan_tingyu", 1, 2], ["guan_jingqi", 9, 0], ["guan_qi", 9, 2], ["guan_gong", 12, 1]]},
	{"t": 28.0, "msg": "刽子手与铁骑死战不退！",
		"groups": [["guan_zhanzi", 12, 2], ["guan_jingqi", 10, 0], ["guan_qi", 8, 1], ["guan_gong", 12, 1]]},
	{"t": 30.0, "msg": "祝龙、祝虎、祝彪——祝家三杰合围！",
		"groups": [["zhu_long", 1, 0], ["zhu_hu", 1, 0], ["zhu_biao", 1, 1], ["zhu_qi", 10, 0], ["guan_jingqi", 8, 2], ["guan_gong", 12, 1]]},
	{"t": 36.0, "msg": "高太尉亲督中军，蒋门神、史文恭压阵——决死一战！",
		"groups": [["gao_qiu", 1, 0], ["jiang_menshen", 1, 2], ["shi_wengong", 1, 1], ["guan_jingqi", 10, 0], ["guan_qi", 10, 2], ["guan_zhanzi", 10, 1], ["guan_gong", 14, 1]]},
]

var hall: Unit
var _wave := 0
var _wave_t := 0.0
var _wave_spawned := false
var _started := false


func id() -> String: return "skirmish"
func title() -> String: return "遭遇战"
func subtitle() -> String: return "自由经营 · 据守聚义厅"
func map_w() -> int: return 64
func map_h() -> int: return 64
func map_theme() -> String: return "marsh"
func map_base() -> int: return T.GRASS
func camera_start_cell() -> Vector2i: return Vector2i(22, 44)

func economy_enabled() -> bool: return true
func start_gold() -> int: return 250
func start_wood() -> int: return 150
func base_pop_cap() -> int: return 20
func hero_cap() -> int: return int(Campaign.defense_hero_cap)   # 驻守战英雄上限（菜单选：默认 4 / 60关 6）
func fog_enabled() -> bool: return true

func deploy_hint() -> String:
	return "自由经营：用喽啰采金/伐木、建造营寨、在聚义厅训练英雄。妥当后点「开战」迎击官军。"


func intro_lines() -> Array:
	return [
		{"who": "旁白", "key": "narrator", "text": "梁山新立，百废待兴。聚义厅前金矿、林木皆备——遣喽啰采办钱粮，招兵买马，再练就几员上将，方能与官军长久周旋。"},
		{"who": "军令", "key": "narrator", "text": "【据守·三十波】聚义厅居西，官军将自右侧东、东北、东南三路轮番杀来，一波紧似一波，更有栾廷玉、呼延灼、蒋门神、史文恭等地方名将压阵。建寨练兵、升将守关——守满三十波，梁山方可立稳！"},
	]


func paint_map(map: GameMap) -> void:
	# 右上角一片水泊 + 沼泽芦苇
	map.fill_ellipse(Vector2(52, 12), 15, 11, T.WATER)
	map.fill_ellipse(Vector2(45, 20), 4, 3, T.MARSH, [T.GRASS])
	map.scatter(T.MARSH, T.REEDS, 5)
	# 树林（伐木处）
	map.fill_ellipse(Vector2(24, 52), 4, 3, T.FOREST, [T.GRASS])
	map.fill_ellipse(Vector2(10, 38), 3, 3, T.FOREST, [T.GRASS])
	map.fill_ellipse(Vector2(34, 40), 3, 2, T.FOREST, [T.GRASS])
	# 聚义厅地基
	for y in range(HALL.y - 1, HALL.y + 2):
		for x in range(HALL.x - 1, HALL.x + 2):
			map.set_cell_t(x, y, T.HALL)


func decorate(map: GameMap) -> void:
	map.decor = [
		["banner", Vector2i(18, 48), 52.0], ["banner", Vector2i(14, 44), 52.0],
		["rocks", Vector2i(29, 45), 48.0], ["rocks", Vector2i(25, 48), 48.0],
		["boat", Vector2i(46, 16), 56.0],
	]


## 子类(自定义据守)可覆写这些钩子改波次/投石车/数值；据守本体返回原值，行为不变。
var _wavelist_cache: Array = []
func _waves() -> Array:
	if _wavelist_cache.is_empty():
		_wavelist_cache = _build_wavelist()
	return _wavelist_cache


## 按菜单所选波数构造波次表：30=经典原表；<30 取前 n 波；>30 经典之后循环加量续到 n 波。
func _build_wavelist() -> Array:
	var n := int(Campaign.defense_waves)
	if n == WAVES.size():
		return WAVES.duplicate(true)
	if n < WAVES.size():
		return WAVES.slice(0, maxi(1, n))
	return _extended_waves(n)


## 60 关·史诗：前 29 波照旧，之后循环复用中后段波次并逐圈加量，末波仍为高太尉决战。
func _extended_waves(n: int) -> Array:
	var out: Array = WAVES.slice(0, WAVES.size() - 1)   # 前 29 波（决战留作末波）
	var pool: Array = WAVES.slice(6, WAVES.size() - 1)  # 中后段循环池
	var k := 0
	var boost := 1
	while out.size() < n - 1:
		var src: Dictionary = pool[k % pool.size()]
		var w: Dictionary = src.duplicate(true)
		w["t"] = maxf(20.0, float(src["t"]) - 2.0)
		var g2: Array = []
		for g in src["groups"]:
			g2.append([g[0], int(g[1]) + boost, int(g[2])])
		w["groups"] = g2
		w["msg"] = "援军不绝，铁壁再压——第 %d 波来袭！" % (out.size() + 1)
		out.append(w)
		k += 1
		if k % pool.size() == 0:
			boost += 1
	out.append(WAVES[WAVES.size() - 1].duplicate(true))
	return out
func _cata_for(i: int) -> int: return 1 if i < 10 else 2
func _apply_overrides(_b) -> void: pass


func deploy(b) -> void:
	_apply_overrides(b)   # 自定义据守：在任何 spawn 前把数值覆盖合并进 b._defs/_abilities
	hall = b.spawn_at("hall", Unit.FACTION_LIANG, HALL)
	b.spawn_at("gold_mine", Unit.FACTION_LIANG, GOLD)
	# 林木资源点（伐木处）
	for c in [Vector2i(23, 51), Vector2i(25, 52), Vector2i(24, 53), Vector2i(26, 51),
			Vector2i(10, 37), Vector2i(11, 39), Vector2i(9, 38), Vector2i(33, 40), Vector2i(35, 40)]:
		b.spawn_at("tree", Unit.FACTION_LIANG, c)
	for c in [Vector2i(19, 44), Vector2i(20, 45), Vector2i(19, 46), Vector2i(20, 47), Vector2i(21, 45)]:
		b.spawn_at("lou_luo", Unit.FACTION_LIANG, c)
	b.spawn_at("liang_dao", Unit.FACTION_LIANG, Vector2i(18, 49))
	b.spawn_at("liang_dao", Unit.FACTION_LIANG, Vector2i(20, 49))


func on_start(b) -> void:
	# 起始喽啰自动采办（3 采金、2 伐木）——帝国式开局
	var workers: Array = []
	for u in b.units:
		if is_instance_valid(u) and u.is_worker and u.faction == Unit.FACTION_LIANG:
			workers.append(u)
	for i in range(workers.size()):
		var kind := "gold" if i < 3 else "wood"
		var node = b.nearest_resource(workers[i].position, kind)
		if node != null:
			workers[i].order_gather(node)
	b.msg("喽啰开始采办钱粮——采金伐木，扩充寨势。", 4.0)
	_wave = 0
	var ws: Array = _waves()
	_wave_t = float(ws[0]["t"]) if not ws.is_empty() else 9999.0
	_wave_spawned = false
	_started = true


func process(b, delta: float) -> void:
	if hall == null or not is_instance_valid(hall) or hall.hp <= 0.0:
		b.lose("聚义厅被攻破，杏黄旗倒下了……")
		return
	if not _started:
		return
	var ws: Array = _waves()
	if _wave < ws.size():
		# 定时出兵：到点就放，不等上一波被清完 → 波次叠加，密度大、间隔短
		_wave_t -= delta
		if _wave_t <= 0.0:
			_spawn_wave(b, _wave)
			_wave += 1
			if _wave < ws.size():
				_wave_t = float(ws[_wave]["t"])
	elif b.enemies_alive() == 0:
		# 末波也已出，且场上敌人尽灭 → 守住了
		b.win("官军围剿一波波尽数瓦解——梁山大寨，固若金汤！")
		return


func _spawn_wave(b, i: int) -> void:
	_wave_spawned = true
	var ws: Array = _waves()
	var wave: Dictionary = ws[i]
	b.msg("【第 %d/%d 波】%s" % [i + 1, ws.size(), wave.get("msg", "")], 5.5)
	var hall_pos: Vector2 = b.map.cell_to_world(HALL)
	for g in wave["groups"]:
		var gate: Vector2i = GATES[clampi(int(g[2]), 0, GATES.size() - 1)]
		var spawned: Array = b.spawn_group(String(g[0]), int(g[1]), Unit.FACTION_GUAN, gate, hall_pos)
		_arm_boss(spawned, _group_rank(g))
	# 每波附带投石车：射程远、专破箭楼，轮换从一门压上（数量由 _cata_for 决定）
	var n_cata: int = _cata_for(i)
	if n_cata > 0:
		var cgate: Vector2i = GATES[i % GATES.size()]
		b.spawn_group("siege_cata", n_cata, Unit.FACTION_GUAN, cgate, hall_pos)


## 经济模式下英雄技能默认未学(rank0)不放招 → 给来犯的地方英雄自动学满，使其会自动施放招式
func _arm_boss(spawned: Array, rank := 2) -> void:
	if rank <= 0:
		return   # rank 0：敌将不学技能、不放招
	for u in spawned:
		if not (is_instance_valid(u) and u.is_hero):
			continue
		for s in range(u.slot_count()):
			if not bool(u.ability_slots[s]["passive"]):
				u.ability_slots[s]["rank"] = clampi(rank, 1, 2)


## 该兵组敌将的技能等级（0=不放招 / 1 / 2满级）。据守本体一律满级；自定义据守按 config 第 4 元。
func _group_rank(_g) -> int:
	return 2


func top_status(b) -> String:
	var nxt := ""
	var total := _waves().size()
	if _started and _wave < total:
		nxt = " ｜ 下一波 %d 秒" % int(ceil(maxf(_wave_t, 0.0)))
	return "遭遇战 已出 %d/%d 波%s ｜ 金 %d 木 %d 人口 %d/%d ｜ 聚义厅 %d%%" % [
		_wave, total, nxt, b.gold, b.wood, b.used_pop(), b.pop_cap,
		int(hall.hp / hall.max_hp * 100.0) if (hall != null and is_instance_valid(hall)) else 0]
