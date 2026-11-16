extends RefCounted
## Stateless orders shared by campaign squads. The owning level stores members,
## strength, phase and timers explicitly so saves never replay a deployment.

static func alive(u) -> bool:
	return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == ""

static func survivors(members: Array) -> Array:
	return members.filter(alive)

static func should_withdraw(members: Array, initial_count: int) -> bool:
	var live := survivors(members)
	if live.is_empty(): return false
	if live.size() * 2 <= initial_count: return true
	var health := 0.0
	var capacity := 0.0
	for u in live:
		health += u.hp
		capacity += u.max_hp
	return capacity > 0.0 and health <= capacity * 0.45

static func gathered(members: Array, at: Vector2, radius := 150.0) -> bool:
	var live := survivors(members)
	if live.is_empty(): return false
	var near := 0
	for u in live:
		if u.position.distance_to(at) <= radius: near += 1
	return near * 3 >= live.size() * 2

static func advance(members: Array, at: Vector2) -> void:
	for u in survivors(members):
		u.set_stance(Unit.STANCE_AGGRO)
		u.order_amove(at)

static func withdraw(members: Array, at: Vector2) -> void:
	# Explicit movement disengages. No teleport, healing or replacement units.
	for u in survivors(members):
		u.order_move(at)

static func guard(members: Array) -> void:
	for u in survivors(members):
		u.order_stop()
		u.set_stance(Unit.STANCE_DEFEND)
