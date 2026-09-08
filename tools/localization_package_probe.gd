extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var failures: Array = []
	var locale := OS.get_environment("LSH_LANGUAGE")
	var expected := {"en": "Paused", "ja": "一時停止", "zh_CN": "暂停", "zh_TW": "暫停"}
	if root.get_node_or_null("Localize") == null:
		failures.append("autoload missing")
	if TranslationServer.get_locale() != locale or String(TranslationServer.translate("暂停")) != expected[locale]:
		failures.append("packed translation unavailable")
	var catalog := "res://assets/localization/catalog.json"
	if FileAccess.get_sha256(catalog) != OS.get_environment("LSH_QA_CATALOG_SHA"):
		failures.append("packed catalog hash differs")
	var font: Font = load("res://assets/fonts/NotoSansCJK-Regular.ttc")
	for character in "汉語繁體あいうカキクABC":
		if font == null or not font.has_char(character.unicode_at(0)):
			failures.append("packed font missing glyph: " + character)
	if not FileAccess.file_exists("res://assets/fonts/OFL.txt"):
		failures.append("font license missing")
	var report := {"locale": locale, "passed": failures.is_empty(), "failures": failures,
		"catalog_sha256": FileAccess.get_sha256(catalog)}
	var output := FileAccess.open(OS.get_environment("LSH_QA_REPORT"), FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
