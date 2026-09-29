class_name FishingLine
extends MeshInstance3D
## The fishing line from the rod tip to the float (or the hooked fish): a thin
## monofilament hanging in a curve that tightens with tension and lies on the water where
## it reaches it. Drawn every frame as a ribbon turned to the camera, about a pixel wide
## at any distance, lit so it glints in the sun and fades into the dusk.

const SEGMENTS := 28
## Width as a share of the distance to the camera (about 1.3 px at 1080p).
const WIDTH_PER_M := 0.0012
const MIN_WIDTH := 0.0007

var _im := ImmediateMesh.new()


func _ready() -> void:
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	layers = 2
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.82, 0.85, 0.8, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.3
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material_override = m
	global_transform = Transform3D.IDENTITY


## Draws the line from `a` to `b` sagging by `sag` metres at its middle; `water_y`: it
## lies on the water there (NAN: no water under it).
func draw_line(a: Vector3, b: Vector3, sag: float, water_y := NAN) -> void:
	_im.clear_surfaces()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or a.distance_to(b) < 0.01:
		return
	var eye := cam.global_position
	var pts := PackedVector3Array()
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		var p := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		if not is_nan(water_y):
			p.y = maxf(p.y, water_y + 0.003)
		pts.append(p)
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pts.size():
		var p := pts[i]
		var along := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var to_eye := eye - p
		var dist := to_eye.length()
		var side := along.cross(to_eye / maxf(dist, 0.001)).normalized()
		var w := maxf(dist * WIDTH_PER_M, MIN_WIDTH) * 0.5
		_im.surface_set_normal(to_eye / maxf(dist, 0.001))
		_im.surface_add_vertex(p - side * w)
		_im.surface_set_normal(to_eye / maxf(dist, 0.001))
		_im.surface_add_vertex(p + side * w)
	_im.surface_end()


func clear() -> void:
	_im.clear_surfaces()
