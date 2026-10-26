extends SceneTree
func _initialize() -> void:
 call_deferred("probe")
func probe() -> void:
 var pid: int = int(OS.get_environment("PROBE_OTHER_PID"))
 var report := {"engine":Engine.get_version_info(),"observer_pid":OS.get_process_id(),"other_pid":pid,"self_query":OS.is_process_running(OS.get_process_id()),"other_query":OS.is_process_running(pid),"api":"OS.is_process_running","no_gameplay_or_store_test":true}
 var file := FileAccess.open(OS.get_environment("PROBE_REPORT"),FileAccess.WRITE)
 if file == null: quit(2); return
 file.store_string(JSON.stringify(report,"\t"));file.flush();file.close()
 print("PROCESS_LIVENESS_API_PROBE ",report)
 quit(0)
