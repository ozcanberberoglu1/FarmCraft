extends SceneTree
## Side-by-side check of the scanned tools against the hand-built ones in item space:
## per tool, hand-built and scanned from the front (X right, Y up) and from the side
## (Z right, Y up), with the grip point (origin) marked red.
## Run (needs a window): godot --path . -s res://tools/tool_preview.gd -- --out=/abs/sheet.png

const CELL := 280
const IDS: Array[StringName] = [&"axe", &"pickaxe", &"hoe", &"scythe", &"shears", &"watering_can", &"milk_pail"]

var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D


func _initialize() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(CELL, CELL)
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.78, 0.8, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.86)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 1.6
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	_run.call_deferred()


func _run() -> void:
	var out := "user://tool_preview.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var sheet := Image.create(CELL * 4, CELL * IDS.size(), false, Image.FORMAT_RGBA8)
	for row in IDS.size():
		var id := IDS[row]
		var meshes := [ItemModels.procedural(id), ToolModels.mesh(id) if ToolModels.has(id) else null]
		var box := (meshes[0] as Mesh).get_aabb()
		if meshes[1]:
			box = box.merge((meshes[1] as Mesh).get_aabb())
		for col in 4:
			for c in _holder.get_children():
				c.free()
			var m: Mesh = meshes[col % 2]
			if m == null:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = m
			_holder.add_child(mi)
			var dot := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = box.get_longest_axis_size() * 0.02
			sphere.height = sphere.radius * 2.0
			var red := StandardMaterial3D.new()
			red.albedo_color = Color(1, 0, 0)
			red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			red.no_depth_test = true
			sphere.material = red
			dot.mesh = sphere
			_holder.add_child(dot)
			var side := col >= 2
			var c := box.get_center()
			_cam.size = maxf(box.size.y, (box.size.z if side else box.size.x)) * 1.15
			_cam.position = c + (Vector3(4, 0, 0) if side else Vector3(0, 0, 4))
			_cam.look_at(c, Vector3.UP)
			for f in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := _vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(col * CELL, row * CELL))
		print("preview ", id)
	sheet.save_png(ProjectSettings.globalize_path(out) if out.begins_with("user://") else out)
	print("sheet ", out)
	quit()
