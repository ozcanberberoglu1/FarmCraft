@tool
class_name Chest
extends StaticBody3D
## Wooden storage chest with iron bands. Interacting opens the chest next to the
## player inventory; the lid swings open while the window is shown.

@export var slots := 16
## Key of this chest's inventory in FarmState.storage (kept across rebuilds).
@export var storage_id := ""
@export var title_key := "UI_CHEST"
## Items placed in the chest for a new game: [[id, count], ...]
@export var starting_items: Array = []
## Grandpa's old chest in the run-down house: grey boards and rusty bands.
@export var worn := false

const W := 0.9
const H := 0.46
const D := 0.54
const LID_H := 0.16

var inventory: Inventory
var _lid_pivot: Node3D
var _tween: Tween


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(&"persist")
	_build()
	if not Engine.is_editor_hint():
		if storage_id == "":
			storage_id = "chest_%d" % get_instance_id()
		var fresh := not FarmState.storage.has(storage_id)
		inventory = FarmState.get_storage(storage_id, slots)
		if fresh:
			for entry in starting_items:
				inventory.add_item(entry[0], entry[1])


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var body := MeshBuilder.new()
	var plank_key: StringName = &"planks_old" if worn else &"planks"
	var iron_key: StringName = &"rusty" if worn else &"steel"
	var wood: Color = Color(0.5, 0.49, 0.47) if worn else Color(0.52, 0.46, 0.42)
	var iron: Color = Color(0.36, 0.25, 0.18) if worn else Color(0.24, 0.24, 0.25)
	body.box_at(plank_key, Vector3(0, H * 0.5, 0), Vector3(W, H, D), wood, Vector3.ZERO, false)
	body.box_at(&"wood_in", Vector3(0, H - 0.01, 0), Vector3(W - 0.06, 0.02, D - 0.06), Color(0.3, 0.26, 0.23))
	for sx: float in [-1.0, 1.0]:
		# Iron corner straps and side handles.
		body.box_at(iron_key, Vector3(sx * (W * 0.5 - 0.025), H * 0.5, D * 0.5 + 0.004), Vector3(0.05, H + 0.006, 0.01), iron)
		body.box_at(iron_key, Vector3(sx * (W * 0.5 - 0.025), H * 0.5, -D * 0.5 - 0.004), Vector3(0.05, H + 0.006, 0.01), iron)
		body.box_at(iron_key, Vector3(sx * (W * 0.5 + 0.004), H * 0.5, 0), Vector3(0.01, H + 0.006, D * 0.3), iron)
		body.loft(iron_key, [Vector3(sx * (W * 0.5 + 0.01), H * 0.62, -0.07), Vector3(sx * (W * 0.5 + 0.045), H * 0.56, 0),
				Vector3(sx * (W * 0.5 + 0.01), H * 0.62, 0.07)], [0.008, 0.008, 0.008], 6, iron, false)
	body.box_at(iron_key, Vector3(0, H - 0.06, D * 0.5 + 0.006), Vector3(0.1, 0.1, 0.012), iron)
	body.box_at(iron_key, Vector3(0, H - 0.075, D * 0.5 + 0.013), Vector3(0.03, 0.035, 0.006), Color(0.62, 0.52, 0.28))
	var mi := MeshInstance3D.new()
	mi.mesh = body.build()
	add_child(mi)

	# Lid on its own pivot along the back edge so it can open.
	_lid_pivot = Node3D.new()
	_lid_pivot.position = Vector3(0, H, -D * 0.5)
	add_child(_lid_pivot)
	var lid := MeshBuilder.new()
	var arc_segments := 8
	for i in arc_segments:
		var a0 := PI * float(i) / arc_segments
		var a1 := PI * float(i + 1) / arc_segments
		var z0 := D * 0.5 - cos(a0) * D * 0.5
		var z1 := D * 0.5 - cos(a1) * D * 0.5
		var y0 := sin(a0) * LID_H
		var y1 := sin(a1) * LID_H
		var mid := Vector3(0, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
		var seg_len := Vector2(z1 - z0, y1 - y0).length()
		var ang := atan2(y1 - y0, z1 - z0)
		lid.box(plank_key, Transform3D(Basis(Vector3.RIGHT, -ang), mid), Vector3(W + 0.02, 0.025, seg_len + 0.004), wood)
	for x: float in [-W * 0.5 + 0.03, 0.0, W * 0.5 - 0.03]:
		var band: Array[Vector3] = []
		var band_r: Array[float] = []
		for i in arc_segments + 1:
			var a := PI * float(i) / arc_segments
			band.append(Vector3(x, sin(a) * (LID_H + 0.014), D * 0.5 - cos(a) * (D * 0.5 + 0.012)))
			band_r.append(0.012)
		lid.loft(iron_key, band, band_r, 4, iron, false)
	lid.box_at(&"wood_in", Vector3(0, 0.006, D * 0.5), Vector3(W - 0.04, 0.012, D - 0.04), Color(0.3, 0.26, 0.23))
	var lid_mi := MeshInstance3D.new()
	lid_mi.mesh = lid.build()
	_lid_pivot.add_child(lid_mi)

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(W, H + LID_H, D)
	cs.shape = box
	cs.position.y = (H + LID_H) * 0.5
	add_child(cs)


func interact_prompt(_player: Node) -> String:
	return tr("ACTION_OPEN")


func interact(_player: Node) -> void:
	_set_open(true)
	Game.hud.open_container(inventory, tr(title_key), _set_open.bind(false))


func _set_open(open: bool) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_lid_pivot, "rotation:x", -1.9 if open else 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


