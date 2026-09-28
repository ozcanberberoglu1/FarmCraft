class_name VehicleHUD
extends Control
## Dashboard shown while driving: speed, fuel, load in the bed (units and weight),
## lights and the key hints (E get out, V camera, L lights, Space handbrake).

var _speed: Label
var _fuel_bar: StatBar
var _fuel_label: Label
var _cargo_label: Label
var _lights: TextureRect
var _name: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# (In the tree, plain set_anchors_preset would keep the current zero-size rect.)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := GlassPanel.new(Vector4(22, 14, 22, 16), 18.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	add_child(card)
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_left = -28
	card.offset_right = -28
	card.offset_top = -28
	card.offset_bottom = -28
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	_name = UiTheme.make_label("", UiTheme.heading(16, UiTheme.TEXT_MUTED, 700, 3))
	col.add_child(_name)
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 8)
	speed_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(speed_row)
	_speed = UiTheme.make_label("0", UiTheme.heading(76, UiTheme.TEXT, 700, 1))
	_speed.custom_minimum_size = Vector2(140, 0)
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_row.add_child(_speed)
	var unit := UiTheme.make_label("KM/H", UiTheme.heading(20, UiTheme.GOLD_SOFT, 700, 2))
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	speed_row.add_child(unit)
	speed_row.add_child(UiTheme.expand())
	_lights = UiTheme.icon_rect(UiTheme.glyph("headlight"), 30, UiTheme.TEXT_DIM)
	_lights.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speed_row.add_child(_lights)
	var fuel_row := HBoxContainer.new()
	fuel_row.add_theme_constant_override("separation", 10)
	fuel_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(fuel_row)
	fuel_row.add_child(UiTheme.icon_rect(UiTheme.glyph("fuel"), 22, UiTheme.TEXT_MUTED))
	_fuel_bar = StatBar.new(8.0)
	_fuel_bar.custom_minimum_size = Vector2(200, 8)
	_fuel_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fuel_row.add_child(_fuel_bar)
	_fuel_label = UiTheme.make_label("", UiTheme.heading(18, UiTheme.TEXT, 700, 0))
	_fuel_label.custom_minimum_size = Vector2(56, 0)
	_fuel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fuel_row.add_child(_fuel_label)
	var cargo_row := HBoxContainer.new()
	cargo_row.add_theme_constant_override("separation", 10)
	cargo_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cargo_row)
	cargo_row.add_child(UiTheme.icon_rect(UiTheme.glyph("box"), 22, UiTheme.TEXT_MUTED))
	_cargo_label = UiTheme.make_label("", UiTheme.heading(18, UiTheme.TEXT, 700, 1))
	cargo_row.add_child(_cargo_label)
	col.add_child(UiTheme.separator())
	var hints := HBoxContainer.new()
	hints.add_theme_constant_override("separation", 12)
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hints)
	for h: Array in [["E", "ACTION_EXIT_VEHICLE"], ["V", "HINT_CAMERA"], ["L", "HINT_LIGHTS"], ["SPACE", "HINT_HANDBRAKE"]]:
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 5)
		pair.add_child(UiTheme.keycap(h[0], 13))
		var l := UiTheme.make_label(UiTheme.caps(tr(h[1])), UiTheme.heading(13, UiTheme.TEXT_MUTED, 700, 1))
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(l)
		hints.add_child(pair)
	visible = false


func _process(_delta: float) -> void:
	var v: Vehicle = Game.player.driving if Game.player and Game.player.get("driving") else null
	visible = v != null and not Game.is_ui_open()
	if v == null:
		return
	_name.text = UiTheme.caps(v.display_name())
	_speed.text = str(roundi(v.speed_kmh()))
	_fuel_bar.set_value(v.fuel_ratio() * 100.0, false)
	_fuel_label.text = "%d L" % roundi(v.fuel)
	_cargo_label.text = "%d / %d  ·  %d kg" % [v.cargo.total(), v.cargo.capacity, roundi(v.cargo_kg())]
	_lights.modulate = Color("8fd0ff") if v.lights_on else UiTheme.TEXT_DIM
