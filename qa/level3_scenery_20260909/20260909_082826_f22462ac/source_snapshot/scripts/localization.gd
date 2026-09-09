extends Node
## Display-only localization. Source keys are the existing Simplified Chinese text;
## identifiers, saves, scenario names and gameplay values remain unchanged.

signal language_changed(locale: String)

const CATALOG_PATH := "res://assets/localization/catalog.json"
const PREFERENCE_PATH := "user://language.cfg"
const LOCALES := ["zh_CN", "zh_TW", "en", "ja"]
const LANGUAGE_NAMES := ["简体中文", "繁體中文", "English", "日本語"]

var locale := "zh_CN"
var _test_override := false
var _translations: Array[Translation] = []
var _bindings: Dictionary = {}
var _display_sources: Dictionary = {}
var _formatted_sources: Dictionary = {}
const FORMAT_HISTORY_LIMIT := 512


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_catalog()
	var preference := ConfigFile.new()
	var selected := ""
	if preference.load(PREFERENCE_PATH) == OK:
		var saved: Variant = preference.get_value("language", "locale", "")
		if saved is String and saved in LOCALES:
			selected = saved
	if selected.is_empty():
		selected = normalize_locale(OS.get_locale())
	var forced := OS.get_environment("LSH_LANGUAGE").strip_edges()
	_test_override = not forced.is_empty()
	if _test_override:
		selected = normalize_locale(forced)
	set_language(selected, false)


## Explicit script wins over region: zh-Hans-TW still means Simplified Chinese.
func normalize_locale(value: String) -> String:
	var parts := value.replace("-", "_").to_lower().split("_", false)
	if parts.is_empty():
		return "en"
	if parts[0] == "zh":
		if "hant" in parts:
			return "zh_TW"
		if "hans" in parts:
			return "zh_CN"
		return "zh_TW" if "tw" in parts or "hk" in parts or "mo" in parts else "zh_CN"
	if parts[0] == "ja":
		return "ja"
	return "en"


func set_language(value: String, persist := true) -> bool:
	if value not in LOCALES:
		return false
	var changed := locale != value or TranslationServer.get_locale() != value
	locale = value
	UITheme.apply_language_font(locale)
	TranslationServer.set_locale(locale)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title(text(String(ProjectSettings.get_setting("application/config/name"))))
	if persist and not _test_override:
		var preference := ConfigFile.new()
		preference.set_value("language", "locale", locale)
		var error := preference.save(PREFERENCE_PATH)
		if error != OK:
			push_warning("Could not save language preference: %s" % error_string(error))
	if changed:
		_refresh_bindings()
		language_changed.emit(locale)
	return true


func text(source: String) -> String:
	return String(TranslationServer.translate(source))


## Translate the template before substitution. Argument ordering and numeric types
## are preserved. Pass false for translate_arguments when args contain player text.
func format_text(source: String, args: Variant, translate_arguments := true) -> String:
	var localized_args: Variant = args
	if translate_arguments:
		if args is Array or args is PackedStringArray:
			var values: Array = []
			for value in args:
				values.append(text(String(value)) if value is String or value is StringName else value)
			localized_args = values
		elif args is String or args is StringName:
			localized_args = text(String(args))
	var result := text(source) % localized_args
	# A message may reach a display binding after it has already been formatted.
	# Retain its template and plain values, never a Unit or a gameplay callback.
	var values: Variant = args.duplicate(true) if args is Array or args is Dictionary else args
	if translate_arguments:
		if values is Array or values is PackedStringArray:
			var canonical: Array = []
			for value in values:
				canonical.append(_display_sources.get(String(value), value) if value is String or value is StringName else value)
			values = canonical
		elif values is String or values is StringName:
			values = _display_sources.get(String(values), values)
	_formatted_sources[result] = {"source": source, "args": values, "translate_arguments": translate_arguments}
	if _formatted_sources.size() > FORMAT_HISTORY_LIMIT:
		_formatted_sources.erase(_formatted_sources.keys()[0])
	return result


## Bind only intentional display properties; no scene scans or per-frame matching.
func bind_text(target: Object, source: String, property: StringName = &"text", suffix := "") -> void:
	var descriptor: Dictionary
	if _formatted_sources.has(source):
		descriptor = _formatted_sources[source].duplicate(true)
	else:
		descriptor = {"source": _display_sources.get(source, source)}
	descriptor["suffix"] = suffix
	_bind(target, property, descriptor)


## Refresh already rendered, recent built-in log text; never apply to player input.
func current_text(display: String) -> String:
	if _formatted_sources.has(display):
		var descriptor: Dictionary = _formatted_sources[display]
		return format_text(descriptor["source"], descriptor["args"], descriptor["translate_arguments"])
	return text(_display_sources.get(display, display))


func bind_format(target: Object, source: String, args: Variant, property: StringName = &"text", translate_arguments := true) -> void:
	var kept_args: Variant = args.duplicate(true) if args is Array or args is Dictionary else args
	_bind(target, property, {"source": source, "args": kept_args, "translate_arguments": translate_arguments})


## A display builder is useful for joined help text or several translated fragments.
## Keep it free of gameplay side effects; it runs only on binding or language change.
func bind_render(target: Object, render: Callable, property: StringName = &"text") -> void:
	_bind(target, property, {"render": render})


func unbind(target: Object, property: StringName = &"text") -> void:
	if is_instance_valid(target):
		_bindings.erase(_binding_key(target, property))


func create_selector() -> OptionButton:
	var selector := OptionButton.new()
	selector.name = "LanguageSelector"
	selector.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	selector.tooltip_text = "语言 / Language / 言語"
	selector.custom_minimum_size = Vector2(168, 36)
	selector.add_theme_font_size_override("font_size", 17)
	for language_name in LANGUAGE_NAMES:
		selector.add_item(language_name)
	selector.select(LOCALES.find(locale))
	selector.item_selected.connect(func(index: int) -> void: set_language(LOCALES[index]))
	var sync_selection := func(value: String) -> void:
		if is_instance_valid(selector):
			selector.select(LOCALES.find(value))
	language_changed.connect(sync_selection)
	selector.tree_exiting.connect(func() -> void: language_changed.disconnect(sync_selection), CONNECT_ONE_SHOT)
	return selector


func _load_catalog() -> void:
	if not FileAccess.file_exists(CATALOG_PATH):
		push_warning("Localization catalog is missing: %s" % CATALOG_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not parsed is Dictionary:
		push_error("Localization catalog must be a JSON dictionary.")
		return
	for language in LOCALES:
		var translation := Translation.new()
		translation.locale = language
		for source in parsed:
			var entry: Variant = parsed[source]
			if not entry is Dictionary:
				continue
			var translated: Variant = String(source) if language == "zh_CN" else entry.get(language, source)
			if not translated is String or translated.is_empty():
				translated = String(source)
			# Include an identity table for zh_CN, so English fallback cannot replace it.
			translation.add_message(String(source), translated)
			if language != "zh_CN" and translated != source:
				_display_sources[translated] = String(source)
		TranslationServer.add_translation(translation)
		_translations.append(translation)


func _binding_key(target: Object, property: StringName) -> String:
	return "%d:%s" % [target.get_instance_id(), property]


func _bind(target: Object, property: StringName, binding: Dictionary) -> void:
	if not is_instance_valid(target):
		return
	var key := _binding_key(target, property)
	var existed := _bindings.has(key)
	binding["target"] = weakref(target)
	binding["property"] = property
	_bindings[key] = binding
	if target is Node and not existed:
		(target as Node).tree_exiting.connect(func() -> void: _bindings.erase(key), CONNECT_ONE_SHOT)
	_render_binding(binding)


func _render_binding(binding: Dictionary) -> bool:
	var target: Object = (binding["target"] as WeakRef).get_ref()
	if not is_instance_valid(target):
		return false
	var rendered: String
	if binding.has("render"):
		var render: Callable = binding["render"]
		if not render.is_valid():
			return false
		rendered = String(render.call())
	elif binding.has("args"):
		rendered = format_text(binding["source"], binding["args"], binding["translate_arguments"])
	else:
		rendered = text(binding["source"])
	target.set(binding["property"], rendered + String(binding.get("suffix", "")))
	return true


func _refresh_bindings() -> void:
	for key in _bindings.keys():
		if not _render_binding(_bindings[key]):
			_bindings.erase(key)
