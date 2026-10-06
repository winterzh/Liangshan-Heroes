extends SceneTree
func _initialize() -> void:
	var values: Array = JSON.parse_string(FileAccess.get_file_as_string("res://numbers.json"))
	var differences := []
	for row in values:
		var bits := PackedFloat64Array([float(row.number)]).to_byte_array().hex_encode()
		if bits!=row.expected_ieee64_le:
			differences.append({"path":row.path,"expected":row.expected_ieee64_le,"parsed":bits,"parsed_text":str(row.number)})
	var f := FileAccess.open("res://result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"numbers":values.size(),"differences":differences},"\t",true,true));f.close()
	print("JSON_NUMERIC_PROBE ",values.size()," values, ",differences.size()," different bit patterns")
	quit()
