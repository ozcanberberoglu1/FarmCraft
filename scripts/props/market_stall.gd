class_name MarketStall
extends StaticBody3D
## Timber market stall with a striped canvas awning and crates of goods.
## `shop` is the stall's stock definition for ShopScreen; `animals` opens the
## livestock dealer instead.

@export var title_key := "UI_MERCHANT"
@export var awning_color := Color(0.62, 0.14, 0.1)
@export var animals := false
@export var display_items: Array[StringName] = [&"tomato", &"carrot", &"pumpkin", &"potato"]


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	var mb := MeshBuilder.new()
	var wood := Color(0.52, 0.48, 0.44)
	var w := 3.4
	var d := 1.4
	# Posts, counter and back shelf.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var h := 2.7 if sz < 0.0 else 2.35
			mb.box_at(&"wood", Vector3(sx * (w * 0.5 - 0.08), h * 0.5, sz * (d * 0.5 - 0.08)), Vector3(0.14, h, 0.14), wood.darkened(0.2), Vector3.ZERO, true)
	mb.box_at(&"planks", Vector3(0, 0.48, d * 0.5 - 0.1), Vector3(w - 0.1, 0.96, 0.08), wood)
	mb.box_at(&"planks", Vector3(0, 0.99, d * 0.5 - 0.25), Vector3(w + 0.1, 0.07, 0.6), wood.lightened(0.05))
	mb.box_at(&"planks", Vector3(0, 1.3, -d * 0.5 + 0.2), Vector3(w - 0.2, 0.05, 0.36), wood)
	# Striped awning sloping toward the customer.
	var stripes := 8
	var ang := atan2(0.35, d + 0.6)
	for i in stripes:
		var x := -w * 0.5 - 0.2 + (w + 0.4) * (i + 0.5) / stripes
		var col := awning_color if i % 2 == 0 else Color(0.93, 0.9, 0.84)
		mb.box_at(&"cloth", Vector3(x, 2.55, 0.2), Vector3((w + 0.4) / stripes, 0.04, d + 0.9), col, Vector3(rad_to_deg(ang), 0, 0))
		# Scalloped valance.
		mb.box_at(&"cloth", Vector3(x, 2.25, d * 0.5 + 0.63), Vector3((w + 0.4) / stripes, 0.28, 0.03), col)
	# Crates with goods on the counter.
	for i in display_items.size():
		var cx := -w * 0.5 + 0.55 + i * (w - 1.1) / maxf(display_items.size() - 1, 1)
		var crate := Vector3(cx, 1.03, d * 0.5 - 0.28)
		mb.box_at(&"planks", crate + Vector3(0, 0.1, 0), Vector3(0.62, 0.2, 0.44), wood.lightened(0.08))
		var item_mesh := ItemModels.mesh(display_items[i])
		var aabb := item_mesh.get_aabb()
		var s := 0.16 / maxf(aabb.get_longest_axis_size(), 0.01)
		var rng := RandomNumberGenerator.new()
		rng.seed = i * 17 + 3
		for k in 5:
			var p := crate + Vector3(rng.randf_range(-0.2, 0.2), 0.22, rng.randf_range(-0.12, 0.12))
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p - aabb.get_center() * s)
			_append_mesh(mb, item_mesh, xf)
	# Sacks by the stall.
	for k in 2:
		mb.blob(&"cloth", Transform3D(Basis.from_scale(Vector3(0.8, 1.1, 0.7)), Vector3(w * 0.5 + 0.35, 0.35, -0.1 + k * 0.55)), 0.35, 2, Color(0.72, 0.64, 0.5), 0.12, 2.0, k + 3, 0.0, true, -0.4)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	add_child(mi)
	var sign_label := Label3D.new()
	sign_label.text = tr(title_key)
	sign_label.font = UiTheme.font(800)
	sign_label.font_size = 48
	sign_label.pixel_size = 0.0028
	sign_label.modulate = Color(0.98, 0.95, 0.88)
	sign_label.outline_size = 10
	sign_label.outline_modulate = Color(0.2, 0.12, 0.06)
	sign_label.position = Vector3(0, 2.25, d * 0.5 + 0.66)
	add_child(sign_label)
	for col_data: Array in [[Vector3(0, 0.5, d * 0.5 - 0.1), Vector3(w, 1.0, 0.3)],
			[Vector3(0, 1.3, -d * 0.5 + 0.2), Vector3(w, 2.6, 0.4)]]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = col_data[1]
		cs.shape = box
		cs.position = col_data[0]
		add_child(cs)


## Copies every surface of `mesh` (with its material) into the builder surfaces.
func _append_mesh(mb: MeshBuilder, mesh: ArrayMesh, xf: Transform3D) -> void:
	for si in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(si)
		var key := StringName(mesh.surface_get_name(si))
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var nb := xf.basis.inverse().transposed()
		# Stored order is Godot's front-face order; tri_n expects counter-clockwise input.
		for i in range(0, verts.size(), 3):
			mb.tri_n(key, xf * verts[i], xf * verts[i + 2], xf * verts[i + 1],
					(nb * norms[i]).normalized(), (nb * norms[i + 2]).normalized(), (nb * norms[i + 1]).normalized(),
					cols[i].linear_to_srgb(), cols[i + 2].linear_to_srgb(), cols[i + 1].linear_to_srgb(), uvs[i], uvs[i + 2], uvs[i + 1])


func interact_prompt(_player: Node) -> String:
	return tr("ACTION_SHOP")


func interact(_player: Node) -> void:
	if animals:
		Game.hud.open_rancher()
	else:
		Game.hud.open_shop(ShopStock.general_store())
