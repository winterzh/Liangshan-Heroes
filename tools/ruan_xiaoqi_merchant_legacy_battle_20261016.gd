extends "res://scripts/battle.gd"
## QA-only selection of the unregistered legacy Level1 implementation.
## Production map/definitions/deploy/start execute unchanged. The real mission
## service is added explicitly because policy correctly classifies this route
## as custom rather than granting it current campaign eligibility.
func _resolve_level() -> LevelBase:
	return load("res://scripts/levels/level1_huangnigang.gd").new()

func _ready() -> void:
	super._ready()
	if mission == null:
		mission = preload("res://scripts/campaign_mission.gd").new(self)
		set_meta("qa_legacy_mission_adapter",true)
