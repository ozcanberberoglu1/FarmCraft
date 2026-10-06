class_name NameBoard
extends StaticBody3D
## Grandpa's old name board at the farm's entrance, where the house lane meets the track
## to the county road (WorldLayout.NAME_BOARD_POS): two posts, a face of boards under a
## little rain cap, a frame round it. On a new farm its paint has flaked off: grey boards,
## a few pale scabs of the old coat, no name to read. E opens the naming prompt
## (PetNameScreen: a name in the field, a few ideas under it, FarmIdentity.MAX_NAME
## letters; an empty field or Esc keeps what it is called); the board then wears a fresh
## cream coat with the name in hand-painted capitals, sized to fit (two lines for a long
## one), a line of the farm's last paint colour under it. E on it again at any time
## renames the farm. With a can of paint in hand, LMB paints its frame (Painter).
## The story's "farm_name" goal points here (its waypoint anchor ANCHOR).

const GROUP := &"name_board"
const ANCHOR := &"name_board"
## The face: width, height, the height of its middle over the ground.
const FACE := Vector2(2.5, 0.92)
const FACE_Y := 1.72
## The room the letters have on it.
const TEXT_BOX := Vector2(2.24, 0.6)
const PIXEL := 0.004
## The largest its letters are painted (font size, at PIXEL metres a pixel).
const MAX_LETTERS := 132
const WOOD_OLD := Color(0.5, 0.49, 0.47)
const COAT := Color(0.95, 0.89, 0.74)
const INK := Color(0.2, 0.13, 0.08)

var _face: MeshInstance3D
var _frame: MeshInstance3D
var _text: Label3D
var _naming: PetNameScreen


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(GROUP)
	add_to_group(FarmIdentity.LISTENERS)
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1958
	# The posts, set a hand into the ground, and the rain cap over the face.
	for sx: float in [-1.0, 1.0]:
		mb.box_at(&"wood_old", Vector3(sx * (FACE.x * 0.5 + 0.12), 1.2, -0.02), Vector3(0.14, 2.6, 0.14), WOOD_OLD.darkened(0.12), Vector3(0, 0, sx * -0.6))
		mb.box_at(&"wood_old", Vector3(sx * (FACE.x * 0.5 + 0.12), 2.52, -0.02), Vector3(0.19, 0.05, 0.19), WOOD_OLD.darkened(0.2))
	for sz: float in [-1.0, 1.0]:
		mb.box_at(&"planks_old", Vector3(0, FACE_Y + FACE.y * 0.5 + 0.2, sz * 0.11), Vector3(FACE.x + 0.62, 0.03, 0.28), WOOD_OLD.lightened(0.04),
				Vector3(sz * 24.0, 0, 0), true)
	# The boards of the face (their backs stay bare wood).
	var rows := 5
	var bh := FACE.y / rows
	for k in rows:
		var v := rng.randf_range(0.9, 1.05)
		mb.box_at(&"planks_old", Vector3(rng.randf_range(-0.01, 0.01), FACE_Y - FACE.y * 0.5 + (k + 0.5) * bh, 0.0), Vector3(FACE.x, bh - 0.008, 0.04),
				Color(WOOD_OLD.r * v, WOOD_OLD.g * v, WOOD_OLD.b * v), Vector3.ZERO, true)
	# Two battens behind hold them together.
	for sx: float in [-0.8, 0.8]:
		mb.box_at(&"wood_old", Vector3(sx, FACE_Y, -0.035), Vector3(0.09, FACE.y - 0.06, 0.03), WOOD_OLD.darkened(0.15))
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = mb.build()
	add_child(body)
	# The frame round the face: its own mesh, so a coat of paint goes on it alone.
	var fb := MeshBuilder.new()
	var fw := 0.075
	var tone := Color(0.42, 0.4, 0.37)
	for sy: float in [-1.0, 1.0]:
		fb.box_at(&"paint", Vector3(0, FACE_Y + sy * (FACE.y * 0.5 - fw * 0.5 + 0.02), 0.03), Vector3(FACE.x + 0.04, fw, 0.03), tone, Vector3.ZERO, true)
	for sx: float in [-1.0, 1.0]:
		fb.box_at(&"paint", Vector3(sx * (FACE.x * 0.5 - fw * 0.5 + 0.02), FACE_Y, 0.03), Vector3(fw, FACE.y - fw * 2.0 + 0.04, 0.03), tone.darkened(0.05))
	_frame = MeshInstance3D.new()
	_frame.name = "Frame"
	_frame.mesh = fb.build()
	add_child(_frame)
	_face = MeshInstance3D.new()
	_face.name = "Face"
	add_child(_face)
	_text = Label3D.new()
	_text.name = "Name"
	_text.font = UiTheme.display(700, 2)
	_text.pixel_size = PIXEL
	_text.outline_size = 0
	_text.modulate = INK
	_text.shaded = true
	_text.double_sided = false
	_text.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	_text.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_text.position = Vector3(0, FACE_Y + 0.03, 0.036)
	# Painted by hand: not quite level.
	_text.rotation_degrees.z = 1.2
	_text.visibility_range_end = 110.0
	_text.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_text)
	for sx: float in [-1.0, 1.0]:
		var post := CollisionShape3D.new()
		var pbox := BoxShape3D.new()
		pbox.size = Vector3(0.16, 2.6, 0.16)
		post.shape = pbox
		post.position = Vector3(sx * (FACE.x * 0.5 + 0.12), 1.3, -0.02)
		add_child(post)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(FACE.x + 0.1, FACE.y + 0.1, 0.1)
	cs.shape = box
	cs.position = Vector3(0, FACE_Y, 0.0)
	add_child(cs)
	var spot := Marker3D.new()
	spot.name = "Guide"
	spot.position = Vector3(0, FACE_Y + FACE.y * 0.5 + 0.75, 0.1)
	add_child(spot)
	WaypointMarker.tag(spot, ANCHOR)
	refresh()


## Where the story's dot floats (over the board).
func guide_point() -> Vector3:
	return global_transform * Vector3(0, FACE_Y + FACE.y * 0.5 + 0.75, 0.1)


## The face as it is now: bare grey boards with scabs of old paint, or the fresh coat
## with the farm's name on it.
func refresh() -> void:
	if _face == null:
		return
	var mb := MeshBuilder.new()
	var named := FarmIdentity.is_named()
	var coats := {}
	if named:
		# A fresh coat over the old boards (their grain shows through it: Painter.coat).
		mb.box_at(&"coat", Vector3(0, FACE_Y, 0.024), Vector3(FACE.x - 0.1, FACE.y - 0.1, 0.008), COAT, Vector3.ZERO, true)
		coats[&"coat"] = Painter.coat(&"paint", COAT)
		# A brushed line under the name, in the colour last used on the farm.
		mb.box_at(&"line", Vector3(0, FACE_Y - FACE.y * 0.5 + 0.13, 0.029), Vector3(FACE.x * 0.62, 0.03, 0.004), COAT, Vector3(0, 0, 0.5), true)
		coats[&"line"] = Painter.painted(&"paint", FarmIdentity.last_color())
	else:
		# What is left of Grandpa's coat: pale scabs here and there.
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in 14:
			var w := rng.randf_range(0.1, 0.34)
			var h := rng.randf_range(0.03, 0.09)
			var p := Vector3(rng.randf_range(-FACE.x * 0.5 + 0.25, FACE.x * 0.5 - 0.25), FACE_Y + rng.randf_range(-FACE.y * 0.5 + 0.12, FACE.y * 0.5 - 0.12), 0.0215)
			var v := rng.randf_range(0.6, 0.78)
			mb.box_at(&"paint_old", p, Vector3(w, h, 0.004), Color(v, v * 0.97, v * 0.9), Vector3(0, 0, rng.randf_range(-3.0, 3.0)), true)
	_face.mesh = mb.build(coats)
	_write(FarmIdentity.farm_name() if named else "")


## Writes `text` on the face in capitals, as large as fits: on one line, or on two (broken
## at the space nearest its middle) when that writes it larger.
func _write(text: String) -> void:
	var t := UiTheme.caps(text.strip_edges())
	var one := _fit(PackedStringArray([t]))
	var best := -1
	for i in t.length():
		if t[i] == " " and (best < 0 or absi(i - t.length() / 2) < absi(best - t.length() / 2)):
			best = i
	var size := one
	if best > 0:
		var halves := PackedStringArray([t.substr(0, best), t.substr(best + 1)])
		var two := _fit(halves)
		if two > one:
			size = two
			t = "\n".join(halves)
	_text.font_size = size
	_text.line_spacing = -size * 0.16
	_text.text = t


## The largest letters (font size) `lines` can be written in within TEXT_BOX.
func _fit(lines: PackedStringArray) -> int:
	var font := _text.font
	var size := MAX_LETTERS
	while size > 24:
		var widest := 0.0
		for l: String in lines:
			widest = maxf(widest, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		var tall := font.get_height(size) * (1.0 + (lines.size() - 1) * 0.84) * 0.8
		if widest * PIXEL <= TEXT_BOX.x and tall * PIXEL <= TEXT_BOX.y:
			break
		size -= 4
	return size


## What is written on the board now ("" on the bare one; tests).
func shown_name() -> String:
	return _text.text.replace("\n", " ") if _text else ""


func farm_identity_changed(_what: StringName) -> void:
	refresh()


# --- Prompts ----------------------------------------------------------------------------------

func interact_title() -> String:
	return FarmIdentity.farm_name() if FarmIdentity.is_named() else tr("NAME_BOARD_TITLE")


func interact_prompt(_player: Node) -> String:
	return tr("ACTION_RENAME_FARM") if FarmIdentity.is_named() else tr("ACTION_NAME_FARM")


func interact(_player: Node) -> void:
	open_prompt()


## The naming prompt: the name it has (Grandpa's on a new farm) in the field, a few ideas
## under it.
func open_prompt() -> void:
	if Game.hud == null or not is_instance_valid(Game.hud):
		return
	if _naming == null or not is_instance_valid(_naming):
		_naming = PetNameScreen.new()
		_naming.named.connect(_on_named)
		Game.hud.add_child(_naming)
	_naming.open(FarmIdentity.farm_name(), tr("FARM_NAME_TITLE"), tr("FARM_NAME_SUB"), "home", FarmIdentity.name_ideas())
	# A farm's name is longer than a hen's (the prompt cut it to a hen's length: put it back).
	_naming.edit.max_length = FarmIdentity.MAX_NAME
	_naming.edit.text = FarmIdentity.farm_name()
	_naming.edit.custom_minimum_size.x = 560
	_naming.edit.add_theme_font_size_override("font_size", 30)


## The prompt while it is open (tests answer it), else null.
func naming_screen() -> PetNameScreen:
	return _naming if _naming != null and is_instance_valid(_naming) and _naming.visible else null


func _on_named(chosen: String) -> void:
	var first := not FarmIdentity.is_named()
	FarmIdentity.set_farm_name(chosen)
	Audio.play("brush", global_position + Vector3(0, FACE_Y, 0.2), -6.0)
	Game.notify(tr("MSG_FARM_NAMED" if first else "MSG_FARM_RENAMED") % FarmIdentity.farm_name(), UiTheme.GREEN)


# --- Paint (Painter) ----------------------------------------------------------------------------

func use_prompt(_player: Node, stack: ItemStack) -> String:
	return Painter.use_prompt(self, stack)


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	return Painter.use_action(self, stack)


func use_impact(_player: Node, stack: ItemStack, _action: Dictionary, hit: Dictionary) -> void:
	Painter.use_impact(self, stack, hit)


func complete_use(_player: Node, stack: ItemStack, _action: Dictionary) -> void:
	Painter.complete_use(self, stack)
