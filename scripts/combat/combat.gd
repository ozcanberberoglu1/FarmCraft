class_name Combat
extends Node
## The farmer's knife, axe and bow as weapons (a child of the Player, which hands it the
## LMB while the knife or the bow is in hand, and the axe's when a target is in its reach).
##
## What can be hit is in the "hittable" group (itself, or a parent of the collider an
## arrow strikes, up to 4 levels) and implements
##   take_hit(damage: float, from: Vector3, kind: StringName)   kind &"knife", &"axe" or &"arrow"
## where `from` is where the blow came from (the farmer). Optionally can_be_hit() -> bool
## (false: a carcass), hit_center() -> Vector3 and a `hit_radius` property (m) for the
## knife's and the axe's reach (a wolf-sized body otherwise), evasion() -> float (0..1:
## how much harder it is to hit on the move) and dodge(from: Vector3) (a blow missed it).
##
## KNIFE: LMB stabs (ToolAnim "stab", a swoosh). On the stroke's contact the nearest
## hittable in front of the farmer within KNIFE_REACH of his body (not behind a wall)
## takes KNIFE_DAMAGE, with a thud, a few drops of blood and a punch of the view, and the
## knife wears by one; a stab at nothing only swooshes. The knife's other uses (cleaning a
## catch at the food table) are left as they are.
## AXE: LMB with a hittable in front within AXE_REACH (Player._update_action; else the axe
## chops or swings at nothing as before): the axe's own swing (ToolAnim "axe"), landing
## on its contact like the stab for AXE_DAMAGE (three blows kill a wolf), with a heavier
## knock of the view; it wears by one.
## A blow can miss (KNIFE_MISS, AXE_MISS; more often at a target on the move, MOVING_MISS
## times its evasion()): only the swoosh, no wound and no wear, and the target jumps aside
## (dodge).
## BOW: hold LMB to draw (DRAW_TIME to full draw): the bow comes up to the aim pose, an
## arrow from the bag is nocked and the string comes back with it, the view narrows a
## little (DRAW_ZOOM) and the farmer walks slower. Releasing looses the arrow (Arrow),
## faster and harder the further it was drawn (ARROW_SPEED, ARROW_DAMAGE), and wears the
## bow by one; a barely drawn string is only let down. RMB, a menu or changing the item
## lets it down too. Without arrows LMB says so.

enum Bow { IDLE, DRAW, LOOSE }

const HITTABLE := &"hittable"
const KNIFE := &"knife"
const BOW := &"bow"
const ARROW := &"arrow"
## The knife: reach from the farmer's body to the target's (m), the wound, the stab's
## length (s) and half the angle in front it finds a target in (degrees).
const KNIFE_REACH := 1.8
const KNIFE_DAMAGE := 34.0
const STAB_TIME := 0.42
const KNIFE_CONE := 40.0
## The axe as a weapon: reach (m, as the knife's), the wound, the swing's length (s) and
## half the angle in front it finds a target in (degrees).
const AXE := &"axe"
const AXE_REACH := 1.9
const AXE_DAMAGE := 40.0
const AXE_CONE := 45.0
## The chance a blow misses: the knife's, the axe's, and what is added at a target on the
## move (times its evasion(), 0..1).
const KNIFE_MISS := 0.15
const AXE_MISS := 0.25
const MOVING_MISS := 0.15
## A target without hit_center / hit_radius: a wolf-sized body.
const HIT_HEIGHT := 0.45
const HIT_RADIUS := 0.35
## Seconds to full draw; under MIN_DRAW the string is only let down.
const DRAW_TIME := 0.7
const MIN_DRAW := 0.18
## Seconds the bow takes to come up to the aim pose (and to go back down).
const RAISE_TIME := 0.22
## Seconds after a shot before the next draw (the string settles, the bow comes back).
const LOOSE_TIME := 0.38
## An arrow's speed (m/s) and wound at the least and at full draw.
const ARROW_SPEED := Vector2(16.0, 50.0)
const ARROW_DAMAGE := Vector2(14.0, 55.0)
## How much the view narrows at full draw (degrees) and how fast the farmer walks then.
const DRAW_ZOOM := 9.0
const DRAW_WALK := 0.55
## Spread of a hasty shot (degrees at no draw; none at full draw).
const SPREAD := 2.5

var player: Player
var bow_state := Bow.IDLE
## Blows can miss (tests that need every blow to land switch it off).
var misses := true
## Knife and axe blows at a target, and those that missed it (tests).
var blows := 0
var missed := 0
## How far the string is drawn (0..1) and how far the bow is up in the aim pose (0..1).
var draw := 0.0
var aim := 0.0
## Seconds left of a stab, of an axe's swing, and of a shot's follow-through.
var _stab_left := 0.0
var _swing_left := 0.0
var _loose_left := 0.0
## Seconds the string has been held at full draw (the arms start to tire after a while).
var _held := 0.0
var _draw_sfx: Node = null
var _no_arrows_note := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	player = get_parent() as Player
	_rng.randomize()
	PlayerState.selected_changed.connect(func(_s: int) -> void: _check_hand())
	PlayerState.inventory.changed.connect(_check_hand)


## The knife is the item in hand.
func holding_knife() -> bool:
	var s := PlayerState.selected_stack()
	return s != null and (s.item.id == KNIFE or s.item.tool_type == KNIFE)


## The axe is the item in hand.
func holding_axe() -> bool:
	var s := PlayerState.selected_stack()
	return s != null and s.item.tool_type == AXE


## An axe's swing at something is under way (the Player starts nothing else meanwhile).
func swinging() -> bool:
	return _swing_left > 0.0


## The bow is the item in hand.
func holding_bow() -> bool:
	var s := PlayerState.selected_stack()
	return s != null and (s.item.id == BOW or s.item.tool_type == BOW)


## A string is being drawn (for the player's speed and view, and tests).
func is_drawing() -> bool:
	return bow_state == Bow.DRAW


## How much narrower the view is now (degrees).
func fov_offset() -> float:
	return -DRAW_ZOOM * ease(draw, -1.6) if bow_state == Bow.DRAW else 0.0


## How fast the farmer walks now (1 = as usual).
func move_factor() -> float:
	return lerpf(1.0, DRAW_WALK, aim) if bow_state == Bow.DRAW else 1.0


## The prompt lines while the bow is in hand (the Player adds them under its own).
func prompt_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if not holding_bow():
		return out
	var arrows := PlayerState.inventory.count_item(ARROW)
	if bow_state == Bow.DRAW:
		out.append("%s (%s)" % [tr("KEY_RMB"), tr("ACTION_LET_DOWN")])
	elif arrows > 0:
		out.append("%s (%s)" % [tr("KEY_LMB"), tr("ACTION_DRAW_BOW")])
	out.append(tr("HINT_ARROWS") % arrows if arrows > 0 else tr("HINT_NO_ARROWS"))
	return out


# --- Knife -------------------------------------------------------------------------------

## LMB with the knife in hand: a stab, landing on the stroke's contact (_land_stab).
func stab() -> void:
	var stack := PlayerState.selected_stack()
	if _stab_left > 0.0 or stack == null:
		return
	if stack.item.has_durability() and stack.durability <= 0:
		Game.notify(tr("MSG_TOOL_BROKEN") % stack.item.display_name(), Color(1.0, 0.45, 0.35))
		return
	_stab_left = STAB_TIME
	player.held.play(&"stab", STAB_TIME, 1, false)
	var impact := ToolAnim.impact_u(&"stab") * STAB_TIME
	CombatSfx.play("knife_swing", player.camera.global_position - player.camera.global_basis.z * 0.5, -8.0, 0.1)
	get_tree().create_timer(impact, false, true).timeout.connect(_land_stab.bind(stack))


## The stab's contact: the target in reach takes the wound (or it misses).
func _land_stab(stack: ItemStack) -> void:
	if not is_instance_valid(player) or PlayerState.selected_stack() != stack or player.riding or player.driving:
		return
	var t := knife_target()
	if t == null:
		return
	if _misses(t, KNIFE_MISS):
		return
	_strike(t, KNIFE_DAMAGE, KNIFE, stack)
	player.kick_view(Vector4(-0.7, 0.35, 0.6, -0.008), 0.1)


## LMB with the axe in hand at a target in its reach (Player._update_action): the axe's
## swing, landing on its contact (_land_axe).
func axe_swing() -> void:
	var stack := PlayerState.selected_stack()
	if _swing_left > 0.0 or stack == null:
		return
	if stack.item.has_durability() and stack.durability <= 0:
		Game.notify(tr("MSG_TOOL_BROKEN") % stack.item.display_name(), Color(1.0, 0.45, 0.35))
		return
	var length: float = ToolAnim.AIR.get(AXE, 0.7)
	_swing_left = length
	player.held.play(&"axe", length, 1, false)
	var impact := ToolAnim.impact_u(&"axe") * length
	get_tree().create_timer(maxf(impact - ToolAnim.WHOOSH_LEAD, 0.0), false, true).timeout.connect(func() -> void:
		if is_instance_valid(player):
			Audio.swing(AXE, player.camera.global_position - player.camera.global_basis.z * 0.6))
	get_tree().create_timer(impact, false, true).timeout.connect(_land_axe.bind(stack))


## The axe's contact: the target in reach takes the blow (or it misses).
func _land_axe(stack: ItemStack) -> void:
	if not is_instance_valid(player) or PlayerState.selected_stack() != stack or player.riding or player.driving:
		return
	var t := axe_target()
	if t == null:
		return
	if _misses(t, AXE_MISS):
		return
	_strike(t, AXE_DAMAGE, AXE, stack)
	player.kick_view(Vector4(-1.4, 0.5, -0.9, -0.02), 0.3)
	CombatSfx.play("arrow_flesh", hit_center(t), -4.0, 0.1)


## Whether a blow at `t` misses (`chance`, more at a target on the move): then only the
## swoosh, and it jumps aside.
func _misses(t: Node3D, chance: float) -> bool:
	blows += 1
	if not misses:
		return false
	var moving := clampf(float(t.call("evasion")), 0.0, 1.0) if t.has_method("evasion") else 0.0
	if _rng.randf() >= chance + MOVING_MISS * moving:
		return false
	missed += 1
	if t.has_method("dodge"):
		t.call("dodge", player.global_position)
	return true


## A blow lands on `t`: the wound, the tool worn by one, a thud and a few drops of blood.
func _strike(t: Node3D, damage: float, kind: StringName, stack: ItemStack) -> void:
	var at := hit_center(t)
	var toward := (at - player.camera.global_position).normalized()
	at -= toward * hit_radius(t) * 0.6
	t.take_hit(damage, player.global_position, kind)
	player.wear_tool(stack)
	CombatSfx.play("knife_hit", at, -2.0 if kind == KNIFE else 1.0, 0.08)
	Fx.blood_drops(at, -toward)


## The hittable the knife reaches now (melee_target).
func knife_target() -> Node3D:
	return melee_target(KNIFE_REACH, KNIFE_CONE)


## The hittable the axe reaches now (melee_target).
func axe_target() -> Node3D:
	return melee_target(AXE_REACH, AXE_CONE)


## The hittable a blow reaches now: the nearest one in front of the farmer within `reach`
## of his body (their hit_radius counted off), inside `cone` degrees of where he looks,
## with nothing solid between; null when there is none.
func melee_target(reach: float, cone: float) -> Node3D:
	var eye := player.camera.global_position
	var fwd := -player.camera.global_basis.z
	var flat_fwd := Vector3(fwd.x, 0.0, fwd.z)
	if flat_fwd.length_squared() < 0.0001:
		flat_fwd = -player.global_basis.z
	flat_fwd = flat_fwd.normalized()
	var feet := player.global_position
	var best: Node3D = null
	var best_d := INF
	for n: Node in get_tree().get_nodes_in_group(HITTABLE):
		var t := n as Node3D
		if t == null or not t.is_inside_tree() or not t.is_visible_in_tree():
			continue
		if t.has_method("can_be_hit") and not t.can_be_hit():
			continue
		var c := hit_center(t)
		if c.y < feet.y - 0.6 or c.y > eye.y + 0.6:
			continue
		var flat := Vector3(c.x - feet.x, 0.0, c.z - feet.z)
		var d := flat.length() - hit_radius(t)
		if d > reach or d >= best_d:
			continue
		if flat.length() > hit_radius(t) and rad_to_deg(flat_fwd.angle_to(flat.normalized())) > cone:
			continue
		if not _in_sight(eye, c, t):
			continue
		best = t
		best_d = d
	return best


## Nothing of the world stands between `from` and `to` (a hit on `t` itself is fine).
func _in_sight(from: Vector3, to: Vector3, t: Node) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or find_hittable(hit["collider"]) == t


# --- Bow ---------------------------------------------------------------------------------

## LMB from Player._update_action every physics tick while the bow is in hand.
func bow_input(down: bool, pressed: bool) -> void:
	match bow_state:
		Bow.IDLE:
			if pressed:
				_start_draw()
		Bow.DRAW:
			if Game.is_ui_open() or Input.is_action_pressed("secondary") or player.riding or player.driving:
				let_down()
			elif not down:
				_loose()


func _start_draw() -> void:
	var stack := PlayerState.selected_stack()
	if stack == null:
		return
	if stack.item.has_durability() and stack.durability <= 0:
		Game.notify(tr("MSG_TOOL_BROKEN") % stack.item.display_name(), Color(1.0, 0.45, 0.35))
		return
	if PlayerState.inventory.count_item(ARROW) <= 0:
		if _no_arrows_note <= 0.0:
			_no_arrows_note = 1.5
			Game.notify(tr("MSG_NO_ARROWS"), Color(1.0, 0.55, 0.4))
		return
	bow_state = Bow.DRAW
	draw = 0.0
	_held = 0.0
	_draw_sfx = CombatSfx.play("bow_draw", null, -9.0, 0.05)
	Events.action_progress_started.emit(tr("PROGRESS_DRAW"), DRAW_TIME)


## The string let down without a shot (RMB, a menu, the item put away).
func let_down() -> void:
	if bow_state != Bow.DRAW:
		return
	bow_state = Bow.IDLE
	_stop_draw_sfx()
	Events.action_progress_finished.emit(false)
	if draw > 0.3:
		CombatSfx.play("bow_letdown", null, -14.0, 0.05)


## Release: the arrow flies (or, barely drawn, the string is let down).
func _loose() -> void:
	if draw < MIN_DRAW:
		let_down()
		return
	var stack := PlayerState.selected_stack()
	if stack == null or not PlayerState.inventory.remove_item(ARROW, 1):
		let_down()
		return
	_stop_draw_sfx()
	Events.action_progress_finished.emit(true)
	var power := ease(draw, 0.6)
	var fwd := -player.camera.global_basis.z
	var spread := deg_to_rad(SPREAD * (1.0 - draw) + (0.4 if _held > 4.0 else 0.0))
	if spread > 0.0:
		fwd = fwd.rotated(player.camera.global_basis.x, _rng.randf_range(-spread, spread))
		fwd = fwd.rotated(player.camera.global_basis.y, _rng.randf_range(-spread, spread))
	var from := player.camera.global_position + fwd * 0.35 - player.camera.global_basis.y * 0.04
	Arrow.launch(from, fwd * lerpf(ARROW_SPEED.x, ARROW_SPEED.y, power), lerpf(ARROW_DAMAGE.x, ARROW_DAMAGE.y, power),
			player.global_position, player)
	player.wear_tool(stack)
	player.kick_view(Vector4(0.5, -0.15, -0.4, 0.0), 0.04)
	CombatSfx.play("bow_release", null, -4.0 + 4.0 * power, 0.06)
	bow_state = Bow.LOOSE
	_loose_left = LOOSE_TIME
	draw = 0.0


func _stop_draw_sfx() -> void:
	if is_instance_valid(_draw_sfx):
		Audio.fade_out(_draw_sfx, 0.08)
	_draw_sfx = null


## Puts everything away: no stab lands, no string stays drawn.
func cancel() -> void:
	let_down()
	bow_state = Bow.IDLE
	draw = 0.0
	_loose_left = 0.0


func _check_hand() -> void:
	if not holding_bow():
		cancel()
		aim = 0.0
		_pose()


# --- Every frame -------------------------------------------------------------------------

func _process(delta: float) -> void:
	_no_arrows_note = maxf(_no_arrows_note - delta, 0.0)
	_stab_left = maxf(_stab_left - delta, 0.0)
	_swing_left = maxf(_swing_left - delta, 0.0)
	if not holding_bow():
		return
	match bow_state:
		Bow.DRAW:
			draw = minf(draw + delta / DRAW_TIME, 1.0)
			if draw >= 1.0:
				_held += delta
			Events.action_progress_updated.emit(draw)
			aim = minf(aim + delta / RAISE_TIME, 1.0)
		Bow.LOOSE:
			_loose_left -= delta
			if _loose_left <= 0.0:
				bow_state = Bow.IDLE
		Bow.IDLE:
			aim = maxf(aim - delta / (RAISE_TIME * 1.6), 0.0)
	_pose()


## The bow in hand: up in the aim pose, the string drawn and an arrow on it while drawing.
func _pose() -> void:
	if player == null or player.held == null:
		return
	var nocked := bow_state == Bow.DRAW
	# The string snaps forward on a shot; the bow comes down after a moment.
	var shown := draw if nocked else 0.0
	var a := aim if bow_state != Bow.LOOSE else 1.0
	# A long hold at full draw starts to shake a little.
	var tremor := clampf((_held - 3.0) / 4.0, 0.0, 1.0) if nocked else 0.0
	player.held.set_bow(shown, a, nocked, tremor)


# --- Hittables ---------------------------------------------------------------------------

## The hittable a collider belongs to (it, or a parent up to 4 levels), or null.
static func find_hittable(node: Object) -> Node3D:
	var n := node as Node
	for i in 5:
		if n == null:
			return null
		if n.is_in_group(HITTABLE) and n.has_method("take_hit"):
			return n as Node3D
		n = n.get_parent()
	return null


## Where `t` is struck (its hit_center, else a little above its origin).
static func hit_center(t: Node3D) -> Vector3:
	if t.has_method("hit_center"):
		return t.hit_center()
	return t.global_position + Vector3(0, HIT_HEIGHT, 0)


## How far `t`'s body reaches out from its centre (m).
static func hit_radius(t: Node3D) -> float:
	var r: Variant = t.get("hit_radius")
	return float(r) if r is float or r is int else HIT_RADIUS
