extends "res://tools/campaign_callback_snapshot_v1.gd"
## QA-only receive acknowledgement; never changes a production game node.
## Host must send breakpoint then arm on the same original debugger transport.
## Native command ordering/paused capture compatibility is still unqualified.
var arm_received: bool=false
var arm_ack: Dictionary={}

func _capture(message: String,data: Array) -> bool:
	if message=="arm":
		if not active or arm_received or last_sequence!=0 or case_id!="cloud_applying_callback_no_upload_claim" or data.size()!=4: return false
		if typeof(data[0])!=TYPE_INT or data[0]!=OS.get_process_id() or typeof(data[1])!=TYPE_STRING or data[1]!=nonce or typeof(data[2])!=TYPE_STRING or data[2]!=case_id or typeof(data[3])!=TYPE_INT or data[3]!=0: return false
		var campaign: Node=tree.root.get_node_or_null("Campaign")
		var cloud: Node=tree.root.get_node_or_null("SteamCloud")
		if not _production_nodes(campaign,cloud) or campaign.get_instance_id()!=campaign_id or cloud.get_instance_id()!=cloud_id: return false
		if OS.get_environment("STEAM_DISABLED")!="1" or not OS.get_environment("CAMPAIGN_QA").is_empty(): return false
		arm_ack={"schema":"campaign_cloud_callback_arm_received_v2","pid":OS.get_process_id(),"nonce":nonce,"case":case_id,"sequence":0,"campaign_id":campaign_id,"cloud_id":cloud_id,"identity":identity.duplicate(true),"user_directory":OS.get_user_data_dir(),"SDK_reward_once_qualified":false,"actual_callback_qualified":false,"overall_goal_qualified":false}
		arm_received=true
		EngineDebugger.send_message("lsh_callback19:armed",[OS.get_process_id(),nonce,case_id,0,JSON.stringify(arm_ack)])
		return true
	if message=="read" and not arm_received: return false
	return super._capture(message,data)
