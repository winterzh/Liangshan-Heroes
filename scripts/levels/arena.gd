extends LevelBase
## 竞技场·沙盒（DOTA 改版技能试演场）：
## 资源无限、即时成军、英雄一出场即满配 4 技能(rank3) —— 在聚义厅「点将」选任意 108 将出战，
## 自由放 Q/W/E/R；主界面两枚按钮「出兵 / 随机」各刷 50 兵 + 1 名随机敌将(自动放招)对练。

const T := GameMap.T
const HALL := Vector2i(12, 24)
const SPAWN := Vector2i(46, 24)   # 敌军刷新点(右侧)，刷出后向聚义厅推进

# 杂兵池 / 敌将池
const TROOPS_STD := ["guan_dao", "guan_gong", "guan_qi", "guan_jingqi"]
const TROOPS_RAND := ["guan_dao", "guan_gong", "guan_qi", "guan_jingqi", "guan_zhanzi", "guan_musket", "guan_bomber", "camel_rider"]
const BOSSES := ["hu_yanzhuo", "jiang_menshen", "shi_wengong", "luan_tingyu", "wei_dingguo",
	"wang_huan", "gao_qiu", "zhang_qing", "hu_sanniang", "shan_tinggui", "zhu_long", "ling_zhen"]

var hall: Unit
var _wave := 0
var _enemy_ai_t := 0.0


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
func hero_start_rank() -> int: return 3             # 英雄一出场即满配 4 技能(rank3)，随便放
func start_gold() -> int: return 999999
func start_wood() -> int: return 999999
func base_pop_cap() -> int: return 300
func hero_cap() -> int: return 0                     # 英雄不限员
func fog_enabled() -> bool: return false
func start_age() -> int: return 3


func deploy_hint() -> String:
	return "竞技场沙盒：聚义厅「点将」选任意英雄出战（资源无限、即时成军、4 技能满配），自由放 Q/W/E/R；屏幕左下「⚔出兵 / 🎲随机」各召 50 兵 + 1 名随机敌将对练。"


func intro_lines() -> Array:
	return [
		{"who": "旁白", "key": "narrator", "text": "演武竞技场——百单八将任你点选出阵，钱粮无穷、成军即至、绝学满配。左下『出兵 / 随机』召来官军与敌将，尽情试演各路招式。"},
	]


func paint_map(map: GameMap) -> void:
	for y in range(HALL.y - 1, HALL.y + 2):
		for x in range(HALL.x - 1, HALL.x + 2):
			map.set_cell_t(x, y, T.HALL)


func deploy(b) -> void:
	hall = b.spawn_at("hall", Unit.FACTION_LIANG, HALL)
	b.spawn_at("gold_mine", Unit.FACTION_LIANG, Vector2i(5, 20))
	for c in [Vector2i(6, 28), Vector2i(7, 29), Vector2i(5, 30)]:
		b.spawn_at("tree", Unit.FACTION_LIANG, c)
	for c in [Vector2i(15, 26), Vector2i(16, 27), Vector2i(14, 27)]:
		b.spawn_at("lou_luo", Unit.FACTION_LIANG, c)


func on_start(b) -> void:
	b.msg("竞技场：聚义厅『点将』选英雄出战，左下『出兵 / 随机』召敌试招。", 5.0)


## 敌将自动放招：每 ~0.3s 让场上官军英雄走一遍通用托管脑(面向梁山施法)，使其会自动开技能对练。
## 仅本模式驱动敌方英雄；玩家自己的梁山英雄不受托管，手动放 Q/W/E/R。
func process(b, delta: float) -> void:
	_enemy_ai_t -= delta
	if _enemy_ai_t > 0.0:
		return
	_enemy_ai_t = 0.3
	for u in b.units:
		if is_instance_valid(u) and u.is_hero and u.faction == Unit.FACTION_GUAN \
				and u.hp > 0.0 and not u.is_building and u._cast_t <= 0.0 and u.slot_count() > 0:
			b._auto_micro_generic(u)


## 「出兵」：标准官军一波(50，均分四类杂兵) + 1 名随机敌将。
func arena_spawn_troops(b) -> void:
	_arena_spawn(b, TROOPS_STD, false)


## 「随机刷兵+英雄」：50 名随机杂兵(更杂) + 1 名随机敌将。
func arena_spawn_random(b) -> void:
	_arena_spawn(b, TROOPS_RAND, true)


func _arena_spawn(b, pool: Array, randomized: bool) -> void:
	var target: Vector2 = b.map.cell_to_world(HALL)
	var counts := {}
	if randomized:
		for i in range(50):
			var k: String = pool[randi() % pool.size()]
			counts[k] = int(counts.get(k, 0)) + 1
	else:
		var per := int(50.0 / float(pool.size()))
		var rem := 50
		for i in range(pool.size()):
			var c := rem if i == pool.size() - 1 else per
			rem -= c
			counts[pool[i]] = c
	for k in counts:
		for u in b.spawn_group(String(k), int(counts[k]), Unit.FACTION_GUAN, SPAWN, target):
			b.apply_enemy_scale(u)
	# 1 名随机敌将（hero_start_rank=3 已给满配 4 技能；本关 process 驱动其自动放招）
	var boss: String = BOSSES[randi() % BOSSES.size()]
	for u in b.spawn_group(boss, 1, Unit.FACTION_GUAN, SPAWN, target):
		b.apply_enemy_scale(u)
	_wave += 1
	b.msg("【刷敌 第 %d 波】50 兵 + 敌将「%s」压上——试招！" % [_wave, Defs.UNITS.get(boss, {}).get("name", boss)], 3.0)


func top_status(b) -> String:
	return "竞技场·沙盒 ｜ 金∞ 木∞ 人口 %d/%d ｜ 聚义厅『点将』出战 · 左下『出兵/随机』试招（已刷 %d 波）" % [
		b.used_pop(), b.pop_cap, _wave]
