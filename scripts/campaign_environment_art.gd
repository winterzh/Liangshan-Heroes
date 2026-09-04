class_name CampaignEnvironmentArt
extends RefCounted
## Frozen, level-scoped resolver for Web ChatGPT campaign environment art.
## The source PNGs are intentionally absent until browser generation and intake pass.
## Never register these routes in ArtDB: every object/overlay/flag lookup must include
## the active campaign level, and a missing or out-of-scope resource returns null.

const FROZEN_MANIFEST_SHA256 := "162e74544989ce4b89e32db6d1562e10962a1d58fc1c3d39e30c83abdb9430cf"
const OBJECT_ROUTES: Dictionary = {
	"cuiyun_tower": {
		"levels": [
			"level8"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level8/cuiyun_tower_default.png",
			"signal": "res://assets/campaign/environment/level8/cuiyun_tower_signal.png"
		}
	},
	"daming_shop_house": {
		"levels": [
			"level8"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level8/shop_house.png"
		}
	},
	"dock_head_t": {
		"levels": [
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level5/dock_head_t.png"
		}
	},
	"dock_straight": {
		"levels": [
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level5/dock_straight.png"
		}
	},
	"heyang_wine_sign": {
		"levels": [
			"level7"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level7/heyang_wine_sign_blank.png"
		}
	},
	"huangnigang_dry_verge": {
		"levels": [
			"level1"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level1/huangnigang_dry_verge.png"
		}
	},
	"huangnigang_pine_double": {
		"levels": [
			"level1"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level1/huangnigang_pine_double.png"
		}
	},
	"huangnigang_pine_old": {
		"levels": [
			"level1"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level1/huangnigang_pine_old.png"
		}
	},
	"huangnigang_pine_young_lean": {
		"levels": [
			"level1"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level1/huangnigang_pine_young_lean.png"
		}
	},
	"huangnigang_seven_pudao": {
		"levels": [
			"level1"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level1/huangnigang_seven_pudao.png"
		}
	},
	"jujube_cart_01": {
		"levels": [
			"level1"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level1/jujube_cart_01.png"
		}
	},
	"jujube_cart_02": {
		"levels": [
			"level1"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level1/jujube_cart_02.png"
		}
	},
	"jujube_cart_03": {
		"levels": [
			"level1"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level1/jujube_cart_03.png"
		}
	},
	"jujube_cart_04": {
		"levels": [
			"level1"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level1/jujube_cart_04.png"
		}
	},
	"jujube_cart_05": {
		"levels": [
			"level1"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level1/jujube_cart_05.png"
		}
	},
	"jujube_cart_06": {
		"levels": [
			"level1"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level1/jujube_cart_06.png"
		}
	},
	"jujube_cart_07": {
		"levels": [
			"level1"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level1/jujube_cart_07.png"
		}
	},
	"jujube_load": {
		"levels": [
			"level1"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level1/jujube_load.png"
		}
	},
	"kuaihuolin_main_tavern": {
		"levels": [
			"level7"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level7/main_tavern.png"
		}
	},
	"lantern_stall": {
		"levels": [
			"level8"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level8/lantern_stall.png"
		}
	},
	"main_gate": {
		"levels": [
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level5/main_gate.png"
		}
	},
	"reeds_bent": {
		"levels": [
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level5/reeds_bent.png"
		}
	},
	"reeds_seeded": {
		"levels": [
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level5/reeds_seeded.png"
		}
	},
	"reeds_short": {
		"levels": [
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level5/reeds_short.png"
		}
	},
	"reeds_tall": {
		"levels": [
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level5/reeds_tall.png"
		}
	},
	"roadside_tavern_a": {
		"levels": [
			"level7"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level7/roadside_tavern_a.png"
		}
	},
	"roadside_tavern_b": {
		"levels": [
			"level7"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level7/roadside_tavern_b.png"
		}
	},
	"roadside_tavern_c": {
		"levels": [
			"level7"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level7/roadside_tavern_c.png"
		}
	},
	"roadside_tavern_d": {
		"levels": [
			"level7"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level7/roadside_tavern_d.png"
		}
	},
	"stockade_segment": {
		"levels": [
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level5/stockade_segment.png"
		}
	},
	"tree_broad": {
		"levels": [
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level5/tree_broad.png"
		}
	},
	"tree_young": {
		"levels": [
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level5/tree_young.png"
		}
	},
	"tribute_load": {
		"levels": [
			"level1"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level1/tribute_load.png"
		}
	},
	"watchtower": {
		"levels": [
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level5/watchtower.png"
		}
	},
	"willow_old": {
		"levels": [
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level5/willow_old.png"
		}
	},
	"wine_bowls": {
		"levels": [
			"level1"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level1/wine_bowls_scoop.png"
		}
	},
	"wine_buckets": {
		"levels": [
			"level1"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level1/wine_buckets.png"
		}
	},
	"zhongyi_hall": {
		"levels": [
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level5/zhongyi_hall.png"
		}
	},
	"zhujiazhuang_hall": {
		"levels": [
			"level3"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level3/zhujiazhuang_hall.png"
		}
	},
	"zhujiazhuang_main_gate": {
		"levels": [
			"level3"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level3/zhujiazhuang_main_gate.png"
		}
	}
}
const OVERLAY_ROUTES: Dictionary = {
	"dry_grass_leaves": {
		"levels": [
			"level1",
			"level3",
			"level4",
			"level7",
			"level8"
		],
		"paths": {
			"default": "res://assets/campaign/environment/shared/overlays/dry_grass_leaves.png"
		}
	},
	"field_edge_bank": {
		"levels": [
			"level3"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level3/field_edge_bank.png"
		}
	},
	"field_edge_ditch": {
		"levels": [
			"level3"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level3/field_edge_ditch.png"
		}
	},
	"field_edge_stubble": {
		"levels": [
			"level3"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level3/field_edge_stubble.png"
		}
	},
	"field_edge_willow": {
		"levels": [
			"level3"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level3/field_edge_willow.png"
		}
	},
	"flattened_reeds": {
		"levels": [
			"level2",
			"level4",
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/shared/overlays/flattened_reeds.png"
		}
	},
	"gravel_clods": {
		"levels": [
			"level1",
			"level3",
			"level4",
			"level6",
			"level7",
			"level8"
		],
		"paths": {
			"default": "res://assets/campaign/environment/shared/overlays/gravel_clods.png"
		}
	},
	"low_aquatic_plants": {
		"levels": [
			"level2",
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/shared/overlays/low_aquatic_plants.png"
		}
	},
	"mud_spots_wet_marks": {
		"levels": [
			"level2",
			"level4",
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/shared/overlays/mud_spots_wet_marks.png"
		}
	},
	"old_brick_fragments": {
		"levels": [
			"level2",
			"level8"
		],
		"paths": {
			"default": "res://assets/campaign/environment/shared/overlays/old_brick_fragments.png"
		}
	},
	"pine_needles_leaves": {
		"levels": [
			"level1",
			"level6"
		],
		"paths": {
			"default": "res://assets/campaign/environment/shared/overlays/pine_needles_leaves.png"
		}
	},
	"pole_wheel_marks": {
		"levels": [
			"level1",
			"level2",
			"level7",
			"level8"
		],
		"paths": {
			"default": "res://assets/campaign/environment/shared/overlays/pole_wheel_marks.png"
		}
	},
	"roots_moss": {
		"levels": [
			"level3",
			"level5",
			"level6"
		],
		"paths": {
			"default": "res://assets/campaign/environment/shared/overlays/roots_moss.png"
		}
	},
	"rounded_stones": {
		"levels": [
			"level1",
			"level4",
			"level6"
		],
		"paths": {
			"default": "res://assets/campaign/environment/shared/overlays/rounded_stones.png"
		}
	},
	"scattered_footprints": {
		"levels": [
			"level1",
			"level2",
			"level3",
			"level4",
			"level5",
			"level6",
			"level7",
			"level8"
		],
		"paths": {
			"default": "res://assets/campaign/environment/shared/overlays/scattered_footprints.png"
		}
	},
	"shallow_cart_ruts": {
		"levels": [
			"level1",
			"level4",
			"level6",
			"level7"
		],
		"paths": {
			"default": "res://assets/campaign/environment/shared/overlays/shallow_cart_ruts.png"
		}
	},
	"sparse_wet_grass": {
		"levels": [
			"level2",
			"level4",
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/shared/overlays/sparse_wet_grass.png"
		}
	},
	"trampled_mud": {
		"levels": [
			"level2",
			"level3",
			"level4",
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/shared/overlays/trampled_mud.png"
		}
	},
	"twigs_bark": {
		"levels": [
			"level3",
			"level5",
			"level6",
			"level7"
		],
		"paths": {
			"default": "res://assets/campaign/environment/shared/overlays/twigs_bark.png"
		}
	},
	"weathered_slabs": {
		"levels": [
			"level2",
			"level5",
			"level7",
			"level8"
		],
		"paths": {
			"default": "res://assets/campaign/environment/shared/overlays/weathered_slabs.png"
		}
	}
}
const STATIC_FLAG_ROUTES: Dictionary = {
	"liangshan_hilltop_standard": {
		"levels": [
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level5/liangshan_hilltop_standard_blank.png"
		}
	},
	"zhongyi_hall_standard_east": {
		"levels": [
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level5/zhongyi_hall_standard_east_blank.png"
		}
	},
	"zhongyi_hall_standard_west": {
		"levels": [
			"level5"
		],
		"paths": {
			"default": "res://assets/campaign/environment/level5/zhongyi_hall_standard_west_blank.png"
		}
	}
}
const SURFACE_ROUTES: Dictionary = {
	"surface_compacted_stone": {"levels":["level2","level5","level7","level8"],
		"path":"res://assets/campaign/environment/shared/surfaces/surface_compacted_stone.png"},
	"surface_dry_earth": {"levels":["level1","level4","level6"],
		"path":"res://assets/campaign/environment/shared/surfaces/surface_dry_earth.png"},
	"surface_field": {"levels":["level3","level8"],
		"path":"res://assets/campaign/environment/shared/surfaces/surface_field.png"},
	"surface_forest_earth": {"levels":["level1","level3","level5","level6","level7"],
		"path":"res://assets/campaign/environment/shared/surfaces/surface_forest_earth.png"},
	"surface_wet_bank": {"levels":["level2","level4","level5"],
		"path":"res://assets/campaign/environment/shared/surfaces/surface_wet_bank.png"}
}

## Source-SHA-bound visible bounds for the accepted Level 5 candidate PNGs.
## The candidate files keep the intake tool's transparent padding byte for byte;
## consumers use these bounds only to align/scale the whole texture at runtime.
## No crop, mask, pixel clearing, mirroring, or stitched sampling occurs here.
const VISUAL_CALIBRATIONS: Dictionary = {
	"object": {
		"reeds_short": {"level_id":"level5", "source_sha256":"6549dfec74e9336a60a4e0290f60d72f9516c7bf4ee04710fefe674ce2a1b9ed", "visible_bbox_xywh":[115,145,282,222]},
		"reeds_tall": {"level_id":"level5", "source_sha256":"2ac247db101fbdf1912266fcc4c88aa4d03a36fd33b64e6d7928d43fd660c4e3", "visible_bbox_xywh":[129,105,256,301]},
		"reeds_bent": {"level_id":"level5", "source_sha256":"a76a1c59dd647defd49e66ea31f2822439375c4765a0ea65dd5696ffab4116e1", "visible_bbox_xywh":[95,139,319,231]},
		"reeds_seeded": {"level_id":"level5", "source_sha256":"b0bfd2b8e9f8c176acf83918ca8183de15627da8a624b40c8a9d98f96e97bc46", "visible_bbox_xywh":[121,104,273,299]},
		"willow_old": {"level_id":"level5", "source_sha256":"71625a8e05c0e6f1f8dbd4b375dafa977a4ea0179cc73eac1acb0eb585f06324", "visible_bbox_xywh":[120,107,272,294]},
		"tree_broad": {"level_id":"level5", "source_sha256":"4fbfb8c75628b443debe7f7b789d1b735b15e217a471febbefd6420d543a5c6a", "visible_bbox_xywh":[115,105,287,303]},
		"tree_young": {"level_id":"level5", "source_sha256":"9b5985c16184cf574702e5c9b8bd74d193f39ddbc80f1d6e8d7f389ede6a9f9f", "visible_bbox_xywh":[166,119,183,280]},
		"dock_straight": {"level_id":"level5", "source_sha256":"633cba86c77ac76e9cfd023d816939d5ec2b691e256c2aa917a1a9c01d9889d8", "visible_bbox_xywh":[132,148,249,217]},
		"dock_head_t": {"level_id":"level5", "source_sha256":"8d327ee3cdcceb71fca6ded2b2b27755b9905cfc7da14d64b80308bdb691624f", "visible_bbox_xywh":[159,175,193,163]},
		"watchtower": {"level_id":"level5", "source_sha256":"23ab85096e6d15a9a55ace23960f053a660ca5fe0e43a6b93d682e354d2782c4", "visible_bbox_xywh":[200,152,111,208]},
		"stockade_segment": {"level_id":"level5", "source_sha256":"e1f807ef74b32a7bd16bc14705a1436938b6942da34018f96294d11a834a0c44", "visible_bbox_xywh":[167,161,177,186]},
		"main_gate": {"level_id":"level5", "source_sha256":"de94c246d3a0729bd8991c2b6236a6b4bc6de1d32c7531fd29dcf09ae7b2c997", "visible_bbox_xywh":[153,156,203,199]},
		"zhongyi_hall": {"level_id":"level5", "source_sha256":"ec1bc1c6a1a4802eac49893994d7c8213db916eb03a27da33afef334c6adc608", "visible_bbox_xywh":[129,143,257,229]},
	},
	"static_flag": {
		"zhongyi_hall_standard_west": {"level_id":"level5", "source_sha256":"22e4f07042e6f3d21c23ad01b24051c2828fb07c8024ba026d4c115adf21f1bc", "visible_bbox_xywh":[176,141,159,226]},
		"zhongyi_hall_standard_east": {"level_id":"level5", "source_sha256":"5cdadd67978d96b13d5fab3022126716969272b89d526e7e94f59b19bbfa2347", "visible_bbox_xywh":[171,141,170,228]},
		"liangshan_hilltop_standard": {"level_id":"level5", "source_sha256":"d7e2f02fb7feaf54c714c06b325745a9670a491eb5c381c5341e99c575b24d9b", "visible_bbox_xywh":[170,131,167,247]},
	},
}
const VISUAL_CALIBRATION_CANVAS_SIZE := Vector2(512.0,512.0)

## Only the accepted Level 5 source files below have measured blank surfaces.
## Every other rect remains null until its own source and runtime captures pass.
const TEXT_RECTS: Dictionary = {
	"level3_zhujiazhuang_gate_plaque": null,
	"level3_zhujiazhuang_hall_plaque": null,
	"level5_hall_plaque": [0.400390625,0.48828125,0.126953125,0.046875],
	"level5_main_gate_plaque": null,
	"level7_heyang_wine_sign": null,
	"level7_main_tavern_plaque": null,
	"level8_shop_house_plaque": null,
	"liangshan_hilltop_standard": [0.41015625,0.359375,0.060546875,0.16796875],
	"zhongyi_hall_standard_west": [0.41796875,0.361328125,0.05859375,0.166015625],
	"zhongyi_hall_standard_east": [0.404296875,0.361328125,0.05859375,0.166015625]
}
const TEXT_RECT_SOURCE_SHA256: Dictionary = {
	"level3_zhujiazhuang_gate_plaque": "",
	"level3_zhujiazhuang_hall_plaque": "",
	"level5_hall_plaque": "ec1bc1c6a1a4802eac49893994d7c8213db916eb03a27da33afef334c6adc608",
	"level5_main_gate_plaque": "",
	"level7_heyang_wine_sign": "",
	"level7_main_tavern_plaque": "",
	"level8_shop_house_plaque": "",
	"liangshan_hilltop_standard": "d7e2f02fb7feaf54c714c06b325745a9670a491eb5c381c5341e99c575b24d9b",
	"zhongyi_hall_standard_west": "22e4f07042e6f3d21c23ad01b24051c2828fb07c8024ba026d4c115adf21f1bc",
	"zhongyi_hall_standard_east": "5cdadd67978d96b13d5fab3022126716969272b89d526e7e94f59b19bbfa2347"
}


static func _route_path(table: Dictionary, active_level_id: String, route_key: String,
		state: String = "default") -> String:
	if active_level_id.is_empty() or route_key.is_empty() or not table.has(route_key):
		return ""
	var record: Dictionary = table[route_key]
	var levels: Array = record.get("levels", [])
	if active_level_id not in levels:
		return ""
	var paths: Dictionary = record.get("paths", {})
	return String(paths.get(state, ""))


static func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path, "Texture2D") as Texture2D


static func object(active_level_id: String, route_key: String,
		state: String = "default") -> Texture2D:
	return _load_texture(_route_path(OBJECT_ROUTES, active_level_id, route_key, state))


static func overlay(active_level_id: String, route_key: String) -> Texture2D:
	return _load_texture(_route_path(OVERLAY_ROUTES, active_level_id, route_key))


static func static_flag(active_level_id: String, route_key: String) -> Texture2D:
	return _load_texture(_route_path(STATIC_FLAG_ROUTES, active_level_id, route_key))


## The five surface paths are production targets, not ArtDB aliases. GameMap/coast
## materials may ask for one and keep their current atlas texture when this returns null.
static func surface(active_level_id: String, surface_key: String) -> Texture2D:
	return _load_texture(surface_path(active_level_id,surface_key))


static func surface_path(active_level_id: String, surface_key: String) -> String:
	if active_level_id.is_empty() or not SURFACE_ROUTES.has(surface_key): return ""
	var record: Dictionary = SURFACE_ROUTES[surface_key]
	if active_level_id not in record.get("levels",[]): return ""
	return String(record.get("path",""))


## Read-only helpers are used by intake contracts; they never bypass level scope.
static func route_path(resolver: String, active_level_id: String, route_key: String,
		state: String = "default") -> String:
	match resolver:
		"object": return _route_path(OBJECT_ROUTES, active_level_id, route_key, state)
		"overlay": return _route_path(OVERLAY_ROUTES, active_level_id, route_key, state)
		"static_flag": return _route_path(STATIC_FLAG_ROUTES, active_level_id, route_key, state)
	return ""


static func registered_levels(resolver: String, route_key: String) -> Array:
	var table: Dictionary = {}
	match resolver:
		"object": table = OBJECT_ROUTES
		"overlay": table = OVERLAY_ROUTES
		"static_flag": table = STATIC_FLAG_ROUTES
		_: return []
	if not table.has(route_key):
		return []
	var record: Dictionary = table[route_key]
	return record.get("levels", []).duplicate()


static func text_rect(surface_id: String, accepted_source_sha256: String) -> Variant:
	# A rect measured on one source must never be reused after that PNG changes.
	if accepted_source_sha256.is_empty() \
			or String(TEXT_RECT_SOURCE_SHA256.get(surface_id,"")) != accepted_source_sha256:
		return null
	return TEXT_RECTS.get(surface_id)


## Runtime text is enabled only for the exact accepted source file whose SHA was
## used to measure the rectangle. Missing files and stale measurements fail closed.
static func calibrated_text_rect(resolver: String, active_level_id: String,
		route_key: String, state: String, surface_id: String) -> Variant:
	var path := route_path(resolver,active_level_id,route_key,state)
	if path.is_empty() or not ResourceLoader.exists(path): return null
	var disk_path := ProjectSettings.globalize_path(path)
	var source_sha := FileAccess.get_sha256(disk_path)
	if source_sha.is_empty(): return null
	return text_rect(surface_id,source_sha)


## Returns alignment metadata only when the active scoped route and exact disk
## bytes still match the accepted candidate. The PNG itself is always rendered
## whole; visible_bbox_xywh is never used as a crop or mask.
static func calibrated_visual_metrics(resolver: String, active_level_id: String,
		route_key: String, state := "default") -> Dictionary:
	var path := route_path(resolver,active_level_id,route_key,state)
	if path.is_empty() or not ResourceLoader.exists(path): return {}
	var resolver_table: Dictionary = VISUAL_CALIBRATIONS.get(resolver,{})
	if not resolver_table.has(route_key): return {}
	var record: Dictionary = resolver_table[route_key]
	if String(record.get("level_id",""))!=active_level_id: return {}
	var source_sha := FileAccess.get_sha256(ProjectSettings.globalize_path(path))
	if source_sha.is_empty() or source_sha!=String(record.get("source_sha256","")): return {}
	var bbox: Array = record.get("visible_bbox_xywh",[])
	if bbox.size()!=4 or float(bbox[2])<=0.0 or float(bbox[3])<=0.0: return {}
	var result := record.duplicate(true)
	result["foot"]=(float(bbox[1])+float(bbox[3]))/VISUAL_CALIBRATION_CANVAS_SIZE.y
	result["normalized_visible_bbox"]=[float(bbox[0])/VISUAL_CALIBRATION_CANVAS_SIZE.x,
		float(bbox[1])/VISUAL_CALIBRATION_CANVAS_SIZE.y,float(bbox[2])/VISUAL_CALIBRATION_CANVAS_SIZE.x,
		float(bbox[3])/VISUAL_CALIBRATION_CANVAS_SIZE.y]
	return result
