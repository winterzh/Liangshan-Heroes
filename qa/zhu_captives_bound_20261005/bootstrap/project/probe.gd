extends SceneTree
func _initialize(): call_deferred("_run")
func _run():
 var rows = JSON.parse_string(FileAccess.get_file_as_string("res://inputs.json"))
 var checks = []
 var passed = true
 for row in rows:
  var texture = load("res://" + row.path)
  var ok = texture is Texture2D and texture.get_width() == row.native_size[0] and texture.get_height() == row.native_size[1] and FileAccess.get_sha256("res://" + row.path) == row.sha256
  checks.append({"path":row.path,"width":texture.get_width() if texture is Texture2D else 0,"height":texture.get_height() if texture is Texture2D else 0,"passed":ok})
  passed = passed and ok
 var f = FileAccess.open("res://dimensions.json", FileAccess.WRITE)
 f.store_string(JSON.stringify({"passed":passed,"checks":checks},"  "))
 quit(0 if passed else 1)
