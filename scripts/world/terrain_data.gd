@tool
class_name TerrainData
extends RefCounted
## Heightfield (1 m grid) plus a high resolution ground mask (4 px per meter) covering
## the whole map rectangle, generated deterministically from WorldLayout: the farm
## valley, the town valley, the hills around them, a pass between them and the
## county road, whose bed is cut and filled to a smooth, grade-limited profile.
##
## Mask channels: R = path, G = dirt yard, B = pond shore, A = closeness to the centre
## line of a lane vehicles use (1 on it, 0 from TRACK_REACH away; the ground shaders
## draw its wheel ruts from it). The terrain shader samples the mask texture; placement
## code queries it through path_at()/dirt_at().

const MIN_X := WorldLayout.MAP_MIN_X
const MIN_Z := WorldLayout.MAP_MIN_Z
const NX := WorldLayout.MAP_W + 1
const NZ := WorldLayout.MAP_D + 1
const SEED := 20240917
const MASK_PPM := 4
const MASK_W := WorldLayout.MAP_W * MASK_PPM
const MASK_H := WorldLayout.MAP_D * MASK_PPM
## Road centreline resampled every ROAD_STEP metres, with the road surface height.
const ROAD_STEP := 1.0
## Lanes at least this wide carry wheel ruts (mask A).
const TRACK_WIDTH := 2.6
## How far from a lane's centre line the mask A channel reaches (metres).
const TRACK_REACH := 2.5

static var heights := PackedFloat32Array()
static var mask := PackedByteArray()
static var road_points := PackedVector2Array()
static var road_heights := PackedFloat32Array()
static var _mask_texture: ImageTexture
static var _height_texture: ImageTexture
static var _generated := false


static func ensure() -> void:
	if not _generated:
		_generate()
		_generated = true


static func invalidate() -> void:
	_generated = false
	_mask_texture = null
	_height_texture = null


static func mask_texture() -> ImageTexture:
	ensure()
	if _mask_texture == null:
		var img := Image.create_from_data(MASK_W, MASK_H, false, Image.FORMAT_RGBA8, mask)
		img.generate_mipmaps()
		_mask_texture = ImageTexture.create_from_image(img)
	return _mask_texture


## The heightfield as a float texture (one texel per grid point) with mipmaps: the
## ground shaders compare a point's height with the blurred height around it to find
## damp hollows. Half floats: linear filtering of them works on every GPU (32-bit float
## filtering is optional in Vulkan), and they keep millimetres in the valley.
static func height_texture() -> ImageTexture:
	ensure()
	if _height_texture == null:
		var img := Image.create_from_data(NX, NZ, false, Image.FORMAT_RF, heights.to_byte_array())
		img.convert(Image.FORMAT_RH)
		img.generate_mipmaps()
		_height_texture = ImageTexture.create_from_image(img)
	return _height_texture


## Sets the ground-field uniforms (shaders/include/ground.gdshaderinc) that the terrain,
## the meadow grass and the other ground shaders share, so they agree on where the
## meadow is damp, trampled or dry.
static func apply_ground_fields(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("mask_tex", mask_texture())
	mat.set_shader_parameter("height_tex", height_texture())
	mat.set_shader_parameter("map_min", Vector2(MIN_X, MIN_Z))
	mat.set_shader_parameter("map_size", Vector2(WorldLayout.MAP_W, WorldLayout.MAP_D))
	mat.set_shader_parameter("water_level", WorldLayout.WATER_LEVEL)
	mat.set_shader_parameter("pond_center", WorldLayout.POND_CENTER)
	mat.set_shader_parameter("pond_radius", WorldLayout.POND_RADIUS)
	mat.set_shader_parameter("track_reach", TRACK_REACH)
	var lots := PackedVector4Array()
	for lot_id: StringName in WorldLayout.FIELD_LOTS:
		var r: Rect2 = WorldLayout.FIELD_LOTS[lot_id]["rect"]
		lots.append(Vector4(r.position.x, r.position.y, r.end.x, r.end.y))
	while lots.size() < 4:
		lots.append(Vector4(0, 0, 0, 0))
	mat.set_shader_parameter("lots", lots.slice(0, 4))


# --- Queries -------------------------------------------------------------------

static func height(x: float, z: float) -> float:
	ensure()
	return _height_raw(x, z)


static func _height_raw(x: float, z: float) -> float:
	var fx := clampf(x - MIN_X, 0.0, NX - 1.001)
	var fz := clampf(z - MIN_Z, 0.0, NZ - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var a := heights[iz * NX + ix]
	var b := heights[iz * NX + ix + 1]
	var c := heights[(iz + 1) * NX + ix]
	var d := heights[(iz + 1) * NX + ix + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


static func path_at(x: float, z: float) -> float:
	return _mask_sample(x, z, 0)


static func dirt_at(x: float, z: float) -> float:
	return _mask_sample(x, z, 1)


static func shore_at(x: float, z: float) -> float:
	return _mask_sample(x, z, 2)


## Distance (m) to the centre line of the nearest lane vehicles use, TRACK_REACH when
## farther than that. Visual only (ruts, the grassy strip between them).
static func track_distance(x: float, z: float) -> float:
	return (1.0 - _mask_sample(x, z, 3)) * TRACK_REACH


static func normal_at(x: float, z: float) -> Vector3:
	var e := 0.5
	var hx := height(x + e, z) - height(x - e, z)
	var hz := height(x, z + e) - height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


static func point_on_ground(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, height(x, z) + lift, z)


static func is_underwater(x: float, z: float, margin := 0.05) -> bool:
	return height(x, z) < WorldLayout.WATER_LEVEL + margin


## Road surface height at the centreline point nearest to (x, z).
static func road_height_near(x: float, z: float) -> float:
	ensure()
	var p := Vector2(x, z)
	var best := INF
	var h := 0.0
	for i in road_points.size():
		var d := p.distance_squared_to(road_points[i])
		if d < best:
			best = d
			h = road_heights[i]
	return h


static func _mask_sample(x: float, z: float, channel: int) -> float:
	ensure()
	var fx := clampf((x - MIN_X) * MASK_PPM - 0.5, 0.0, MASK_W - 1.001)
	var fz := clampf((z - MIN_Z) * MASK_PPM - 0.5, 0.0, MASK_H - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var a := mask[(iz * MASK_W + ix) * 4 + channel]
	var b := mask[(iz * MASK_W + ix + 1) * 4 + channel]
	var c := mask[((iz + 1) * MASK_W + ix) * 4 + channel]
	var d := mask[((iz + 1) * MASK_W + ix + 1) * 4 + channel]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz) / 255.0


# --- Generation ----------------------------------------------------------------

static func _generate() -> void:
	var rolling := FastNoiseLite.new()
	rolling.seed = SEED
	rolling.frequency = 0.018
	rolling.fractal_octaves = 3
	var hills := FastNoiseLite.new()
	hills.seed = SEED + 1
	hills.frequency = 0.012
	hills.fractal_octaves = 4
	var ridge := FastNoiseLite.new()
	ridge.seed = SEED + 3
	ridge.frequency = 0.022
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 3
	var edge_noise := FastNoiseLite.new()
	edge_noise.seed = SEED + 2
	edge_noise.frequency = 0.9
	var town := WorldLayout.TOWN_CENTER

	heights.resize(NX * NZ)
	for iz in NZ:
		var z := float(MIN_Z + iz)
		for ix in NX:
			var x := float(MIN_X + ix)
			var d := sqrt(x * x + z * z)
			var ang := atan2(z, x)
			var edge := WorldLayout.VALLEY_RADIUS + edge_noise.get_noise_2d(cos(ang) * 3.0, sin(ang) * 3.0) * 9.0
			var hill := smoothstep(edge - 6.0, edge + 42.0, d)
			# Second valley for the town, joined to the farm by a pass along the road.
			var dt := Vector2(x, z).distance_to(town)
			var near_valley := d
			if dt < WorldLayout.TOWN_VALLEY_RADIUS + 110.0:
				var ang_t := atan2(z - town.y, x - town.x)
				var edge_t := WorldLayout.TOWN_VALLEY_RADIUS + edge_noise.get_noise_2d(cos(ang_t) * 3.0 + 7.0, sin(ang_t) * 3.0) * 6.0
				hill = minf(hill, smoothstep(edge_t - 6.0, edge_t + 38.0, dt))
				near_valley = minf(d, dt + 90.0 - WorldLayout.TOWN_VALLEY_RADIUS)
			if x > 40.0 and hill > 0.0:
				var dr := WorldLayout.distance_to_road(x, z)
				hill *= 1.0 - 0.86 * (1.0 - smoothstep(12.0, 48.0, dr))
			var amp := lerpf(0.3, 1.2, smoothstep(25.0, 80.0, near_valley))
			var h := rolling.get_noise_2d(x, z) * amp
			h += hill * (17.0 + hills.get_noise_2d(x, z) * 12.0 + ridge.get_noise_2d(x, z) * 5.0 * hill)
			for zone in WorldLayout.FLAT_ZONES:
				var w := WorldLayout.flat_weight(x, z, zone)
				if w > 0.0:
					h = lerpf(h, float(zone["height"]), w)
			var pd := WorldLayout.distance_to_pond(x, z)
			if pd < WorldLayout.POND_RADIUS + 5.0:
				var bowl := 1.0 - smoothstep(WorldLayout.POND_RADIUS * 0.35, WorldLayout.POND_RADIUS + 3.0, pd)
				h = lerpf(h, -2.4, bowl)
			heights[iz * NX + ix] = h
	_build_road()
	_generate_mask()


## Resamples the road spline, gives it a smooth, grade-limited height profile and
## cuts/fills the terrain under and beside it to that profile.
static func _build_road() -> void:
	var ctrl: Array = WorldLayout.ROAD_POINTS
	# Dense Catmull-Rom samples, then even spacing by arc length.
	var dense := PackedVector2Array()
	for i in ctrl.size() - 1:
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, ctrl.size() - 1)]
		for k in 16:
			dense.append(p1.cubic_interpolate(p2, p0, p3, k / 16.0))
	dense.append(ctrl[ctrl.size() - 1])
	road_points = PackedVector2Array([dense[0]])
	var carry := 0.0
	for i in range(1, dense.size()):
		var a := dense[i - 1]
		var seg := a.distance_to(dense[i])
		var t := ROAD_STEP - carry
		while t <= seg:
			road_points.append(a.lerp(dense[i], t / seg))
			t += ROAD_STEP
		carry = seg - (t - ROAD_STEP)
	var n := road_points.size()
	# Raw ground heights, smoothed, then limited to the maximum grade both ways.
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in n:
		raw[i] = _height_raw(road_points[i].x, road_points[i].y)
	var smooth := PackedFloat32Array()
	smooth.resize(n)
	const R := 24
	for i in n:
		var sum := 0.0
		var wsum := 0.0
		for k in range(-R, R + 1):
			var j := clampi(i + k, 0, n - 1)
			var w := exp(-float(k * k) / (2.0 * 10.0 * 10.0))
			sum += raw[j] * w
			wsum += w
		smooth[i] = sum / wsum
	var g := WorldLayout.ROAD_MAX_GRADE * ROAD_STEP
	for _pass in 3:
		for i in range(1, n):
			smooth[i] = clampf(smooth[i], smooth[i - 1] - g, smooth[i - 1] + g)
		for i in range(n - 2, -1, -1):
			smooth[i] = clampf(smooth[i], smooth[i + 1] - g, smooth[i + 1] + g)
	road_heights = smooth
	# Cut and fill: the bed under the asphalt sits just below the road surface and
	# blends back into the natural ground over the shoulders.
	var half_w := WorldLayout.ROAD_WIDTH * 0.5
	var reach := half_w + 13.0
	var best_d := PackedFloat32Array()
	best_d.resize(NX * NZ)
	best_d.fill(INF)
	var best_h := PackedFloat32Array()
	best_h.resize(NX * NZ)
	for i in n - 1:
		var a := road_points[i]
		var b := road_points[i + 1]
		var ab := b - a
		var len2 := maxf(ab.length_squared(), 0.0001)
		var x0 := maxi(int(floor(minf(a.x, b.x) - reach)) - MIN_X, 0)
		var x1 := mini(int(ceil(maxf(a.x, b.x) + reach)) - MIN_X, NX - 1)
		var z0 := maxi(int(floor(minf(a.y, b.y) - reach)) - MIN_Z, 0)
		var z1 := mini(int(ceil(maxf(a.y, b.y) + reach)) - MIN_Z, NZ - 1)
		for iz in range(z0, z1 + 1):
			for ix in range(x0, x1 + 1):
				var p := Vector2(MIN_X + ix, MIN_Z + iz)
				var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
				var dist := p.distance_to(a + ab * t)
				var k := iz * NX + ix
				if dist < best_d[k]:
					best_d[k] = dist
					best_h[k] = lerpf(road_heights[i], road_heights[i + 1], t)
	for k in NX * NZ:
		var dist := best_d[k]
		if dist >= reach:
			continue
		var w := 1.0 - smoothstep(half_w + 1.2, reach, dist)
		heights[k] = lerpf(heights[k], best_h[k] - 0.08, w)


static func _generate_mask() -> void:
	mask.resize(MASK_W * MASK_H * 4)
	mask.fill(0)
	var edge := FastNoiseLite.new()
	edge.seed = SEED + 7
	edge.frequency = 0.35
	for path in WorldLayout.PATHS:
		var pts: Array = path["points"]
		for i in pts.size() - 1:
			_stamp_segment(pts[i], pts[i + 1], float(path["width"]), edge)
			if float(path["width"]) >= TRACK_WIDTH:
				_stamp_track(pts[i], pts[i + 1], edge)
	# Gravel verges along the asphalt.
	for i in range(0, road_points.size() - 2, 2):
		_stamp_segment(road_points[i], road_points[i + 2], WorldLayout.ROAD_WIDTH + 2.4, edge)
	for spot in WorldLayout.DIRT_SPOTS:
		_stamp_blob(spot["center"], float(spot["radius"]), 1, edge)
	_stamp_blob(WorldLayout.POND_CENTER, WorldLayout.POND_RADIUS + 0.6, 2, edge)


static func _write(px: int, pz: int, channel: int, value: float) -> void:
	var i := (pz * MASK_W + px) * 4 + channel
	var v := clampi(int(value * 255.0), 0, 255)
	if v > mask[i]:
		mask[i] = v


static func _world_x(px: int) -> float:
	return (px + 0.5) / MASK_PPM + MIN_X


static func _world_z(pz: int) -> float:
	return (pz + 0.5) / MASK_PPM + MIN_Z


static func _stamp_segment(a: Vector2, b: Vector2, width: float, edge: FastNoiseLite) -> void:
	var half_w := width * 0.5
	var reach := half_w + 1.2
	var px0 := maxi(int((minf(a.x, b.x) - reach - MIN_X) * MASK_PPM), 0)
	var px1 := mini(int((maxf(a.x, b.x) + reach - MIN_X) * MASK_PPM), MASK_W - 1)
	var pz0 := maxi(int((minf(a.y, b.y) - reach - MIN_Z) * MASK_PPM), 0)
	var pz1 := mini(int((maxf(a.y, b.y) + reach - MIN_Z) * MASK_PPM), MASK_H - 1)
	for pz in range(pz0, pz1 + 1):
		var wz := _world_z(pz)
		for px in range(px0, px1 + 1):
			var p := Vector2(_world_x(px), wz)
			var dist := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
			if dist > reach:
				continue
			var wobble := edge.get_noise_2d(p.x, p.y) * 0.35
			var v := 1.0 - smoothstep(half_w - 0.35, half_w + 0.25, dist + wobble)
			if v > 0.0:
				_write(px, pz, 0, v)


## Mask A along a vehicle lane: closeness to its centre line, which wanders a little
## (drivers don't keep to a line).
static func _stamp_track(a: Vector2, b: Vector2, edge: FastNoiseLite) -> void:
	var reach := TRACK_REACH + 0.3
	var px0 := maxi(int((minf(a.x, b.x) - reach - MIN_X) * MASK_PPM), 0)
	var px1 := mini(int((maxf(a.x, b.x) + reach - MIN_X) * MASK_PPM), MASK_W - 1)
	var pz0 := maxi(int((minf(a.y, b.y) - reach - MIN_Z) * MASK_PPM), 0)
	var pz1 := mini(int((maxf(a.y, b.y) + reach - MIN_Z) * MASK_PPM), MASK_H - 1)
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	for pz in range(pz0, pz1 + 1):
		var wz := _world_z(pz)
		for px in range(px0, px1 + 1):
			var p := Vector2(_world_x(px), wz)
			var q := Geometry2D.get_closest_point_to_segment(p, a, b)
			var off := (p - q).dot(side) + edge.get_noise_2d(q.x * 0.25 + 50.0, q.y * 0.25) * 0.25
			var dist := sqrt(maxf(p.distance_squared_to(q) - (p - q).dot(side) ** 2, 0.0) + off * off)
			if dist < TRACK_REACH:
				_write(px, pz, 3, 1.0 - dist / TRACK_REACH)


static func _stamp_blob(center: Vector2, radius: float, channel: int, edge: FastNoiseLite) -> void:
	var reach := radius + 2.0
	var px0 := maxi(int((center.x - reach - MIN_X) * MASK_PPM), 0)
	var px1 := mini(int((center.x + reach - MIN_X) * MASK_PPM), MASK_W - 1)
	var pz0 := maxi(int((center.y - reach - MIN_Z) * MASK_PPM), 0)
	var pz1 := mini(int((center.y + reach - MIN_Z) * MASK_PPM), MASK_H - 1)
	for pz in range(pz0, pz1 + 1):
		var wz := _world_z(pz)
		for px in range(px0, px1 + 1):
			var p := Vector2(_world_x(px), wz)
			var ang := (p - center).angle()
			var wobble := edge.get_noise_2d(cos(ang) * 4.0 + center.x, sin(ang) * 4.0 + center.y) * radius * 0.22
			wobble += edge.get_noise_2d(p.x * 3.0, p.y * 3.0) * 0.3
			var v := 1.0 - smoothstep(radius - 0.8, radius + 0.3, p.distance_to(center) + wobble)
			if v > 0.0:
				_write(px, pz, channel, v)
