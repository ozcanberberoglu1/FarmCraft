class_name ConstructionBoard
extends StaticBody3D
## Notice board with pinned blueprints. Opens the construction screen.


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	var mb := MeshBuilder.new()
	var wood := Color(0.5, 0.47, 0.44)
	for sx: float in [-0.8, 0.8]:
		mb.box_at(&"wood", Vector3(sx, 1.05, 0), Vector3(0.12, 2.1, 0.12), wood.darkened(0.2), Vector3.ZERO, true)
	mb.box_at(&"planks", Vector3(0, 1.35, 0.02), Vector3(1.8, 1.1, 0.06), wood)
	mb.box_at(&"wood", Vector3(0, 0.78, 0.05), Vector3(1.8, 0.06, 0.1), wood.darkened(0.25))
	# Little roof over the board.
	mb.prism(&"roof", Transform3D(Basis(), Vector3(0, 1.98, 0.0)), 2.1, 0.32, 0.5, Color(0.5, 0.48, 0.47))
	# Pinned blueprints and notes.
	var papers := [[Vector3(-0.45, 1.38, 0.056), Vector2(0.62, 0.46), Color(0.22, 0.38, 0.62), -3.0],
		[Vector3(0.32, 1.52, 0.056), Vector2(0.5, 0.36), Color(0.93, 0.9, 0.8), 4.0],
		[Vector3(0.38, 1.12, 0.056), Vector2(0.56, 0.3), Color(0.24, 0.4, 0.64), 2.0],
		[Vector3(-0.5, 0.98, 0.056), Vector2(0.36, 0.22), Color(0.95, 0.93, 0.85), -5.0]]
	for p: Array in papers:
		mb.box_at(&"paper", p[0], Vector3(p[1].x, p[1].y, 0.006), p[2], Vector3(0, 0, p[3]))
		mb.blob(&"paint", Transform3D(Basis(), (p[0] as Vector3) + Vector3(0, (p[1] as Vector2).y * 0.4, 0.008)), 0.018, 0, Color(0.8, 0.12, 0.1))
	# Blueprint lines on the blue sheets.
	for i in 4:
		mb.box_at(&"paper", Vector3(-0.45, 1.25 + i * 0.07, 0.061), Vector3(0.42, 0.008, 0.002), Color(0.8, 0.88, 1.0), Vector3(0, 0, -3.0))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	add_child(mi)
	var title := Label3D.new()
	title.text = tr("UI_BUILD_BOARD")
	title.font = UiTheme.font(800)
	title.font_size = 34
	title.pixel_size = 0.0025
	title.modulate = Color(0.95, 0.92, 0.85)
	title.outline_size = 8
	title.outline_modulate = Color(0.15, 0.1, 0.06)
	title.position = Vector3(0, 1.8, 0.07)
	add_child(title)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 2.1, 0.3)
	cs.shape = box
	cs.position.y = 1.05
	add_child(cs)


func interact_prompt(_player: Node) -> String:
	return tr("ACTION_BUILD")


func interact(_player: Node) -> void:
	Game.hud.open_build_board()
