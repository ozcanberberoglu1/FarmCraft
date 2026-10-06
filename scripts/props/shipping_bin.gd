class_name ShippingBin
extends StaticBody3D
## Wooden bin next to the house. Whatever is put in it is sold overnight at the
## current market price. Goods going in are reported on the bus (Events.shipped), so
## goals can count what was shipped.

const SLOTS := 24
## The bin's storage in FarmState (kept in the save).
const STORAGE_ID := "shipping_bin"

var inventory: Inventory
var _lid: Node3D
## item id -> how many of it were reported shipped since the last sale: taking goods
## out and putting them back doesn't count them twice.
var _reported := {}


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	inventory = FarmState.get_storage(STORAGE_ID, SLOTS)
	# Only goods that sell (not a hen in its crate, a coop kit or a tool).
	inventory.accepts = func(item: ItemData) -> bool: return item.category != "animal" and item.sell_price > 0
	_reported = _counts()
	inventory.changed.connect(_on_contents_changed)
	var mb := MeshBuilder.new()
	var wood := Color(0.52, 0.47, 0.43)
	var w := 1.3
	var d := 0.8
	var h := 0.75
	mb.box_at(&"planks", Vector3(0, 0.05, 0), Vector3(w, 0.1, d), wood.darkened(0.1))
	for sx: float in [-1.0, 1.0]:
		mb.box_at(&"planks", Vector3(sx * (w * 0.5 - 0.03), h * 0.5, 0), Vector3(0.06, h, d), wood)
	for sz: float in [-1.0, 1.0]:
		mb.box_at(&"planks", Vector3(0, h * 0.5, sz * (d * 0.5 - 0.03)), Vector3(w - 0.12, h, 0.06), wood.darkened(0.05))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.box_at(&"steel", Vector3(sx * (w * 0.5 - 0.02), h * 0.5, sz * (d * 0.5 - 0.02)), Vector3(0.07, h + 0.02, 0.07), Color(0.22, 0.22, 0.23))
	mb.box_at(&"paint", Vector3(0, h * 0.55, d * 0.5 + 0.005), Vector3(0.7, 0.24, 0.01), Color(0.9, 0.86, 0.74))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	add_child(mi)
	var label := Label3D.new()
	label.text = tr("UI_SHIPPING_BIN_SIGN")
	label.font = UiTheme.font(800)
	label.font_size = 26
	label.pixel_size = 0.0022
	label.modulate = Color(0.2, 0.14, 0.08)
	label.outline_size = 0
	label.position = Vector3(0, h * 0.55, d * 0.5 + 0.012)
	add_child(label)
	# Whose goods they are: the farm's name under it (FarmIdentity).
	var farm_line := FarmNameLabel.new()
	farm_line.pixel_size = 0.0022
	farm_line.max_size = 13
	farm_line.fit_width = 0.62
	farm_line.modulate = Color(0.32, 0.2, 0.12)
	farm_line.position = Vector3(0, h * 0.55 - 0.085, d * 0.5 + 0.012)
	add_child(farm_line)
	_lid = Node3D.new()
	_lid.position = Vector3(0, h, -d * 0.5)
	# A tween swings it every frame, not in physics steps.
	_lid.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_lid)
	var lb := MeshBuilder.new()
	lb.box_at(&"planks", Vector3(0, 0.03, d * 0.5), Vector3(w + 0.04, 0.06, d + 0.04), wood.lightened(0.05))
	lb.box_at(&"steel", Vector3(0, 0.07, d - 0.05), Vector3(0.25, 0.03, 0.04), Color(0.22, 0.22, 0.23))
	var lid_mi := MeshInstance3D.new()
	lid_mi.mesh = lb.build()
	_lid.add_child(lid_mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, h + 0.06, d)
	cs.shape = box
	cs.position.y = (h + 0.06) * 0.5
	add_child(cs)
	# Where the story's guide dot floats over the bin.
	var spot := Marker3D.new()
	spot.position = Vector3(0, 1.1, 0)
	add_child(spot)
	WaypointMarker.tag(spot, &"shipping_bin")
	Events.day_ending.connect(_sell_contents)


func interact_prompt(_player: Node) -> String:
	return tr("ACTION_OPEN")


func interact(_player: Node) -> void:
	_set_open(true)
	Game.hud.open_container(inventory, tr("UI_SHIPPING_BIN"), _set_open.bind(false))


func _set_open(open: bool) -> void:
	var tw := create_tween()
	tw.tween_property(_lid, "rotation:x", -1.4 if open else 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The courier keeps a quarter; selling in town pays the full market price.
const COMMISSION_FACTOR := 0.75


func _sell_contents() -> void:
	for i in inventory.size():
		var s := inventory.get_stack(i)
		if s == null:
			continue
		if s.item.sell_price > 0:
			Economy.sell(s.item.id, s.count, s.quality, "REPORT_SHIPPING", COMMISSION_FACTOR)
			inventory.slots[i] = null
	# What stays (goods without a price) was reported already.
	_reported = _counts()
	inventory.changed.emit()


## Reports goods that came into the bin: Events.shipped(item id, how many more).
func _on_contents_changed() -> void:
	var now := _counts()
	for id: StringName in now:
		var more := int(now[id]) - int(_reported.get(id, 0))
		if more > 0:
			_reported[id] = int(now[id])
			Events.shipped.emit(id, more)


## item id -> units in the bin now.
func _counts() -> Dictionary:
	var out := {}
	for s in inventory.slots:
		if s != null:
			out[s.item.id] = int(out.get(s.item.id, 0)) + s.count
	return out


## Units in the bin of an item id or of a whole category ("crop", "animal_product"),
## for goals that ask what waits in it.
static func count_in_bin(what: StringName) -> int:
	var n := 0
	for s in FarmState.get_storage(STORAGE_ID, SLOTS).slots:
		if s != null and (s.item.id == what or StringName(s.item.category) == what):
			n += s.count
	return n
