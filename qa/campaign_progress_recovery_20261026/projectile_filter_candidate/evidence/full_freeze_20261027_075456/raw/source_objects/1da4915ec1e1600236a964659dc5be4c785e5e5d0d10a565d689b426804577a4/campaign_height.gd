extends "res://scripts/liangshan_height.gd"
const Config := preload("res://scripts/campaign_environment.gd")
var style := ""

func _profile(p: Vector2) -> float:
	return Config.height_profile(style,p,width-1,height-1)
