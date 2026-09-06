class_name WorkshopExamples
extends RefCounted

static func scenario() -> Dictionary:
	return {"id":"workshop_liangshan_drill", "title":"示例地图 · 水泊练兵", "subtitle":"两波小规模守卫战", "map":{"w":48,"h":48,"theme":"marsh","base":"GRASS"}, "camera_start":[24,24], "start_age":3, "economy":false, "hero_cap":4, "pop_cap":30,
		"intro":[{"who":"军令","key":"narrator","text":"守住聚义厅，击退两波官军。可以在场景编辑器中调整地形、队伍和波次。"}],
		"terrain":[{"op":"fill_rect","x":0,"y":0,"w":8,"h":48,"t":"WATER"},{"op":"paint_path","pts":[[24,24],[45,24]],"brush":2,"t":"ROAD"}],
		"deploy":[{"key":"hall","cell":[24,24],"faction":"LIANG","ref":"hall"},{"key":"song_jiang","cell":[27,23],"faction":"LIANG"},{"key":"lin_chong","cell":[27,25],"faction":"LIANG"}],
		"gates":{"E":[45,24]}, "waves":[{"delay":10,"msg":"第一队官军到来","groups":[{"key":"guan_dao","n":4,"gate":"E"}]},{"delay":10,"msg":"弓手压阵","groups":[{"key":"guan_dao","n":6,"gate":"E"},{"key":"guan_gong","n":3,"gate":"E"}]}],
		"win":[{"type":"survive_waves","msg":"练兵完成！"}], "lose":[{"type":"ref_dead","ref":"hall","msg":"聚义厅失守"}]}

static func defense() -> Dictionary:
	return {"name":"示例据守 · 两波练兵", "start_gold":250, "start_wood":150, "pop_cap":30, "hero_cap":4, "units":{}, "abilities":{},
		"waves":[{"t":10,"msg":"四面戒备","cata":0,"groups":[["guan_dao",4,0,2]]},{"t":25,"msg":"迎击弓手","cata":0,"groups":[["guan_dao",6,0,2],["guan_gong",3,1,2]]}]}
