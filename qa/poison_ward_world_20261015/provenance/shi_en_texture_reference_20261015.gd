extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	if OS.get_environment("STEAM_DISABLED")!="1":quit(2);return
	var inputs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHI_EN_PACK_INPUTS")))
	var images: Dictionary={}
	for p in inputs.textures:
		var tex: Texture2D=load("res://"+String(p))
		if tex==null:quit(3);return
		var im:=tex.get_image()
		if im.is_compressed() and im.decompress()!=OK:quit(4);return
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(im.get_data())
		images[p]={"size":[im.get_width(),im.get_height()],"format":im.get_format(),"mipmaps":im.has_mipmaps(),"data_sha256":hash.finish().hex_encode()}
	FileAccess.open(OS.get_environment("SHI_EN_TEXTURE_REFERENCE_OUT"),FileAccess.WRITE).store_string(JSON.stringify(images,"\t")+"\n")
	print("SHI_EN_IMPORTED_TEXTURE_REFERENCES ",images.size())
	quit()
