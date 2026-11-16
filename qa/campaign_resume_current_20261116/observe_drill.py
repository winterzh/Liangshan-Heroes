from pathlib import Path
import argparse
import os
import shutil
import sys
import time
import uuid

qa = Path(__file__).resolve().parent
sys.path.insert(0, str(qa))
from prepare import common, running, read, save, sha, need

parser = argparse.ArgumentParser(description='Observe the actual restored drill on an isolated save copy.')
parser.add_argument('run', type=Path)
parser.add_argument('engine', type=Path)
parser.add_argument('lock', type=Path)
parser.add_argument('--batch', default='lianhuanma_131719_3269c6ec')
parser.add_argument('--resave-tail')
parser.add_argument('--current-strategy', action='store_true',
                    help='Observe the current pinned ordinary-order strategy on the same save copy.')
args = parser.parse_args()
run, engine, lock = args.run, args.engine, args.lock
old = run / args.batch
batch = read(old / 'receipt.json')
resave = read(run / args.resave_tail / 'receipt.json') if args.resave_tail else batch
if args.resave_tail:
    need(resave['previous_batch'] == str(old) and resave['previous_receipt_sha256'] == sha(old / 'receipt.json')
         and resave['profile'] == batch['profile'] and resave['source_identity'] == batch['source_identity'],
         'Resave tail belongs to a different batch')
prior_row, = [row for row in resave['reports'] if row['mode'] == 'resume_training' and row['passed']]
prior_path = Path(prior_row['path'])
need(sha(prior_path) == prior_row['sha256'], 'Original restore report changed')
source = old / 'workers'
out = run / ('drill_observation_' + uuid.uuid4().hex[:8])
out.mkdir()
workers = out / 'workers'
shutil.copytree(source, workers)
for name, expected in read(source / 'bindings.json').items():
    need(sha(workers / name) == expected, 'Worker bytes changed')
driver = workers / 'driver.gd'
if args.current_strategy:
    import run_lianhuanma as host
    host.worker_pins()
    shutil.copyfile(qa / 'workers/driver.gd', driver)
strategy_sha = sha(driver)
raw = driver.read_text(encoding='utf8')
lure_wait = '\tif not check(await wait_live(func(): return level.drill_entered and level.drill_lure == lure, 55.0), "ordinary non-hook infantry actually enters lure radius"): return false'
lure_trace = '''	var last_lure_tick := {"value": -600}
	var check_lure := func() -> bool:
		if battle._run_clock._next_tick >= last_lure_tick.value + 120:
			observe_lure(level, lure)
			last_lure_tick.value = battle._run_clock._next_tick
		return level.drill_entered and level.drill_lure == lure
	var entered := await wait_live(check_lure, 55.0)
	observe_lure(level, lure)
	if not check(entered, "ordinary non-hook infantry actually enters lure radius"): return false'''
need(raw.count(lure_wait) == 1, 'Lure wait mismatch')
raw = raw.replace(lure_wait, lure_trace)
old_call = '\tpolicy.target(battle, [instructor, hook], level.dummy, "drill_attack")\n\tif not check(await wait_live(func(): return level.drill_complete, 45.0), "real two-person attacks complete optional teaching"): return false'
new_call = '''	var practice: Variant = level.dummy
	observations["drill_samples"] = []
	observe_drill("before_order", practice, [instructor, hook])
	policy.target(battle, [instructor, hook], practice, "drill_attack")
	observe_drill("after_order", practice, [instructor, hook])
	var previous_state := ""
	var last_sample := -600
	var observe_complete := func() -> bool:
		var tick: int = battle._run_clock._next_tick
		var state: String = str(practice.hp) + "/" + practice.story_outcome + "/" + str(level.drill_coordinated)
		if state != previous_state or tick >= last_sample + 300:
			observe_drill("simulation", practice, [instructor, hook])
			previous_state = state
			last_sample = tick
		return level.drill_complete
	if not check(await wait_live(observe_complete, 45.0), "real two-person attacks complete optional teaching"): return false'''
# Lambda capture is by value in GDScript. Use a dictionary for shared sampling state.
new_call = new_call.replace('var previous_state := ""\n\tvar last_sample := -600','var sample := {"previous": "", "last": -600}').replace('state != previous_state or tick >= last_sample + 300','state != sample.previous or tick >= int(sample.last) + 300').replace('previous_state = state','sample.previous = state').replace('last_sample = tick','sample.last = tick')
need(raw.count(old_call) == 1, 'Drill call mismatch')
raw = raw.replace(old_call, new_call)
stop = '\tif not await natural_drill(): return\n'
need(raw.count(stop) == 1, 'Stop boundary mismatch')
raw = raw.split(stop)[0] + '''	stage_completed = await natural_drill()

func observe_lure(level: Variant, intended: Variant) -> void:
	var accepted: Variant = level.drill_lure
	var dummy: Variant = level.dummy
	var row := {"tick": battle._run_clock._next_tick, "entered": level.drill_entered,
		"accepted_id": accepted.entity_id if is_instance_valid(accepted) else 0,
		"accepted_key": accepted.key if is_instance_valid(accepted) else "",
		"intended_id": intended.entity_id, "intended_hp": intended.hp,
		"intended_position": str(intended.position), "intended_state": intended._state,
		"path_index": intended._path_i, "path_size": intended._path.size(),
		"dummy_position": str(dummy.position) if is_instance_valid(dummy) else "",
		"distance": intended.position.distance_to(dummy.position) if is_instance_valid(dummy) else -1.0}
	if not observations.has("lure_samples"): observations["lure_samples"] = []
	observations.lure_samples.append(row)
	print("LURE_OBSERVATION ", JSON.stringify(row))

func observe_drill(label: String, dummy: Variant, actors: Array) -> void:
	var point: Vector2 = battle.to_screen(dummy.position)
	var clicked: Variant = battle._enemy_at(point)
	var garrison: Variant = battle._garrisonable_at(point)
	var team: Array = battle.level._hook_team(battle, dummy)
	var rows: Array = []
	for u: Variant in actors:
		rows.append({"id": u.entity_id, "hp": u.hp, "position": str(u.position),
			"target": u._target.entity_id if is_instance_valid(u._target) else 0,
			"state": u._state, "distance": u.position.distance_to(dummy.position),
			"reach": u.atk_range + u.radius + dummy.radius + 8.0, "in_hook_team": team.has(u),
			"line_open": battle.map._segment_open(u.position, dummy.position, u.movement_profile)})
	var sample := {"label": label, "tick": battle._run_clock._next_tick,
		"dummy": dummy.entity_id, "dummy_hp": dummy.hp, "dummy_position": str(dummy.position),
		"dummy_outcome": dummy.story_outcome, "clicked_enemy": clicked.entity_id if is_instance_valid(clicked) else 0,
		"garrison_target": garrison.entity_id if is_instance_valid(garrison) else 0,
		"visible": battle.is_visible_world(dummy.position), "coordinated": battle.level.drill_coordinated,
		"complete": battle.level.drill_complete, "actors": rows}
	observations.drill_samples.append(sample)
	print("DRILL_OBSERVATION ", JSON.stringify(sample))
'''
driver.write_text(raw, encoding='utf8', newline='\n')
(workers/'bindings.json').unlink()
save(workers/'bindings.json', {name: sha(workers/name) for name in ('bootstrap.gd', 'base.gd', 'terminal.gd', 'policy.gd', 'driver.gd')})
profile = Path(batch['profile']).with_name('drill_' + uuid.uuid4().hex[:8])
profile.mkdir()
shutil.copytree(Path(batch['profile'])/'appdata',profile/'appdata')
for name in ('localappdata','temp','tmp'):
    (profile/name).mkdir()
prior = read(prior_path)
old_prefix = Path(batch['profile']).as_posix() + '/'
new_prefix = profile.as_posix() + '/'


def rebase_profile_paths(value):
    if isinstance(value, dict):
        return {key: rebase_profile_paths(item) for key, item in value.items()}
    if isinstance(value, list):
        return [rebase_profile_paths(item) for item in value]
    if isinstance(value, str) and value.startswith(old_prefix):
        return new_prefix + value[len(old_prefix):]
    return value


prior = rebase_profile_paths(prior)
prior['profile'] = str(profile)
save(out/'predecessor_rebound.json', prior)
env = os.environ.copy()
for key in list(env):
    if key.startswith(('LSH_', 'LT_')) or key.endswith(('_QA', '_TEST', '_AUDIT')) or key in ('LEVEL','SKIRMISH','SKIRMISH_AI','ARENA','CUSTOM_DEFENSE','SCENARIO','AUTO_MICRO','AUTOMICRO'):
        env.pop(key)
for key in ('APPDATA','LOCALAPPDATA','TEMP','TMP'):
    env[key] = str(profile / key.lower())
project = run/'project'
env.update(STEAM_DISABLED='1', CAMPAIGN_QA='', LSH_CONTINUE_FLOW_QA='1', LSH_CONTINUE_FLOW_PROFILE=str(profile), LSH_LANGUAGE='zh_CN',
           LT_PROFILE=str(profile), LT_PROJECT=str(project), LT_WORKERS=str(workers),
           LT_BINDINGS=str(workers/'bindings.json'), LT_BINDINGS_SHA256=sha(workers/'bindings.json'),
           LT_NONCE=batch['batch_nonce'], LT_CANDIDATE_SHA256=batch['manifest_sha256'],
           LT_PROVENANCE_SHA256=sha(qa/'workers/provenance.json'),
           LT_MODE='resume_victory', LT_REPORT=str(out/'report.json'), LT_PROCESS_NONCE=uuid.uuid4().hex,
           LT_PREVIOUS=str(out/'predecessor_rebound.json'), LT_PREVIOUS_SHA256=sha(out/'predecessor_rebound.json'))
receipt = {'scope':'restored teaching observation only', 'steps':[], 'profile':str(profile), 'source_report_sha256':sha(prior_path),
           'driver_sha256':sha(driver),'original_driver_sha256':sha(source/'driver.gd'),
           'strategy_sha256':strategy_sha, 'source_identity':batch['source_identity']}
print(str(out), flush=True)
start = time.monotonic()
while running():
    need(time.monotonic()-start < 180, 'Engine remains occupied')
    time.sleep(2)
with lock.open('x',encoding='utf8') as f:
    f.write(str(out))
try:
    common.process_step(engine, project, env, out, 'drill',
                        ['--resolution','1280x720','--position','30000,30000','--script',str(workers/'bootstrap.gd')],
                        480,'gl_compatibility',running,receipt['steps'])
except RuntimeError as e:
    receipt['error']=str(e)
finally:
    receipt['lock_released'] = common.release_owned_lock(lock, out, receipt, running())
    save(out/'receipt.json',receipt)

