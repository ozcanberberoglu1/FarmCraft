class_name NewsBanner
extends Control
## A short note of news in town (SideStory: a new neighbour has moved in): a glass card
## under the top of the screen with a small kicker line, a title and a line of text, an
## icon on each side and a rim in the news' colour that glows softly. It floats in,
## stays a while and fades away, then frees itself. Hidden while a window is open.

const TOP := 150.0
const WIDTH := 760.0
const HOLD := 6.5
const FADE_OUT := 2.6

var _card: GlassPanel
var _box: Control
var _color := UiTheme.GOLD
var _age := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = Control.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.place(_box, Vector2(0.5, 0.0), Vector2(-WIDTH * 0.5, TOP), Vector2(WIDTH, 150))
	add_child(_box)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(center)
	_card = GlassPanel.new(Vector4(34, 18, 34, 20), 22.0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_card)


## Shows `title` over `line` under a `kicker`, with `icon_name` (UiTheme.glyph) in
## `color`, then fades away.
func play(kicker: String, title: String, line: String, icon_name: String, color: Color) -> void:
	_color = color
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)
	row.add_child(UiTheme.icon_rect(UiTheme.glyph(icon_name), 36, color))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var top := UiTheme.make_label(UiTheme.caps(kicker), UiTheme.heading(15, color, 700, 4))
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(top)
	var head := UiTheme.make_label(title, UiTheme.heading(34, UiTheme.GOLD_SOFT, 700, 1, true))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var sub := UiTheme.make_label(line, UiTheme.text(18, UiTheme.TEXT, 500))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(WIDTH - 200.0, 0)
	col.add_child(sub)
	row.add_child(UiTheme.icon_rect(UiTheme.glyph(icon_name), 36, UiTheme.GOLD_SOFT))
	_rim(0.0)
	modulate.a = 0.0
	_box.position.y += 24.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_box, "position:y", _box.position.y - 24.0, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(HOLD)
	tw.chain().tween_property(self, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_box, "position:y", _box.position.y - 40.0, FADE_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


## The rim breathes between the news' colour and a softer one.
func _rim(t: float) -> void:
	var c := _color.lerp(UiTheme.GOLD_SOFT, 0.35 + 0.35 * sin(t * 1.6))
	_card.set_look(UiTheme.GLASS, Color(c, 0.8), Color(c, 0.35))


func _process(delta: float) -> void:
	_age += delta
	visible = not Game.is_ui_open()
	if _card:
		_rim(_age)
