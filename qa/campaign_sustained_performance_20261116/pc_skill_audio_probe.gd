extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures.append(detail)

func _await_tasks(tasks: Array) -> void:
	await process_frame
	var deadline := Time.get_ticks_msec() + 15000
	while tasks.any(func(id): return not WorkerThreadPool.is_task_completed(id)) and Time.get_ticks_msec() < deadline:
		await process_frame

func _run() -> void:
	var s = root.get_node("Sfx")
	AudioServer.set_bus_mute(0, true)
	_check(OS.has_feature("windows"), "Windows platform")
	var battle_script: GDScript = load("res://scripts/battle.gd")
	_check(battle_script != null and battle_script.can_instantiate(), "production Battle script compiles")
	var specs := [["wu_yong_w", "command", "rally"], ["gong_icewall", "ice", "ice_wall"], ["liu_tang_w", "blade", "smite"]]
	var tasks := []
	seed(915)
	var expect_rand := randi()
	seed(915)
	for spec in specs:
		s.prepare_ability(spec[0], spec[1], spec[2])
		var key: String = "ab_" + spec[0]
		var job: Dictionary = s._ability_preparations.get(key, {})
		_check(not job.is_empty() and not s._bank.has(key), "prepared skill is silent and does not occupy playback cache")
		if job.is_empty():
			continue
		tasks.append(job.task)
		s.prepare_ability(spec[0], spec[1], spec[2])
		_check(s._ability_preparations[key].task == job.task, "duplicate preparation reuses task")
	await _await_tasks(tasks)
	_check(randi() == expect_rand, "production skill prewarm does not advance global RNG")
	for spec in specs:
		var key: String = "ab_" + spec[0]
		var reference: PackedByteArray = s._ability_pcm(spec[0], spec[1], spec[2])
		s.play_ability(spec[0], spec[1], spec[2])
		var stream: AudioStreamWAV = s._bank[key]
		_check(stream.data == reference and stream.mix_rate == 22050 and not stream.stereo, "first cast uses the same PCM and WAV format as synchronous synthesis")
		_check(not s._ability_preparations.has(key), "used task is reaped at first actual playback")
		_check(stream.data.slice(stream.data.size() - 128).count(0) == 128, "PCM guard tail is silent")
		s.play_ability(spec[0], spec[1], spec[2])
		_check(s._bank[key] == stream, "second cast reuses the first playback stream")
	var mismatch := "style_mismatch"
	s.prepare_ability(mismatch, "fire", "fire_dot")
	await _await_tasks([s._ability_preparations["ab_" + mismatch].task])
	s.play_ability(mismatch, "ice", "bolt")
	_check(s._bank["ab_" + mismatch].data == s._ability_pcm(mismatch, "ice", "bolt"), "first actual cast decides sound when a different style had been prepared")
	var actual := "saved_mid_windup"
	s.play_ability(actual, "water", "hook")
	_check(s._bank["ab_" + actual].data == s._ability_pcm(actual, "water", "hook"), "casting after a saved windup needs no prepared task")
	var gate := Semaphore.new()
	var held := WorkerThreadPool.add_task(func() -> void: gate.wait())
	s._ability_preparations["ab_late"] = {"task": held, "kind": "rally", "theme": "holy", "pcm": []}
	s.play_ability("late", "holy", "rally")
	var fallback: AudioStreamWAV = s._bank["ab_late"]
	_check(not WorkerThreadPool.is_task_completed(held) and fallback.data == s._ability_pcm("late", "holy", "rally"), "busy worker falls back without waiting or deferring sound")
	gate.post()
	await _await_tasks([held])
	s.play_ability("late", "holy", "rally")
	_check(s._bank["ab_late"] == fallback and not s._ability_preparations.has("ab_late"), "late task never overwrites a synchronously generated stream")
	s.enabled = false
	s.prepare_ability("muted", "fire", "fire_dot")
	s.play_ability("muted", "fire", "fire_dot")
	_check(not s._ability_preparations.has("ab_muted") and not s._bank.has("ab_muted"), "disabled effects do not queue or build audio")
	s.enabled = true
	s.prepare_ability("drain", "fire", "fire_dot")
	_check(s._ability_preparations.size() == 1, "shutdown precondition has one queued task")
	s.shutdown()
	_check(s._ability_preparations.is_empty() and s._bank.is_empty() and s._players.is_empty(), "shutdown drains tasks and clears playback")
	root.get_node("Music").shutdown()
	var report := {"checks": checks, "failures": failures}
	print("PC_SKILL_AUDIO_RESULT ", JSON.stringify(report))
	var file := FileAccess.open(OS.get_environment("LSH_SKILL_AUDIO_REPORT"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	quit(0 if failures.is_empty() else 1)
