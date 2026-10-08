extends RefCounted
## QA-only read-only observation; no replacement or modification of game nodes.
## EngineDebugger compatibility and paused delivery require future native proof.
const CAPTURE := &"lsh_callback19"
const IDS := ["callback_sees_new_memory","cloud_applying_callback_no_upload_claim","legacy_real_cloud_apply_failure_boundary"]
var tree: SceneTree
var nonce: String=""
var case_id: String=""
var profile: String=""
var identity: Dictionary={}
var active: bool=false
var last_sequence: int=0
var campaign_id: int=0
var cloud_id: int=0

func install(actual_tree: SceneTree,actual_nonce: String,actual_case: String,actual_profile: String,actual_identity: Dictionary) -> bool:
	if active or actual_tree==null or actual_nonce.length()!=32 or actual_case not in IDS or not actual_profile.is_absolute_path() or not actual_identity.get("save_eligible",false): return false
	if not EngineDebugger.is_active() or EngineDebugger.has_capture(CAPTURE) or OS.get_environment("STEAM_DISABLED")!="1" or not OS.get_environment("CAMPAIGN_QA").is_empty(): return false
	var normalized: String=actual_profile.replace("\\","/").simplify_path().trim_suffix("/")
	for key in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
		if OS.get_environment(key).replace("\\","/").simplify_path().to_lower()!=normalized.path_join(key.to_lower()).to_lower(): return false
	if not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(normalized.path_join("appdata").to_lower()+"/"): return false
	var campaign: Node=actual_tree.root.get_node_or_null("Campaign")
	var cloud: Node=actual_tree.root.get_node_or_null("SteamCloud")
	if not _production_nodes(campaign,cloud): return false
	tree=actual_tree;nonce=actual_nonce;case_id=actual_case;profile=normalized;identity=actual_identity.duplicate(true)
	campaign_id=campaign.get_instance_id();cloud_id=cloud.get_instance_id()
	EngineDebugger.register_message_capture(CAPTURE,_capture)
	active=true
	EngineDebugger.send_message("lsh_callback19:ready",[OS.get_process_id(),nonce,case_id,JSON.stringify({"campaign_id":campaign_id,"cloud_id":cloud_id,"identity":identity,"user_directory":OS.get_user_data_dir()})])
	return true

func _production_nodes(campaign: Node,cloud: Node) -> bool:
	return is_instance_valid(campaign) and is_instance_valid(cloud) and campaign.is_inside_tree() and cloud.is_inside_tree() and campaign.get_script()!=null and cloud.get_script()!=null and campaign.get_script().resource_path=="res://scripts/campaign.gd" and cloud.get_script().resource_path=="res://scripts/steam_cloud.gd"

func _capture(message: String,data: Array) -> bool:
	if not active or message!="read" or data.size()!=4: return false
	if typeof(data[0])!=TYPE_INT or data[0]!=OS.get_process_id() or typeof(data[1])!=TYPE_STRING or data[1]!=nonce or typeof(data[2])!=TYPE_STRING or data[2]!=case_id: return false
	if typeof(data[3])!=TYPE_INT or data[3]!=last_sequence+1 or data[3]>8: return false
	var campaign: Node=tree.root.get_node_or_null("Campaign")
	var cloud: Node=tree.root.get_node_or_null("SteamCloud")
	if not _production_nodes(campaign,cloud) or campaign.get_instance_id()!=campaign_id or cloud.get_instance_id()!=cloud_id: return false
	var value: Dictionary={"schema":"campaign_callback_readonly_snapshot_v1","pid":OS.get_process_id(),"nonce":nonce,"case":case_id,"sequence":data[3],"identity":identity.duplicate(true),"user_directory":OS.get_user_data_dir(),"campaign_id":campaign_id,"cloud_id":cloud_id,
		"campaign_memory":{"records":campaign.records.duplicate(true),"unlocked":campaign.unlocked,"owner":campaign.cloud_owner},
		"cloud_state":{"dirty":cloud.dirty,"pending_upload":cloud._pending_upload,"revision":cloud._revision,"applying":cloud._applying,"owner":cloud._owner,"shared_profile_pending":cloud.shared_profile_pending()},
		"campaign_persistence_busy":campaign.persistence_busy(),"time_scale":Engine.time_scale,"physics_ticks":Engine.physics_ticks_per_second,
		"original19_qualified":false,"SDK_reward_once_qualified":false,"overall_goal_qualified":false}
	var encoded: String=JSON.stringify(value)
	if encoded.to_utf8_buffer().size()>2097152: return false
	last_sequence=data[3]
	EngineDebugger.send_message("lsh_callback19:snapshot",[OS.get_process_id(),nonce,case_id,last_sequence,encoded])
	return true

func close() -> void:
	if active:
		EngineDebugger.unregister_message_capture(CAPTURE)
		active=false
