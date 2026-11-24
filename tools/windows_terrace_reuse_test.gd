extends SceneTree
## Graphical Windows fixture for terrace cache reuse, key changes, and eviction.
var _entrance_script: GDScript
var _map_script: GDScript
var _layout_script: GDScript
var _height_script: GDScript
var _batch_script: GDScript

var _results := {}
var _world: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _map(rts: bool) -> Node2D:
	var map: Node2D = _map_script.new()
	map.init_map(60, 60, "liangshan", _map_script.T.GRASS)
	map.set_meta("liangshan_rts_court", rts)
	_layout_script.paint(map)
	map.height_field = _height_script.new()
	map.height_field.build(map.w, map.h, map.grid)
	return map


func _entrance(map: Node2D) -> Node2D:
	var entrance: Node2D = _entrance_script.new()
	entrance._map = map
	entrance._bank_ridges = _layout_script.bank_ridges_for(map)
	entrance.process_mode = Node.PROCESS_MODE_DISABLED
	return entrance


func _capture(entrance: Node2D) -> String:
	_world.add_child(entrance)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var digest := image.get_data().hex_encode().sha256_text()
	_world.remove_child(entrance)
	return digest


func _rendered_pair(rts: bool) -> void:
	var map := _map(rts)
	var fresh := _entrance(map)
	var reference: RefCounted = _batch_script.new()
	fresh._draw_terrace(reference)
	reference.finish()
	fresh._terrace_draw_batch = reference
	var expected := await _capture(fresh)
	fresh.free()
	var old_map: WeakRef = weakref(map)
	map.free()
	map = _map(rts)
	var first := _entrance(map)
	var first_pixels := await _capture(first)
	var saved: RefCounted = first._terrace_draw_batch
	first.free()
	map.free()
	map = _map(rts)
	var second := _entrance(map)
	var second_pixels := await _capture(second)
	_results["rts" if rts else "traditional"] = {
		"same_pixels": first_pixels == expected and second_pixels == expected,
		"same_batch": (saved != null and is_same(saved, second._terrace_draw_batch)) if _batch_script.enabled()
			else saved == null and second._terrace_draw_batch == null,
		"fresh_map_released": old_map.get_ref() == null,
		"reference_valid": reference.valid and reference.summary().vertices > 1000,
		"rgba_sha256": expected,
	}
	second.free()
	map.free()


func _cache_boundaries() -> void:
	_entrance_script._recent_terraces.clear()
	var map := _map(true)
	var entrance := _entrance(map)
	var original := entrance._build_terrace_batch() as RefCounted
	var original_pixels := await _capture(entrance)
	var field: RefCounted = map.height_field
	var samples: PackedFloat32Array = field.samples
	var raised := samples.duplicate()
	for i in range(raised.size()):
		raised[i] += 8.0
	field.samples = raised
	var higher := _entrance(map)
	var higher_pixels := await _capture(higher)
	field.samples = samples
	var restored := entrance._build_terrace_batch() as RefCounted
	var rock := root.get_node("Art").terrain_texture("cliff") as AtlasTexture
	var region := rock.region
	rock.region.position.x += 1.0
	var new_uv := entrance._build_terrace_batch() as RefCounted
	rock.region = region
	var restored_uv := entrance._build_terrace_batch() as RefCounted
	var height_changed: bool = not is_same(original, higher._terrace_draw_batch) and original_pixels != higher_pixels
	_results["cache_key"] = {
		"height_change_rebuilds": height_changed,
		"restored_height_reuses": is_same(restored, original),
		"atlas_region_change_rebuilds": not is_same(new_uv, original),
		"restored_region_reuses": is_same(restored_uv, original),
	}
	# Keep one live owner while filling the cache with other terrain snapshots.
	for delta in [1.0, 2.0, 3.0]:
		var different := samples.duplicate()
		different[0] += delta
		field.samples = different
		entrance._build_terrace_batch()
	field.samples = samples
	var after_evict := entrance._build_terrace_batch() as RefCounted
	var after_pixels := await _capture(entrance)
	_results["lifetime"] = {
		"cache_is_bounded": _entrance_script._recent_terraces.size() == 3,
		"evicted_batch_rebuilt": not is_same(after_evict, original),
		"live_owner_still_draws": after_pixels == original_pixels and is_same(entrance._terrace_draw_batch, original),
	}
	higher.free()
	entrance.free()
	map.free()


func _run() -> void:
	_entrance_script = load("res://scripts/liangshan_entrance.gd")
	_map_script = load("res://scripts/game_map.gd")
	_layout_script = load("res://scripts/liangshan_layout.gd")
	_height_script = load("res://scripts/liangshan_height.gd")
	_batch_script = load("res://scripts/static_scenery_draw_batch.gd")
	for script in [_entrance_script, _map_script, _layout_script, _height_script, _batch_script]:
		if script == null or not script.can_instantiate():
			push_error("Terrace fixture requires imported project scripts")
			quit(2)
			return
	root.size = Vector2i(1280, 720)
	RenderingServer.set_default_clear_color(Color("252e3b"))
	_world = Node2D.new()
	var iso: Transform2D = _map_script.ISO
	iso.origin = Vector2(960, -650)
	_world.transform = iso
	root.add_child(_world)
	await _rendered_pair(true)
	await _rendered_pair(false)
	if _batch_script.enabled():
		await _cache_boundaries()
	var passed := true
	for row: Dictionary in _results.values():
		for value in row.values():
			if value is bool and not value:
				passed = false
	var file := FileAccess.open(OS.get_environment("LSH_TERRACE_REPORT"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "batch_enabled": _batch_script.enabled(), "checks": _results}, "  "))
	file.close()
	quit(0 if passed else 1)
