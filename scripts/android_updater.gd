extends Node
## Android 专用内容热更新引导器。
##
## 必须位于 Autoload 第一位：_init() 在主场景和战斗资源加载前装入已验证的累计 PCK，
## 从而让补丁中的 res:// 同路径资源覆盖 APK 基础资源。Autoload 自身仍须随完整 APK 更新。
## Windows/macOS 永不启用。

signal status_changed(state: String, text: String, progress: float)
signal update_available(version: String, size_bytes: int)
signal full_update_required(version: String)
signal update_ready(version: String)

const BOOTSTRAP_VERSION := 1
const APK_VERSION_NAME := "1.5"
const APK_VERSION_CODE := 11
const BASE_CONTENT_VERSION := "1.5"
const MANIFEST_URL := "http://120.26.237.195:1234/liangshan/android/stable/manifest.json"

const UPDATE_DIR := "user://android_updates"
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

var _request: HTTPRequest
var _phase := ""
var _manifest_body := PackedByteArray()
var _manifest_signature := ""
var _last_progress_percent := -1


func _init() -> void:
	enabled = OS.has_feature("android") or OS.get_environment("ANDROID_UPDATE_TEST") == "1"
	if not enabled:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UPDATE_DIR))
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
	_set_status("idle", "安卓内容 v%s" % active_content_version)
	if OS.get_environment("ANDROID_UPDATE_TEST") == "1":
		# 首个 Autoload 不引用 Campaign 等项目全局类，避免在 _init() 装 PCK 前连锁预载脚本。
		print("[android_update] boot apk=%s content=%s bootstrap=%d" % [
			APK_VERSION_NAME, active_content_version, BOOTSTRAP_VERSION])
	if OS.get_environment("ANDROID_UPDATE_NO_AUTO") != "1":
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
		_set_status("downloading", "正在下载安卓更新 %d%%" % pct, float(pct) / 100.0)


func check_now() -> void:
	if not enabled or _request == null or _phase != "":
		return
	available_manifest.clear()
	_manifest_body = PackedByteArray()
	_manifest_signature = ""
	_set_status("checking", "正在检查安卓更新……")
	_start_request(_cache_bust(_manifest_url()), "manifest")


func begin_download() -> void:
	if state != "available" or available_manifest.is_empty() or _phase != "":
		return
	var patch: Dictionary = available_manifest.get("patch", {})
	var url := String(patch.get("url", ""))
	if url == "":
		_fail("更新清单缺少补丁地址")
		return
	_remove_file(DOWNLOAD_TMP_PATH)
	_request.body_size_limit = -1
	_request.timeout = 0.0
	_request.download_file = DOWNLOAD_TMP_PATH
	_last_progress_percent = -1
	set_process(true)
	_set_status("downloading", "正在下载安卓更新 0%", 0.0)
	_start_request(url, "patch")


func open_full_apk() -> void:
	var full: Dictionary = available_manifest.get("full_apk", {})
	var url := String(full.get("url", ""))
	if url != "":
		OS.shell_open(url)


func quit_for_restart() -> void:
	get_tree().quit()


func display_version() -> String:
	if active_content_version == APK_VERSION_NAME:
		return APK_VERSION_NAME
	return "%s · 内容%s" % [APK_VERSION_NAME, active_content_version]


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
		_remove_file(DOWNLOAD_TMP_PATH)
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
	available_manifest = manifest
	var latest := String(manifest.get("content_version", BASE_CONTENT_VERSION))
	var min_bootstrap := int(manifest.get("min_bootstrap", 1))
	if min_bootstrap > BOOTSTRAP_VERSION:
		var full: Dictionary = manifest.get("full_apk", {})
		var full_version := String(full.get("version_name", latest))
		_set_status("full_update", "需要安装安卓完整包 v%s" % full_version)
		full_update_required.emit(full_version)
		return
	if _version_compare(latest, active_content_version) <= 0:
		_set_status("current", "安卓内容 v%s · 已是最新" % active_content_version)
		return
	var patch: Dictionary = manifest.get("patch", {})
	var size_bytes := int(patch.get("size", 0))
	if String(patch.get("url", "")) == "" or size_bytes <= 0 or String(patch.get("sha256", "")).length() != 64:
		_fail("新版清单没有可用的差异包")
		return
	_set_status("available", "发现安卓内容更新 v%s（%s）" % [latest, format_bytes(size_bytes)])
	update_available.emit(latest, size_bytes)
	if OS.get_environment("ANDROID_UPDATE_AUTO_DOWNLOAD") == "1":
		begin_download.call_deferred()


func _accept_patch() -> void:
	var patch: Dictionary = available_manifest.get("patch", {})
	var expected_size := int(patch.get("size", -1))
	var expected_sha := String(patch.get("sha256", "")).to_lower()
	var f := FileAccess.open(DOWNLOAD_TMP_PATH, FileAccess.READ)
	var actual_size := f.get_length() if f != null else -1
	if f != null:
		f.close()
	if actual_size != expected_size:
		_remove_file(DOWNLOAD_TMP_PATH)
		_fail("补丁大小校验失败")
		return
	var actual_sha := FileAccess.get_sha256(DOWNLOAD_TMP_PATH).to_lower()
	if actual_sha != expected_sha:
		_remove_file(DOWNLOAD_TMP_PATH)
		_fail("补丁 SHA-256 校验失败，已删除文件")
		return
	var version := String(available_manifest.get("content_version", ""))
	var final_path := _patch_path(version)
	_remove_file(final_path)
	var rename_err := DirAccess.rename_absolute(ProjectSettings.globalize_path(DOWNLOAD_TMP_PATH), ProjectSettings.globalize_path(final_path))
	if rename_err != OK:
		_remove_file(DOWNLOAD_TMP_PATH)
		_fail("补丁保存失败（%s）" % error_string(rename_err))
		return
	var state_data := {
		"manifest": _manifest_body.get_string_from_utf8(),
		"signature": _manifest_signature,
	}
	if not _write_json_atomic(STATE_PATH, state_data):
		_remove_file(final_path)
		_fail("更新状态保存失败")
		return
	_set_status("ready", "安卓内容 v%s 已下载，重启后生效" % version, 1.0)
	update_ready.emit(version)


func _reset_download_request() -> void:
	set_process(false)
	_request.download_file = ""
	_request.body_size_limit = MAX_MANIFEST_BYTES
	_request.timeout = 12.0


func _load_installed_patch() -> void:
	_remove_file(DOWNLOAD_TMP_PATH)
	_remove_file(STATE_TMP_PATH)
	if not FileAccess.file_exists(STATE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
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
	var version := String(manifest.get("content_version", ""))
	# 完整 APK 已内置同版或更新的资源时，旧 PCK 绝不能再覆盖 res://。
	# 例如从热更后的 1.4.0 覆盖安装 1.5，用户目录中可能仍留着 1.4.1/1.5 PCK。
	if version != "" and _version_compare(version, BASE_CONTENT_VERSION) <= 0:
		_remove_file(STATE_PATH)
		_cleanup_stale_patches("")
		return
	var patch: Dictionary = manifest.get("patch", {})
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
	var dir := DirAccess.open(UPDATE_DIR)
	if dir == null:
		return
	for name in dir.get_files():
		var path := UPDATE_DIR.path_join(name)
		if name.begins_with("patch-") and name.ends_with(".pck") and path != active_path:
			dir.remove(name)


func _patch_path(version: String) -> String:
	var safe := ""
	for i in range(version.length()):
		var ch := version.substr(i, 1)
		if ch.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789._-":
			safe += ch
	return UPDATE_DIR.path_join("patch-%s.pck" % safe)


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _manifest_url() -> String:
	var override := OS.get_environment("ANDROID_UPDATE_URL")
	return override if override != "" else MANIFEST_URL


func _signature_url() -> String:
	var url := _manifest_url()
	var slash := url.rfind("/")
	return url.substr(0, slash + 1) + "manifest.sig"


func _cache_bust(url: String) -> String:
	return "%s%st=%d" % [url, "&" if "?" in url else "?", int(Time.get_unix_time_from_system())]


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
	if OS.get_environment("ANDROID_UPDATE_TEST") == "1":
		print("[android_update] state=%s text=%s progress=%.2f" % [state, status_text, progress])
	status_changed.emit(state, status_text, progress)


func _fail(text: String) -> void:
	_set_status("error", text)
