from pathlib import Path
import ast
import difflib
import hashlib
import json

ROOT = Path(r'D:/AI项目/水浒/开发工程')
OUT = Path(__file__).resolve().parent

def sha(data):
    return hashlib.sha256(data).hexdigest()

def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f'Expected one exact anchor: {old[:100]!r}, got {text.count(old)}')
    return text.replace(old, new, 1)

sources = [
    'scripts/run_scenery_state.gd', 'scripts/run_map_state.gd',
    'scripts/campaign_scenery.gd', 'scripts/liangshan_scenery.gd',
    'scripts/campaign_environment.gd', 'scripts/campaign_height.gd',
    'scripts/liangshan_height.gd', 'scripts/game_map.gd',
    'scripts/levels/level3_zhujiazhuang_rts.gd', 'scripts/level_base.gd',
    'scripts/liangshan_stockade.gd', 'scripts/campaign_flag_overlay.gd',
    'scripts/campaign_environment_art.gd', 'scripts/campaign_art.gd',
    'scripts/world_shadow.gd', 'scripts/steam_run_policy.gd',
    'scripts/run_state_value_codec.gd', 'scripts/liangshan_coast.gdshader',
]
manifest = {'status': 'CANDIDATE_NOT_ENGINE_PARSED_OR_WORLD_ACCEPTED', 'source_root': str(ROOT), 'sources': []}
for rel in sources:
    data = (ROOT / rel).read_bytes()
    dest = OUT / 'source_snapshot' / (rel + '.txt')
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.read_bytes() != data:
        raise ValueError(f'Historical source snapshot changed: {rel}')
    dest.write_bytes(data)
    manifest['sources'].append({'path': rel, 'bytes': len(data), 'sha256': sha(data), 'snapshot': dest.relative_to(OUT).as_posix()})

base = (ROOT / sources[0]).read_text(encoding='utf-8')
s = base
s = replace_once(s, '## Standard Liangshan scenery only.', '## CANDIDATE: standard Liangshan plus an explicitly trusted Level3-only factory.')
s = replace_once(s, '## are applied. CampaignScenery has additional story objects and is not routed\n## through the standard factory.', '## are applied. The campaign branch keeps a separate schema, strict Level3\n## context and a retained disabled activation plan; it is not world acceptance.')
s = replace_once(s, 'const Scenery := preload("res://scripts/liangshan_scenery.gd")', '''const Scenery := preload("res://scripts/liangshan_scenery.gd")
const CampaignScenery := preload("res://scripts/campaign_scenery.gd")
const Level3 := preload("res://scripts/levels/level3_zhujiazhuang_rts.gd")
const BattleScript := preload("res://scripts/battle.gd")
const CAMPAIGN_CONTEXT := {"mode": "campaign", "level_id": "level3", "waves": 0}
const CAMPAIGN_SCHEMA := "level3_scenery_state_v1"
const CAMPAIGN_KINDS := ["campaign_scenery", "story_sign", "ground_overlay", "sprite", "stockade", "flag", "art"]
const CAMPAIGN_META := ["campaign_object", "campaign_environment_state", "campaign_environment_fallback_key"]
const LEVEL3_WALLS := [[Vector2(20, 0), Vector2(20, 16)], [Vector2(20, 20), Vector2(20, 26)], [Vector2(20, 30), Vector2(20, 55)]]
const NAV_NAMES := ["astar", "astar_guan", "astar_water", "astar_static", "astar_static_guan"]''')
s = replace_once(s, '\t"scenery": [],', '\t"scenery": [], "campaign_scenery": ["_style"], "story_sign": ["size", "label"], "ground_overlay": ["size"],')
s = replace_once(s, 'const RUNTIME_FIELDS := {"scenery": ["_visibility_tick"],', 'const RUNTIME_FIELDS := {"scenery": ["_visibility_tick"], "campaign_scenery": ["_visibility_tick"], "story_sign": [], "ground_overlay": [],')
s = replace_once(s, 'const TEX_FIELDS := {"scenery": [],', 'const TEX_FIELDS := {"scenery": [], "campaign_scenery": [], "story_sign": [], "ground_overlay": ["tex"],')
s = replace_once(s, 'var _content_version: String = ""', '''var _content_version: String = ""
var _trusted_context: Dictionary = {}
var _campaign_owner: GameMap = null
var _campaign_visual: Node2D = null
var _campaign_activation: Dictionary = {}
var _campaign_record: Dictionary = {}
var _campaign_order: Array = []
var _campaign_activated := false''')
s = replace_once(s, 'func _init(content_version: String) -> void:', 'func _init(content_version: String, trusted_context: Dictionary = {}) -> void:')
s = replace_once(s, '\t\t_content_version = content_version\n', '\t\t_content_version = content_version\n\t_trusted_context = trusted_context.duplicate(true)\n')
s = replace_once(s, '\tif game_map.sample_scenery == null:', '''\tvar campaign: bool = _campaign_enabled()
\tif campaign:
\t\tvar context_check: Dictionary = _campaign_map(game_map)
\t\tif not context_check.ok: return context_check
\t\tif game_map.sample_scenery == null: return _fail("CAMPAIGN_SCENERY_REQUIRED")
\tif game_map.sample_scenery == null:''')
s = replace_once(s, '\tif game_map.sample_scenery.get_script() != Scenery:\n\t\treturn _fail("STANDARD_SCENERY_REQUIRED")', '''\tif game_map.sample_scenery.get_script() != (CampaignScenery if campaign else Scenery):
\t\treturn _fail("CAMPAIGN_SCENERY_REQUIRED" if campaign else "STANDARD_SCENERY_REQUIRED")
\tif campaign:
\t\tvar ownership: Dictionary = _campaign_arrays(game_map.sample_scenery, game_map)
\t\tif not ownership.ok: return ownership''')
s = replace_once(s, '\tvar snapshot := {"schema": "scenery_state_v2", "content_version": _content_version, "kind": "liangshan", "nodes": records,', '\tvar snapshot := {"schema": CAMPAIGN_SCHEMA if campaign else "scenery_state_v2", "content_version": _content_version, "kind": "campaign_level3" if campaign else "liangshan", "nodes": records,')
s = replace_once(s, '\t\t"material": parameters.value, "reed": reed.value}\n\tvar checked:', '\t\t"material": parameters.value, "reed": reed.value}\n\tif campaign: snapshot["context"] = _trusted_context.duplicate(true)\n\tvar checked:')
s = replace_once(s, '\tif typeof(snapshot) != TYPE_DICTIONARY or snapshot.get("schema") != "scenery_state_v2":', '\tvar campaign: bool = _campaign_enabled()\n\tif typeof(snapshot) != TYPE_DICTIONARY or snapshot.get("schema") != (CAMPAIGN_SCHEMA if campaign else "scenery_state_v2"):')
s = replace_once(s, '\tif _fields(snapshot, ["schema", "content_version", "kind"]) and snapshot.kind == "none": return {"ok": true}\n\tif not _fields(snapshot, ["schema", "content_version", "kind", "nodes", "material", "reed"]) or snapshot.kind != "liangshan":', '''\tif not campaign and _fields(snapshot, ["schema", "content_version", "kind"]) and snapshot.kind == "none": return {"ok": true}
\tvar envelope: Array = ["schema", "content_version", "kind", "nodes", "material", "reed"]
\tif campaign: envelope.append("context")
\tif campaign and snapshot.get("context") != _trusted_context: return _fail("CAMPAIGN_CONTEXT_MISMATCH")
\tif not _fields(snapshot, envelope) or snapshot.kind != ("campaign_level3" if campaign else "liangshan"):''')
s = replace_once(s, '\t\tif i == 0 and record.kind != "scenery": return _fail("SCENERY_ROOT")', '''\t\tif campaign and record.kind not in CAMPAIGN_KINDS: return _fail("CAMPAIGN_NODE_KIND", str(i))
\t\tif not campaign and record.kind in ["campaign_scenery", "story_sign", "ground_overlay"]: return _fail("CAMPAIGN_CONTEXT_REQUIRED")
\t\tif i == 0 and record.kind != ("campaign_scenery" if campaign else "scenery"): return _fail("SCENERY_ROOT")
\t\tif campaign and i > 0 and record.parent != 0: return _fail("CAMPAIGN_DIRECT_CHILD_REQUIRED", str(i))''')
s = replace_once(s, 'typeof(key) != TYPE_STRING or key not in NODE_META', 'typeof(key) != TYPE_STRING or not _meta_allowed(String(key))')
s = replace_once(s, '\tif snapshot.kind == "none": return {"ok": true, "complete": true}', '''\tif snapshot.kind == "none": return {"ok": true, "complete": true}
\tvar campaign: bool = _campaign_enabled()
\tif campaign:
\t\tif _campaign_owner != null: return _fail("CAMPAIGN_ADAPTER_ALREADY_USED")
\t\tvar context_check: Dictionary = _campaign_map(game_map)
\t\tif not context_check.ok: return context_check''')
s = replace_once(s, '\tvar visual := Scenery.new()', '''\tvar prior_gameplay: Dictionary = {}
\tif campaign:
\t\tprior_gameplay = _campaign_gameplay_guard(game_map)
\t\tif not prior_gameplay.ok: return prior_gameplay
\tvar visual: Node2D = CampaignScenery.new() if campaign else Scenery.new()''')
s = replace_once(s, '\tvisual.setup(game_map)\n', '''\tvisual.setup(game_map)
\tif campaign:
\t\tif _campaign_gameplay_guard(game_map) != prior_gameplay:
\t\t\treturn _discard(game_map, visual, "CAMPAIGN_FACTORY_CHANGED_GAMEPLAY")
\t\tvar ownership: Dictionary = _campaign_arrays(visual, game_map)
\t\tif not ownership.ok: return _discard(game_map, visual, ownership.code)
\t\t# Source signs gain this derived height on their first scenery process.
\t\t# It changes only metadata/CanvasItem placement, not logical position.
\t\tfor child: Node in visual.get_children(): game_map.sync_render_position(child)
''')
s = replace_once(s, '\t\t\tor saved.textures != rebuilt.textures:', '\t\t\tor saved.textures != rebuilt.textures or (campaign and saved.metadata != rebuilt.metadata):')
s = replace_once(s, '\t\tfor key in RUNTIME_FIELDS[saved.kind]: node.set(key, saved.runtime[key])', '''\t\tfor key in RUNTIME_FIELDS[saved.kind]: node.set(key, saved.runtime[key])
\t\tif campaign:
\t\t\t_campaign_activation[node] = saved.runtime.duplicate(true)
\t\t\tnode.process_mode = Node.PROCESS_MODE_DISABLED
\t\t\tnode.set_block_signals(true)''')
s = replace_once(s, '\t_restore_reed(visual, snapshot.reed)\n\treturn', '''\t_restore_reed(visual, snapshot.reed)
\tif campaign:
\t\tif _campaign_gameplay_guard(game_map) != prior_gameplay:
\t\t\treturn _discard(game_map, visual, "CAMPAIGN_RESTORE_CHANGED_GAMEPLAY")
\t\t_campaign_owner = game_map; _campaign_visual = visual
\t\t_campaign_record = snapshot.duplicate(true); _campaign_order = nodes.duplicate()
\t\treturn {"ok": true, "complete": false, "complete_world": false,
\t\t\t"restored_nodes": nodes.size(), "factory": "fixed_level3_visual_only",
\t\t\t"requires_activation": true, "adapter": self}
\treturn''')
s = replace_once(s, '\tif kind.is_empty(): return _fail("SCENERY_NODE_UNSUPPORTED")', '''\tif kind.is_empty(): return _fail("SCENERY_NODE_UNSUPPORTED")
\tif _campaign_enabled():
\t\tvar boundary: Dictionary = _campaign_node_boundary(node, kind)
\t\tif not boundary.ok: return boundary''')
s = replace_once(s, '\tfor key in RUNTIME_FIELDS[kind]: runtime[key] = node.get(key)', '\tfor key in RUNTIME_FIELDS[kind]: runtime[key] = node.get(key)\n\tif _campaign_activation.has(node): runtime.process_mode = _campaign_activation[node].process_mode')
s = replace_once(s, 'if String(key) not in NODE_META:', 'if not _meta_allowed(String(key)):')
s = replace_once(s, 'func _kind(node: Node2D) -> String:\n', '''func _kind(node: Node2D) -> String:
\tif _campaign_enabled():
\t\tif node.get_script() == CampaignScenery: return "campaign_scenery"
\t\tif node.get_script() == CampaignScenery.StorySign: return "story_sign"
\t\tif node.get_script() == CampaignScenery.CampaignGroundOverlay: return "ground_overlay"
\t\tif node is Scenery.ScenerySprite and node.get_script() != Scenery.ScenerySprite: return ""
''')
s = replace_once(s, '\tmatch kind:\n\t\t"entrance":', '''\tmatch kind:
\t\t"campaign_scenery":
\t\t\tif value._style != "level3": return false
\t\t"story_sign":
\t\t\ttexts = ["label"]; numbers = ["size"]
\t\t\tif value.label not in ["李家庄", "扈家庄", "祝家庄"]: return false
\t\t"ground_overlay": numbers = ["size"]
\t\t"entrance":''')
s = replace_once(s, '\tgame_map.material = null\n\treturn', '\tgame_map.material = null\n\t_campaign_activation.clear(); _campaign_record.clear(); _campaign_order.clear()\n\t_campaign_owner = null; _campaign_visual = null\n\treturn')
s = replace_once(s, '\tgame_map.remove_child(visual)\n\tvisual.free()', '\tif visual.get_parent() != null: visual.get_parent().remove_child(visual)\n\tvisual.free()')
s = s.replace('\tvar campaign: bool = _campaign_enabled()\n', '\tvar campaign: bool = _campaign_enabled()\n\tif not _trusted_context.is_empty() and not campaign: return _fail("TRUSTED_CAMPAIGN_CONTEXT_UNSUPPORTED")\n')
s = replace_once(s, '\t"res://scripts/campaign_art_event.gd", "res://scripts/liangshan_coast.gdshader", "res://scripts/liangshan_layout.gd"]', '\t"res://scripts/campaign_art_event.gd", "res://scripts/liangshan_coast.gdshader", "res://scripts/liangshan_layout.gd",\n\t"res://scripts/campaign_scenery.gd", "res://scripts/campaign_environment.gd", "res://scripts/campaign_environment_art.gd",\n\t"res://scripts/campaign_height.gd", "res://scripts/campaign_art.gd", "res://scripts/levels/level3_zhujiazhuang_rts.gd"]')

s += '''

## Campaign support is selected only by the installed caller's explicit context.
## Invalid/other contexts do not cause a snapshot to select a campaign factory.
func _campaign_enabled() -> bool:
\treturn _fields(_trusted_context, ["mode", "level_id", "waves"]) and _trusted_context == CAMPAIGN_CONTEXT and typeof(_trusted_context.waves) == TYPE_INT

func _meta_allowed(key: String) -> bool:
\treturn key in NODE_META or (_campaign_enabled() and key in CAMPAIGN_META)

func _campaign_map(game_map: GameMap) -> Dictionary:
\tif not _campaign_enabled() or not is_instance_valid(game_map) or game_map.get_script() != preload("res://scripts/game_map.gd"): return _fail("CAMPAIGN_CONTEXT_REQUIRED")
\tif game_map.environment_style != "level3" or game_map.w != 64 or game_map.h != 56 or game_map.get_meta("campaign_wall_segments", null) != LEVEL3_WALLS: return _fail("LEVEL3_MAP_IDENTITY")
\tvar world: Node = game_map.get_parent()
\tvar battle: Node = null if world == null else world.get_parent()
\tif battle == null or battle.get_script() != BattleScript or battle.get("map") != game_map or not is_instance_valid(battle.get("level")) or battle.get("level").get_script() != Level3 or battle.get("level").id() != "level3": return _fail("LEVEL3_BATTLE_IDENTITY")
\treturn {"ok": true}

func _campaign_arrays(visual: Node2D, game_map: GameMap) -> Dictionary:
\tif visual.get_script() != CampaignScenery or visual._map != game_map or visual._battle != game_map.get_parent().get_parent() or visual._style != "level3": return _fail("CAMPAIGN_SCENERY_BINDINGS")
\tif visual._entrance != null or not visual._guard_posts.is_empty() or visual._lantern_texture != null or visual._cuiyun_light != null: return _fail("CAMPAIGN_UNSUPPORTED_OWNER_STATE")
\tvar walls: Array = []; var sprites: Array = []
\tfor child: Node in visual.get_children(true):
\t\tif not child is Node2D: return _fail("CAMPAIGN_CHILD_KIND")
\t\tif child.get_script() == Stockade: walls.append(child)
\t\telse: sprites.append(child)
\tif visual._walls != walls or visual._sprites != sprites: return _fail("CAMPAIGN_OWNER_ARRAYS")
\tvar trees: Array = []
\tfor child: Node in sprites:
\t\t# setup records grove sprites and non-excluded old/scoped props in _trees.
\t\tif child.get_script() != Scenery.ScenerySprite: continue
\t\tvar key: String = str(child.get_meta("campaign_object", ""))
\t\tif child.is_tree or (not key.is_empty() and key not in ["boat", "dock", "bridge", "banner", "rocks", "zhujiazhuang_hall"]): trees.append(child)
\tif visual._trees != trees: return _fail("CAMPAIGN_TREE_BINDINGS")
\treturn {"ok": true}

func _campaign_node_boundary(node: Node2D, kind: String) -> Dictionary:
\tif kind not in CAMPAIGN_KINDS or node.is_queued_for_deletion() or (kind != "campaign_scenery" and node.get_child_count(true) != 0): return _fail("CAMPAIGN_NODE_BOUNDARY")
\tif node.material != null or node.use_parent_material or node.top_level or node.light_mask != 1 or node.visibility_layer != 1 or node.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED or node.process_thread_group != Node.PROCESS_THREAD_GROUP_INHERIT: return _fail("CAMPAIGN_NODE_OVERRIDE")
\tif node.is_processing_input() or node.is_processing_shortcut_input() or node.is_processing_unhandled_input() or node.is_processing_unhandled_key_input() or node.process_physics_priority != 0 or not node.get_groups().is_empty(): return _fail("CAMPAIGN_NODE_INPUT")
\tif node.is_blocking_signals() and not _campaign_activation.has(node): return _fail("CAMPAIGN_SIGNAL_GATE")
\tfor info: Dictionary in node.get_signal_list():
\t\tfor row: Dictionary in node.get_signal_connection_list(info.name):
\t\t\tvar callback: Callable = row.callable
\t\t\tif info.name != &"child_order_changed" or not node.is_inside_tree() or row.flags != CONNECT_REFERENCE_COUNTED or callback.get_object() != node.get_viewport(): return _fail("CAMPAIGN_EXTRA_SIGNAL")
\t\t\tif callback.get_method() == &"Viewport::canvas_parent_mark_dirty" and callback.get_bound_arguments() == [node]: continue
\t\t\tif callback.get_method() == &"Viewport::gui_set_root_order_dirty" and callback.get_bound_arguments().is_empty(): continue
\t\t\treturn _fail("CAMPAIGN_EXTRA_SIGNAL")
\tvar language_count := 0
\tfor row: Dictionary in node.get_incoming_connections():
\t\tvar source_signal: Signal = row.signal
\t\tif kind != "story_sign" or source_signal.get_object() != Localize or source_signal.get_name() != &"language_changed" or row.callable != Callable(node, "_on_language_changed") or row.flags != 0: return _fail("CAMPAIGN_FOREIGN_INCOMING_SIGNAL")
\tfor row: Dictionary in Localize.language_changed.get_connections():
\t\tvar callback: Callable = row.callable
\t\tif callback.get_object() != node: continue
\t\tif kind != "story_sign" or callback != Callable(node, "_on_language_changed") or row.flags != 0 or not callback.get_bound_arguments().is_empty(): return _fail("CAMPAIGN_LANGUAGE_SIGNAL")
\t\tlanguage_count += 1
\tif language_count != (1 if kind == "story_sign" and node.is_inside_tree() else 0): return _fail("CAMPAIGN_LANGUAGE_SIGNAL_COUNT")
\treturn {"ok": true}

## Read-only in-memory guard; values never enter the save envelope. Keep material,
## its image caches and natural_surface_contract out: the existing display factory
## is explicitly allowed to rebuild those. A prior natural contract is checked by
## restore_into above. All gameplay map/nav/height/resources remain byte-exact.
func _campaign_gameplay_guard(game_map: GameMap) -> Dictionary:
\tvar result: Dictionary = {"ok": true, "map": {}, "nav": {}, "height": {}, "battle": {}, "meta": {}}
\tfor key: String in ["w", "h", "theme", "base_fill", "environment_style", "natural_surface_enabled", "_navigation_revision", "decor"]: result.map[key] = game_map.get(key)
\tresult.map["grid"] = game_map.grid.to_byte_array().hex_encode()
\tresult.map["base_solid"] = game_map._base_solid.hex_encode()
\tresult.map["block_count"] = game_map._block_count.to_byte_array().hex_encode()
\tfor key: StringName in game_map.get_meta_list():
\t\tif key != &"natural_surface_contract": result.meta[str(key)] = game_map.get_meta(key)
\tfor key: String in NAV_NAMES:
\t\tvar nav: AStarGrid2D = game_map.get(key)
\t\tif nav == null or nav.is_dirty() or nav.region != Rect2i(0, 0, game_map.w, game_map.h): return _fail("CAMPAIGN_NAV_NOT_STAGED", key)
\t\tvar values: Dictionary = {}; var solid := PackedByteArray(); var weights := PackedByteArray()
\t\tsolid.resize(game_map.w * game_map.h); weights.resize(game_map.w * game_map.h * 8)
\t\tfor field: String in ["region", "cell_size", "offset", "cell_shape", "default_compute_heuristic", "default_estimate_heuristic", "diagonal_mode", "jumping_enabled"]: values[field] = nav.get(field)
\t\tfor y: int in range(game_map.h):
\t\t\tfor x: int in range(game_map.w):
\t\t\t\tvar index: int = y * game_map.w + x; var cell := Vector2i(x, y)
\t\t\t\tsolid[index] = 1 if nav.is_point_solid(cell) else 0
\t\t\t\tweights.encode_double(index * 8, nav.get_point_weight_scale(cell))
\t\tvalues["solid"] = solid; values["weights"] = weights; result.nav[key] = values
\tif game_map.height_field != null:
\t\tvar height: RefCounted = game_map.height_field
\t\tif height.get_script() != preload("res://scripts/campaign_height.gd"): return _fail("CAMPAIGN_HEIGHT_SCRIPT")
\t\tresult.height = {"width": height.width, "height": height.height, "samples": height.samples.to_byte_array().hex_encode(), "style": height.style}
\t\tif height.texture != null:
\t\t\tvar image: Image = height.texture.get_image()
\t\t\tif image == null: return _fail("CAMPAIGN_HEIGHT_IMAGE")
\t\t\tresult.height["image"] = image.get_data().hex_encode()
\tvar battle: Node = game_map.get_parent().get_parent()
\tfor key: String in ["gold", "wood", "pop_cap", "current_age", "faction_res", "faction_gather_mult", "_tech_done", "next_entity_id", "next_item_uid", "kills", "_steam_valid_kills", "_defs", "_abilities", "_items"]: result.battle[key] = battle.get(key)
\tresult.battle["gameplay_rng"] = battle.capture_gameplay_rng()
\tvar ids: Array = []
\tfor unit: Variant in battle.get("units"): ids.append(unit.get_instance_id())
\tresult.battle["units"] = ids
\treturn result.duplicate(true)

## Call only while the final world transaction is still paused, immediately
## before its synchronous activation. The adapter must remain alive until then.
func activate_campaign() -> Dictionary:
\tif _campaign_activated or not is_instance_valid(_campaign_owner) or not _campaign_owner.is_inside_tree() or not _campaign_owner.get_tree().paused or Engine.is_in_physics_frame(): return _fail("CAMPAIGN_ACTIVATION_PHASE")
\tif not is_instance_valid(_campaign_visual) or _campaign_visual.get_parent() != _campaign_owner or _campaign_owner.sample_scenery != _campaign_visual: return _fail("CAMPAIGN_ACTIVATION_OWNER")
\tvar context_check: Dictionary = _campaign_map(_campaign_owner)
\tif not context_check.ok: return context_check
\tvar battle: Node = _campaign_owner.get_parent().get_parent()
\tif battle.process_mode != Node.PROCESS_MODE_DISABLED or not battle.is_blocking_signals(): return _fail("CAMPAIGN_ACTIVATION_OWNER_GATE")
\tvar nodes: Array = []; _walk_nodes(_campaign_visual, nodes)
\tif nodes != _campaign_order: return _fail("CAMPAIGN_ACTIVATION_TOPOLOGY")
\tfor node: Node in nodes:
\t\tif not node.is_node_ready() or not node.is_blocking_signals() or node.process_mode != Node.PROCESS_MODE_DISABLED: return _fail("CAMPAIGN_ACTIVATION_GATE")
\tvar captured: Dictionary = capture(_campaign_owner)
\tif not captured.ok: return captured
\tif captured.value != _campaign_record: return _fail("CAMPAIGN_PREPARED_STATE_CHANGED")
\tfor node: Node in nodes:
\t\tvar flags: Dictionary = _campaign_activation[node]
\t\tnode.set_process(flags.processing); node.set_physics_process(flags.physics_processing)
\t\tnode.process_priority = flags.process_priority; node.process_mode = flags.process_mode
\t\tnode.set_block_signals(false)
\t_campaign_activation.clear(); _campaign_activated = true
\treturn {"ok": true, "complete_world": false}

func dispose_campaign() -> void:
\t# Full world rollback still owns/frees the map and Battle. This helper only
\t# removes its own scenery and the StorySign global hooks before that happens.
\tif not _campaign_activated and is_instance_valid(_campaign_owner) and is_instance_valid(_campaign_visual) and _campaign_owner.sample_scenery == _campaign_visual:
\t\tfor node: Node in _campaign_order:
\t\t\tif is_instance_valid(node) and node.get_script() == CampaignScenery.StorySign and Localize.language_changed.is_connected(Callable(node, "_on_language_changed")): Localize.language_changed.disconnect(Callable(node, "_on_language_changed"))
\t\t_discard(_campaign_owner, _campaign_visual, "CAMPAIGN_DISPOSED")
\t_campaign_activation.clear(); _campaign_record.clear(); _campaign_order.clear()
\t_campaign_owner = null; _campaign_visual = null
'''

dest = OUT / 'candidate/scripts/run_scenery_state.gd'
dest.parent.mkdir(parents=True, exist_ok=True)
dest.write_text(s, encoding='utf-8', newline='\n')
(OUT / 'run_scenery_state.patch').write_text(''.join(difflib.unified_diff(base.splitlines(True), s.splitlines(True), 'a/scripts/run_scenery_state.gd', 'b/scripts/run_scenery_state.gd')), encoding='utf-8', newline='\n')

# Keep MapState glue as a separate precise proposal. Core must retain the returned
# adapter and activate it; this script deliberately does not patch Core or a gate.
map_base = (ROOT / 'scripts/run_map_state.gd').read_text(encoding='utf-8')
m = replace_once(map_base, 'var _content_version: String = ""', 'var _content_version: String = ""\nvar _trusted_context: Dictionary = {}')
m = replace_once(m, 'func _init(content_version: String) -> void:', 'func _init(content_version: String, trusted_context: Dictionary = {}) -> void:')
m = replace_once(m, '\t\t_content_version = content_version\n', '\t\t_content_version = content_version\n\t_trusted_context = trusted_context.duplicate(true)\n')
assert m.count('SceneryState.new(_content_version)') == 4
m = m.replace('SceneryState.new(_content_version)', 'SceneryState.new(_content_version, _trusted_context)')
m = replace_once(m, '\t\t"restored_scenery_nodes": display_result.get("restored_nodes", 0)}', '\t\t"restored_scenery_nodes": display_result.get("restored_nodes", 0),\n\t\t"display_requires_activation": display_result.get("requires_activation", false),\n\t\t"display_adapter": display_result.get("adapter")}')
m = replace_once(m, '\treturn {"ok": true, "code": "OK", "complete": true, "requirements": [], "footprints_already_registered": true,', '\treturn {"ok": true, "code": "OK", "complete": not display_result.get("requires_activation", false), "requirements": [], "footprints_already_registered": true,')
(OUT / 'candidate/scripts/run_map_state.gd').write_text(m, encoding='utf-8', newline='\n')
(OUT / 'run_map_state.patch').write_text(''.join(difflib.unified_diff(map_base.splitlines(True), m.splitlines(True), 'a/scripts/run_map_state.gd', 'b/scripts/run_map_state.gd')), encoding='utf-8', newline='\n')

checks = []
def check(label, value):
    checks.append({'name': label, 'passed': bool(value)})
    if not value:
        raise AssertionError(label)

check('exact 18 source snapshots captured', len(manifest['sources']) == 18)
check('campaign schema isolated from classic v2', 'level3_scenery_state_v1' in s and 'scenery_state_v2' in s)
check('optional context never comes from snapshot', '_trusted_context = trusted_context.duplicate(true)' in s and '_trusted_context = snapshot' not in s)
check('exact three current wall segments', 'Vector2(20, 55)' in s and 'LEVEL3_WALLS' in s)
check('exact Level3 production script', 'level3_zhujiazhuang_rts.gd' in s)
check('StorySign and actual ground overlay supported', 'CampaignScenery.StorySign' in s and 'CampaignScenery.CampaignGroundOverlay' in s)
check('all three raw signs enumerated', all(x in s for x in ['李家庄', '扈家庄', '祝家庄']))
check('metadata has all level3 scoped object keys', all(x in s for x in ['campaign_object', 'campaign_environment_state', 'campaign_environment_fallback_key']))
check('runtime marker identity not filesystem loader', 'load(snapshot' not in s and 'load(record' not in s)
check('same shared material and reed implementations', s[s.index('func _capture_material'):s.index('func _canvas_valid')] == base[base.index('func _capture_material'):base.index('func _canvas_valid')])
check('same shared canvas validation', s[s.index('func _canvas_valid'):s.index('func _fixed_values_valid')] == base[base.index('func _canvas_valid'):base.index('func _fixed_values_valid')])
check('exact setup call retained once', s.count('\tvisual.setup(game_map)') == 1)
check('pre post factory gameplay guard', s.count('_campaign_gameplay_guard(game_map)') == 3)
check('all five nav tables', all(x in s for x in ['astar_guan', 'astar_water', 'astar_static', 'astar_static_guan']))
check('height samples and image guarded', 'height.samples' in s and 'image.get_data()' in s)
check('battle resources guarded', all(x in s for x in ['"gold", "wood"', '"faction_res"', '"_defs", "_abilities", "_items"']))
check('no battle deployment or map rebuilding in new code', not any(x in s[s.index('func _campaign_enabled'): ] for x in ['.deploy(', '.paint_map(', '.bake(', '.build(', '.set_cell_t(', '.block_footprint(']))
check('new campaign restores stay gated', '"requires_activation": true, "adapter": self' in s)
check('invalid supplied context fails explicitly', s.count('TRUSTED_CAMPAIGN_CONTEXT_UNSUPPORTED') == 3)
check('pending readback masks only intentional mode gate', 'runtime.process_mode = _campaign_activation[node].process_mode' in s and 'runtime = _campaign_activation[node].duplicate' not in s)
check('mutable packed gameplay arrays guard uses owned bytes', all(x in s for x in ['grid.to_byte_array().hex_encode()', 'height.samples.to_byte_array().hex_encode()', '_block_count.to_byte_array().hex_encode()']))
check('campaign post mount topology checked', 'nodes != _campaign_order' in s)
check('activation retains disabled whole-world owner', 'CAMPAIGN_ACTIVATION_OWNER_GATE' in s)
check('campaign post mount whole record compared', 'captured.value != _campaign_record' in s)
check('StorySign exact callback counted', 'CAMPAIGN_LANGUAGE_SIGNAL_COUNT' in s)
check('foreign incoming callbacks rejected', 'CAMPAIGN_FOREIGN_INCOMING_SIGNAL' in s)
check('gameplay RNG observed without draws', 'result.battle["gameplay_rng"] = battle.capture_gameplay_rng()' in s)
check('rollback removes StorySign globals', 'Localize.language_changed.disconnect(Callable(node, "_on_language_changed"))' in s)
check('MapState passes caller context to four routes', m.count('SceneryState.new(_content_version, _trusted_context)') == 4)
check('MapState exports retained activation adapter', '"display_adapter": display_result.get("adapter")' in m)
check('MapState pending display not complete', '"complete": not display_result.get("requires_activation", false)' in m)
check('MapState gameplay guard unchanged', m[m.index('\t# Audit the factory'):m.index('\t# setup regenerates')] == map_base[map_base.index('\t# Audit the factory'):map_base.index('\t# setup regenerates')])
check('source bytes still unchanged', all(sha((ROOT / row['path']).read_bytes()) == row['sha256'] for row in manifest['sources']))
check('Python builder compiles without execution', ast.parse(Path(__file__).read_text(encoding='utf-8')) is not None)
manifest['candidates'] = []
for path in [dest, OUT / 'candidate/scripts/run_map_state.gd', OUT / 'run_scenery_state.patch', OUT / 'run_map_state.patch']:
    data = path.read_bytes()
    manifest['candidates'].append({'path': path.relative_to(OUT).as_posix(), 'bytes': len(data), 'sha256': sha(data)})
(OUT / 'source_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
(OUT / 'static_review.json').write_text(json.dumps({'status': 'STATIC_CANDIDATE_ONLY', 'engine_parsed': False, 'godot_run': False, 'complete_world': False, 'source_unchanged': True, 'checks': checks}, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
(OUT / '.gdignore').write_text('', encoding='utf-8')
print(json.dumps({'static_checks': len(checks), 'source_files': len(manifest['sources']), 'candidates': manifest['candidates'], 'engine_parsed': False}, ensure_ascii=False, indent=2))
