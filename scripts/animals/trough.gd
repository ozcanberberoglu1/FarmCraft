class_name Trough
extends StaticBody3D
## Feed or water trough. The player fills it with the right item (or the watering
## can); animals eat and drink rations from it. Open-air water troughs refill in
## the rain.

signal changed
## The farmer filled it (feed or water poured in by hand).
signal filled

enum Kind { FEED, WATER }

var kind := Kind.FEED
## Items accepted as one ration each (feed troughs only).
var accepts: Array[StringName] = [&"hay"]
## Items of feed (or hay) one fill puts in the trough.
const FEED_PER_USE := 1

var capacity := 8
var amount := 0.0
var outdoors := true
var long := true
## Its length in metres when set (a longer coop's feeder and waterer); else as `long` says.
var span := 0.0

var _fill: MeshInstance3D
var _fill_top := 0.0
var _fill_bottom := 0.0
var _width := 0.5
var _length := 2.0


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(&"troughs")
	_build()
	_build_fill()
	_refresh()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var mb := MeshBuilder.new()
	var length := span if span > 0.0 else (2.0 if long else 0.9)
	var width := 0.55 if long else 0.42
	var height := 0.55 if long else 0.3
	var wall := 0.06
	var y0 := 0.0
	if kind == Kind.WATER:
		# Cast stone trough (or a small galvanized waterer in the coop).
		var key := &"stone" if long else &"galv"
		var col := Color(0.5, 0.5, 0.49) if long else Color(0.55, 0.58, 0.6)
		_open_box(mb, key, Vector3.ZERO, Vector3(width, height, length), wall, col)
	else:
		var wood := Color(0.5, 0.46, 0.42)
		y0 = height - 0.3 if long else 0.02
		_open_box(mb, &"planks", Vector3(0, y0, 0), Vector3(width, 0.3, length), 0.045, wood)
		if long:
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					mb.box_at(&"wood", Vector3(sx * (width * 0.5 - 0.06), y0 * 0.5, sz * (length * 0.5 - 0.1)), Vector3(0.08, y0, 0.08), wood.darkened(0.2), Vector3.ZERO, true)
		height = y0 + 0.3
	_fill_bottom = y0 + 0.05
	_fill_top = height - 0.05
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	add_child(mi)
	_width = width
	_length = length


## Open-topped box: bottom plate and four walls.
func _open_box(mb: MeshBuilder, key: StringName, base: Vector3, size: Vector3, wall: float, col: Color) -> void:
	mb.box_at(key, base + Vector3(0, wall * 0.5, 0), Vector3(size.x, wall, size.z), col.darkened(0.1))
	for sx: float in [-1.0, 1.0]:
		mb.box_at(key, base + Vector3(sx * (size.x - wall) * 0.5, size.y * 0.5, 0), Vector3(wall, size.y, size.z), col)
	for sz: float in [-1.0, 1.0]:
		mb.box_at(key, base + Vector3(0, size.y * 0.5, sz * (size.z - wall) * 0.5), Vector3(size.x - wall * 2.0, size.y, wall), col.darkened(0.05))


func _build_fill() -> void:
	# Fill surface: hay or water, scaled with the amount.
	_fill = MeshInstance3D.new()
	var fb := MeshBuilder.new()
	var inner := Vector2(_width - 0.12, _length - 0.12)
	if kind == Kind.WATER:
		fb.box_at(&"water_still", Vector3(0, -0.01, 0), Vector3(inner.x, 0.02, inner.y), Color(0.2, 0.32, 0.36))
	elif &"feed" in accepts:
		_grain(fb, inner)
	else:
		fb.box(&"straw", Transform3D(Basis(), Vector3(0, -0.06, 0)), Vector3(inner.x, 0.12, inner.y), Color(0.76, 0.62, 0.34))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 40:
			var p := Vector3(rng.randf_range(-inner.x, inner.x) * 0.45, 0.0, rng.randf_range(-inner.y, inner.y) * 0.45)
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 0.8), rng.randf_range(-1, 1)).normalized()
			fb.cylinder_between(&"veg", p, p + d * rng.randf_range(0.05, 0.12), 0.002, 0.001, 3, Color(0.8, 0.66, 0.36), false, false)
	_fill.mesh = fb.build()
	add_child(_fill)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_width, maxf(_fill_top + 0.05, 0.3), _length)
	cs.shape = box
	cs.position.y = box.size.y * 0.5
	add_child(cs)


## Chicken feed in a coop feeder: a bed of crumbled mash heaped in little mounds, with
## loose grains and pellets on top.
func _grain(fb: MeshBuilder, inner: Vector2) -> void:
	var mash := Color(0.62, 0.5, 0.3)
	fb.box_at(&"veg_rough", Vector3(0, -0.04, 0), Vector3(inner.x, 0.08, inner.y), mash)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 5:
		var p := Vector3(rng.randf_range(-0.4, 0.4) * inner.x, 0.0, rng.randf_range(-0.4, 0.4) * inner.y)
		var r := rng.randf_range(0.05, 0.09)
		fb.sphere(&"veg_rough", Transform3D(Basis(), p), Vector3(r * 1.3, r * 0.35, r), 7, 3, mash.lightened(rng.randf_range(-0.08, 0.06)))
	for i in 46:
		var p := Vector3(rng.randf_range(-0.46, 0.46) * inner.x, rng.randf_range(0.0, 0.012), rng.randf_range(-0.46, 0.46) * inner.y)
		var b := Basis(Vector3.UP, rng.randf() * TAU)
		var col := Color(0.78, 0.64, 0.34) if i % 3 != 0 else Color(0.5, 0.4, 0.26)
		fb.box(&"veg", Transform3D(b, p), Vector3(0.016, 0.008, 0.008), col.lightened(rng.randf_range(-0.1, 0.1)))


func set_amount(value: float) -> void:
	amount = clampf(value, 0.0, capacity)
	_refresh()
	changed.emit()


## Takes up to `rations` and returns how much was actually eaten or drunk.
func take(rations: float) -> float:
	var got := minf(rations, amount)
	if got > 0.0:
		set_amount(amount - got)
	return got


func is_empty() -> bool:
	return amount < 0.05


## How far either side of its middle an animal may stand along it to eat or drink.
func reach() -> float:
	return 0.7 if long else maxf(0.15, _length * 0.5 - 0.3)


func _refresh() -> void:
	if _fill == null:
		return
	var r := amount / float(capacity)
	_fill.visible = r > 0.01
	_fill.position.y = lerpf(_fill_bottom + 0.03, _fill_top, r)
	# The level jumps to the new amount rather than gliding over a physics tick.
	_fill.reset_physics_interpolation()


## Rain tops up open-air water troughs.
func rain(hours: float) -> void:
	if kind == Kind.WATER and outdoors:
		set_amount(amount + hours * 2.0)


# --- Player interaction -------------------------------------------------------------

func interact_prompt(_player: Node) -> String:
	return ""


func use_prompt(_player: Node, stack: ItemStack) -> String:
	var a := use_action(_player, stack)
	return tr(a["verb"]) if not a.is_empty() else ""


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	if stack == null:
		return {}
	if kind == Kind.WATER and stack.item.water_capacity > 0:
		return {"id": "fill_water", "verb": "ACTION_FILL_TROUGH", "label": "PROGRESS_FILLING", "duration": 0.8}
	if kind == Kind.FEED and stack.item.id in accepts:
		return {"id": "fill_feed", "verb": "ACTION_FILL_TROUGH", "label": "PROGRESS_FILLING", "duration": 0.6}
	return {}


func can_start(action: Dictionary, stack: ItemStack) -> String:
	if amount >= capacity - 0.01:
		return tr("MSG_TROUGH_FULL")
	if action["id"] == "fill_water" and stack.water <= 0:
		return tr("MSG_CAN_EMPTY")
	return ""


## The can's stream or the tipped armful landing (the look only): drips while the can
## pours, a splash as the water level rises.
func use_impact(_player: Node, _stack: ItemStack, action: Dictionary, hit: Dictionary) -> void:
	if action["id"] != "fill_water":
		return
	var surface := global_position + Vector3(0, _fill_top, 0)
	if hit.get("final", false):
		Fx.water_splash(surface)
	else:
		var along := global_basis.z * randf_range(-0.3, 0.3) * _length
		Fx.drips(surface + along)


func complete_use(_player: Node, stack: ItemStack, action: Dictionary) -> void:
	var room := int(ceil(capacity - amount))
	if action["id"] == "fill_water":
		var used := mini(room, stack.water)
		stack.water -= used
		PlayerState.inventory.changed.emit()
		set_amount(amount + used)
	else:
		# One sack or armful per go (holding the button keeps filling, one at a time).
		var used := mini(room, mini(stack.count, FEED_PER_USE))
		PlayerState.inventory.remove_item(stack.item.id, used)
		set_amount(amount + used)
		Game.notify(tr("MSG_TROUGH_FILLED") % used)
	filled.emit()


func save_data() -> Dictionary:
	return {"amount": amount}


func load_data(d: Dictionary) -> void:
	set_amount(float(d.get("amount", 0.0)))
