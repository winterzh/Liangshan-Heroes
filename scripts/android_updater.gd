extends Node
## Android / Windows / macOS 内容热更新引导器。
##
## 必须位于 Autoload 第一位：_init() 在主场景和战斗资源加载前装入已验证的累计 PCK，
## 从而让补丁中的 res:// 同路径资源覆盖完整包基础资源。Autoload 自身仍须随完整包更新。
## 保留 AndroidUpdater 这个 Autoload 名称及旧 Android 字段/环境变量，兼容 1.4.0 客户端。

signal status_changed(state: String, text: String, progress: float)
signal update_available(version: String, size_bytes: int)
signal full_update_required(version: String)
signal update_ready(version: String)

const BOOTSTRAP_VERSION := 3
const PACKAGE_VERSION_NAME := "1.7"
const PACKAGE_VERSION_CODE := 14
const BASE_CONTENT_VERSION := "1.7"

# 旧补丁脚本和专项测试可能仍读取这两个名字，不能删除。
const APK_VERSION_NAME := PACKAGE_VERSION_NAME
const APK_VERSION_CODE := PACKAGE_VERSION_CODE

const ANDROID_MANIFEST_URL := "http://120.26.237.195:1234/liangshan/android/stable/manifest.json"
const WINDOWS_MANIFEST_URL := "http://120.26.237.195:1234/liangshan/windows/stable/manifest.json"
const MACOS_MANIFEST_URL := "http://120.26.237.195:1234/liangshan/macos/stable/manifest.json"
# 旧代码可能读取 MANIFEST_URL；它始终保持 Android 地址。
const MANIFEST_URL := ANDROID_MANIFEST_URL

const ANDROID_UPDATE_DIR := "user://android_updates"
const DESKTOP_UPDATE_ROOT := "user://content_updates"
# 旧代码可能读取这些常量；Android 目录布局保持原样。
const UPDATE_DIR := ANDROID_UPDATE_DIR
const STATE_PATH := UPDATE_DIR + "/state.json"
const STATE_TMP_PATH := UPDATE_DIR + "/state.json.tmp"
const DOWNLOAD_TMP_PATH := UPDATE_DIR + "/download.pck.tmp"
const MAX_MANIFEST_BYTES := 256 * 1024

# 私钥只保存在发布机 ~/.config/liangshan-update/；客户端仅内置公钥。
const MANIFEST_PUBLIC_KEY := """-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAvH5n7XS6lT3F3MyOaEvH
RxjbUM6TNLVJB26THgUug0F+2U0mOjaHBSgnT76O1mLfeFpMbQ0h1FqD1WN57ppS
B9Pq8ac91mXWeSG6iAssAQSz/bKMUXqM9ISGJ4PB3RElUpUblILwxnRr1JV5ODVs
uSKGMVKdJKspTrvgVu03Va0Hdwf6wBbZ7BDugg2TtbcRLNlxQZ/lt58EcdooMQGM
cl7ZRrjC3f7rNqf13IO1CavBINqLAJYNA81D4J2tMDukaZPrtk4/x+Nb8Z6YonYK
tMSBAXB63xL9Q9Y3jMgTIiqZyikqZz8IP80CwkAg2JOKqL4XAXN5OV/3MeNfKcpC
5OKwAorDPl05vjlZ4p9zbLrjSHOc15QVVAPpu98Uoixvm1uCT3OYNZhehva7fb7m
vsSrfEVqbSm9MkQoXEi9yet6O8H/hOvNmm8QYy/8N7E/IiLHg0MGEIOxvSRo6WT9
pQiEyC+hB77tQmAfT7L3efOwBRGa9v4sZ+ZEeic+Q2R1AgMBAAE=
-----END PUBLIC KEY-----"""

var enabled := false
var state := "disabled"
var status_text := ""
var progress := -1.0
var active_content_version := BASE_CONTENT_VERSION
var available_manifest: Dictionary = {}
var platform_id := ""
var architecture := ""

var _request: HTTPRequest
var _phase := ""
var _manifest_body := PackedByteArray()
var _manifest_signature := ""
var _last_progress_percent := -1
var _update_dir := ""
var _state_path := ""
var _state_tmp_path := ""
var _download_tmp_path := ""


func _init() -> void:
	platform_id = _detect_platform()
	architecture = _detect_architecture()
	# Godot 4.6 导出模板并不保证提供 `standalone` feature tag；v1.6 因此把
	# 真实 EXE/APP/APK 的更新器全部关掉了。`editor` 只存在编辑器可执行文件，
	# 所以反向判断才能稳定区分导出程序与本地编辑调试。专项测试仍可显式绕过。
	enabled = platform_id != "" and (not OS.has_feature("editor") or _is_update_test())
	if not enabled:
		return
	_update_dir = ANDROID_UPDATE_DIR if platform_id == "android" else DESKTOP_UPDATE_ROOT.path_join(platform_id)
	_state_path = _update_dir.path_join("state.json")
	_state_tmp_path = _update_dir.path_join("state.json.tmp")
	_download_tmp_path = _update_dir.path_join("download.pck.tmp")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_update_dir))
	_load_installed_patch()


func _ready() -> void:
	if not enabled:
		return
	_request = HTTPRequest.new()
	# HTTPRequest 本身异步；关闭工作线程可避开部分 Android/无头环境的线程式 DNS/连接失败。
	_request.use_threads = false
	_request.timeout = 12.0
	_request.body_size_limit = MAX_MANIFEST_BYTES
	_request.request_completed.connect(_on_request_completed)
	add_child(_request)
	_set_status("idle", "%s内容 v%s" % [platform_display_name(), active_content_version])
	if _is_update_test():
		# 首个 Autoload 不引用 Campaign 等项目全局类，避免在 _init() 装 PCK 前连锁预载脚本。
		if platform_id == "android":
			# 保留旧回归脚本使用的 apk= 日志字段。
			print("[android_update] boot apk=%s content=%s bootstrap=%d platform=%s architecture=%s" % [
				APK_VERSION_NAME, active_content_version, BOOTSTRAP_VERSION, platform_id, architecture])
		else:
			print("[content_update] boot package=%s content=%s bootstrap=%d platform=%s architecture=%s" % [
				PACKAGE_VERSION_NAME, active_content_version, BOOTSTRAP_VERSION, platform_id, architecture])
	if not _env_flag("CONTENT_UPDATE_NO_AUTO") and not _env_flag("ANDROID_UPDATE_NO_AUTO"):
		get_tree().create_timer(1.0).timeout.connect(check_now)


func _process(_delta: float) -> void:
	if _phase != "patch" or _request == null:
		return
	var total := _request.get_body_size()
	var got := _request.get_downloaded_bytes()
	if total <= 0:
		return
	var pct := clampi(int(float(got) * 100.0 / float(total)), 0, 100)
	if pct != _last_progress_percent:
		_last_progress_percent = pct
		_set_status("downloading", "正在下载%s更新 %d%%" % [platform_display_name(), pct], float(pct) / 100.0)


func check_now() -> void:
	if not enabled or _request == null or _phase != "":
		return
	available_manifest.clear()
	_manifest_body = PackedByteArray()
	_manifest_signature = ""
	_set_status("checking", "正在检查%s更新……" % platform_display_name())
	_start_request(_cache_bust(_manifest_url()), "manifest")


func begin_download() -> void:
	if state != "available" or available_manifest.is_empty() or _phase != "":
		return
	var patch: Dictionary = available_manifest.get("patch", {})
	var url := String(patch.get("url", ""))
	if url == "":
		_fail("更新清单缺少补丁地址")
		return
	_remove_file(_download_tmp_path)
	_request.body_size_limit = -1
	_request.timeout = 0.0
	_request.download_file = _download_tmp_path
	_last_progress_percent = -1
	set_process(true)
	_set_status("downloading", "正在下载%s更新 0%%" % platform_display_name(), 0.0)
	_start_request(url, "patch")


func open_full_package() -> void:
	var full := get_full_package()
	var url := String(full.get("url", ""))
	if url != "":
		OS.shell_open(url)


# 保留旧菜单/补丁调用入口。
func open_full_apk() -> void:
	open_full_package()


func quit_for_restart() -> void:
	get_tree().quit()


func display_version() -> String:
	if active_content_version == PACKAGE_VERSION_NAME:
		return PACKAGE_VERSION_NAME
	return "%s · 内容%s" % [PACKAGE_VERSION_NAME, active_content_version]


func platform_display_name() -> String:
	match platform_id:
		"android":
			return "安卓"
		"windows":
			return "Windows"
		"macos":
			return "macOS"
	return "当前平台"


func get_full_package() -> Dictionary:
	var full: Variant = available_manifest.get("full_package", {})
	if full is Dictionary and not full.is_empty():
		return full
	# schema 1 的 Android 1.4.0 清单使用 full_apk。
	full = available_manifest.get("full_apk", {})
	return full if full is Dictionary else {}


func format_bytes(n: int) -> String:
	if n < 1024:
		return "%d B" % n
	if n < 1024 * 1024:
		return "%.1f KB" % (float(n) / 1024.0)
	return "%.1f MB" % (float(n) / 1048576.0)


func _start_request(url: String, phase_name: String) -> void:
	_phase = phase_name
	var err := _request.request(url, PackedStringArray(["Cache-Control: no-cache"]), HTTPClient.METHOD_GET)
	if err != OK:
		_phase = ""
		if phase_name == "patch":
			_reset_download_request()
		_fail("无法连接更新服务器（%s）" % error_string(err))


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var finished_phase := _phase
	_phase = ""
	if finished_phase == "patch":
		_reset_download_request()
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_remove_file(_download_tmp_path)
		_fail("更新服务器暂时不可用（%d/%d）" % [result, response_code])
		return
	match finished_phase:
		"manifest":
			if body.is_empty() or body.size() > MAX_MANIFEST_BYTES:
				_fail("更新清单大小异常")
				return
			_manifest_body = body
			_start_request.call_deferred(_cache_bust(_signature_url()), "signature")
		"signature":
			_manifest_signature = body.get_string_from_utf8().strip_edges()
			_accept_manifest()
		"patch":
			_accept_patch()
		_:
			_fail("未知更新响应")


func _accept_manifest() -> void:
	if not _verify_signature(_manifest_body, _manifest_signature):
		_fail("更新清单签名无效，已拒绝下载")
		return
	var parsed: Variant = JSON.parse_string(_manifest_body.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("更新清单格式错误")
		return
	var manifest: Dictionary = parsed
	if int(manifest.get("schema", 0)) != 1 or String(manifest.get("channel", "")) != "stable":
		_fail("更新清单版本不受支持")
		return
	var target_error := _target_validation_error(manifest, platform_id == "android")
	if target_error != "":
		_fail(target_error)
		return
	available_manifest = manifest
	var latest := String(manifest.get("content_version", BASE_CONTENT_VERSION))
	if not _valid_version(latest):
		_fail("更新清单的内容版本无效")
		return
	var min_bootstrap := int(manifest.get("min_bootstrap", 1))
	if min_bootstrap > BOOTSTRAP_VERSION:
		if not _offer_full_package_update(latest):
			_fail("新版需要完整包，但清单缺少下载地址")
		return
	if _version_compare(latest, active_content_version) <= 0:
		_set_status("current", "%s内容 v%s · 已是最新" % [platform_display_name(), active_content_version])
		return
	var patch_var: Variant = manifest.get("patch", null)
	# 新的两段式完整发行版没有跨发行线差异包；已有桌面客户端应跳转完整包。
	if not patch_var is Dictionary:
		if not _offer_full_package_update(latest):
			_fail("新版清单没有可用的差异包或完整包")
		return
	var patch: Dictionary = patch_var
	var patch_target_error := _target_validation_error(patch, true)
	if patch_target_error != "":
		_fail("差异包%s" % patch_target_error.trim_prefix("更新清单"))
		return
	var size_bytes := int(patch.get("size", 0))
	if String(patch.get("url", "")) == "" or size_bytes <= 0 or String(patch.get("sha256", "")).length() != 64:
		_fail("新版清单没有可用的差异包")
		return
	_set_status("available", "发现%s内容更新 v%s（%s）" % [platform_display_name(), latest, format_bytes(size_bytes)])
	update_available.emit(latest, size_bytes)
	if _env_flag("CONTENT_UPDATE_AUTO_DOWNLOAD") or _env_flag("ANDROID_UPDATE_AUTO_DOWNLOAD"):
		begin_download.call_deferred()


func _accept_patch() -> void:
	var patch: Dictionary = available_manifest.get("patch", {})
	var expected_size := int(patch.get("size", -1))
	var expected_sha := String(patch.get("sha256", "")).to_lower()
	var f := FileAccess.open(_download_tmp_path, FileAccess.READ)
	var actual_size := f.get_length() if f != null else -1
	if f != null:
		f.close()
	if actual_size != expected_size:
		_remove_file(_download_tmp_path)
		_fail("补丁大小校验失败")
		return
	var actual_sha := FileAccess.get_sha256(_download_tmp_path).to_lower()
	if actual_sha != expected_sha:
		_remove_file(_download_tmp_path)
		_fail("补丁 SHA-256 校验失败，已删除文件")
		return
	var version := String(available_manifest.get("content_version", ""))
	var final_path := _patch_path(version)
	_remove_file(final_path)
	var rename_err := DirAccess.rename_absolute(ProjectSettings.globalize_path(_download_tmp_path), ProjectSettings.globalize_path(final_path))
	if rename_err != OK:
		_remove_file(_download_tmp_path)
		_fail("补丁保存失败（%s）" % error_string(rename_err))
		return
	var state_data := {
		"manifest": _manifest_body.get_string_from_utf8(),
		"signature": _manifest_signature,
	}
	if not _write_json_atomic(_state_path, state_data):
		_remove_file(final_path)
		_fail("更新状态保存失败")
		return
	_set_status("ready", "%s内容 v%s 已下载，重启后生效" % [platform_display_name(), version], 1.0)
	update_ready.emit(version)


func _reset_download_request() -> void:
	set_process(false)
	_request.download_file = ""
	_request.body_size_limit = MAX_MANIFEST_BYTES
	_request.timeout = 12.0


func _load_installed_patch() -> void:
	_remove_file(_download_tmp_path)
	_remove_file(_state_tmp_path)
	if not FileAccess.file_exists(_state_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_state_path))
	if not parsed is Dictionary:
		return
	var saved: Dictionary = parsed
	var raw := String(saved.get("manifest", ""))
	var signature := String(saved.get("signature", ""))
	var raw_bytes := raw.to_utf8_buffer()
	if raw == "" or not _verify_signature(raw_bytes, signature):
		return
	var manifest_var: Variant = JSON.parse_string(raw)
	if not manifest_var is Dictionary:
		return
	var manifest: Dictionary = manifest_var
	if int(manifest.get("schema", 0)) != 1 or int(manifest.get("min_bootstrap", 1)) > BOOTSTRAP_VERSION:
		return
	if _target_validation_error(manifest, platform_id == "android") != "":
		return
	var version := String(manifest.get("content_version", ""))
	# 完整包已内置同版或更新的资源时，旧 PCK 绝不能再覆盖 res://。
	if version != "" and _version_compare(version, BASE_CONTENT_VERSION) <= 0:
		_remove_file(_state_path)
		_cleanup_stale_patches("")
		return
	var patch_var: Variant = manifest.get("patch", null)
	if not patch_var is Dictionary:
		return
	var patch: Dictionary = patch_var
	var path := _patch_path(version)
	if version == "" or not FileAccess.file_exists(path):
		return
	var expected_sha := String(patch.get("sha256", "")).to_lower()
	if expected_sha.length() != 64 or FileAccess.get_sha256(path).to_lower() != expected_sha:
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var expected_size := int(patch.get("size", -1))
	var size_ok := file != null and file.get_length() == expected_size
	if file != null:
		file.close()
	if not size_ok:
		return
	if ProjectSettings.load_resource_pack(path, true):
		active_content_version = version
		_cleanup_stale_patches(path)


func _verify_signature(body: PackedByteArray, signature_b64: String) -> bool:
	signature_b64 = signature_b64.strip_edges()
	if body.is_empty() or signature_b64.length() < 128 or signature_b64.length() % 4 != 0:
		return false
	for i in range(signature_b64.length()):
		var ch := signature_b64.substr(i, 1)
		if not (ch.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789+/="):
			return false
	var key := CryptoKey.new()
	if key.load_from_string(MANIFEST_PUBLIC_KEY, true) != OK:
		return false
	var signature := Marshalls.base64_to_raw(signature_b64)
	if signature.is_empty():
		return false
	return Crypto.new().verify(HashingContext.HASH_SHA256, _sha256(body), signature, key)


func _sha256(body: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	if ctx.start(HashingContext.HASH_SHA256) != OK:
		return PackedByteArray()
	if ctx.update(body) != OK:
		return PackedByteArray()
	return ctx.finish()


func _write_json_atomic(path: String, data: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.flush()
	f.close()
	_remove_file(path)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) == OK


func _cleanup_stale_patches(active_path: String) -> void:
	var dir := DirAccess.open(_update_dir)
	if dir == null:
		return
	for name in dir.get_files():
		var path := _update_dir.path_join(name)
		if name.begins_with("patch-") and name.ends_with(".pck") and path != active_path:
			dir.remove(name)


func _patch_path(version: String) -> String:
	var safe := ""
	for i in range(version.length()):
		var ch := version.substr(i, 1)
		if ch.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789._-":
			safe += ch
	return _update_dir.path_join("patch-%s.pck" % safe)


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _manifest_url() -> String:
	var override := OS.get_environment("CONTENT_UPDATE_URL")
	if override == "" and platform_id == "android":
		override = OS.get_environment("ANDROID_UPDATE_URL")
	if override != "":
		return override
	match platform_id:
		"windows":
			return WINDOWS_MANIFEST_URL
		"macos":
			return MACOS_MANIFEST_URL
	return ANDROID_MANIFEST_URL


func _signature_url() -> String:
	var url := _manifest_url()
	var slash := url.rfind("/")
	return url.substr(0, slash + 1) + "manifest.sig"


func _cache_bust(url: String) -> String:
	return "%s%st=%d" % [url, "&" if "?" in url else "?", int(Time.get_unix_time_from_system())]


func _detect_platform() -> String:
	var override := OS.get_environment("CONTENT_UPDATE_PLATFORM")
	if override != "":
		return _normalize_platform(override)
	# 历史 Android 专项在 macOS 构建机运行，继续将该开关解释为 Android 客户端。
	if _env_flag("ANDROID_UPDATE_TEST"):
		return "android"
	if OS.has_feature("android"):
		return "android"
	if OS.has_feature("windows"):
		return "windows"
	if OS.has_feature("macos"):
		return "macos"
	return ""


func _detect_architecture() -> String:
	var override := OS.get_environment("CONTENT_UPDATE_ARCHITECTURE")
	if override != "":
		return _normalize_architecture(override)
	if _env_flag("ANDROID_UPDATE_TEST") and OS.get_environment("CONTENT_UPDATE_PLATFORM") == "":
		return "arm64"
	var detected := _normalize_architecture(Engine.get_architecture_name())
	if detected != "":
		return detected
	if OS.has_feature("arm64"):
		return "arm64"
	if OS.has_feature("x86_64"):
		return "x86_64"
	return "unknown"


func _normalize_platform(value: String) -> String:
	match value.strip_edges().to_lower().replace("_", "").replace("-", ""):
		"android":
			return "android"
		"windows", "win", "win64":
			return "windows"
		"macos", "mac", "osx", "darwin":
			return "macos"
	return ""


func _normalize_architecture(value: String) -> String:
	match value.strip_edges().to_lower().replace("-", "_"):
		"arm64", "arm64_v8a", "aarch64":
			return "arm64"
		"x86_64", "x64", "amd64":
			return "x86_64"
		"universal", "universal2", "any":
			return "universal"
	return ""


func _target_validation_error(data: Dictionary, allow_missing: bool) -> String:
	var target: Dictionary = {}
	var target_var: Variant = data.get("target", {})
	if target_var is Dictionary:
		target = target_var
	var declared_platform := String(data.get("platform", target.get("platform", "")))
	if declared_platform == "":
		if not allow_missing:
			return "更新清单缺少平台标识"
	elif _normalize_platform(declared_platform) != platform_id:
		return "更新清单平台不匹配（需要 %s）" % platform_id

	var declared_arches: Array[String] = []
	var arches_var: Variant = data.get("architectures", target.get("architectures", []))
	if arches_var is Array:
		for item in arches_var:
			declared_arches.append(String(item))
	var single_arch := String(data.get("architecture",
		data.get("arch", target.get("architecture", target.get("arch", "")))))
	if single_arch != "":
		declared_arches.append(single_arch)
	if declared_arches.is_empty():
		if not allow_missing:
			return "更新清单缺少架构标识"
		return ""
	for declared in declared_arches:
		var normalized := _normalize_architecture(declared)
		if normalized == architecture or normalized == "universal":
			return ""
	return "更新清单架构不匹配（本机为 %s）" % architecture


func _full_package_version(full: Dictionary, fallback: String) -> String:
	var version := String(full.get("version", full.get("version_name", fallback)))
	return version if version != "" else fallback


func _offer_full_package_update(fallback_version: String) -> bool:
	var full := get_full_package()
	if String(full.get("url", "")) == "":
		return false
	var full_version := _full_package_version(full, fallback_version)
	_set_status("full_update", "需要安装%s完整包 v%s" % [platform_display_name(), full_version])
	full_update_required.emit(full_version)
	return true


func _valid_version(version: String) -> bool:
	var parts := version.split(".")
	if parts.size() < 2 or parts.size() > 3:
		return false
	for part in parts:
		if part == "":
			return false
		for i in range(part.length()):
			if not part.substr(i, 1) in "0123456789":
				return false
	return true


func _is_update_test() -> bool:
	return _env_flag("CONTENT_UPDATE_TEST") or _env_flag("ANDROID_UPDATE_TEST")


func _env_flag(name: String) -> bool:
	return OS.get_environment(name) == "1"


func _log_tag() -> String:
	return "android_update" if platform_id == "android" else "content_update"


func _version_compare(a: String, b: String) -> int:
	var aa := a.split(".")
	var bb := b.split(".")
	for i in range(maxi(aa.size(), bb.size())):
		var av := int(aa[i]) if i < aa.size() else 0
		var bv := int(bb[i]) if i < bb.size() else 0
		if av != bv:
			return 1 if av > bv else -1
	return 0


func _set_status(next_state: String, text: String, value := -1.0) -> void:
	state = next_state
	status_text = text
	progress = value
	if _is_update_test():
		print("[%s] state=%s text=%s progress=%.2f" % [_log_tag(), state, status_text, progress])
	status_changed.emit(state, status_text, progress)


func _fail(text: String) -> void:
	_set_status("error", text)
