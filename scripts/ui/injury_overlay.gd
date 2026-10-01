class_name InjuryOverlay
extends CanvasLayer
## The farmer's wounds on screen (PlayerState.injury), under the HUD: a dark red creeping
## in from the edges as the meter fills, throbbing with a heartbeat when it is high and
## easing away as he heals; each bite (PlayerState.hurt_taken) flares the edge and leaves
## a smear of blood on the side it came from (shaders/injury_vignette.gdshader). Not
## drawn at all while he is unhurt.

## Seconds a bite's smear and its flare take to fade.
const SPLASH_FADE := 1.8
const FLASH_FADE := 0.35
## Heartbeats per second at the worst.
const PULSE_RATE := 2.1

var _rect: ColorRect
var _mat: ShaderMaterial
var _shown := 0.0
var _splash := 0.0
var _flash := 0.0
var _beat := 0.0


func _ready() -> void:
	layer = 6
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/injury_vignette.gdshader")
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)
	PlayerState.hurt_taken.connect(_on_hurt)


## How strongly the wounds show now (0..1; for tests).
func shown() -> float:
	return _shown if _rect.visible else 0.0


func _on_hurt(amount: float, from: Vector3) -> void:
	_flash = clampf(_flash + amount / 25.0, 0.0, 1.0)
	_splash = 1.0
	var dir := Vector2(0.0, 1.0)
	var player := Game.player as Player
	if player:
		var cam := player.camera
		var local := cam.global_basis.inverse() * (from - cam.global_position)
		var flat := Vector2(local.x, local.z)
		if flat.length() > 0.01:
			# Wolves bite low: the smear leans to the bottom edge; one from behind is there.
			dir = Vector2(flat.normalized().x, 0.55 + maxf(flat.normalized().y, 0.0)).normalized()
	_mat.set_shader_parameter("splash_dir", dir)
	_mat.set_shader_parameter("splash_seed", randf() * 10.0)


func _process(delta: float) -> void:
	var want := PlayerState.injury / PlayerState.INJURY_MAX
	# Up quickly with a wound, down slowly as it heals.
	_shown = move_toward(_shown, want, delta * (2.5 if want > _shown else 0.6))
	_splash = maxf(_splash - delta / SPLASH_FADE, 0.0)
	_flash = maxf(_flash - delta / FLASH_FADE, 0.0)
	var on := _shown > 0.002 or _splash > 0.0 or _flash > 0.0
	if _rect.visible != on:
		_rect.visible = on
	if not on:
		return
	_beat += delta * lerpf(1.1, PULSE_RATE, _shown)
	# A double beat (lub-dub), only when it is bad.
	var ph := fposmod(_beat, 1.0)
	var lub := exp(-pow((ph - 0.1) / 0.06, 2.0)) + 0.6 * exp(-pow((ph - 0.32) / 0.07, 2.0))
	var vp := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("injury", _shown)
	_mat.set_shader_parameter("pulse", lub * smoothstep(0.45, 0.9, _shown))
	_mat.set_shader_parameter("flash", _flash)
	_mat.set_shader_parameter("splash", ease(_splash, 0.6))
	_mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
