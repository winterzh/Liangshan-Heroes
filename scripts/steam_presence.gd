extends Node
## Steam 好友状态（Rich Presence）：模式、关卡、据守波次、暂停状态，四语文本。

signal changed

const PRESENCE_STRINGS := {
	"主菜单": {"zh_CN": "主菜单", "zh_TW": "主選單", "en": "Main menu", "ja": "メインメニュー"},
	"正在 %s": {"zh_CN": "正在 %s", "zh_TW": "正在 %s", "en": "Playing %s", "ja": "%s をプレイ中"},
	"正在战役": {"zh_CN": "正在战役", "zh_TW": "正在戰役", "en": "Playing campaign", "ja": "キャンペーンをプレイ中"},
	"据守梁山": {"zh_CN": "据守梁山", "zh_TW": "據守梁山", "en": "Defending Liangshan", "ja": "梁山を防衛中"},
	"据守梁山 · 第 %d/%d 波": {"zh_CN": "据守梁山 · 第 %d/%d 波", "zh_TW": "據守梁山 · 第 %d/%d 波", "en": "Defending Liangshan · Wave %d/%d", "ja": "梁山を防衛中 · 第 %d/%d 波"},
	"据守梁山 · 第 %d 波": {"zh_CN": "据守梁山 · 第 %d 波", "zh_TW": "據守梁山 · 第 %d 波", "en": "Defending Liangshan · Wave %d", "ja": "梁山を防衛中 · 第 %d 波"},
	"遭遇战": {"zh_CN": "遭遇战", "zh_TW": "遭遇戰", "en": "Skirmish", "ja": "遭遇戦"},
	"AI 对战": {"zh_CN": "AI 对战", "zh_TW": "AI 對戰", "en": "AI match", "ja": "AI対戦"},
	"竞技场": {"zh_CN": "竞技场", "zh_TW": "競技場", "en": "Arena", "ja": "アリーナ"},
	"自定义关卡": {"zh_CN": "自定义关卡", "zh_TW": "自訂關卡", "en": "Custom scenario", "ja": "カスタムシナリオ"},
	"自定义据守": {"zh_CN": "自定义据守", "zh_TW": "自訂據守", "en": "Custom defense", "ja": "カスタム防衛"},
	"水浒英雄传": {"zh_CN": "水浒英雄传", "zh_TW": "水滸英雄傳", "en": "Liangshan Heroes", "ja": "水滸英雄伝"},
	"已暂停": {"zh_CN": "已暂停", "zh_TW": "已暫停", "en": "Paused", "ja": "一時停止"},
}

const LOCALES := ["zh_CN", "zh_TW", "en", "ja"]

var status := "好友状态未连接"
var ready := false
var _last_key := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SteamService.initialized.connect(_attach)
	if SteamService.available:
		_attach()

func _attach() -> void:
	if SteamRunPolicy.test_environment() or not SteamService.available or not SteamService.ensure_account():
		return
	ready = true
	status = Localize.text("好友状态已就绪")
	set_presence({"mode": "menu"})
	changed.emit()

func set_presence(context: Dictionary) -> void:
	if not ready or not SteamService.ensure_account():
		return
	var lines := _build_keys(context)
	var fingerprint := JSON.stringify(lines)
	if fingerprint == _last_key:
		return
	_last_key = fingerprint
	var native: Object = SteamService.native
	if native == null:
		return
	native.call("clearRichPresence")
	for key in lines:
		native.call("setRichPresence", key, String(lines[key]))
	native.call("setRichPresence", "steam_display", "#Status")
	changed.emit()

func clear_presence() -> void:
	if not ready or SteamService.native == null:
		return
	_last_key = ""
	SteamService.native.call("clearRichPresence")
	changed.emit()

func _build_keys(context: Dictionary) -> Dictionary:
	var mode := String(context.get("mode", "menu"))
	var level_id := String(context.get("level_id", ""))
	var level_title := String(context.get("level_title", ""))
	var wave := int(context.get("wave", 0))
	var wave_total := int(context.get("wave_total", 0))
	var paused := bool(context.get("paused", false))
	var keys := {"mode": mode, "paused": "1" if paused else "0"}
	for locale in LOCALES:
		keys["status_" + locale] = _status_for(locale, mode, level_title, wave, wave_total, paused)
	keys["status"] = String(keys.get("status_" + Localize.locale, keys.get("status_en", "Liangshan Heroes")))
	if level_id != "":
		keys.level = level_id
	if wave > 0:
		keys.wave = str(wave)
		if wave_total > 0:
			keys.wave_total = str(wave_total)
	return keys

func _status_for(locale: String, mode: String, level_title: String, wave: int, wave_total: int, paused: bool) -> String:
	var body := _body_for(locale, mode, level_title, wave, wave_total)
	if not paused:
		return body
	return _t(locale, "已暂停") + " · " + body

func _body_for(locale: String, mode: String, level_title: String, wave: int, wave_total: int) -> String:
	match mode:
		"menu":
			return _t(locale, "主菜单")
		"campaign":
			if level_title != "":
				return _t(locale, "正在 %s") % level_title
			return _t(locale, "正在战役")
		"defense":
			if wave > 0 and wave_total > 0:
				return _t(locale, "据守梁山 · 第 %d/%d 波") % [wave, wave_total]
			if wave > 0:
				return _t(locale, "据守梁山 · 第 %d 波") % wave
			return _t(locale, "据守梁山")
		"skirmish":
			return _t(locale, "遭遇战")
		"ai":
			return _t(locale, "AI 对战")
		"arena":
			return _t(locale, "竞技场")
		"scenario":
			return _t(locale, "自定义关卡")
		"custom_defense":
			return _t(locale, "自定义据守")
		_:
			return _t(locale, "水浒英雄传")

func _t(locale: String, source: String) -> String:
	var entry: Variant = PRESENCE_STRINGS.get(source, {})
	if entry is Dictionary and entry.has(locale):
		return String(entry[locale])
	return source

func _exit_tree() -> void:
	clear_presence()

func level_title(level_id: String) -> String:
	var campaign := get_node_or_null("/root/Campaign")
	if campaign == null:
		return level_id
	for entry in campaign.LEVELS:
		if String(entry.id) == level_id:
			return String(entry.title)
	return level_id
