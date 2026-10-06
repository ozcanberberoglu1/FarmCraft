class_name Decor
extends PlacedObject
## A decoration put down on the farm (PlaceableTable kind "decor"; bought at the town
## market, put down and picked back up like any placeable; models: IdentityModels):
##
##   flower_pot     a planter box whose flowers follow the seasons (tulips, geraniums,
##                  chrysanthemums, winter heather)
##   garden_bench   E sits down a moment: the view from the bench, turning slowly, for
##                  REST_SECONDS (any key gets up sooner), and a little energy back
##                  (REST_ENERGY, once every REST_EVERY game minutes: no second bed)
##   scarecrow      Grandpa's old shirt and straw hat on a stake (it only stands there)
##   flag_pole      a pennant in the farm's last paint colour, flying in the wind
##   bird_bath      a stone bowl of water with a sparrow on its rim
##
## Entry fields besides {id, pos, yaw}: rested_at (the bench: GameClock.total_minutes of
## the last rest that gave energy).

## The bench's rest: real seconds of the view, energy points given, and the game minutes
## before it gives any again.
const REST_SECONDS := 5.0
const REST_ENERGY := 8.0
const REST_EVERY := 120.0
## The screen name the rest holds the player with (not one of Game.PAUSING_UI: time goes on).
const REST_UI := &"bench_rest"
## The seated eye over the seat, and how far the view turns to each side (degrees).
const SEAT_EYE := 0.72
const VIEW_SWING := 16.0

const WAVE_SHADER := "
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec3 tone : source_color = vec3(0.6, 0.2, 0.15);
uniform float wind = 1.0;
void vertex() {
	float u = UV.x;
	float t = TIME * (2.2 + wind * 2.0);
	VERTEX.z += sin(u * 7.0 - t) * 0.07 * u * (0.5 + wind * 0.7) + sin(u * 3.1 - t * 0.6) * 0.05 * u;
	VERTEX.y -= u * u * 0.1 * (1.2 - min(wind, 1.0)) + sin(u * 5.0 - t * 0.8) * 0.015 * u;
}
void fragment() {
	float fold = 0.88 + 0.12 * sin(UV.x * 21.0 - TIME * 3.0);
	ALBEDO = tone * fold * (FRONT_FACING ? 1.0 : 0.85);
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
"

static var _wave: Shader

var _flowers: MeshInstance3D
var _pennant: MeshInstance3D
var _season := -1
var _rest_cam: Camera3D
var _rest_t := 0.0
var _resting := false


func _setup() -> void:
	set_process(false)
	match item_id:
		&"flower_pot":
			_flowers = MeshInstance3D.new()
			_flowers.name = "Flowers"
			add_child(_flowers)
			_bloom()
			Events.day_started.connect(func(_d: int) -> void: _bloom())
			Events.season_changed.connect(func(_s: int) -> void: _bloom())
		&"flag_pole":
			add_to_group(FarmIdentity.LISTENERS)
			_pennant = MeshInstance3D.new()
			_pennant.name = "Pennant"
			_pennant.mesh = IdentityModels.pennant_mesh()
			_pennant.position = Vector3(0.03, IdentityModels.POLE_H - 0.1 - IdentityModels.PENNANT.y * 0.5, 0)
			if _wave == null:
				_wave = Shader.new()
				_wave.code = WAVE_SHADER
			var m := ShaderMaterial.new()
			m.shader = _wave
			_pennant.material_override = m
			_pennant.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			add_child(_pennant)
			_fly()


## The planter's flowers for the season it is.
func _bloom() -> void:
	var season := GameClock.get_season()
	if _flowers == null or season == _season:
		return
	_season = season
	_flowers.mesh = IdentityModels.flowers_mesh(season)


## The season the planter's flowers are of (tests).
func flower_season() -> int:
	return _season


## The pennant in the farm's last paint colour.
func _fly() -> void:
	if _pennant == null:
		return
	var c := FarmIdentity.rgb(FarmIdentity.last_color())
	(_pennant.material_override as ShaderMaterial).set_shader_parameter("tone", Color(c.r, c.g, c.b))


## The colour id the pennant flies (tests).
func pennant_color() -> StringName:
	return FarmIdentity.last_color() if _pennant != null else &""


func farm_identity_changed(what: StringName) -> void:
	if what == &"paint":
		_fly()


# --- The bench ----------------------------------------------------------------------------------

func interact_title() -> String:
	return display_name()


func interact_prompt(_player: Node) -> String:
	return tr("ACTION_SIT") if item_id == &"garden_bench" and not _resting else ""


func interact(player: Node) -> void:
	if item_id == &"garden_bench" and not _resting:
		sit(player)


## Whether sitting down now would give energy (not within REST_EVERY of the last time).
func rest_ready() -> bool:
	return GameClock.total_minutes - float(entry.get("rested_at", -INF)) >= REST_EVERY


## Sits the farmer down for a moment: the view from the bench, then a little energy.
func sit(player: Node) -> void:
	if _resting or Game.is_ui_open():
		return
	_resting = true
	_rest_t = 0.0
	Game.push_ui(REST_UI)
	# No pointer over the view (automated runs never take the mouse).
	Game.capture_mouse()
	Audio.play("plank", global_position + Vector3(0, 0.5, 0), -14.0)
	var own := (player as Player).camera if player is Player else null
	if own != null and DisplayServer.get_name() != "headless":
		_rest_cam = Camera3D.new()
		_rest_cam.fov = own.fov
		_rest_cam.near = own.near
		_rest_cam.far = own.far
		_rest_cam.cull_mask = own.cull_mask
		_rest_cam.attributes = own.attributes
		_rest_cam.environment = own.environment
		_rest_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(_rest_cam)
		_rest_cam.position = Vector3(0, IdentityModels.BENCH_SEAT + SEAT_EYE, 0.02)
		_rest_cam.rotation = Vector3(deg_to_rad(-4.0), PI, 0)
		_rest_cam.make_current()
	Game.notify(tr("MSG_BENCH_SIT"), IdentityWorks.GOAL_COLOR)
	set_process(true)


func is_resting() -> bool:
	return _resting


func _process(delta: float) -> void:
	if not _resting:
		set_process(false)
		return
	if Game.is_paused():
		return
	_rest_t += delta
	if _rest_cam:
		# The bench faces +Z: the eye looks out along it, turning slowly side to side.
		var swing := sin(_rest_t / REST_SECONDS * TAU * 0.5 - PI * 0.5) * deg_to_rad(VIEW_SWING)
		_rest_cam.rotation = Vector3(deg_to_rad(-4.0), PI + swing, 0)
	if _rest_t >= REST_SECONDS:
		stand_up(true)


func _unhandled_input(event: InputEvent) -> void:
	if _resting and _rest_t > 0.4 and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		get_viewport().set_input_as_handled()
		stand_up(_rest_t >= REST_SECONDS * 0.6)


## Up from the bench: `rested` gives the energy (when the bench has any to give).
func stand_up(rested: bool) -> void:
	if not _resting:
		return
	_resting = false
	set_process(false)
	if _rest_cam:
		_rest_cam.queue_free()
		_rest_cam = null
		var player := Game.player as Player
		if player:
			player.camera.make_current()
	Game.pop_ui(REST_UI)
	if rested and rest_ready():
		entry["rested_at"] = GameClock.total_minutes
		var needs := PlayerState.needs
		needs.energy = minf(needs.energy + REST_ENERGY, Needs.MAX)
		needs.changed.emit()
		Game.notify(tr("MSG_BENCH_RESTED"), UiTheme.GREEN)


func _exit_tree() -> void:
	if _resting:
		stand_up(false)


func can_pick_up() -> bool:
	return not _resting
