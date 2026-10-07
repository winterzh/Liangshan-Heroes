"""Apply reviewed role uniqueness and dying escort rules; preserve the cancelled producer."""
from pathlib import Path
import ast,hashlib,json
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    cancelled=json.loads((QA/'campaign_units_preimport_cancelled_v19.json').read_text(encoding='utf-8'))
    assert not cancelled['engine_started'] and cancelled['lock_released']
    for row in cancelled['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    changes={
      'scripts/run_level5_unit_contract.gd':('if actors.has(id):return actors[id].key==key and actors[id].roles.has(role)','if actors.has(id):return false # Every named actor/wave slot is distinct in the installed Gao chapter.'),
      'scripts/run_level8_unit_contract.gd':('if pools.get(str(v.entity_id))!="escorts" or typeof(meta.source_lane)!=TYPE_INT or meta.source_lane not in [0,1]:return bad("SUPPORT_LANE")','if typeof(meta.source_lane)!=TYPE_INT or meta.source_lane not in [0,1]:return bad("SUPPORT_LANE")\n\t\t# The authored support dispatcher filters dead escorts, while dying Unit children remain.\n\t\tif pools.get(str(v.entity_id))!="escorts" and not (v._dying and v.faction==1 and v.key in ["guan_dao","guan_gong"]):return bad("UNREGISTERED_SUPPORT_LANE")'),
      'scripts/run_unit_state.gd':('\t\tif _unit_schema == LEVEL7_SCHEMA and not known_ids.has(id):','\t\tif _unit_schema in [LEVEL5_SCHEMA,LEVEL8_SCHEMA] and not known_ids.has(id):return _failure("LEVEL5_ROLE_NOT_IN_GRAPH" if _unit_schema == LEVEL5_SCHEMA else "LEVEL8_ROLE_NOT_IN_GRAPH",id)\n\t\tif _unit_schema == LEVEL7_SCHEMA and not known_ids.has(id):')}
    pending={};rows=[]
    for name,(a,b) in changes.items():
        p=ROOT/name;s=p.read_text(encoding='utf-8');assert s.count(a)==1;pending[name]=s.replace(a,b)
        rows.append({'path':name,'before_sha256':sha(p)})
    for row in rows:
        p=ROOT/row['path'];p.write_bytes(pending[row['path']].encode('utf-8'));row['after_sha256']=sha(p)
    record={'source_delta':rows,'producer_sha256':sha(Path(__file__)),'cancelled_receipt_sha256':sha(QA/'campaign_units_preimport_cancelled_v19.json'),
      'reason':'Distinct installed Gao actor/wave slots reject duplicate refs; Daming dispatcher removes dead escorts from its pool before dying nodes free, so preserve only dying known troop source-lane metadata; new role missing-id diagnostics use correct chapter.',
      'engine_qualified':False}
    p=QA/'campaign_units_contract_review_fix_v19a.json';assert not p.exists();p.write_bytes((json.dumps(record,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    p=QA/'harness/campaign_units_v19.gd';s=p.read_text(encoding='utf-8').replace('campaign_units_v19','campaign_units_v19a')
    needle='\t# Malformed mine references are rejected before Unit allocation.'
    extra='''\tif id=="level5":
\t\tvar duplicated: Dictionary=Codec.new().decode(captured.level_record.payload).value
\t\tduplicated.references.water_groups[0][1]=duplicated.references.water_groups[0][0]
\t\tvar altered_level: Dictionary=captured.level_record.duplicate(true);altered_level.payload=Codec.new().encode(duplicated).value
\t\tcheck(not graph.validate(captured.value,version,altered_level,mission_token,external).ok,label+" duplicate wave actor rejected")
'''
    assert s.count(needle)==1;s=s.replace(needle,extra+needle)
    needle='\t\taltered=captured.value.duplicate(true);altered.active_order.erase(str(b.level.lu.entity_id))'
    extra='''\t\tpayload.metadata.daming_mine.tag={"state":"expired"};altered.records[position].payload=Codec.new().encode(payload).value
\t\tvar expired_plan: Dictionary=graph.prepare(altered,version,owner,owner.map,captured.level_record,mission_token,external)
\t\tcheck(expired_plan.get("ok",false),label+" valid expired mineral tag binds through owned tombstone")
\t\tif expired_plan.get("ok",false):
\t\t\texpired_plan.identity.release_tombstones()
\t\t\tcheck(not is_instance_valid(expired_plan.id_to_unit[str(worker.entity_id)].get_meta("daming_mine")),label+" released mineral tombstone preserves expired metadata")
\t\t\texpired_plan.identity.dispose()
\t\t\tfor u in expired_plan.units_in_root_order:u.free()
'''
    assert s.count(needle)==1;s=s.replace(needle,extra+needle)
    needle='\tpaused=false;await _dispose(b)'
    extra='''\t\tvar before_gold: float=float(b.faction_res[1].gold)
\t\tb.level._support_tick(b,120.0)
\t\tcheck(not b.level.escorts.is_empty() and b.level.ai_trained>0 and float(b.faction_res[1].gold)<before_gold,"actual paid Daming support production")
\t\tif not b.level.escorts.is_empty():
\t\t\tvar escort=b.level.escorts[0];escort.take_damage(100000.0,null,false,true)
\t\t\tb.level._support_tick(b,39.0)
\t\t\tcheck(escort._dying and not b.level.escorts.has(escort),"authored dispatcher drops dying escort from pool")
\t\t\tawait _roundtrip(b,"level8 paid support dying")
'''
    assert s.count(needle)==1;s=s.replace(needle,extra+needle)
    p=p.with_name('campaign_units_v19a.gd');assert not p.exists();p.write_bytes(s.encode('utf-8'))
    p=QA/'harness/run_campaign_units_v19.py';s=p.read_text(encoding='utf-8').replace('campaign_units_v19','campaign_units_v19a')
    needle="        assert sha(ROOT/row['path'])==expected"
    new="        reviewed=read(ROOT/'qa/zhu_wounded_20261005/campaign_units_contract_review_fix_v19a.json')\n        for fix in reviewed['source_delta']:\n            if row['path']==fix['path']:expected=fix['after_sha256']\n"+needle
    assert s.count(needle)==1;s=s.replace(needle,new);ast.parse(s);p=p.with_name('run_campaign_units_v19a.py');assert not p.exists();p.write_bytes(s.encode('utf-8'))
    print(json.dumps({'reviewed_contract_fixes':3,'prepared_sibling':'v19a','engine_qualified':False}))
if __name__=='__main__':main()
