@tool
class_name BuildingKit
extends RefCounted
## Pieces for the town's buildings, written into a MeshBuilder: walls with window and
## door openings (framed, glazed), slabs, flat roofs with parapets, awnings, lamps
## and signs. Collision boxes are collected as [center, size, yaw] for StaticBodies.
## The ruin pieces (board walls, cobwebs, broken glass) age Grandpa's old buildings.

const FRAME := Color(0.16, 0.17, 0.18)
## Height of one board in the weathered_brown_planks photo at uv_scale 0.45 (13 boards
## a repeat) and where its first seam lies: a board cut to it shows one plank exactly.
const BOARD_H := 0.1709
const BOARD_SEAM := 0.0868


## Wall from `a` to `b` (world XZ) standing on `y0`. Openings along the wall:
## {at: distance from a to the opening centre, w, bottom, top, glass: bool,
##  mullions: spacing (0 = none)}. Glass openings get a frame and panes; others stay open
## (doorways).
static func wall(mb: MeshBuilder, cols: Array, a: Vector2, b: Vector2, y0: float, height: float, t: float,
		key: StringName, color: Color, openings: Array = []) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var yaw := atan2(-dir.y, dir.x)
	var basis := Basis(Vector3.UP, yaw)
	for seg in _segments(length, height, openings):
		var mid := (seg.x + seg.y) * 0.5
		var p := a + dir * mid
		var center := Vector3(p.x, y0 + (seg.z + seg.w) * 0.5, p.y)
		var size := Vector3(seg.y - seg.x, seg.w - seg.z, t)
		mb.box(key, Transform3D(basis, center), size, color)
		cols.append([center, size, yaw])
	for o: Dictionary in openings:
		var p := a + dir * float(o["at"])
		var w: float = o["w"]
		var bottom: float = o["bottom"]
		var top: float = o["top"]
		var fw := 0.07
		var depth := t + 0.04
		var base := Vector3(p.x, y0, p.y)
		var frame_col: Color = o.get("frame", FRAME)
		# Frame around the opening.
		for piece: Array in [[Vector3(-w * 0.5 + fw * 0.5, (bottom + top) * 0.5, 0), Vector3(fw, top - bottom, depth)],
				[Vector3(w * 0.5 - fw * 0.5, (bottom + top) * 0.5, 0), Vector3(fw, top - bottom, depth)],
				[Vector3(0, top - fw * 0.5, 0), Vector3(w, fw, depth)]]:
			mb.box(&"metal", Transform3D(basis, base + basis * piece[0]), piece[1], frame_col)
		if bottom > 0.05:
			mb.box(&"metal", Transform3D(basis, base + basis * Vector3(0, bottom + fw * 0.5, 0)), Vector3(w, fw, depth + 0.06), frame_col)
		if o.get("glass", true):
			mb.box(&"shop_glass", Transform3D(basis, base + basis * Vector3(0, (bottom + top) * 0.5, 0)),
					Vector3(w - fw * 2.0, top - bottom - fw * 2.0, 0.02), Color.WHITE)
			var spacing: float = o.get("mullions", 0.0)
			if spacing > 0.0:
				var count := int(floor(w / spacing))
				for k in range(1, count):
					var x := -w * 0.5 + w * k / count
					mb.box(&"metal", Transform3D(basis, base + basis * Vector3(x, (bottom + top) * 0.5, 0)),
							Vector3(0.05, top - bottom, depth), frame_col)
			# Glass stops people and cars.
			cols.append([base + basis * Vector3(0, (bottom + top) * 0.5, 0), Vector3(w, top - bottom, t), yaw])


static func _segments(length: float, height: float, openings: Array) -> Array[Vector4]:
	var out: Array[Vector4] = []
	var sorted := openings.duplicate()
	sorted.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["at"] < q["at"])
	var cursor := 0.0
	for o: Dictionary in sorted:
		var left := float(o["at"]) - float(o["w"]) * 0.5
		var right := float(o["at"]) + float(o["w"]) * 0.5
		if left - cursor > 0.01:
			out.append(Vector4(cursor, left, 0.0, height))
		if float(o["bottom"]) > 0.01:
			out.append(Vector4(left, right, 0.0, o["bottom"]))
		if height - float(o["top"]) > 0.01:
			out.append(Vector4(left, right, o["top"], height))
		cursor = right
	if length - cursor > 0.01:
		out.append(Vector4(cursor, length, 0.0, height))
	return out


## Solid ramp (a wedge) up to a doorway whose floor stands above the ground: `edge` is
## the middle of its top edge on the door line (world XZ), `out` the unit direction
## away from the building. It climbs from `foot_y`, `run` metres out, to `top_y`.
static func ramp(mb: MeshBuilder, cols: Array, edge: Vector2, out: Vector2, width: float, run: float,
		top_y: float, foot_y: float, key: StringName, color: Color) -> void:
	var basis := Basis(Vector3.UP, atan2(out.x, out.y))
	var o := Vector3(edge.x, 0.0, edge.y)
	var hw := width * 0.5
	var lo := foot_y - 0.12
	var nose := foot_y + 0.02
	# Corners in box() order; local +Z points away from the building.
	var p: Array[Vector3] = []
	for c: Vector3 in [Vector3(-hw, lo, 0.0), Vector3(hw, lo, 0.0), Vector3(hw, top_y, 0.0), Vector3(-hw, top_y, 0.0),
			Vector3(-hw, lo, run), Vector3(hw, lo, run), Vector3(hw, nose, run), Vector3(-hw, nose, run)]:
		p.append(o + basis * c)
	mb.hexa(key, p, color)
	# A tilted box whose top face is the ramp's surface.
	var rise := top_y - nose
	var tilt := basis * Basis(Vector3.RIGHT, atan2(rise, run))
	var mid := o + basis * Vector3(0.0, (top_y + nose) * 0.5, run * 0.5)
	cols.append([mid - tilt.y * 0.05, Vector3(width, 0.1, Vector2(run, rise).length()), tilt])


## Horizontal slab covering `rect` (XZ) with its top at `top`.
static func slab(mb: MeshBuilder, cols: Array, rect: Rect2, top: float, thickness: float, key: StringName,
		color: Color, collide := true) -> void:
	var c := rect.get_center()
	var center := Vector3(c.x, top - thickness * 0.5, c.y)
	var size := Vector3(rect.size.x, thickness, rect.size.y)
	mb.box(key, Transform3D(Basis(), center), size, color)
	if collide:
		cols.append([center, size, 0.0])


## Rectangular building shell: floor, four walls (openings per side: "n", "s", "e", "w"),
## ceiling and a flat roof with a parapet. Walls sit inside `rect`.
static func shell(mb: MeshBuilder, cols: Array, rect: Rect2, y0: float, height: float, t: float,
		wall_key: StringName, wall_color: Color, openings: Dictionary, floor_key := &"tile_floor",
		ceiling := true) -> void:
	var x0 := rect.position.x
	var z0 := rect.position.y
	var x1 := rect.end.x
	var z1 := rect.end.y
	var h := t * 0.5
	slab(mb, cols, rect.grow(-0.02), y0 + 0.02, 0.4, floor_key, Color(0.5, 0.5, 0.5))
	wall(mb, cols, Vector2(x0, z1 - h), Vector2(x1, z1 - h), y0, height, t, wall_key, wall_color, openings.get("s", []))
	wall(mb, cols, Vector2(x1, z0 + h), Vector2(x0, z0 + h), y0, height, t, wall_key, wall_color, openings.get("n", []))
	wall(mb, cols, Vector2(x1 - h, z1 - t), Vector2(x1 - h, z0 + t), y0, height, t, wall_key, wall_color, openings.get("e", []))
	wall(mb, cols, Vector2(x0 + h, z0 + t), Vector2(x0 + h, z1 - t), y0, height, t, wall_key, wall_color, openings.get("w", []))
	if ceiling:
		slab(mb, cols, rect.grow(-t), y0 + height - 0.02, 0.12, &"plaster_in", Color(0.62, 0.62, 0.6), false)
	# Roof slab, parapet and a darker cap.
	slab(mb, cols, rect.grow(0.08), y0 + height + 0.3, 0.3, &"concrete", Color(0.38, 0.38, 0.38))
	var ph := 0.7
	for e: Array in [[Vector2(x0 - 0.08, z1 + 0.08), Vector2(x1 + 0.08, z1 + 0.08)], [Vector2(x1 + 0.08, z0 - 0.08), Vector2(x0 - 0.08, z0 - 0.08)],
			[Vector2(x1 + 0.08, z1 + 0.08), Vector2(x1 + 0.08, z0 - 0.08)], [Vector2(x0 - 0.08, z0 - 0.08), Vector2(x0 - 0.08, z1 + 0.08)]]:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var dir := (b - a).normalized()
		var mid := (a + b) * 0.5 - Vector2(-dir.y, dir.x) * 0.12
		var yaw := atan2(-dir.y, dir.x)
		mb.box(wall_key, Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, y0 + height + ph * 0.5 + 0.3, mid.y)),
				Vector3(a.distance_to(b), ph, 0.24), wall_color)
		mb.box(&"metal", Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, y0 + height + ph + 0.33, mid.y)),
				Vector3(a.distance_to(b) + 0.04, 0.06, 0.32), Color(0.3, 0.31, 0.32))


## Sloped metal awning over a door or window on a wall facing `normal`.
static func awning(mb: MeshBuilder, center: Vector3, width: float, depth: float, normal: Vector2, color: Color) -> void:
	var yaw := atan2(normal.x, normal.y)
	var basis := Basis(Vector3.UP, yaw)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(12.0))
	mb.box(&"metal", Transform3D(basis * tilt, center + basis * Vector3(0, 0, depth * 0.5)), Vector3(width, 0.05, depth), color)
	for sx: float in [-1.0, 1.0]:
		mb.box(&"metal", Transform3D(basis * Basis(Vector3.RIGHT, deg_to_rad(-35.0)), center + basis * Vector3(sx * width * 0.46, -0.3, depth * 0.45)),
				Vector3(0.04, 0.04, depth * 1.1), FRAME)


## Street lamp: returns the light so the caller can switch it at night. The lamp
## head uses the `lamp_glow` surface so its glow can be switched too.
static func street_lamp(parent: Node3D, mb: MeshBuilder, cols: Array, base: Vector3, facing: Vector2) -> Light3D:
	var dark := Color(0.13, 0.14, 0.15)
	mb.cylinder(&"metal", Transform3D(Basis(), base), 0.09, 0.07, 5.2, 10, dark)
	mb.cylinder(&"metal", Transform3D(Basis(), base), 0.16, 0.14, 0.5, 10, dark)
	var arm_end := base + Vector3(facing.x * 1.2, 5.25, facing.y * 1.2)
	mb.cylinder_between(&"metal", base + Vector3(0, 5.05, 0), arm_end, 0.05, 0.045, 8, dark)
	var head := arm_end + Vector3(0, -0.06, 0)
	var yaw := atan2(facing.x, facing.y)
	mb.box(&"metal", Transform3D(Basis(Vector3.UP, yaw), head), Vector3(0.34, 0.12, 0.6), dark)
	mb.box(&"lamp_glow", Transform3D(Basis(Vector3.UP, yaw), head + Vector3(0, -0.07, 0)), Vector3(0.26, 0.02, 0.48), Color(1.0, 0.9, 0.7))
	cols.append([base + Vector3(0, 2.6, 0), Vector3(0.2, 5.2, 0.2), 0.0])
	var light := SpotLight3D.new()
	light.position = head + Vector3(0, -0.12, 0)
	light.basis = Basis.looking_at(Vector3(facing.x * 0.25, -1.0, facing.y * 0.25), Vector3.FORWARD if absf(facing.y) < 0.9 else Vector3.RIGHT)
	light.light_color = Color(1.0, 0.8, 0.55)
	light.light_energy = 0.0
	light.spot_range = 15.0
	light.spot_angle = 62.0
	light.spot_attenuation = 0.9
	light.shadow_enabled = false
	light.visible = false
	parent.add_child(light)
	return light


static var _lamp_mat: ShaderMaterial


## Shared emissive material for lamp heads, dimmed in the daytime.
static func lamp_material() -> ShaderMaterial:
	if _lamp_mat == null:
		_lamp_mat = ShaderMaterial.new()
		_lamp_mat.shader = load("res://shaders/vcolor.gdshader")
		_lamp_mat.set_shader_parameter("emission_strength", 0.0)
		_lamp_mat.set_shader_parameter("snow_accumulates", 0.0)
	return _lamp_mat


## Text on a board; `lit` signs glow at night (unshaded text).
static func sign(parent: Node3D, text: String, pos: Vector3, yaw: float, font_size: int, color: Color,
		outline := Color(0, 0, 0, 0), lit := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UiTheme.display(700, 3)
	l.font_size = font_size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 0 if outline.a <= 0.0 else 8
	l.outline_modulate = outline
	l.shaded = not lit
	l.double_sided = false
	l.position = pos
	l.rotation.y = yaw
	parent.add_child(l)
	return l


## Collision boxes into one StaticBody (layer 1). Entries are [center, size, yaw], or
## [center, size, basis] for a tilted box (ramps).
static func collider(parent: Node3D, cols: Array, layer := 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	for c: Array in cols:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = c[1]
		cs.shape = box
		cs.position = c[0]
		if c.size() > 2 and c[2] is Basis:
			cs.basis = c[2]
		else:
			cs.rotation.y = float(c[2]) if c.size() > 2 else 0.0
		body.add_child(cs)
	parent.add_child(body)
	return body


## A building's small trim (glazing bars, rafter tails, brackets, balusters, battens):
## no shadows (it is thinner than a shadow texel), kept off global illumination and
## visual layer 1 (lamps' shadows, the rain map), and faded out past 70 m, where it is
## about a pixel wide.
static func detail_instance(mesh: ArrayMesh, node_name := "Detail") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.layers = 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.visibility_range_end = 70.0
	mi.visibility_range_end_margin = 10.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return mi


## Copies every surface of `mesh` (keeping its materials by surface name) into `mb`.
static func append_mesh(mb: MeshBuilder, mesh: ArrayMesh, xf: Transform3D) -> void:
	var nb := xf.basis.inverse().transposed()
	for si in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(si)
		var key := StringName(mesh.surface_get_name(si))
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		# Stored order is Godot's front-face order; tri_n expects counter-clockwise input.
		for i in range(0, verts.size(), 3):
			mb.tri_n(key, xf * verts[i], xf * verts[i + 2], xf * verts[i + 1],
					(nb * norms[i]).normalized(), (nb * norms[i + 2]).normalized(), (nb * norms[i + 1]).normalized(),
					cols[i].linear_to_srgb(), cols[i + 2].linear_to_srgb(), cols[i + 1].linear_to_srgb(), uvs[i], uvs[i + 2], uvs[i + 1])


# --- Pitched roofs, trims and rainwater -------------------------------------------------

## Depth of one tile row in the roof_tiles_14 photo at the "roof" material's uv_scale
## (13 rows a 2.5 m repeat) and where the first gap between rows lies: a course cut to
## them shows one row of tiles exactly.
const ROOF_ROW := 2.5 / 13.0
const ROOF_SEAM := 0.0751
## Galvanised rainwater goods (the "zinc" material: weathered to a dull grey).
const GALV := Color(0.5, 0.52, 0.53)


## Frame of one roof slope (for roof_courses() and roof_trim()): origin at `ridge` on
## the roof deck, X along the ridge, Y out of the roof, Z down the slope, which falls
## toward +Z (`side` 1) or -Z (`side` -1) at `theta`. Always right-handed, so X runs
## the other way on the back slope.
static func slope_frame(ridge: Vector3, theta: float, side: float) -> Transform3D:
	var n := Vector3(0.0, cos(theta), side * sin(theta))
	var s := Vector3(0.0, -sin(theta), side * cos(theta))
	return Transform3D(Basis(n.cross(s), n, s), ridge)


## Tiles (or shingles, sheets) laid in courses down one slope of `frame` (see
## slope_frame()), `length` along the ridge (centred), from `s_top` down to `s_eave`.
## Every course is one photo row deep and cut from another row and offset of the
## photo, so the roof never repeats; its lower edge rests on the course below, so a
## shadow line runs under every course and the verges show a stepped edge.
static func roof_courses(mb: MeshBuilder, key: StringName, frame: Transform3D, length: float, s_top: float,
		s_eave: float, color: Color, rng: RandomNumberGenerator, row := ROOF_ROW, seam := ROOF_SEAM,
		thick := 0.02, lift := 0.028) -> void:
	var hx := length * 0.5
	var s_low := s_eave
	while s_low > s_top + 0.02:
		var s_up := maxf(s_low - row - 0.05, s_top)
		var depth := s_low - s_up
		var v_low := seam + rng.randi_range(0, 12) * row
		var u0 := rng.randf() * 2.5
		var p: Array[Vector3] = []
		for c: Vector3 in [Vector3(-hx, 0, s_up), Vector3(hx, 0, s_up), Vector3(hx, thick, s_up), Vector3(-hx, thick, s_up),
				Vector3(-hx, lift, s_low), Vector3(hx, lift, s_low), Vector3(hx, lift + thick, s_low), Vector3(-hx, lift + thick, s_low)]:
			p.append(frame * c)
		var v := rng.randf_range(0.9, 1.05)
		var top: Array[Vector2] = [Vector2(u0, v_low), Vector2(u0 + length, v_low), Vector2(u0 + length, v_low - depth),
			Vector2(u0, v_low - depth)]
		panel(mb, key, p, Color(color.r * v, color.g * v, color.b * v), top)
		s_low -= row


## The timber a pitched roof slope stands on and is finished with, for `frame` (see
## slope_frame()) `length` along the ridge: a board deck (its underside is the ceiling
## seen from inside and under the eaves), rafter tails under the overhang from the
## wall line `s_wall` out, a plumb fascia board at the eave `s_eave` and barge boards
## up both verges (no deck when `deck` is 0: tin sheets on purlins). The covering
## (roof_courses()) should run 0.06 past `s_eave` and `length` + 0.06, so it overhangs
## the boards. Returns the fascia's outer top edge (the middle of it), where a gutter
## hangs. `trim_key` and `deck_key` are rough_wood keys (grain along V); the rafter
## tails go into `detail` when it is given (a mesh drawn without shadows).
static func roof_trim(mb: MeshBuilder, frame: Transform3D, length: float, s_top: float, s_eave: float, s_wall: float,
		trim_key: StringName, trim_color: Color, deck_key := &"wood_in", deck_color := Color(0.46, 0.42, 0.38),
		deck := 0.12, fascia_h := -1.0, detail: MeshBuilder = null) -> Vector3:
	var b := frame.basis
	var hx := length * 0.5
	if deck > 0.0:
		mb.box(deck_key, Transform3D(b, frame * Vector3(0, -deck * 0.5, (s_top + s_eave) * 0.5)),
				Vector3(length, deck, s_eave - s_top), deck_color, true)
	# Rafter tails every 0.6 m under the overhang, out of the wall's outer face.
	var n := maxi(2, roundi(length / 0.6))
	var r0 := s_wall + 0.005
	var r1 := s_eave - 0.02
	var tails := detail if detail else mb
	if r1 - r0 > 0.05:
		for k in n + 1:
			var x := -hx + 0.05 + (length - 0.1) * k / n
			beam(tails, deck_key, frame * Vector3(x, -deck - 0.06, r0), frame * Vector3(x, -deck - 0.06, r1), Vector2(0.12, 0.06),
					Color(deck_color.r * 0.9, deck_color.g * 0.9, deck_color.b * 0.9), true, 0.0, Vector2(k * 0.37, k * 0.61))
	# Fascia: plumb, its top flush with the deck.
	var out := Vector3(b.z.x, 0.0, b.z.z).normalized()
	var eave := frame * Vector3(0, 0, s_eave)
	var fb := Basis(Vector3.UP.cross(out), Vector3.UP, out)
	var fh := deck + 0.1 if fascia_h <= 0.0 else fascia_h
	mb.box(trim_key, Transform3D(fb, eave + Vector3(0, -fh * 0.5, 0) + out * 0.016), Vector3(length + 0.02, fh, 0.032), trim_color, true)
	# Barge boards up the verges, their tops flush with the deck under the tiles' edge.
	for sx: float in [-1.0, 1.0]:
		var x := sx * (hx - 0.016)
		var lo := frame * Vector3(x, -fh * 0.5 + 0.005, s_eave + 0.03)
		var hi := frame * Vector3(x, -fh * 0.5 + 0.005, s_top)
		beam(mb, trim_key, lo, hi, Vector2(fh, 0.032), trim_color, true, 0.0, Vector2(0.4 + sx * 0.3, 0.0))
	return eave + out * 0.032


## Half-round gutter from `a` to `b` (its rim's centre line), open to the sky, with
## end stops and a rolled bead along the rim on the `out` side (away from the wall).
static func gutter(mb: MeshBuilder, a: Vector3, b: Vector3, out: Vector3, radius := 0.065, color := GALV,
		key := &"zinc") -> void:
	if (b - a).cross(Vector3.UP).dot(out) < 0.0:
		var swap := a
		a = b
		b = swap
	var x := (b - a).normalized()
	var side := x.cross(Vector3.UP).normalized()
	var segs := 6
	var ring_a: Array[Vector3] = []
	var ring_b: Array[Vector3] = []
	for k in segs + 1:
		var ang := PI * k / segs
		var off := side * cos(ang) * radius + Vector3.DOWN * sin(ang) * radius
		ring_a.append(a + off)
		ring_b.append(b + off)
	for k in segs:
		# Inside (seen from above), then outside.
		mb.quad(key, ring_a[k], ring_b[k], ring_b[k + 1], ring_a[k + 1], color * 0.75)
		mb.quad(key, ring_a[k + 1], ring_b[k + 1], ring_b[k], ring_a[k], color)
	# Rolled bead along the outer rim and the two end stops.
	mb.cylinder_between(key, ring_a[0], ring_b[0], 0.009, 0.009, 5, color)
	for e: Array in [[a, ring_a], [b, ring_b]]:
		var c: Vector3 = e[0]
		var r: Array[Vector3] = e[1]
		for k in segs:
			mb.tri(key, c, r[k], r[k + 1], color)
			mb.tri(key, c, r[k + 1], r[k], color)


## Downpipe from the gutter outlet `top` back in to the wall at `wall_point` (on its
## face; `wall_out` points out of it), down the wall `stand_off` in front of it on
## brackets to `foot_y` (0.32 over `ground` when left out), and out through a shoe
## just over a splash stone on the ground. With `foot_y` the top of a plinth standing
## `plinth_out` proud of the wall, the pipe bends out over it there and runs on down in
## front of it.
static func downpipe(mb: MeshBuilder, top: Vector3, wall_point: Vector3, wall_out: Vector3, ground: float,
		color := GALV, stand_off := 0.07, foot_y := -INF, plinth_out := 0.0) -> void:
	var r := 0.04
	var key := &"zinc"
	var at := Vector3(wall_point.x, 0.0, wall_point.z) + wall_out * stand_off
	var bend := Vector3(at.x, top.y - 0.3, at.z)
	var foot := Vector3(at.x, foot_y if foot_y > -1000.0 else ground + 0.32, at.z)
	var low_bracket := foot.y + 0.25
	mb.cylinder_between(key, top + Vector3(0, 0.02, 0), top + Vector3(0, -0.1, 0), r, r, 8, color)
	mb.cylinder_between(key, top + Vector3(0, -0.1, 0), bend, r, r, 8, color)
	mb.cylinder_between(key, bend, foot, r, r, 8, color)
	if foot_y > -1000.0 and plinth_out > 0.0:
		# Swan neck out over the plinth, then down its face to a hand over the ground.
		var off := foot + wall_out * (plinth_out + 0.06 - stand_off) + Vector3(0, -0.18, 0)
		mb.cylinder_between(key, foot, off, r, r, 8, color)
		foot = Vector3(off.x, minf(off.y, ground + 0.3), off.z)
		if off.y - foot.y > 0.01:
			mb.cylinder_between(key, off, foot, r, r, 8, color)
	var shoe := foot + wall_out * 0.2 + Vector3(0, -0.16, 0)
	mb.cylinder_between(key, foot, shoe, r, r * 1.1, 8, color)
	var b := Basis(Vector3.UP.cross(wall_out), Vector3.UP, wall_out)
	for k in 3:
		var y := lerpf(low_bracket, bend.y - 0.2, k / 2.0)
		mb.box(key, Transform3D(b, Vector3(at.x, y, at.z) - wall_out * (stand_off * 0.5)), Vector3(0.1, 0.03, stand_off + 0.01), color * 0.85)
	mb.box(&"concrete", Transform3D(b, Vector3(shoe.x, ground + 0.02, shoe.z) + wall_out * 0.1), Vector3(0.26, 0.06, 0.42),
			Color(0.5, 0.49, 0.47))


## Ridge of half-round capping tiles along `a` -> `b`, each lapping over the next.
static func ridge_tiles(mb: MeshBuilder, key: StringName, a: Vector3, b: Vector3, color: Color, rng: RandomNumberGenerator,
		radius := 0.1, piece := 0.36) -> void:
	var length := a.distance_to(b)
	var n := maxi(1, roundi(length / (piece - 0.04)))
	var d := (b - a) / n
	for k in n:
		var p0 := a + d * k
		var v := rng.randf_range(0.88, 1.04)
		mb.cylinder_between(key, p0, p0 + d * (piece / d.length()), radius * 1.06, radius * 0.94, 8,
				Color(color.r * v, color.g * v, color.b * v))


## Boarded ridge cap for a small roof: on the slope of `frame` (see slope_frame()), a
## board along the ridge, `length` long, lying on the covering `lift` over the deck and
## lapping just over the ridge onto the other side's board. `key` is a rough_wood key.
static func ridge_boards(mb: MeshBuilder, key: StringName, frame: Transform3D, length: float, color: Color, lift: float,
		width := 0.13) -> void:
	mb.box(key, Transform3D(frame.basis, frame * Vector3(0, lift + 0.011, width * 0.5 - 0.012)), Vector3(length, 0.022, width + 0.024),
			color, true)


# --- Ruins ---------------------------------------------------------------------------

## Box like MeshBuilder.box() whose UVs start at `uv_off` (metres) instead of 0, so
## boards cut from one photo texture show different planks. `uv_rotate` turns the
## grain across, as box() does (vertical boards, deck boards).
static func plank(mb: MeshBuilder, key: StringName, xf: Transform3D, size: Vector3, color: Color,
		uv_off := Vector2.ZERO, uv_rotate := false) -> void:
	var h := size * 0.5
	var p: Array[Vector3] = [
		xf * Vector3(-h.x, -h.y, -h.z), xf * Vector3(h.x, -h.y, -h.z),
		xf * Vector3(h.x, h.y, -h.z), xf * Vector3(-h.x, h.y, -h.z),
		xf * Vector3(-h.x, -h.y, h.z), xf * Vector3(h.x, -h.y, h.z),
		xf * Vector3(h.x, h.y, h.z), xf * Vector3(-h.x, h.y, h.z)]
	# Faces in box() order: +Z, -Z, +X, -X, +Y, -Y as [corners, u length, v length].
	for f: Array in [[4, 5, 6, 7, size.x, size.y], [1, 0, 3, 2, size.x, size.y], [5, 1, 2, 6, size.z, size.y],
			[0, 4, 7, 3, size.z, size.y], [7, 6, 2, 3, size.x, size.z], [0, 1, 5, 4, size.x, size.z]]:
		var u: float = f[4]
		var v: float = f[5]
		var o := uv_off
		if uv_rotate:
			mb.quad(key, p[f[0]], p[f[1]], p[f[2]], p[f[3]], color, o, o + Vector2(0, u), o + Vector2(v, u), o + Vector2(v, 0))
		else:
			mb.quad(key, p[f[0]], p[f[1]], p[f[2]], p[f[3]], color, o, o + Vector2(u, 0), o + Vector2(u, v), o + Vector2(0, v))


## MeshBuilder.hexa() with chosen UVs on the top face (corners 7, 6, 2, 3) and, when
## given, the bottom face (corners 0, 1, 5, 4): neighbouring panels then run one
## texture on without a seam (a sagging roof, its ceiling).
static func panel(mb: MeshBuilder, key: StringName, p: Array[Vector3], color: Color, top_uv: Array[Vector2],
		bottom_uv: Array[Vector2] = []) -> void:
	for f: Array in [[4, 5, 6, 7], [1, 0, 3, 2], [5, 1, 2, 6], [0, 4, 7, 3]]:
		var a: Vector3 = p[f[0]]
		var u := a.distance_to(p[f[1]])
		var v := a.distance_to(p[f[3]])
		mb.quad(key, a, p[f[1]], p[f[2]], p[f[3]], color, Vector2.ZERO, Vector2(u, 0), Vector2(u, v), Vector2(0, v))
	mb.quad(key, p[7], p[6], p[2], p[3], color, top_uv[0], top_uv[1], top_uv[2], top_uv[3])
	if bottom_uv.size() == 4:
		mb.quad(key, p[0], p[1], p[5], p[4], color, bottom_uv[0], bottom_uv[1], bottom_uv[2], bottom_uv[3])
	else:
		var u := p[0].distance_to(p[1])
		var v := p[0].distance_to(p[4])
		mb.quad(key, p[0], p[1], p[5], p[4], color, Vector2.ZERO, Vector2(u, 0), Vector2(u, v), Vector2(0, v))


## Board or beam from `from` to `to` with a `section` of (height, depth), its length
## on the box's X so plank photos run along it; `uv_rotate` does the same for the
## rough_wood grain. `roll` turns it about its own length; `uv_off` as in plank().
static func beam(mb: MeshBuilder, key: StringName, from: Vector3, to: Vector3, section: Vector2, color: Color,
		uv_rotate := false, roll := 0.0, uv_off := Vector2.ZERO) -> void:
	var d := to - from
	var length := d.length()
	if length < 0.001:
		return
	var x := d / length
	var ref := Vector3.UP if absf(x.y) < 0.95 else Vector3.BACK
	var z := x.cross(ref).normalized()
	var b := Basis(x, z.cross(x), z)
	if roll != 0.0:
		b = b * Basis(Vector3.RIGHT, roll)
	plank(mb, key, Transform3D(b, (from + to) * 0.5), Vector3(length, section.x, section.y), color, uv_off, uv_rotate)


## Weathered board wall from `a` to `b` (world XZ, outer face on the same side as in
## wall()): lapped horizontal boards on studs, with a board `lining` inside (&"" =
## none, as in a shed: daylight shows through the gaps). Some boards are missing or
## hang from one nail, picked by `rng`, so a seeded wall looks the same every time.
## Openings split it as in wall() but get no frame (the caller trims them), except
## {"hole": true}: a broken-through patch with ragged board ends and a stud across.
## Every stretch and every hole gets a full collision box: the damage is only for show.
## A hole with {"spot": true} is a RepairSpot's: the spot hangs its own loose board.
## `core` closes the wall with a layer of boards behind the studs (on the lining), so no
## daylight or dark room shows through the gaps and global illumination sees a solid
## wall; a sound wall (`damage` 0) then leaves out the studs, which nothing shows.
static func board_wall(mb: MeshBuilder, cols: Array, a: Vector2, b: Vector2, y0: float, height: float, t: float,
		key: StringName, color: Color, openings: Array, rng: RandomNumberGenerator, damage := 0.12,
		lining := &"", stud_step := 0.6, core := false) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var yaw := atan2(-dir.y, dir.x)
	var basis := Basis(Vector3.UP, yaw)
	var out := basis.z
	var skin := 0.028
	var line := 0.024 if lining != &"" else 0.0
	var stud_d := minf(0.1, t - skin - line - 0.01)
	var stud_z := t * 0.5 - skin - stud_d * 0.5 - 0.004
	var stud_col := Color(color.r * 0.72, color.g * 0.7, color.b * 0.68)
	# Lap siding: every board's lower edge stands a little proud of the one below.
	var lap := basis * Basis(Vector3.RIGHT, -0.035)
	for seg in _segments(length, height, openings):
		var mid := a + dir * ((seg.x + seg.y) * 0.5)
		cols.append([Vector3(mid.x, y0 + (seg.z + seg.w) * 0.5, mid.y), Vector3(seg.y - seg.x, seg.w - seg.z, t), yaw])
		var along := seg.y - seg.x
		var tall := seg.w - seg.z
		var mid_y := y0 + (seg.z + seg.w) * 0.5
		var sz := stud_z
		if core:
			# Lined: boards on the lining (behind the studs where boards are missing). Not
			# lined (a shed): sheathing boards right behind the siding, the studs inside.
			var back := t * 0.5 - skin - (0.004 if damage <= 0.0 or lining == &"" else stud_d + 0.004)
			var front := -t * 0.5 + line if lining != &"" else back - 0.03
			if lining == &"":
				sz = front - stud_d * 0.5
			mb.box(lining if lining != &"" else &"wood_in", Transform3D(basis, Vector3(mid.x, mid_y, mid.y) + out * ((back + front) * 0.5)),
					Vector3(along, tall, back - front), Color(stud_col.r * 0.9, stud_col.g * 0.9, stud_col.b * 0.9), true)
		# Studs at both ends of the stretch and every `stud_step` between.
		var n := maxi(1, roundi(along / stud_step))
		for k in (0 if core and damage <= 0.0 and lining != &"" else n + 1):
			var su := clampf(seg.x + along * k / n, seg.x + 0.035, seg.y - 0.035)
			var sp := a + dir * su
			mb.box(&"wood_old_in", Transform3D(basis, Vector3(sp.x, mid_y, sp.y) + out * sz),
					Vector3(0.07, tall, stud_d), stud_col)
		# Lining: plain vertical boards on the inside.
		if lining != &"":
			var u := seg.x
			while u < seg.y - 0.02:
				var bw := minf(rng.randf_range(0.15, 0.26), seg.y - u)
				if seg.y - u - bw < 0.08:
					bw = seg.y - u
				var lp := a + dir * (u + bw * 0.5)
				var v := rng.randf_range(0.82, 1.05)
				plank(mb, lining, Transform3D(basis, Vector3(lp.x, y0 + (seg.z + seg.w) * 0.5, lp.y) + out * (line * 0.5 - t * 0.5)),
						Vector3(bw - 0.006, tall, line), Color(0.46 * v, 0.42 * v, 0.38 * v), Vector2(rng.randf() * 1.4, 0.0))
				u += bw
		# Siding rows, lined up with the photo's planks and across the whole wall.
		var row := floori(seg.z / BOARD_H + 0.001)
		while row * BOARD_H < seg.w - 0.02:
			var lo := maxf(row * BOARD_H, seg.z)
			var hi := minf((row + 1) * BOARD_H, seg.w)
			var u := seg.x
			while hi - lo > 0.02 and u < seg.y - 0.02:
				var run := minf(rng.randf_range(1.2, 3.2), seg.y - u)
				if seg.y - u - run < 0.3:
					run = seg.y - u
				var roll := rng.randf()
				# Missing boards leave the studs (and the lining, or daylight) showing.
				if roll >= damage * 0.35 or lo < 0.45 or hi > height - 0.25:
					var bp := a + dir * (u + run * 0.5)
					var xf := Transform3D(lap, Vector3(bp.x, y0 + (lo + hi) * 0.5, bp.y) + out * (t * 0.5 - skin * 0.5 + 0.003))
					if roll < damage:
						# Loose: hangs from the nail at one end, pulled off the wall.
						var s := 1.0 if rng.randf() < 0.5 else -1.0
						var nail := xf * Vector3(s * run * 0.42, 0, 0)
						var drop := clampf(minf(0.35, lo) / maxf(run * 0.84, 0.1), 0.02, 0.2)
						var r := Basis(out, s * rng.randf_range(0.3, 1.0) * drop)
						xf = Transform3D(r * xf.basis, nail + r * (xf.origin - nail) + out * 0.012)
					var v := rng.randf_range(0.8, 1.06) * (0.8 if lo < 0.35 else 1.0)
					var uv := Vector2(rng.randf() * 2.2, BOARD_SEAM + rng.randi_range(0, 12) * BOARD_H + lo - row * BOARD_H)
					plank(mb, key, xf, Vector3(run - 0.01, hi - lo - 0.008, skin), Color(color.r * v, color.g * v, color.b * v * 0.98), uv)
				u += run
			row += 1
	for o: Dictionary in openings:
		if o.get("hole", false):
			_hole(mb, cols, o, a, dir, basis, y0, t, key, color, rng, lining, line, skin, stud_d, stud_z, stud_col)


## Lap siding over a triangular gable, its rows lined up with the photo's planks as in
## board_wall(), each board cut to the roof's slope at both ends. `xf`: origin at the
## middle of the gable's foot on the wall's outer face, X along it, Y up, Z out.
static func gable_siding(mb: MeshBuilder, key: StringName, xf: Transform3D, width: float, rise: float, color: Color,
		rng: RandomNumberGenerator) -> void:
	var skin := 0.028
	var row := 0
	while row * BOARD_H < rise - 0.03:
		var lo := row * BOARD_H
		var hi := minf(lo + BOARD_H, rise)
		var wl := width * (1.0 - lo / rise) * 0.5
		var wh := width * (1.0 - hi / rise) * 0.5
		var v := rng.randf_range(0.82, 1.05)
		var c := Color(color.r * v, color.g * v, color.b * v)
		var u0 := rng.randf() * 2.2
		var v0 := BOARD_SEAM + rng.randi_range(0, 12) * BOARD_H
		# Lapped: each board's lower edge stands out over the one below.
		var zl := 0.009 + skin
		var zh := 0.003 + skin
		var bl := xf * Vector3(-wl, lo + 0.004, zl)
		var br := xf * Vector3(wl, lo + 0.004, zl)
		var tr := xf * Vector3(wh, hi - 0.004, zh)
		var tl := xf * Vector3(-wh, hi - 0.004, zh)
		mb.quad(key, bl, br, tr, tl, c, Vector2(u0 - wl, v0), Vector2(u0 + wl, v0), Vector2(u0 + wh, v0 + hi - lo),
				Vector2(u0 - wh, v0 + hi - lo))
		mb.quad(key, xf * Vector3(-wl, lo + 0.004, zl - skin), xf * Vector3(wl, lo + 0.004, zl - skin), br, bl, c * 0.8,
				Vector2(u0, v0), Vector2(u0 + wl * 2.0, v0), Vector2(u0 + wl * 2.0, v0 + skin), Vector2(u0, v0 + skin))
		row += 1


## Timber trim of the opening `o` ({at, w, bottom, top}) of a board_wall() from `a` to
## `b` (`t` thick, standing on `y0`): casing boards round it outside, linings through
## the wall and, for a window (bottom over 0), a sill, a four-pane sash with its glass
## set back in the wall and, when `dark_in`, a dark board behind it (a wall that is
## solid behind the window). `key` is a rough_wood key; the sash's glazing bars go into
## `detail` when it is given.
static func opening_trim(mb: MeshBuilder, a: Vector2, b: Vector2, y0: float, t: float, o: Dictionary, key: StringName,
		color: Color, dark_in := false, detail: MeshBuilder = null) -> void:
	var xf := opening_frame(a, b, y0, t, o)
	var w: float = o["w"]
	var bottom: float = o["bottom"]
	var top: float = o["top"]
	var h := top - bottom
	var window := bottom > 0.01
	var cw := 0.09
	var z_out := 0.026
	var foot := -h * 0.5 if window else -h * 0.5 - bottom
	# Upright members keep the grain up (no uv_rotate), lying ones turn it along X.
	for sx: float in [-1.0, 1.0]:
		mb.box(key, xf * Transform3D(Basis(), Vector3(sx * (w * 0.5 + cw * 0.5), (foot + h * 0.5 + cw) * 0.5, z_out)),
				Vector3(cw, h * 0.5 + cw - foot, 0.026), color)
		mb.box(key, xf * Transform3D(Basis(), Vector3(sx * (w * 0.5 - 0.011), 0, -t * 0.5)), Vector3(0.022, h, t + 0.01), color * 0.9)
	mb.box(key, xf * Transform3D(Basis(), Vector3(0, h * 0.5 + cw * 0.5, z_out)), Vector3(w + cw * 2.0, cw, 0.026), color, true)
	mb.box(key, xf * Transform3D(Basis(), Vector3(0, h * 0.5 - 0.011, -t * 0.5)), Vector3(w, 0.022, t + 0.01), color * 0.9, true)
	if not window:
		return
	mb.box(key, xf * Transform3D(Basis(), Vector3(0, -h * 0.5 - 0.018, 0.02)), Vector3(w + cw * 2.0 + 0.08, 0.04, 0.12), color, true)
	mb.box(key, xf * Transform3D(Basis(), Vector3(0, -h * 0.5 + 0.011, -t * 0.5)), Vector3(w, 0.022, t + 0.01), color * 0.9, true)
	var z := -t * 0.45
	var sc := Color(color.r * 0.88, color.g * 0.88, color.b * 0.88)
	var bars := detail if detail else mb
	for piece: Array in [[Vector3(-w * 0.5 + 0.045, 0, z), Vector3(0.05, h - 0.04, 0.04), mb], [Vector3(w * 0.5 - 0.045, 0, z), Vector3(0.05, h - 0.04, 0.04), mb],
			[Vector3(0, h * 0.5 - 0.045, z), Vector3(w - 0.04, 0.05, 0.04), mb], [Vector3(0, -h * 0.5 + 0.05, z), Vector3(w - 0.04, 0.06, 0.04), mb],
			[Vector3(0, 0, z), Vector3(0.03, h - 0.1, 0.03), bars], [Vector3(0, 0, z), Vector3(w - 0.1, 0.03, 0.03), bars]]:
		var size: Vector3 = piece[1]
		(piece[2] as MeshBuilder).box(key, xf * Transform3D(Basis(), piece[0]), size, sc, size.x > size.y)
	mb.box(&"window_glass", xf * Transform3D(Basis(), Vector3(0, 0, z)), Vector3(w - 0.1, h - 0.1, 0.006), Color.WHITE)
	if dark_in:
		mb.box(&"paint_in", xf * Transform3D(Basis(), Vector3(0, 0, z - 0.08)), Vector3(w, h, 0.02), Color(0.05, 0.045, 0.04))


## Vertical battens over the board seams of a box wall built with MeshBuilder.box()
## (`uv_rotate`, the planks photo on its faces): on the face whose outward normal is
## `face` (+X, -X, +Z or -Z of the box `xf`, `size`), one every `every` boards, so
## they cover the photo's joints: board-and-batten siding. None within the ranges
## `skips` (along the face, in the box's own X or Z), where windows are. `key` is a
## rough_wood key: the grain runs up each batten, cut from another part of the photo.
static func battens(mb: MeshBuilder, key: StringName, xf: Transform3D, size: Vector3, face: Vector3, color: Color,
		every := 2, skips: Array[Vector2] = []) -> void:
	var h := size * 0.5
	var along := size.x if absf(face.z) > 0.5 else size.z
	# The face's UVs start at the corner box() puts first: -X on +Z, +X on -Z, +Z on +X, -Z on -X.
	var start := -h.x if face.z > 0.5 else (h.x if face.z < -0.5 else (h.z if face.x > 0.5 else -h.z))
	var step := -1.0 if (face.z < -0.5 or face.x > 0.5) else 1.0
	var depth := h.z if absf(face.z) > 0.5 else h.x
	var k := 0
	while true:
		var u := BOARD_SEAM + k * BOARD_H * every
		if u > along - 0.02:
			break
		k += 1
		var c := start + step * u
		var skipped := false
		for r: Vector2 in skips:
			skipped = skipped or (c > r.x and c < r.y)
		if skipped:
			continue
		var p := Vector3(c, 0, face.z * (depth + 0.011)) if absf(face.z) > 0.5 else Vector3(face.x * (depth + 0.011), 0, c)
		var s := Vector3(0.055, size.y, 0.022) if absf(face.z) > 0.5 else Vector3(0.022, size.y, 0.055)
		plank(mb, key, xf * Transform3D(Basis(), p), s, color, Vector2(fposmod(k * 0.53, 1.3), fposmod(k * 0.91, 1.3)))


## Frame of the opening `o` ({at, bottom, top}) of a board_wall() from `a` to `b`: X runs
## along the wall, Z out of its outer face, the origin in the middle of the opening on
## that face (a RepairSpot sits there).
static func opening_frame(a: Vector2, b: Vector2, y0: float, t: float, o: Dictionary) -> Transform3D:
	var dir := (b - a).normalized()
	var basis := Basis(Vector3.UP, atan2(-dir.y, dir.x))
	var p := a + dir * float(o["at"])
	var y := y0 + (float(o["bottom"]) + float(o["top"])) * 0.5
	return Transform3D(basis, Vector3(p.x, y, p.y) + basis.z * (t * 0.5))


## A broken-through patch of a board wall: its collision box, the ragged ends of the
## siding rows and of the lining, a stud across and maybe a board hanging over it.
static func _hole(mb: MeshBuilder, cols: Array, o: Dictionary, a: Vector2, dir: Vector2, basis: Basis, y0: float,
		t: float, key: StringName, color: Color, rng: RandomNumberGenerator, lining: StringName, line: float,
		skin: float, stud_d: float, stud_z: float, stud_col: Color) -> void:
	var out := basis.z
	var at: float = o["at"]
	var w: float = o["w"]
	var bottom: float = o["bottom"]
	var top: float = o["top"]
	var p := a + dir * at
	cols.append([Vector3(p.x, y0 + (bottom + top) * 0.5, p.y), Vector3(w, top - bottom, t), atan2(-dir.y, dir.x)])
	var row := floori(bottom / BOARD_H + 0.001)
	while row * BOARD_H < top - 0.02:
		var lo := maxf(row * BOARD_H, bottom)
		var hi := minf((row + 1) * BOARD_H, top)
		for side: float in [-1.0, 1.0]:
			var stub := rng.randf_range(0.0, minf(0.3, w * 0.45))
			if stub > 0.04 and hi - lo > 0.02:
				var sp := a + dir * (at + side * (w * 0.5 - stub * 0.5))
				var v := rng.randf_range(0.75, 1.0)
				plank(mb, key, Transform3D(basis, Vector3(sp.x, y0 + (lo + hi) * 0.5, sp.y) + out * (t * 0.5 - skin * 0.5 + 0.003)),
						Vector3(stub, hi - lo - 0.008, skin), Color(color.r * v, color.g * v, color.b * v),
						Vector2(rng.randf() * 2.2, BOARD_SEAM + rng.randi_range(0, 12) * BOARD_H + lo - row * BOARD_H))
		row += 1
	if lining != &"":
		var u := at - w * 0.5
		while u < at + w * 0.5 - 0.03:
			var bw := minf(rng.randf_range(0.15, 0.24), at + w * 0.5 - u)
			var lp := a + dir * (u + bw * 0.5)
			for side: float in [-1.0, 1.0]:
				var stub := rng.randf_range(0.0, minf(0.3, (top - bottom) * 0.4))
				if stub > 0.04:
					var y := bottom + stub * 0.5 if side < 0.0 else top - stub * 0.5
					var v := rng.randf_range(0.78, 1.0)
					mb.box(lining, Transform3D(basis, Vector3(lp.x, y0 + y, lp.y) + out * (line * 0.5 - t * 0.5)),
							Vector3(bw - 0.006, stub, line), Color(0.46 * v, 0.42 * v, 0.38 * v))
			u += bw
	var stud_at := a + dir * (at + w * rng.randf_range(-0.25, 0.25))
	mb.box(&"wood_old_in", Transform3D(basis, Vector3(stud_at.x, y0 + (bottom + top) * 0.5, stud_at.y) + out * stud_z),
			Vector3(0.07, top - bottom, stud_d), stud_col)
	if rng.randf() < 0.6 and not o.get("spot", false):
		var from := a + dir * (at - w * 0.5 - 0.15)
		var to := a + dir * (at + w * 0.5 - 0.1)
		beam(mb, key, Vector3(from.x, y0 + top - 0.08, from.y) + out * (t * 0.5 + 0.02),
				Vector3(to.x, y0 + bottom + 0.12, to.y) + out * (t * 0.5 + 0.03), Vector2(BOARD_H - 0.01, skin),
				Color(color.r * 0.9, color.g * 0.9, color.b * 0.88))


## Dusty cobweb spun across an inside corner: a fan from `corner` between the unit
## directions `a` and `b`, `size` metres out, sagging in the middle and fading toward
## its rim. Draw it with the "cobweb" material in a mesh that casts no shadow.
static func cobweb(mb: MeshBuilder, corner: Vector3, a: Vector3, b: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	var steps := 5
	var n := a.cross(b).normalized()
	for layer in 2:
		var reach := size * (1.0 if layer == 0 else rng.randf_range(0.5, 0.7))
		var sag := size * rng.randf_range(0.1, 0.2)
		var inner: Array[Vector3] = []
		var rim: Array[Vector3] = []
		for k in steps + 1:
			var f := float(k) / steps
			var d := (a * (1.0 - f) + b * f).normalized()
			var r := reach * (rng.randf_range(0.8, 1.05) if k > 0 and k < steps else 1.0)
			var droop := Vector3.DOWN * sag * sin(PI * f)
			rim.append(corner + d * r + droop)
			inner.append(corner + d * r * 0.45 + droop * 0.6)
		var c0 := Color(0.86, 0.85, 0.82, 0.32)
		var c1 := Color(0.86, 0.85, 0.82, 0.2)
		var c2 := Color(0.86, 0.85, 0.82, 0.02)
		for k in steps:
			mb.tri_n(&"cobweb", corner, inner[k], inner[k + 1], n, n, n, c0, c1, c1)
			mb.tri_n(&"cobweb", inner[k], rim[k], rim[k + 1], n, n, n, c1, c2, c2)
			mb.tri_n(&"cobweb", inner[k], rim[k + 1], inner[k + 1], n, n, n, c1, c2, c1)


## What is left of a broken pane (`w` x `h`, centred on `xf`, in its XY plane): jagged
## shards stuck in two or three of its corners. Uses "glass_old" (seen from both sides).
static func broken_glass(mb: MeshBuilder, xf: Transform3D, w: float, h: float, rng: RandomNumberGenerator) -> void:
	var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var n := (xf.basis * Vector3.BACK).normalized()
	var start := rng.randi_range(0, 3)
	for i in rng.randi_range(2, 3):
		var c := corners[(start + i) % 4]
		var p0 := Vector2(c.x * w * 0.5, c.y * h * 0.5)
		var p1 := p0 - Vector2(c.x * w * rng.randf_range(0.25, 0.8), 0.0)
		var p2 := p0 - Vector2(0.0, c.y * h * rng.randf_range(0.2, 0.75))
		var jag := p0.lerp((p1 + p2) * 0.5, rng.randf_range(0.4, 1.3))
		for tri: Array in [[p0, p1, jag], [p0, jag, p2]]:
			var q0: Vector2 = tri[0]
			var q1: Vector2 = tri[1]
			var q2: Vector2 = tri[2]
			# Counter-clockwise toward +Z in every corner, so the two-sided material flips
			# the normal on the right side and no shard shades inside out.
			if (q1 - q0).cross(q2 - q0) < 0.0:
				var swap := q1
				q1 = q2
				q2 = swap
			mb.tri_n(&"glass_old", xf * Vector3(q0.x, q0.y, 0), xf * Vector3(q1.x, q1.y, 0), xf * Vector3(q2.x, q2.y, 0),
					n, n, n, Color.WHITE, Color.WHITE, Color.WHITE)
