extends LevelBase
## 竞技场·沙盒（DOTA 改版技能试演场）：
## 资源无限、即时成军 —— 在聚义厅「点将」选任意 108 将出战，自由放 Q/W/E/R；
## 点命令卡「刷敌」一键召来一波官军试招。仅此模式与战役剧情启用新技能组。

const T := GameMap.T
const HALL := Vector2i(12, 24)
const SPAWN := Vector2i(46, 24)   # 敌军刷新点(右侧)，刷出后向聚义厅推进

var hall: Unit
var _wave := 0


func id() -> String: return "arena"
func title() -> String: return "竞技场"
func subtitle() -> String: return "沙盒 · 自由点将放技能 · 一键刷敌"
func map_w() -> int: return 56
func map_h() -> int: return 48
func map_theme() -> String: return "marsh"
func map_base() -> int: return T.GRASS
func camera_start_cell() -> Vector2i: return Vector2i(24, 24)

func economy_enabled() -> bool: return true
func uses_dota_roster() -> bool: return true       # 聚义厅点将列全部 108 将
func arena_instant_train() -> bool: return true     # 即时成军（沙盒不等训练）
func start_gold() -> int: return 999999
func start_wood() -> int: return 999999
func base_pop_cap() -> int: return 200
func hero_cap() -> int: return 0                     # 英雄不限员
func fog_enabled() -> bool: return false
func start_age() -> int: return 3


func deploy_hint() -> String:
	return "竞技场沙盒：在聚义厅「点将」选任意英雄出战（资源无限、即时成军），自由施放 Q/W/E/R 技能；点命令卡「刷敌」一键召来一波官军试招。"


func intro_lines() -> Array:
	return [
		{"who": "旁白", "key": "narrator", "text": "演武竞技场——百单八将任你点选出阵，钱粮无穷、成军即至。点『刷敌』召来一队官军，尽情试演各路绝学。"},
	]


func paint_map(map: GameMap) -> void:
	# 一片平整开阔的演武场 + 聚义厅地基
	for y in range(HALL.y - 1, HALL.y + 2):
		for x in range(HALL.x - 1, HALL.x + 2):
			map.set_cell_t(x, y, T.HALL)


func deploy(b) -> void:
	hall = b.spawn_at("hall", Unit.FACTION_LIANG, HALL)
	# 资源点（资源虽无限，工人/经济链需要存在；摆在基地旁）
	b.spawn_at("gold_mine", Unit.FACTION_LIANG, Vector2i(5, 20))
	for c in [Vector2i(6, 28), Vector2i(7, 29), Vector2i(5, 30)]:
		b.spawn_at("tree", Unit.FACTION_LIANG, c)
	for c in [Vector2i(15, 26), Vector2i(16, 27), Vector2i(14, 27)]:
		b.spawn_at("lou_luo", Unit.FACTION_LIANG, c)


func on_start(b) -> void:
	b.msg("竞技场：聚义厅『点将』选英雄出战，命令卡『刷敌』召敌试招。", 5.0)


func process(_b, _delta: float) -> void:
	pass


## 竞技场「刷敌」：从右侧刷一波官军(含若干敌将)向聚义厅推进，供试招。每点一次量略增。
func arena_spawn_wave(b) -> void:
	var target: Vector2 = b.map.cell_to_world(HALL)
	var troops := ["guan_dao", "guan_gong", "guan_qi", "guan_jingqi"]
	for k in troops:
		var g: Array = b.spawn_group(k, 4, Unit.FACTION_GUAN, SPAWN, target)
		for u in g:
			b.apply_enemy_scale(u)
	# 附带一两个敌将试招用（自动学满技能、会放招）
	var bosses := ["hu_yanzhuo", "jiang_menshen", "shi_wengong", "luan_tingyu", "wei_dingguo"]
	var boss: String = bosses[_wave % bosses.size()]
	var bg: Array = b.spawn_group(boss, 1, Unit.FACTION_GUAN, SPAWN, target)
	for u in bg:
		if is_instance_valid(u) and u.is_hero:
			for s in range(u.slot_count()):
				if not bool(u.ability_slots[s]["passive"]):
					u.ability_slots[s]["rank"] = 2
		b.apply_enemy_scale(u)
	_wave += 1
	b.msg("【刷敌 第 %d 波】一队官军压上——试招！" % _wave, 3.0)


func top_status(b) -> String:
	return "竞技场·沙盒 ｜ 金∞ 木∞ 人口 %d/%d ｜ 聚义厅『点将』出战 · 命令卡『刷敌』试招（已刷 %d 波）" % [
		b.used_pop(), b.pop_cap, _wave]
