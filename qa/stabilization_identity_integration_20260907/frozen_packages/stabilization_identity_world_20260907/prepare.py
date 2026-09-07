"""Freeze driver + original 24 candidate paths; no production mutations or engine."""
from pathlib import Path
import json,hashlib,re,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
IDENTITY=ROOT/'scratchpad/stabilization_identity_20260907'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8',newline='\n')
data=json.loads((IDENTITY/'source_receipt.json').read_text('utf8'))
rows=[]
for row in data['files']:
    original=ROOT/row['path'];candidate=IDENTITY/'candidate'/row['path']
    assert sha(original)==row['before_raw_sha256'],row['path']
    assert sha(candidate)==row['candidate_sha256'],row['path']
    rows.append({'path':row['path'],'candidate':candidate.relative_to(ROOT).as_posix(),'candidate_sha256':sha(candidate),
                 'before_exists':True,'before_raw_sha256':sha(original)})
dump(HERE/'overlay_manifest.json',{'files':rows,'candidate_count':24,'production_changed':False,
    'scope':'Only frozen identity candidates','native_component_evidence':'qa/stabilization_identity_20260907/attempt_2_passed/receipt.json'})
source_paths=['scripts/battle.gd','scripts/campaign.gd','scripts/settings.gd','scripts/android_updater.gd','scripts/hud.gd']
blocked=set()
for name in source_paths:
    blocked.update(re.findall(r'OS\.get_environment\("([^"]+)"\)',(ROOT/name).read_text('utf8')))
blocked.discard('STEAM_DISABLED')
blocked.discard('RUN_RESTORE_QA_MANIFEST')
dump(HERE/'launch_contract.json',{'cases':['defense30']+['level'+str(i) for i in range(1,9)],
    'process_per_case':True,'set_environment':{'STEAM_DISABLED':'1'},'clear_environment':sorted(blocked),
    'manifest_required':['run_id','case_id','private_user','report','source_sha256','engine_binary_sha256'],
    'minimum_completed_battle_physics_callbacks':120,'entry':'res://tools/stabilization_identity_world/world_smoke.gd',
    'recommended_host_case_timeout_seconds':150,'production_source_sha256':{p:sha(ROOT/p) for p in source_paths}})
sys.path.insert(0,str(IDENTITY/'parser_runtime'))
from gdtoolkit.parser import parser
s=(HERE/'world_smoke.gd').read_text('utf8')
parser.parse(s,gather_metadata=True)
assert 'preload(' not in s and ': Unit' not in s and ': GameMap' not in s
assert not re.search(r'battle\.phase\s*=([^=])',s)
assert 'spawn_unit(' not in s and 'spawn_at(' not in s and 'take_damage(' not in s
assert all('await ' in x for x in s.splitlines() if '_finish(' in x and not x.startswith('func '))
dump(HERE/'static_review.json',{'status':'PASS','native_tested':False,'cases':9,'identity_candidates_changed':False,
    'checks':['24 raw source and frozen candidate SHA','deferred CLI game-script loads','GDScript grammar',
        'normal production main scene/new RNG API','no direct spawns/phase writes/damage injection',
        'asynchronous deferred scene cleanup','per-case private manifest contract']})
inputs=['world_smoke.gd','prepare.py','HANDOFF.md','overlay_manifest.json','launch_contract.json','static_review.json']
dump(HERE/'freeze.json',{'status':'frozen_native_pending','production_changed':False,'engine_run':False,
    'inputs':{p:sha(HERE/p) for p in inputs}})
print(json.dumps({'freeze_sha256':sha(HERE/'freeze.json'),'driver_sha256':sha(HERE/'world_smoke.gd'),
    'overlay_sha256':sha(HERE/'overlay_manifest.json'),'launch_contract_sha256':sha(HERE/'launch_contract.json')},indent=2))
