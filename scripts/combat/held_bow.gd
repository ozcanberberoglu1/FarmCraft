class_name HeldBow
extends Node3D
## The bow in the farmer's hand, strung (a child of the held item's model, in the bow's
## model space): the stave bends as the string is drawn (CraftModels.bow_body), the
## string runs from both tips to the nock point and, while drawing, an arrow sits on the
## string and on the arrow shelf above the grip, sliding back with the draw (Combat).

## How far the nock point comes back at full draw, from the braced string (bow space):
## the broadhead then sits just past the stave's back, as at a real full draw.
const DRAW_PULL := 0.51
## The nocking point's height on the string, level with the shelf above the grip, and the
## arrow's side of the stave (the archer's left: -X).
const NOCK_Y := 0.085
const SHELF := Vector3(-0.024, 0.085, 0.0)
const STRING_R := 0.0014
const STRING_COLOR := Color(0.82, 0.8, 0.72)

static var _string_mesh: CylinderMesh

var _upper: MeshInstance3D
var _lower: MeshInstance3D
var _arrow: MeshInstance3D
var _body: MeshInstance3D
var _draw := -1.0
var _nocked := false


func _ready() -> void:
	_body = get_parent() as MeshInstance3D
	if _string_mesh == null:
		_string_mesh = CylinderMesh.new()
		_string_mesh.top_radius = STRING_R
		_string_mesh.bottom_radius = STRING_R
		_string_mesh.height = 1.0
		_string_mesh.radial_segments = 5
		_string_mesh.rings = 1
		_string_mesh.cap_top = false
		_string_mesh.cap_bottom = false
		var m := StandardMaterial3D.new()
		m.albedo_color = STRING_COLOR
		m.roughness = 0.8
		_string_mesh.material = m
	_upper = _part(_string_mesh)
	_lower = _part(_string_mesh)
	_arrow = _part(ArrowModels.single())
	_arrow.visible = false
	set_draw(0.0, false)


func _part(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.layers = 2
	add_child(mi)
	return mi


## The string drawn `amount` (0 braced .. 1 full draw), an arrow on it when `nocked`.
func set_draw(amount: float, nocked: bool) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if is_equal_approx(amount, _draw) and nocked == _nocked:
		return
	_draw = amount
	_nocked = nocked
	# The limbs bend ahead of the string a little (they take the weight first).
	var flex := ease(amount, 0.8)
	if _body:
		_body.mesh = CraftModels.bow_body(flex)
	var tip := CraftModels.bow_nock(flex)
	var nock := Vector3(0.0, NOCK_Y, tip.z + DRAW_PULL * amount)
	_span(_upper, tip, nock)
	_span(_lower, Vector3(tip.x, -tip.y, tip.z), nock)
	_arrow.visible = nocked
	if nocked:
		# From the nock over the shelf, the point running on past the stave.
		var dir := (SHELF - nock).normalized()
		_arrow.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), nock)


## A string segment from `a` to `b`.
static func _span(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := maxf(d.length(), 0.0001)
	var y := d / length
	var x := y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y * length, z), (a + b) * 0.5)
