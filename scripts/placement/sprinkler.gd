class_name Sprinkler
extends PlacedObject
## Waters every tilled bed whose centre is within RADIUS each morning, spinning and
## spraying for a little while as it does (the first morning after it's put down too).

const RADIUS := 3.4
const SPRAY_SECONDS := 14.0

var _spray: CPUParticles3D
var _spraying := 0.0


func _setup() -> void:
	_spray = CPUParticles3D.new()
	_spray.amount = 220
	_spray.lifetime = 1.2
	_spray.position = Vector3(0, 0.36, 0)
	_spray.direction = Vector3(1, 0.7, 0)
	_spray.spread = 16.0
	_spray.initial_velocity_min = 3.4
	_spray.initial_velocity_max = 4.6
	_spray.gravity = Vector3(0, -9.8, 0)
	_spray.scale_amount_min = 0.5
	_spray.scale_amount_max = 1.0
	var drop := SphereMesh.new()
	drop.radius = 0.02
	drop.height = 0.05
	drop.radial_segments = 6
	drop.rings = 3
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.82, 0.9, 1.0, 0.55)
	mat.roughness = 0.05
	drop.material = mat
	_spray.mesh = drop
	_spray.local_coords = true
	_spray.emitting = false
	_spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Small clutter: kept out of the rain height map (layer 2) and out of GI.
	_spray.layers = 2
	_spray.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Turned with the spinner from _process.
	_spray.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_spray)
	Events.day_started.connect(_on_day_started)
	# Only runs while spraying.
	set_process(false)


func _on_day_started(_day: int) -> void:
	water()


## Soaks the beds in reach; returns how many.
func water() -> int:
	var n := 0
	for p: FarmPlot in get_tree().get_nodes_in_group(&"farm_plots"):
		var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if d <= RADIUS and p.soil == FarmPlot.Soil.TILLED:
			p.soak()
			n += 1
	_spraying = SPRAY_SECONDS
	set_process(true)
	return n


func info_prompt() -> String:
	return tr("ACTION_PICK_UP")


func _process(delta: float) -> void:
	if _spraying <= 0.0:
		_spray.emitting = false
		set_process(false)
		return
	_spraying -= delta
	if not _spray.emitting:
		_spray.emitting = true
	if _moving:
		_moving.rotation.y += delta * 6.0
		# The spray leaves along the spinner's arm.
		_spray.rotation.y = _moving.rotation.y
