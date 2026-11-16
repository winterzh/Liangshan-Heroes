from pathlib import Path
import os
import shutil
import sys
import time
import uuid

qa = Path(__file__).resolve().parent
sys.path.insert(0, str(qa))
from prepare import common, running, read, save, sha, need

run, engine, lock = map(Path, sys.argv[1:])
old = run / 'lianhuanma_131719_3269c6ec'
batch = read(old / 'receipt.json')
source = old / 'workers'
out = run / ('drill_observation_' + uuid.uuid4().hex[:8])
out.mkdir()
workers = out / 'workers'
shutil.copytree(source, workers)
for name, expected in read(source / 'bindings.json').items():
    need(sha(workers / name) == expected, 'Worker bytes changed')
driver = workers / 'driver.gd'
raw = driver.read_text(encoding='utf8')
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
prior_path = old/'resume_training/report.json'
need(sha(prior_path) == batch['reports'][1]['sha256'], 'Original restore report changed')
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
receipt = {'scope':'restored teaching observation only', 'steps':[], 'profile':str(profile), 'source_report_sha256':sha(old/'resume_training/report.json'),
           'driver_sha256':sha(driver),'original_driver_sha256':sha(source/'driver.gd'),'source_identity':batch['source_identity']}
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

