"""Preserve v19b; encode Gao definition key kinds within its new Unit schema only."""
from pathlib import Path
import ast,hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'qa/zhu_wounded_20261005';BASE=ROOT.parent/'qa-ordinary-posture-20261006'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    run=BASE/'campaign_units_v19b_7845b761';rp=run/'receipt.json';r=json.loads(rp.read_text(encoding='utf-8'))
    assert not r['complete'] and r['lock_released'];report=json.loads((run/'skills/report.json').read_text(encoding='utf-8'))
    assert report['checks']==83 and len(report['failures'])==3 and len(report['runtime'])==1
    for row in r['harnesses']:assert sha(ROOT/row['path'])==row['sha256']
    for src,dst in [('receipt.json','campaign_units_failed_receipt_v19b.json'),('skills/report.json','campaign_units_failed_report_v19b.json'),('skills.log','campaign_units_failed_log_v19b.txt')]:
        p=QA/dst;assert not p.exists();shutil.copy2(run/src,p);assert sha(p)==sha(run/src)
    rejected={'qualified':False,'receipt_sha256':sha(rp),'report_sha256':sha(run/'skills/report.json'),'checks':83,'harnesses':r['harnesses'],
      'findings':['Gao Unit definition accepts StringName keys but common bounded codec rejects them; actual capture fails at setup_def key15. Keep key type, do not stringify the live definition or broaden the global codec.',
      'Daming initial61 real Units bound and recaptured exactly; both miners point to fresh minerals, invalid/false-mineral/expired tags checked. Whole batch still failed before later Daming cases.',
      'QA called nonexistent _spy_tick; installed method is _cover_tick.'],
      'next':'Sibling v19c stores bounded root setup_def key-kind entries in Level5 Unit wire representation and restores exact String/StringName kinds; old schemas/global codec unchanged. Correct QA callback name; full new execution required.'}
    p=QA/'campaign_units_rejected_v19b.json';assert not p.exists();p.write_bytes((json.dumps(rejected,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    p=ROOT/'scripts/run_unit_state.gd';before=sha(p);s=p.read_text(encoding='utf-8')
    needle='\tvar wire := values.duplicate(false)';assert s.count(needle)==1
    extra='''
\tif _unit_schema == LEVEL5_SCHEMA:
\t\t# Dictionary property assignments can add StringName keys to naval definitions.
\t\t# Only this new chapter wire shape carries key kind; the shared codec stays closed.
\t\tvar entries: Array = []
\t\tfor key in values.setup_def:
\t\t\tentries.append({"kind":"string_name" if typeof(key) == TYPE_STRING_NAME else "string","key":String(key),"value":values.setup_def[key]})
\t\twire.setup_def = {"schema":"level5_definition_keys_v1","entries":entries}'''
    s=s.replace(needle,needle+extra,1)
    needle='\tvar values := wire.duplicate(false)';assert s.count(needle)==1
    extra='''
\tif _unit_schema == LEVEL5_SCHEMA:
\t\tvar definition: Variant = wire.setup_def
\t\tif typeof(definition) != TYPE_DICTIONARY or not _fields(definition,["schema","entries"]):return _failure("LEVEL5_DEFINITION_KEYS")
\t\tif typeof(definition.schema) != TYPE_STRING or definition.schema != "level5_definition_keys_v1" or typeof(definition.entries) != TYPE_ARRAY or definition.entries.size() > 512:return _failure("LEVEL5_DEFINITION_KEYS")
\t\tvar restored: Dictionary = {}
\t\tfor entry: Variant in definition.entries:
\t\t\tif typeof(entry) != TYPE_DICTIONARY or not _fields(entry,["kind","key","value"]):return _failure("LEVEL5_DEFINITION_ENTRY")
\t\t\tif typeof(entry.kind) != TYPE_STRING or entry.kind not in ["string","string_name"] or typeof(entry.key) != TYPE_STRING or entry.key.is_empty() or entry.key.length() > 256:return _failure("LEVEL5_DEFINITION_KEY")
\t\t\tvar key: Variant = StringName(entry.key) if entry.kind == "string_name" else entry.key
\t\t\tif restored.has(key):return _failure("LEVEL5_DEFINITION_DUPLICATE_KEY")
\t\t\trestored[key] = entry.value
\t\tvalues.setup_def = restored'''
    s=s.replace(needle,needle+extra,1);p.write_bytes(s.encode('utf-8'))
    fix={'path':p.relative_to(ROOT).as_posix(),'before_sha256':before,'after_sha256':sha(p),'producer_sha256':sha(Path(__file__)),'failed_receipt_sha256':sha(rp),'scope':'Gao new Unit schema only: preserve ordered String/StringName setup_def root keys with bounded explicit entries. Common codec and previous Unit schemas untouched. Full new unit graph qualification pending.'}
    p=QA/'campaign_naval_definition_fix_v19c.json';assert not p.exists();p.write_bytes((json.dumps(fix,indent=2)+'\n').encode())
    p=QA/'harness/campaign_units_v19b.gd';s=p.read_text(encoding='utf-8').replace('_spy_tick(b,0.25)','_cover_tick(b,0.25)').replace('campaign_units_v19b','campaign_units_v19c')
    needle='\t\tif old.has_meta("daming_mine"):'
    extra='''\t\tif id=="level5":
\t\t\tvar old_keys: Array=old.setup_def.keys();var new_keys: Array=fresh.setup_def.keys();var key_types := old_keys.size()==new_keys.size()
\t\t\tfor i in range(old_keys.size()):key_types=key_types and typeof(old_keys[i])==typeof(new_keys[i]) and old_keys[i]==new_keys[i]
\t\t\tcheck(key_types and old.setup_def==fresh.setup_def,label+" ordered naval definition and key kinds preserved "+entity_id)
'''
    assert s.count(needle)==1;s=s.replace(needle,extra+needle)
    needle='\tart_runtime.append({"case":label,';a=s.index(needle);b=s.index('\n\tprepared.identity.dispose()',a)
    replacement='''\tvar snapshot_path: String=art_output.path_join(label.replace(" ","_")+"_snapshot.json")
\tvar file:=FileAccess.open(snapshot_path,FileAccess.WRITE)
\tcheck(file!=null,label+" native compact graph snapshot opened")
\tif file!=null:
\t\tfile.store_string(JSON.stringify({"source_graph":captured.value,"source_level":captured.level_record})+"\\n");file.close()
\tart_runtime.append({"case":label,"chapter":id,"units":original.size(),"snapshot_path":snapshot_path,"snapshot_sha256":FileAccess.get_sha256(snapshot_path),"scope":"Actual original Unit state/reference remapping and exact recapture. Disabled detached owner/map and explicit saved node activation flags; not complete map/clock/Mission/FX or independent world restore. Contact and stage fixtures explicit."})'''
    s=s[:a]+replacement+s[b:];p=p.with_name('campaign_units_v19c.gd');assert not p.exists();p.write_bytes(s.encode('utf-8'))
    p=QA/'harness/run_campaign_units_v19b.py';s=p.read_text(encoding='utf-8').replace('campaign_units_v19b','campaign_units_v19c')
    needle="        assert sha(ROOT/row['path'])==expected";assert s.count(needle)==1
    s=s.replace(needle,"        naval=read(ROOT/'qa/zhu_wounded_20261005/campaign_naval_definition_fix_v19c.json')\n        if row['path']==naval['path']:expected=naval['after_sha256']\n"+needle)
    needle="        for row in inputs:assert sha(ROOT/row['path'])==sha(project/row['path'])==row['sha256']";assert s.count(needle)==1
    s=s.replace(needle,"        for row in result['runtime']:assert sha(Path(row['snapshot_path']))==row['snapshot_sha256']\n"+needle)
    ast.parse(s);p=p.with_name('run_campaign_units_v19c.py');assert not p.exists();p.write_bytes(s.encode('utf-8'))
    print(json.dumps({'v19b_failure_preserved':True,'naval_key_type_fix':True,'next':'v19c','global_codec_changed':False}))
if __name__=='__main__':main()
