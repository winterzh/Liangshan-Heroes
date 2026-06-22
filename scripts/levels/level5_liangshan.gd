extends LevelBase
## 第5关·梁山泊保卫战（终战）。宋江吴用守聚义厅，高俅率官军沿两条窄堤四波围剿，
## 芦苇藏伏兵、半渡而击；第三波林冲花荣伏兵来援。

const T := GameMap.T
const HALL_CELL := Vector2i(16, 30)
const GATE_E := Vector2i(57, 22)
const GATE_S := Vector2i(57, 46)
const AMBUSH_E := Vector2i(36, 25)
const AMBUSH_S := Vector2i(34, 40)

const START_ARMY := [
	["song_jiang", Vector2i(30, 31)], ["wu_yong", Vector2i(29, 33)],
	["liang_qiang", Vector2i(33, 28)], ["liang_qiang", Vector2i(33, 30)],
	["liang_qiang", Vector2i(32, 35)], ["liang_qiang", Vector2i(31, 37)],
	["liang_dao", Vector2i(31, 29)], ["liang_dao", Vector2i(31, 31)],
	["liang_dao", Vector2i(30, 30)], ["liang_dao", Vector2i(30, 34)],
	["liang_dao", Vector2i(29, 35)], ["liang_dao", Vector2i(30, 36)],
	["liang_gong", Vector2i(29, 28)], ["liang_gong", Vector2i(29, 31)],
	["liang_gong", Vector2i(28, 33)], ["liang_gong", Vector2i(27, 35)],
	["liang_gong", Vector2i(36, 25)], ["liang_gong", Vector2i(35, 26)],
]

const WAVES := [
	{"msg": "斥候来报——官军先锋已上东面长堤！",
		"groups": [["guan_dao", 6, 0], ["guan_gong", 3, 0]]},
	{"msg": "官军马军自东南堤道突进，小心骑兵冲阵！",
		"groups": [["guan_dao", 5, 1], ["guan_gong", 3, 1], ["guan_qi", 3, 1]]},
	{"msg": "官军两路齐攻，狼烟四起！", "reinforce": true,
		"groups": [["guan_dao", 5, 0], ["guan_gong", 3, 0], ["guan_dao", 4, 1], ["guan_gong", 2, 1], ["guan_qi", 2, 1]]},
	{"msg": "高俅亲临阵前：『梁山草寇，还不下马受缚！』——擒贼先擒王！",
		"groups": [["gao_qiu", 1, 0], ["guan_dao", 8, 0], ["guan_gong", 4, 0], ["guan_qi", 4, 1]]},
]

var hall: Unit
var gao: Unit = null
var wave_idx := 0
var wave_spawned := false
var spawn_timer := 0.0


func id() -> String: return "level5"
func title() -> String: return "梁山泊保卫战"
func subtitle() -> String: return "三败高太尉·八百里水泊终一战"
func map_w() -> int: return 60
func map_h() -> int: return 60
func map_theme() -> String: return "marsh"
func map_base() -> int: return T.WATER
func camera_start_cell() -> Vector2i: return Vector2i(30, 30)
func deploy_hint() -> String:
	return "左键框选兵马，右键布防。长枪手把守堤口克制骑兵，弓手伏于芦苇荡（芦苇中不易被发现）。妥当后点「开战」。"


func intro_lines() -> Array:
	return [
		{"who": "旁白", "key": "narrator", "text": "宣和年间，太尉高俅奏请天子，亲点十节度大军，水陆并进，征讨梁山泊。八百里水泊烟波浩渺，芦苇如海，只有两条窄堤可通山寨……"},
		{"who": "吴用", "key": "wu_yong", "text": "兄长勿忧。官军远来，不识水路。长堤狭窄，马军难以展开；沼泽泥泞，官兵迟缓，我梁山儿郎却如履平地。芦苇荡中再藏一支伏兵，待其半渡而击，可获全胜。"},
		{"who": "宋江", "key": "song_jiang", "text": "好！众兄弟依军师之计布阵——守住聚义厅，叫高俅有来无回！"},
		{"who": "军令", "key": "narrator", "text": "【布阵阶段】长枪手把守堤口，弓手伏于芦苇荡。布置妥当后点击「开战」。"},
	]


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
	for y in range(HALL_CELL.y - 1, HALL_CELL.y + 2):
		for x in range(HALL_CELL.x - 1, HALL_CELL.x + 2):
			map.set_cell_t(x, y, T.HALL)


func decorate(map: GameMap) -> void:
	map.decor = [
		["tower", Vector2i(33, 32), 76.0], ["tower", Vector2i(31, 38), 76.0],
		["banner", Vector2i(18, 27), 52.0], ["banner", Vector2i(14, 33), 52.0],
		["tent", Vector2i(55, 21), 68.0], ["tent", Vector2i(58, 23), 68.0],
		["tent", Vector2i(55, 45), 68.0], ["tent", Vector2i(58, 47), 68.0],
		["boat", Vector2i(24, 14), 56.0], ["boat", Vector2i(42, 34), 56.0], ["boat", Vector2i(28, 46), 56.0],
		["bridge", Vector2i(24, 16), 72.0], ["rocks", Vector2i(22, 26), 48.0], ["rocks", Vector2i(10, 33), 48.0],
	]


func deploy(b) -> void:
	hall = b.spawn_at("hall", Unit.FACTION_LIANG, HALL_CELL)
	for e in START_ARMY:
		b.spawn_at(e[0], Unit.FACTION_LIANG, e[1])


func on_start(b) -> void:
	wave_idx = 0
	wave_spawned = false
	spawn_timer = 6.0
	b.msg("战鼓擂动——官军围剿大军压境！", 4.0)


func process(b, delta: float) -> void:
	if not wave_spawned:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_wave(b, wave_idx)
	elif b.enemies_alive() == 0:
		if wave_idx >= WAVES.size() - 1:
			b.win("官军四波攻势尽数瓦解，水泊上漂满了官军的旗帜。")
			return
		wave_idx += 1
		wave_spawned = false
		spawn_timer = 9.0
		b.msg("官军暂退！抓紧时间重整阵型……", 4.0)
	if hall.hp <= 0.0:
		b.lose("聚义厅燃起大火，杏黄旗倒下了……")
	elif b.players_alive() == 0:
		b.lose("梁山兵马折损殆尽，水泊易主……")


func _spawn_wave(b, i: int) -> void:
	wave_spawned = true
	var wave: Dictionary = WAVES[i]
	b.msg("【第 %d 波】%s" % [i + 1, wave["msg"]], 5.0)
	var hall_pos: Vector2 = b.map.cell_to_world(HALL_CELL)
	for g in wave["groups"]:
		var gate: Vector2i = GATE_E if g[2] == 0 else GATE_S
		var spawned: Array = b.spawn_group(g[0], g[1], Unit.FACTION_GUAN, gate, hall_pos)
		if g[0] == "gao_qiu" and spawned.size() > 0:
			gao = spawned[0]
	if wave.get("reinforce", false):
		_reinforce(b)


func _reinforce(b) -> void:
	b.msg("芦苇荡中喊声大震——林冲、花荣引伏兵杀到！", 5.0)
	var spots := [Vector2i(33, 40), Vector2i(35, 41), Vector2i(34, 39), Vector2i(35, 40)]
	var keys := ["lin_chong", "hua_rong", "liang_gong", "liang_gong"]
	for i in range(keys.size()):
		b.spawn_at(keys[i], Unit.FACTION_LIANG, spots[i])


func on_unit_died(b, u) -> void:
	if u == gao:
		b.win("高俅中箭落马，官军群龙无首，四散溃逃！")
	elif u.is_hero and u.faction == Unit.FACTION_LIANG:
		b.msg("%s 阵亡了！" % u.display_name, 4.0)


func top_status(b) -> String:
	var nxt := ""
	if not wave_spawned:
		nxt = " | 下一波 %d 秒" % int(ceil(spawn_timer))
	return "第 %d/%d 波%s | 歼敌 %d | 聚义厅 %d%%" % [
		wave_idx + 1, WAVES.size(), nxt, b.kills, int(hall.hp / hall.max_hp * 100.0)]
