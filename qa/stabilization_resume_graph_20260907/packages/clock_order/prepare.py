"""Lightweight source inventory and immutable isolated draft manifest; no engine."""
from pathlib import Path
import hashlib,json,re,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8',newline='\n')
assert not (HERE/'freeze.json').exists(),'Do not mutate frozen draft inputs'
patterns={'engine_frame':r'Engine\.(?:get_physics_frames|get_process_frames)\s*\(',
    'monotonic_time':r'Time\.get_ticks_(?:msec|usec)\s*\(',
    'native_callback':r'^\s*func\s+_(?:physics_process|process)\s*\(',
    'deferred':r'(?:call_deferred\s*\(|\.call_deferred\b)',
    'schedule_settings':r'(?:process_physics_priority|process_priority|process_thread_group|process_mode)\s*='}
matches={key:[] for key in patterns};sources={};count=0
for p in sorted((ROOT/'scripts').rglob('*.gd')):
    count+=1;rel=p.relative_to(ROOT).as_posix();found=False
    for number,line in enumerate(p.read_text('utf8').splitlines(),1):
        code=line.split('#',1)[0]
        for kind,pattern in patterns.items():
            if re.search(pattern,code):
                matches[kind].append({'path':rel,'line':number,'text':line.strip()});found=True
    if found:sources[rel]=sha(p)
assert len(matches['engine_frame'])==4,matches['engine_frame']
dump(HERE/'source_inventory.json',{'root_confirmed_production_head':'61f8f557cb19e5f6483f468ba3435767a2108584',
    'production_scripts_scanned':count,'matches':matches,'source_raw_sha256':sources,
    'scope':'All production scripts/*.gd recursively; lexical inventory of listed scheduling constructs, not a complete dynamic side-effect proof.'})
sys.path.insert(0,str(ROOT/'scratchpad/stabilization_identity_20260907/parser_runtime'))
from gdtoolkit.parser import parser
files=[]
for rel in ['scripts/run_simulation_clock.gd','scripts/run_step_barrier.gd']:
    candidate=HERE/'candidate'/rel;production=ROOT/rel
    assert not production.exists(),rel+' unexpectedly exists in production'
    parser.parse(candidate.read_text('utf8'),gather_metadata=True)
    files.append({'path':rel,'candidate':candidate.relative_to(ROOT).as_posix(),'candidate_sha256':sha(candidate),'before_exists':False,'before_raw_sha256':None})
parser.parse((HERE/'clock_smoke.gd').read_text('utf8'),gather_metadata=True)
dump(HERE/'overlay_manifest.json',{'status':'isolated_clock_and_scheduler_draft_native_pending','source_full_copy_required':True,
    'production_changed':False,'root_confirmed_production_head':'61f8f557cb19e5f6483f468ba3435767a2108584','files':files})
paths=['candidate/scripts/run_simulation_clock.gd','candidate/scripts/run_step_barrier.gd','clock_smoke.gd','HANDOFF.md','source_inventory.json','overlay_manifest.json','prepare.py']
dump(HERE/'freeze.json',{'status':'isolated_clock_and_scheduler_draft_frozen_native_pending','production_changed':False,
    'whole_battle_barrier':False,'root_schema_changed':False,'grammar_only':True,'inputs':{p:sha(HERE/p) for p in paths}})
print(json.dumps({'freeze':sha(HERE/'freeze.json'),'overlay':sha(HERE/'overlay_manifest.json'),'driver':sha(HERE/'clock_smoke.gd'),
    'production_scripts_scanned':count,'engine_frame_sites':len(matches['engine_frame'])},indent=2))
