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
static func board_wall(mb: MeshBuilder, cols: Array, a: Vector2, b: Vector2, y0: float, height: float, t: float,
		key: StringName, color: Color, openings: Array, rng: RandomNumberGenerator, damage := 0.12,
		lining := &"", stud_step := 0.6) -> void:
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
		# Studs at both ends of the stretch and every `stud_step` between.
		var n := maxi(1, roundi(along / stud_step))
		for k in n + 1:
			var su := clampf(seg.x + along * k / n, seg.x + 0.035, seg.y - 0.035)
			var sp := a + dir * su
			mb.box(&"wood_old_in", Transform3D(basis, Vector3(sp.x, y0 + (seg.z + seg.w) * 0.5, sp.y) + out * stud_z),
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
	if rng.randf() < 0.6:
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
