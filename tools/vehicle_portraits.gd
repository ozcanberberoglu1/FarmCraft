extends SceneTree
## Renders a 3/4 studio portrait of every vehicle with a transparent background to
## art/icons/vehicles/<id>.png (dealer screen).
## Run (needs a window): godot --path . -s res://tools/vehicle_portraits.gd

const OUT := "res://art/icons/vehicles/"
const SIZE := Vector2i(1200, 760)

var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_8X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.86)
	env.ambient_light_energy = 0.55
	# Chrome and clear coat need something to reflect: a studio sky, not drawn.
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	for l: Array in [[Vector3(-35, -30, 0), 2.2, true], [Vector3(-15, 150, 0), 0.8, false], [Vector3(-60, 95, 0), 0.5, false]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = l[0]
		light.light_energy = l[1]
		light.shadow_enabled = l[2]
		_vp.add_child(light)
	_cam = Camera3D.new()
	_cam.fov = 24.0
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	_run.call_deferred()


func _run() -> void:
	for id: StringName in VehicleTable.VEHICLES:
		var info: Dictionary = VehicleTable.get_info(id)
		for c in _holder.get_children():
			c.queue_free()
		var model := (load(info["model"]) as PackedScene).instantiate() as Node3D
		_holder.add_child(model)
		if info.has("detail"):
			VehicleLook.add_detail(model, info["detail"])
		if info.has("strip_parts"):
			ModelStrip.strip_parts(model, info["strip_parts"][0], info["strip_parts"][1])
		model.rotation.y = deg_to_rad(-38.0)
		# Dressed as in game (VehicleLook): paint, trim, wheels, cab and plates; dust and
		# rust are placed in the model's frame.
		var framed: Array[MeshInstance3D] = []
		var mats := {}
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if "Numberplate" in String(mi.name) and info.has("plate"):
				VehicleLook.add_plate(mi, info["plate"])
			for si in mi.mesh.get_surface_count():
				var m := mi.get_active_material(si) as StandardMaterial3D
				if m == null:
					continue
				var look := ""
				if "Bodymat" in m.resource_name:
					look = "paint"
				elif "UCB_BOTTOM" in m.resource_name:
					look = "trim"
				elif "Tire" in m.resource_name:
					# One per wheel part (tyre, rim, nuts, brakes).
					look = m.resource_name
				elif "Interiors" in m.resource_name:
					look = "interior"
				if look == "":
					continue
				if not mats.has(look):
					match look:
						"paint":
							mats[look] = VehicleLook.paint(m, info)
						"trim":
							mats[look] = VehicleLook.trim(m, info)
						"interior":
							mats[look] = VehicleLook.interior(m)
						_:
							mats[look] = VehicleLook.wheel(m, info)
				mi.set_surface_override_material(si, mats[look])
				if look in ["paint", "trim"] and mi not in framed:
					framed.append(mi)
		await process_frame
		for mi in framed:
			VehicleLook.fit_frame(mi, model)
		var box := AABB()
		var first := true
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var b := mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		var center := box.get_center()
		var dir := Vector3(0, 0.3, 1).normalized()
		# Fit all box corners into the view with a small margin.
		var right := Vector3.UP.cross(dir).normalized()
		var up := dir.cross(right).normalized()
		var tan_v := tan(deg_to_rad(_cam.fov * 0.5))
		var tan_h := tan_v * float(SIZE.x) / float(SIZE.y)
		var dist := 0.0
		for i in 8:
			var q := box.get_endpoint(i) - center
			dist = maxf(dist, q.dot(dir) + absf(q.dot(right)) / tan_h * 1.08)
			dist = maxf(dist, q.dot(dir) + absf(q.dot(up)) / tan_v * 1.08)
		_cam.global_position = center + dir * dist
		_cam.look_at(center, Vector3.UP)
		for f in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		var path := ProjectSettings.globalize_path("%s%s.png" % [OUT, id])
		img.save_png(path)
		print("portrait ", path)
	quit()
