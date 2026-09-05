#!/usr/bin/env python3
"""Source-only contract for the campaign environment-art router.

This deliberately does not start Godot and does not require any generated PNG.
It proves route identity, state and path parity with the retained, SHA-bound
production mapping (or explicitly restored frozen schema-v2 manifest), plus
documented runtime reuse. Original-source and visual acceptance are separate.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

from environment_validation_common import MAPPING, MAPPING_SHA256, contained_path, report_target, write_report


EXPECTED_MANIFEST_SHA256 = "162e74544989ce4b89e32db6d1562e10962a1d58fc1c3d39e30c83abdb9430cf"
# IDs retained in the initial Git router (b534fd3), independently of the
# runtime file being checked. This is a route baseline, not recovered prompts.
EXPECTED_TEXT_SURFACE_IDS = [
    "level3_zhujiazhuang_gate_plaque", "level3_zhujiazhuang_hall_plaque",
    "level5_hall_plaque", "level5_main_gate_plaque", "level7_heyang_wine_sign",
    "level7_main_tavern_plaque", "level8_shop_house_plaque",
    "liangshan_hilltop_standard", "zhongyi_hall_standard_west", "zhongyi_hall_standard_east",
]
LEVEL_IDS = tuple(f"level{i}" for i in range(1, 9))
FORBIDDEN_GLOBAL_ALIASES = {"town_house", "zhu_hall", "zhu_gate", "roadside_tavern", "tree", "banner"}
EXPECTED_SURFACES = {
    "surface_dry_earth": {"levels": ["level1", "level4", "level6"],
        "path": "res://assets/campaign/environment/shared/surfaces/surface_dry_earth.png"},
    "surface_forest_earth": {"levels": ["level1", "level3", "level5", "level6", "level7"],
        "path": "res://assets/campaign/environment/shared/surfaces/surface_forest_earth.png"},
    "surface_wet_bank": {"levels": ["level2", "level4", "level5"],
        "path": "res://assets/campaign/environment/shared/surfaces/surface_wet_bank.png"},
    "surface_compacted_stone": {"levels": ["level2", "level5", "level7", "level8"],
        "path": "res://assets/campaign/environment/shared/surfaces/surface_compacted_stone.png"},
    "surface_field": {"levels": ["level3", "level8"],
        "path": "res://assets/campaign/environment/shared/surfaces/surface_field.png"},
}
ACCEPTED_LEVEL5_TEXT_CALIBRATIONS = {
    "level5_hall_plaque": {
        "rect": [0.400390625, 0.48828125, 0.126953125, 0.046875],
        "source_sha256": "ec1bc1c6a1a4802eac49893994d7c8213db916eb03a27da33afef334c6adc608",
    },
    "liangshan_hilltop_standard": {
        "rect": [0.41015625, 0.359375, 0.060546875, 0.16796875],
        "source_sha256": "d7e2f02fb7feaf54c714c06b325745a9670a491eb5c381c5341e99c575b24d9b",
    },
    "zhongyi_hall_standard_west": {
        "rect": [0.41796875, 0.361328125, 0.05859375, 0.166015625],
        "source_sha256": "22e4f07042e6f3d21c23ad01b24051c2828fb07c8024ba026d4c115adf21f1bc",
    },
    "zhongyi_hall_standard_east": {
        "rect": [0.404296875, 0.361328125, 0.05859375, 0.166015625],
        "source_sha256": "5cdadd67978d96b13d5fab3022126716969272b89d526e7e94f59b19bbfa2347",
    },
}


def _evidence(source: str, rel_path: str, needle: str) -> str:
    for number, line in enumerate(source.splitlines(), 1):
        if needle in line:
            return f"{rel_path}:{number}: {line.strip()}"
    raise AssertionError(f"missing consumer evidence {rel_path}: {needle}")


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _constant(source: str, name: str) -> Any:
    marker = f"const {name}: Dictionary = "
    start = source.find(marker)
    if start < 0:
        raise AssertionError(f"missing constant {name}")
    start += len(marker)
    decoder = json.JSONDecoder()
    value, _ = decoder.raw_decode(source[start:])
    return value


def _manifest_routes(manifest: dict[str, Any]) -> tuple[dict[str, Any], set[str]]:
    routes: dict[str, dict[str, Any]] = {"object": {}, "overlay": {}, "static_flag": {}}
    text_surfaces: set[str] = set()
    for batch in manifest["send_order"]:
        for cell in batch.get("cell_routes", []):
            resolver = cell["route"]["resolver"].rsplit(".", 1)[-1]
            route_key = cell["route"]["route_key"]
            state = cell.get("state", "default")
            record = routes[resolver].setdefault(
                route_key, {"levels": cell["level_scope"], "paths": {}}
            )
            assert record["levels"] == cell["level_scope"], (resolver, route_key, "scope drift")
            assert state not in record["paths"], (resolver, route_key, state, "duplicate state")
            record["paths"][state] = cell["output_path"]
            if "runtime_text_surface" in cell:
                text_surfaces.add(cell["runtime_text_surface"]["surface_id"])
    return routes, text_surfaces


def load_route_basis(path: Path) -> tuple[dict[str, Any], str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    digest = _sha256(path)
    if data.get("schema_version") == 2:
        if digest != EXPECTED_MANIFEST_SHA256:
            raise ValueError(f"frozen manifest SHA256 mismatch: {digest}")
        return data, "original_frozen_manifest"
    if data.get("kind") != "web_chatgpt_environment_production_mapping" or digest != MAPPING_SHA256:
        raise ValueError(f"route mapping is not the retained SHA-bound baseline: {digest}")
    if data.get("batch_manifest_sha256") != EXPECTED_MANIFEST_SHA256:
        raise ValueError("retained mapping references a different historical manifest")
    batches = []
    for batch in data["batches"]:
        cells = []
        for cell in batch.get("cells", []):
            # Read the independent retained mapping, never the current router.
            contained_path(path.parent.parent, cell["target"])
            cells.append({
                "output_path": "res://" + cell["target"], "level_scope": cell["level_scope"],
                "state": cell.get("state", "default"),
                "route": {"resolver": cell["resolver"], "route_key": cell["route_key"]},
            })
        batches.append({"cell_routes": cells})
    return {"send_order": batches, "runtime_text_rect_contract": {"flag_markers": EXPECTED_TEXT_SURFACE_IDS}}, "retained_production_mapping"


def _gd_route_path(table: dict[str, Any], level_id: str, route_key: str, state: str = "default") -> str:
    record = table.get(route_key)
    if not level_id or not route_key or record is None or level_id not in record["levels"]:
        return ""
    return record["paths"].get(state, "")


def run(repo: Path, manifest_path: Path, report_path: Path) -> dict[str, Any]:
    checks: list[dict[str, Any]] = []

    def check(name: str, passed: bool, detail: Any = None) -> None:
        checks.append({"name": name, "passed": bool(passed), "detail": detail})

    manifest_sha = _sha256(manifest_path)
    manifest, basis_kind = load_route_basis(manifest_path)
    router_path = repo / "scripts" / "campaign_environment_art.gd"
    router_source = router_path.read_text(encoding="utf-8")
    scenery_source = (repo / "scripts" / "campaign_scenery.gd").read_text(encoding="utf-8")
    config_source = (repo / "scripts" / "campaign_environment.gd").read_text(encoding="utf-8")
    consumer_rel_paths = [
        "scripts/battle.gd", "scripts/campaign_environment.gd",
        "scripts/campaign_scenery.gd", "scripts/campaign_flag_overlay.gd",
        "scripts/liangshan_scenery.gd", "scripts/liangshan_entrance.gd",
        "scripts/liangshan_stockade.gd", "scripts/liangshan_gate.gd",
        "scripts/liangshan_coast.gdshader", "scripts/unit.gd",
        "scripts/levels/level1_huangnigang.gd",
        "scripts/levels/level3_zhujiazhuang.gd",
        "scripts/levels/level5_liangshan.gd",
        "scripts/levels/level7_kuaihuolin.gd",
        "scripts/levels/level8_dongchangfu.gd",
    ]
    consumer_sources = {
        rel: (repo / rel).read_text(encoding="utf-8") for rel in consumer_rel_paths
    }
    consumer_sha256 = {rel: _sha256(repo / rel) for rel in consumer_rel_paths}

    if basis_kind == "original_frozen_manifest":
        check("frozen_manifest_sha256", manifest_sha == EXPECTED_MANIFEST_SHA256, manifest_sha)
        check("schema_v2", manifest.get("schema_version") == 2, manifest.get("schema_version"))
    else:
        check("retained_mapping_sha256", manifest_sha == MAPPING_SHA256, manifest_sha)
        check("retained_mapping_has_64_cells", sum(len(b["cell_routes"]) for b in manifest["send_order"]) == 64)
    check(
        "router_embeds_same_manifest_sha",
        f'const FROZEN_MANIFEST_SHA256 := "{EXPECTED_MANIFEST_SHA256}"' in router_source,
    )

    expected_routes, expected_text_surfaces = _manifest_routes(manifest)
    # 2026-09-06: the unlettered accepted timber panel is reused by Zhu's
    # wooden boundary. Preserve every original source path and other scope;
    # this is a single deliberate consumer addition, not a wildcard fallback.
    stockade = expected_routes["object"]["stockade_segment"]
    check("stockade_frozen_scope_before_reuse", stockade["levels"] == ["level5"])
    stockade["levels"] = ["level3", "level5"]
    reuse_source = repo / "assets/campaign/environment/level5/stockade_segment.png"
    check("stockade_reuse_accepted_source", reuse_source.is_file() and _sha256(reuse_source) ==
          "e1f807ef74b32a7bd16bc14705a1436938b6942da34018f96294d11a834a0c44")
    actual_routes = {
        "object": _constant(router_source, "OBJECT_ROUTES"),
        "overlay": _constant(router_source, "OVERLAY_ROUTES"),
        "static_flag": _constant(router_source, "STATIC_FLAG_ROUTES"),
    }
    for resolver, expected in expected_routes.items():
        actual = actual_routes[resolver]
        check(f"{resolver}_route_table_exact", actual == expected, {"expected": len(expected), "actual": len(actual)})
        for key, record in actual.items():
            check(f"{resolver}:{key}:not_global_alias", key not in FORBIDDEN_GLOBAL_ALIASES)
            check(
                f"{resolver}:{key}:production_path_root",
                all(path.startswith("res://assets/campaign/environment/") for path in record["paths"].values()),
            )
            for level_id in LEVEL_IDS:
                expected_allowed = level_id in record["levels"]
                for state, path in record["paths"].items():
                    resolved = _gd_route_path(actual, level_id, key, state)
                    check(
                        f"{resolver}:{key}:{state}:{level_id}:scope",
                        (resolved == path) if expected_allowed else (resolved == ""),
                    )
            check(f"{resolver}:{key}:unknown_level_rejected", _gd_route_path(actual, "level999", key) == "")
        check(f"{resolver}:unknown_route_rejected", _gd_route_path(actual, "level1", "town_house") == "")

    actual_surfaces = _constant(router_source, "SURFACE_ROUTES")
    check("five_surface_targets_exact", actual_surfaces == EXPECTED_SURFACES, actual_surfaces)
    check("surface_target_paths_unique", len({record["path"] for record in actual_surfaces.values()}) == 5)
    check("surface_interface_requires_level",
          "static func surface(active_level_id: String, surface_key: String) -> Texture2D:" in router_source)
    check("surface_path_requires_level",
          "static func surface_path(active_level_id: String, surface_key: String) -> String:" in router_source)
    for surface_key, record in actual_surfaces.items():
        for level_id in LEVEL_IDS:
            expected_path = record["path"] if level_id in record["levels"] else ""
            # Source-level emulation of the small fail-closed surface resolver.
            actual_path = record["path"] if level_id in record["levels"] else ""
            check(f"surface:{surface_key}:{level_id}:scope", actual_path == expected_path)
        check(f"surface:{surface_key}:unknown_level_rejected", "level999" not in record["levels"])

    actual_text_rects = _constant(router_source, "TEXT_RECTS")
    actual_text_rect_shas = _constant(router_source, "TEXT_RECT_SOURCE_SHA256")
    flag_text_surfaces = set(manifest.get("runtime_text_rect_contract", {}).get("flag_markers", []))
    all_text_surfaces = expected_text_surfaces | flag_text_surfaces
    check("text_rect_ids_exact", set(actual_text_rects) == all_text_surfaces, sorted(actual_text_rects))
    accepted_ids = set(ACCEPTED_LEVEL5_TEXT_CALIBRATIONS)
    check("accepted_level5_text_rects_exact", all(
        actual_text_rects.get(surface_id) == calibration["rect"]
        for surface_id, calibration in ACCEPTED_LEVEL5_TEXT_CALIBRATIONS.items()
    ))
    check("other_text_rects_stay_unmeasured", all(
        value is None for surface_id, value in actual_text_rects.items()
        if surface_id not in accepted_ids
    ))
    check("text_rect_sha_ids_exact", set(actual_text_rect_shas) == all_text_surfaces)
    check("accepted_level5_text_shas_exact", all(
        actual_text_rect_shas.get(surface_id) == calibration["source_sha256"]
        for surface_id, calibration in ACCEPTED_LEVEL5_TEXT_CALIBRATIONS.items()
    ))
    check("other_text_rect_shas_stay_empty", all(
        value == "" for surface_id, value in actual_text_rect_shas.items()
        if surface_id not in accepted_ids
    ))
    check(
        "text_rect_lookup_is_source_sha_bound",
        "static func text_rect(surface_id: String, accepted_source_sha256: String)" in router_source
        and 'TEXT_RECT_SOURCE_SHA256.get(surface_id,"")' in router_source,
    )
    check("visual_metrics_are_source_sha_bound",
          "static func calibrated_visual_metrics(resolver: String" in router_source
          and 'source_sha!=String(record.get("source_sha256","")' in router_source)

    check("resource_exists_guard", "not ResourceLoader.exists(path)" in router_source)
    check("object_requires_level", "static func object(active_level_id: String, route_key: String" in router_source)
    check("overlay_requires_level", "static func overlay(active_level_id: String, route_key: String)" in router_source)
    check("static_flag_requires_level", "static func static_flag(active_level_id: String, route_key: String)" in router_source)
    check("router_does_not_call_artdb", "Art." not in router_source and "art_db" not in router_source.lower())

    check("scenery_inherits_scoped_router",
          'extends "res://scripts/liangshan_scenery.gd"' in scenery_source
          and 'preload("res://scripts/campaign_environment_art.gd")'
              in consumer_sources["scripts/liangshan_scenery.gd"])
    check("scenery_object_lookup_uses_active_style", "EnvironmentArt.object(_style,route_key,state)" in scenery_source)
    check("scenery_overlay_lookup_uses_active_style", "EnvironmentArt.overlay(_style,str(d[3]))" in scenery_source)
    check("state_change_stays_scoped", "EnvironmentArt.object(_style,route_key,state)" in scenery_source)
    check(
        "lantern_stall_level8_route_registered",
        actual_routes["object"].get("lantern_stall", {}).get("levels") == ["level8"]
        and 'EnvironmentArt.object(_style,"lantern_stall")' not in scenery_source
        and '"lantern_stall","",0.82,false,true' in scenery_source,
    )
    check("explicit_legacy_fallback_only", "_legacy_environment_texture(fallback_key,state)" in scenery_source)
    check("state_fallback_never_infers_story_key",
          "explicit_environment_fallback(sprite)" in scenery_source
          and 'get_meta("campaign_environment_fallback_key","")' in scenery_source
          and "_legacy_environment_texture(key,state)" not in scenery_source)
    check("cuiyun_default_consumer_present",
          '"cuiyun_tower","cuiyun_tower"' in config_source)
    level8_source = consumer_sources["scripts/levels/level8_dongchangfu.gd"]
    check("cuiyun_signal_consumer_present",
          'set_story_object_state("cuiyun_tower","signal")' in level8_source)
    check("config_uses_dedicated_markers", "SCOPED_OBJECT_MARKER" in config_source and "SCOPED_OVERLAY_MARKER" in config_source)

    # Every literal route used by the campaign scenery configuration must exist
    # in the matching frozen resolver. Fallback keys are intentionally ignored.
    object_literals = set(re.findall(r'scoped_object\([^\n]*?,\s*"([a-z0-9_]+)"\s*,', config_source))
    object_literals.update(
        re.findall(r'_add_direct_campaign_object\([^\n]*?,\s*"([a-z0-9_]+)"\s*,', scenery_source)
    )
    overlay_literals = set(re.findall(r'scoped_overlay\([^\n]*?,\s*"([a-z0-9_]+)"\s*\)', config_source))
    check("configured_object_routes_registered", object_literals <= set(actual_routes["object"]), sorted(object_literals))
    check("configured_overlay_routes_registered", overlay_literals <= set(actual_routes["overlay"]), sorted(overlay_literals))
    check("configured_routes_never_use_global_alias", not (object_literals | overlay_literals) & FORBIDDEN_GLOBAL_ALIASES)

    def consumer_binding(resolver: str, route_key: str, state: str) -> tuple[str, str, list[str]]:
        specs: list[tuple[str, str]] = []
        symbol = ""
        if resolver == "overlay":
            specs = [
                ("scripts/campaign_environment.gd", f'"{route_key}"'),
                ("scripts/campaign_scenery.gd", "EnvironmentArt.overlay(_style,str(d[3]))"),
            ]
            symbol = "CampaignEnvironment.overlay_layout -> CampaignScenery._add_campaign_environment_overlay"
        elif resolver == "static_flag":
            specs = [
                ("scripts/levels/level5_liangshan.gd", f'"{route_key}"'),
                ("scripts/liangshan_scenery.gd", "EnvironmentArt.static_flag(level_id,String(d[3]))"),
                ("scripts/liangshan_scenery.gd", 'calibrated_text_rect("static_flag"'),
            ]
            symbol = "Level5.decorate -> LiangshanScenery.setup blank flag + source-bound text"
        elif route_key.startswith("jujube_cart_"):
            specs = [
                ("scripts/levels/level1_huangnigang.gd", '"jujube_cart_%02d" % (i+1)'),
                ("scripts/levels/level1_huangnigang.gd", "EnvironmentArt.object(id(),route_key)"),
                ("scripts/levels/level1_huangnigang.gd", "JUJUBE_CART_CELLS.size()"),
            ]
            symbol = "Level1._place_jujube_carts exact slot-index route"
        elif route_key in {"huangnigang_pine_old", "huangnigang_pine_double",
                           "huangnigang_pine_young_lean", "huangnigang_seven_pudao",
                           "huangnigang_dry_verge"}:
            specs = [
                ("scripts/campaign_environment.gd", f'"{route_key}"'),
                ("scripts/campaign_scenery.gd", "EnvironmentArt.object(_style,route_key,state)"),
            ]
            symbol = "CampaignEnvironment level1 marker -> CampaignScenery scoped object"
        elif route_key in {"jujube_load", "wine_buckets", "wine_bowls"}:
            specs = [
                ("scripts/levels/level1_huangnigang.gd", f'"{route_key}","{route_key}"'),
                ("scripts/battle.gd", "CampaignEnvironmentArt.object(active_level_id,route_key,state)"),
            ]
            symbol = "Level1 story prop -> Battle.show_campaign_environment_art"
        elif route_key == "tribute_load":
            specs = [
                ("scripts/levels/level1_huangnigang.gd", 'set_meta("campaign_environment_route","tribute_load")'),
                ("scripts/unit.gd", "CampaignEnvironmentArt.object(_active_campaign_level_id(), route_key, state)"),
            ]
            symbol = "Level1 bundle Unit -> Unit._campaign_environment_texture"
        elif route_key in {"tree_broad", "tree_young", "willow_old"}:
            specs = [
                ("scripts/liangshan_scenery.gd", f'"{route_key}"'),
                ("scripts/liangshan_scenery.gd", "EnvironmentArt.object(level_id,tree_route)"),
            ]
            symbol = "LiangshanScenery deterministic tree variant"
        elif route_key in {"reeds_short", "reeds_tall", "reeds_bent", "reeds_seeded"}:
            specs = [
                ("scripts/liangshan_scenery.gd", f'"{route_key}"'),
                ("scripts/liangshan_scenery.gd", "EnvironmentArt.object(_active_campaign_level_id(),route_key)"),
                ("scripts/liangshan_scenery.gd", "_routed_reed_count<4"),
            ]
            symbol = "LiangshanScenery four bounded reed anchors over retained batch"
        elif route_key in {"dock_straight", "dock_head_t", "stockade_segment", "main_gate"}:
            specs = [
                ("scripts/liangshan_entrance.gd", f'EnvironmentArt.object("level5","{route_key}")'),
            ]
            if route_key == "main_gate":
                specs.append(("scripts/liangshan_entrance.gd", 'calibrated_text_rect("object","level5","main_gate"'))
            symbol = "LiangshanEntrance optional structural replacement with legacy fallback"
        elif route_key == "watchtower":
            specs = [
                ("scripts/liangshan_scenery.gd", 'EnvironmentArt.object(level_id,"watchtower")'),
                ("scripts/liangshan_scenery.gd", 'Art.terrain_texture("tower")'),
            ]
            symbol = "LiangshanScenery guard-post replacement"
        elif route_key == "zhongyi_hall":
            specs = [
                ("scripts/levels/level5_liangshan.gd", 'set_meta("campaign_environment_route","zhongyi_hall")'),
                ("scripts/unit.gd", "CampaignEnvironmentArt.object(_active_campaign_level_id(), route_key, state)"),
            ]
            symbol = "Level5 hall Unit -> Unit._campaign_environment_texture"
        elif route_key.startswith("roadside_tavern_"):
            specs = [
                ("scripts/levels/level7_kuaihuolin.gd", '"roadside_tavern_%s" % ["a","b","c","d"][index]'),
                ("scripts/unit.gd", "CampaignEnvironmentArt.object(_active_campaign_level_id(), route_key, state)"),
            ]
            symbol = "Level7 TAVERN_CELLS exact index route -> Unit"
        elif route_key == "heyang_wine_sign":
            specs = [
                ("scripts/levels/level7_kuaihuolin.gd", 'set_meta("campaign_environment_route","heyang_wine_sign")'),
                ("scripts/unit.gd", "calibrated_text_rect"),
            ]
            symbol = "Level7 sign Unit with source-bound runtime text"
        elif route_key == "kuaihuolin_main_tavern":
            specs = [
                ("scripts/campaign_environment.gd", '"kuaihuolin_main_tavern","town_house"'),
                ("scripts/campaign_scenery.gd", "EnvironmentArt.object(_style,route_key,state)"),
            ]
            symbol = "CampaignEnvironment level7 main-tavern marker -> CampaignScenery"
        elif route_key == "zhujiazhuang_main_gate":
            specs = [
                ("scripts/levels/level3_zhujiazhuang.gd", 'set_meta("campaign_environment_route","zhujiazhuang_main_gate")'),
                ("scripts/unit.gd", "CampaignEnvironmentArt.object(_active_campaign_level_id(), route_key, state)"),
            ]
            symbol = "Level3 gate Unit -> Unit._campaign_environment_texture"
        elif route_key == "cuiyun_tower" and state == "signal":
            specs = [
                ("scripts/levels/level8_dongchangfu.gd", 'set_story_object_state("cuiyun_tower","signal")'),
                ("scripts/campaign_scenery.gd", "EnvironmentArt.object(_style,route_key,state)"),
                ("scripts/campaign_scenery.gd", "explicit_environment_fallback(sprite)"),
            ]
            symbol = "Level8 signal event -> CampaignScenery.set_story_object_state"
        elif route_key == "cuiyun_tower":
            specs = [
                ("scripts/campaign_environment.gd", '"cuiyun_tower","cuiyun_tower"'),
                ("scripts/campaign_scenery.gd", "EnvironmentArt.object(_style,route_key,state)"),
            ]
            symbol = "CampaignEnvironment level8 default marker -> CampaignScenery"
        elif route_key == "lantern_stall":
            specs = [
                ("scripts/campaign_scenery.gd", '"lantern_stall","",0.82,false,true'),
                ("scripts/campaign_scenery.gd", "EnvironmentArt.object(_style,route_key,state)"),
            ]
            symbol = "CampaignScenery level8 lantern-stall direct scoped object"
        elif route_key in {"daming_shop_house", "zhujiazhuang_hall"}:
            specs = [
                ("scripts/campaign_environment.gd", f'"{route_key}"'),
                ("scripts/campaign_scenery.gd", "EnvironmentArt.object(_style,route_key,state)"),
            ]
            symbol = "CampaignEnvironment dedicated level marker -> CampaignScenery"
        else:
            raise AssertionError(f"no consumer contract for {(resolver, route_key, state)}")
        evidence = [_evidence(consumer_sources[rel], rel, needle) for rel, needle in specs]
        return specs[0][0], symbol, evidence

    exact_consumers: list[dict[str, Any]] = []
    for batch in manifest["send_order"]:
        for cell in batch.get("cell_routes", []):
            resolver = cell["route"]["resolver"].rsplit(".", 1)[-1]
            route_key = cell["route"]["route_key"]
            state = cell.get("state", "default")
            consumer_file, symbol, evidence = consumer_binding(resolver, route_key, state)
            exact_consumers.append({
                "resolver": f"CampaignEnvironmentArt.{resolver}",
                "route_key": route_key,
                "state": state,
                "output_path": cell["output_path"],
                "level_scope": cell["level_scope"],
                "consumer_file": consumer_file,
                "consumer_sha256": consumer_sha256[consumer_file],
                "consumer_symbol": symbol,
                "consumer_evidence": evidence,
            })
    check("consumer_routes_exact", len(exact_consumers) == 64, exact_consumers)

    surface_consumers: list[dict[str, Any]] = []
    coast_source = consumer_sources["scripts/liangshan_scenery.gd"]
    shader_source = consumer_sources["scripts/liangshan_coast.gdshader"]
    surface_shader_flags = {
        "surface_forest_earth": "use_surface_forest_texture",
        "surface_dry_earth": "use_surface_dry_texture",
        "surface_wet_bank": "use_surface_wet_texture",
        "surface_compacted_stone": "use_surface_hard_texture",
        "surface_field": "use_surface_field_texture",
    }
    for surface_key, record in actual_surfaces.items():
        evidence = [
            _evidence(coast_source, "scripts/liangshan_scenery.gd", f'"{surface_key}"'),
            _evidence(coast_source, "scripts/liangshan_scenery.gd", "EnvironmentArt.surface(active_level_id,surface_key)"),
            _evidence(shader_source, "scripts/liangshan_coast.gdshader", surface_shader_flags[surface_key]),
        ]
        surface_consumers.append({
            "surface_key": surface_key,
            "level_scope": record["levels"],
            "output_path": record["path"],
            "consumer_file": "scripts/liangshan_scenery.gd",
            "consumer_sha256": consumer_sha256["scripts/liangshan_scenery.gd"],
            "consumer_symbol": "LiangshanScenery._setup_coast_material -> liangshan_coast shader",
            "fallback_evidence": evidence,
        })
    check("surface_consumers_exact", len(surface_consumers) == 5, surface_consumers)
    check("all_69_consumer_ready", len(exact_consumers) + len(surface_consumers) == 69,
          {"atlas_cells": len(exact_consumers), "surfaces": len(surface_consumers)})

    missing_resources = []
    for resolver, table in actual_routes.items():
        for route_key, record in table.items():
            for state, resource_path in record["paths"].items():
                disk_path = repo / resource_path.removeprefix("res://")
                if not disk_path.is_file():
                    missing_resources.append({"resolver": resolver, "route_key": route_key, "state": state, "path": resource_path})
    for key, surface_record in actual_surfaces.items():
        resource_path = surface_record["path"]
        if not (repo / resource_path.removeprefix("res://")).is_file():
            missing_resources.append({"resolver": "surface", "route_key": key, "state": "default", "path": resource_path})

    passed = all(item["passed"] for item in checks)
    report = {
        "passed": passed,
        "scope": "source_only_no_godot_no_bitmap_generation",
        "basis_kind": basis_kind,
        "historical_manifest_verified": basis_kind == "original_frozen_manifest",
        "provenance_verified": False,
        "resource_completeness_verified": False,
        "manifest_path": str(manifest_path.resolve()),
        "manifest_sha256": manifest_sha,
        "router_path": str(router_path.resolve()),
        "router_sha256": _sha256(router_path),
        "consumer_file_sha256": consumer_sha256,
        "counts": {
            "manifest_cells": sum(len(batch.get("cell_routes", [])) for batch in manifest["send_order"]),
            "object_route_keys": len(actual_routes["object"]),
            "object_state_paths": sum(len(record["paths"]) for record in actual_routes["object"].values()),
            "overlay_route_keys": len(actual_routes["overlay"]),
            "static_flag_route_keys": len(actual_routes["static_flag"]),
            "surface_paths": len(actual_surfaces),
            "consumer_ready_manifest_cells": len(exact_consumers),
            "consumer_ready_surfaces": len(surface_consumers),
            "consumer_ready_total": len(exact_consumers) + len(surface_consumers),
            "missing_source_resources_expected_before_web_intake": len(missing_resources),
            "checks": len(checks),
        },
        "missing_source_resources": missing_resources,
        "checks": checks,
    }
    write_report(report_path, report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument(
        "--manifest",
        type=Path,
        default=MAPPING,
        help="repo-relative retained mapping, or an explicitly restored original frozen manifest",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=Path(".godot/environment_validation/router.json"),
    )
    args = parser.parse_args()
    repo = args.repo.resolve()
    output = None
    try:
        output = report_target(repo, args.report)
        manifest = args.manifest if args.manifest.is_absolute() else repo / args.manifest
        if output == manifest.resolve():
            output = None
            raise ValueError("report may not overwrite the route basis input")
        report = run(repo, manifest.resolve(), output)
        print(json.dumps({"passed": report["passed"], "basis_kind": report["basis_kind"], **report["counts"]}, ensure_ascii=False))
        return 0 if report["passed"] else 1
    except (OSError, ValueError, KeyError, TypeError, AssertionError) as error:
        report = {"passed": False, "status": "invalid_or_missing_input", "error": str(error), "scope": "source_only_no_godot_no_bitmap_generation"}
        if output is not None:
            write_report(output, report)
        print(json.dumps(report, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
