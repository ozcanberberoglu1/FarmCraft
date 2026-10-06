class_name LanternPost
extends PlacedObject
## A post with an oil lantern (PlaceableTable "lantern_post", made at the workbench): it
## lights itself at dusk (LIT_FROM) and goes out at dawn (LIT_TO). Lit, it keeps wolves
## SAFE metres off as a burning campfire does (Wolf, WolfRaids ask Pastures), so a pasture
## whose every corner is in a lantern's light is safe for the night. It can stand on a
## fence's post (FencePlacing snaps it there). E held takes it back into the bag.

const GROUP := &"lantern_posts"
## Game hours it burns between (lit from dusk through the night to dawn).
const LIT_FROM := 18.5
const LIT_TO := 6.25
## Metres a lit one keeps wolves off.
const SAFE := 8.0
const HOLD := FencePiece.HOLD
const GLOW := Color(1.0, 0.72, 0.38)

var _light: OmniLight3D
var _flame: MeshInstance3D
var _lit := false
var _flicker := 0.0
var _hold := -1.0
var _holder: Player
var _showing := false


func _setup() -> void:
	add_to_group(GROUP)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, FenceModels.LANTERN_POST, 0.2)
	cs.shape = box
	cs.position.y = FenceModels.LANTERN_POST * 0.5
	add_child(cs)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = FenceModels.lantern_body()
	add_child(body)
	_flame = MeshInstance3D.new()
	_flame.name = "Flame"
	_flame.mesh = FenceModels.lantern_flame()
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.visible = false
	add_child(_flame)
	_light = OmniLight3D.new()
	_light.name = "Light"
	_light.position = FenceModels.LANTERN_FLAME + Vector3(0.0, -0.02, 0.0)
	_light.light_color = GLOW
	_light.omni_range = SAFE + 1.0
	_light.omni_attenuation = 1.3
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 70.0
	_light.distance_fade_length = 20.0
	_light.visible = false
	add_child(_light)
	_flicker = randf() * 10.0
	_sync(true)
	Pastures.mark_dirty()


func _exit_tree() -> void:
	_end_hold(false)
	Pastures.mark_dirty()


## Whether a lantern burns at game hour `hour`.
static func lit_at(hour: float) -> bool:
	return hour >= LIT_FROM or hour < LIT_TO


func is_lit() -> bool:
	return lit_at(GameClock.get_hour_float())


func _process(delta: float) -> void:
	_sync()
	if _lit:
		# The flame breathes a little.
		_flicker += delta
		_light.light_energy = 1.9 + sin(_flicker * 7.3) * 0.12 + sin(_flicker * 17.1) * 0.07
	_update_hold(delta)


func _sync(instant := false) -> void:
	var lit := is_lit()
	if lit == _lit and not instant:
		return
	_lit = lit
	_flame.visible = lit
	_light.visible = lit
	_light.light_energy = 1.9 if lit else 0.0
	if not instant and is_inside_tree():
		Audio.play("soft", global_position + FenceModels.LANTERN_FLAME, -16.0, 0.1, &"Effects", 4.0, 1.5)


# --- Prompts -------------------------------------------------------------------------------

func interact_title() -> String:
	return display_name()


func interact_prompt(_player: Node) -> String:
	return tr("ACTION_HOLD_PICK_UP")


func hint_prompt() -> String:
	return tr("HINT_LANTERN_LIT") if _lit else tr("HINT_LANTERN_DUSK")


func info_prompt() -> String:
	return ""


func info_interact(_player: Node) -> void:
	pass


func interact(player: Node) -> void:
	_hold = 0.0
	_holder = player as Player


func _update_hold(delta: float) -> void:
	if _hold < 0.0:
		return
	var aimed := _holder != null and is_instance_valid(_holder) and _holder.target == self
	if not Input.is_action_pressed("interact") or Game.is_ui_open() or not aimed:
		_end_hold(false)
		return
	_hold += delta
	if _hold > 0.18 and not _showing:
		_showing = true
		Events.action_progress_started.emit(tr("PROGRESS_FENCE_PICKUP"), HOLD)
	if _showing:
		Events.action_progress_updated.emit(clampf(_hold / HOLD, 0.0, 1.0))
	if _hold >= HOLD:
		_end_hold(true)
		pick_up()


func _end_hold(done: bool) -> void:
	if _showing:
		Events.action_progress_finished.emit(done)
	_showing = false
	_hold = -1.0
	_holder = null


## Back into the bag (and off the farm). False when the bag has no room for it.
func pick_up() -> bool:
	if PlayerState.give(item_id, 1) > 0:
		return false
	Audio.play("plank", global_position + Vector3(0, 0.5, 0), -6.0)
	FarmState.remove_placed(entry)
	queue_free()
	Pastures.mark_dirty()
	return true
