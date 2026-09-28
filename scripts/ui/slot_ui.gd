class_name SlotUI
extends Control
## One inventory slot: item icon, stack count, durability / water meters, quality
## star and hotbar number, on a glass card that lights up in gold when selected.
## Supports drag & drop between any inventories, right-click split and shift-click
## quick move (handled by the owning screen through `quick_move`).

signal quick_move(slot: SlotUI)
signal hovered(slot: SlotUI, inside: bool)

const SIZE := Vector2(80, 80)

var inventory: Inventory
var index := 0
var number := -1
var selected := false:
	set(value):
		selected = value
		queue_redraw()

var _icon: TextureRect
var _count: Label
var _number_label: Label
var _hover := false


func setup(inv: Inventory, slot_index: int, hotbar_number := -1) -> void:
	inventory = inv
	index = slot_index
	number = hotbar_number
	refresh()


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_icon.position = Vector2(10, 9)
	_icon.size = Vector2(60, 58)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_count = UiTheme.make_label("", UiTheme.heading(21, UiTheme.TEXT, 700, 0, true))
	_count.position = Vector2(0, SIZE.y - 32)
	_count.size = Vector2(SIZE.x - 8, 26)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_count)
	_number_label = UiTheme.make_label("", UiTheme.heading(14, UiTheme.TEXT_DIM, 700, 0))
	_number_label.position = Vector2(7, 3)
	add_child(_number_label)
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw()
		hovered.emit(self, true))
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw()
		hovered.emit(self, false))
	refresh()


func stack() -> ItemStack:
	return inventory.get_stack(index) if inventory else null


func refresh() -> void:
	if _icon == null:
		return
	var s := stack()
	_icon.texture = s.item.icon if s else null
	_count.text = str(s.count) if s and s.count > 1 else ""
	_number_label.text = str(number) if number > 0 else ""
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var sb: StyleBoxFlat
	if selected:
		sb = UiTheme.glow_box(UiTheme.CARD_ACTIVE, 12, Color(UiTheme.GOLD, 0.95), Color(UiTheme.GOLD, 0.28), 12)
	elif _hover:
		sb = UiTheme.box(UiTheme.CARD_HOVER, 12, 1, Color(1, 1, 1, 0.3))
	else:
		sb = UiTheme.box(Color(0, 0, 0, 0.28), 12, 1, Color(1, 1, 1, 0.09))
	draw_style_box(sb, rect)
	var s := stack()
	if s == null:
		return
	var y := size.y - 9.0
	if s.item.has_durability():
		_meter(y, s.durability_ratio(), UiTheme.RED.lerp(UiTheme.GREEN, s.durability_ratio()))
		y -= 6.0
	if s.item.water_capacity > 0:
		_meter(y, float(s.water) / s.item.water_capacity, UiTheme.BLUE)
	if s.upgrade > 0:
		var font := UiTheme.display(700, 0)
		draw_string(font, Vector2(8, 20), "+%d" % s.upgrade, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.GOLD_SOFT)
	if s.quality > 0:
		var star := UiTheme.glyph("star")
		var col := Color("dfe7f2") if s.quality == ItemStack.Quality.SILVER else UiTheme.GOLD
		draw_texture_rect(star, Rect2(Vector2(size.x - 22, 6), Vector2(15, 15)), false, col)


func _meter(y: float, ratio: float, col: Color) -> void:
	var w := size.x - 22.0
	var track := UiTheme.box(Color(0, 0, 0, 0.55), 2)
	draw_style_box(track, Rect2(11, y, w, 4))
	var fill := UiTheme.box(col, 2)
	draw_style_box(fill, Rect2(11, y, maxf(w * clampf(ratio, 0.0, 1.0), 4.0), 4))


func _get_drag_data(_at: Vector2) -> Variant:
	var s := stack()
	if s == null:
		return null
	var preview := TextureRect.new()
	preview.texture = s.item.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(68, 68)
	preview.position = -preview.size * 0.5
	preview.modulate = Color(1, 1, 1, 0.9)
	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	return {"inventory": inventory, "index": index}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("inventory")


func _drop_data(_at: Vector2, data: Variant) -> void:
	Inventory.transfer(data["inventory"], data["index"], inventory, index)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.shift_pressed:
			quick_move.emit(self)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			inventory.split_half(index)
			accept_event()
