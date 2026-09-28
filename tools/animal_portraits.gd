extends SceneTree
## Renders adult and young portraits of every animal species with a transparent
## background to art/icons/animals (used by the livestock screens).
## Run (needs a window): godot --path . -s res://tools/animal_portraits.gd

const OUT := "res://art/icons/animals/"
const SIZE := Vector2i(512, 384)

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
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	for l: Array in [[Vector3(-38, -40, 0), 2.0], [Vector3(-20, 150, 0), 0.9]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = l[0]
		light.light_energy = l[1]
		_vp.add_child(light)
	_cam = Camera3D.new()
	_cam.fov = 26.0
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	_run.call_deferred()


func _run() -> void:
	for species: StringName in AnimalTable.ORDER:
		for adult: bool in [true, false]:
			for c in _holder.get_children():
				c.queue_free()
			var rig := AnimalModels.create_rig(species)
			_holder.add_child(rig)
			rig.set_variant(0 if species != &"horse" else 0, not adult)
			rig.set_age(1.0 if adult else 0.0)
			rig.rotation_degrees.y = 125.0
			for f in 30:
				rig.animate(1.0 / 60.0, 0.0, AnimalRig.Mode.IDLE)
			await process_frame
			var pts := _points(rig)
			var center := Vector3.ZERO
			for p in pts:
				center += p
			center /= pts.size()
			var dir := Vector3(0, 0.25, 1).normalized()
			_cam.global_position = center + dir * _fit_distance(pts, center, dir)
			_cam.look_at(center, Vector3.UP)
			for f in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := _vp.get_texture().get_image()
			var path := ProjectSettings.globalize_path("%s%s%s.png" % [OUT, species, "" if adult else "_baby"])
			img.save_png(path)
			print("portrait ", path)
	quit()


## Distance along `dir` from `center` at which all points (each with a margin
## for the body around it) fit the view.
func _fit_distance(pts: PackedVector3Array, center: Vector3, dir: Vector3) -> float:
	var right := Vector3.UP.cross(dir).normalized()
	var up := dir.cross(right).normalized()
	var tan_v := tan(deg_to_rad(_cam.fov * 0.5))
	var tan_h := tan_v * float(SIZE.x) / float(SIZE.y)
	var box := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		box = box.expand(p)
	var margin := box.size.length() * 0.12
	var d := 0.0
	for p in pts:
		var q := p - center
		var z := q.dot(dir) + margin
		d = maxf(d, z + (absf(q.dot(right)) + margin) / tan_h)
		d = maxf(d, z + (absf(q.dot(up)) + margin) / tan_v)
	return d


## Points to frame: the anatomical bones of photo rigs, mesh box corners otherwise.
func _points(rig: Node3D) -> PackedVector3Array:
	var pts := PackedVector3Array()
	if rig is PhotoRig:
		var sk := (rig as PhotoRig).skeleton
		for idx: int in (rig as PhotoRig)._b.values():
			pts.append(sk.global_transform * sk.get_bone_global_pose(idx).origin)
			for child in sk.get_bone_children(idx):
				pts.append(sk.global_transform * sk.get_bone_global_pose(child).origin)
	else:
		var box := _bounds(rig)
		for i in 8:
			pts.append(box.get_endpoint(i))
	return pts


func _bounds(n: Node) -> AABB:
	if n is PhotoRig:
		# Skinned vertices sit in bind space, so frame the posed skeleton instead,
		# grown a little for the body around the bones.
		# Only the anatomical (mapped) bones and their tips: rigs also carry IK
		# targets and helpers far outside the body.
		var rig := n as PhotoRig
		var sk := rig.skeleton
		var ids: Array[int] = []
		for idx: int in rig._b.values():
			ids.append(idx)
			ids.append_array(sk.get_bone_children(idx))
		var bones := AABB(sk.global_transform * sk.get_bone_global_pose(ids[0]).origin, Vector3.ZERO)
		for i in ids:
			bones = bones.expand(sk.global_transform * sk.get_bone_global_pose(i).origin)
		return bones.grow(bones.size.length() * 0.1)
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
