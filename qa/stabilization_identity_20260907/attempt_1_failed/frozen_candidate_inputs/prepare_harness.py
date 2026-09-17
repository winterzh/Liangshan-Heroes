"""Port archived real-object graph suite and add stable identity cases; no engine."""
from prepare import HERE, ROOT, one, sha, dump, write

source=ROOT/'qa/run_unit_graph_20260907/sources/scratchpad/run_unit_graph/graph_smoke.gd.txt'
raw=source.read_bytes();s=raw.decode('utf8').replace('\r\n','\n')
s=one(s,'res://scratchpad/run_unit_graph/unit_graph.gd','res://scripts/run_unit_graph.gd')
s=one(s,'const VERSION := "unit_graph_smoke_v1"','const VERSION := "stable_identity_smoke_v2"')
s=one(s,'"suite": "unit-graph"','"suite": "stable-identity-candidate"')
s=one(s,'[unit-graph QA]','[stable-identity candidate QA]')
s=one(s,'No Battle._ready, economy/effects/disk restore, global UID/tick, cross-process Battle, PCK or menu test.',
        'Also tests actual allocator bounds, faulted capture refusal, required replacement retention, paid failed production and wave-capacity fault propagation. No Battle._ready, whole economy/effect/disk restore, clock, cross-process Battle, PCK or menu test.')
marker='\tvar expected_active: Array = ["9007199254740993", "73", "19", "41"]\n'
s=one(s,marker,marker+'\tfor unit: Variant in ids: unit.entity_id = String(ids[unit]).to_int()\n\tsource.next_entity_id = 9007199254740994\n')
marker='\t_check("wire and validated snapshot preserve exact JSON", JSON.stringify(validated.value) == json_text)\n'
s=one(s,marker,marker+'''\t_check("next allocator exact decimal survives JSON", wire.next_entity_id == "9007199254740994" and validated.next_entity_id == 9007199254740994)
\tfor invalid_next: Variant in [0, -1, 1.0, "0", "01", "-1", "9223372036854775808", "9007199254740993"]:
\t\tvar invalid_counter: Dictionary = wire.duplicate(true)
\t\tinvalid_counter.next_entity_id = invalid_next
\t\tvar counter_result: Dictionary = graph.prepare(invalid_counter, VERSION, target, target.map)
\t\t_check("bad next allocator rejects before construction " + str(invalid_next), counter_result.get("ok") == false and counter_result.get("created_count") == 0)
\tvar exhausted_counter: Dictionary = wire.duplicate(true)
\texhausted_counter.next_entity_id = "9223372036854775807"
\t_check("exhausted sentinel is valid next only", graph.validate(exhausted_counter, VERSION).get("ok") == true)
''')
s=one(s,'\t_check("capture rejects duplicate persistent IDs", graph.capture(source, duplicate_ids, VERSION).get("code") == "ENTITY_ID_DUPLICATE")\n',
'''\t_check("capture rejects registry field mismatch", graph.capture(source, duplicate_ids, VERSION).get("code") == "ENTITY_FIELD_REGISTRY")
\tdying.entity_id = holder.entity_id
\t_check("capture rejects duplicate persistent IDs", graph.capture(source, duplicate_ids, VERSION).get("code") == "ENTITY_ID_DUPLICATE")
\tdying.entity_id = 107
''')
marker='\tcontexts.append(prepared.identity)\n'
s=one(s,marker,marker+'''\t_check("prepare returns allocator without installing it", target.next_entity_id == 1 and prepared.pending_battle_fields.next_entity_id == source.next_entity_id and not prepared.entity_allocator_installed)
\tvar early_activation: Dictionary = factory.activate(prepared.activation_plan[0].unit, prepared.activation_plan[0].activation)
\t_check("activation refuses uninstalled allocator", early_activation.get("code") == "ENTITY_ALLOCATOR_NOT_INSTALLED")
\ttarget.next_entity_id = prepared.pending_battle_fields.next_entity_id
''')
marker='\t_finish()\n'
s=one(s,marker,'\t_stable_failure_tests(battle_script, map_script, unit_script, graph)\n'+marker)
s+='\n'+(HERE/'failure_cases.gd.inc').read_text('utf8')
write(HERE/'identity_smoke.gd',s)
dump(HERE/'harness_receipt.json',{'status':'parser_only_engine_pending','archived_driver':source.relative_to(ROOT).as_posix(),
     'archived_sha256':sha(raw),'driver_sha256':sha(s.encode()),'retained_actual_graph_cases':True,
     'manifest_env':'RUN_RESTORE_QA_MANIFEST','entry':'res://tools/stabilization_identity/identity_smoke.gd',
     'battle_ready_or_ui':False,'cross_process_resume':False})
print('Prepared identity_smoke.gd; engine not launched.')
