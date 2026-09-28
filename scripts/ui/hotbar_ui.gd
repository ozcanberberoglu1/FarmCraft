class_name HotbarUI
extends Control
## The 8 quick slots at the bottom of the screen (first slots of the inventory) on
## a glass strip; the selected item's name shows above it for a moment. On a new farm
## it stays hidden until the first item comes into the bag, then rises in (reveal).

const GAP := 8

var _slots: Array[SlotUI] = []
var _strip: GlassPanel
var _name: Label
var _name_tween: Tween
var _reveal_tween: Tween
var _hint: Control
## offset_top and offset_bottom where the strip rests (the reveal rises to them).
var _rest := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var count := PlayerState.HOTBAR_SIZE
	var width := count * SlotUI.SIZE.x + (count - 1) * GAP + 20
	var height := SlotUI.SIZE.y + 20
	UiTheme.place(self, Vector2(0.5, 1.0), Vector2(-width * 0.5, -height - 22), Vector2(width, height))
	_rest = Vector2(offset_top, offset_bottom)
	_strip = GlassPanel.new(Vector4(10, 10, 10, 10), 18.0)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_child(row)
	for i in count:
		var slot := SlotUI.new()
		row.add_child(slot)
		slot.setup(PlayerState.inventory, i, i + 1)
		_slots.append(slot)
	_name = UiTheme.make_label("", UiTheme.heading(26, UiTheme.TEXT, 700, 2, true))
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.position = Vector2(0, -44)
	_name.size = Vector2(width, 34)
	_name.modulate.a = 0.0
	add_child(_name)
	PlayerState.inventory.changed.connect(_refresh)
	PlayerState.selected_changed.connect(_on_selected)
	_on_selected(PlayerState.selected)


func _refresh() -> void:
	for s in _slots:
		s.refresh()


func _on_selected(slot: int) -> void:
	for i in _slots.size():
		_slots[i].selected = i == slot
	var s := PlayerState.inventory.get_stack(slot)
	_name.text = UiTheme.caps(s.display_name()) if s else ""
	if _name_tween:
		_name_tween.kill()
	_name.modulate.a = 1.0
	_name_tween = create_tween()
	_name_tween.tween_interval(1.6)
	_name_tween.tween_property(_name, "modulate:a", 0.0, 0.6)


## The first item on a new farm: the strip rises into place, its slots light up left
## to right, the item's name shows, and a "Tab  Inventory" hint sits over the strip's
## right end for a while. Only modulate is animated on the slots: their container
## resets a child's position and scale.
func reveal() -> void:
	if _reveal_tween and _reveal_tween.is_valid():
		_reveal_tween.kill()
	offset_top = _rest.x + 90.0
	offset_bottom = _rest.y + 90.0
	modulate.a = 0.0
	for s in _slots:
		s.modulate.a = 0.0
	_reveal_tween = create_tween().set_parallel(true)
	_reveal_tween.tween_property(self, "offset_top", _rest.x, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(self, "offset_bottom", _rest.y, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	for i in _slots.size():
		_reveal_tween.tween_property(_slots[i], "modulate:a", 1.0, 0.25).set_delay(0.25 + i * 0.06)
	_reveal_tween.chain().tween_callback(func() -> void: _on_selected(PlayerState.selected))
	_show_tab_hint()


func _show_tab_hint() -> void:
	if is_instance_valid(_hint):
		_hint.queue_free()
	var hint := HBoxContainer.new()
	hint.add_theme_constant_override("separation", 8)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(UiTheme.keycap(tr("KEY_TAB"), 16))
	var l := UiTheme.make_label(UiTheme.caps(tr("UI_INVENTORY")), UiTheme.heading(18, UiTheme.TEXT, 700, 2, true))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.add_child(l)
	add_child(hint)
	# Over the strip's right end, clear of the item name in the middle.
	hint.reset_size()
	hint.position = Vector2(size.x - hint.size.x - 12.0, -hint.size.y - 10.0)
	hint.modulate.a = 0.0
	_hint = hint
	var tw := hint.create_tween()
	tw.tween_property(hint, "modulate:a", 1.0, 0.35).set_delay(1.0)
	tw.tween_interval(8.0)
	tw.tween_property(hint, "modulate:a", 0.0, 0.6)
	tw.tween_callback(hint.queue_free)
