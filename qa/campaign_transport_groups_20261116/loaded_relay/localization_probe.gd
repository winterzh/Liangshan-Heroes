extends "res://tools/zhujiazhuang_rts_test.gd"
## One real chapter setup, then switch languages with only saved display text.

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var b = await _start("",0)
	var localize = root.get_node("Localize")
	var phrases := [
		["%s倒下；幸存七星仍可接力推车。", ["白胜"]],
		["%s倒下，第%d辆枣车留在原地，可由幸存七星接手。", ["吴用", 7]],
		["%s倒下，第%d车（%d担）留在原地，可由幸存七星接力。", ["晁盖", 1, 2]],
	]
	var reports := {}
	for locale: String in localize.LOCALES:
		localize.set_language(locale,false)
		var rendered := []
		for phrase: Array in phrases:
			rendered.append(localize.format_text(phrase[0],phrase[1]))
		rendered.append(localize.text("第1车·2担"))
		reports[locale] = rendered
	for locale: String in localize.LOCALES:
		localize.set_language(locale,false)
		for from_locale: String in localize.LOCALES:
			localize._formatted_sources.clear()
			var restored: Array = reports[from_locale].map(
				func(line: String) -> String: return localize.current_text(line))
			check(restored == reports[locale], "saved relay text %s -> %s" % [from_locale, locale])
	for report_index in range(reports["zh_CN"].size()):
		check(reports["en"][report_index] != reports["zh_CN"][report_index]
			and reports["ja"][report_index] != reports["zh_CN"][report_index],
			"relay phrase %d has distinct English and Japanese text" % (report_index + 1))
	print("HG_RELAY_LOCALIZATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"reports":reports}))
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
