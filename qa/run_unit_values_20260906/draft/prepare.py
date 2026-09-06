"""Build this explicit draft only; never runs Godot or writes production."""
import collections
import hashlib
import json
from pathlib import Path
import re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
UNIT_LF='f4382456b8c619cbb86c40cd8a9ed6ea9f171ba0a8a90c191538f689176d49ee'
CODEC_RAW='c8c4a58d1e68e22abb9f8b1abcb1a9cc1dbaa486e51ea5174dd16984aaa35d15'
SCHEMA=ROOT/'scratchpad/defense_resume_schema.md'
REFS={'story_assist_partner','story_assist_owner','_gold_miner','_gold_waiters','_gather_node','_drop','_build_site','garrison_holder','_garrison_dest','passengers','rally_node','_taunt_src','_hua_lock_target','_target','_pending_target','_killer'}
IDENTITIES={'_lin_spear_target_id','_aura_atkspeed_sources','_damage_reduction_sources','_charge_hit','_chase_last_id','_giveup_id'}
RELATIONS={'battle','map','inventory'}
VISUAL={'_real_frames','_frame_directional','_animated_redraw_t','_queued_redraw_frame','_dust'}
NESTED={'setup_def':'definition_values','ability_slots':'ability_slots','_form':'form','_form_backup':'form_backup','_train_queue':'string_array','group_nums':'group_array','_path':'packed_vector2'}
ENUMS={'faction':[0,1],'stance':[0,3],'_hold_prev_stance':[0,3],'_state':[0,8],'_chase_intent':[0,3],'_swing_kind':[0,5],'_weapon':[-1,5],'hero_level':[1,12],'ai_tick_phase':[0,15],'_lin_guard_rank':[0,3],'lin_spear_rank':[0,3]}

def sha(raw):return hashlib.sha256(raw).hexdigest()
def save(name,data):(HERE/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main():
    raw=(ROOT/'scripts/unit.gd').read_bytes();source=raw.decode('utf-8').replace('\r\n','\n')
    assert sha(source.encode())==UNIT_LF,'Unit changed; independently review then repin'
    codec=(ROOT/'scratchpad/run_state_value_codec/value_codec.gd').read_bytes()
    assert sha(codec)==CODEC_RAW,'Value codec changed'
    indexed=re.findall(r'^\| `([^`]+)` \| `scripts/unit.gd:(\d+)` \| ([A-Z]) ([^|]+)\|',SCHEMA.read_text(encoding='utf-8'),re.M)
    lines={m.group(1):(source[:m.start()].count('\n')+1,m.group(2).split('#')[0].strip()) for m in re.finditer(r'^var (\w+)(.*)$',source,re.M)}
    assert len(indexed)==len(lines)==272 and set(lines)=={x[0] for x in indexed}
    catalog=[];rules={};deferred=[]
    for name,old_line,old_kind,old_note in indexed:
        line,decl=lines[name]
        if name in REFS:kind='reference_next_layer';note='none/entity/expired; ordered arrays retain order; never encode Node/ObjectID'
        elif name in IDENTITIES:kind='identity_or_source_next_layer';note='stable entity/effect/tombstone IDs; mixed source namespaces require explicit mapping'
        elif name in RELATIONS:kind='runtime_relation_next_layer';note='bind new Battle/Map or dedicated HeroInventory adapter; no Resource/Node encoding'
        elif name=='_queue':kind='order_queue_next_layer';note='ordered move/amove/attack/gather/build/repair/garrison shapes; targets need reference protocol'
        elif name in VISUAL:kind='visual_cache_omitted';note='pure draw cache or dust; never call simulation to rebuild'
        else:kind='captured_value';note=old_note.strip()
        row={'field':name,'source_line':line,'declaration':decl,'original_index_category':old_kind,'handling':kind,'note':note}
        if kind=='captured_value':
            if name in NESTED:rule=NESTED[name]
            elif name in ['_ai_dest','mission_order_target']:rule='vector2_positive_inf_sentinel'
            elif name=='_chase_best_distance':rule='float_positive_inf_sentinel'
            elif 'Vector2i' in decl:rule='vector2i'
            elif 'Vector2' in decl:rule='vector2'
            elif 'Color(' in decl:rule='color'
            elif ':= true' in decl or ':= false' in decl:rule='bool'
            elif ':= "' in decl:rule='string'
            elif re.search(r':= -?\d+\.\d+',decl):rule='float'
            elif re.search(r':= (?:-?\d+|FACTION_|STANCE_|ST_|CHASE_|WK\.)',decl):rule='int'
            else:raise AssertionError((name,decl,'Explicit rule missing'))
            limits={'string':'Exact String; aggregate codec byte budget','bool':'Exact bool; no numeric coercion','int':'Exact signed int64','float':'Finite float; signed timer values preserved without clamping','vector2':'Finite native Vector2 components','vector2i':'Native signed int32 components','color':'Finite float32 components; HDR/negative finite values retained','vector2_positive_inf_sentinel':'Finite Vector2 or exactly Vector2(+INF,+INF)','float_positive_inf_sentinel':'Nonnegative finite float or exactly +INF','packed_vector2':'PackedVector2Array, <=4096 finite points; no repath','string_array':'Array of nonempty String, <=8 training entries','group_array':'Strictly increasing unique int Array, <=32 badges','definition_values':'String-keyed Dictionary <=512 top keys; full value tree budgeted, business schema deferred','ability_slots':'<=4 slots; exact 7 keys and native member types','form':'Known 7 optional keys only; finite numeric or Color tint','form_backup':'Empty or exact 6 original float fields'}
            row['rule']=rule;row['range']=ENUMS.get(name,limits[rule])
            if name=='_weapon':row['note']='Preserve cache: _weapon_kind chooses next _swing_kind and damage timing; not proven pure draw.'
            if name=='_stepped':row['note']='Retain cheap visual continuity; avoid unnecessary state loss.'
            rules[name]=rule
        elif kind!='visual_cache_omitted':deferred.append(name)
        catalog.append(row)
    assert len(rules)==241 and len(deferred)==26 and len(VISUAL)==5
    rules.update(position='vector2',modulate='color')
    counts=dict(collections.Counter(x['handling'] for x in catalog))
    save('field_catalog.json',{'schema':1,'unit_lf_sha256':UNIT_LF,'source_declared_fields':272,'handling_counts':counts,'captured_declared_values':241,'inherited_values':['position','modulate'],'fields':catalog,'complete_battle_restore':False})
    header='extends RefCounted\n# Generated explicit fields; runtime never enumerates Node properties.\n'
    header+='const UNIT_SOURCE_LF := '+json.dumps(UNIT_LF)+'\n'
    header+='const CODEC_SOURCE_LF := '+json.dumps(CODEC_RAW)+'\n'
    header+='const DECLARED_COUNT := 272\nconst CAPTURED_DECLARED_COUNT := 241\n'
    header+='const RULES := '+json.dumps(rules,indent=2)+'\n'
    header+='const INT_RANGES := '+json.dumps(ENUMS,indent=2)+'\n'
    header+='const DEFERRED_FIELDS := '+json.dumps(deferred)+'\n'
    header+='const OMITTED_VISUAL_FIELDS := '+json.dumps(sorted(VISUAL))+'\n\n'
    header+='func _read_explicit(unit) -> Dictionary:\n\treturn {\n'+''.join('\t\t'+json.dumps(name)+':unit.'+name+',\n' for name in rules)+'\t}\n\n'
    body=(HERE/'adapter_methods.gd.in').read_text(encoding='utf-8')
    forbidden=r'\b(?:get_property_list|inst_to_dict|var_to_bytes|store_var|setup|take_damage|order_\w+|_enqueue|_recompute_hero_stats)\s*\('
    assert not re.search(forbidden,header+body),'Forbidden reflection or behavioral restore call'
    (HERE/'unit_values.gd').write_text(header+body,encoding='utf-8')
    names=['prepare.py','adapter_methods.gd.in','unit_values.gd','field_catalog.json','qa_driver.gd']
    save('pins.json',{'schema':1,'source_unit_raw_sha256':sha(raw),'source_unit_lf_sha256':UNIT_LF,'value_codec_raw_sha256':CODEC_RAW,'schema_index_raw_sha256':sha(SCHEMA.read_bytes()),'raw_sha256':{n:sha((HERE/n).read_bytes()) for n in names},'counts':counts,'godot_run':False,'production_modified':False})
    table=['# Unit 272 字段处理表','',f'当前 Unit LF SHA `{UNIT_LF}`；运行时使用显式字段，下面的扫描仅在离线 prepare 中核对覆盖。','',f'241 个声明值字段 + position/modulate；26 个待引用/关系层；5 个纯绘制缓存。完整恢复未实现。','','| Field | Current source line | Handling | Type / range |','| --- | --- | --- | --- |']
    for row in catalog:table.append('| `'+row['field']+'` | '+str(row['source_line'])+' | '+row['handling']+' | '+row.get('rule','—')+' / '+str(row.get('range',row['note']))+' |')
    (HERE/'FIELD_TABLE.md').write_text('\n'.join(table)+'\n',encoding='utf-8')
    print(json.dumps({'source_fields':272,'captured_declared':241,'inherited_values':2,'deferred':26,'visual_omitted':5,'godot_run':False,'unit_values_raw_sha256':sha((HERE/'unit_values.gd').read_bytes())}))

if __name__=='__main__':main()
