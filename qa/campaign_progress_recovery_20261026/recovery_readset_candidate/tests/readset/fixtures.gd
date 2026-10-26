extends RefCounted
## Synthetic, in-memory file-protocol fixtures only. No filesystem writes,
## recovery, world mounting, Flow qualification, or alteration of source bytes.
const SlotScript = preload("res://scripts/run_slot_store.gd")
const CFGScript = preload("res://scripts/run_campaign_cfg_transaction.gd")
const Core = preload("res://scripts/run_battle_world_core.gd")
const SceneryJSON = preload("res://scripts/run_scenery_json_boundary.gd")
const ZERO := "0000000000000000000000000000000000000000000000000000000000000000"

## A real subclass resource, deliberately distinct from the installed exact Slot.
## Inherits its constructor and every production method without replacement.
class DerivedSlot extends "res://scripts/run_slot_store.gd":
	pass

static func _bad(code: String, stage: String = "", detail: Dictionary = {}) -> Dictionary:
	return {"ok":false,"code":code,"fixture_stage":stage,"detail":detail.duplicate(true),
		"synthetic":true,"world_mount_qualified":false,"flow_qualified":false}

static func _checked_envelope(store: RefCounted, document: Dictionary, previous: String) -> Dictionary:
	var payload: String = JSON.stringify(document)
	var envelope: Dictionary = {"magic":String(store._magic()),"version":"1","app":String(store.APP),
		"owner":String(store.owner),"revision":str(int(document.generation)),"previous_sha256":previous,
		"payload_bytes":str(payload.to_utf8_buffer().size()),"payload_sha256":payload.sha256_text(),"payload":payload}
	var raw: String = JSON.stringify(envelope)
	var checked: Dictionary = store._decode(raw)
	if not checked.get("ok",false):
		return _bad(String(checked.get("code","FIXTURE_DECODE_FAILED")),"synthetic_decode",checked)
	if checked.file_sha256 != raw.sha256_text() or checked.previous != previous \
		or checked.revision != int(document.generation) or checked.document != document:
		return _bad("FIXTURE_DECODE_CHANGED","synthetic_decode")
	return {"ok":true,"code":"OK","raw":raw,"sha256":raw.sha256_text(),
		"document":checked.document.duplicate(true),"synthetic":true,
		"world_mount_qualified":false,"flow_qualified":false}

static func slot_variants(slot: RefCounted, original_envelope: String) -> Dictionary:
	if slot == null or slot.get_script() != SlotScript:
		return _bad("FIXTURE_EXACT_SLOT_REQUIRED","source")
	if original_envelope.is_empty() or original_envelope.to_utf8_buffer().size() > slot._byte_limit():
		return _bad("FIXTURE_SOURCE_SIZE","source")
	# Validate the complete original envelope using the actual installed Slot.
	# It remains a caller-owned String; this helper never opens or writes a file.
	var opened: Dictionary = slot._decode(original_envelope)
	if not opened.get("ok",false):
		return _bad(String(opened.get("code","FIXTURE_SOURCE_DECODE_FAILED")),"source",opened)
	var source: Dictionary = opened.document
	if source.schema != SlotScript.SCHEMA or source.context != SlotScript.CONTEXT:
		return _bad("FIXTURE_CLASSIC_SOURCE_REQUIRED","source")
	var document: Dictionary = source.duplicate(true)
	var map_sections: Dictionary = {}
	for section: String in SceneryJSON.MAP_SECTIONS:
		map_sections[section] = {}
	var content: String = String(source.world.content_version)
	map_sections.display = {"schema":"scenery_state_v2","content_version":content,"kind":"none"}
	var sections: Dictionary = {}
	for section: String in Core.SECTIONS:
		sections[section] = {}
	sections.map = {"schema":"game_map_v2","content_version":content,"sections":map_sections}
	document.world.sections = sections
	# Keep the genuine source options/session/root Codec payloads, binding,
	# context and world identity. Empty non-map sections are intentionally not
	# a mountable Battle world, even though the Slot document boundary accepts it.
	document.generation = 1
	document.resume_paused = true
	var a: Dictionary = _checked_envelope(slot,document,ZERO)
	if not a.ok: return a
	var b_document: Dictionary = document.duplicate(true)
	b_document.resume_paused = false
	var b: Dictionary = _checked_envelope(slot,b_document,ZERO)
	if not b.ok: return b
	var h_document: Dictionary = document.duplicate(true)
	h_document.generation = 2
	var h: Dictionary = _checked_envelope(slot,h_document,String(b.sha256))
	if not h.ok: return h
	if a.sha256 == b.sha256:
		return _bad("FIXTURE_VARIANTS_NOT_DISTINCT","variants")
	return {"ok":true,"code":"OK","a":a,"b":b,"h":h,
		"source_sha256":original_envelope.sha256_text(),"synthetic":true,
		"world_mount_qualified":false,"flow_qualified":false}

static func cfg_bad_genesis(cfg: RefCounted, content: String, engine_sha: String, token: String) -> Dictionary:
	if cfg == null or cfg.get_script() != CFGScript:
		return _bad("FIXTURE_EXACT_CFG_REQUIRED","cfg")
	# Individually valid data, deliberately invalid as a standalone chain:
	# production CFG._chain requires generation 1 to be state "prepared".
	var document: Dictionary = {"schema":CFGScript.CFG_SCHEMA,"generation":1,"state":"applied",
		"transaction":token,"original_sha256":ZERO,"candidate_sha256":"1".repeat(64),
		"semantics_sha256":"2".repeat(64),"original_owner":"","target_owner":"",
		"content_version":content,"engine_sha256":engine_sha,"operation":"prefs",
		"run_token":"","intent_sha256":""}
	var checked: Dictionary = _checked_envelope(cfg,document,ZERO)
	if not checked.ok: return checked
	checked.expected_chain_code = "CFG_PREPARED_GENESIS_REQUIRED"
	checked.chain_checked = false
	return checked
