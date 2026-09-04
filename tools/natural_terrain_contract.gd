extends "res://tools/campaign_mode_performance_test.gd"
## 八关自然地表合同。只验证确定性、逻辑状态隔离、城市平地和人工硬边接线；
## 不把它当作人工视觉、完整战斗性能或真人试玩证据。
const LEVELS := ["level1","level2","level3","level4","level5","level6","level7","level8"]
const WEB_SURFACE_BINDINGS := {
	"surface_forest_earth":["use_surface_forest_texture",["level1","level3","level5","level6","level7"]],
	"surface_dry_earth":["use_surface_dry_texture",["level1","level4","level6"]],
	"surface_wet_bank":["use_surface_wet_texture",["level2","level4","level5"]],
	"surface_compacted_stone":["use_surface_hard_texture",["level2","level5","level7","level8"]],
	"surface_field":["use_surface_field_texture",["level3","level8"]],
}


func _logic_snapshot(b) -> Dictionary:
	var solids := PackedByteArray()
	var guan_solids := PackedByteArray()
	var water_solids := PackedByteArray()
	var weights := PackedFloat32Array()
	for y in range(b.map.h):
		for x in range(b.map.w):
			var c := Vector2i(x, y)
			solids.append(1 if b.map.astar.is_point_solid(c) else 0)
			guan_solids.append(1 if b.map.astar_guan.is_point_solid(c) else 0)
			water_solids.append(1 if b.map.astar_water.is_point_solid(c) else 0)
			weights.append(b.map.astar.get_point_weight_scale(c))
			weights.append(b.map.astar_guan.get_point_weight_scale(c))
	return {
		"grid": b.map.grid.to_byte_array().hex_encode().sha256_text(),
		"solid": solids.hex_encode().sha256_text(),
		"guan_solid": guan_solids.hex_encode().sha256_text(),
		"water_solid": water_solids.hex_encode().sha256_text(),
		"weights": weights.to_byte_array().hex_encode().sha256_text(),
		"height": b.map.height_field.samples.to_byte_array().hex_encode().sha256_text()
			if b.map.height_field != null else "flat",
	}


func _surface_snapshot(b) -> Dictionary:
	var generated: Dictionary = b.map.natural_surface_maps()
	var connected: Dictionary = b.map.get_meta("natural_surface_contract", {})
	return {
		"enabled": b.map.natural_surface_enabled,
		"class_counts": generated.class_counts,
		"protected_cells": generated.protected_cells,
		"weight_sha256": generated.weight_sha256,
		"land_sha256": generated.land_sha256,
		"blend_min_px": generated.blend_min_px,
		"blend_max_px": generated.blend_max_px,
		"warp_px": generated.warp_px,
		"seed": generated.seed,
		"connected": connected,
	}


func _authored_rules_snapshot(b) -> Dictionary:
	var result := {"roads":0,"protected_roads":0,"docks":0,"protected_docks":0,
		"walls":0,"protected_walls":0,"steps":0,"protected_steps":0,
		"hard_cells":0,"height_min":INF,"height_max":-INF}
	for y in range(b.map.h):
		for x in range(b.map.w):
			var terrain: int = b.map.t_at(x,y)
			var protected: bool = b.map.natural_hard_edge_cell(x,y)
			if terrain == b.map.T.ROAD:
				result.roads += 1
				if protected: result.protected_roads += 1
			if terrain == b.map.T.DOCK:
				result.docks += 1
				if protected: result.protected_docks += 1
			if b.map._is_authored_wall_base(x,y):
				result.walls += 1
				if protected: result.protected_walls += 1
			if b.map._is_authored_step_base(x,y):
				result.steps += 1
				if protected: result.protected_steps += 1
			if protected: result.hard_cells += 1
			var elevation: float = b.map.height_at(b.map.cell_to_world(Vector2i(x,y)))
			result.height_min = minf(result.height_min,elevation)
			result.height_max = maxf(result.height_max,elevation)
	return result


func _rules_pass(id: String,rules: Dictionary,b) -> bool:
	var flat := absf(float(rules.height_max)-float(rules.height_min))<0.001
	match id:
		"level1":
			return rules.roads>0 and rules.protected_roads==0 and rules.hard_cells==0 and rules.height_max>5.0
		"level2":
			return flat and rules.docks>0 and rules.protected_docks==rules.docks \
				and rules.steps>0 and rules.protected_steps==rules.steps and rules.roads>rules.protected_roads
		"level3":
			return rules.walls>0 and rules.protected_walls==rules.walls \
				and rules.roads>rules.protected_roads and rules.height_max>5.0
		"level4":
			return rules.roads>0 and rules.protected_roads==0 and rules.hard_cells==0 and rules.height_max>5.0
		"level5":
			return rules.docks>0 and rules.protected_docks==rules.docks and rules.height_max>5.0 \
				and b.map.natural_surface_class_at(16,30)!=b.map.SURFACE_WET
		"level6":
			return rules.roads>0 and rules.protected_roads==0 and rules.hard_cells==0 and rules.height_max>5.0
		"level7":
			return flat and rules.roads>0 and rules.protected_roads==0 and rules.hard_cells==0
		"level8":
			return flat and rules.walls>0 and rules.protected_walls==rules.walls \
				and rules.roads>rules.protected_roads
	return false


func _surface_sampling_pass(id: String, surface: Dictionary, material: ShaderMaterial) -> bool:
	var routes: Dictionary = surface.connected.get("routed_surfaces",{})
	if routes.size()!=WEB_SURFACE_BINDINGS.size() or material==null:
		return false
	for surface_key in WEB_SURFACE_BINDINGS:
		var binding: Array = WEB_SURFACE_BINDINGS[surface_key]
		var route: Dictionary = routes.get(surface_key,{})
		var allowed_path := String(route.get("allowed_path",""))
		var should_load: bool = id in binding[1] and not allowed_path.is_empty() \
			and FileAccess.file_exists(allowed_path)
		if bool(route.get("loaded",false))!=should_load:
			return false
		if bool(material.get_shader_parameter(binding[0]))!=should_load:
			return false
		if should_load:
			if route.get("sampling_mode","")!="map_clamped" or bool(route.get("repeat_enabled",true)):
				return false
		else:
			if route.get("sampling_mode","")!="atlas_tile_uv" or not bool(route.get("repeat_enabled",false)):
				return false
	return true


func _check_surface(id: String) -> Dictionary:
	OS.set_environment("CAMPAIGN_NATURAL_TERRAIN", "1")
	var b = await _start(id)
	var logic_on := _logic_snapshot(b)
	var surface := _surface_snapshot(b)
	var repeat := _surface_snapshot(b)
	var rules := _authored_rules_snapshot(b)
	check(b.map.natural_surface_enabled, id + " enables natural terrain")
	check(surface.class_counts.size() == b.map.SURFACE_CLASS_COUNT
		and surface.class_counts.reduce(func(total, count): return total + int(count), 0) == b.map.w * b.map.h,
		id + " assigns every logical cell to one of five visual materials")
	check(surface.weight_sha256 == repeat.weight_sha256 and surface.land_sha256 == repeat.land_sha256,
		id + " regenerates identical material and hard-edge masks")
	check(surface.connected.weight_sha256 == surface.weight_sha256
		and surface.connected.land_sha256 == surface.land_sha256,
		id + " shader receives the exact audited masks")
	check(surface.blend_min_px >= 12.0 and surface.blend_max_px <= 24.0
		and surface.blend_min_px < surface.blend_max_px,
		id + " natural transition width stays within 12-24 logical pixels")
	check(surface.warp_px > 0.0 and surface.warp_px < surface.blend_min_px,
		id + " low-frequency warp cannot move a boundary beyond its blend band")
	var material := b.map.material as ShaderMaterial
	check(material != null and bool(material.get_shader_parameter("natural_surface_enabled")),
		id + " uses the natural terrain shader path")
	check(_surface_sampling_pass(id,surface,material),
		id + " samples each routed Web surface once across the map and keeps missing routes on the repeating atlas")
	check(_rules_pass(id,rules,b), id + " keeps authored structures hard, ordinary terrain natural and intended height profile")
	await _dispose(b)

	OS.set_environment("CAMPAIGN_NATURAL_TERRAIN", "0")
	b = await _start(id)
	var logic_off := _logic_snapshot(b)
	var disabled_material := b.map.material as ShaderMaterial
	check(not b.map.natural_surface_enabled
		and disabled_material != null
		and not bool(disabled_material.get_shader_parameter("natural_surface_enabled")),
		id + " retains a one-run visual fallback switch")
	check(logic_on == logic_off,
		id + " visual toggle leaves grid, three movement profiles, weights and height field byte-identical")
	await _dispose(b)
	return {"level": id, "logic": logic_on, "surface": surface, "authored_rules": rules}


func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	OS.set_environment("CAMPAIGN_ENV_BASELINE", "0")
	OS.set_environment("LIANGSHAN_VISUAL_BASELINE", "0")
	var out := OS.get_environment("NATURAL_TERRAIN_OUT")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://qa/natural_terrain_20260902/contract")
	DirAccess.make_dir_recursive_absolute(out)
	var saved_before := _save_hash()
	var settings = root.get_node("Settings")
	settings.edge_scroll = false
	settings.auto_micro_level = 0
	settings.game_speed = 1.0
	AudioServer.set_bus_mute(0, true)
	report["scope"] = "all eight campaigns: deterministic render-only terrain masks, hard-edge whitelist, city flatness and logic isolation; no visual approval, combat performance or playtest claim"
	report["samples"] = []
	for id in LEVELS:
		report.samples.append(await _check_surface(id))
	OS.set_environment("CAMPAIGN_NATURAL_TERRAIN", "1")
	check(report.mode_checks.size() == 88, "all 88 per-level terrain assertions actually executed")
	check(_save_hash() == saved_before, "terrain contract leaves campaign progress bytes unchanged")
	report["expected_check_count"] = 90
	report["passed"] = failures.is_empty()
	report["failures"] = failures
	report["save_hash_before"] = saved_before
	report["save_hash_after"] = _save_hash()
	var file := FileAccess.open(out.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("[natural-terrain-result] ", JSON.stringify({"passed": failures.is_empty(),
		"checks": report.mode_checks.size(), "failures": failures, "output": out}))
	quit(0 if failures.is_empty() else 1)
