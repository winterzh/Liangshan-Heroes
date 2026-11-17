extends "res://qa/campaign_counter_window_20261116/menu_resume/probe.gd"

const PlayerSession := preload("res://qa/campaign_short_player_continue_20261117/player_session.gd")
const EXPECTED_GOALS := 4

func _run() -> void:
	stage = OS.get_environment("SHORT_PLAYER_STAGE")
	if not PlayerSession.is_isolated():
		quit(2)
		return
	flow = root.get_node("ContinueFlow")
	if not await PlayerSession.prepare(self):
		_finish()
		return
	match stage:
		"save": await _save()
		"resume": await _resume()
		"reject": await PlayerSession.reject_settled(self, CONTEXT.level_id, HANDOFF, EXPECTED_GOALS)
		_:
			check(false,"known stage")
			_finish()

func _finish() -> void:
	await PlayerSession.finish(self, CONTEXT.level_id, EXPECTED_GOALS)
