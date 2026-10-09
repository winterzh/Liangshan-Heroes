extends SceneTree
## New deterministic geometry reference. Never reads or edits character bitmaps.

func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=color
	m.roughness=0.9
	return m

func ball(parent: Node3D, p: Vector3, r: float, color: Color) -> void:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius=r
	mesh.height=r*2
	n.mesh=mesh
	n.material_override=material(color)
	n.position=p
	parent.add_child(n)

func segment(parent: Node3D, a: Vector3, b: Vector3, r: float, color: Color) -> void:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius=r
	mesh.bottom_radius=r
	mesh.height=a.distance_to(b)
	n.mesh=mesh
	n.material_override=material(color)
	n.position=(a+b)*0.5
	n.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	parent.add_child(n)

func box(parent: Node3D, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=size
	n.mesh=mesh
	n.position=center
	n.material_override=material(color)
	parent.add_child(n)
	return n

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://geometry_config.json"))
	var x_sign: float = float(config.x_sign)
	var vp := SubViewport.new()
	vp.size=Vector2i(768,768)
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("ecece5")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=0.8
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-55,-30,0)
	world.add_child(light)
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.12
	camera.position=Vector3(config.camera[0],config.camera[1],config.camera[2])+Vector3(0,0.82,0)
	world.add_child(camera)
	camera.look_at(Vector3(0,0.82,0))
	camera.current=true
	var gray := Color("758080")
	var red := Color("db4037")
	var blue := Color("306cda")
	# Reference is deliberately broad and short adult; no costume, face or weapon.
	box(world,Vector3(-0.04,1.01,-0.025),Vector3(0.58,0.49,0.34),gray)
	box(world,Vector3(-0.04,0.755,-0.025),Vector3(0.46,0.12,0.31),gray)
	segment(world,Vector3(-0.04,1.24,-0.025),Vector3(-0.04,1.38,-0.025),0.08,gray)
	ball(world,Vector3(-0.04,1.51,-0.025),0.137,gray)
	ball(world,Vector3(-0.04,1.51,-0.167),0.038,gray)
	for sign_value in [-1.0,1.0]:
		var shoulder := Vector3(sign_value*0.34-0.04,1.18,-0.025)
		var elbow := Vector3(sign_value*0.38-0.04,0.94,-0.03)
		var hand := Vector3(sign_value*0.37-0.04,0.76,-0.03)
		segment(world,shoulder,elbow,0.078,gray)
		segment(world,elbow,hand,0.065,gray)
		ball(world,hand,0.070,gray)
	var left_hip := Vector3(0.17*x_sign,0.755,-0.025)
	var left_knee := Vector3(0.17*x_sign,0.425,0.0)
	var left_ankle := Vector3(0.18*x_sign,0.135,0.0)
	var right_hip := Vector3(-0.17*x_sign,0.755,-0.025)
	var right_knee := Vector3(-0.18*x_sign,0.48,-0.10)
	var right_ankle := Vector3(-0.18*x_sign,0.225,0.005)
	for leg in [[left_hip,left_knee,left_ankle,red],[right_hip,right_knee,right_ankle,blue]]:
		segment(world,leg[0],leg[1],0.092,leg[3])
		segment(world,leg[1],leg[2],0.074,leg[3])
		ball(world,leg[1],0.083,leg[3])
	var planted := box(world,Vector3(0.18*x_sign,0.055,-0.065),Vector3(0.145,0.11,0.31),red)
	var lifted := box(world,Vector3(-0.18*x_sign,0.17,-0.07),Vector3(0.145,0.11,0.31),blue)
	lifted.rotation.x=0.03
	# Flat green patch only marks contact plane; it is not a game floor.
	box(world,Vector3(0.18*x_sign,-0.009,-0.065),Vector3(0.21,0.018,0.38),Color("5fac66"))
	var labels := Control.new()
	vp.add_child(labels)
	var heading := Label.new()
	heading.text="NEW GEOMETRY ONLY: "+String(config.direction).to_upper()+" "+String(config.phase)+" near-foot passing"
	heading.position=Vector2(18,12)
	heading.add_theme_color_override("font_color",Color("252b29"))
	heading.add_theme_font_size_override("font_size",20)
	labels.add_child(heading)
	var legend := Label.new()
	legend.text="RED = flat support boot. BLUE = low raised boot.\nNo source bitmap, costume, skin, weapon or production artwork."
	legend.position=Vector2(18,704)
	legend.add_theme_color_override("font_color",Color("252b29"))
	legend.add_theme_font_size_override("font_size",17)
	labels.add_child(legend)
	await process_frame
	await RenderingServer.frame_post_draw
	var support_screen := camera.unproject_position(planted.global_position)
	var swing_screen := camera.unproject_position(lifted.global_position)
	var code := vp.get_texture().get_image().save_png("res://"+String(config.output))
	var f := FileAccess.open("res://geometry_result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":code==OK,"scope":"New primitive geometry only; no bitmap input or edit",
		"camera":config.camera,"direction":config.direction,"phase":config.phase,"support_screen":[support_screen.x,support_screen.y],"swing_screen":[swing_screen.x,swing_screen.y],"support_on_image_left":support_screen.x<swing_screen.x,"planted_boot_center":[planted.position.x,planted.position.y,planted.position.z],
		"planted_boot_size":[0.145,0.11,0.31],"planted_boot_bottom_y":planted.position.y-0.055,
		"raised_boot_center":[lifted.position.x,lifted.position.y,lifted.position.z],"raised_boot_rotation_x":lifted.rotation.x,
		"left_chain":[[left_hip.x,left_hip.y,left_hip.z],[left_knee.x,left_knee.y,left_knee.z],[left_ankle.x,left_ankle.y,left_ankle.z]],
		"right_chain":[[right_hip.x,right_hip.y,right_hip.z],[right_knee.x,right_knee.y,right_knee.z],[right_ankle.x,right_ankle.y,right_ankle.z]]},"  "))
	quit(0 if code==OK else 1)
