extends Node
## 美术资源管理（Autoload: Art）。
## 把 Imagen 生成的整张图集放进 assets/ 即自动切片使用；缺图时返回 null，
## 单位/地块会用代码绘制的占位图形代替，随时可以无缝换皮。

const UNITS_SHEET := "res://assets/units_sheet.png"        # 4x4 单位图集
const TERRAIN_SHEET := "res://assets/terrain_sheet.png"    # 4x4 地形图集
const PORTRAITS_SHEET := "res://assets/portraits_sheet.png" # 3x3 头像图集

# 各图集的网格布局（key -> 第几列第几行），必须与 ART_PROMPTS.md 中的提示词一致
const UNIT_CELLS := {
	"song_jiang": Vector2i(0, 0), "wu_yong": Vector2i(1, 0),
	"lin_chong": Vector2i(2, 0), "hua_rong": Vector2i(3, 0),
	"liang_dao": Vector2i(0, 1), "liang_qiang": Vector2i(1, 1),
	# liang_gong 不再走 units_sheet 旧格(那张带白光描边)——改回退到新画的逐帧走图(干净)，与马军同路
	"liang_banner": Vector2i(3, 1),
	"guan_dao": Vector2i(0, 2), "guan_qiang": Vector2i(1, 2),
	"guan_gong": Vector2i(2, 2), "guan_qi": Vector2i(3, 2),
	"gao_qiu": Vector2i(0, 3), "guan_banner": Vector2i(1, 3),
	"boat": Vector2i(2, 3), "drummer": Vector2i(3, 3),
}
const TERRAIN_CELLS := {
	"water": Vector2i(0, 0), "shore": Vector2i(1, 0), "marsh": Vector2i(2, 0), "reeds": Vector2i(3, 0),
	"grass": Vector2i(0, 1), "grass2": Vector2i(1, 1), "road": Vector2i(2, 1), "forest": Vector2i(3, 1),
	"hall": Vector2i(0, 2), "tower": Vector2i(1, 2), "palisade": Vector2i(2, 2), "banner": Vector2i(3, 2),
	"tent": Vector2i(0, 3), "rocks": Vector2i(1, 3), "boat": Vector2i(2, 3), "bridge": Vector2i(3, 3),
}
const PORTRAIT_CELLS := {
	"song_jiang": Vector2i(0, 0), "wu_yong": Vector2i(1, 0), "gao_qiu": Vector2i(2, 0),
	"lin_chong": Vector2i(0, 1), "hua_rong": Vector2i(1, 1), "narrator": Vector2i(2, 1),
	"lu_zhishen": Vector2i(0, 2), "wu_song": Vector2i(1, 2), "li_kui": Vector2i(2, 2),
}

# ---- 第二批图集（五幕战役新增）：见 ART_PROMPTS.md ----
const UNITS2_SHEET := "res://assets/units2.png"        # 梁山新好汉 4x4
const UNITS3_SHEET := "res://assets/units3.png"        # 敌将/特殊/目标 4x4
const TERRAIN2_SHEET := "res://assets/terrain2.png"    # 丘陵/城镇/村庄 4x4
const PORTRAITS2_SHEET := "res://assets/portraits2.png" # 新登场人物 3x3
const PORTRAITS3_SHEET := "res://assets/portraits3.png" # 第6-8幕新登场人物 3x3
const BUILDINGS_SHEET := "res://assets/buildings.png"   # 遭遇战可建造建筑 2x2
const OBJECTS_SHEET := "res://assets/objects.png"       # 资源点物件 2x2（金矿+三种树）

const BUILDING_CELLS := {
	"barracks": Vector2i(0, 0), "arrow_tower": Vector2i(1, 0),
	"house": Vector2i(0, 1), "depot": Vector2i(1, 1),
}

# 新防御塔 2x2 图集（霹雳炮/五雷法坛/拒马 + 备用）。无图则程序化塔身兜底。
const BUILDINGS2_SHEET := "res://assets/buildings2.png"
const BUILDING2_CELLS := {
	"thunder_tower": Vector2i(0, 0), "altar_tower": Vector2i(1, 0), "caltrop_tower": Vector2i(0, 1),
}

# 杂项建筑 2x2 图集（集市/攻城作坊 + 2 备用）。无图则程序化兜底。
const BUILDINGS3_SHEET := "res://assets/buildings3.png"
const BUILDING3_CELLS := {
	"market": Vector2i(0, 0), "siege_workshop": Vector2i(1, 0),
}

const OBJECT_CELLS := {
	"gold_mine": Vector2i(0, 0), "tree": Vector2i(1, 0),
	"tree1": Vector2i(0, 1), "tree2": Vector2i(1, 1),
}

# 陷阱 2x2 图集（喽啰 E 一次性机关）。无图返回 null（程序化 TrapMarkerFx 兜底）。
const TRAPS_SHEET := "res://assets/traps.png"
const TRAP_CELLS := {
	"trap_logs": Vector2i(0, 0), "trap_pit": Vector2i(1, 0), "trap_oil": Vector2i(0, 1),
}

# 防御塔朝向 3x3 图集：中心(1,1)=底座/头像，外围 8 格=八方向开火帧。
# 命名 res://assets/tower_<short>.png。无图则 building_texture 退回 BUILDING_CELLS / 程序化。
const TOWER_DIR_SHEETS := {
	"arrow_tower": "res://assets/tower_arrow.png",
	"thunder_tower": "res://assets/tower_thunder.png",
	"altar_tower": "res://assets/tower_altar.png",
	"caltrop_tower": "res://assets/tower_caltrop.png",
}

const UNIT2_CELLS := {
	"chao_gai": Vector2i(0, 0), "gongsun_sheng": Vector2i(1, 0), "liu_tang": Vector2i(2, 0), "ruan_brother": Vector2i(3, 0),
	"bai_sheng": Vector2i(0, 1), "li_kui": Vector2i(1, 1), "dai_zong": Vector2i(2, 1), "zhang_shun": Vector2i(3, 1),
	"yan_shun": Vector2i(0, 2), "shi_xiu": Vector2i(1, 2), "xu_ning": Vector2i(2, 2), "tang_long": Vector2i(3, 2),
	"gou_lian": Vector2i(0, 3), "zhu_keke": Vector2i(1, 3), "zhu_gong": Vector2i(2, 3), "zhu_qi": Vector2i(3, 3),
}
const UNIT3_CELLS := {
	"yang_zhi": Vector2i(0, 0), "jun_han": Vector2i(1, 0), "yu_hou": Vector2i(3, 0),
	"lao_duguan": Vector2i(0, 1), "guan_zhanzi": Vector2i(1, 1), "guan_laozi": Vector2i(2, 1), "lian_huan_ma": Vector2i(3, 1),
	"hu_yanzhuo": Vector2i(0, 2), "han_tao": Vector2i(1, 2), "peng_qi": Vector2i(1, 2), "treasure_cart": Vector2i(2, 2),
	"guan_jingqi": Vector2i(0, 3),
	# 复用既有官军兵作祝家庄客/牢子的视觉近似（无专属格时回退）
}
const TERRAIN2_CELLS := {
	"dryhill": Vector2i(0, 0), "cliff": Vector2i(1, 0), "plaza": Vector2i(2, 0), "town": Vector2i(3, 0),
	"field": Vector2i(0, 1), "plain": Vector2i(1, 1),
	"pine": Vector2i(0, 2), "white_poplar": Vector2i(1, 2), "scaffold": Vector2i(2, 2), "town_house": Vector2i(3, 2),
	"dock": Vector2i(0, 3), "zhu_gate": Vector2i(1, 3), "zhu_hall": Vector2i(2, 3), "village_palisade": Vector2i(3, 3),
}
const PORTRAIT2_CELLS := {
	"chao_gai": Vector2i(0, 0), "yang_zhi": Vector2i(1, 0), "bai_sheng": Vector2i(2, 0),
	"cai_jiu": Vector2i(0, 1), "shi_xiu": Vector2i(1, 1), "hu_sanniang": Vector2i(2, 1),
	"xu_ning": Vector2i(0, 2), "hu_yanzhuo": Vector2i(1, 2), "tang_long": Vector2i(2, 2),
}
const PORTRAIT3_CELLS := {
	"zhang_qing": Vector2i(0, 0), "jiang_menshen": Vector2i(1, 0), "shi_en": Vector2i(2, 0),
	"lu_qian": Vector2i(0, 1), "dong_chao": Vector2i(1, 1), "xue_ba": Vector2i(2, 1),
	"zhang_tuanlian": Vector2i(0, 2), "gong_wang": Vector2i(1, 2), "ding_desun": Vector2i(2, 2),
}
const PORTRAITS4_SHEET := "res://assets/portraits4.png" # 据守模式·地方英雄 3x3（原本没脸的敌将）
const PORTRAIT4_CELLS := {
	"luan_tingyu": Vector2i(0, 0), "han_tao": Vector2i(1, 0), "peng_qi": Vector2i(2, 0),
	"zhu_long": Vector2i(0, 1), "zhu_hu": Vector2i(1, 1), "zhu_biao": Vector2i(2, 1),
	"zhu_zhaofeng": Vector2i(0, 2), "shi_wengong": Vector2i(1, 2),
}
const PORTRAITS5_SHEET := "res://assets/portraits5.png" # 据守模式·官军/庄兵兵种立绘 3x3
const PORTRAIT5_CELLS := {
	"guan_dao": Vector2i(0, 0), "guan_gong": Vector2i(1, 0), "guan_qi": Vector2i(2, 0),
	"guan_jingqi": Vector2i(0, 1), "guan_zhanzi": Vector2i(1, 1), "jiang_thug": Vector2i(2, 1),
	"zhu_qi": Vector2i(0, 2), "zhu_gong": Vector2i(1, 2), "zhu_keke": Vector2i(2, 2),
}
const PORTRAITS6_SHEET := "res://assets/portraits6.png" # 驻守战·十节度使头像 3x3
const PORTRAIT6_CELLS := {
	"wang_huan": Vector2i(0, 0), "xu_jing": Vector2i(1, 0), "wang_wende": Vector2i(2, 0),
	"mei_zhan": Vector2i(0, 1), "zhang_kai": Vector2i(1, 1), "yang_wen": Vector2i(2, 1),
	"li_congji": Vector2i(0, 2), "xiang_yuanzhen": Vector2i(1, 2), "jing_zhong": Vector2i(2, 2),
}
const PORTRAITS7_SHEET := "res://assets/portraits7.png" # 驻守战·童贯/水火二将/凌振/闻达 头像 3x3
const PORTRAIT7_CELLS := {
	"duan_pengju": Vector2i(0, 0), "tong_guan": Vector2i(1, 0), "ling_zhen": Vector2i(2, 0),
	"wei_dingguo": Vector2i(0, 1), "shan_tinggui": Vector2i(1, 1), "wen_da": Vector2i(2, 1),
}
const PORTRAITS8_SHEET := "res://assets/portraits8.png" # 重画批·梁山好汉+配角 头像 3x3
const PORTRAIT8_CELLS := {
	"dai_zong": Vector2i(0, 0), "liu_tang": Vector2i(1, 0), "ruan_brother": Vector2i(2, 0),
	"zhang_shun": Vector2i(0, 1), "yan_shun": Vector2i(1, 1), "gou_lian": Vector2i(2, 1),
	"gong_ren": Vector2i(0, 2), "yu_hou": Vector2i(1, 2), "lao_duguan": Vector2i(2, 2),
}
const PORTRAITS9_SHEET := "res://assets/portraits9.png" # 重画批·江州牢子/连环马/朴刀/长枪/猛虎 头像 3x3(填5格)
const PORTRAIT9_CELLS := {
	"guan_laozi": Vector2i(0, 0), "lian_huan_ma": Vector2i(1, 0), "liang_dao": Vector2i(2, 0),
	"liang_qiang": Vector2i(0, 1), "tiger_summon": Vector2i(1, 1),
}

# ── 一百单八将补全批（portraits10..18，3×3 灰底头像，见 ART_REQUEST_108.md §5）──
const PORTRAITS10_SHEET := "res://assets/portraits10.png"
const PORTRAIT10_CELLS := {
	"lu_junyi": Vector2i(0, 0), "guan_sheng": Vector2i(1, 0), "qin_ming": Vector2i(2, 0),
	"chai_jin": Vector2i(0, 1), "li_ying": Vector2i(1, 1), "zhu_tong": Vector2i(2, 1),
	"dong_ping": Vector2i(0, 2), "suo_chao": Vector2i(1, 2), "shi_jin": Vector2i(2, 2),
}
const PORTRAITS11_SHEET := "res://assets/portraits11.png"
const PORTRAIT11_CELLS := {
	"mu_hong": Vector2i(0, 0), "lei_heng": Vector2i(1, 0), "li_jun": Vector2i(2, 0),
	"zhang_heng": Vector2i(0, 1), "ruan_xiaowu": Vector2i(1, 1), "ruan_xiaoqi": Vector2i(2, 1),
	"yang_xiong": Vector2i(0, 2), "xie_zhen": Vector2i(1, 2), "xie_bao": Vector2i(2, 2),
}
const PORTRAITS12_SHEET := "res://assets/portraits12.png"
const PORTRAIT12_CELLS := {
	"yan_qing": Vector2i(0, 0), "zhu_wu": Vector2i(1, 0), "huang_xin": Vector2i(2, 0),
	"sun_li": Vector2i(0, 1), "xuan_zan": Vector2i(1, 1), "hao_siwen": Vector2i(2, 1),
	"xiao_rang": Vector2i(0, 2), "pei_xuan": Vector2i(1, 2), "ou_peng": Vector2i(2, 2),
}
const PORTRAITS13_SHEET := "res://assets/portraits13.png"
const PORTRAIT13_CELLS := {
	"deng_fei": Vector2i(0, 0), "yang_lin": Vector2i(1, 0), "jiang_jing": Vector2i(2, 0),
	"lu_fang": Vector2i(0, 1), "guo_sheng": Vector2i(1, 1), "an_daoquan": Vector2i(2, 1),
	"huangfu_duan": Vector2i(0, 2), "wang_ying": Vector2i(1, 2), "bao_xu": Vector2i(2, 2),
}
const PORTRAITS14_SHEET := "res://assets/portraits14.png"
const PORTRAIT14_CELLS := {
	"fan_rui": Vector2i(0, 0), "kong_ming": Vector2i(1, 0), "kong_liang": Vector2i(2, 0),
	"xiang_chong": Vector2i(0, 1), "li_gun": Vector2i(1, 1), "jin_dajian": Vector2i(2, 1),
	"ma_lin": Vector2i(0, 2), "tong_wei": Vector2i(1, 2), "tong_meng": Vector2i(2, 2),
}
const PORTRAITS15_SHEET := "res://assets/portraits15.png"
const PORTRAIT15_CELLS := {
	"meng_kang": Vector2i(0, 0), "hou_jian": Vector2i(1, 0), "chen_da": Vector2i(2, 0),
	"yang_chun": Vector2i(0, 1), "zheng_tianshou": Vector2i(1, 1), "tao_zongwang": Vector2i(2, 1),
	"song_qing": Vector2i(0, 2), "yue_he": Vector2i(1, 2), "mu_chun": Vector2i(2, 2),
}
const PORTRAITS16_SHEET := "res://assets/portraits16.png"
const PORTRAIT16_CELLS := {
	"cao_zheng": Vector2i(0, 0), "song_wan": Vector2i(1, 0), "du_qian": Vector2i(2, 0),
	"xue_yong": Vector2i(0, 1), "li_zhong": Vector2i(1, 1), "zhou_tong": Vector2i(2, 1),
	"du_xing": Vector2i(0, 2), "zou_yuan": Vector2i(1, 2), "zou_run": Vector2i(2, 2),
}
const PORTRAITS17_SHEET := "res://assets/portraits17.png"
const PORTRAIT17_CELLS := {
	"zhu_gui": Vector2i(0, 0), "zhu_fu": Vector2i(1, 0), "cai_fu": Vector2i(2, 0),
	"cai_qing": Vector2i(0, 1), "li_li": Vector2i(1, 1), "li_yun": Vector2i(2, 1),
	"jiao_ting": Vector2i(0, 2), "shi_yong": Vector2i(1, 2), "sun_xin": Vector2i(2, 2),
}
const PORTRAITS18_SHEET := "res://assets/portraits18.png"
const PORTRAIT18_CELLS := {
	"gu_dasao": Vector2i(0, 0), "zhang_qing_cai": Vector2i(1, 0), "sun_erniang": Vector2i(2, 0),
	"wang_dingliu": Vector2i(0, 1), "yu_baosi": Vector2i(1, 1), "shi_qian": Vector2i(2, 1),
	"duan_jingzhu": Vector2i(0, 2),
}

var _units_tex: Texture2D
var _terrain_tex: Texture2D
var _portraits_tex: Texture2D
var _units2_tex: Texture2D
var _units3_tex: Texture2D
var _terrain2_tex: Texture2D
var _portraits2_tex: Texture2D
var _portraits3_tex: Texture2D
var _portraits4_tex: Texture2D
var _portraits5_tex: Texture2D
var _portraits6_tex: Texture2D
var _portraits7_tex: Texture2D
var _portraits8_tex: Texture2D
var _portraits9_tex: Texture2D
var _portraits10_tex: Texture2D
var _portraits11_tex: Texture2D
var _portraits12_tex: Texture2D
var _portraits13_tex: Texture2D
var _portraits14_tex: Texture2D
var _portraits15_tex: Texture2D
var _portraits16_tex: Texture2D
var _portraits17_tex: Texture2D
var _portraits18_tex: Texture2D
var _buildings_tex: Texture2D
var _buildings2_tex: Texture2D
var _buildings3_tex: Texture2D
var _objects_tex: Texture2D
var _traps_tex: Texture2D
var _tower_tex := {}   # 塔 key -> 3x3 朝向贴图(或 null)，惰性加载
var _cache := {}
var _terrain_img: Image
var _avg_cache := {}
var _anim_cache := {}


func _ready() -> void:
	_units_tex = _try_load(UNITS_SHEET)
	_terrain_tex = _try_load(TERRAIN_SHEET)
	_portraits_tex = _try_load(PORTRAITS_SHEET)
	_units2_tex = _try_load(UNITS2_SHEET)
	_units3_tex = _try_load(UNITS3_SHEET)
	_terrain2_tex = _try_load(TERRAIN2_SHEET)
	_portraits2_tex = _try_load(PORTRAITS2_SHEET)
	_portraits3_tex = _try_load(PORTRAITS3_SHEET)
	_portraits4_tex = _try_load(PORTRAITS4_SHEET)
	_portraits5_tex = _try_load(PORTRAITS5_SHEET)
	_portraits6_tex = _try_load(PORTRAITS6_SHEET)
	_portraits7_tex = _try_load(PORTRAITS7_SHEET)
	_portraits8_tex = _try_load(PORTRAITS8_SHEET)
	_portraits9_tex = _try_load(PORTRAITS9_SHEET)
	_portraits10_tex = _try_load(PORTRAITS10_SHEET)
	_portraits11_tex = _try_load(PORTRAITS11_SHEET)
	_portraits12_tex = _try_load(PORTRAITS12_SHEET)
	_portraits13_tex = _try_load(PORTRAITS13_SHEET)
	_portraits14_tex = _try_load(PORTRAITS14_SHEET)
	_portraits15_tex = _try_load(PORTRAITS15_SHEET)
	_portraits16_tex = _try_load(PORTRAITS16_SHEET)
	_portraits17_tex = _try_load(PORTRAITS17_SHEET)
	_portraits18_tex = _try_load(PORTRAITS18_SHEET)
	_buildings_tex = _try_load(BUILDINGS_SHEET)
	_buildings2_tex = _try_load(BUILDINGS2_SHEET)
	_buildings3_tex = _try_load(BUILDINGS3_SHEET)
	_objects_tex = _try_load(OBJECTS_SHEET)
	_traps_tex = _try_load(TRAPS_SHEET)


func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


# 内容包美术覆盖：把 res://content/art/<key>.png 当作该 key 的贴图（优先于内置图集）。
# 让换皮/加新单位无需改 art_db 的图集常量——丢一张同名 png 即可。无文件则返回 null（走内置）。
const CONTENT_ART_DIR := "res://content/art"
var _content_tex := {}

# 运行时美术别名（场景编辑器「新建单位」时让新 key 借用某现有单位的贴图/动画）。
# 仅本场战斗有效；Battle 每局开场先清空，再由 scenario.apply_overrides 填入。
var _runtime_alias := {}

func set_runtime_alias(d: Dictionary) -> void:
	_runtime_alias = d if d != null else {}

func _ra(key: String) -> String:
	return String(_runtime_alias.get(key, key))

func _content_override(key: String) -> Texture2D:
	if _content_tex.has(key):
		return _content_tex[key]
	var t := _try_load(CONTENT_ART_DIR + "/" + key + ".png")
	_content_tex[key] = t
	return t


func _atlas(tex: Texture2D, cell: Vector2i, grid: int, cache_key: String) -> Texture2D:
	if tex == null:
		return null
	if _cache.has(cache_key):
		return _cache[cache_key]
	var cs := float(tex.get_width()) / float(grid)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(cell.x * cs, cell.y * cs, cs, cs)
	_cache[cache_key] = at
	return at


# 无专属美术的 key → 借用一张合适的现成图，免得 HUD 头像画成空白黄圈。
#  • *_bound：被擒的英雄沿用本体脸  • 公人/战船：借同阵营官军立绘
#  • 特殊道具建筑（集市/酒望/招牌/法场/帅旗/庄门/府衙）：世界内本就以「聚义厅」贴图渲染，头像同款兜底
const ART_ALIAS := {
	"lin_chong_bound": "lin_chong", "song_jiang_bound": "song_jiang", "dai_zong_bound": "dai_zong",
	"gong_ren": "yu_hou", "guan_zhanchuan": "guan_dao",
	"market": "hall", "tavern": "hall", "signboard": "hall", "scaffold": "hall",
	"jiangtai": "hall", "zhu_gate": "hall", "dongchang_yamen": "hall",
}

# 世界内走图别名：暂无专属逐帧走图的地方将领/兵种 → 借同型官军立绘渲染，
# 免得战场上画成「圆圈/三角」占位。HUD 头像不受影响（这些将领多有专属头像，portrait 优先）。
# 按兵种归类：骑→guan_qi、弓→guan_gong、步→guan_dao；投石车→treasure_cart(战车样)。
## 现已为全部战斗单位（含 14 祝家庄/官军小兵 + 呼延灼/扈三娘 + 投石车）生成专属走+打逐帧，
## 不再借同型官军立绘——SPRITE_ALIAS 清空（保留常量以便日后临时借图）。
const SPRITE_ALIAS := {}


## HUD 选区图标/面板头像统一取图：脸→走图→建筑→物件→地形，并先过别名表。
## 全空才返回 null（此时调用方画占位首字，而非黄圈）。这条链覆盖建筑/资源/特殊单位，
## 是消灭「黄色圈圈头像」的单一来源。
func avatar_texture(key: String) -> Texture2D:
	var rk: String = ART_ALIAS.get(key, key)
	var t := portrait_texture(rk)
	if t == null: t = unit_texture(rk)
	if t == null: t = building_texture(rk)
	if t == null: t = object_texture(rk)
	if t == null: t = terrain_texture(rk)
	return t


func unit_texture(key: String) -> Texture2D:
	key = _ra(key)                     # 运行时别名（场景新建单位借图）
	var ov := _content_override(key)   # 内容包覆盖优先
	if ov != null:
		return ov
	key = SPRITE_ALIAS.get(key, key)   # 无专属走图的将领/兵种借同型官军立绘
	if _units_tex != null and UNIT_CELLS.has(key):
		return _atlas(_units_tex, UNIT_CELLS[key], 4, "u_" + key)
	if _units2_tex != null and UNIT2_CELLS.has(key):
		return _atlas(_units2_tex, UNIT2_CELLS[key], 4, "u2_" + key)
	if _units3_tex != null and UNIT3_CELLS.has(key):
		return _atlas(_units3_tex, UNIT3_CELLS[key], 4, "u3_" + key)
	# 回退：仅有逐帧行走图、无静态图集格的单位（喽啰、梁山马军）取走循环「立定帧」当图标，
	# 否则 HUD 头像/选择栏会画成占位圆圈。世界内渲染不受影响（那里始终用动画帧、从不用此回退）。
	var wf := unit_anim_frames(key, "walk")
	if not wf.is_empty():
		return wf[1 % wf.size()]
	return null


func building_texture(key: String) -> Texture2D:
	key = _ra(key)                     # 运行时别名
	var ov := _content_override(key)   # 内容包覆盖优先
	if ov != null:
		return ov
	var tw := tower_sheet(key)         # 防御塔：3x3 朝向表的中心格当底座/图标
	if tw != null:
		return _atlas(tw, Vector2i(1, 1), 3, "twr_%s_c" % key)
	if _buildings_tex != null and BUILDING_CELLS.has(key):
		return _atlas(_buildings_tex, BUILDING_CELLS[key], 2, "b_" + key)
	if _buildings2_tex != null and BUILDING2_CELLS.has(key):
		return _atlas(_buildings2_tex, BUILDING2_CELLS[key], 2, "b2_" + key)
	if _buildings3_tex != null and BUILDING3_CELLS.has(key):
		return _atlas(_buildings3_tex, BUILDING3_CELLS[key], 2, "b3_" + key)
	return null


## 防御塔 3x3 朝向图集（惰性加载）。无图返回 null。
func tower_sheet(key: String) -> Texture2D:
	key = _ra(key)
	if not _tower_tex.has(key):
		_tower_tex[key] = _try_load(TOWER_DIR_SHEETS[key]) if TOWER_DIR_SHEETS.has(key) else null
	return _tower_tex[key]


## 防御塔朝向贴图：cell=3x3 中的格 (col,row)，(1,1)=中心底座。无 3x3 表则返回 null（在世界画程序化转向）。
func tower_dir_texture(key: String, cell: Vector2i) -> Texture2D:
	var tx := tower_sheet(key)
	if tx == null:
		return null
	return _atlas(tx, cell, 3, "twrd_%s_%d_%d" % [key, cell.x, cell.y])


## 陷阱贴图（喽啰 E）。无图返回 null（TrapMarkerFx 程序化兜底）。
func trap_texture(key: String) -> Texture2D:
	if _traps_tex != null and TRAP_CELLS.has(key):
		return _atlas(_traps_tex, TRAP_CELLS[key], 2, "trap_" + key)
	return null


## 资源点物件贴图（金矿/林木）。key ∈ gold_mine/tree/tree1/tree2。无图返回 null（Unit 退回程序化）。
func object_texture(key: String) -> Texture2D:
	if _objects_tex != null and OBJECT_CELLS.has(key):
		return _atlas(_objects_tex, OBJECT_CELLS[key], 2, "o_" + key)
	return null


func terrain_texture(key: String) -> Texture2D:
	if _terrain_tex != null and TERRAIN_CELLS.has(key):
		return _atlas(_terrain_tex, TERRAIN_CELLS[key], 4, "t_" + key)
	if _terrain2_tex != null and TERRAIN2_CELLS.has(key):
		return _atlas(_terrain2_tex, TERRAIN2_CELLS[key], 4, "t2_" + key)
	return null


# 无专属图集格的英雄，可放一张独立头像图（assets/portrait_<key>.png）——优先于图集与回退链。
const STANDALONE_PORTRAITS := {
	"gongsun_sheng": "res://assets/portrait_gongsun_sheng.png",
}
var _standalone_portraits := {}


func portrait_texture(key: String) -> Texture2D:
	key = _ra(key)                  # 运行时别名
	key = ART_ALIAS.get(key, key)   # 被擒英雄等沿用本体脸
	if STANDALONE_PORTRAITS.has(key):   # 独立头像图（有就用）
		if not _standalone_portraits.has(key):
			_standalone_portraits[key] = _try_load(STANDALONE_PORTRAITS[key])
		if _standalone_portraits[key] != null:
			return _standalone_portraits[key]
	if _portraits_tex != null and PORTRAIT_CELLS.has(key):
		return _atlas(_portraits_tex, PORTRAIT_CELLS[key], 3, "p_" + key)
	if _portraits2_tex != null and PORTRAIT2_CELLS.has(key):
		return _atlas(_portraits2_tex, PORTRAIT2_CELLS[key], 3, "p2_" + key)
	if _portraits3_tex != null and PORTRAIT3_CELLS.has(key):
		return _atlas(_portraits3_tex, PORTRAIT3_CELLS[key], 3, "p3_" + key)
	if _portraits4_tex != null and PORTRAIT4_CELLS.has(key):
		return _atlas(_portraits4_tex, PORTRAIT4_CELLS[key], 3, "p4_" + key)
	if _portraits5_tex != null and PORTRAIT5_CELLS.has(key):
		return _atlas(_portraits5_tex, PORTRAIT5_CELLS[key], 3, "p5_" + key)
	if _portraits6_tex != null and PORTRAIT6_CELLS.has(key):
		return _atlas(_portraits6_tex, PORTRAIT6_CELLS[key], 3, "p6_" + key)
	if _portraits7_tex != null and PORTRAIT7_CELLS.has(key):
		return _atlas(_portraits7_tex, PORTRAIT7_CELLS[key], 3, "p7_" + key)
	if _portraits8_tex != null and PORTRAIT8_CELLS.has(key):
		return _atlas(_portraits8_tex, PORTRAIT8_CELLS[key], 3, "p8_" + key)
	if _portraits9_tex != null and PORTRAIT9_CELLS.has(key):
		return _atlas(_portraits9_tex, PORTRAIT9_CELLS[key], 3, "p9_" + key)
	if _portraits10_tex != null and PORTRAIT10_CELLS.has(key):
		return _atlas(_portraits10_tex, PORTRAIT10_CELLS[key], 3, "p10_" + key)
	if _portraits11_tex != null and PORTRAIT11_CELLS.has(key):
		return _atlas(_portraits11_tex, PORTRAIT11_CELLS[key], 3, "p11_" + key)
	if _portraits12_tex != null and PORTRAIT12_CELLS.has(key):
		return _atlas(_portraits12_tex, PORTRAIT12_CELLS[key], 3, "p12_" + key)
	if _portraits13_tex != null and PORTRAIT13_CELLS.has(key):
		return _atlas(_portraits13_tex, PORTRAIT13_CELLS[key], 3, "p13_" + key)
	if _portraits14_tex != null and PORTRAIT14_CELLS.has(key):
		return _atlas(_portraits14_tex, PORTRAIT14_CELLS[key], 3, "p14_" + key)
	if _portraits15_tex != null and PORTRAIT15_CELLS.has(key):
		return _atlas(_portraits15_tex, PORTRAIT15_CELLS[key], 3, "p15_" + key)
	if _portraits16_tex != null and PORTRAIT16_CELLS.has(key):
		return _atlas(_portraits16_tex, PORTRAIT16_CELLS[key], 3, "p16_" + key)
	if _portraits17_tex != null and PORTRAIT17_CELLS.has(key):
		return _atlas(_portraits17_tex, PORTRAIT17_CELLS[key], 3, "p17_" + key)
	if _portraits18_tex != null and PORTRAIT18_CELLS.has(key):
		return _atlas(_portraits18_tex, PORTRAIT18_CELLS[key], 3, "p18_" + key)
	return null


## 逐帧动画图集接口（混合动画的“逐帧”一侧）。
## 约定：assets/anim/<key>_<state>.png 为一条横向帧带（每帧为正方形），state ∈ idle/walk/attack。
## 文件存在则返回各帧 AtlasTexture，否则返回空数组（Unit 退回程序化动画）。
func unit_anim_frames(key: String, state: String) -> Array:
	key = _ra(key)                     # 运行时别名（场景新建单位借动画）
	key = SPRITE_ALIAS.get(key, key)   # 无专属走图的将领/兵种借同型官军逐帧
	var ck := key + "_" + state
	if _anim_cache.has(ck):
		return _anim_cache[ck]
	var frames: Array = []
	var path := "res://assets/anim/%s_%s.png" % [key, state]
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		var h := tex.get_height()
		var n := maxi(1, int(round(float(tex.get_width()) / float(h))))
		for i in range(n):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * h, 0, h, h)
			frames.append(at)
	_anim_cache[ck] = frames
	return frames


## 某地形贴图的平均色（地形过渡混合与小地图用）；无图时返回 fallback
func terrain_avg_color(key: String, fallback: Color) -> Color:
	if _terrain_tex == null or not TERRAIN_CELLS.has(key):
		return fallback
	if _avg_cache.has(key):
		return _avg_cache[key]
	if _terrain_img == null:
		_terrain_img = _terrain_tex.get_image()
		_terrain_img.convert(Image.FORMAT_RGBA8)
	var cs := _terrain_img.get_width() / 4
	var cell: Vector2i = TERRAIN_CELLS[key]
	var sum := Vector3.ZERO
	var n := 0
	for y in range(cell.y * cs + 8, (cell.y + 1) * cs - 8, 12):
		for x in range(cell.x * cs + 8, (cell.x + 1) * cs - 8, 12):
			var c := _terrain_img.get_pixel(x, y)
			if c.a > 0.5:
				sum += Vector3(c.r, c.g, c.b)
				n += 1
	var avg := fallback if n == 0 else Color(sum.x / n, sum.y / n, sum.z / n)
	_avg_cache[key] = avg
	return avg
