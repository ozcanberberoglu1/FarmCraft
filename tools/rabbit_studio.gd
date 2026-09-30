extends SceneTree
## Renders the wild rabbit (RabbitRig) to a contact sheet for review: sitting, grazing,
## alert, a close look at the head, then frames through a lazy hop and a flat-out bound
## seen from the side. Run (needs a window):
##   godot --path . -s res://tools/rabbit_studio.gd -- --out=/abs/sheet.png [--only=hop|run|still]

const CELL := Vector2i(480, 360)

var _vp: SubViewport
var _cam: Camera3D
var _rig: RabbitRig


func _initialize() -> void:
	_vp = SubViewport.new()
	_vp.size = CELL
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.35, 0.52, 0.78)
	sm.sky_horizon_color = Color(0.72, 0.78, 0.84)
	sm.ground_bottom_color = Color(0.22, 0.24, 0.16)
	sm.ground_horizon_color = Color(0.5, 0.55, 0.45)
	sky.sky_material = sm
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 0.1
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 130, 0)
	sun.light_energy = 2.2
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 6.0
	_vp.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.3, 0.37, 0.2)
	gm.roughness = 1.0
	ground.material_override = gm
	_vp.add_child(ground)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_cam.near = 0.02
	_vp.add_child(_cam)
	_rig = RabbitRig.create()
	_vp.add_child(_rig)
	_run.call_deferred()


func _run() -> void:
	var out := "user://rabbit_sheet.png"
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--only="):
			only = a.substr(7)
	var cells: Array[Image] = []
	var t := Vector3(0, 0.12, 0)
	if only == "" or only == "still":
		cells.append(await _still(RabbitRig.Mode.SIT, Vector3(0.55, 0.3, -0.75), t))
		cells.append(await _still(RabbitRig.Mode.SIT, Vector3(1.05, 0.16, -0.05), t))
		cells.append(await _still(RabbitRig.Mode.GRAZE, Vector3(0.7, 0.35, -0.6), t))
		cells.append(await _still(RabbitRig.Mode.ALERT, Vector3(0.75, 0.3, -0.7), t + Vector3(0, 0.04, 0)))
		cells.append(await _still(RabbitRig.Mode.SIT, Vector3(0.28, 0.2, -0.26), Vector3(0, 0.15, -0.12), 26.0))
		cells.append(await _still(RabbitRig.Mode.SIT, Vector3(0.6, 0.35, 0.8), t))
		cells.append(await _still(RabbitRig.Mode.GRAZE, Vector3(1.05, 0.16, -0.05), t))
	for gait: Array in [["hop", 0.75], ["run", 7.0]]:
		if only != "" and only != gait[0]:
			continue
		for i in 8:
			cells.append(await _gait(float(gait[1]), i / 8.0))
	var cols := 4
	var rows := (cells.size() + cols - 1) / cols
	var sheet := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGBA8)
	for i in cells.size():
		var img := cells[i]
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
	sheet.save_png(out)
	print("RABBIT SHEET ", out)
	quit()


func _still(mode: int, cam: Vector3, target: Vector3, fov := 30.0) -> Image:
	_rig._phase = 0.0
	for i in 90:
		_rig.animate(1.0 / 60.0, 0.0, mode)
	return await _shot(cam, target, fov)


## Side view of the hop at `speed` (m/s), at phase `p`.
func _gait(speed: float, p: float) -> Image:
	for i in 70:
		_rig.animate(1.0 / 60.0, speed, RabbitRig.Mode.HOP)
	_rig._phase = p
	_rig.animate(0.00001, speed, RabbitRig.Mode.HOP)
	return await _shot(Vector3(0.95, 0.14, -0.02), Vector3(0, 0.1, -0.02))


func _shot(cam: Vector3, target: Vector3, fov := 30.0) -> Image:
	_cam.fov = fov
	_cam.global_position = cam
	_cam.look_at(target, Vector3.UP)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	return _vp.get_texture().get_image()
