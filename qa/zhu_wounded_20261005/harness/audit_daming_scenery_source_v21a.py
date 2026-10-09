"""Engine-free source contracts for installed Daming; no runtime qualification."""
from pathlib import Path
import argparse
import hashlib
import json
import math
import re

ROOT = Path(__file__).resolve().parents[3]
PATHS = [
    "scripts/campaign.gd", "scripts/levels/level8_daming_rts.gd",
    "scripts/levels/level8_dongchangfu.gd", "scripts/campaign_environment.gd",
    "scripts/campaign_scenery.gd", "scripts/campaign_city_wall.gd",
    "scripts/campaign_passage.gd", "scripts/game_map.gd",
    "scripts/battle.gd", "scripts/run_campaign_level_state.gd",
    "scripts/run_scenery_state.gd",
]


def function(text, name):
    match = re.search(r"(?m)^(?:static )?func " + re.escape(name) + r"\(", text)
    if not match:
        raise ValueError("missing function: " + name)
    tail = text[match.start():]
    end = re.search(r"\n(?:static )?func ", tail)
    return tail[:end.start()] if end else tail


def audit(sources):
    checks = []

    def require(name, passed):
        checks.append({"name": name, "passed": bool(passed)})

    campaign, level, legacy, config, scenery, wall, door, game_map, battle, state, adapter = (
        sources[p] for p in PATHS)
    setup = function(scenery, "setup")
    light = function(scenery, "_add_lantern_light")
    passage = function(scenery, "_add_passage")
    wall_factory = function(scenery, "_add_wall")
    opened = function(level, "_open_prison")
    update = function(level, "process")
    require("installed RTS script", '"script": "res://scripts/levels/level8_daming_rts.gd"' in campaign)
    require("installed map 60x66 town", all(token in level for token in [
        'func map_w() -> int: return 60', 'func map_h() -> int: return 66',
        'func map_theme() -> String: return "town"']))
    require("legacy map is distinct 60x52", 'func map_h() -> int: return 52' in legacy)
    require("installed sealed wicket", 'map.set_meta("campaign_city_wicket_sealed",true)' in function(level, "paint_map"))
    require("source decor chain", 'level8_dongchangfu.gd").new().decorate(map)' in function(level, "decorate"))
    require("level decor before environment factory", battle.index('level.decorate(map)') < battle.index('map.enable_campaign_environment(level.id())'))
    enable = function(game_map, "enable_campaign_environment")
    require("environment transform before scenery setup", enable.index('config.decorate(self,id)') < enable.index('sample_scenery.setup(self)'))
    require("four market lamp locations", 'for cell in [Vector2i(27,12),Vector2i(33,20),Vector2i(27,27),Vector2i(34,33)]:' in config)
    require("market lamp energy independent", '_add_lantern_light(d[1],0.55)' in setup)
    require("Cuiyun owner location and initial energy", '_cuiyun_light=_add_lantern_light(Vector2i(37,15),0.45)' in setup)
    require("night tint", 'dusk.color=Color(0.62,0.67,0.79)' in setup)
    require("terrain tint is separate", 'set_shader_parameter("scene_tint",Color(0.72,0.77,0.87))' in setup)
    require("shared fresh lantern texture", 'if _lantern_texture==null:' in light and 'lamp.texture=_lantern_texture' in light)
    require("gradient fixed contract", all(token in light for token in [
        'gradient.colors=PackedColorArray([Color.WHITE,Color(0,0,0,0)])',
        '_lantern_texture.width=128', '_lantern_texture.height=128',
        '_lantern_texture.fill=GradientTexture2D.FILL_RADIAL',
        '_lantern_texture.fill_from=Vector2(0.5,0.5)', '_lantern_texture.fill_to=Vector2(0.5,1.0)',
        'lamp.texture_scale=1.8', 'lamp.color=Color(1.0,0.68,0.32)', 'lamp.shadow_enabled=false']))
    story = function(scenery, "set_story_object_state")
    require("signal energy branch", '_cuiyun_light.energy=1.15 if state=="signal" else 0.45' in story)
    require("signal expiry is not extinguishing", 'signal_left=maxf(0,signal_left-delta)' in update and 'set_story_object_state' not in update)
    require("prison opening is navigation authority", 'b.map.block_footprint(PRISON_DOOR,0,false)' in opened)
    require("passage reads land navigation", 'map.is_open_world(position,"land")' in function(door, "_process"))
    require("passage new map binding", 'door.map=_map' in passage)
    require("prison art belongs to actual passage", 'if caption=="牢门": door.object_key="prison_gate"' in passage and 'if _style=="level8" and d[0]=="prison_gate": continue' in setup)
    require("sealed wicket adds wall instead of passage", all(token in setup for token in [
        'if bool(_map.get_meta("campaign_city_wicket_sealed",false)):',
        '_add_wall(Vector2(32.5,39),Vector2(33.5,39))', '_add_passage(Vector2i(33,39),"偏门")']))
    require("south gate is Unit not passage", '_add_passage(Vector2i(30,39)' not in setup and 'gate=b.spawn_at("zhu_gate"' in level)
    require("city wall uses original renderer", 'CityWall.new() if _style=="level8" else Stockade.new()' in wall_factory)
    require("wall panel spacing and height", all(token in wall_factory for token in [
        '1.7 if _style=="level8" else 3.0', 'else 108.0', 'wall.height_scale=height_override',
        'wall.end_local = _map.project(to)-_map.project(from)']))
    require("wall mesh derived from fields", all(token in wall for token in ['var salt := 0', 'if _mesh==null: _build_mesh()', 'var top := height_scale*0.76']))
    require("original wall salt is default", 'wall.salt' not in wall_factory)
    require("installed Level state matches RTS", '"level8": preload("res://scripts/levels/level8_daming_rts.gd")' in state and 'gate_open prison_open rescued signaled reserve_returned' in state)
    # These are expected missing adapters, not successful restore tests.
    blockers = {
        "installed_level8_context_missing": '"level8"' not in function(adapter, "_campaign_enabled"),
        "lights_explicitly_rejected": 'visual._lantern_texture != null or visual._cuiyun_light != null' in function(adapter, "_campaign_arrays"),
        "city_wall_and_passage_kinds_missing": 'CityWall' not in function(adapter, "_kind") and 'Passage' not in function(adapter, "_kind"),
        "level8_crowd_kind_missing": '== "level2" and node.get_script() == CampaignScenery.StoryCrowd' in function(adapter, "_kind"),
    }
    return checks, blockers


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    if args.out.exists():
        raise SystemExit("Refusing to overwrite prior evidence: " + str(args.out))
    raw = {p: (ROOT / p).read_bytes() for p in PATHS}
    sources = {p: b.decode("utf-8-sig").replace("\r\n", "\n") for p, b in raw.items()}
    checks, blockers = audit(sources)
    negatives = []
    for name, path, before, after in [
        ("wrong installed script", PATHS[0], 'res://scripts/levels/level8_daming_rts.gd', 'res://scripts/levels/level8_dongchangfu.gd'),
        ("legacy dimensions", PATHS[1], 'func map_h() -> int: return 66', 'func map_h() -> int: return 52'),
        ("unsealed installed wicket", PATHS[1], 'campaign_city_wicket_sealed",true', 'campaign_city_wicket_sealed",false'),
        ("lost market lamp", PATHS[3], 'Vector2i(27,12),', ''),
        ("independent texture per lamp", PATHS[4], 'lamp.texture=_lantern_texture', 'lamp.texture=GradientTexture2D.new()'),
        ("wrong Cuiyun owner", PATHS[4], '_cuiyun_light=_add_lantern_light(Vector2i(37,15)', '_cuiyun_light=_add_lantern_light(Vector2i(35,16)'),
        ("door ignores navigation", PATHS[6], 'map.is_open_world(position,"land")', 'true'),
        ("door references old world", PATHS[4], 'door.map=_map', 'door.map=null'),
        ("duplicate static prison art", PATHS[4], 'if _style=="level8" and d[0]=="prison_gate": continue', 'if false: continue'),
    ]:
        if before not in sources[path]:
            raise AssertionError("mutation anchor missing: " + name)
        mutated = dict(sources)
        mutated[path] = sources[path].replace(before, after, 1)
        failed = [c["name"] for c in audit(mutated)[0] if not c["passed"]]
        negatives.append({"case": name, "rejected": bool(failed), "failed_contracts": failed})
    # Fixed source geometry only: this is not Godot mesh/render evidence.
    outer = [((7, 4), (52, 4)), ((7, 4), (7, 39)), ((52, 4), (52, 39)),
             ((7, 39), (28, 39)), ((32, 39), (32.5, 39)), ((33.5, 39), (52, 39))]
    sealed = [((32.5, 39), (33.5, 39))]
    prison = [((15, 13), (21, 13)), ((15, 13), (15, 20)), ((21, 13), (21, 20)),
              ((15, 20), (18.5, 20)), ((19.5, 20), (21, 20))]
    for segment in outer + sealed + prison:
        token = '[Vector2(%g,%g),Vector2(%g,%g)]' % (*segment[0], *segment[1])
        if segment in sealed:
            token = '_add_wall(Vector2(%g,%g),Vector2(%g,%g))' % (*segment[0], *segment[1])
        checks.append({"name": "wall source segment " + token, "passed": token in sources[PATHS[4]]})
    counts = {name: sum(math.ceil(math.dist(a, b) / 1.7) for a, b in segments)
              for name, segments in [("outer", outer), ("sealed_wicket", sealed), ("prison", prison)]}
    unchanged = all((ROOT / p).read_bytes() == b for p, b in raw.items())
    passed = all(c["passed"] for c in checks) and all(n["rejected"] for n in negatives) and unchanged
    report = {"source_audit_passed": passed, "runtime_qualified": False, "restore_qualified": False,
              "public_campaign_continue_qualified": False, "production_modified": False,
              "scope": __doc__, "checks": checks, "mutation_cases": negatives,
              "confirmed_adapter_blockers": blockers, "source_inputs_unchanged": unchanged,
              "fixed_source_layout": {"map": [60, 66], "wall_panel_counts": counts,
                                      "city_walls_total": sum(counts.values()), "passages": [[19, 20]],
                                      "market_lamps": [[27, 12], [33, 20], [27, 27], [34, 33]],
                                      "market_energy": 0.55, "cuiyun": [37, 15], "cuiyun_energies": [0.45, 1.15]},
              "source_files": [{"path": p, "bytes": len(b), "sha256": hashlib.sha256(b).hexdigest()}
                               for p, b in raw.items()],
              "producer_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    # Exclusive creation preserves evidence even if concurrent invocations race.
    with args.out.open("x", encoding="utf-8", newline="\n") as output:
        json.dump(report, output, ensure_ascii=False, indent=2)
        output.write("\n")
    print(json.dumps({"source_audit_passed": passed, "checks": len(checks),
                      "mutation_cases": len(negatives), "runtime_qualified": False,
                      "report": str(args.out)}, ensure_ascii=False))
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
