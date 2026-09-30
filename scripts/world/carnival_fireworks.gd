class_name CarnivalFireworks
extends Node3D
## Fireworks over Yeşilova's fairground on a carnival night (TownCarnival asks for
## shells): a glowing rocket climbs from behind the fair, bursts into a sphere of sparks
## in one or two colours that fall and fade, a flash lights the town for a moment (not on
## LOW) and the bang arrives a moment later, as far away as the burst was (sound travels
## at 343 m/s), sometimes with a crackle of glitter after it. A small pool of CPU
## emitters (a few hundred sparks at most) is reused; LOW throws fewer sparks.

const POOL := 6
const SPARKS: Array[int] = [70, 110, 150, 150]
const RISE := 1.15
const COLORS: Array[Color] = [Color("ff4d6d"), Color("ffd166"), Color("06d6a0"), Color("4cc9f0"),
	Color("c77dff"), Color("ff9f1c"), Color("f1faee")]

## Where rockets go up from (the green behind the fair) and how widely they spread.
var origin := Vector3.ZERO
var spread := Vector2(26.0, 14.0)

var _bursts: Array[CPUParticles3D] = []
var _next := 0
var _rockets: Array[MeshInstance3D] = []
var _flash: OmniLight3D
var _spark_mat: ShaderMaterial
var _rocket_mat: StandardMaterial3D


func _ready() -> void:
	_spark_mat = ShaderMaterial.new()
	_spark_mat.shader = load("res://shaders/carnival_spark.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	quad.material = _spark_mat
	for i in POOL:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.emitting = false
		p.explosiveness = 0.96
		p.lifetime = 2.2
		p.amount = SPARKS[Settings.quality]
		p.mesh = quad
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.direction = Vector3.UP
		p.spread = 180.0
		p.initial_velocity_min = 10.0
		p.initial_velocity_max = 15.0
		p.gravity = Vector3(0, -3.2, 0)
		p.damping_min = 3.5
		p.damping_max = 5.0
		p.scale_amount_min = 0.7
		p.scale_amount_max = 1.3
		p.color_ramp = Gradient.new()
		_set_colors(p.color_ramp, COLORS[i % COLORS.size()], COLORS[(i + 3) % COLORS.size()])
		add_child(p)
		_bursts.append(p)
	_rocket_mat = StandardMaterial3D.new()
	_rocket_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rocket_mat.albedo_color = Color(1.0, 0.8, 0.5)
	_rocket_mat.emission_enabled = true
	var dot := SphereMesh.new()
	dot.radius = 0.12
	dot.height = 0.24
	dot.radial_segments = 6
	dot.rings = 3
	dot.material = _rocket_mat
	for i in 3:
		var r := MeshInstance3D.new()
		r.mesh = dot
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.visible = false
		add_child(r)
		_rockets.append(r)
	_flash = OmniLight3D.new()
	_flash.omni_range = 90.0
	_flash.omni_attenuation = 1.4
	_flash.shadow_enabled = false
	_flash.light_energy = 0.0
	_flash.visible = false
	add_child(_flash)


## White-hot at first, then `a`, turning towards `b` as the sparks fade.
static func _set_colors(g: Gradient, a: Color, b: Color) -> void:
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.97, 0.9, 1.0), Color(a.srgb_to_linear(), 1.0),
			Color(a.lerp(b, 0.6).srgb_to_linear(), 0.7), Color(b.srgb_to_linear(), 0.0)])


## Sends one rocket up; it bursts over the fair.
func launch() -> void:
	var at := origin + Vector3(randf_range(-spread.x, spread.x), randf_range(34.0, 52.0), randf_range(-spread.y, spread.y) * 0.6)
	var from := Vector3(at.x + randf_range(-3.0, 3.0), origin.y + 1.0, at.z + randf_range(-2.0, 2.0))
	var rocket: MeshInstance3D = null
	for r in _rockets:
		if not r.visible:
			rocket = r
			break
	if rocket:
		rocket.visible = true
		rocket.position = from
		var tw := create_tween()
		tw.tween_property(rocket, "position", at, RISE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			rocket.visible = false
			_burst(at))
	else:
		_burst(at)


func _burst(at: Vector3) -> void:
	var p := _bursts[_next]
	_next = (_next + 1) % _bursts.size()
	var a: Color = COLORS.pick_random()
	var b: Color = COLORS.pick_random()
	_set_colors(p.color_ramp, a, b)
	if p.amount != SPARKS[Settings.quality]:
		p.amount = SPARKS[Settings.quality]
	p.position = at
	p.restart()
	p.emitting = true
	if Settings.quality > Settings.Quality.LOW:
		_flash.position = at
		_flash.light_color = a.lerp(Color.WHITE, 0.4)
		_flash.visible = true
		var tw := create_tween()
		tw.tween_property(_flash, "light_energy", 5.0, 0.04)
		tw.tween_property(_flash, "light_energy", 0.0, 0.7).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void: _flash.visible = false)
	# The bang follows the flash by the time sound takes to get to the player.
	var player := Game.player as Node3D
	var delay := at.distance_to(player.global_position) / 343.0 if player else 0.2
	get_tree().create_timer(delay, false).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		Audio.play("firework", at, -1.0, 0.12, &"Effects", 40.0)
		if randf() < 0.45:
			get_tree().create_timer(0.35, false).timeout.connect(func() -> void:
				if is_inside_tree():
					Audio.play("firework_crackle", at, -6.0, 0.15, &"Effects", 40.0)))
