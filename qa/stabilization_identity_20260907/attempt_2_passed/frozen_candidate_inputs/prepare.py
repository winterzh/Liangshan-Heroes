"""Create an isolated successor to the archived stable-ID candidate; never edit production."""
from pathlib import Path
import difflib
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ARCHIVE = ROOT / 'qa/run_resume_handoff_20260907/drafts/scratchpad/run_stable_entity_candidate'

def sha(raw): return hashlib.sha256(raw).hexdigest()
def lf(raw): return raw.decode('utf-8-sig').replace('\r\n', '\n')
def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data if isinstance(data, bytes) else data.encode('utf-8'))
def dump(path, data): write(path, json.dumps(data, ensure_ascii=False, indent=2) + '\n')
def one(s, old, new, count=1):
    assert s.count(old) == count, (old[:140], s.count(old), count)
    return s.replace(old, new)
def spans(s):
    """Top-level functions stop before ANY next top-level code, not merely next func.

    This fixes the archived review's false attribution of following const blocks
    to run_unit_state::_unit. Blank/comment-only lines are ignored for equality.
    Multiline top-level signatures in these pinned inputs end in their header.
    """
    lines = s.splitlines(True)
    offsets, total = [], 0
    for line in lines: offsets.append(total); total += len(line)
    out = {}
    for i, line in enumerate(lines):
        m = re.match(r'^(?:static )?func (\w+)\(', line)
        if not m: continue
        name = m.group(1)
        assert name not in out, name
        end = i + 1
        # Continued headers are indented in these sources.
        while end < len(lines):
            t = lines[end]
            if t.strip() and not t.startswith(('\t', ' ', '#')): break
            end += 1
        out[name] = (offsets[i], offsets[end] if end < len(lines) else total)
    return out
def methods(s):
    return {name: '\n'.join(line for line in s[a:b].splitlines() if line.strip() and not line.lstrip().startswith('#'))
            for name, (a, b) in spans(s).items()}
def method(s, name, fn):
    a, b = spans(s)[name]
    before = s[a:b]
    after = fn(before)
    assert after != before, name
    return s[:a] + after + s[b:]

def main():
    previous = json.loads((ARCHIVE / 'source_receipt.json.txt').read_bytes())
    before, out, origins = {}, {}, []
    for row in previous['files']:
        name = row['path']
        archived_before = (ARCHIVE/'before'/(name+'.txt.txt')).read_bytes()
        candidate = (ARCHIVE/'candidate'/(name+'.txt')).read_bytes()
        assert sha(archived_before) == row['before_raw_sha256'], name
        assert sha(candidate) == row['candidate_raw_sha256'], name
        raw = (ROOT/name).read_bytes()
        assert lf(raw) == lf(archived_before), ('semantic source drift', name)
        before[name], out[name] = raw, lf(candidate)
        origins.append({'path':name,'archive_before_sha256':sha(archived_before),'archive_candidate_sha256':sha(candidate)})
    def load(name):
        if name not in before:
            before[name] = (ROOT/name).read_bytes()
            out[name] = lf(before[name])
        return out[name]

    # A failed replacement must leave the original registered patient intact.
    # Spawn success is published at the same final root/activity position as
    # before: old nodes are queue-freed only afterwards, within the same call.
    name = 'scripts/levels/level2_jiangzhou.gd'
    s = load(name)
    for person, key in [('song','song_jiang'), ('dai','dai_zong')]:
        old = f'\t\t\tb.units.erase({person}_bound)\n\t\t\t{person}_bound.queue_free()\n\t\t\t{person}_bound = null\n\t\t\t{person}_freed = b.spawn_unit("{key}", Unit.FACTION_LIANG, at)\n'
        new = f'\t\t\tvar replacement: Unit = b.spawn_unit("{key}", Unit.FACTION_LIANG, at)\n\t\t\tif replacement == null: return\n\t\t\tb.units.erase({person}_bound)\n\t\t\t{person}_bound.queue_free()\n\t\t\t{person}_bound = null\n\t\t\t{person}_freed = replacement\n'
        s = one(s, old, new)
    out[name] = s

    # Current RTS Jiangzhou has the same replacement hazard as its old base.
    name = 'scripts/levels/level2_jiangzhou_rts.gd'; s = load(name)
    s = one(s, '\tb.units.erase(bound); bound.queue_free()\n\tvar key: String="song_jiang" if is_song else "dai_zong"\n\tvar rescued: Unit=b.spawn_unit(key,0,pos)\n',
        '\tvar key: String="song_jiang" if is_song else "dai_zong"\n\tvar rescued: Unit=b.spawn_unit(key,0,pos)\n\tif rescued == null: return\n\tb.units.erase(bound); bound.queue_free()\n')
    out[name] = s

    name = 'scripts/levels/level6_yezhulin.gd'; s = load(name)
    replacements = [
        ('\t\t\t','lin_freed','lin_bound','lin_chong_bound','old_pos'),
        ('\t\t','lin_freed','lin_bound','lin_chong_bound','bind_at'),
        ('\t','lin_bound','lin_freed','lin_chong','patient_pos'),
    ]
    for ind, old_unit, new_unit, key, pos in replacements:
        old = f'{ind}b.units.erase({old_unit})\n{ind}{old_unit}.queue_free()\n{ind}{old_unit} = null\n{ind}{new_unit} = b.spawn_unit("{key}", Unit.FACTION_LIANG, {pos})\n'
        new = f'{ind}var replacement: Unit = b.spawn_unit("{key}", Unit.FACTION_LIANG, {pos})\n{ind}if replacement == null: return\n{ind}b.units.erase({old_unit})\n{ind}{old_unit}.queue_free()\n{ind}{old_unit} = null\n{ind}{new_unit} = replacement\n'
        s = one(s, old, new)
    # Force-rescue completion markers follow successful replacement, not failure.
    def force(s):
        mark = '\tb.mission.mark("yezhulin_early_force", reason)\n\t_story_miss(b, "hidden_intercept", "提前现身，未等水火棍落下再拦棍。")\n'
        s = one(s, mark, '')
        return one(s, '\tfor guard in escorts:\n', mark + '\tfor guard in escorts:\n')
    s = method(s, '_begin_open_rescue', force)
    out[name] = s

    # Arena preflights the complete authored wave before any RNG or unit spawn.
    name = 'scripts/levels/arena.gd'; s = load(name)
    s = method(s, '_arena_spawn', lambda s: one(s,
        '\tvar target: Vector2 = b.map.cell_to_world(HALL)\n',
        '\tif not b.entity_ids_available(50 + maxi(0, boss_count)):\n\t\tb._gameplay_rng_stop("ENTITY_ARENA_CAPACITY")\n\t\treturn\n\tvar target: Vector2 = b.map.cell_to_world(HALL)\n'))
    s = one(s, '\t_wave += 1\n', '\tif not b._gameplay_rng_issue.is_empty(): return\n\t_wave += 1\n')
    out[name] = s

    name = 'scripts/levels/scenario.gd'; s = load(name)
    s = one(s, '\n\t\t\t\t_spawn_wave(b, _wave_i)\n', '\n\t\t\t\tif not _spawn_wave(b, _wave_i): return\n')
    s = one(s, '\n\t\t\t\t\t_spawn_wave(b, _wave_i)\n', '\n\t\t\t\t\tif not _spawn_wave(b, _wave_i): return\n')
    def scenario_wave(s):
        s = one(s, 'func _spawn_wave(b, i: int) -> void:\n\t_wave_spawned = true\n', 'func _spawn_wave(b, i: int) -> bool:\n')
        marker = '\tvar wave: Dictionary = data.get("waves", [])[i]\n'
        preflight = '''\tvar required_ids: int = 0
\tfor group in wave.get("groups", []):
\t\tvar count: int = maxi(0, int(group.get("n", 1)))
\t\tif count > 9223372036854775807 - required_ids:
\t\t\tb._gameplay_rng_stop("ENTITY_SCENARIO_COUNT")
\t\t\treturn false
\t\trequired_ids += count
\tvar reinforcement: Variant = wave.get("reinforce", null)
\tif reinforcement != null:
\t\tvar count: int = reinforcement.get("units", []).size()
\t\tif count > 9223372036854775807 - required_ids:
\t\t\tb._gameplay_rng_stop("ENTITY_SCENARIO_COUNT")
\t\t\treturn false
\t\trequired_ids += count
\tif not b.entity_ids_available(required_ids):
\t\tb._gameplay_rng_stop("ENTITY_SCENARIO_CAPACITY")
\t\treturn false
'''
        s = one(s, marker, marker + preflight)
        # Existing hook used to observe _wave_spawned=true. Keep that on success,
        # restoring its prior flag if a hook faults; do not claim hook rollback.
        s = one(s, '\tif _hook != null and _hook.has_method("on_wave"):\n\t\t_hook.on_wave(b, i, self)\n',
            '\tif not b._gameplay_rng_issue.is_empty(): return false\n\tvar previous_spawned: bool = _wave_spawned\n\t_wave_spawned = true\n\tif _hook != null and _hook.has_method("on_wave"):\n\t\t_hook.on_wave(b, i, self)\n\tif not b._gameplay_rng_issue.is_empty():\n\t\t_wave_spawned = previous_spawned\n\t\treturn false\n\treturn true\n')
        s = one(s, '\t\tvar spawned: Array = b.spawn_group(String(g.get("key", "")), int(g.get("n", 1)), wf, gate_cell, target)\n',
            '\t\tvar spawned: Array = b.spawn_group(String(g.get("key", "")), int(g.get("n", 1)), wf, gate_cell, target)\n\t\tif not b._gameplay_rng_issue.is_empty(): return false\n')
        s = one(s, '\t\t\tvar ru = b.spawn_at(String(e.get("key", "")), _fac(e.get("faction", "LIANG")), _cell(e.get("cell", [0, 0])))\n',
            '\t\t\tvar ru = b.spawn_at(String(e.get("key", "")), _fac(e.get("faction", "LIANG")), _cell(e.get("cell", [0, 0])))\n\t\t\tif ru == null:\n\t\t\t\tb._gameplay_rng_stop("ENTITY_SCENARIO_REINFORCE")\n\t\t\t\treturn false\n')
        return s
    s = method(s, '_spawn_wave', scenario_wave)
    out[name] = s

    # Candidate layer only. More caller hardening is applied by this local helper.
    from harden import harden
    out = harden(out, before, ROOT, load)

    name = 'scripts/run_unit_graph.gd'
    out[name] = method(out[name], '_live_graph', lambda body: one(body,
        '\tif not _node(battle, _battle_script): return _bad("BATTLE_INSTANCE")\n',
        '\tif not _node(battle, _battle_script): return _bad("BATTLE_INSTANCE")\n'
        '\t# Never serialize a partial mission/creation commit after fail-stop.\n'
        '\tif not battle.gameplay_rng_fault().is_empty(): return _bad("BATTLE_FAULT")\n'))

    # The archived identity draft missed final-wave recovery placement and its
    # persisted movement map, plus two chapter identity-keyed tracking fields.
    # Opaque combat target/source IDs continue through run_graph_identity.
    name = 'scripts/battle.gd'
    out[name] = method(out[name], 'final_wave_cleanup', lambda body: one(body,
        'var eid := e.get_instance_id()', 'var eid := e.entity_id'))
    out[name] = method(out[name], '_final_cleanup_selftest', lambda body: one(body,
        '{foe.get_instance_id(): foe.position}', '{foe.entity_id: foe.position}'))
    name = 'scripts/levels/skirmish.gd'
    out[name] = method(out[name], 'process', lambda body: one(body,
        'var eid: int = e.get_instance_id()', 'var eid: int = e.entity_id'))
    name = 'scripts/unit.gd'
    out[name] = method(out[name], '_queue_motion_redraw', lambda body: one(body,
        'get_instance_id() % stride', 'entity_id % stride'))
    name = 'scripts/levels/level2_jiangzhou.gd'
    out[name] = method(out[name], 'on_unit_resolved', lambda body: one(body,
        'u.get_instance_id()', 'u.entity_id'))
    name = 'scripts/levels/level6_yezhulin.gd'
    out[name] = one(out[name], 'escort_orders[unit.get_instance_id()]', 'escort_orders[unit.entity_id]')
    out[name] = one(out[name], 'escort_orders.get(unit.get_instance_id(),-1)', 'escort_orders.get(unit.entity_id,-1)')

    rows, patches, changed = [], [], {}
    for name in sorted(out):
        raw = out[name].encode()
        if raw == before[name]: continue
        old = lf(before[name])
        assert raw != old.encode(), ('newline-only change', name)
        write(HERE/'before'/(name+'.txt'), before[name])
        write(HERE/'candidate'/name, raw)
        patches.append(''.join(difflib.unified_diff(old.splitlines(True),out[name].splitlines(True),fromfile='a/'+name,tofile='b/'+name)))
        rows.append({'path':name,'before_raw_sha256':sha(before[name]),'before_lf_sha256':sha(old.encode()),'candidate_sha256':sha(raw),'candidate_bytes':len(raw)})
        a,b = methods(old),methods(out[name])
        changed[name] = sorted(k for k in a.keys()|b.keys() if a.get(k)!=b.get(k))
    patch = ''.join(patches).encode()
    write(HERE/'candidate.patch', patch)
    write(HERE/'.gdignore', b'')
    dump(HERE/'source_receipt.json', {'status':'candidate_not_engine_tested','production_modified':False,'files':rows,'patch_sha256':sha(patch),'archive_sources':origins,'changed_methods':changed})
    print(json.dumps({'candidate_files':len(rows),'patch_sha256':sha(patch),'changed_methods':changed},ensure_ascii=False))

if __name__ == '__main__': main()
