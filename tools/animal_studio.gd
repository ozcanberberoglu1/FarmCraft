extends SceneTree
## Renders the livestock models in several poses to a contact sheet for review.
## Run (needs a window): godot --path . -s res://tools/animal_studio.gd -- --out=/abs/path.png

const CELL := Vector2i(560, 420)

var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D


func _initialize() -> void:
	_vp = SubViewport.new()
	_vp.size = CELL
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.72, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.76, 0.84)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	_vp.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.44, 0.24)
	gm.roughness = 1.0
	ground.material_override = gm
	_vp.add_child(ground)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	_run.call_deferred()


func _run() -> void:
	var out := "user://animals.png"
	var only := ""
	var heads := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--only="):
			only = a.substr(7)
		elif a == "--heads":
			heads = true
		elif a == "--check":
			only = "check"
	# [species, variant, baby, mode, speed, yaw, camera distance]
	var shots := [
		[&"cow", 0, false, AnimalRig.Mode.IDLE, 0.0, 50.0, 4.4], [&"cow", 1, false, AnimalRig.Mode.WALK, 0.8, 90.0, 4.4],
		[&"cow", 2, false, AnimalRig.Mode.GRAZE, 0.0, 130.0, 4.4], [&"cow", 0, true, AnimalRig.Mode.IDLE, 0.0, 60.0, 3.0],
		[&"horse", 0, false, AnimalRig.Mode.IDLE, 0.0, 50.0, 4.6], [&"horse", 1, false, AnimalRig.Mode.RUN, 11.0, 90.0, 4.6],
		[&"horse", 3, false, AnimalRig.Mode.GRAZE, 0.0, 120.0, 4.6], [&"horse", 2, true, AnimalRig.Mode.WALK, 0.9, 70.0, 3.2],
		[&"sheep", 0, false, AnimalRig.Mode.IDLE, 0.0, 50.0, 2.6], [&"sheep", 1, false, AnimalRig.Mode.WALK, 0.75, 90.0, 2.6],
		[&"sheep", 2, false, AnimalRig.Mode.SLEEP, 0.0, 60.0, 2.6], [&"cow", 0, false, AnimalRig.Mode.SLEEP, 0.0, 60.0, 4.4],
		[&"chicken", 0, false, AnimalRig.Mode.IDLE, 0.0, 60.0, 1.1], [&"chicken", 1, false, AnimalRig.Mode.WALK, 0.8, 90.0, 1.1],
		[&"chicken", 2, false, AnimalRig.Mode.GRAZE, 0.0, 40.0, 1.1], [&"chicken", 3, true, AnimalRig.Mode.IDLE, 0.0, 60.0, 0.7],
	]
	if only == "check":
		# Lying poses and the recoloured coats up close.
		shots = [
			[&"cow", 0, false, AnimalRig.Mode.SLEEP, 0.0, 90.0, 4.4], [&"cow", 0, false, AnimalRig.Mode.SLEEP, 0.0, 30.0, 4.4],
			[&"sheep", 0, false, AnimalRig.Mode.SLEEP, 0.0, 90.0, 2.6], [&"sheep", 0, false, AnimalRig.Mode.SLEEP, 0.0, 30.0, 2.6],
			[&"cow", 1, false, AnimalRig.Mode.IDLE, 0.0, 70.0, 3.0], [&"cow", 1, false, AnimalRig.Mode.IDLE, 0.0, -70.0, 3.0],
			[&"cow", 2, false, AnimalRig.Mode.WALK, 0.8, 60.0, 3.4], [&"horse", 4, false, AnimalRig.Mode.IDLE, 0.0, 60.0, 5.5],
		]
	elif only != "":
		shots = shots.filter(func(sh): return String(sh[0]) == only)
		# Extra close-ups of the head and a view from the right side.
		shots.append([StringName(only), 0, false, AnimalRig.Mode.IDLE, 0.0, -60.0, 2.4])
		shots.append([StringName(only), 1, false, AnimalRig.Mode.IDLE, 0.0, -120.0, 4.4])
		shots.append([StringName(only), 2, false, AnimalRig.Mode.IDLE, 0.0, 20.0, 1.8])
		shots.append([StringName(only), 3, false, AnimalRig.Mode.WALK, 1.0, -90.0, 4.4])
	if heads:
		# Head close-ups (negative distance = frame the head bone): side and three-quarter.
		shots = []
		for sp: StringName in [&"cow", &"horse", &"sheep", &"chicken"]:
			var d: float = {&"cow": 0.9, &"horse": 0.9, &"sheep": 0.55, &"chicken": 0.2}[sp]
			shots.append([sp, 0, false, AnimalRig.Mode.IDLE, 0.0, 90.0, -d])
			shots.append([sp, 1, false, AnimalRig.Mode.IDLE, 0.0, 135.0, -d])
	var cols := 4
	var rows := int(ceil(shots.size() / float(cols)))
	var sheet := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var s: Array = shots[i]
		for c in _holder.get_children():
			c.queue_free()
		var rig := AnimalModels.create_rig(s[0])
		_holder.add_child(rig)
		rig.set_variant(s[1], s[2])
		rig.set_age(0.0 if s[2] else 1.0)
		if s[0] == &"sheep" and s[1] == 1:
			rig.set_wool(0.3)
		rig.rotation_degrees.y = s[5]
		for f in 90:
			rig.animate(1.0 / 60.0, s[4], s[3])
		var dist: float = s[6]
		var target := Vector3(0, dist * 0.18, 0)
		if dist < 0.0:
			var hb := rig.skeleton.find_bone("head")
			target = (rig.skeleton.global_transform * rig.skeleton.get_bone_global_pose(hb)).origin
			var face := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(s[5]))
			target += face * absf(dist) * 0.2 + Vector3(0, -absf(dist) * 0.08, 0)
			dist = -dist
		elif dist < 2.5 and s[0] == &"horse":
			target = Vector3(0, 1.7, -0.9).rotated(Vector3.UP, deg_to_rad(s[5]))
		_cam.global_position = target + Vector3(0, dist * 0.35, dist)
		_cam.look_at(target, Vector3.UP)
		for f in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
	sheet.save_png(out)
	print("ANIMAL SHEET ", out)
	quit()
