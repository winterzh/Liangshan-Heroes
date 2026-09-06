class_name SteamPanels
extends RefCounted
## Shared in-game views, reusing the existing UITheme and Control navigation.

static func _panel(parent: Node, title: String) -> Dictionary:
	var overlay := ColorRect.new()
	overlay.color = Color(0.035, 0.03, 0.025, 0.98)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	overlay.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 24)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	head.add_child(_button("返回", overlay.queue_free))
	var status_label := Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	return {"root":overlay, "body":content, "status":status_label, "head":head}

static func _button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 38
	button.pressed.connect(callback)
	return button

static func show_achievements(parent: Node) -> void:
	var p := _panel(parent, "成就 · 30 项")
	var refresh := func() -> void:
		p.status.text = SteamService.status
		for child in p.body.get_children():
			p.body.remove_child(child)
			child.queue_free()
		for entry in SteamAchievementCatalog.entries():
			var unlocked := bool(SteamService.state.unlocked.get(entry.id, false))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 16)
			p.body.add_child(row)
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(64, 64)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var path: String = entry.icon if unlocked else entry.locked_icon
			if ResourceLoader.exists(path): icon.texture = load(path)
			row.add_child(icon)
			var text := Label.new()
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.text = ("✓ " if unlocked else "○ ") + String(entry.title) + "\n" + String(entry.description)
			if entry.stat != "":
				text.text += "\n%d / %d" % [mini(int(SteamService.state.stats.get(entry.stat, 0)), int(entry.target)), int(entry.target)] if SteamService.stats_ready else "\n进度未读取"
			row.add_child(text)
	SteamService.changed.connect(refresh)
	p.root.tree_exiting.connect(func() -> void: SteamService.changed.disconnect(refresh))
	refresh.call()

static func show_workshop(parent: Node) -> void:
	var p := _panel(parent, "创意工坊 · 已订阅作品")
	p.head.add_child(_button("浏览工坊", func() -> void: SteamService.open_page("https://steamcommunity.com/app/5088120/workshop/")))
	p.head.add_child(_button("刷新", WorkshopService.refresh))
	p.head.add_child(_button("保存创作示例", func() -> void:
		var a := save_copy("scenario", WorkshopExamples.scenario())
		var b := save_copy("custom_defense", WorkshopExamples.defense())
		WorkshopService.status = "示例已保存，可从两种编辑器读取并修改" if a != "" and b != "" else "示例保存失败"
		WorkshopService.changed.emit()))
	var refresh := func() -> void:
		p.status.text = WorkshopService.status + "\n工坊关卡不计入 Steam 成就。取消订阅不会删除编辑器里的本地作品。"
		for child in p.body.get_children():
			p.body.remove_child(child)
			child.queue_free()
		if WorkshopService.items.is_empty():
			var empty := Label.new()
			empty.text = "还没有可显示的订阅作品。可以先浏览工坊并订阅，再回来刷新。"
			empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			p.body.add_child(empty)
		for item in WorkshopService.items:
			var row := HBoxContainer.new()
			p.body.add_child(row)
			var label := Label.new()
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.text = String(item.title) + "\n" + ("可游玩" if item.get("ok", false) else String(item.get("error", "下载中")))
			row.add_child(label)
			var play := _button("游玩", WorkshopService.play.bind(String(item.id)))
			play.disabled = not bool(item.get("ok", false))
			row.add_child(play)
			row.add_child(_button("作品页", WorkshopService.open_item.bind(String(item.id))))
			row.add_child(_button("取消订阅", WorkshopService.unsubscribe.bind(String(item.id))))
	WorkshopService.changed.connect(refresh)
	p.root.tree_exiting.connect(func() -> void: WorkshopService.changed.disconnect(refresh))
	WorkshopService.refresh()

static func show_publish(parent: Control, kind: String, source: Dictionary) -> void:
	var default_cover := parent.get_viewport().get_texture().get_image()
	var p := _panel(parent, "发布／更新创意工坊作品")
	var name := LineEdit.new()
	name.text = String(source.get("title", source.get("name", "")))
	name.max_length = 128
	p.body.add_child(name)
	var description := TextEdit.new()
	description.placeholder_text = "作品说明：介绍玩法、胜负条件和建议人数／难度"
	description.custom_minimum_size.y = 130
	description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	p.body.add_child(description)
	var visibility := OptionButton.new()
	visibility.add_item("私有（默认）", 2)
	visibility.add_item("好友可见", 1)
	visibility.add_item("公开", 0)
	p.body.add_child(visibility)
	var cover := {"image":default_cover}
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(256, 144)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = ImageTexture.create_from_image(default_cover)
	p.body.add_child(preview)
	var chooser := FileDialog.new()
	chooser.access = FileDialog.ACCESS_FILESYSTEM
	chooser.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	chooser.filters = PackedStringArray(["*.png,*.jpg,*.jpeg ; 封面图片"])
	p.root.add_child(chooser)
	chooser.file_selected.connect(func(path: String) -> void:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null or f.get_length() > 10 * 1024 * 1024:
			p.status.text = "请选择小于 10 MB 的封面图片"
			return
		var image := Image.load_from_file(path)
		if image == null or image.is_empty() or image.get_width() > 8192 or image.get_height() > 8192:
			p.status.text = "封面图片无效或尺寸过大"
			return
		cover.image = image
		preview.texture = ImageTexture.create_from_image(image))
	p.body.add_child(_button("选择封面（默认使用当前编辑器画面）", func() -> void: chooser.popup_centered_ratio(0.75)))
	var terms := RichTextLabel.new()
	terms.bbcode_enabled = true
	terms.fit_content = true
	terms.text = "提交作品即表示同意 [url=https://steamcommunity.com/sharedfiles/workshoplegalagreement]Steam 创意工坊协议[/url]。使用游戏内素材的地图和据守配置可发布；脚本与外部资源不支持。"
	terms.meta_clicked.connect(func(url: Variant) -> void: SteamService.open_page(String(url)))
	p.body.add_child(terms)
	var submit := _button("上传作品", func() -> void:
		source["title" if kind == "scenario" else "name"] = name.text
		WorkshopService.publish(kind, source, description.text, visibility.get_selected_id(), cover.image))
	p.body.add_child(submit)
	var refresh := func() -> void:
		p.status.text = WorkshopService.status
		submit.disabled = WorkshopService.busy or not SteamService.available
	WorkshopService.changed.connect(refresh)
	p.root.tree_exiting.connect(func() -> void: WorkshopService.changed.disconnect(refresh))
	refresh.call()

static func save_copy(kind: String, source: Dictionary) -> String:
	var copy := source.duplicate(true)
	copy.erase("_workshop_source_id")
	var field := "title" if kind == "scenario" else "name"
	copy[field] = String(copy.get(field, "作品")) + "_副本_" + Crypto.new().generate_random_bytes(4).hex_encode()
	return ScenarioStore.save(copy) if kind == "scenario" else CustomConfig.save(copy)
