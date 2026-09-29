class_name ForSaleSign
extends StaticBody3D
## Wooden "for sale" sign on an unbuilt lot, or "needs repair" by one of Grandpa's
## run-down buildings. Interacting opens the construction board at this project.

var project_id: StringName
## Header text: "SIGN_FOR_SALE" on empty lots, "SIGN_REPAIR" by a run-down building.
var header_key := "SIGN_FOR_SALE"
## Colour of the painted strip behind the header.
var accent := Color(0.72, 0.16, 0.12)

var _title: Label3D
var _price: Label3D


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	var mb := MeshBuilder.new()
	var wood := Color(0.5, 0.47, 0.44)
	for sx: float in [-0.55, 0.55]:
		mb.box_at(&"wood", Vector3(sx, 0.75, 0), Vector3(0.1, 1.5, 0.1), wood.darkened(0.15), Vector3.ZERO, true)
	mb.box_at(&"planks", Vector3(0, 1.22, 0.02), Vector3(1.5, 0.62, 0.05), wood)
	mb.box_at(&"paint", Vector3(0, 1.22, 0.048), Vector3(1.38, 0.5, 0.01), Color(0.93, 0.9, 0.82))
	mb.box_at(&"paint", Vector3(0, 1.4, 0.052), Vector3(1.38, 0.14, 0.01), accent)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	add_child(mi)
	var header := _label(tr(header_key), 30, Color(1, 1, 1), Vector3(0, 1.4, 0.06))
	header.outline_size = 0
	_title = _label("", 22, Color(0.12, 0.1, 0.08), Vector3(0, 1.24, 0.056))
	_price = _label("", 24, Color(0.55, 0.12, 0.08), Vector3(0, 1.08, 0.056))
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.6, 0.2)
	cs.shape = box
	cs.position.y = 0.8
	add_child(cs)
	refresh()


func _label(text: String, size: int, color: Color, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UiTheme.font(800)
	l.font_size = size
	l.pixel_size = 0.0025
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.shaded = true
	l.double_sided = false
	l.width = 520
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(l)
	return l


func refresh() -> void:
	if _title == null:
		return
	var p := ProjectTable.get_project(project_id)
	_title.text = tr("PROJECT_" + String(project_id).to_upper())
	_price.text = UiTheme.money(int(p.get("cost", 0)))


func interact_prompt(_player: Node) -> String:
	return tr("ACTION_EXAMINE")


func interact(_player: Node) -> void:
	Game.hud.open_build_board(project_id)
