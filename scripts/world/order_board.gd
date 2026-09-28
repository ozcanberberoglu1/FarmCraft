class_name OrderBoard
extends StaticBody3D
## The chalkboard outside the town market where townsfolk leave orders (Quests.orders).
## Chalk writing on the slate shows the heading and the open orders ("Carrot ×23"); E
## opens the order list.

## The slate of the scanned board: its face is SLATE_Z in front of the origin at 0.6 m
## and leans back TILT degrees; the writable part is 0.33–1.43 m high, 0.79 m wide.
const TILT := 12.0
const SLATE_Z := 0.24
const WRITE_WIDTH := 0.66
const PIXEL := 0.0022

var _lines: Array[Label3D] = []


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(&"order_board")
	var mi := MeshInstance3D.new()
	mi.mesh = PlaceableModels.mesh(&"order_board", "whole")
	add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.95, 1.5, 0.3)
	cs.shape = box
	cs.position.y = 0.75
	add_child(cs)
	add_child(_chalk(UiTheme.caps(tr("UI_ORDERS")), 64, 1.27))
	Quests.orders_changed.connect(_refresh)
	_refresh()


## Chalk writing centred at height `y` on the slate, shrunk to fit its width.
func _chalk(text: String, size: int, y: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UiTheme.display(600, 2)
	l.font_size = size
	var w := l.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * PIXEL
	if w > WRITE_WIDTH:
		l.font_size = int(size * WRITE_WIDTH / w)
	l.pixel_size = PIXEL
	l.modulate = Color(0.95, 0.95, 0.9, 0.85)
	l.shaded = true
	l.double_sided = false
	var z := SLATE_Z - (y - 0.6) * tan(deg_to_rad(TILT)) + 0.004
	l.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-TILT)), Vector3(0, y, z))
	return l


func _refresh() -> void:
	for l in _lines:
		l.queue_free()
	_lines.clear()
	var y := 1.08
	for o: Dictionary in Quests.orders:
		var item := ItemDB.get_item(StringName(o["item"]))
		_lines.append(_chalk("%s ×%d" % [item.display_name(), int(o["count"])], 44, y))
		y -= 0.15
	if Quests.orders.is_empty():
		_lines.append(_chalk(tr("UI_ORDERS_OPEN") % 0, 44, y))
	for l in _lines:
		add_child(l)


func interact_prompt(_player: Node) -> String:
	return tr("ACTION_ORDERS")


func interact(_player: Node) -> void:
	Game.hud.open_orders()
