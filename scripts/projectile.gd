class_name Projectile
extends Node2D
## 简单追踪箭矢。逻辑空间飞行；绘制时按等距屏幕方向旋转、保持不被斜切。

var target: Unit = null
var shooter: Unit = null
var dmg := 8.0
var crit := false
var speed := 420.0
var _dir := Vector2.RIGHT
var _life := 3.0
var kind := "arrow"          # "arrow"=直射箭；"boulder"=投石车抛射巨石（抛物线+缓速+落地扬尘）
var splash := 0.0            # >0 = 命中点小范围溅射（金龙吐火）：范围内其余敌人也吃同等伤害
var _dist0 := 1.0            # 起射时与目标的距离（算抛物线高度用）
var _spin := 0.0            # 巨石翻滚相位


func setup(p_shooter: Unit, p_target: Unit, p_dmg: float, p_crit := false) -> void:
	shooter = p_shooter
	target = p_target
	dmg = p_dmg
	crit = p_crit
	if is_instance_valid(target):
		_dir = (target.position - position).normalized()
		_dist0 = maxf(position.distance_to(target.position), 1.0)
	if p_shooter != null and is_instance_valid(p_shooter) and p_shooter.key == "siege_cata":
		kind = "boulder"
		speed = 240.0          # 巨石飞得慢、看得见抛射
		_life = 5.0
	elif p_shooter != null and is_instance_valid(p_shooter) and String(p_shooter.setup_def.get("proj_kind", "")) == "fireball":
		kind = "fireball"      # 公孙胜·火球
		speed = 320.0
		_spin = randf() * TAU


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if not is_instance_valid(target) or target.hp <= 0.0:
		queue_free()
		return
	var tp := target.position
	# 弹道箭矢：只「轻微」地朝目标修正（而非每帧完全锁头），看起来像直射的箭而非跟踪导弹；
	# 接近目标即结算命中（仍必中，不改数值平衡）。
	var want := (tp - position).normalized()
	_dir = _dir.lerp(want, 0.14)
	if _dir.length() < 0.01:
		_dir = want
	_dir = _dir.normalized()
	var step := speed * delta
	_spin += delta * 7.0
	if position.distance_to(tp) <= maxf(step, target.radius + 6.0):
		var s := shooter if (shooter != null and is_instance_valid(shooter)) else null
		if target._phys_immune_t > 0.0:   # 醉神·物理免疫：远程普攻也被挡下，累计转血
			target._absorbed_phys += dmg
			target._buff_glow = 1.0
		else:
			target.take_damage(dmg, s, crit)
			if s != null and not target.garrisoned:   # 远程命中也吸血（与近战一致）
				var ls: float = s.lifesteal_frac()
				if ls > 0.0:
					s.heal(dmg * ls)
		# 小范围溅射（金龙吐火）：对命中点附近的其余敌人也造成同等伤害
		if splash > 0.0 and s != null and is_instance_valid(s) and s.battle != null:
			for u in s.battle.units:
				if u == target or not is_instance_valid(u) or u.hp <= 0.0:
					continue
				if u.faction == s.faction or u.is_resource or u.garrisoned:
					continue
				if tp.distance_to(u.position) <= splash + u.radius:
					if u._phys_immune_t > 0.0:
						u._absorbed_phys += dmg
						u._buff_glow = 1.0
					else:
						u.take_damage(dmg, s)
			s.battle.spawn_impact(tp, true)
		if kind == "boulder" and s != null and s.battle != null:   # 巨石落地：扬尘+屏震
			s.battle.spawn_impact(tp, true)
			s.battle.shake(3.0, tp)
		queue_free()
	else:
		position += _dir * step
		queue_redraw()


## 抛物线视觉高度：飞行中段升起、落点归零（仅绘制偏移，不改命中判定）。
func _lob_height() -> float:
	if kind != "boulder" or not is_instance_valid(target):
		return 0.0
	var prog := clampf(1.0 - position.distance_to(target.position) / _dist0, 0.0, 1.0)
	return sin(prog * PI) * (18.0 + _dist0 * 0.10)


func _draw() -> void:
	if kind == "boulder":
		draw_set_transform_matrix(GameMap.ISO_INV * Transform2D(_spin, Vector2.ONE, 0.0, Vector2(0, -10 - _lob_height())))
		draw_circle(Vector2(1.5, 2.0), 6.2, Color(0, 0, 0, 0.28))           # 自影
		draw_circle(Vector2.ZERO, 6.2, Color(0.46, 0.44, 0.42))             # 石体
		draw_circle(Vector2(-1.6, -1.8), 3.0, Color(0.62, 0.60, 0.57))      # 高光面
		draw_arc(Vector2.ZERO, 6.2, 0.0, TAU, 14, Color(0.26, 0.24, 0.22), 1.2)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if kind == "fireball":
		draw_set_transform_matrix(GameMap.ISO_INV * Transform2D(_spin, Vector2.ONE, 0.0, Vector2(0, -12)))
		draw_circle(Vector2(2.0, 2.5), 6.5, Color(0, 0, 0, 0.22))                  # 自影
		draw_circle(Vector2.ZERO, 6.8, Color(1.0, 0.42, 0.10, 0.85))              # 外焰
		draw_circle(Vector2.ZERO, 4.4, Color(1.0, 0.72, 0.20))                    # 中焰
		draw_circle(Vector2(-1.0, -1.0), 2.4, Color(1.0, 0.96, 0.7))              # 内核
		for i in range(4):                                                        # 拖尾火舌
			var a := _spin * 0.5 + float(i) * 1.57
			draw_circle(Vector2(cos(a), sin(a)) * 5.0, 2.0, Color(1.0, 0.55, 0.12, 0.5))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var screen_angle := GameMap.ISO.basis_xform(_dir).angle()
	draw_set_transform_matrix(GameMap.ISO_INV * Transform2D(screen_angle, Vector2.ONE, 0.0, Vector2(0, -10)))
	var c := Color(0.92, 0.87, 0.7)
	draw_line(Vector2(-7, 0), Vector2(5, 0), c, 1.6)
	draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(3, -2.5), Vector2(3, 2.5)]), c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
