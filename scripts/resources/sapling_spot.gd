class_name SaplingSpot
extends Node3D
## Where the sapling in hand would go: the open ground the player aims at
## (SaplingGrove.ground_target), the Player's hold-to-use target there. Holding LMB
## brings the sapling down to the ground, sets it into the soil and pats the earth round
## it once (ToolAnim "set_down": a placing hand, no blows). A ring lies on the ground
## under the aim while it is the target: green where a sapling can go, red where not,
## the reason under the prompt.

const RING_RADIUS := 0.34

## "" where a sapling can go, else why not (a translation key; SaplingGrove.plant_reason).
var reason := ""
var _ring: MeshInstance3D
var _checked_at := Vector3.INF

static var _ok_mat: StandardMaterial3D
static var _bad_mat: StandardMaterial3D


func _ready() -> void:
	# Moved in one jump to wherever the aim lands.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if _ok_mat == null:
		_ok_mat = _material(Color(0.35, 1.0, 0.45, 0.55))
		_bad_mat = _material(Color(1.0, 0.3, 0.25, 0.55))
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RING_RADIUS - 0.025
	torus.outer_radius = RING_RADIUS + 0.025
	torus.rings = 32
	torus.ring_segments = 6
	_ring.mesh = torus
	_ring.scale = Vector3(1.0, 0.35, 1.0)
	_ring.position.y = 0.02
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_ring.layers = 2
	add_child(_ring)
	visible = false


static func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


## Follows the aim on the ground (it stays put while a sapling is going in there).
func aim(player: Player, p: Vector3) -> SaplingSpot:
	if player.action_clock() < 0.0:
		global_position = p
		var n := TerrainData.normal_at(p.x, p.z)
		_ring.basis = Basis(Quaternion(Vector3.UP, n)) * Basis.from_scale(Vector3(1.0, 0.35, 1.0))
		if p.distance_squared_to(_checked_at) > 0.0025:
			_checked_at = p
			_check(player)
	return self


func _check(player: Node) -> void:
	var grove := get_parent() as SaplingGrove
	reason = grove.plant_reason(global_position, player) if grove else "SAPLING_NOT_HERE"
	_ring.material_override = _ok_mat if reason == "" else _bad_mat


# --- The Player's target ----------------------------------------------------------------

func interact_prompt(_player: Node) -> String:
	return ""


func use_prompt(player: Node, stack: ItemStack) -> String:
	return tr("ACTION_PLANT") if not use_action(player, stack).is_empty() else ""


## The reason a sapling can't go here, under the prompt.
func hint_prompt() -> String:
	return tr(reason) if reason != "" else ""


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	if stack == null or stack.item.id != SaplingGrove.ITEM:
		return {}
	return {"id": "plant_sapling", "verb": "ACTION_PLANT", "label": "PROGRESS_PLANTING", "duration": 1.4}


func can_start(_action: Dictionary, _stack: ItemStack) -> String:
	_check(Game.player)
	return tr(reason) if reason != "" else ""


func set_highlight(on: bool) -> void:
	visible = on


## The sapling going into the soil (the final stroke): a little loose earth gives way round
## its root ball. The pat that follows firms it down: a soft thud and a breath of dust.
func use_impact(_player: Node, _stack: ItemStack, _action: Dictionary, hit: Dictionary) -> void:
	var at := global_position + Vector3(0, 0.04, 0)
	if hit.get("final", false):
		Fx.dirt_burst(at, 0.3, global_position.y)
		Audio.play("plant", at + Vector3(0, 0.2, 0), -3.0, 0.08, &"Effects", 5.0)
		Audio.play("dig", at + Vector3(0, 0.2, 0), -15.0, 0.08, &"Effects", 5.0, 1.15)
	else:
		Fx.dirt_burst(at, 0.15, global_position.y)
		Audio.play("plant", at + Vector3(0, 0.2, 0), -9.0, 0.08, &"Effects", 5.0, 0.85)


func complete_use(_player: Node, _stack: ItemStack, _action: Dictionary) -> void:
	var grove := get_parent() as SaplingGrove
	if grove == null:
		return
	_check(Game.player)
	if reason != "":
		Game.notify(tr(reason), UiTheme.RED)
		return
	var s := PlayerState.selected_stack()
	if s == null or s.item.id != SaplingGrove.ITEM or PlayerState.inventory.take_from(PlayerState.selected, 1) == null:
		return
	grove.plant(global_position)
	_checked_at = Vector3.INF
	visible = false
	Game.notify(tr("MSG_SAPLING_PLANTED"), UiTheme.GREEN)
