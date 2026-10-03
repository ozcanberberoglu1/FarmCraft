class_name TownCarnival
extends Node3D
## Yeşilova dressed for a carnival night (Carnival). Built when the evening comes (19:30,
## or on loading into one) and freed at 23:00, so other nights carry none of it:
##
##   - the main street: strings of coloured bulbs zig-zagging over it from the lamp posts
##     to the far pavement's lamps and the filling station's canopy, paper lanterns
##     hanging under them, bunting from lamp to lamp along the pavements, bulbs scalloped
##     along the market's cornice, the station's fascia and over the Animal Market's gate
##   - a lit arch ("KARNAVAL") in the gap between the market and the car dealer, and a
##     festooned walk from it to the fairground on the green behind them: a plaza under a
##     canopy of bulb strings from a tall mast, a cotton-candy stall, a roasted-corn stall
##     and a balloon seller's cart around it, a carousel with its horses, and a Ferris
##     wheel whose rim and spokes are ringed with bulbs, turning slowly
##   - fireworks (CarnivalFireworks) when the fun starts at 20:00 and again before 23:00
##   - the whole town at the fair meanwhile (CarnivalCrowd, a child of this node)
##
## Hundreds of bulbs cost little: they are multimesh instances of one small sphere whose
## shader (carnival_bulb.gdshader) makes them glow, shimmer, chase along their strings or
## run round the wheel; the screen's glow does the rest. Only a handful of real lights
## (no shadows) throw colour on the ground: three on LOW, five on MEDIUM, seven above.
## The bulbs switch on at dusk (or at 20:00 at the latest) in a sweep along the street.
## Things people could walk into (stalls, the carousel, the wheel's platform, the arch's
## posts) stand off the pavements and walks and have simple colliders.

const BULB_ENERGY := 4.5
const LANTERN_ENERGY := 1.15
## Bulb colours (sRGB): warm white and amber, then red, green, blue, pink and yellow.
const PALETTE: Array[Color] = [Color(1.0, 0.76, 0.42), Color(1.0, 0.5, 0.08), Color(1.0, 0.12, 0.08),
	Color(0.2, 1.0, 0.25), Color(1.0, 0.76, 0.42), Color(0.15, 0.4, 1.0), Color(1.0, 0.2, 0.62),
	Color(1.0, 0.85, 0.15)]
const WARM := Color(1.0, 0.76, 0.45)
const LANTERN_COLORS: Array[Color] = [Color(1.0, 0.16, 0.06), Color(1.0, 0.45, 0.05), Color(1.0, 0.75, 0.15),
	Color(1.0, 0.22, 0.45)]
## The fairground: its plaza (under the mast's bulb canopy), the Ferris wheel (hub over
## x, z; it faces the street) and the carousel, on the green behind the market.
const PLAZA := Vector2(226.0, -20.0)
const PLAZA_R := 10.0
const WHEEL := Vector2(226.0, -36.0)
const WHEEL_R := 8.0
const HUB_H := 10.4
const GONDOLAS := 12
const CAROUSEL := Vector2(208.0, -25.0)
## The arch over the walk between the market and the dealer's (posts at x, z).
const ARCH_X := Vector2(225.3, 230.7)
const ARCH_Z := 9.6
## Lamp posts along the north pavement (z 14) and the south one (z 26.1), and where the
## filling station's canopy fascia takes the strings in between.
const LAMPS_N: Array[float] = [190.0, 204.0, 218.0, 232.0, 246.0, 260.0, 274.0]
const LAMPS_S: Array[float] = [236.0, 250.0, 264.0, 278.0]
const CANOPY_HOOKS: Array[float] = [201.0, 212.0, 222.0]
## Seconds the bulbs take to come on along the street.
const SWEEP_SECONDS := 2.5
const WHEEL_SPEED := 0.1
const CAROUSEL_SPEED := 0.42

var town: Town
## Everything of tonight's dressing (null on other nights).
var root: Node3D
var fireworks: CarnivalFireworks
## The dressing goes up over a few frames (none of them long); true meanwhile.
var building := false
## The longest of those frames' work, in milliseconds (tests read it).
var build_ms := 0.0

var _bulb_mat: ShaderMaterial
var _lantern_mat: ShaderMaterial
var _wheel: Node3D
## The gondolas: one multimesh per colour, three gondolas each, set level every frame.
var _gondolas: Array[MultiMesh] = []
var _carousel: Node3D
var _balloons: Node3D
var _lights: Array[OmniLight3D] = []
var _power := 0.0
var _sweep := 2.0
var _lit := false
var _show_left := 0.0
var _next_shell := 0.0
var _time := 0.0
## Counts builds and clears: a build going up over several frames stops when it changes.
var _gen := 0

## Instances gathered while building: set name -> [positions, colours, custom data].
var _sets := {}
var _mb: MeshBuilder
var _wires: MeshBuilder
var _cols: Array = []


func _ready() -> void:
	name = "Carnival"
	town = get_parent() as Town
	Carnival.began.connect(_on_began)
	Settings.changed.connect(_apply_quality)
	# The whole town comes to the fair (after the townspeople are in: Town adds them first).
	var crowd := CarnivalCrowd.new()
	crowd.town = town
	crowd.carnival = self
	add_child(crowd)


func _process(delta: float) -> void:
	var want := Carnival.is_dressed()
	if building:
		if not want:
			clear()
		return
	if want and root == null:
		build()
		return
	elif not want and root != null:
		clear()
	if root == null:
		return
	_time += delta
	# The bulbs come on at dusk, at 20:00 at the latest, sweeping along the street.
	var lit := DayNightCycle.night_factor > 0.3 or Carnival.is_on()
	if lit and not _lit:
		_sweep = 0.0
	_lit = lit
	_power = move_toward(_power, 1.0 if lit else 0.0, delta * 0.8)
	_sweep = minf(_sweep + delta / SWEEP_SECONDS, 2.0)
	for m: ShaderMaterial in [_bulb_mat, _lantern_mat]:
		m.set_shader_parameter("power", _power)
		m.set_shader_parameter("sweep", _sweep)
	for l in _lights:
		l.light_energy = float(l.get_meta(&"energy")) * _power
		l.visible = l.get_meta(&"on") and _power > 0.01
	_wheel.rotation.z += WHEEL_SPEED * delta
	_level_gondolas()
	_carousel.rotation.y += CAROUSEL_SPEED * delta * (0.4 + 0.6 * _power)
	_balloons.rotation = Vector3(sin(_time * 0.9) * 0.05, 0.0, sin(_time * 0.7 + 1.0) * 0.06)
	_update_fireworks(delta)


## Shells: a show when the fun starts, a big finale in the last twenty minutes, and now
## and then one in between.
func _update_fireworks(delta: float) -> void:
	if not Carnival.is_on():
		return
	_show_left -= delta
	_next_shell -= delta
	if _next_shell > 0.0:
		return
	var finale := GameClock.minute >= Carnival.END_MINUTE - 20
	if _show_left > 0.0:
		_next_shell = randf_range(0.45, 1.1)
	elif finale:
		_next_shell = randf_range(0.3, 0.8)
	else:
		_next_shell = randf_range(6.0, 12.0)
	fireworks.launch()


func _on_began() -> void:
	_show_left = 24.0
	_next_shell = 0.8


## The fireworks' show is on (the opening one, or the finale): the crowd claps.
func show_on() -> bool:
	return root != null and Carnival.is_on() and (_show_left > 0.0 or GameClock.minute >= Carnival.END_MINUTE - 20)


# --- Building ----------------------------------------------------------------------------

func build() -> void:
	if root != null or building:
		return
	building = true
	_gen += 1
	var gen := _gen
	build_ms = 0.0
	var t0 := Time.get_ticks_usec()
	root = Node3D.new()
	root.name = "Dressing"
	add_child(root)
	_sets = {"street": [[], [], []], "lanterns": [[], [], []], "wheel": [[], [], []], "carousel": [[], [], []]}
	_mb = MeshBuilder.new()
	_wires = MeshBuilder.new()
	_cols = []
	_gondolas.clear()
	_lights.clear()
	_bulb_mat = _material(BULB_ENERGY, 0.4)
	_lantern_mat = _material(LANTERN_ENERGY, 0.75)
	# A few parts a frame, so the evening doesn't stutter as the town dresses up.
	var steps: Array[Callable] = [_street, _facades, _arch, _plaza, _stalls, _ferris_wheel, _carousel_ride, _finish_meshes,
			_finish]
	for step in steps:
		step.call()
		build_ms = maxf(build_ms, (Time.get_ticks_usec() - t0) / 1000.0)
		print_verbose("TownCarnival: %s %.1f ms" % [step.get_method(), (Time.get_ticks_usec() - t0) / 1000.0])
		await get_tree().process_frame
		if not is_inside_tree() or gen != _gen:
			return
		t0 = Time.get_ticks_usec()
	building = false


## The props' and the wires' meshes.
func _finish_meshes() -> void:
	_mesh("CarnivalProps", _mb, true, 260.0)
	_mesh("CarnivalWires", _wires, false, 160.0)


## The last step: the bulbs' multimeshes, the colliders, the real lights and the fireworks.
func _finish() -> void:
	_real_lights()
	_instances("street", _bulb_mesh(0.055), root, 320.0)
	_instances("lanterns", _lantern_mesh(), root, 200.0)
	_instances("wheel", _bulb_mesh(0.07), _wheel, 400.0)
	_instances("carousel", _bulb_mesh(0.05), _carousel, 220.0)
	if not _cols.is_empty():
		BuildingKit.collider(root, _cols)
	fireworks = CarnivalFireworks.new()
	fireworks.origin = Vector3(WHEEL.x, TerrainData.height(WHEEL.x, WHEEL.y), WHEEL.y - 6.0)
	root.add_child(fireworks)
	_power = 0.0
	_lit = false
	_sweep = 2.0
	_apply_quality()
	# Loaded into the middle of the fun: a short show all the same.
	if Carnival.is_on():
		_on_began()
	_mb = null
	_wires = null


## Takes tonight's dressing down.
func clear() -> void:
	building = false
	_gen += 1
	if root:
		root.queue_free()
	root = null
	fireworks = null
	_wheel = null
	_carousel = null
	_balloons = null
	_gondolas.clear()
	_lights.clear()
	_sets.clear()


## How many bulbs and lanterns shine tonight (tests read it).
func bulb_count() -> int:
	var n := 0
	for key: String in _sets:
		n += (_sets[key][0] as Array).size()
	return n


func _apply_quality() -> void:
	var q: int = Settings.quality
	for l in _lights:
		l.set_meta(&"on", int(l.get_meta(&"rank")) < [3, 5, 7, 7][q])


func _material(energy: float, glass: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/carnival_bulb.gdshader")
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("glass", glass)
	m.set_shader_parameter("power", 0.0)
	return m


func _bulb_mesh(radius: float) -> Mesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.4
	s.radial_segments = 10 if radius < 0.06 else 8
	s.rings = 5 if radius < 0.06 else 4
	s.material = _bulb_mat
	return s


func _lantern_mesh() -> Mesh:
	var s := SphereMesh.new()
	s.radius = 0.19
	s.height = 0.42
	s.radial_segments = 16
	s.rings = 8
	s.material = _lantern_mat
	return s


func _mesh(node_name: String, mb: MeshBuilder, shadows: bool, range_end: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mb.build()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.visibility_range_end = range_end
	root.add_child(mi)
	return mi


func _instances(set_name: String, mesh: Mesh, parent: Node3D, range_end: float) -> void:
	var d: Array = _sets[set_name]
	var pos: Array = d[0]
	if pos.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = pos.size()
	for i in pos.size():
		mm.set_instance_transform(i, Transform3D(Basis(), pos[i]))
		mm.set_instance_color(i, d[1][i])
		mm.set_instance_custom_data(i, d[2][i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Bulbs_" + set_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mmi.visibility_range_end = range_end
	parent.add_child(mmi)


## One bulb (or lantern) of a set: its colour (sRGB), phase and pattern; bulbs of the
## street sets come on in a sweep from the west end of town.
func _bulb(set_name: String, at: Vector3, col: Color, phase: float, mode := 0) -> void:
	var d: Array = _sets[set_name]
	(d[0] as Array).append(at)
	(d[1] as Array).append(col.srgb_to_linear())
	var order := clampf((at.x - 184.0) / 100.0, 0.0, 1.0) if set_name in ["street", "lanterns"] else 0.0
	(d[2] as Array).append(Color(phase, float(mode), order, 0.0))


static func _sag(a: Vector3, b: Vector3, sag: float, t: float) -> Vector3:
	return a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)


## A sagging wire from `a` to `b` with bulbs every `spacing` metres (colours cycling
## through `palette`), and a paper lantern every `lantern_every` bulbs (0: none).
func _string(a: Vector3, b: Vector3, sag: float, spacing := 0.45, palette: Array[Color] = PALETTE, mode := 0,
		lantern_every := 0, set_name := "street") -> void:
	var length := a.distance_to(b)
	var n := maxi(int(length / spacing), 2)
	var pts: Array[Vector3] = []
	var rs: Array[float] = []
	var segs := clampi(int(length / 1.5), 4, 24)
	for i in segs + 1:
		pts.append(_sag(a, b, sag, float(i) / segs))
		rs.append(0.009)
	_wires.loft(&"carn_wire", pts, rs, 4, Color(0.05, 0.05, 0.05), false)
	var seed_offset := absi(int(a.x * 13.0 + a.z * 7.0))
	for i in range(1, n):
		var t := float(i) / n
		var p := _sag(a, b, sag, t) + Vector3(0, -0.07, 0)
		var col: Color = palette[(i + seed_offset) % palette.size()]
		_bulb(set_name, p, col, float(i) / n, mode)
		if lantern_every > 0 and i % lantern_every == floori(lantern_every * 0.5):
			var lp := p + Vector3(0, -0.42, 0)
			_wires.cylinder_between(&"carn_wire", p, lp + Vector3(0, 0.2, 0), 0.006, 0.006, 3, Color(0.05, 0.05, 0.05), false, false)
			_bulb("lanterns", lp, LANTERN_COLORS[(floori(float(i) / lantern_every) + seed_offset) % LANTERN_COLORS.size()], randf(), 0)


## Pennants from `a` to `b` on their cord.
func _bunting(a: Vector3, b: Vector3, sag: float) -> void:
	var colors: Array[Color] = [Color(0.85, 0.12, 0.14), Color(0.98, 0.78, 0.12), Color(0.1, 0.45, 0.8),
		Color(0.96, 0.95, 0.9), Color(0.1, 0.6, 0.3), Color(0.9, 0.35, 0.6)]
	var pts: Array[Vector3] = []
	var rs: Array[float] = []
	for i in 13:
		pts.append(_sag(a, b, sag, i / 12.0))
		rs.append(0.006)
	_wires.loft(&"carn_wire", pts, rs, 4, Color(0.2, 0.2, 0.2), false)
	var length := a.distance_to(b)
	var n := int(length / 0.5)
	var dir := (b - a).normalized()
	for i in range(1, n):
		var t := float(i) / n
		var p := _sag(a, b, sag, t)
		var q := _sag(a, b, sag, minf(t + 0.3 / length, 1.0))
		var tip := (p + q) * 0.5 + Vector3(0, -0.34, 0) + dir.cross(Vector3.UP) * 0.03 * sin(i * 1.7)
		var col: Color = colors[i % colors.size()]
		_mb.tri(&"cloth", p, q, tip, col)
		_mb.tri(&"cloth", q, p, tip, col)


func _h(x: float, z: float) -> float:
	return TerrainData.height(x, z)


# --- The main street -------------------------------------------------------------------------

func _street() -> void:
	var y_station := _h(Town.STATION.get_center().x, Town.STATION.get_center().y) + 0.06 + 5.4
	var anchors: Array = []
	for x in LAMPS_N:
		anchors.append(Vector3(x, _h(x, 14.0) + 0.15 + 4.95, 14.0))
	for x in CANOPY_HOOKS:
		anchors.append(Vector3(x, y_station + 0.05, Town.CANOPY.position.y - 0.08))
	for x in LAMPS_S:
		anchors.append(Vector3(x, _h(x, 26.1) + 0.15 + 4.95, 26.1))
	anchors.sort_custom(func(p: Vector3, q: Vector3) -> bool: return p.x < q.x)
	# Zig-zag over the street, a lantern every few bulbs.
	for i in anchors.size() - 1:
		var a: Vector3 = anchors[i]
		var b: Vector3 = anchors[i + 1]
		if (a.z < 20.0) == (b.z < 20.0):
			continue
		_string(a, b, 0.85, 0.42, PALETTE, 0, 7)
	# Bunting from lamp to lamp along both pavements, under the bulbs.
	for i in LAMPS_N.size() - 1:
		var a := Vector3(LAMPS_N[i], _h(LAMPS_N[i], 14.0) + 4.2, 14.0)
		var b := Vector3(LAMPS_N[i + 1], _h(LAMPS_N[i + 1], 14.0) + 4.2, 14.0)
		_bunting(a, b, 0.55)
	for i in LAMPS_S.size() - 1:
		var a := Vector3(LAMPS_S[i], _h(LAMPS_S[i], 26.1) + 4.2, 26.1)
		var b := Vector3(LAMPS_S[i + 1], _h(LAMPS_S[i + 1], 26.1) + 4.2, 26.1)
		_bunting(a, b, 0.55)


## Bulbs scalloped along the market's cornice and the station's canopy fascia, and over
## the Animal Market's gate.
func _facades() -> void:
	var m := Town.MARKET
	var ym := _h(m.get_center().x, m.get_center().y) + 0.15 + 4.98
	var zm := m.end.y + 0.32
	var x := m.position.x - 0.2
	while x < m.end.x + 0.1:
		var nx := minf(x + 2.05, m.end.x + 0.2)
		_string(Vector3(x, ym, zm), Vector3(nx, ym, zm), 0.28, 0.3, PALETTE, 1)
		x = nx
	var c := Town.CANOPY
	var yc := _h(Town.STATION.get_center().x, Town.STATION.get_center().y) + 0.06 + 5.4 - 0.02
	x = c.position.x
	while x < c.end.x - 0.1:
		var nx := minf(x + 2.4, c.end.x)
		_string(Vector3(x, yc, c.position.y - 0.08), Vector3(nx, yc, c.position.y - 0.08), 0.3, 0.3, PALETTE, 1)
		x = nx
	# The Animal Market's gate: along the top beam and down the posts.
	var lane := Town.MARKET_LANE
	var gz := lane.position.y + 0.2 - 0.18
	var xa := lane.position.x - 0.15
	var xb := lane.end.x + 0.15
	var gy := _h((xa + xb) * 0.5, gz + 0.18)
	var top := gy + 4.3 + 0.16
	var n := int((xb - xa + 1.0) / 0.28)
	for i in n + 1:
		var px := xa - 0.5 + (xb - xa + 1.0) * i / n
		_bulb("street", Vector3(px, top, gz), PALETTE[i % PALETTE.size()], float(i) / n, 1)
	for px: float in [xa, xb]:
		for k in 12:
			_bulb("street", Vector3(px, gy + 0.7 + k * 0.3, gz - 0.02), WARM, k / 12.0, 1)


# --- The fairground --------------------------------------------------------------------------

## The arch over the walk from the street to the fair: striped posts, an arc of bulbs and
## a lit board.
func _arch() -> void:
	var y := _h((ARCH_X.x + ARCH_X.y) * 0.5, ARCH_Z)
	var red := Color(0.78, 0.1, 0.12)
	var cream := Color(0.95, 0.9, 0.78)
	var post_h := 3.7
	for px: float in [ARCH_X.x, ARCH_X.y]:
		for k in 8:
			_mb.box_at(&"carn_paint", Vector3(px, y + post_h * (k + 0.5) / 8.0, ARCH_Z), Vector3(0.24, post_h / 8.0, 0.24),
					red if k % 2 == 0 else cream)
		_mb.box_at(&"carn_paint", Vector3(px, y + 0.1, ARCH_Z), Vector3(0.44, 0.2, 0.44), Color(0.25, 0.25, 0.27))
		_cols.append([Vector3(px, y + post_h * 0.5, ARCH_Z), Vector3(0.3, post_h, 0.3), 0.0])
		for k in 12:
			_bulb("street", Vector3(px, y + 0.3 + k * 0.3, ARCH_Z + 0.16), WARM, k / 12.0, 1)
	# The arc: a band of boxes over the posts, bulbs along its front.
	var cx := (ARCH_X.x + ARCH_X.y) * 0.5
	var r := (ARCH_X.y - ARCH_X.x) * 0.5
	var base := y + post_h
	var steps := 20
	for i in steps:
		var a0 := PI * float(i) / steps
		var a1 := PI * float(i + 1) / steps
		var p0 := Vector3(cx + cos(a0) * r, base + sin(a0) * r * 0.62, ARCH_Z)
		var p1 := Vector3(cx + cos(a1) * r, base + sin(a1) * r * 0.62, ARCH_Z)
		_mb.cylinder_between(&"carn_paint", p0, p1, 0.13, 0.13, 6, red if i % 2 == 0 else cream, false)
	var nb := 34
	for i in nb + 1:
		var a := PI * float(i) / nb
		var p := Vector3(cx + cos(a) * r, base + sin(a) * r * 0.62, ARCH_Z + 0.17)
		_bulb("street", p, PALETTE[i % PALETTE.size()], float(i) / nb, 1)
		_bulb("street", p - Vector3(0, 0, 0.34), PALETTE[(i + 3) % PALETTE.size()], float(i) / nb, 1)
	# The board under the arc, lit, both ways.
	var board := Vector3(cx, base + 0.62, ARCH_Z)
	_mb.box_at(&"carn_paint", board, Vector3(3.9, 0.78, 0.08), Color(0.1, 0.12, 0.3))
	_mb.box_at(&"carn_paint", board + Vector3(0, 0.42, 0), Vector3(4.0, 0.06, 0.12), Color(0.85, 0.66, 0.2))
	_mb.box_at(&"carn_paint", board - Vector3(0, 0.42, 0), Vector3(4.0, 0.06, 0.12), Color(0.85, 0.66, 0.2))
	BuildingKit.sign(root, "KARNAVAL", board + Vector3(0, 0.0, 0.05), 0.0, 150, Color(1.0, 0.86, 0.45))
	BuildingKit.sign(root, "KARNAVAL", board + Vector3(0, 0.0, -0.05), PI, 150, Color(1.0, 0.86, 0.45))


## The plaza: a tall mast in the middle with strings of bulbs to a ring of masts round
## it, and the ring joined up; a walk of bulbs and bunting from the arch.
func _plaza() -> void:
	var cy := _h(PLAZA.x, PLAZA.y)
	var top := Vector3(PLAZA.x, cy + 8.6, PLAZA.y)
	_mast(Vector3(PLAZA.x, cy, PLAZA.y), 8.8, 0.11)
	for k in 10:
		var a := TAU * k / 10.0
		_bulb("street", top + Vector3(cos(a) * 0.3, 0.25, sin(a) * 0.3), PALETTE[k % PALETTE.size()], k / 10.0, 1)
	var ring: Array[Vector3] = []
	for k in 8:
		var a := deg_to_rad(22.5 + 45.0 * k)
		var px := PLAZA.x + cos(a) * PLAZA_R
		var pz := PLAZA.y + sin(a) * PLAZA_R
		var gy := _h(px, pz)
		_mast(Vector3(px, gy, pz), 4.3, 0.07)
		ring.append(Vector3(px, gy + 4.2, pz))
	for k in 8:
		_string(top, ring[k], 0.45, 0.42, PALETTE, 1)
		_string(ring[k], ring[(k + 1) % 8], 0.6, 0.45, PALETTE, 0, 6)
	# The walk: from the arch's posts over two masts halfway to the plaza's front masts
	# (at 67.5 and 112.5 degrees: ring[1], ring[2]), bunting across it.
	var ya := _h((ARCH_X.x + ARCH_X.y) * 0.5, ARCH_Z) + 3.6
	var mid_l := Vector3(224.9, _h(224.9, -1.0), -1.0)
	var mid_r := Vector3(231.2, _h(231.2, -1.0), -1.0)
	_mast(mid_l, 4.3, 0.07)
	_mast(mid_r, 4.3, 0.07)
	_string(Vector3(ARCH_X.x, ya, ARCH_Z), mid_l + Vector3(0, 4.2, 0), 0.5, 0.42, PALETTE, 1)
	_string(Vector3(ARCH_X.y, ya, ARCH_Z), mid_r + Vector3(0, 4.2, 0), 0.5, 0.42, PALETTE, 1)
	_string(mid_l + Vector3(0, 4.2, 0), ring[2], 0.5, 0.42, PALETTE, 1)
	_string(mid_r + Vector3(0, 4.2, 0), ring[1], 0.5, 0.42, PALETTE, 1)
	_string(mid_l + Vector3(0, 4.2, 0), mid_r + Vector3(0, 4.2, 0), 0.5, 0.45, PALETTE, 0, 5)
	_bunting(mid_l + Vector3(0, 3.6, 0), mid_r + Vector3(0, 3.6, 0), 0.4)
	_bunting(Vector3(ARCH_X.x, ya - 0.4, ARCH_Z), mid_r + Vector3(0, 3.5, 0), 0.8)
	_bunting(Vector3(ARCH_X.y, ya - 0.4, ARCH_Z), mid_l + Vector3(0, 3.5, 0), 0.8)


## A slim white mast on a small footing.
func _mast(base: Vector3, height: float, radius: float) -> void:
	_mb.cylinder(&"carn_paint", Transform3D(Basis(), base), radius * 1.15, radius, height, 8, Color(0.9, 0.9, 0.88))
	_mb.cylinder(&"carn_paint", Transform3D(Basis(), base), radius * 2.4, radius * 2.2, 0.18, 8, Color(0.35, 0.35, 0.36))
	_mb.sphere(&"carn_paint", Transform3D(Basis(), base + Vector3(0, height, 0)), Vector3.ONE * radius * 1.4, 8, 4, Color(0.85, 0.66, 0.2))


## The stalls round the plaza, facing its middle: cotton candy, roasted corn, and the
## balloon seller's cart.
func _stalls() -> void:
	var spots := {"candy": 135.0, "corn": 45.0, "balloons": 180.0}
	for kind: String in spots:
		var a := deg_to_rad(float(spots[kind]))
		var p := Vector2(PLAZA.x + cos(a) * 7.0, PLAZA.y + sin(a) * 7.0)
		var to_mid := PLAZA - p
		var yaw := atan2(to_mid.x, to_mid.y)
		var base := Vector3(p.x, _h(p.x, p.y), p.y)
		var xf := Transform3D(Basis(Vector3.UP, yaw), base)
		match kind:
			"candy":
				_stall(xf, [Color(0.95, 0.45, 0.66), Color(0.97, 0.94, 0.9)], "PAMUK ŞEKER")
				_candy(xf)
			"corn":
				_stall(xf, [Color(0.86, 0.2, 0.14), Color(0.98, 0.8, 0.2)], "KÖZ MISIR")
				_corn(xf)
			"balloons":
				_balloon_cart(xf)


## A timber stall: posts, counter, back shelf and a striped awning sloping to the front,
## its name on a board over it and a string of warm bulbs along the awning's edge.
func _stall(xf: Transform3D, stripes: Array, title: String) -> void:
	var w := 2.8
	var d := 1.5
	var wood := Color(0.5, 0.42, 0.34)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var h := 2.75 if sz < 0.0 else 2.4
			_mb.box(&"wood", xf * Transform3D(Basis(), Vector3(sx * (w * 0.5 - 0.08), h * 0.5, sz * (d * 0.5 - 0.08))),
					Vector3(0.12, h, 0.12), wood.darkened(0.15))
	_mb.box(&"carn_paint", xf * Transform3D(Basis(), Vector3(0, 0.5, d * 0.5 - 0.1)), Vector3(w - 0.1, 1.0, 0.08), stripes[0].darkened(0.25))
	_mb.box(&"wood", xf * Transform3D(Basis(), Vector3(0, 1.02, d * 0.5 - 0.22)), Vector3(w + 0.1, 0.07, 0.56), wood.lightened(0.1))
	_mb.box(&"wood", xf * Transform3D(Basis(), Vector3(0, 1.25, -d * 0.5 + 0.1)), Vector3(w - 0.1, 2.5, 0.06), wood.darkened(0.05))
	var n := 8
	for i in n:
		var x0 := -w * 0.5 - 0.1 + (w + 0.2) * i / n
		var x1 := -w * 0.5 - 0.1 + (w + 0.2) * (i + 1) / n
		var back := -d * 0.5 - 0.05
		var front := d * 0.5 + 0.45
		_mb.quad2(&"cloth", xf * Vector3(x0, 2.42, front), xf * Vector3(x1, 2.42, front), xf * Vector3(x1, 2.8, back),
				xf * Vector3(x0, 2.8, back), stripes[i % 2])
		# The valance: a scallop at the front edge.
		_mb.quad2(&"cloth", xf * Vector3(x0, 2.18, front + 0.01), xf * Vector3(x1, 2.18, front + 0.01),
				xf * Vector3(x1, 2.42, front), xf * Vector3(x0, 2.42, front), stripes[i % 2])
	_string(xf * Vector3(-w * 0.5 - 0.1, 2.16, d * 0.5 + 0.48), xf * Vector3(w * 0.5 + 0.1, 2.16, d * 0.5 + 0.48), 0.12, 0.25,
			Array([WARM, Color(1.0, 0.62, 0.22)], TYPE_COLOR, &"", null), 0)
	var board := xf * Vector3(0, 3.18, -d * 0.5 + 0.1)
	_mb.box(&"carn_paint", xf * Transform3D(Basis(), Vector3(0, 3.18, -d * 0.5 + 0.1)), Vector3(2.3, 0.56, 0.06), Color(0.12, 0.14, 0.32))
	var yaw := xf.basis.get_euler().y
	BuildingKit.sign(root, title, board + xf.basis * Vector3(0, 0, 0.04), yaw, 90, Color(1.0, 0.9, 0.62))
	_cols.append([xf * Vector3(0, 1.2, 0), Vector3(w, 2.4, d), yaw])


## Cotton candy: the spinning bowl on the counter, and pink and blue clouds on sticks in
## a rack.
func _candy(xf: Transform3D) -> void:
	_mb.cylinder(&"steel", xf * Transform3D(Basis(), Vector3(-0.7, 1.06, 0.45)), 0.3, 0.36, 0.32, 16, Color(0.75, 0.76, 0.78))
	_mb.cylinder(&"carn_paint", xf * Transform3D(Basis(), Vector3(-0.7, 1.08, 0.45)), 0.26, 0.26, 0.26, 12, Color(0.98, 0.8, 0.88))
	var colors := [Color(1.0, 0.6, 0.8), Color(0.7, 0.85, 1.0), Color(1.0, 0.75, 0.88)]
	for i in 7:
		var p := Vector3(0.1 + i * 0.16, 1.45 + (i % 2) * 0.1, 0.35 - (i % 3) * 0.08)
		_mb.cylinder(&"wood", xf * Transform3D(Basis(), p - Vector3(0, 0.38, 0)), 0.008, 0.008, 0.36, 4, Color(0.8, 0.72, 0.6))
		_mb.sphere(&"cloth", xf * Transform3D(Basis(), p + Vector3(0, 0.1, 0)), Vector3(0.13, 0.16, 0.13), 8, 5, colors[i % 3])
	_mb.box(&"wood", xf * Transform3D(Basis(), Vector3(0.58, 1.1, 0.3)), Vector3(1.2, 0.08, 0.3), Color(0.45, 0.36, 0.28))


## Roasted corn: a charcoal grill glowing under the cobs, and a basket of more.
func _corn(xf: Transform3D) -> void:
	_mb.box(&"steel", xf * Transform3D(Basis(), Vector3(0, 1.12, 0.42)), Vector3(1.4, 0.2, 0.46), Color(0.12, 0.12, 0.12))
	_mb.box(&"glow", xf * Transform3D(Basis(), Vector3(0, 1.225, 0.42)), Vector3(1.3, 0.02, 0.38), Color(1.0, 0.36, 0.08))
	for i in 9:
		var p := Vector3(-0.56 + i * 0.14, 1.27, 0.42)
		var cob := xf * Transform3D(Basis(Vector3.UP, 0.1 * sin(i * 2.1)) * Basis(Vector3.RIGHT, PI * 0.5), p - Vector3(0, 0, 0.14))
		_mb.cylinder(&"veg", cob, 0.034, 0.028, 0.28, 8, Color(0.92, 0.7, 0.18).darkened(0.1 + 0.12 * (i % 3)))
	_mb.cylinder(&"straw", xf * Transform3D(Basis(), Vector3(0.95, 1.06, 0.3)), 0.2, 0.24, 0.22, 12, Color(0.7, 0.55, 0.3))
	for i in 5:
		var p := Vector3(0.85 + (i % 3) * 0.08, 1.3, 0.24 + floori(i / 3.0) * 0.1)
		_mb.cylinder(&"veg", xf * Transform3D(Basis(Vector3.FORWARD, 0.6 + i * 0.3), p), 0.03, 0.026, 0.22, 8, Color(0.95, 0.78, 0.25))


## The balloon seller's cart with a bunch of balloons swaying on their strings.
func _balloon_cart(xf: Transform3D) -> void:
	var blue := Color(0.15, 0.35, 0.7)
	_mb.box(&"carn_paint", xf * Transform3D(Basis(), Vector3(0, 0.7, 0)), Vector3(1.2, 0.5, 0.7), blue)
	_mb.box(&"carn_paint", xf * Transform3D(Basis(), Vector3(0, 0.97, 0)), Vector3(1.26, 0.05, 0.76), Color(0.95, 0.92, 0.85))
	for sx: float in [-0.5, 0.5]:
		_mb.cylinder(&"steel", xf * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(sx * 1.25, 0.24, 0.0)), 0.24, 0.24, 0.06, 14, Color(0.15, 0.15, 0.15))
	var pole := xf * Vector3(0.45, 0.95, 0.0)
	_mb.cylinder(&"steel", Transform3D(Basis(), pole), 0.02, 0.02, 1.1, 6, Color(0.7, 0.7, 0.72))
	_cols.append([xf * Vector3(0, 0.6, 0), Vector3(1.3, 1.2, 0.8), xf.basis.get_euler().y])
	# The balloons: their own node, so the bunch can sway.
	_balloons = Node3D.new()
	_balloons.position = pole + Vector3(0, 1.1, 0)
	root.add_child(_balloons)
	var bm := MeshBuilder.new()
	var colors := [Color(0.9, 0.12, 0.14), Color(0.98, 0.8, 0.1), Color(0.12, 0.45, 0.9), Color(0.1, 0.7, 0.35),
		Color(0.95, 0.4, 0.7), Color(0.6, 0.25, 0.8), Color(1.0, 0.55, 0.1)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.1, 0.55)
		var top := Vector3(cos(a) * r, rng.randf_range(1.0, 1.9), sin(a) * r)
		bm.cylinder_between(&"carn_wire", Vector3.ZERO, top - Vector3(0, 0.25, 0), 0.004, 0.004, 3, Color(0.9, 0.9, 0.9), false, false)
		bm.sphere(&"veg_gloss", Transform3D(Basis(), top), Vector3(0.2, 0.25, 0.2), 10, 6, colors[i % colors.size()])
	var mi := MeshInstance3D.new()
	mi.mesh = bm.build()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_balloons.add_child(mi)


## The Ferris wheel: a steel A-frame on a platform, the wheel (two rims, spokes and a hub)
## turning on its axle with twelve gondolas hanging level, bulbs round both rims and
## along the front spokes.
func _ferris_wheel() -> void:
	var gy := _h(WHEEL.x, WHEEL.y)
	var hub := Vector3(WHEEL.x, gy + HUB_H, WHEEL.y)
	var white := Color(0.92, 0.92, 0.9)
	# Platform and steps to the boarding point.
	_mb.box_at(&"concrete", Vector3(WHEEL.x, gy + 0.25, WHEEL.y), Vector3(12.4, 0.5, 5.0), Color(0.6, 0.6, 0.58))
	_mb.box_at(&"carn_paint", Vector3(WHEEL.x, gy + 0.52, WHEEL.y + 2.3), Vector3(12.4, 0.05, 0.4), Color(0.85, 0.66, 0.2))
	_cols.append([Vector3(WHEEL.x, gy + 0.25, WHEEL.y), Vector3(12.4, 0.5, 5.0), 0.0])
	# The A-frame's legs to both ends of the axle, and their braces.
	for sz: float in [-1.0, 1.0]:
		var axle := hub + Vector3(0, 0, sz * 1.05)
		for sx: float in [-1.0, 1.0]:
			var foot := Vector3(WHEEL.x + sx * 4.6, gy + 0.5, WHEEL.y + sz * 1.9)
			_mb.cylinder_between(&"carn_paint", foot, axle, 0.2, 0.14, 10, white)
			_bulb("street", foot.lerp(axle, 0.5), WARM, 0.0, 0)
			for k in 14:
				_bulb("street", foot.lerp(axle, (k + 0.5) / 14.0) + Vector3(0, 0, sz * 0.2), PALETTE[k % PALETTE.size()], k / 14.0, 1)
		var l := Vector3(WHEEL.x - 2.3, gy + 5.4, WHEEL.y + sz * 1.48)
		var r := Vector3(WHEEL.x + 2.3, gy + 5.4, WHEEL.y + sz * 1.48)
		_mb.cylinder_between(&"carn_paint", l, r, 0.09, 0.09, 8, white)
	_mb.cylinder_between(&"steel", hub + Vector3(0, 0, -1.2), hub + Vector3(0, 0, 1.2), 0.22, 0.22, 12, Color(0.4, 0.4, 0.42))
	_cols.append([Vector3(WHEEL.x, gy + 3.0, WHEEL.y), Vector3(9.5, 5.0, 4.0), 0.0])
	# The wheel itself, on its own node.
	_wheel = Node3D.new()
	_wheel.name = "FerrisWheel"
	_wheel.position = hub
	root.add_child(_wheel)
	var wm := MeshBuilder.new()
	var segs := 40
	for side: float in [-0.55, 0.55]:
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			for rr: float in [WHEEL_R, WHEEL_R - 0.7]:
				wm.cylinder_between(&"carn_paint", Vector3(cos(a0) * rr, sin(a0) * rr, side), Vector3(cos(a1) * rr, sin(a1) * rr, side),
						0.07, 0.07, 6, white, false, false)
			# Truss zig-zag between the outer and inner rims.
			wm.cylinder_between(&"carn_paint", Vector3(cos(a0) * WHEEL_R, sin(a0) * WHEEL_R, side),
					Vector3(cos(a1) * (WHEEL_R - 0.7), sin(a1) * (WHEEL_R - 0.7), side), 0.035, 0.035, 4, white, false, false)
		for k in GONDOLAS:
			var a := TAU * k / GONDOLAS
			wm.cylinder_between(&"carn_paint", Vector3(0, 0, side * 0.6), Vector3(cos(a) * (WHEEL_R - 0.7), sin(a) * (WHEEL_R - 0.7), side),
					0.06, 0.045, 6, white, false, false)
			wm.cylinder_between(&"carn_paint", Vector3(0, 0, side * 0.6), Vector3(cos(a + PI / GONDOLAS) * (WHEEL_R - 0.7), sin(a + PI / GONDOLAS) * (WHEEL_R - 0.7), side),
					0.035, 0.03, 4, white, false, false)
	wm.cylinder_between(&"carn_paint", Vector3(0, 0, -0.9), Vector3(0, 0, 0.9), 0.6, 0.6, 16, Color(0.85, 0.2, 0.2))
	for k in GONDOLAS:
		var a := TAU * k / GONDOLAS
		wm.cylinder_between(&"steel", Vector3(cos(a) * WHEEL_R, sin(a) * WHEEL_R, -0.62), Vector3(cos(a) * WHEEL_R, sin(a) * WHEEL_R, 0.62),
				0.05, 0.05, 6, Color(0.5, 0.5, 0.52))
	var wmi := MeshInstance3D.new()
	wmi.mesh = wm.build()
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	wmi.visibility_range_end = 400.0
	_wheel.add_child(wmi)
	# Bulbs: round both outer rims (a wave running round), along the front spokes.
	var nb := 96
	for i in nb:
		var a := TAU * i / nb
		for side: float in [-0.62, 0.62]:
			_bulb("wheel", Vector3(cos(a) * (WHEEL_R + 0.1), sin(a) * (WHEEL_R + 0.1), side),
					[Color(1.0, 0.35, 0.72), WARM, Color(1.0, 0.62, 0.22)][i % 3], float(i) / nb, 2)
	for k in GONDOLAS:
		var a := TAU * k / GONDOLAS
		for j in 12:
			var rr := 0.9 + (WHEEL_R - 1.6) * j / 11.0
			_bulb("wheel", Vector3(cos(a) * rr, sin(a) * rr, 0.66), [WARM, Color(0.35, 0.55, 1.0), Color(0.36, 1.0, 0.4)][k % 3],
					rr / WHEEL_R, 2)
	# Gondolas in four colours (a multimesh each), level as the wheel turns.
	var looks: Array[Color] = [Color(0.85, 0.15, 0.15), Color(0.95, 0.75, 0.15), Color(0.15, 0.4, 0.8), Color(0.15, 0.6, 0.35)]
	for c in looks:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _gondola_mesh(c)
		mm.instance_count = floori(float(GONDOLAS) / looks.size())
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mmi.visibility_range_end = 300.0
		mmi.custom_aabb = AABB(Vector3(-WHEEL_R - 1.5, -WHEEL_R - 2.5, -1.5), Vector3(WHEEL_R * 2.0 + 3.0, WHEEL_R * 2.0 + 4.0, 3.0))
		_wheel.add_child(mmi)
		_gondolas.append(mm)
	_level_gondolas()


## Each gondola hangs from its pin on the rim, level whatever the wheel's angle.
func _level_gondolas() -> void:
	var level := Basis(Vector3.BACK, -_wheel.rotation.z)
	for k in GONDOLAS:
		var a := TAU * k / GONDOLAS
		var mm := _gondolas[k % _gondolas.size()]
		mm.set_instance_transform(floori(float(k) / _gondolas.size()), Transform3D(level, Vector3(cos(a) * WHEEL_R, sin(a) * WHEEL_R, 0)))


## A gondola hanging from its pivot: a tub with a bench, four posts and a little roof.
static func _gondola_mesh(col: Color) -> Mesh:
	var mb := MeshBuilder.new()
	var cream := Color(0.95, 0.92, 0.85)
	mb.box_at(&"carn_paint", Vector3(0, -1.55, 0), Vector3(1.3, 0.55, 0.95), col)
	mb.box_at(&"carn_paint", Vector3(0, -1.26, 0), Vector3(1.36, 0.05, 1.0), cream)
	mb.box_at(&"carn_paint", Vector3(0, -1.5, -0.25), Vector3(1.1, 0.12, 0.35), cream.darkened(0.2))
	for sx: float in [-0.6, 0.6]:
		for sz: float in [-0.42, 0.42]:
			mb.cylinder_between(&"steel", Vector3(sx, -1.26, sz), Vector3(sx * 0.9, -0.45, sz * 0.9), 0.022, 0.022, 4, Color(0.7, 0.7, 0.72))
	mb.cylinder(&"carn_paint", Transform3D(Basis(), Vector3(0, -0.5, 0)), 0.85, 0.12, 0.4, 8, col.lightened(0.15))
	mb.cylinder_between(&"steel", Vector3(0, -0.1, 0), Vector3(0, -0.5, 0), 0.03, 0.03, 4, Color(0.5, 0.5, 0.52))
	return mb.build()


## The carousel: a low round plinth, and turning on it the deck, a mirrored column, a
## striped canopy with a gold valance, brass poles with horses on them, bulbs round the
## valance and up the canopy's seams.
func _carousel_ride() -> void:
	var gy := _h(CAROUSEL.x, CAROUSEL.y)
	var base := Vector3(CAROUSEL.x, gy, CAROUSEL.y)
	_mb.cylinder(&"concrete", Transform3D(Basis(), base - Vector3(0, 0.2, 0)), 5.5, 5.4, 0.45, 32, Color(0.62, 0.6, 0.57))
	var body := StaticBody3D.new()
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 5.5
	cyl.height = 4.0
	shape.shape = cyl
	shape.position = base + Vector3(0, 2.0, 0)
	body.add_child(shape)
	root.add_child(body)
	_carousel = Node3D.new()
	_carousel.name = "Carousel"
	_carousel.position = base + Vector3(0, 0.25, 0)
	root.add_child(_carousel)
	var cm := MeshBuilder.new()
	var gold := Color(0.88, 0.68, 0.22)
	var red := Color(0.8, 0.12, 0.14)
	var cream := Color(0.96, 0.92, 0.82)
	cm.cylinder(&"wood", Transform3D(), 5.0, 5.0, 0.2, 32, Color(0.55, 0.42, 0.3))
	cm.cylinder(&"carn_paint", Transform3D(Basis(), Vector3(0, -0.02, 0)), 5.05, 5.05, 0.16, 32, red, true, false)
	cm.cylinder(&"carn_paint", Transform3D(Basis(), Vector3(0, 0.2, 0)), 0.62, 0.55, 3.9, 12, cream)
	for k in 12:
		var a := TAU * k / 12.0
		cm.box(&"steel", Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.6, 2.2, sin(a) * 0.6)), Vector3(0.28, 2.6, 0.02), Color(0.8, 0.82, 0.85))
	# The canopy: sixteen gores, red and cream, and the valance hanging round its edge.
	var gores := 16
	var eave := 4.3
	var apex := 6.0
	for k in gores:
		var a0 := TAU * k / gores
		var a1 := TAU * (k + 1) / gores
		var p0 := Vector3(cos(a0) * 5.5, eave, sin(a0) * 5.5)
		var p1 := Vector3(cos(a1) * 5.5, eave, sin(a1) * 5.5)
		var col := red if k % 2 == 0 else cream
		cm.tri(&"cloth", p1, p0, Vector3(0, apex, 0), col)
		cm.tri(&"cloth", p0, p1, Vector3(0, apex, 0), col.darkened(0.3))
		var mid := (p0 + p1) * 0.5 + Vector3(0, -0.5, 0) * 1.0
		cm.quad2(&"cloth", p0 + Vector3(0, -0.3, 0), p1 + Vector3(0, -0.3, 0), p1, p0, gold)
		cm.tri(&"cloth", p0 + Vector3(0, -0.3, 0), mid, p1 + Vector3(0, -0.3, 0), gold)
		cm.tri(&"cloth", p1 + Vector3(0, -0.3, 0), mid, p0 + Vector3(0, -0.3, 0), gold)
	cm.sphere(&"carn_paint", Transform3D(Basis(), Vector3(0, apex + 0.15, 0)), Vector3.ONE * 0.22, 8, 5, gold)
	cm.cylinder(&"steel", Transform3D(Basis(), Vector3(0, apex + 0.3, 0)), 0.02, 0.02, 0.8, 4, Color(0.7, 0.7, 0.7))
	cm.tri(&"cloth", Vector3(0, apex + 1.1, 0), Vector3(0, apex + 0.8, 0), Vector3(0.5, apex + 0.95, 0), red)
	cm.tri(&"cloth", Vector3(0, apex + 0.8, 0), Vector3(0, apex + 1.1, 0), Vector3(0.5, apex + 0.95, 0), red)
	# Poles and horses: eight outside, eight inside.
	var horse_colors := [Color(0.96, 0.94, 0.9), Color(0.55, 0.36, 0.22), Color(0.2, 0.18, 0.17), Color(0.9, 0.85, 0.75)]
	for ring_i in 2:
		var rr := 4.0 if ring_i == 0 else 2.65
		for k in 8:
			var a := TAU * (k + 0.5 * ring_i) / 8.0
			var p := Vector3(cos(a) * rr, 0.2, sin(a) * rr)
			var roof_y := eave + (apex - eave) * (1.0 - rr / 5.5)
			cm.cylinder(&"steel", Transform3D(Basis(), p), 0.035, 0.035, roof_y - 0.2, 6, gold)
			_horse(cm, p + Vector3(0, 1.05 + 0.25 * ((k + ring_i) % 2), 0), a + PI * 0.5, horse_colors[(k + ring_i) % 4])
	var mi := MeshInstance3D.new()
	mi.mesh = cm.build()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.visibility_range_end = 260.0
	_carousel.add_child(mi)
	for k in 48:
		var a := TAU * k / 48.0
		_bulb("carousel", Vector3(cos(a) * 5.58, eave - 0.3, sin(a) * 5.58), [WARM, Color(1.0, 0.62, 0.22)][k % 2], k / 48.0, 1)
	for k in gores:
		var a := TAU * k / gores
		for j in 5:
			var t := (j + 0.5) / 5.0
			var p := Vector3(cos(a) * 5.5, eave, sin(a) * 5.5).lerp(Vector3(0, apex, 0), t * 0.85)
			_bulb("carousel", p + Vector3(0, 0.06, 0), PALETTE[(k + j) % PALETTE.size()], t, 0)
	for k in 12:
		var a := TAU * k / 12.0
		_bulb("carousel", Vector3(cos(a) * 0.66, 4.0, sin(a) * 0.66), WARM, k / 12.0, 0)


## A carousel horse facing along `yaw` (its body along local x): body, neck and head,
## legs in a gallop, a saddle.
static func _horse(mb: MeshBuilder, at: Vector3, yaw: float, col: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	var xf := Transform3D(b, at)
	var saddle := Color(0.75, 0.12, 0.14)
	mb.sphere(&"carn_paint", xf * Transform3D(Basis(), Vector3.ZERO), Vector3(0.5, 0.2, 0.17), 10, 6, col)
	mb.cylinder_between(&"carn_paint", xf * Vector3(0.35, 0.05, 0), xf * Vector3(0.55, 0.42, 0), 0.11, 0.08, 8, col)
	mb.sphere(&"carn_paint", xf * Transform3D(Basis(Vector3.BACK, -0.5), Vector3(0.66, 0.46, 0)), Vector3(0.18, 0.08, 0.075), 8, 5, col)
	mb.box(&"carn_paint", xf * Transform3D(Basis(), Vector3(-0.02, 0.19, 0)), Vector3(0.3, 0.05, 0.36), saddle)
	for leg: Array in [[0.3, 0.9], [0.22, 0.4], [-0.3, -0.6], [-0.36, -0.2]]:
		var hip := Vector3(leg[0], -0.08, 0.08 if leg[0] > 0.25 or leg[0] < -0.33 else -0.08)
		var hoof := hip + Vector3(sin(leg[1]) * 0.42, -cos(leg[1]) * 0.42, 0)
		mb.cylinder_between(&"carn_paint", xf * hip, xf * hoof, 0.04, 0.03, 5, col)
	mb.cylinder_between(&"carn_paint", xf * Vector3(-0.48, 0.05, 0), xf * Vector3(-0.72, -0.3, 0), 0.05, 0.02, 5, col.darkened(0.4))


## The few real lights: warm and coloured pools on the street, the plaza, the wheel's
## foot, the carousel and the arch. `rank` orders them for the quality presets.
func _real_lights() -> void:
	var specs := [
		[Vector3(232.0, 5.2, 20.0), Color(1.0, 0.55, 0.3), 1.3, 12.0],
		[Vector3(PLAZA.x, 5.5, PLAZA.y), Color(1.0, 0.72, 0.45), 3.0, 18.0],
		[Vector3(WHEEL.x, 3.5, WHEEL.y + 3.5), Color(1.0, 0.4, 0.7), 2.6, 16.0],
		[Vector3(204.0, 5.2, 20.0), Color(1.0, 0.45, 0.55), 1.2, 12.0],
		[Vector3(260.0, 5.2, 20.0), Color(1.0, 0.62, 0.35), 1.2, 12.0],
		[Vector3(CAROUSEL.x, 3.6, CAROUSEL.y), Color(1.0, 0.75, 0.42), 1.3, 10.0],
		[Vector3((ARCH_X.x + ARCH_X.y) * 0.5, 4.0, ARCH_Z + 1.2), Color(1.0, 0.5, 0.65), 1.1, 9.0],
	]
	for i in specs.size():
		var s: Array = specs[i]
		var p: Vector3 = s[0]
		var l := OmniLight3D.new()
		l.position = Vector3(p.x, _h(p.x, p.z) + p.y, p.z)
		l.light_color = s[1]
		l.omni_range = s[3]
		l.omni_attenuation = 1.2
		l.shadow_enabled = false
		l.light_energy = 0.0
		l.visible = false
		l.set_meta(&"energy", s[2])
		l.set_meta(&"rank", i)
		l.set_meta(&"on", true)
		root.add_child(l)
		_lights.append(l)
