extends RefCounted
## New closed-A protocol only. Never reads descriptor.source_scope/profile.
## Native Slot/LC decode is authoritative; no Python-generated packet/world.
const Store := preload("res://scripts/run_slot_store.gd")
const Lifecycle := preload("res://scripts/run_campaign_local_lifecycle.gd")
const Profiles := preload("res://scripts/run_official_restore_profile.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const Intent := preload("res://scripts/run_campaign_progress_intent.gd")
var checks: Array = []
var provenance: Array = []
var slot_decode_called := false
var lifecycle_decode_called := false
var terminal_document_validate_called := false

func check(ok: bool, label: String) -> bool:
	checks.append({"passed":ok,"label":label})
	return ok

func integer(value: Variant, expected: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == float(expected)

func path(value: Variant) -> String:
	if typeof(value) != TYPE_STRING: return ""
	var text: String = value.replace("\\", "/")
	if not text.is_absolute_path() or ".." in text.split("/") or text.begins_with("//?/"): return ""
	return text.simplify_path().trim_suffix("/")

func no_links(value: String) -> bool:
	if value.is_empty(): return false
	var current := value
	while current != current.get_base_dir():
		var parent := DirAccess.open(current.get_base_dir())
		if parent == null or parent.is_link(current.get_file()): return false
		current = current.get_base_dir()
	return true

func read_pin(value: Variant, label: String) -> String:
	if not check(typeof(value) == TYPE_DICTIONARY and value.has_all(["path","bytes","sha256"]), label + " pin fields"): return ""
	var location := path(value.path)
	if not check(not location.is_empty() and no_links(location) and FileAccess.file_exists(location)
		and typeof(value.sha256) == TYPE_STRING and value.sha256.length() == 64
		and FileAccess.get_sha256(location) == value.sha256, label + " exact SHA and unlinked path"): return ""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(location)
	if not check(integer(value.bytes, bytes.size()) and bytes.size() > 0 and bytes.size() <= 67108864,
		label + " exact bounded bytes"): return ""
	var text: String = bytes.get_string_from_utf8()
	if not check(text.to_utf8_buffer() == bytes and FileAccess.get_sha256(location) == value.sha256,
		label + " UTF8 and stable raw bytes"): return ""
	provenance.append({"path":location,"sha256":value.sha256,"bytes":bytes.size()})
	return text

func parse(raw: String, label: String) -> Dictionary:
	var json := JSON.new()
	if not check(not raw.is_empty() and json.parse(raw) == OK and typeof(json.data) == TYPE_DICTIONARY,
		label + " JSON object"): return {}
	return json.data

func scan(root: String, relative := "", out: Dictionary = {}) -> Dictionary:
	if out.is_empty(): out = {"ok":true,"files":{},"directories":[]}
	var location := root if relative.is_empty() else root.path_join(relative)
	if not no_links(location): out.ok = false; return out
	var dir := DirAccess.open(location)
	if dir == null: out.ok = false; return out
	dir.include_hidden = true
	dir.include_navigational = false
	for name: String in dir.get_files():
		var rel := name if relative.is_empty() else relative.path_join(name)
		var leaf := root.path_join(rel)
		if dir.is_link(name): out.ok = false; return out
		var file := FileAccess.open(leaf, FileAccess.READ)
		if file == null: out.ok = false; return out
		var size: int = file.get_length()
		file.close()
		out.files[rel] = {"bytes":size,"sha256":FileAccess.get_sha256(leaf)}
	for name: String in dir.get_directories():
		var rel := name if relative.is_empty() else relative.path_join(name)
		if dir.is_link(name): out.ok = false; return out
		out.directories.append(rel)
		scan(root, rel, out)
	return out

func inventory_matches(root: String, expected: Variant, token: String) -> bool:
	if typeof(expected) != TYPE_DICTIONARY or not expected.has_all(["files","directories"]): return false
	if typeof(expected.files) != TYPE_DICTIONARY or typeof(expected.directories) != TYPE_ARRAY: return false
	var names := ["5088120/1/record_0000000001.json", "local_runs/" + token + "/5088120/1/record_0000000001.json"]
	var dirs := ["5088120", "5088120/1", "local_runs", "local_runs/" + token,
		"local_runs/" + token + "/5088120", "local_runs/" + token + "/5088120/1"]
	var observed := scan(root)
	if not observed.ok or observed.files.size() != 2 or expected.files.size() != 2 \
		or observed.directories.size() != 6 or expected.directories.size() != 6: return false
	for name: String in dirs:
		if not observed.directories.has(name) or not expected.directories.has(name): return false
	for name: String in names:
		if not observed.files.has(name) or not expected.files.has(name): return false
		var row: Variant = expected.files[name]
		if typeof(row) != TYPE_DICTIONARY or not row.has_all(["bytes","sha256"]) \
			or row.sha256 != observed.files[name].sha256 or not integer(row.bytes, observed.files[name].bytes): return false
	return true

func unchanged() -> bool:
	for row: Dictionary in provenance:
		if not no_links(row.path) or FileAccess.get_sha256(row.path) != row.sha256: return false
	return true

func admit(request: Dictionary, trusted: Dictionary) -> Dictionary:
	if not check(request.get("schema") == "daming_negative_admission_request_v2"
		and request.get("scope") == "admission_only_not_52_execution"
		and request.get("first_role") in ["lu","shi"]
		and request.has_all(["flow_receipt","closed_a_descriptor","a_report","a_log","slot","lifecycle",
			"producer_terminal_report","producer_pid","binding","context","consumer_process_nonce"]), "new fixture admission protocol"): return {}
	if not check(Profiles.trusted_identity(trusted) and trusted.get("source_mode") == true
		and trusted.content_version == request.get("content_version")
		and trusted.engine_binary_sha256 == request.get("engine_sha256")
		and FileAccess.get_sha256(OS.get_executable_path()) == request.get("engine_sha256"), "actual installed identity equals original A"): return {}
	var flow: Dictionary = parse(read_pin(request.get("flow_receipt"), "producer receipt"), "producer receipt")
	var descriptor: Dictionary = parse(read_pin(request.get("closed_a_descriptor"), "closed A descriptor"), "closed A descriptor")
	var report: Dictionary = parse(read_pin(request.get("a_report"), "actual A report"), "actual A report")
	var terminal: Dictionary = parse(read_pin(request.get("producer_terminal_report"), "actual C report"), "actual C report")
	if flow.is_empty() or descriptor.is_empty() or report.is_empty() or terminal.is_empty(): return {}
	if not check(flow.get("schema") == "daming_flow_eight_process_v1" and flow.get("complete") == true
		and flow.get("eight_stages_passed") == true and flow.get("final_identity_passed") == true
		and flow.get("lock_released") == true and flow.get("content_version") == trusted.content_version
		and flow.get("engine_sha256") == trusted.engine_binary_sha256, "actual completed producer receipt"): return {}
	var role: String = request.first_role
	var producer_pins: Variant = flow.get("pinned_files")
	if not check(typeof(producer_pins) == TYPE_DICTIONARY, "producer original pin map"): return {}
	for name: String in ["closed_a_descriptor","a_report","a_log","slot","lifecycle","producer_terminal_report"]:
		var row: Variant = request.get(name)
		if not check(typeof(row) == TYPE_DICTIONARY and row.has_all(["path","sha256"])
			and producer_pins.get(row.path) == row.sha256, "exact producer pin " + name): return {}
	var reference: Dictionary = flow.get("roles", {}).get(role, {}).get("closed_a_fixture", {})
	if not check(descriptor.get("schema") == "daming_flow_closed_a_fixture_v1" and descriptor.get("complete") == true
		and descriptor.get("evidence_kind") == "actual_host_validated_closed_a" and descriptor.get("first_role") == role
		and reference.get("sha256") == request.closed_a_descriptor.sha256
		and path(reference.get("path")) == path(request.closed_a_descriptor.path), "actual fixture referenced by producer"): return {}
	if not check(descriptor.get("a_report", {}).get("sha256") == request.a_report.sha256
		and path(descriptor.get("a_report", {}).get("path")) == path(request.a_report.path)
		and descriptor.get("a_log", {}).get("sha256") == request.a_log.sha256
		and path(request.producer_terminal_report.path) == path(request.flow_receipt.path).get_base_dir().path_join(role).path_join("resume_finish/report.json"),
		"exact A report/log and same-role C evidence paths"): return {}
	var source_expected: Dictionary = descriptor.get("expected", {})
	if not check(source_expected.get("content_version") == trusted.content_version
		and source_expected.get("engine_sha256") == trusted.engine_binary_sha256
		and source_expected.get("candidate_manifest_sha256") == request.get("candidate_manifest_sha256"), "descriptor exact candidate binding"): return {}
	var step: Dictionary = descriptor.get("actual_process_step", {})
	if not check(report.get("schema") == "campaign_daming_flow_v1" and report.get("mode") == "save_single"
		and report.get("first_role") == role and report.get("passed") == true and report.get("stage_completed") == true
		and report.get("save_exit_observed") == true and report.get("exit_reason") == "continue_saved"
		and integer(report.get("pid"), int(request.producer_pid)) and int(request.producer_pid) != OS.get_process_id()
		and integer(step.get("pid"), int(request.producer_pid)) and integer(step.get("exit_code"), 0)
		and step.get("passed") == true and step.get("errors") == [] and step.get("stopped_for") == null,
		"distinct actual terminal A and production save exit"): return {}
	for pair: Array in [["batch_nonce","producer_batch_nonce"],["role_nonce","producer_role_nonce"],["process_nonce","producer_process_nonce"]]:
		if not check(report.get(pair[0]) == request.get(pair[1]) and source_expected.get(pair[0]) == request.get(pair[1])
			and report.get(pair[0]) != request.get("consumer_process_nonce"), "exact producer nonce " + pair[0]): return {}
	var log_raw: String = read_pin(request.get("a_log"), "actual A log")
	if not check(not log_raw.is_empty() and step.get("log_sha256") == request.a_log.sha256,
		"actual A log matches terminal step"): return {}
	var binding: Dictionary = request.get("binding", {})
	if not check(Lifecycle.validate_binding(binding).get("ok", false) and binding.get("kind") == "uncredited"
		and descriptor.get("binding") == binding, "strict original uncredited token"): return {}
	var frozen_root: String = path(descriptor.get("frozen_scope"))
	if not check(frozen_root == path(request.closed_a_descriptor.path).get_base_dir().path_join("slot_scope")
		and inventory_matches(frozen_root, descriptor.get("frozen_inventory"), binding.token), "complete frozen two-file six-directory inventory"): return {}
	if not check(path(request.slot.path) == frozen_root.path_join("5088120/1/record_0000000001.json")
		and path(request.lifecycle.path) == frozen_root.path_join("local_runs/" + binding.token + "/5088120/1/record_0000000001.json"),
		"only immutable frozen records are opened"): return {}
	var slot_raw: String = read_pin(request.get("slot"), "original canonical slot")
	var life_raw: String = read_pin(request.get("lifecycle"), "original LC3 record")
	if slot_raw.is_empty() or life_raw.is_empty(): return {}
	var store := Store.new("user://continue/v1")
	slot_decode_called = true
	var decoded: Dictionary = store._decode(slot_raw)
	if not check(decoded.get("ok", false) and integer(decoded.get("revision"), 1)
		and decoded.get("file_sha256") == request.slot.sha256, "actual Slot._decode validates original raw genesis"): return {}
	var packet: Dictionary = decoded.document
	if not check(packet.schema == Store.CAMPAIGN_SCHEMA and packet.context == Profiles.DAMING_CONTEXT
		and packet.binding == binding and packet.resume_paused and packet.world.profile.id == Profiles.DAMING_ID
		and packet.world.content_version == trusted.content_version
		and packet.world.engine_sha256 == trusted.engine_binary_sha256, "native typed Level8 packet binding"): return {}
	var lifecycle := Lifecycle.new(binding.token, "user://continue/v1", Profiles.DAMING_CONTEXT, trusted, "")
	lifecycle_decode_called = true
	var life: Dictionary = lifecycle._decode(life_raw)
	if not check(Lifecycle.CAMPAIGN_SCHEMA == "local_campaign_continue_lifecycle_v3"
		and Intent.SCHEMA == "campaign_progress_intent_v2" and life.get("ok", false)
		and integer(life.get("revision"), 1) and life.get("file_sha256") == binding.receipt_sha256,
		"actual LC3 decode and Intent2 installed"): return {}
	var active: Dictionary = life.document
	if not check(active.generation == 1 and active.token == binding.token and active.state == "active"
		and not active.victory and active.progress_state == "none" and active.intent.is_empty()
		and active.progress_receipt.is_empty() and active.context == Profiles.DAMING_CONTEXT
		and active.scope == {"owner":"","content_version":trusted.content_version,"engine_sha256":trusted.engine_binary_sha256},
		"original active LC has no invented terminal Intent or ACK"): return {}
	var terminal_document: Variant = terminal.get("terminal_checkpoint", {}).get("lifecycle", {}).get("document")
	terminal_document_validate_called = true
	var validated_terminal: Dictionary = lifecycle._validate_document(terminal_document)
	if not check(terminal.get("schema") == "campaign_daming_flow_v1" and terminal.get("mode") == "resume_finish"
		and terminal.get("first_role") == role and terminal.get("passed") == true
		and terminal.get("batch_nonce") == request.get("producer_batch_nonce")
		and validated_terminal.get("ok", false) and integer(validated_terminal.get("revision"), 3)
		and validated_terminal.document.token == binding.token
		and validated_terminal.document.intent.schema == "campaign_progress_intent_v2"
		and validated_terminal.document.progress_receipt.schema == "campaign_progress_ack_v2",
		"producer same-token C retains strict current LC3 Intent2 ACK2, no legacy allowance"): return {}
	var level: Dictionary = Codec.new().decode(packet.world.sections.level.payload)
	var mission: Dictionary = Codec.new().decode(packet.world.sections.mission.payload)
	if not check(level.get("ok", false) and mission.get("ok", false), "real production Codec decodes Level and Mission"): return {}
	var first: Variant = level.value.references.get(role)
	var other: Variant = level.value.references.get("shi" if role == "lu" else "lu")
	if not check(typeof(first) == TYPE_STRING and typeof(other) == TYPE_STRING and first != other
		and not first.is_empty() and not other.is_empty() and mission.value.events.has("daming_" + role + "_safe")
		and not mission.value.events.has("daming_" + ("shi" if role == "lu" else "lu") + "_safe"), "typed original single-safe role/event fixture"): return {}
	if not check(unchanged() and inventory_matches(frozen_root, descriptor.frozen_inventory, binding.token),
		"all input bytes and frozen directories unchanged after native decode"): return {}
	return {"packet":packet,"world":packet.world,"slot_raw":slot_raw,"lifecycle":active,
		"first_role":role,"safe_id":first,"other_id":other,"descriptor":descriptor,
		"source_report":report,"trusted":trusted,"mission":mission.value,"level":level.value}
