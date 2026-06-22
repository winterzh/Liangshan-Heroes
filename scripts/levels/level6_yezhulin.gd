extends LevelBase
## 第6关·大闹野猪林（花和尚鲁智深救林冲）。林冲被高俅陷害刺配沧州，防送公人董超、薛霸受陆谦
## 买嘱，要在野猪林结果了林冲性命。一路尾随暗护的花和尚鲁智深从松树后跳出，禅杖一搅救下兄弟，
## 再杀散追兵，护着林冲穿出野猪林、奔沧州道而去。
## 机制：限时营救（行刑倒计时）→ 救出受刑的林冲（烫伤脚·初时虚弱）→ 护送二人杀出西林口=胜。

const T := GameMap.T

const GATE_E := Vector2i(49, 20)     # 东林口：公人押解入场 / 追兵增援
const EXIT_W := Vector2i(3, 20)      # 西林口·沧州道（护送脱险点）
const PINE := Vector2i(27, 20)       # 行刑大松树（林冲缚于此）
const AMBUSH := Vector2i(24, 16)     # 鲁智深伏身的松林芦苇

const EXEC_TIME := 42.0              # 行刑倒计时（秒，受 time_scale 缩放）
const RESCUE_R := 86.0               # 救出半径（好汉贴近大松树即救下林冲）
const EXIT_R := 120.0                # 抵达西林口判定半径

enum { STALK, ESCAPE }

var lin_bound: Unit = null
var lin_freed: Unit = null
var lu: Unit = null
var st := STALK
var exec_timer := EXEC_TIME
var rescued := false
var alarm := false
var wave_t := 0.0
var wave_n := 0
var smoke_t := 0.0


func id() -> String: return "level6"
func title() -> String: return "大闹野猪林"
func subtitle() -> String: return "花和尚禅杖·救林冲"
func map_w() -> int: return 52
func map_h() -> int: return 40
func map_theme() -> String: return "marsh"
func map_base() -> int: return T.GRASS
func camera_start_cell() -> Vector2i: return Vector2i(27, 20)
func deploy_hint() -> String:
	return "把花和尚鲁智深藏在大松树旁的松林芦苇里按兵不动。开战后董超、薛霸便要对缚在树上的林冲下毒手——抢在行刑倒计时归零前，让鲁智深杀到大松树下救出林冲！救下后再护着二人一路向西杀出林口。"


func intro_lines() -> Array:
	return [
		{"who": "旁白", "key": "narrator", "text": "野猪林，乃自东京去沧州路上一处大林子，最是僻静杀人的去处。豹子头林冲被高太尉陷害，刺配沧州，一路披枷带锁。防送公人董超、薛霸早受了陆谦的银两嘱托，要在这林中结果了他性命。"},
		{"who": "薛霸", "key": "narrator", "text": "林教头，不是俺们要害你，是上头的钧旨——你且把这条性命，留在这野猪林里罢！来，先绑上这松树……"},
		{"who": "鲁智深", "key": "lu_zhishen", "text": "洒家自东京一路暗暗跟到这里！你这两个腌臜泼才，敢害俺兄弟！且吃洒家一禅杖——林教头休慌，鲁智深来也！"},
		{"who": "军令", "key": "narrator", "text": "【限时营救】行刑倒计时已悬于头顶。让鲁智深杀到大松树下，贴近即可救出林冲（初时烫伤脚虚弱，稍后恢复）。救下后护着鲁智深、林冲一路向西杀出林口=胜；倒计时归零、或二人有失=败。"},
	]


func paint_map(map: GameMap) -> void:
	# 上下以崖壁松岭围合，中部留出一条林间官道走廊
	map.fill_rect(0, 0, 52, 7, T.CLIFF)
	map.fill_rect(0, 33, 52, 7, T.CLIFF)
	# 野猪林：成片密松（FOREST），夹道幽深
	map.fill_ellipse(Vector2(14, 12), 4, 2, T.FOREST)
	map.fill_ellipse(Vector2(20, 27), 4, 2, T.FOREST)
	map.fill_ellipse(Vector2(33, 12), 4, 2, T.FOREST)
	map.fill_ellipse(Vector2(36, 28), 4, 2, T.FOREST)
	map.fill_ellipse(Vector2(9, 25), 3, 2, T.FOREST)
	map.fill_ellipse(Vector2(44, 14), 3, 2, T.FOREST)
	# 林间官道：东林口 → 行刑松树 → 西林口
	map.paint_path([Vector2(49, 20), Vector2(40, 20), Vector2(33, 20), Vector2(27, 20), Vector2(18, 20), Vector2(8, 20), Vector2(1, 20)], 1, T.ROAD)
	# 行刑松树前的小空地
	map.fill_ellipse(Vector2(PINE.x, PINE.y), 4, 2, T.DRYHILL, [T.DRYHILL, T.GRASS])
	# 伏身芦苇荡（鲁智深藏身，离官道 3 格以上，藏得住）
	map.fill_ellipse(Vector2(24, 16), 3, 2, T.REEDS)
	map.fill_ellipse(Vector2(30, 25), 3, 2, T.REEDS)


func decorate(map: GameMap) -> void:
	map.decor = [
		["pine", Vector2i(27, 17), 64.0],      # 行刑大松树
		["rocks", Vector2i(10, 9), 48.0], ["rocks", Vector2i(42, 31), 48.0],
		["rocks", Vector2i(6, 30), 44.0], ["pine", Vector2i(15, 30), 52.0],
		["pine", Vector2i(38, 11), 52.0],
	]


func deploy(b) -> void:
	var B: Battle = b
	# 缚于大松树的林冲（FACTION_LIANG 建筑形态·不可动，待救）
	lin_bound = B.spawn_at("lin_chong_bound", Unit.FACTION_LIANG, PINE)
	# 行刑的两个公人 + 主谋陆谦，守在松树旁（按兵不动，待鲁智深杀出才发作）
	for spec in [["dong_chao", Vector2i(-1, -1)], ["xue_ba", Vector2i(1, -1)], ["lu_qian", Vector2i(2, 1)]]:
		var g := B.spawn_at(spec[0], Unit.FACTION_GUAN, PINE + spec[1])
		g.passive = true
	# 鲁智深伏在松林芦苇里（按兵不动，芦苇中隐身）
	lu = B.spawn_at("lu_zhishen", Unit.FACTION_LIANG, AMBUSH)
	lu.passive = true


func on_start(b) -> void:
	var B: Battle = b
	st = STALK
	exec_timer = EXEC_TIME
	rescued = false
	alarm = false
	wave_t = 0.0
	wave_n = 0
	B.msg("董超、薛霸把林冲缚上大松树，举起水火棍便要下手——鲁智深，快救人！", 5.0)


func process(b, delta: float) -> void:
	var B: Battle = b
	if B._smoke:
		_smoke_drive(B, delta)
	match st:
		STALK:
			# 行刑倒计时
			if not rescued:
				exec_timer -= delta
				if exec_timer <= 0.0:
					B.lose("迟了一步！董超、薛霸一棍结果了林冲性命，野猪林血溅松根……")
					return
				if _liang_near(B, lin_bound, RESCUE_R):
					_rescue(B)
		ESCAPE:
			# 追兵成波杀来（共 2 波，间隔较宽，重在护送脱险而非剿灭）
			wave_t -= delta
			if wave_t <= 0.0 and wave_n < 2:
				wave_t = 18.0
				wave_n += 1
				_spawn_pursuit(B, wave_n)
			# 护送二人杀出西林口
			var lu_ok := is_instance_valid(lu) and lu.hp > 0.0
			var lin_ok := is_instance_valid(lin_freed) and lin_freed.hp > 0.0
			if not lu_ok:
				B.lose("花和尚鲁智深力战殁于野猪林，林冲再无人搭救……")
				return
			if not lin_ok:
				B.lose("林冲终究没能走出这座林子……")
				return
			var ew := B.map.cell_to_world(EXIT_W)
			if lu.position.distance_to(ew) < EXIT_R and lin_freed.position.distance_to(ew) < EXIT_R:
				B.win("杀散追兵，护着林冲冲出野猪林、直奔沧州道！花和尚倒提禅杖，一路相送十七八里。")
				return


func _rescue(b) -> void:
	var B: Battle = b
	rescued = true
	st = ESCAPE
	alarm = true
	var sp: Vector2 = lin_bound.position if is_instance_valid(lin_bound) else B.map.cell_to_world(PINE)
	if is_instance_valid(lin_bound):
		lin_bound.queue_free()
		B.units.erase(lin_bound)
	# 救出可控的林冲：满血解缚，烫伤脚·初时略虚弱（移速/攻击小降，10 秒后恢复）；
	# 生成在松树西侧（偏向脱险方向，不被守军围心）
	lin_freed = B.spawn_unit("lin_chong", Unit.FACTION_LIANG, sp + Vector2(-14, 8))
	lin_freed.heal(lin_freed.max_hp)
	lin_freed.apply_slow(0.82, 10.0)
	lin_freed.apply_temp_atk(0.85, 10.0)
	lu.passive = false
	# 陆谦呼来追兵，松树旁的公人也一齐发作
	for u in B.units_of(Unit.FACTION_GUAN):
		if is_instance_valid(u) and not u.is_building:
			u.passive = false
	# 头一波追兵略缓登场，先给护送留出起步的工夫
	wave_t = 10.0
	B.msg("禅杖一搅，绳断枷开——救下林冲了！陆谦呼来追兵，护着二人向西杀出林口！", 5.0)


func _spawn_pursuit(b, n: int) -> void:
	var B: Battle = b
	var tw: Vector2 = B.map.cell_to_world(PINE) if is_instance_valid(lu) else B.map.cell_to_world(EXIT_W)
	if is_instance_valid(lu):
		tw = lu.position
	B.spawn_group("guan_dao", 1 + n, Unit.FACTION_GUAN, GATE_E, tw)
	if n >= 2:
		B.spawn_group("guan_gong", 2, Unit.FACTION_GUAN, GATE_E + Vector2i(0, 2), tw)
	if n >= 3:
		B.spawn_group("guan_qi", 2, Unit.FACTION_GUAN, GATE_E + Vector2i(0, -2), tw)


func _liang_near(b, target: Unit, r: float) -> bool:
	var B: Battle = b
	if target == null or not is_instance_valid(target):
		return false
	for u in B.units_of(Unit.FACTION_LIANG):
		if is_instance_valid(u) and u.hp > 0.0 and not u.is_building \
				and u.position.distance_to(target.position) <= r:
			return true
	return false


func on_unit_died(b, u) -> void:
	if u == lu:
		b.lose("花和尚鲁智深力战殁于野猪林，林冲再无人搭救……")
	elif u == lin_bound and not rescued:
		b.lose("林冲被害于大松树下，鲁智深来迟一步……")
	elif u == lin_freed and rescued:
		b.lose("林冲终究没能走出这座林子……")


func top_status(b) -> String:
	var B: Battle = b
	if st == STALK:
		return "大闹野猪林 | 行刑倒计时 %d 秒 | 让鲁智深杀到大松树下救人！" % ceili(maxf(0.0, exec_timer))
	var lw := B.map.cell_to_world(EXIT_W)
	var d := 999
	if is_instance_valid(lu):
		d = int(lu.position.distance_to(lw) / 16.0)
	return "护送脱险 | 距西林口约 %d 步 | 追兵第 %d 波 | 歼敌 %d" % [d, wave_n, B.kills]


# ---- 冒烟自测：鲁智深扑松树救人 → 护二人向西杀出林口 ----
## 注意：order 须节流下发（每帧重发会把寻路打断、原地踏步）。
func _smoke_drive(b, delta: float) -> void:
	var B: Battle = b
	smoke_t -= delta
	if smoke_t > 0.0:
		return
	smoke_t = 1.0
	if st == STALK:
		if is_instance_valid(lu) and is_instance_valid(lin_bound):
			lu.passive = false
			lu.order_amove(lin_bound.position)
			if lu.slot_ready(0):
				B.cast_ability(lu)
	elif st == ESCAPE:
		var ew := B.map.cell_to_world(EXIT_W)
		for u in B.units_of(Unit.FACTION_LIANG):
			if is_instance_valid(u) and not u.is_building:
				u.order_amove(ew)
		if is_instance_valid(lu) and lu.slot_ready(0):
			B.cast_ability(lu)
