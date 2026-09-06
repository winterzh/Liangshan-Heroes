"""Build only this pinned two-file candidate. Never writes production or runs Godot."""
import difflib
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCES = {
    'scripts/battle.gd': '9b79f2c677fe16def52b312d1e313a6fd63370f9119bb0b11d27443fd1c92e7e',
    'scripts/hero_inventory.gd': '1dd9a3b2fec0a5fc1ed2546e7bc842719a60f2cd251897434564702c01419de5',
}


def replace_once(raw, before, after):
    variants = [(before.encode(), after.encode()),
                (before.replace('\n', '\r\n').encode(), after.replace('\n', '\r\n').encode())]
    matches = [(old, new) for old, new in variants if raw.count(old) == 1]
    if len(matches) != 1:
        raise ValueError('Exact unique source block required: ' + before[:80])
    return raw.replace(*matches[0])


def candidate(path, raw):
    if hashlib.sha256(raw).hexdigest() != SOURCES[path]:
        raise ValueError('Source SHA mismatch: ' + path)
    if path == 'scripts/battle.gd':
        raw = replace_once(raw, 'var _items := {}\n', '''var _items := {}
# Battle-wide item stack identity. MAX is an exhausted next-counter sentinel;
# it is never issued, so next_item_uid always exceeds every allocated item UID.
const ITEM_UID_EXHAUSTED := 9223372036854775807
var next_item_uid: int = 1
''')
        raw = replace_once(raw, '''func item_def(item_id: String) -> Dictionary:
	return _items.get(item_id, {})
''', '''func allocate_item_uid() -> int:
	if next_item_uid <= 0 or next_item_uid >= ITEM_UID_EXHAUSTED:
		return 0
	var uid: int = next_item_uid
	next_item_uid += 1
	return uid


func item_def(item_id: String) -> Dictionary:
	return _items.get(item_id, {})
''')
        raw = replace_once(raw, '''	if u.is_hero and u.inventory != null and hero_item_progress.has(key):
		u.inventory.restore(hero_item_progress[key])
		hero_item_progress.erase(key)
''', '''	if u.is_hero and u.inventory != null and hero_item_progress.has(key):
		if not u.inventory.restore(hero_item_progress[key]):
			# Keep the retired snapshot if its UID domain is not installed yet.
			u.queue_free()
			return null
		hero_item_progress.erase(key)
''')
    else:
        raw = replace_once(raw, '''func _new_uid() -> int:
	_uid_seq += 1
	var base := int(owner.get_instance_id()) if owner != null and is_instance_valid(owner) else 1
	return base * 1000 + _uid_seq
''', '''func _uid_battle():
	if owner == null or not is_instance_valid(owner):
		return null
	var battle = owner.battle
	if battle == null or not is_instance_valid(battle) or not battle.has_method("allocate_item_uid"):
		return null
	return battle


func _new_uid() -> int:
	var battle = _uid_battle()
	# Ownerless/old standalone tools have no safe Battle UID domain: fail closed.
	if battle == null:
		return 0
	var uid: int = battle.allocate_item_uid()
	if uid > 0 and _uid_seq < 9223372036854775807:
		_uid_seq += 1 # Legacy snapshot field only; never determines the UID.
	return uid
''')
        raw = replace_once(raw, '''	var maximum := maxi(1, int(idef.get("max_stack", 1)))
	slots[slot] = {"id": item_id, "count": mini(count, maximum), "uid": _new_uid()}
''', '''	var maximum := maxi(1, int(idef.get("max_stack", 1)))
	var uid := _new_uid()
	if uid <= 0:
		return false
	slots[slot] = {"id": item_id, "count": mini(count, maximum), "uid": uid}
''')
        raw = replace_once(raw, '''		var moved := mini(left, maximum)
		slots[empty] = {"id": item_id, "count": moved, "uid": _new_uid()}
		left -= moved
''', '''		var moved := mini(left, maximum)
		var uid := _new_uid()
		if uid <= 0:
			break
		slots[empty] = {"id": item_id, "count": moved, "uid": uid}
		left -= moved
''')
        raw = replace_once(raw, '''	if slot < 0 or slot >= SLOT_COUNT or slots[slot].is_empty() or target_inventory == null:
		return false
	var dst := target_inventory.first_empty_slot()
''', '''	if (slot < 0 or slot >= SLOT_COUNT or slots[slot].is_empty() or target_inventory == null
			or target_inventory == self):
		return false
	var battle = _uid_battle()
	# A preserved UID cannot cross allocation domains or overwrite an alias.
	if battle == null or not is_same(battle, target_inventory._uid_battle()):
		return false
	var source_uid = slots[slot].get("uid")
	if (typeof(source_uid) != TYPE_INT or source_uid <= 0 or source_uid >= battle.next_item_uid
			or target_inventory.find_uid(source_uid) >= 0):
		return false
	var dst := target_inventory.first_empty_slot()
''')
        raw = replace_once(raw, '''func restore(data: Dictionary) -> void:
	_reset_slots()
	var saved: Array = data.get("slots", [])
''', '''func restore(data: Dictionary) -> bool:
	# Trusted same-Battle respawn snapshots only. Full RunSession loading uses the
	# strict Unit adapter and installs the validated Battle counter separately.
	var battle = _uid_battle()
	var saved_v = data.get("slots")
	if battle == null or not (saved_v is Array) or saved_v.size() != SLOT_COUNT:
		return false
	var seen := {}
	for item in saved_v:
		if not (item is Dictionary):
			return false
		if item.is_empty():
			continue
		var uid = item.get("uid")
		if typeof(uid) != TYPE_INT or uid <= 0 or uid >= battle.next_item_uid or seen.has(uid):
			return false
		seen[uid] = true
	_reset_slots()
	var saved: Array = saved_v
''')
        raw = replace_once(raw, '''	_uid_seq = maxi(int(data.get("uid_seq", 0)), _uid_seq)
	_notify_changed()
''', '''	_uid_seq = maxi(int(data.get("uid_seq", 0)), _uid_seq)
	_notify_changed()
	return true
''')
    return raw


def main():
    rows, patches = [], []
    for path, source_sha in SOURCES.items():
        before = (ROOT / path).read_bytes()
        after = candidate(path, before)
        # Source line endings (Battle is mixed) remain exact in candidate bytes.
        patches.extend(difflib.unified_diff(before.decode().splitlines(True),
                       after.decode().splitlines(True), 'a/' + path, 'b/' + path))
        rows.append({'path': path, 'before_bytes': len(before), 'before_sha256': source_sha,
                     'candidate_bytes': len(after), 'candidate_sha256': hashlib.sha256(after).hexdigest()})
    (HERE / 'candidate.patch').write_bytes(''.join(patches).encode())
    (HERE / 'source_changes.json').write_bytes((json.dumps(rows, indent=2) + '\n').encode())
    print(json.dumps(rows, indent=2))


if __name__ == '__main__':
    main()
