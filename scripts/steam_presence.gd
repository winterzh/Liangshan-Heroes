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
const RETRY_SECONDS := 5.0

var status := "好友状态未连接"
var presence_ready := false
var _last_key := ""
var _context: Dictionary = {}
var _bound_account := ""
var _native: Object
var _retry_pending := false
var _retry_after := 0.0
var _account_tick := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SteamService.initialized.connect(_attach)
	SteamService.changed.connect(_on_service_changed)
	Localize.language_changed.connect(_on_language_changed)
	if SteamService.available:
		_attach()

func _attach() -> void:
	if SteamRunPolicy.test_environment() or not SteamService.available or not SteamService.ensure_account():
		return
	clear_presence()
	_bound_account = SteamService.account
	_native = SteamService.native
	presence_ready = true
	status = Localize.text("好友状态已就绪")
	set_presence({"mode": "menu"})
	changed.emit()

func set_presence(context: Dictionary) -> void:
	if not _account_valid():
		return
	_context = context.duplicate(true)
	_publish()

func _publish() -> void:
	if not _account_valid() or _context.is_empty():
		return
	var lines := _build_keys(_context)
	# This token REQUIRES the published Steamworks localization mapping in
	# tools/contracts/steam/rich_presence.vdf. `status` is not a display fallback.
	lines["steam_display"] = "#Status"
	var fingerprint := JSON.stringify(lines)
	if fingerprint == _last_key:
		return
	_native.call("clearRichPresence")
	for key in lines:
		if not bool(_native.call("setRichPresence", key, String(lines[key]))):
			# Never cache failed/partial writes as successfully published. Clear the
			# partial display, then retry the latest context without another event.
			_native.call("clearRichPresence")
			_last_key = ""
			_retry_pending = true
			_retry_after = RETRY_SECONDS
			return
	_last_key = fingerprint
	_retry_pending = false
	_retry_after = 0.0
	changed.emit()

func clear_presence() -> void:
	_last_key = ""
	_context.clear()
	_retry_pending = false
	_retry_after = 0.0
	if is_instance_valid(_native):
		_native.call("clearRichPresence")
	changed.emit()

func _account_valid() -> bool:
	if not presence_ready:
		return false
	if not SteamService.ensure_account() or SteamService.account != _bound_account or SteamService.native != _native:
		_detach()
		return false
	return true

func _detach() -> void:
	presence_ready = false
	clear_presence()
	_bound_account = ""
	_native = null
	_account_tick = 0.0
	status = Localize.text("好友状态未连接")

func _on_service_changed() -> void:
	if presence_ready and (not SteamService.available or SteamService.account != _bound_account or SteamService.native != _native):
		_detach()

func _on_language_changed(_locale: String) -> void:
	if presence_ready:
		_publish()

func _process(delta: float) -> void:
	# No polling or context allocation at all in ordinary/non-Steam launches.
	if not presence_ready:
		return
	_account_tick += delta
	if _account_tick >= 1.0:
		_account_tick = 0.0
		if not _account_valid():
			return
	if _retry_pending:
		_retry_after -= delta
		if _retry_after <= 0.0:
			_publish()

func _build_keys(context: Dictionary) -> Dictionary:
	var mode := String(context.get("mode", "menu"))
	var level_id := String(context.get("level_id", ""))
	var wave := int(context.get("wave", 0))
	var wave_total := int(context.get("wave_total", 0))
	var paused := bool(context.get("paused", false))
	var keys := {"mode": mode, "paused": "1" if paused else "0"}
	for locale in LOCALES:
		var title := level_title(level_id, locale) if mode == "campaign" else ""
		keys["status_" + locale] = _status_for(locale, mode, title, wave, wave_total, paused)
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

func level_title(level_id: String, locale := "") -> String:
	var campaign := get_node_or_null("/root/Campaign")
	if campaign == null:
		return level_id
	for entry in campaign.LEVELS:
		if String(entry.id) == level_id:
			var source := String(entry.title)
			var target_locale := Localize.locale if locale.is_empty() else locale
			# Query each catalog directly; do not change the game's global locale
			# while constructing the other three friends-list language variants.
			var translation := TranslationServer.get_translation_object(target_locale)
			if translation != null:
				var translated := String(translation.get_message(source))
				if not translated.is_empty():
					return translated
			return source
	return level_id
