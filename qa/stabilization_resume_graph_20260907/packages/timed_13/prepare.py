"""Build only this isolated 27-file candidate; never launch Godot or touch production."""
from pathlib import Path
import ast, difflib, hashlib, json, re, sys
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'scratchpad/stabilization_visual_graph_20260907'
CLASSES = {'meteor':'MeteorFx', 'ground_fire':'GroundFireFx', 'ward':'WardFx',
           'arrow_shot':'ArrowShotFx', 'arrow_rain':'ArrowRainFx', 'flameburst':'FlameburstFx',
           'ability':'AbilityFx', 'building_collapse':'BuildingCollapseFx'}
FIELDS = {
 'meteor':['dur','t','start_w','end_w','rad','life','col','_roll','_embers'],
 'ground_fire':['dur','t','rad','col','life','lite','_flames','_embers'],
 'ward':['dur','t','rad','col','life','style','banner_kind','lite','_ph','ward_visual'],
 'arrow_shot':['dur','t','end_w','col','pin','big','travel','_E','_ang'],
 'arrow_rain':['dur','t','rad','col','_arrows'],
 'flameburst':['dur','t','rad','col','_flames','_embers'],
 'ability':['dur','t','rad','col','_seed'],
 'building_collapse':['dur','t','tex','s']}
FLOATS = {'meteor':['rad','life','_roll'], 'ground_fire':['rad','life'], 'ward':['rad','life','_ph'],
          'arrow_shot':['travel','_ang'], 'arrow_rain':['rad'], 'flameburst':['rad'],
          'ability':['rad'], 'building_collapse':['s']}
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p, s): p.parent.mkdir(parents=True, exist_ok=True); p.write_text(s, encoding='utf8', newline='\n')
def dump(p, value): write(p, json.dumps(value, ensure_ascii=False, indent=2)+'\n')
def replace(s, before, after):
    assert s.count(before)==1, before
    return s.replace(before, after)
def main():
    assert not (HERE/'freeze.json').exists(), 'Do not regenerate an already frozen package'
    frozen=json.loads((BASE/'freeze.json').read_text('utf8'))
    for name, expected in frozen['inputs'].items(): assert sha(BASE/name)==expected, name
    manifest=json.loads((BASE/'overlay_manifest.json').read_text('utf8'))
    for row in manifest['files']:
        source=ROOT/row['candidate']; assert sha(source)==row['candidate_sha256'], row['path']
        out=HERE/'candidate'/row['path']
        if row['path'] not in ['scripts/battle.gd','scripts/run_visual_graph.gd']:
            assert sha(out)==sha(source), row['path']
    before=(BASE/'candidate/scripts/battle.gd').read_text('utf8'); battle=before
    inventory=[]
    for kind, name in CLASSES.items():
        marker='class '+name+' extends TimedFx:'; start=battle.index(marker); end=battle.index('\nclass ', start+len(marker))
        block=battle[start:end]; old=block
        declared=re.findall(r'^\tvar (\w+)',block,re.M)
        assert set(declared)==set(FIELDS[kind])-{'dur','t','ward_visual'}, (kind,declared)
        assert 'add_child(' not in block and 'create_tween(' not in block
        needle='\tfunc _ready() -> void:\n'
        block=replace(block,needle,needle+'\t\tif get_meta("_run_restore_prepared", false): return\n')
        battle=battle[:start]+block+battle[end:]
        inventory.append({'kind':kind,'class':name,'fields':FIELDS[kind], 'own_declarations':declared,
                          'child_nodes':0,'ready_guard':True,'ready_uses_global_visual_rng':bool(re.search(r'\brandf\(|\brandf_range\(',old)),
                          'source_line':before[:before.index(marker)].count('\n')+1})
    write(HERE/'candidate/scripts/battle.gd',battle)
    write(HERE/'battle_delta.patch',''.join(difflib.unified_diff(before.splitlines(True),battle.splitlines(True),fromfile='frozen_visual/battle.gd',tofile='timed_visual/battle.gd')))
    graph=(BASE/'candidate/scripts/run_visual_graph.gd').read_text('utf8')
    graph=replace(graph, '"_pack"]}', '"_pack"],\n'+',\n'.join('\t'+json.dumps(k)+': '+json.dumps(v) for k,v in FIELDS.items())+'}')
    graph=replace(graph, 'const NODE_FIELDS :=', 'const TIMED_KINDS := '+json.dumps(list(CLASSES))+'\nconst TIMED_FLOATS := '+json.dumps(FLOATS)+'\nconst NODE_FIELDS :=')
    graph=replace(graph,'var _committed := false','var _committed := false\nvar _owner: Variant = null\nvar _textures: Dictionary = {}\nvar _ground_bound := false')
    graph=replace(graph,'func _init(codec: Script, battle: Script, unit: Script) -> void:', 'func _init(codec: Script, battle: Script, unit: Script, owner: Variant = null, trusted_textures: Dictionary = {}) -> void:')
    graph=replace(graph,'\t_unit = unit','\t_unit = unit\n\t_owner = owner\n\t_textures = trusted_textures.duplicate()')
    graph=replace(graph,'\tif node.get_script() == _battle.FloatLabel: return "float_label"', '\tif node.get_script() == _battle.FloatLabel: return "float_label"\n'+'\n'.join(f'\tif node.get_script() == _battle.{v}: return "{k}"' for k,v in CLASSES.items()))
    graph=replace(graph,'\t\t"float_label": return _battle.FloatLabel.new()', '\t\t"float_label": return _battle.FloatLabel.new()\n'+'\n'.join(f'\t\t"{k}": return _battle.{v}.new()' for k,v in CLASSES.items()))
    graph=replace(graph,'\tfor field: String in FIELDS[kind]: values[field] = node.get(field)', '\tfor field: String in FIELDS[kind]:\n\t\tif field != "ward_visual": values[field] = node.get(field)\n\tif kind == "building_collapse": values["tex"] = _texture_token(node.tex).value\n\tif kind == "ward": values["ward_visual"] = _ward_signature(node.style).value')
    graph=replace(graph,'\tvar floats: Array = ["_t"]', '\tif kind in TIMED_KINDS: return _timed_check(values, kind)\n\tvar floats: Array = ["_t"]')
    graph=replace(graph,'\t\tvar id: String = str(rows.size() + 1)', '\t\tvar supported: Dictionary = _timed_node_supported(node, kind)\n\t\tif not supported.ok: return supported\n\t\tvar id: String = str(rows.size() + 1)')
    graph=replace(graph,'\t\t\trefs.chain_from = tag.value', '\t\t\trefs["chain_from"] = tag.value')
    graph=replace(graph,'\tvar encoded: Dictionary = _codec.encode(rows)', '\tvar owner_check: Dictionary = _capture_ground_owner(root, rows)\n\tif not owner_check.ok: return owner_check\n\tvar encoded: Dictionary = _codec.encode(rows)')
    graph=replace(graph,'\t\tif row.kind in ["beast_stampede", "hit_spark"]:', '\t\tif row.kind in ["beast_stampede", "hit_spark"] + TIMED_KINDS:')
    graph=replace(graph,'\t\tfor field: String in FIELDS[row.kind]: node.set(field, row.values[field])', '\t\tfor field: String in FIELDS[row.kind]:\n\t\t\tif field == "ward_visual": continue\n\t\t\tif row.kind == "building_collapse" and field == "tex":\n\t\t\t\tnode.tex = null if row.values.tex.state == "none" else _textures[row.values.tex.key]\n\t\t\telse: node.set(field, row.values[field])')
    graph=replace(graph,'\tif _committed: return _failure("VISUAL_ALREADY_ACTIVATED")', '\tif _committed: return _failure("VISUAL_ALREADY_ACTIVATED")\n\tif _ground_count(_records.values()) > 0:\n\t\tif not _ground_bound: return _failure("GROUND_FIRE_OWNER_NOT_BOUND")\n\t\tvar owner_check: Dictionary = _capture_ground_owner(_root, _records.values(), true)\n\t\tif not owner_check.ok: return owner_check')
    # Capture uses _objects; activation uses freshly prepared _nodes for signal checks.
    graph += '\n' + (HERE/'timed_helpers.gd.inc').read_text('utf8')
    graph=replace(graph,'func _capture_ground_owner(root: Node2D, rows: Array) -> Dictionary:', 'func _capture_ground_owner(root: Node2D, rows: Array, prepared: bool = false) -> Dictionary:')
    graph=replace(graph,'\tfor object: Node2D in _objects:', '\tvar objects: Array = _nodes.values() if prepared else _objects.keys()\n\tfor object: Node2D in objects:')
    write(HERE/'candidate/scripts/run_visual_graph.gd',graph)
    write(HERE/'visual_delta.patch',''.join(difflib.unified_diff((BASE/'candidate/scripts/run_visual_graph.gd').read_text('utf8').splitlines(True),graph.splitlines(True),fromfile='frozen_visual/run_visual_graph.gd',tofile='timed_visual/run_visual_graph.gd')))
    legacy=(BASE/'visual_smoke.gd').read_text('utf8')
    legacy=replace(legacy,'scripts.battle.AbilityFx.new()','scripts.battle.StompFx.new()')
    legacy=replace(legacy,'rows[1].values.extra_unknown = 1','rows[1].values["extra_unknown"] = 1')
    legacy=replace(legacy,'\tvar stage: Node2D = _stage()', '\tvar stage: Node2D = _stage()\n\tvar target_stage: Node2D = _stage()\n\ttarget_stage.transform = stage.transform\n\t_check(kind + " independent same-transform fixture parents", stage != target_stage and stage.global_transform == target_stage.global_transform)')
    legacy=replace(legacy,'\tstage.add_child(target.fx_root)', '\ttarget_stage.add_child(target.fx_root)\n\t_check(kind + " distinct parents preserve exact FxRoot names", source.fx_root.get_parent() != target.fx_root.get_parent() and source.fx_root.name == &"FxRoot" and target.fx_root.name == &"FxRoot")')
    write(HERE/'visual_smoke.gd',legacy)
    timed=legacy[:legacy.index('func _step(')]
    timed=replace(timed,'"run_remaining_effect_state", "run_visual_graph"', '"run_remaining_effect_state", "run_visual_graph", "run_meteor_wards_state", "run_continuous_effect_state", "hud"')
    timed=replace(timed,'["bolt", "bolt_expired", "bolt_line", "bolt_line_expired", "hook_out", "hook_drag", "trap", "beast"]', '["meteor", "ground_fire", "ground_fire_lite", "ward_heal", "ward_loyalty", "ward_righteous", "arrow_shot_flight", "arrow_shot_impact", "arrow_rain", "flameburst", "ability", "building_collapse", "ward_attack_boundary"]')
    timed=timed.replace('remaining-effects-visual-candidate','timed-effects-visual-candidate').replace('[remaining-effects visual candidate QA]','[timed-effects visual candidate QA]')
    timed=re.sub(r'"scope": "[^"]*"', '"scope": "Eight additional actual timed classes, exact ready and remaining state; paired fixed consumer steps for meteor, ground fire and heal/banner ward. Source and target use explicit same visual test seeds for future creations. Attack-ward next snapshot explicitly rejects BlinkShotFx. No Battle ready, full scheduler, rendering proof, global visual RNG restore, disk slot or production integration."',timed)
    write(HERE/'timed_smoke.gd',timed+(HERE/'timed_cases.gd.inc').read_text('utf8'))
    sys.path.insert(0,str(ROOT/'scratchpad/stabilization_identity_20260907/parser_runtime'))
    from gdtoolkit.parser import parser
    parsed=[]
    for p in sorted((HERE/'candidate').rglob('*.gd'))+sorted(HERE.glob('*.gd')):
        parser.parse(p.read_text('utf8').replace('== not hud.touch_ui','== (not hud.touch_ui)'),gather_metadata=True)
        parsed.append(str(p.relative_to(HERE)))
    ast.parse(Path(__file__).read_text('utf8'))
    for row in manifest['files']:
        p=HERE/'candidate'/row['path']; row['candidate']=p.relative_to(ROOT).as_posix(); row['candidate_sha256']=sha(p)
    manifest.update(status='grammar_only_native_pending',parent_visual_freeze_sha256=sha(BASE/'freeze.json'),
                    behavior_tested=False,supported_visual_classes=13)
    dump(HERE/'overlay_manifest.json',manifest)
    dump(HERE/'inventory.json',{'new_classes':inventory,'parent_visual_freeze_sha256':sha(BASE/'freeze.json'),
         'original_five_fields_preserved':True,'battle_delta_only_eight_ready_guards':True,
         'resource_policy':'Caller supplies immutable content-bound actual textures by opaque key; no save-directed load.',
         'ground_fire_policy':'Explicit exact owner/count/tree_exited callback bind before activation.'})
    dump(HERE/'static_preparation.json',{'status':'grammar_only_native_pending','parsed':parsed,'gd_count':len(parsed),
         'source_files_changed':False,'engine_started':False,'freeze_parent_verified':True,
         'battle_sha256':sha(HERE/'candidate/scripts/battle.gd'),'visual_sha256':sha(HERE/'candidate/scripts/run_visual_graph.gd')})
    r4_path=ROOT/'.godot/stabilization_overlay/overlay_20260907T071132Z_40a31089/report.json'
    r4=json.loads(r4_path.read_text('utf8'))
    diagnostic=[]
    for kind,observation in r4['observations'].items():
        d=observation['field_diagnostic']; first=d['first_lifecycle_mismatch']
        attachment=d['attachment']['differences']; distinct=d['lifecycle_distinct_fields']
        assert [x['path'] for x in attachment]==['visual.records/0/node/name'], kind
        assert {x['difference']['path'] for x in distinct}=={'visual.records/0/node/name'}, kind
        assert attachment[0]['expected']['text']=='"FxRoot"' and attachment[0]['actual']['text']=='""', kind
        assert first['array_differences']==[] and first['source_unit']==first['target_unit'], kind
        diagnostic.append({'case':kind,'attachment_only':'visual.records/0/node/name','lifecycle_only':'visual.records/0/node/name','arrays_and_sampled_units_equal':True})
    assert len(diagnostic)==8
    dump(HERE/'topology_evidence.json',{'native_r4_report':r4_path.relative_to(ROOT).as_posix(),'sha256':sha(r4_path),
        'cases':diagnostic,'fix':'Independent source and restored stage with equal transform; saved FxRoot name and complete equality checks retained.',
        'new_driver_native_tested':False,'candidate_graph_changed_by_topology_fix':False})
    print(json.dumps({'grammar_pass':len(parsed),'overlay':len(manifest['files']),'new_classes':len(CLASSES),'native_tested':False}))
if __name__ == '__main__': main()
