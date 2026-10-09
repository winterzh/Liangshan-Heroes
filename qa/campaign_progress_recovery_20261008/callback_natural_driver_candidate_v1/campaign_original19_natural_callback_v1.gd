extends "res://tools/campaign_original19_first_repeat_v1.gd"
## Single actual natural callback path; all parent orders/guards remain unchanged.
## Runtime publication, owned debugger custody and complete host validation are
## still required. This candidate grants no original19 or SDK qualification.
var callback_observer
var callback_case: String="callback_sees_new_memory"

func _fresh() -> void:
	if not check(mode=="first" and OS.get_environment("CAMPAIGN_CALLBACK_CASE")==callback_case,"single actual natural callback mode"): return
	var profile: String=OS.get_environment("CAMPAIGN_TERMINAL_PROFILE")
	var Observer: Script=load("res://tools/campaign_callback_snapshot_v1.gd")
	if not check(Observer!=null,"actual read-only callback observer script loaded"): return
	callback_observer=Observer.new()
	if not check(callback_observer.install(self,nonce,callback_case,profile,identity),"actual private observer registered on production nodes"): return
	var ready: Dictionary={"schema":"campaign_callback_driver_ready_v1","pid":OS.get_process_id(),"nonce":nonce,"case":callback_case,"identity":identity.duplicate(true),"user_directory":OS.get_user_data_dir()}
	if not check(_write("callback_driver_ready.json",ready),"immutable actual callback driver identity handshake"): return
	await super._fresh()

func _write(name: String,value: Dictionary) -> bool:
	if name!="callback_driver_ready.json": return super._write(name,value)
	var path: String=output.path_join(name)
	var pending: String=path+".native-"+nonce
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path) or FileAccess.file_exists(pending) or DirAccess.dir_exists_absolute(pending): return false
	var file: FileAccess=FileAccess.open(pending,FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(value,"\t")+"\n");file.flush();file.close()
	print("CAMPAIGN_FILE19_EXPORT ",OS.get_process_id()," ",nonce," ",name," ",FileAccess.get_sha256(pending))
	return true

func _finish() -> void:
	check(mode=="first","callback report requires actual first mode")
	check(callback_observer!=null and callback_observer.last_sequence==1,"actual owned host requested exactly one callback snapshot")
	if callback_observer!=null: callback_observer.close()
	var report: Dictionary={"schema":"campaign_original19_natural_callback_probe_v1","passed":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"pid":OS.get_process_id(),"nonce":nonce,"mode":mode,"orders":orders,"identity":identity,"user_directory":OS.get_user_data_dir(),"time_scale":Engine.time_scale,"physics_ticks":Engine.physics_ticks_per_second,"case":callback_case,"natural_parent_case":case_id,"seal_evidence":seal_evidence,"observer_sequence":callback_observer.last_sequence if callback_observer!=null else 0,"scope":"Actual ordinary first Huangnigang full victory with QA-only production callback snapshot; host must separately bind owned PID, exact stack and original packet custody.","actual_callback_qualified":false,"original19_faults_qualified":false,"Steam_rewards_qualified":false,"overall_goal_qualified":false}
	if not _write("report.json",report): quit(2);return
	print("CAMPAIGN_ORIGINAL19_NATURAL_CALLBACK ",callback_case," ",report.passed," ",checks.size())
	quit(0 if report.passed else 1)
