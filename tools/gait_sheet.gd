extends SceneTree
## Gait frame sheet for review: one animal walking over a checker ground (0.25 m squares),
## an orthographic camera following it from the side (and/or the front), N frames through
## one gait cycle. Run (needs a window):
##   godot --path . -s res://tools/gait_sheet.gd -- --species=cow --speed=0.8 --mode=WALK \
##       --frames=8 --view=side|front|both --out=/abs/path.png
## --period=S sets the cycle (seconds) where the rig's gait clock is not what moves the legs
## (the horse's walk and gallop clips: clip length / playing speed); --warm, --age, --variant.

const CELL := Vector2i(480, 320)

var _vp: SubViewport
var _cam: Camera3D


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
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	_vp.add_child(sun)
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var c := ((x / 32) + (y / 32)) % 2 == 0
			img.set_pixel(x, y, Color(0.4, 0.44, 0.3) if c else Color(0.34, 0.38, 0.25))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = ImageTexture.create_from_image(img)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	gm.uv1_scale = Vector3(400, 400, 1)
	gm.roughness = 1.0
	ground.material_override = gm
	_vp.add_child(ground)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	_run.call_deferred()


func _run() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		var kv := s.trim_prefix("--").split("=", true, 1)
		a[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var species := StringName(a.get("species", "cow"))
	var speed := float(a.get("speed", "0.8"))
	var mode: int = AnimalRig.Mode.keys().find(String(a.get("mode", "WALK")))
	var frames := int(a.get("frames", "10"))
	var view: String = a.get("view", "side")
	var out: String = a.get("out", "/tmp/sheet.png")
	var holder := Node3D.new()
	holder.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vp.add_child(holder)
	var rig := AnimalModels.create_rig(species)
	holder.add_child(rig)
	rig.set_variant(int(a.get("variant", "0")), false)
	rig.set_age(float(a.get("age", "1")))
	var h: float = float(PhotoRig.MODELS.get(species, {}).get("height", 1.0)) * rig.scale.x
	var dt := 1.0 / 60.0
	var x := 0.0
	# Walks along +X (turned so its -Z faces +X).
	rig.rotation.y = -PI * 0.5
	var t := 0.0
	var phase_start := -1.0
	var wraps := 0.0
	var last := 0.0
	var warm := float(a.get("warm", "3"))
	while t < warm:
		rig.position.x = x
		rig.animate(dt, speed, mode)
		x += speed * dt
		t += dt
		if t > warm - 2.0:
			if phase_start < 0.0:
				phase_start = t
				last = rig._phase
			else:
				wraps += fposmod(rig._phase - last, 1.0)
				last = rig._phase
	var period := float(a.get("period", "0"))
	if period <= 0.0:
		period = (t - phase_start) / maxf(wraps, 0.001)
	var views: Array = ["side", "front"] if view == "both" else [view]
	var sheet := Image.create(CELL.x * frames, CELL.y * views.size(), false, Image.FORMAT_RGBA8)
	var step := period / frames
	print("SHEET %s period %.3f s" % [species, period])
	for f in frames:
		# Advance one step in small ticks.
		var n := maxi(1, int(round(step / dt)))
		var sdt := step / n
		for k in n:
			rig.position.x = x
			rig.animate(sdt, speed, mode)
			x += speed * sdt
		rig.position.x = x
		for vi in views.size():
			var centre := Vector3(x, h * 0.62, 0)
			if views[vi] == "side":
				_cam.size = h * 1.9
				_cam.global_position = centre + Vector3(0, 20 * sin(0.2), 20 * cos(0.2))
				_cam.look_at(centre, Vector3.UP)
			else:
				_cam.size = h * 1.75
				_cam.global_position = centre + Vector3(20 * cos(0.2), 20 * sin(0.2), 0)
				_cam.look_at(centre, Vector3.UP)
			for w in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := _vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(f * CELL.x, vi * CELL.y))
	sheet.save_png(out)
	print("SHEET saved ", out)
	quit()
