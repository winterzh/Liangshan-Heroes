class_name HeroInventory
extends RefCounted
## 英雄单局物品栏。这里只管理物品实例、堆叠、共享冷却、被动触发冷却与快照；
## 施放目标选择和效果结算由 Battle 负责，HUD 只读取状态，不把物品伪装成 Q/W/E/R 技能。

const SLOT_COUNT := 6
const PERIODIC_STEP := 0.25

var owner = null
var slots: Array = []                  # [{id,count,uid}]；空格为 {}
var cooldowns: Dictionary = {}         # item id -> 剩余秒数；同名主动物品天然共享
var proc_cooldowns: Dictionary = {}    # "uid:event" -> 剩余秒数
var _uid_seq := 0
var _periodic_acc := 0.0


func _init(p_owner = null) -> void:
	owner = p_owner
	_reset_slots()


func _reset_slots() -> void:
	slots.clear()
	for _i in range(SLOT_COUNT):
		slots.append({})


func item_def(item_id: String) -> Dictionary:
	if owner != null and is_instance_valid(owner) and owner.battle != null \
			and owner.battle.has_method("item_def"):
		return owner.battle.item_def(item_id)
	return Defs.ITEMS.get(item_id, {})


func slot_item(slot: int) -> Dictionary:
	if slot < 0 or slot >= SLOT_COUNT:
		return {}
	return slots[slot]


func slot_def(slot: int) -> Dictionary:
	var item := slot_item(slot)
	return item_def(String(item.get("id", ""))) if not item.is_empty() else {}


func _new_uid() -> int:
	_uid_seq += 1
	var base := int(owner.get_instance_id()) if owner != null and is_instance_valid(owner) else 1
	return base * 1000 + _uid_seq


func put_item(slot: int, item_id: String, count := 1) -> bool:
	if slot < 0 or slot >= SLOT_COUNT or not slots[slot].is_empty():
		return false
	var idef := item_def(item_id)
	if idef.is_empty() or count <= 0:
		return false
	var maximum := maxi(1, int(idef.get("max_stack", 1)))
	slots[slot] = {"id": item_id, "count": mini(count, maximum), "uid": _new_uid()}
	_notify_changed()
	return true


## 返回未能放入的数量。先补已有堆叠，再占空格；满栏绝不覆盖或销毁旧物品。
func add_item(item_id: String, count := 1) -> int:
	var idef := item_def(item_id)
	if idef.is_empty() or count <= 0:
		return maxi(0, count)
	var left := count
	var maximum := maxi(1, int(idef.get("max_stack", 1)))
	if maximum > 1:
		for i in range(SLOT_COUNT):
			var cur: Dictionary = slots[i]
			if String(cur.get("id", "")) != item_id or int(cur.get("count", 0)) >= maximum:
				continue
			var moved := mini(left, maximum - int(cur["count"]))
			cur["count"] = int(cur["count"]) + moved
			left -= moved
			if left <= 0:
				_notify_changed()
				return 0
	while left > 0:
		var empty := first_empty_slot()
		if empty < 0:
			break
		var moved := mini(left, maximum)
		slots[empty] = {"id": item_id, "count": moved, "uid": _new_uid()}
		left -= moved
	_notify_changed()
	return left


func first_empty_slot() -> int:
	for i in range(SLOT_COUNT):
		if slots[i].is_empty():
			return i
	return -1


func find_uid(uid: int) -> int:
	for i in range(SLOT_COUNT):
		if int(slots[i].get("uid", 0)) == uid:
			return i
	return -1


func has_item(item_id: String) -> bool:
	for item in slots:
		if String(item.get("id", "")) == item_id:
			return true
	return false


func swap_slots(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= SLOT_COUNT or b >= SLOT_COUNT or a == b:
		return false
	var tmp: Dictionary = slots[a]
	slots[a] = slots[b]
	slots[b] = tmp
	_notify_changed()
	return true


## 转给另一英雄的第一个空格。数量、实例 uid 和剩余冷却完整保留；目标满栏则原物品不动。
func transfer_slot(slot: int, target_inventory: HeroInventory) -> bool:
	if slot < 0 or slot >= SLOT_COUNT or slots[slot].is_empty() or target_inventory == null:
		return false
	var dst := target_inventory.first_empty_slot()
	if dst < 0:
		return false
	var item: Dictionary = slots[slot]
	var item_id := String(item.get("id", ""))
	target_inventory.slots[dst] = item.duplicate(true)
	var left := cooldown_left(item_id)
	if left > 0.0:
		target_inventory.cooldowns[item_id] = maxf(target_inventory.cooldown_left(item_id), left)
	# 实例被动内置冷却跟随该件物品转移。
	var uid := int(item.get("uid", 0))
	for key_v in proc_cooldowns.keys().duplicate():
		var key := String(key_v)
		if key.begins_with("%d:" % uid):
			target_inventory.proc_cooldowns[key] = float(proc_cooldowns[key])
			proc_cooldowns.erase(key)
	slots[slot] = {}
	if not has_item(item_id):
		cooldowns.erase(item_id)
	_notify_changed()
	target_inventory._notify_changed()
	return true


func consume_one(slot: int) -> void:
	if slot < 0 or slot >= SLOT_COUNT or slots[slot].is_empty():
		return
	var item_id := String(slots[slot].get("id", ""))
	var count := int(slots[slot].get("count", 1)) - 1
	if count > 0:
		slots[slot]["count"] = count
	else:
		var uid := int(slots[slot].get("uid", 0))
		slots[slot] = {}
		for key_v in proc_cooldowns.keys().duplicate():
			if String(key_v).begins_with("%d:" % uid):
				proc_cooldowns.erase(key_v)
		if not has_item(item_id):
			cooldowns.erase(item_id)
	_notify_changed()


func cooldown_left(item_id: String) -> float:
	return maxf(0.0, float(cooldowns.get(item_id, 0.0)))


func cooldown_total(slot: int) -> float:
	var active: Dictionary = slot_def(slot).get("active", {})
	return maxf(0.0, float(active.get("cooldown", 0.0)))


func cooldown_frac(slot: int) -> float:
	var total := cooldown_total(slot)
	if total <= 0.0:
		return 0.0
	return clampf(cooldown_left(String(slot_item(slot).get("id", ""))) / total, 0.0, 1.0)


func is_active(slot: int) -> bool:
	return not slot_def(slot).get("active", {}).is_empty()


func ready(slot: int) -> bool:
	if owner == null or not is_instance_valid(owner) or not owner.is_hero or owner.hp <= 0.0 or owner.garrisoned:
		return false
	if slot < 0 or slot >= SLOT_COUNT or slots[slot].is_empty() or not is_active(slot):
		return false
	# 沉默不禁用物品；硬控、冲锋、引导和已有施法抬手会阻止使用。
	if owner._stun_t > 0.0 or owner._channel_t > 0.0 or owner._cast_t > 0.0 \
			or owner._charge_t > 0.0 or owner._charge_dash > 0.0:
		return false
	return cooldown_left(String(slots[slot].get("id", ""))) <= 0.0


func start_cooldown(slot: int) -> void:
	if slot < 0 or slot >= SLOT_COUNT or slots[slot].is_empty():
		return
	var item_id := String(slots[slot].get("id", ""))
	var total := cooldown_total(slot)
	if total > 0.0:
		cooldowns[item_id] = maxf(cooldown_left(item_id), total)


func proc_ready(uid: int, event: String) -> bool:
	return float(proc_cooldowns.get("%d:%s" % [uid, event], 0.0)) <= 0.0


func start_proc_cooldown(uid: int, event: String, seconds: float) -> void:
	if seconds > 0.0:
		proc_cooldowns["%d:%s" % [uid, event]] = seconds


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	_tick_dict(cooldowns, delta)
	_tick_dict(proc_cooldowns, delta)
	_periodic_acc += delta
	if _periodic_acc >= PERIODIC_STEP:
		_periodic_acc = fmod(_periodic_acc, PERIODIC_STEP)
		if owner != null and is_instance_valid(owner) and owner.battle != null \
				and owner.battle.has_method("trigger_item_event"):
			owner.battle.trigger_item_event(owner, "periodic", {"step": PERIODIC_STEP})


static func _tick_dict(values: Dictionary, delta: float) -> void:
	for key in values.keys().duplicate():
		var left := maxf(0.0, float(values[key]) - delta)
		if left <= 0.0:
			values.erase(key)
		else:
			values[key] = left


## 普通 stats/stats_pct 每件都叠加；passive 中声明 unique_group 的属性只取 power 最大的一件。
func stat_modifiers() -> Dictionary:
	var out := {"flat": {}, "pct": {}}
	var unique := {}
	for i in range(SLOT_COUNT):
		var idef := slot_def(i)
		if idef.is_empty():
			continue
		_add_stat_dict(out["flat"], idef.get("stats", {}))
		_add_stat_dict(out["pct"], idef.get("stats_pct", {}))
		for passive in _passive_list(idef):
			var group := String(passive.get("unique_group", ""))
			if group == "":
				_add_stat_dict(out["flat"], passive.get("stats", {}))
				_add_stat_dict(out["pct"], passive.get("stats_pct", {}))
			elif not unique.has(group) or float(passive.get("power", 1.0)) > float(unique[group].get("power", 1.0)):
				unique[group] = passive
	for passive in unique.values():
		_add_stat_dict(out["flat"], passive.get("stats", {}))
		_add_stat_dict(out["pct"], passive.get("stats_pct", {}))
	return out


static func _add_stat_dict(dst: Dictionary, src_v) -> void:
	if not (src_v is Dictionary):
		return
	var src: Dictionary = src_v
	for key in src:
		dst[key] = float(dst.get(key, 0.0)) + float(src[key])


## 返回某事件当前真正生效的被动。唯一被动按组只取 power 最大者；普通被动可随重复物品叠加。
func event_passives(event: String) -> Array:
	var normal: Array = []
	var unique := {}
	for i in range(SLOT_COUNT):
		var item: Dictionary = slots[i]
		if item.is_empty():
			continue
		var idef := slot_def(i)
		for passive_v in _passive_list(idef):
			var passive: Dictionary = passive_v
			var triggers: Dictionary = passive.get("triggers", {})
			if not triggers.has(event):
				continue
			var rec := {"item_id": String(item.get("id", "")), "uid": int(item.get("uid", 0)),
				"slot": i, "passive": passive, "effect": triggers[event]}
			var group := String(passive.get("unique_group", ""))
			if group == "":
				normal.append(rec)
			elif not unique.has(group) or float(passive.get("power", 1.0)) > float((unique[group]["passive"] as Dictionary).get("power", 1.0)):
				unique[group] = rec
	for rec in unique.values():
		normal.append(rec)
	return normal


static func _passive_list(idef: Dictionary) -> Array:
	var raw = idef.get("passive", [])
	if raw is Dictionary:
		return [raw]
	return raw if raw is Array else []


func snapshot() -> Dictionary:
	return {"slots": slots.duplicate(true), "cooldowns": cooldowns.duplicate(true),
		"proc_cooldowns": proc_cooldowns.duplicate(true), "uid_seq": _uid_seq}


func restore(data: Dictionary) -> void:
	_reset_slots()
	var saved: Array = data.get("slots", [])
	for i in range(mini(SLOT_COUNT, saved.size())):
		if saved[i] is Dictionary:
			slots[i] = (saved[i] as Dictionary).duplicate(true)
	cooldowns = (data.get("cooldowns", {}) as Dictionary).duplicate(true)
	proc_cooldowns = (data.get("proc_cooldowns", {}) as Dictionary).duplicate(true)
	_uid_seq = maxi(int(data.get("uid_seq", 0)), _uid_seq)
	_notify_changed()


static func tick_snapshot(data: Dictionary, delta: float) -> void:
	if delta <= 0.0:
		return
	var cds: Dictionary = data.get("cooldowns", {})
	var procs: Dictionary = data.get("proc_cooldowns", {})
	_tick_dict(cds, delta)
	_tick_dict(procs, delta)
	data["cooldowns"] = cds
	data["proc_cooldowns"] = procs


func _notify_changed() -> void:
	if owner != null and is_instance_valid(owner):
		owner._recompute_hero_stats()
		owner.queue_redraw()
		if owner.battle != null and owner.battle.hud != null:
			owner.battle.hud.refresh_inventory()
