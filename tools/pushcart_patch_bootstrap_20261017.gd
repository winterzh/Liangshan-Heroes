extends SceneTree
## Mount the verified exported overlay before loading the frozen external QA.
## No gameplay art is generated here. Actual strict-owner and packed-identity
## probes fail if stale base scripts or resources survive in the loader cache.
var mount_ok:=false
func _init() -> void:
	var chain_path:=OS.get_environment("PUSHCART_PATCH_CHAIN")
	if chain_path.is_empty() or OS.get_environment("STEAM_DISABLED")!="1":return
	var chain=JSON.parse_string(FileAccess.get_file_as_string(chain_path))
	if not chain is Array or chain.size()<2:return
	# Godot removes --main-pack from get_cmdline_args(). Verify declared bytes;
	# the Python receipt retains the actual --main-pack invocation and path.
	if FileAccess.get_sha256(chain[0].path)!=String(chain[0].sha256):return
	for i in range(1,chain.size()):
		var row: Dictionary=chain[i]
		if FileAccess.get_sha256(row.path)!=String(row.sha256):return
		if not ProjectSettings.load_resource_pack(row.path,true):return
		print("PCK_PATCH_MOUNTED ",i," ",row.sha256)
	mount_ok=true
func _initialize() -> void:
	if not mount_ok:push_error("Verified base+patch chain was not mounted");quit(2);return
	# Release presets deliberately exclude tools/*. Candidate probes stay outside
	# the pack; production textures/scripts and identity load through mounted res://.
	var entry:=OS.get_environment("PUSHCART_PATCH_ENTRY").replace("\\","/")
	var source_root:=OS.get_environment("PUSHCART_QA_SOURCE_ROOT").replace("\\","/")
	if source_root.is_empty() or entry not in [source_root.path_join("tools/ruan_xiaoer_pushcart_20261017.gd"),source_root.path_join("tools/ruan_xiaoer_pushcart_identity_20261017.gd")]:
		push_error("Unexpected frozen external QA entry");quit(2);return
	if FileAccess.get_sha256(entry)!=OS.get_environment("PUSHCART_QA_ENTRY_SHA"):
		push_error("External QA entry differs from frozen source");quit(2);return
	var script=load(entry)
	if script==null:push_error("Frozen QA script unavailable");quit(2);return
	var task=script.new()
	if not task is Node:push_error("QA must be a Node on the real main SceneTree");quit(2);return
	root.add_child.call_deferred(task)
