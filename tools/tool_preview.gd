extends SceneTree
## Side-by-side check of the scanned tools against the hand-built ones in item space:
## per tool, hand-built and scanned from the front (X right, Y up) and from the side
## (Z right, Y up), with the grip point (origin) marked red.
## Run (needs a window): godot --path . -s res://tools/tool_preview.gd -- --out=/abs/sheet.png
##
## With --held[=axe,pickaxe,...] it draws the first-person pose sheet instead: per item a
## row through its use stroke as the player sees it (HeldPoses + ToolAnim), one from the
## side and one from ahead (the eye marked red, the item's working point yellow), against a stand-in
## target: a trunk for the axe, a rock for the pickaxe, a stall wall for animal work, soil
## for the rest.

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
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--held"):
			var ids: Array[StringName] = []
			for id in a.trim_prefix("--held").trim_prefix("=").split(",", false):
				ids.append(StringName(id))
			await _held_sheet(ids if not ids.is_empty() else HELD_IDS, out)
			quit()
			return
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


# --- First-person pose sheet --------------------------------------------------------------

const HELD_IDS: Array[StringName] = [&"axe", &"pickaxe", &"hoe", &"scythe", &"pitchfork", &"watering_can",
		&"milk_pail", &"shears", &"brush", &"wheat_seed", &"fertilizer", &"hay", &"wood", &"stone", &"egg", &"pumpkin"]
## Item -> the stroke shown and the u of each column (rest, wind-up, strike, contact, follow-through).
const HELD_STROKES := {
	&"axe": [&"axe", [0.0, 0.46, 0.54, 0.58, 0.76]],
	&"pickaxe": [&"pickaxe", [0.0, 0.47, 0.55, 0.6, 0.76]],
	&"hoe": [&"hoe", [0.0, 0.48, 0.56, 0.6, 0.82]],
	&"scythe": [&"scythe", [0.0, 0.42, 0.52, 0.62, 0.72]],
	&"pitchfork": [&"fork", [0.0, 0.3, 0.45, 0.62, 0.78]],
	&"watering_can": [&"can_pour", [0.0, 0.12, 0.3, 0.6, 0.9]],
	&"milk_pail": [&"work", [0.0, 0.25, 0.5, 0.75, 1.0]],
	&"shears": [&"brush", [0.0, 0.25, 0.5, 0.75, 1.0]],
	&"brush": [&"brush", [0.0, 0.25, 0.5, 0.75, 1.0]],
	&"wheat_seed": [&"scatter", [0.0, 0.3, 0.42, 0.6, 0.8]],
	&"fertilizer": [&"sack", [0.0, 0.35, 0.5, 0.62, 0.8]],
	&"hay": [&"sack", [0.0, 0.35, 0.5, 0.62, 0.8]],
	&"egg": [&"throw", [0.0, 0.32, 0.46, 0.6, 0.8]],
}
const HELD_W := 384
const HELD_H := 216
const EYE := Vector3(0, 1.62, 0)


func _held_sheet(ids: Array[StringName], out: String) -> void:
	_vp.size = Vector2i(HELD_W, HELD_H)
	var cols := 5
	var sheet := Image.create(HELD_W * cols, HELD_H * 3 * ids.size(), false, Image.FORMAT_RGBA8)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color(0.36, 0.3, 0.22)
	soil.roughness = 1.0
	plane.material = soil
	ground.mesh = plane
	_vp.add_child(ground)
	var props := Node3D.new()
	_vp.add_child(props)
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.near = 0.05
	for row in ids.size():
		var id := ids[row]
		var stroke: Array = HELD_STROKES.get(id, [&"work", [0.0, 0.25, 0.5, 0.75, 1.0]])
		var prof: Dictionary = ToolAnim.PROFILES[stroke[0]]
		var aim := _held_target(stroke[0], props)
		var eye := Transform3D(Basis.IDENTITY, EYE).looking_at(aim, Vector3.UP)
		var mesh := ItemModels.mesh(id)
		var rest := HeldPoses.rest_pose(id, mesh)
		var grip := HeldPoses.grip_point(id, mesh)
		for col in cols:
			var u: float = (stroke[1] as Array)[col]
			var pose := ToolAnim.sample(prof, u)
			var xf := eye * HeldPoses.posed(rest, grip, pose[0], pose[1])
			for c in _holder.get_children():
				c.free()
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.transform = xf
			_holder.add_child(mi)
			var work := xf * (HeldPoses.SPOUT if id == &"watering_can" else _working_point(id, mesh))
			for side in 3:
				_holder.get_child(0).visible = true
				for d in _holder.get_children().slice(1):
					d.free()
				props.visible = side != 2
				if side > 0:
					_add_dot(eye.origin, Color(1, 0, 0), 0.04)
					_add_dot(eye.origin - eye.basis.z * 0.5, Color(1, 0.4, 0.4), 0.015)
					_add_dot(work, Color(1, 0.9, 0), 0.02)
					if id == &"watering_can":
						# The first stretch of the stream out of the spout.
						for k in range(1, 6):
							_add_dot(work + xf.basis.orthonormalized() * HeldPoses.SPOUT_DIR * 0.04 * k, Color(0.3, 0.6, 1), 0.008)
					_cam.fov = 50.0
				if side == 1:
					# From the right, level with the swing.
					var mid := Vector3(0, 1.15, (eye.origin.z + aim.z) * 0.5)
					_cam.position = mid + Vector3(2.3, 0.15, 0.0)
					_cam.look_at(mid, Vector3.UP)
				elif side == 2:
					# From ahead and to the left, above: the face of the tool's head.
					var at := eye * Vector3(0.15, -0.25, -0.6)
					_cam.position = eye * Vector3(-0.7, 0.5, -1.9)
					_cam.look_at(at, Vector3.UP)
				else:
					_cam.fov = 75.0
					_cam.transform = eye
				for f in 3:
					await process_frame
				await RenderingServer.frame_post_draw
				var img := _vp.get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(img, Rect2i(0, 0, HELD_W, HELD_H), Vector2i(col * HELD_W, (row * 3 + side) * HELD_H))
		print("held ", id)
	sheet.save_png(ProjectSettings.globalize_path(out) if out.begins_with("user://") else out)
	print("sheet ", out)


## Builds the stand-in target of a stroke; returns the point the eye looks at.
func _held_target(profile: StringName, props: Node3D) -> Vector3:
	for c in props.get_children():
		c.free()
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.roughness = 1.0
	props.add_child(mi)
	match profile:
		&"axe":
			var trunk := CylinderMesh.new()
			trunk.top_radius = 0.26
			trunk.bottom_radius = 0.3
			trunk.height = 5.0
			mat.albedo_color = Color(0.42, 0.34, 0.26)
			trunk.material = mat
			mi.mesh = trunk
			mi.position = Vector3(0, 2.5, -1.4 - 0.28)
			return Vector3(0, 1.2, -1.4)
		&"pickaxe":
			var rock := SphereMesh.new()
			rock.radius = 0.55
			rock.height = 0.8
			mat.albedo_color = Color(0.55, 0.55, 0.52)
			rock.material = mat
			mi.mesh = rock
			mi.position = Vector3(0, 0.15, -1.9)
			return Vector3(0, 0.5, -1.55)
		&"brush", &"work":
			var wall := BoxMesh.new()
			wall.size = Vector3(1.8, 1.0, 0.6)
			mat.albedo_color = Color(0.5, 0.36, 0.26)
			wall.material = mat
			mi.mesh = wall
			mi.position = Vector3(0, 0.9, -1.3)
			return Vector3(0, 1.0, -1.0)
		&"throw":
			return Vector3(0, 1.4, -6.0)
		_:
			return Vector3(0, 0.15, -2.4)


## Where a held item does its work, in its model space (the head end of a long tool).
func _working_point(id: StringName, mesh: Mesh) -> Vector3:
	var b := mesh.get_aabb()
	if id in [&"axe", &"pickaxe", &"hoe", &"scythe", &"pitchfork"]:
		return Vector3(0, b.end.y, 0)
	return Vector3(b.get_center().x, b.end.y, b.get_center().z)


func _add_dot(at: Vector3, color: Color, r: float) -> void:
	var dot := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = r
	sphere.height = r * 2.0
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	sphere.material = m
	dot.mesh = sphere
	dot.position = at
	_holder.add_child(dot)
