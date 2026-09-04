extends SceneTree
## Web ChatGPT PNGs only: deterministic crop/resize/placement; no drawing or mirroring.
## Incremental and separate from campaign_art_slice.gd / slice_qa.json.
const ROOT := "res://assets/campaign/"
const MANIFEST := ROOT + "web_art_manifest.json"
const REPORT := ROOT + "web_art_slice_qa.json"
const VERSION := "web-art-slice-1"
# Halfway avoids float32 expansion treating the byte value99 as greater than99.
const THRESHOLD := 99.5 / 255.0
var failures: Array[String] = []
var sources: Dictionary = {}
var protected_legacy: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _rect(values: Array) -> Rect2i:
	return Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))

func _bounds(im: Image) -> Rect2i:
	var left := im.get_width()
	var top := im.get_height()
	var right := -1
	var bottom := -1
	for y in range(im.get_height()):
		for x in range(im.get_width()):
			if im.get_pixel(x, y).a > THRESHOLD:
				left = mini(left, x)
				top = mini(top, y)
				right = maxi(right, x)
				bottom = maxi(bottom, y)
	return Rect2i(left, top, right-left+1, bottom-top+1) if right >= left else Rect2i()

func _safe_output(relative: String) -> bool:
	return not relative.contains("..") and not relative.contains(":") and relative.ends_with(".png") and (relative.begins_with("objects/") or relative.begins_with("anim/") or relative.begins_with("portraits/"))

func _load_source(source_id: String, manifest: Dictionary) -> Image:
	if sources.has(source_id): return sources[source_id]
	var spec: Dictionary = manifest.get("sources", {}).get(source_id, {})
	if spec.get("status", "") != "accepted":
		_fail("Unaccepted source: " + source_id)
		return null
	var relative := String(spec.get("file", ""))
	if not relative.begins_with("source/") or relative.contains(".."):
		_fail("Unsafe source path: " + relative)
		return null
	var path := ROOT + relative
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != spec.get("sha256", ""):
		_fail("Source missing or changed since review: " + source_id)
		return null
	var im := Image.load_from_file(path)
	if im == null or im.is_empty():
		_fail("Cannot read image: " + path)
		return null
	im.convert(Image.FORMAT_RGBA8)
	sources[source_id] = im
	return im

func _compose_frame(frame: Dictionary, spec: Dictionary, manifest: Dictionary) -> Dictionary:
	var source_id := String(frame.get("source", ""))
	var im := _load_source(source_id, manifest)
	if im == null: return {}
	var region := _rect(frame.get("region", [0, 0, im.get_width(), im.get_height()]))
	if region.size.x <= 0 or region.size.y <= 0 or not Rect2i(Vector2i.ZERO, im.get_size()).encloses(region):
		_fail("Frame region outside reviewed source: " + source_id)
		return {}
	var cell := im.get_region(region)
	# Optional reviewed atlas ownership cuts preserve original RGBA in every kept run.
	# They only remove another independently generated figure in an overlapping rectangle.
	if frame.has("isolation_runs"):
		var isolated := Image.create(region.size.x, region.size.y, false, Image.FORMAT_RGBA8)
		isolated.fill(Color.TRANSPARENT)
		for run in frame.isolation_runs:
			var row := int(run[0])
			var left := int(run[1])
			var length := int(run[2])
			if row < 0 or row >= region.size.y or left < 0 or length < 1 or left+length > region.size.x:
				_fail("Invalid atlas isolation run: " + source_id)
				return {}
			isolated.blit_rect(cell, Rect2i(left, row, length, 1), Vector2i(left, row))
		cell = isolated
	var box := _bounds(cell)
	if box.size.x <= 0 or box.size.y <= 0:
		_fail("Empty alpha body: " + source_id)
		return {}
	if frame.has("expected_bounds") and box != _rect(frame.expected_bounds):
		_fail("Reviewed alpha bounds changed: " + source_id)
		return {}
	var minimum := int(frame.get("minimum_source_margin", 1))
	var allow_crop: bool = bool(frame.get("allow_source_crop", false)) and spec.get("kind", "") == "portrait"
	if not allow_crop and (box.position.x < minimum or box.position.y < minimum or box.end.x > cell.get_width()-minimum or box.end.y > cell.get_height()-minimum):
		_fail("Visible body touches source cell boundary: " + source_id)
		return {}
	# Two transparent pixels preserve antialiased contours. No threshold mask is applied.
	var safe := box.grow(2).intersection(Rect2i(Vector2i.ZERO, cell.get_size()))
	var part := cell.get_region(safe)
	var scale := float(frame.get("scale", spec.get("scale", 1.0)))
	var size := int(spec.get("canvas_size", 256))
	var anchor: Array = spec.get("anchor", [0.5, 0.82])
	if scale <= 0.0 or size <= 0:
		_fail("Invalid scale or canvas: " + String(spec.id))
		return {}
	part.resize(maxi(1, roundi(safe.size.x * scale)), maxi(1, roundi(safe.size.y * scale)), Image.INTERPOLATE_LANCZOS)
	var ground := float(box.end.y - safe.position.y)
	var at := Vector2i(roundi(size*float(anchor[0]) - part.get_width()*0.5), roundi(size*float(anchor[1])-ground*scale))
	if spec.get("kind", "") == "portrait":
		at = Vector2i(roundi((size-part.get_width())*0.5), roundi((size-part.get_height())*0.5))
	if at.x < 0 or at.y < 0 or at.x+part.get_width() > size or at.y+part.get_height() > size:
		_fail("Composition would clip; lower shared scale: " + String(spec.id))
		return {}
	var result := Image.create(size, size, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	result.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), at)
	var output_box := _bounds(result)
	return {"image": result, "source": source_id, "scale": scale, "source_region": [region.position.x,region.position.y,region.size.x,region.size.y], "source_alpha_bounds": [box.position.x,box.position.y,box.size.x,box.size.y], "alpha_bounds": [output_box.position.x,output_box.position.y,output_box.size.x,output_box.size.y], "bottom": output_box.end.y-1}

func _fingerprint(spec: Dictionary, manifest: Dictionary) -> String:
	var hashes: Dictionary = {}
	for frame in spec.get("frames", []):
		var key := String(frame.source)
		hashes[key] = manifest.sources.get(key, {}).get("sha256", "missing")
	return (VERSION + JSON.stringify(spec, "", true) + JSON.stringify(hashes, "", true)).sha256_text()

func _build(spec: Dictionary, manifest: Dictionary, previous: Dictionary) -> Dictionary:
	var relative := String(spec.get("output", ""))
	if not _safe_output(relative) or protected_legacy.has(relative):
		_fail("Unsafe output: " + relative)
		return {}
	var path := ROOT + relative
	var fingerprint := _fingerprint(spec, manifest)
	# Recheck source hashes even when the output is unchanged.
	for frame in spec.get("frames", []):
		if _load_source(String(frame.source), manifest) == null: return {}
	if previous.get("fingerprint", "") == fingerprint and FileAccess.file_exists(path) and FileAccess.get_sha256(path) == previous.get("sha256", ""):
		var cached := previous.duplicate(true)
		cached["build_action"] = "unchanged"
		return cached
	if FileAccess.file_exists(path) and previous.is_empty():
		_fail("Refusing to overwrite output not owned by web report: " + relative)
		return {}
	var frame_records: Array = []
	var frames: Array[Image] = []
	for frame in spec.get("frames", []):
		var result := _compose_frame(frame, spec, manifest)
		if result.is_empty(): return {}
		frames.append(result.image)
		result.erase("image")
		frame_records.append(result)
	if frames.is_empty():
		_fail("No frames: " + String(spec.id))
		return {}
	var size := int(spec.get("canvas_size", 256))
	var strip := Image.create(size*frames.size(), size, false, Image.FORMAT_RGBA8)
	strip.fill(Color.TRANSPARENT)
	for index in range(frames.size()):
		strip.blit_rect(frames[index], Rect2i(0, 0, size, size), Vector2i(index*size, 0))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := strip.save_png(path)
	if err != OK:
		_fail("PNG write failed: " + relative)
		return {}
	return {"id": spec.id, "output": relative, "kind": spec.get("kind", "animation"), "variant": spec.get("variant", ""), "state": spec.get("state", ""), "direction": spec.get("direction", ""), "frame_count": frames.size(), "canvas_size": size, "anchor": spec.get("anchor", [0.5,0.82]), "shared_scale": spec.get("scale", 1.0), "fingerprint": fingerprint, "sha256": FileAccess.get_sha256(path), "build_action": "built", "frames": frame_records}

func _run() -> void:
	var manifest := _json(MANIFEST)
	if manifest.get("schema_version", 0) != 1:
		_fail("Missing or unsupported web manifest")
		quit(2)
		return
	var previous_report := _json(REPORT)
	var previous := previous_report.get("artifacts", {}) as Dictionary
	if bool(previous_report.get("passed", false)):
		var backup := FileAccess.open(ROOT+"web_art_slice_qa.previous.json", FileAccess.WRITE)
		backup.store_string(JSON.stringify(previous_report, "\t", true))
		backup.close()
	protected_legacy = _json(ROOT+String(manifest.get("legacy_baseline", "web_art_legacy_baseline.json"))).get("sha256", {}) as Dictionary
	var records: Dictionary = {}
	var selected: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): selected.assign(arg.substr(7).split(","))
	for spec in manifest.get("artifacts", []):
		var key := String(spec.id)
		if not selected.is_empty() and key not in selected:
			if previous.has(key): records[key] = previous[key]
			continue
		var result := _build(spec, manifest, previous.get(key, {}))
		if not result.is_empty():
			records[key] = result
		elif previous.has(key):
			# Retain ownership of the old PNG when a changed input fails validation.
			# The report still fails; never present this stale entry as the new build.
			records[key] = previous[key].duplicate(true)
			records[key]["build_action"] = "retained_after_failed_update"
	var report := {"schema_version": 1, "tool": VERSION, "source_mode": "web ChatGPT download", "mirrored": false, "pixel_generation": false, "manifest_sha256": FileAccess.get_sha256(MANIFEST), "artifacts": records, "failures": failures, "passed": failures.is_empty()}
	var out := FileAccess.open(REPORT, FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "\t", true))
	out.close()
	sources.clear()
	print("[campaign_web_art_slice] artifacts=%d passed=%s" % [records.size(), failures.is_empty()])
	quit.call_deferred(0 if failures.is_empty() else 3)
