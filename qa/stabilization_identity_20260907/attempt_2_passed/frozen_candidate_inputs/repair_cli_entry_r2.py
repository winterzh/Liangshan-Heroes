"""Repair only first native QA entry's eager game-class load; preserve prior freeze."""
from pathlib import Path
import hashlib,json,runpy,sys
HERE=Path(__file__).resolve().parent
archive=HERE/'attempt_history'/'first_entry_compile_failure'
archive.mkdir(parents=True,exist_ok=False)
for name in ('identity_smoke.gd','harness_receipt.json','freeze.json','prepare_harness.py','failure_cases.gd.inc','HANDOFF.md'):
    (archive/name).write_bytes((HERE/name).read_bytes())
p=HERE/'failure_cases.gd.inc'
s=p.read_text('utf8').replace('var map: GameMap','var map: Variant').replace('-> Unit:', '-> Variant:')
p.write_text(s,encoding='utf8',newline='\n')
p=HERE/'prepare_harness.py';s=p.read_text('utf8')
marker="s=one(s,'res://scratchpad/run_unit_graph/unit_graph.gd','res://scripts/run_unit_graph.gd')\n"
assert s.count(marker)==1
s=s.replace(marker,marker+'''s=one(s,'const Graph := preload("res://scripts/run_unit_graph.gd")\\n','')
s=one(s,'\\tvar graph: Variant = Graph.new(', '\\tvar graph_script: Script = load("res://scripts/run_unit_graph.gd")\\n\\tvar graph: Variant = graph_script.new(')
''')
p.write_text(s,encoding='utf8',newline='\n')
sys.path.insert(0,str(HERE));runpy.run_path(str(p),run_name='__main__')
sys.path.insert(0,str(HERE/'parser_runtime'))
from gdtoolkit.parser import parser
driver=(HERE/'identity_smoke.gd').read_text('utf8')
parser.parse(driver,gather_metadata=True)
assert 'preload(' not in driver and ': GameMap' not in driver and '-> Unit' not in driver
receipt=json.loads((HERE/'harness_receipt.json').read_text('utf8'))
receipt.update(status='entry_r2_parser_pass_native_pending',prior_native_attempt='.godot/stabilization_identity/identity_20260907T061258Z_551411d4',
    prior_native_result='CLI eager class compilation failed: Art/Sfx unresolved, behavior suite did not pass',
    fix='Graph load deferred until _run; test-only RejectBattle map/return signatures Variant; 24 overlay scripts unchanged')
(HERE/'harness_receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf8',newline='\n')
with (HERE/'HANDOFF.md').open('a',encoding='utf8',newline='\n') as f:
    f.write('\n## CLI entry revision 2\n\nFirst native attempt `identity_20260907T061258Z_551411d4` failed before behavioral validation: entry preload and test-only typed signatures compiled game classes before Art/Sfx autoload availability. Prior driver/receipts are retained under `attempt_history/first_entry_compile_failure`. Revision 2 defers Graph load inside `_run` and removes production-class annotations only from RejectBattle. All 24 overlay scripts remain frozen. Parser passes; native rerun pending.\n')
freeze=json.loads((HERE/'freeze.json').read_text('utf8'))
freeze.update(status='frozen_for_second_godot_attempt_entry_only_fix',engine_run=True,engine_validation_passed=False,
    previous_freeze_sha256=hashlib.sha256((archive/'freeze.json').read_bytes()).hexdigest())
for name in list(freeze['inputs']):freeze['inputs'][name]=hashlib.sha256((HERE/name).read_bytes()).hexdigest()
freeze['inputs']['repair_cli_entry_r2.py']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
(HERE/'freeze.json').write_text(json.dumps(freeze,ensure_ascii=False,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps({'freeze_sha256':hashlib.sha256((HERE/'freeze.json').read_bytes()).hexdigest(),'driver_sha256':freeze['inputs']['identity_smoke.gd'],'receipt_sha256':freeze['inputs']['harness_receipt.json'],'source_receipt_sha256':freeze['inputs']['source_receipt.json'],'candidate_patch_sha256':freeze['inputs']['candidate.patch']},indent=2))
