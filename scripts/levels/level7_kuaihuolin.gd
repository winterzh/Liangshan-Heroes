extends LevelBase
## 第7关·醉打蒋门神（武松快活林）。武松为施恩夺回被蒋门神霸占的快活林酒肉店。
## 「无三不过望」：往快活林的路上一连十数家酒望，武松逢酒便吃三碗——酒越喝得多，醉意越浓、
## 拳脚越狠。喝足了再扑进快活林，玉环步、鸳鸯脚打翻蒋门神一伙，砸了那霸占的招牌，物归原主。
## 机制：沿路在酒望「吃三碗」叠加醉意（永久增攻/增速/增血）→ 杀进快活林打死蒋门神并砸毁招牌=胜。

const T := GameMap.T

const START_E := Vector2i(6, 19)     # 东·孟州牢营（我军起点）
const KUAIHUO := Vector2i(52, 19)    # 西·快活林市口（蒋门神盘踞）
const SIGN := Vector2i(54, 18)       # 蒋家霸占的招牌/酒肉店
const BOSS_TRIGGER_X := 45           # 武松越过此列 → 快活林决战打响

const DRINK_R := 58.0                # 路过酒望「吃三碗」的判定半径
const TAVERN_CELLS := [Vector2i(16, 15), Vector2i(25, 22), Vector2i(34, 14), Vector2i(43, 21)]

enum { ROAD, SHOWDOWN }

var wu: Unit = null
var sign: Unit = null
var menshen: Unit = null
var taverns: Array = []              # [{u:Unit, drunk:bool}]
var drunk := 0
var st := ROAD
var boss_on := false
var smoke_t := 0.0


func id() -> String: return "level7"
func title() -> String: return "醉打蒋门神"
func subtitle() -> String: return "快活林·无三不过望"
func map_w() -> int: return 60
func map_h() -> int: return 38
func map_theme() -> String: return "town"
func map_base() -> int: return T.GRASS
func camera_start_cell() -> Vector2i: return Vector2i(12, 19)
func deploy_hint() -> String:
	return "「无三不过望」——往快活林的路上有好几处酒望（酒旗）。让武松挨家走过去「吃三碗」，每喝一处，醉意便加一层，攻击、移速、气血俱涨！喝得越足，进了快活林越是打得蒋门神抱头鼠窜。攒够醉意，再杀进西头快活林，打死蒋门神、砸了那块霸占的招牌！"


func intro_lines() -> Array:
	return [
		{"who": "旁白", "key": "narrator", "text": "孟州道快活林，是来往客商辐辏之地，一座酒肉店是金眼彪施恩的衣食父母。不料蒋门神倚仗张团练的势力，一拳打跑施恩，强占了这座买卖。武松刺配孟州，得施恩义气相待，今日便要替他夺回快活林。"},
		{"who": "施恩", "key": "shi_en", "text": "二哥，那蒋门神有一身好本事，又有张团练撑腰，端的不好惹。这一路上酒望甚多……"},
		{"who": "武松", "key": "wu_song", "text": "施恩贤弟放心！我武松平生'三碗不过冈'，偏是吃了酒,胆量越大，气力越壮。这一路酒望，逢着便吃他三碗——吃得我十分醉了，方才有力气打那厮！'无三不过望'，走！"},
		{"who": "军令", "key": "narrator", "text": "【无三不过望】沿路在每处酒望「吃三碗」，醉意层层叠加（攻击/移速/气血皆涨，永久不退）。喝足了再杀进快活林，打死蒋门神并砸毁霸占的招牌=胜；武松倒下=败。"},
	]


func paint_map(map: GameMap) -> void:
	# 上下林木夹道（快活"林"），中部一条贯通东西的孟州官道
	map.fill_rect(0, 0, 60, 6, T.FOREST)
	map.fill_rect(0, 32, 60, 6, T.FOREST)
	map.fill_ellipse(Vector2(20, 9), 4, 2, T.FOREST)
	map.fill_ellipse(Vector2(30, 28), 5, 2, T.FOREST)
	map.fill_ellipse(Vector2(40, 9), 4, 2, T.FOREST)
	# 孟州官道（东牢营 → 西快活林）
	map.paint_path([Vector2(START_E.x, START_E.y), Vector2(16, 19), Vector2(28, 19), Vector2(40, 19), Vector2(KUAIHUO.x, KUAIHUO.y)], 1, T.ROAD)
	# 快活林市口：一片镇集硬地
	map.fill_ellipse(Vector2(KUAIHUO.x, KUAIHUO.y), 7, 5, T.PLAZA)
	map.fill_ellipse(Vector2(SIGN.x, SIGN.y), 3, 2, T.PLAZA)
	# 各酒望前清出小块硬地
	for c in TAVERN_CELLS:
		map.fill_ellipse(Vector2(c.x, c.y), 2, 1, T.DRYHILL, [T.DRYHILL, T.GRASS, T.ROAD])


func decorate(map: GameMap) -> void:
	var d: Array = [
		["town_house", Vector2i(KUAIHUO.x - 3, KUAIHUO.y - 2), 60.0],
		["town_house", Vector2i(KUAIHUO.x + 2, KUAIHUO.y + 3), 56.0],
		["tent", Vector2i(START_E.x + 1, START_E.y + 1), 54.0],
	]
	for c in TAVERN_CELLS:
		d.append(["tent", c, 48.0])   # 酒望/酒旗草棚
	map.decor = d


func deploy(b) -> void:
	var B: Battle = b
	# 我军：武松（主角）+ 施恩 + 几名牢营弟兄，自东牢营出发
	wu = B.spawn_at("wu_song", Unit.FACTION_LIANG, START_E)
	B.spawn_at("shi_en", Unit.FACTION_LIANG, START_E + Vector2i(0, 1))
	for c in [Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 2)]:
		B.spawn_at("liang_dao", Unit.FACTION_LIANG, START_E + c)
	# 酒望（drink 站点）：作我方中立标记建筑（不可摧毁、不会被自家攻击）
	taverns.clear()
	for cell in TAVERN_CELLS:
		var tv := B.spawn_at("tavern", Unit.FACTION_LIANG, cell)
		taverns.append({"u": tv, "drunk": false})
	# 快活林：蒋门神 + 张团练 + 一伙打手盘踞，先按兵不动（passive），待武松杀近才发作
	menshen = B.spawn_at("jiang_menshen", Unit.FACTION_GUAN, KUAIHUO)
	menshen.passive = true
	sign = B.spawn_at("signboard", Unit.FACTION_GUAN, SIGN)
	var zt := B.spawn_at("zhang_tuanlian", Unit.FACTION_GUAN, KUAIHUO + Vector2i(2, 2))
	zt.passive = true
	for c in [Vector2i(-2, -1), Vector2i(-1, 2), Vector2i(1, -2), Vector2i(2, 0)]:
		var th := B.spawn_at("jiang_thug", Unit.FACTION_GUAN, KUAIHUO + c)
		th.passive = true


func on_start(b) -> void:
	var B: Battle = b
	st = ROAD
	drunk = 0
	boss_on = false
	B.msg("「无三不过望」——领着武松挨家酒望吃三碗，攒足醉意，再杀奔快活林！", 5.0)


func process(b, delta: float) -> void:
	var B: Battle = b
	if B._smoke:
		_smoke_drive(B, delta)
	if not is_instance_valid(wu) or wu.hp <= 0.0:
		B.lose("武松醉倒在快活林前，夺店之事，终成泡影……")
		return
	# 沿途「吃三碗」：武松路过酒望即叠加醉意
	for t in taverns:
		if not t["drunk"] and is_instance_valid(t["u"]) \
				and wu.position.distance_to(t["u"].position) <= DRINK_R:
			_drink(B, t)
	# 杀近快活林 → 决战打响
	if not boss_on and wu.position.x >= B.map.cell_to_world(Vector2i(BOSS_TRIGGER_X, KUAIHUO.y)).x:
		_open_showdown(B)
	if st == SHOWDOWN:
		var menshen_dead := not is_instance_valid(menshen) or menshen.hp <= 0.0
		var sign_dead := not is_instance_valid(sign) or sign.hp <= 0.0
		if menshen_dead and sign_dead:
			B.win("醉拳如风，玉环步鸳鸯脚——蒋门神被打得求饶滚地，那霸占的招牌也砸了个粉碎！快活林，物归施恩。")
			return


func _drink(b, t: Dictionary) -> void:
	var B: Battle = b
	t["drunk"] = true
	drunk += 1
	# 醉意叠加：永久增攻（垫高基础攻击，与技能临时增攻叠乘不冲突）+ 增血 + 增速
	wu._base_atk += 7.0
	wu.atk += 7.0
	wu.max_hp += 60.0
	wu.heal(110.0)
	wu.apply_slow(1.0 + 0.11 * float(drunk), 999.0)   # apply_slow(>1)=加速
	wu._buff_glow = 0.9
	wu.queue_redraw()
	B.spawn_impact(wu.position + Vector2(0, -12), true)
	Sfx.play("cast", 0.0, 0.05, 100)
	var quips := ["这酒有些气力！", "好酒！再来三碗！", "我武松吃得越醉，越有本事！", "十分醉了——正好打那蒋门神！"]
	B.msg("【吃三碗·醉意 ×%d】%s" % [drunk, quips[mini(drunk - 1, quips.size() - 1)]], 3.0)


func _open_showdown(b) -> void:
	var B: Battle = b
	boss_on = true
	st = SHOWDOWN
	# 快活林众人发作扑出
	for u in B.units_of(Unit.FACTION_GUAN):
		if is_instance_valid(u) and not u.is_building and u.key != "tavern":
			u.passive = false
			if is_instance_valid(wu):
				u.order_amove(wu.position)
	var dz := "醉" if drunk >= 3 else "尚欠几碗酒"
	B.msg("快活林到了！蒋门神拍案而起——武松（%s，醉意 ×%d）抢上去便打！打死蒋门神、砸了招牌！" % [dz, drunk], 5.0)


func on_unit_died(b, u) -> void:
	if u == wu:
		b.lose("武松力竭倒在快活林前，夺店之事，终成泡影……")
	elif u == menshen:
		b.msg("蒋门神被打翻在地，连声讨饶！再把那块霸占的招牌也砸了！", 4.0)


func top_status(b) -> String:
	var B: Battle = b
	if st == ROAD:
		var n := 0
		for t in taverns:
			if t["drunk"]:
				n += 1
		return "无三不过望 | 醉意 ×%d | 已吃酒望 %d/%d | 杀奔快活林" % [drunk, n, taverns.size()]
	var ms := "已伏诛" if (not is_instance_valid(menshen) or menshen.hp <= 0.0) else "%d" % ceili(menshen.hp)
	var sg := "已砸毁" if (not is_instance_valid(sign) or sign.hp <= 0.0) else "%d" % ceili(sign.hp)
	return "快活林决战 | 醉意 ×%d | 蒋门神 %s | 招牌 %s | 歼敌 %d" % [drunk, ms, sg, B.kills]


# ---- 冒烟自测：武松沿路吃酒 → 杀进快活林平蒋门神、砸招牌 ----
func _smoke_drive(b, delta: float) -> void:
	var B: Battle = b
	smoke_t -= delta
	if smoke_t > 0.0:
		return
	smoke_t = 1.5
	if not is_instance_valid(wu):
		return
	if st == ROAD:
		# 依次走向尚未喝过的酒望，喝完直奔快活林
		var goal: Vector2 = B.map.cell_to_world(KUAIHUO)
		for t in taverns:
			if not t["drunk"] and is_instance_valid(t["u"]):
				goal = t["u"].position
				break
		for u in B.units_of(Unit.FACTION_LIANG):
			if is_instance_valid(u) and not u.is_building:
				u.order_amove(goal)
	else:
		var tgt: Vector2 = menshen.position if (is_instance_valid(menshen) and menshen.hp > 0.0) \
			else (sign.position if is_instance_valid(sign) else B.map.cell_to_world(KUAIHUO))
		for u in B.units_of(Unit.FACTION_LIANG):
			if is_instance_valid(u) and not u.is_building:
				u.order_amove(tgt)
		if wu.slot_ready(0):
			B.cast_ability(wu)
