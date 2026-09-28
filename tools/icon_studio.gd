extends SceneTree
## Renders every item's 3D model to a transparent 256 px PNG icon in
## art/icons/items. Crops are rendered first because seed packets show them.
## Run (needs a window): godot --path . -s res://tools/icon_studio.gd
## Optional: -- --only=hoe,wheat

const OUT := "res://art/icons/items/"
const SIZE := 256

var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_8X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.76, 0.84)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 0.05
	env.ssao_intensity = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

	_light(Vector3(-40, -35, 0), Color(1.0, 0.96, 0.9), 1.9, true)
	_light(Vector3(-15, 60, 0), Color(0.8, 0.86, 1.0), 0.7, false)
	_light(Vector3(-20, 170, 0), Color(1.0, 0.95, 0.9), 1.4, false)

	_cam = Camera3D.new()
	_cam.fov = 24.0
	_cam.near = 0.01
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	_run.call_deferred()


func _light(rot_deg: Vector3, color: Color, energy: float, shadows: bool) -> void:
	var l := DirectionalLight3D.new()
	l.rotation_degrees = rot_deg
	l.light_color = color
	l.light_energy = energy
	l.shadow_enabled = shadows
	_vp.add_child(l)


func _run() -> void:
	var only := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	var crops := []
	var seeds := []
	var others := []
	for id: StringName in ItemTable.ITEMS:
		if not only.is_empty() and String(id) not in only:
			continue
		var cat: String = ItemTable.ITEMS[id]["cat"]
		if cat == "crop":
			crops.append(id)
		elif cat == "seed":
			seeds.append(id)
		else:
			others.append(id)
	for id in crops + others + seeds:
		await _render(id)
	print("ICONS DONE")
	quit()


func _render(id: StringName) -> void:
	for c in _holder.get_children():
		c.queue_free()
	var mi := MeshInstance3D.new()
	mi.mesh = ItemModels.mesh(id)
	var rot: Vector3 = ItemModels.ICON_ROTATION.get(id, Vector3(12, 30, 0))
	mi.rotation_degrees = rot
	_holder.add_child(mi)
	# Frame the rotated bounding box, or the tool's working end for long tools.
	var aabb := mi.transform * mi.mesh.get_aabb()
	var center := aabb.get_center()
	var radius := aabb.size.length() * 0.5
	if ItemModels.ICON_FRAME.has(id):
		var frame: Array = ItemModels.ICON_FRAME[id]
		center = mi.transform * (frame[0] as Vector3)
		radius = frame[1]
	var dist := radius / sin(deg_to_rad(_cam.fov * 0.5)) * 0.92
	var view_dir := Vector3(0, 0.35, 1).normalized()
	_cam.global_position = center + view_dir * dist
	_cam.look_at(center, Vector3.UP)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT + String(id) + ".png")
	img.save_png(path)
	print("icon ", id)
