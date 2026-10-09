"""Connect installed chapter Unit contracts and remappable Daming mine metadata."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def replace(s,a,b,count=1):assert s.count(a)==count,(a,s.count(a));return s.replace(a,b)
def main():
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip()=='e1d546d04cb166905ac5493afbc5275d95c87574'
    names=['scripts/run_unit_state.gd','scripts/run_unit_graph.gd'];before={n:sha(ROOT/n) for n in names}
    p=ROOT/names[0];s=p.read_text(encoding='utf-8')
    s=replace(s,'const LEVEL4_SCHEMA :=','const LEVEL5_SCHEMA := "level5_unit_state_v1"\nconst LEVEL8_SCHEMA := "level8_unit_state_v1"\nvar _gao_contract: RefCounted\nvar _daming_contract: RefCounted\nconst LEVEL4_SCHEMA :=')
    needle='\tif context.mode == "campaign" and context.level_id == "level4" and context.waves == 0:'
    new=''
    for number,name in [(5,'gao'),(8,'daming')]:
        new+=f'\tif context.mode == "campaign" and context.level_id == "level{number}" and context.waves == 0:\n\t\t_{name}_contract = preload("res://scripts/run_level{number}_unit_contract.gd").new()\n\t\tvar result: Dictionary = _{name}_contract.configure(roles)\n\t\tif not result.ok: _scope_error = result.code; return\n\t\t_chapter_roles = _{name}_contract.actors.duplicate(true)\n\t\tfor id in _{name}_contract.pools:_chapter_roles[id] = {{}}\n\t\t_unit_schema = LEVEL{number}_SCHEMA\n\t\treturn\n'
    s=replace(s,needle,new+needle)
    s=replace(s,'\tif _unit_schema == LEVEL4_SCHEMA: return _lian_contract.values(v)','\tif _unit_schema == LEVEL5_SCHEMA: return _gao_contract.values(v)\n\tif _unit_schema == LEVEL8_SCHEMA: return _daming_contract.values(v)\n\tif _unit_schema == LEVEL4_SCHEMA: return _lian_contract.values(v)')
    s=replace(s,'\tif _unit_schema == LEVEL4_SCHEMA: return _lian_contract.parts(v, refs, meta, node)','\tif _unit_schema == LEVEL5_SCHEMA: return _gao_contract.parts(v, refs, meta, node)\n\tif _unit_schema == LEVEL8_SCHEMA: return _daming_contract.parts(v, refs, meta, node)\n\tif _unit_schema == LEVEL4_SCHEMA: return _lian_contract.parts(v, refs, meta, node)')
    s=replace(s,'_unit_schema in [LEVEL3_SCHEMA, LEVEL1_SCHEMA, LEVEL2_SCHEMA]','_unit_schema in [LEVEL3_SCHEMA, LEVEL1_SCHEMA, LEVEL2_SCHEMA, LEVEL8_SCHEMA]')
    needle='func validate_level4_membership(states: Dictionary, active_ids: Array) -> Dictionary:'
    new=''
    for number,name in [(5,'gao'),(8,'daming')]:new+=f'func validate_level{number}_membership(states: Dictionary, active_ids: Array) -> Dictionary:\n\tif _unit_schema != LEVEL{number}_SCHEMA or not _scope_error.is_empty():return _failure("LEVEL{number}_CONTEXT_REQUIRED")\n\treturn _{name}_contract.membership(states, active_ids)\n\n'
    s=replace(s,needle,new+needle)
    s=replace(s,'func _read_metadata(unit: Variant) -> Dictionary:','func _read_metadata(unit: Variant, object_to_id: Dictionary = {}) -> Dictionary:')
    needle='\t\tif typeof(value) == TYPE_RECT2:\n\t\t\tresult[key] = {"kind": "rect2", "position": value.position, "size": value.size}'
    new='\t\tif _unit_schema == LEVEL8_SCHEMA and key == "daming_mine":\n\t\t\tvar reference: Dictionary = _tag(value, object_to_id, "metadata.daming_mine")\n\t\t\tif not reference.ok:return reference\n\t\t\tresult[key] = {"kind": "unit_reference", "tag": reference.value}\n\t\telif typeof(value) == TYPE_RECT2:\n\t\t\tresult[key] = {"kind": "rect2", "position": value.position, "size": value.size}'
    s=replace(s,needle,new)
    s=replace(s,'func _check_metadata(values: Variant) -> Dictionary:','func _check_metadata(values: Variant, known_ids: Dictionary = {}) -> Dictionary:')
    needle='\t\tif entry.kind == "rect2":'
    new='\t\tif entry.kind == "unit_reference":\n\t\t\tif _unit_schema != LEVEL8_SCHEMA or key != "daming_mine" or not _fields(entry,["kind","tag"]):return _failure("METADATA_REFERENCE_SCOPE",key)\n\t\t\tvar checked: Dictionary = _check_tag(entry.tag,known_ids,"metadata.daming_mine")\n\t\t\tif not checked.ok:return checked\n\t\t\tresult[key] = entry.tag.duplicate(true)\n\t\telif entry.kind == "rect2":'
    s=replace(s,needle,new)
    s=replace(s,'_read_metadata(unit)','_read_metadata(unit, object_to_id)')
    s=replace(s,'_check_metadata(metadata.value)','_check_metadata(metadata.value, registry.ids)')
    s=replace(s,'_check_metadata(payload.metadata)','_check_metadata(payload.metadata, known_ids)')
    s=replace(s,'\tfor key in state.metadata: unit.set_meta(StringName(key), state.metadata[key])','\tfor key in state.metadata:\n\t\t# The new registry exists only at bind(); never install a saved tag as gameplay metadata.\n\t\tif _unit_schema == LEVEL8_SCHEMA and key == "daming_mine":continue\n\t\tunit.set_meta(StringName(key), state.metadata[key])')
    needle='\tvar count: int = _expired_count(state.references)'
    new=needle+'\n\tif _unit_schema == LEVEL8_SCHEMA and state.metadata.has("daming_mine") and state.metadata.daming_mine.state == "expired":count += 1'
    s=replace(s,needle,new)
    needle='\tunit.battle = battle\n\tunit.map = game_map'
    s=replace(s,needle,'\tif _unit_schema == LEVEL8_SCHEMA and state.metadata.has("daming_mine"):\n\t\tunit.set_meta("daming_mine", _resolve_tag(state.metadata.daming_mine,id_to_unit,expired_unit))\n'+needle)
    p.write_bytes(s.encode('utf-8'))
    p=ROOT/names[1];s=p.read_text(encoding='utf-8')
    needle='const LEVEL4_SCHEMA :=';s=replace(s,needle,'const LEVEL5_SCHEMA := "level5_unit_graph_v1"\nconst LEVEL8_SCHEMA := "level8_unit_graph_v1"\nconst GAO_CONTEXT := {"mode":"campaign","level_id":"level5","waves":0}\nconst DAMING_CONTEXT := {"mode":"campaign","level_id":"level8","waves":0}\nconst Gao := preload("res://scripts/levels/level5_gao_rts.gd")\nconst Daming := preload("res://scripts/levels/level8_daming_rts.gd")\n'+needle)
    s=replace(s,'["level3", "level1", "level6", "level2", "level7", "level4"]','["level3", "level1", "level6", "level2", "level7", "level4", "level5", "level8"]')
    needle='\tif context.level_id == "level4":';new=''
    for number,name,index in [(5,'Gao',4),(8,'Daming',7)]:new+=f'\tif context.level_id == "level{number}":\n\t\tif CampaignScript.LEVELS.size() <= {index} or CampaignScript.LEVELS[{index}].id != "level{number}" or CampaignScript.LEVELS[{index}].script != ({name} as Script).resource_path:\n\t\t\t_scope_error = "LEVEL{number}_INSTALLED_CATALOG_REQUIRED"; return\n\t\t_graph_schema = LEVEL{number}_SCHEMA; _campaign_level_id = "level{number}"; return\n'
    s=replace(s,needle,new+needle)
    needle='\tif _graph_schema == LEVEL4_SCHEMA:\n\t\tvar lian_roles:'
    new='\tif _graph_schema in [LEVEL5_SCHEMA, LEVEL8_SCHEMA]:\n\t\tif _graph_schema == LEVEL5_SCHEMA:\n\t\t\tvar token: Variant = checked.value.external.end_button\n\t\t\tif token != null and (typeof(token) != TYPE_STRING or token != "level5:end"):return _bad("LEVEL5_END_TOKEN")\n\t\t\tif external_tokens.size() != (0 if token == null else 1) or (token != null and not external_tokens.has("level5:end")):return _bad("LEVEL5_END_EXTERNAL_SET")\n\t\tvar roles := {"values":checked.value.values,"references":refs,"external":checked.value.external}\n\t\t_factory = _unit_state_script.new(_codec_script,_unit_script,_inventory_script,GAO_CONTEXT if _graph_schema == LEVEL5_SCHEMA else DAMING_CONTEXT,roles)\n\telif _graph_schema == LEVEL4_SCHEMA:\n\t\tvar lian_roles:'
    s=replace(s,needle,new)
    s=replace(s,'[LEVEL3_SCHEMA, LEVEL1_SCHEMA, LEVEL6_SCHEMA, LEVEL2_SCHEMA, LEVEL7_SCHEMA, LEVEL4_SCHEMA]','[LEVEL3_SCHEMA, LEVEL1_SCHEMA, LEVEL6_SCHEMA, LEVEL2_SCHEMA, LEVEL7_SCHEMA, LEVEL4_SCHEMA, LEVEL5_SCHEMA, LEVEL8_SCHEMA]')
    needle='\t\telif _graph_schema == LEVEL2_SCHEMA:\n\t\t\tvar external:'
    new='\t\telif _graph_schema == LEVEL5_SCHEMA:\n\t\t\tvar external: Dictionary = _level5_external_tokens(battle)\n\t\t\tif not external.ok:return external\n\t\t\texternal_to_token = external.value\n\t\telif _graph_schema == LEVEL2_SCHEMA:\n\t\t\tvar external:'
    s=replace(s,needle,new)
    a=s.index('func _level2_external_tokens(');b=s.index('func _level7_external_tokens(',a)
    helper=s[a:b].replace('_level2_external_tokens','_level5_external_tokens').replace('Jiang','Gao').replace('LEVEL2','LEVEL5').replace('DEPART','END').replace('depart_button','end_button').replace('jiang_depart','gao_end').replace('level2:depart','level5:end')
    s=s[:b]+helper+s[b:]
    needle='\tif _graph_schema == LEVEL4_SCHEMA:\n\t\tvar membership:'
    new='\tif _graph_schema in [LEVEL5_SCHEMA,LEVEL8_SCHEMA]:\n\t\tvar membership: Dictionary = _factory.validate_level5_membership(states,snapshot.active_order) if _graph_schema == LEVEL5_SCHEMA else _factory.validate_level8_membership(states,snapshot.active_order)\n\t\tif not membership.ok:\n\t\t\tidentity.dispose();return membership\n\telif _graph_schema == LEVEL4_SCHEMA:\n\t\tvar membership:'
    s=replace(s,needle,new);p.write_bytes(s.encode('utf-8'))
    for n in ['scripts/run_level5_unit_contract.gd','scripts/run_level8_unit_contract.gd']:names.append(n)
    record={'applied':True,'parent_commit':'e1d546d04cb166905ac5493afbc5275d95c87574','source_delta':[{'path':n,'before_sha256':before.get(n),'after_sha256':sha(ROOT/n)} for n in names],
      'producer_sha256':sha(Path(__file__)),'scope':'Installed Level5/Level8 Unit state/graph contracts and Level8-only daming_mine entity reference capture, validation and post-registry binding. Existing schemas/metadata representation unchanged. Full map/scenery/visual/core and cross-process world qualification still required.','unit_graph_qualified':False,'full_world_qualified':False}
    p=ROOT/'qa/zhu_wounded_20261005/campaign_units_patch_v19.json';assert not p.exists();p.write_bytes((json.dumps(record,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    print(json.dumps({'production_files':names,'full_world_qualified':False}))
if __name__=='__main__':main()
