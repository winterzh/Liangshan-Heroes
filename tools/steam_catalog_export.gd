extends SceneTree
## Deterministic vector badges -> Steamworks PNG assets; no external artwork.

func _initialize() -> void:
	var folder := OS.get_environment("STEAM_CATALOG_OUTPUT")
	if folder.is_empty():
		push_error("STEAM_CATALOG_OUTPUT must name a dedicated output directory")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder.path_join("icons"))
	var entries := SteamAchievementCatalog.entries()
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		for locked in [false, true]:
			var svg := badge(entry.id, index, locked)
			var image := Image.new()
			if image.load_svg_from_string(svg) != OK:
				quit(3)
				return
			var stem := String(entry.id).to_lower() + ("_locked" if locked else "")
			if image.save_png(folder.path_join("icons/" + stem + ".png")) != OK:
				quit(4)
				return
			var source := FileAccess.open(folder.path_join("icons/" + stem + ".svg"), FileAccess.WRITE)
			source.store_string(svg)
	var file := FileAccess.open(folder.path_join("steamworks_catalog.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"app_id":SteamAchievementCatalog.APP_ID, "stats":SteamAchievementCatalog.STATS, "achievements":entries}, "\t"))
	print("CATALOG_EXPORTED 30 achievements, 60 PNG icons")
	quit()

static func badge(id: String, index: int, locked: bool) -> String:
	var gold := "#dcb570" if not locked else "#77746e"
	var ink := "#28251f" if not locked else "#292929"
	var red := "#9c342b" if not locked else "#484642"
	var body := '<rect x="0" y="0" width="256" height="256" rx="28" fill="%s"/><rect x="13" y="13" width="230" height="230" rx="21" fill="none" stroke="%s" stroke-width="3"/><path d="M32 57V32h25 M199 32h25v25 M224 199v25h-25 M57 224H32v-25" fill="none" stroke="%s" stroke-width="6"/>' % [ink,gold,gold]
	body += '<circle cx="128" cy="120" r="78" fill="%s" stroke="%s" stroke-width="4"/>' % [red,gold]
	if "STORY" in id:
		body += '<path d="M91 64h74v105H91z M79 70v105h76 M110 82h36 M110 101h36 M110 120h26 M110 140h36" fill="none" stroke="%s" stroke-width="7" stroke-linejoin="round"/>' % gold
	elif "DEFENSE" in id:
		body += '<path d="M77 92V76h20v16h21V76h20v16h21V76h20v84H77z M113 160v-34h30v34" fill="none" stroke="%s" stroke-width="7" stroke-linejoin="round"/>' % gold
	elif "KILLS" in id:
		body += '<path d="M84 74l87 87 M79 144l28 28 M77 179l21-21 M84 74l8 26 52 51 18-18-51-51z M172 74l-87 87 M149 172l28-28" fill="none" stroke="%s" stroke-width="7" stroke-linejoin="round"/>' % gold
	elif "AI" in id:
		body += '<path d="M85 80h86v80H85z M85 106h86 M85 133h86 M113 80v80 M143 80v80" fill="none" stroke="%s" stroke-width="5"/><circle cx="113" cy="106" r="10" fill="%s"/><circle cx="143" cy="133" r="10" fill="%s"/>' % [gold,gold,ink]
	else:
		body += '<path d="M83 73h90v16c0 53-16 62-45 73-29-11-45-20-45-73z M128 163v21 M102 184h52 M82 87H66v24c0 14 11 23 23 23 M174 87h16v24c0 14-11 23-23 23" fill="none" stroke="%s" stroke-width="7" stroke-linejoin="round"/>' % gold
	# A unique constellation for each badge; chapter pairs share an eight-dot register.
	var count := int(id.get_slice("_", id.get_slice_count("_")-1)) if "LEVEL" in id else (index % 8) + 1
	for i in range(8):
		body += '<circle cx="%d" cy="212" r="4" fill="%s" opacity="%s"/>' % [72 + i*16,gold,"1" if i < count else "0.18"]
	return '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">' + body + '</svg>'
