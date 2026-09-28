class_name StatBar
extends Control
## Rounded meter with a colour that runs from red (low) through amber to green, or
## a fixed colour. Animates towards new values.

var value := 0.0
var max_value := 100.0
var fixed_color := Color(0, 0, 0, 0)
var bar_height := 10.0

var _shown := 0.0


func _init(height := 10.0, color := Color(0, 0, 0, 0)) -> void:
	bar_height = height
	fixed_color = color
	custom_minimum_size = Vector2(120, height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(v: float, animate := true) -> void:
	value = v
	if not animate:
		_shown = v
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_shown = move_toward(_shown, value, max_value * delta * 2.5)
	queue_redraw()
	if is_equal_approx(_shown, value):
		set_process(false)


func color_for(ratio: float) -> Color:
	if fixed_color.a > 0.0:
		return fixed_color
	if ratio < 0.5:
		return UiTheme.RED.lerp(Color("f2b64a"), ratio * 2.0)
	return Color("f2b64a").lerp(UiTheme.GREEN, (ratio - 0.5) * 2.0)


func _draw() -> void:
	var h := minf(bar_height, size.y)
	var y := (size.y - h) * 0.5
	var r := h * 0.5
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.08)
	track.set_corner_radius_all(int(r))
	track.anti_aliasing = true
	draw_style_box(track, Rect2(0, y, size.x, h))
	var ratio := clampf(_shown / maxf(max_value, 0.001), 0.0, 1.0)
	if ratio <= 0.0:
		return
	var fill := StyleBoxFlat.new()
	var col := color_for(clampf(value / maxf(max_value, 0.001), 0.0, 1.0))
	fill.bg_color = col
	fill.set_corner_radius_all(int(r))
	fill.anti_aliasing = true
	fill.shadow_color = Color(col, 0.35)
	fill.shadow_size = 6
	draw_style_box(fill, Rect2(0, y, maxf(size.x * ratio, h), h))
