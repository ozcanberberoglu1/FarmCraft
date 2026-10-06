class_name RadioLine
extends CenterContainer
## The car radio's line on the HUD, bottom centre while driving: the station with its
## frequency and the track on air (or that the set is off), with the two keys (R on/off,
## T next station). It comes up for a few seconds when the driver gets in, the set is
## switched, the dial moves or a new track starts (CarRadio.shown), then fades away.

const FADE_IN := 0.25
const HOLD := 5.0
const FADE_OUT := 0.8

## What the line says now (tests read it).
var title := ""
var detail := ""
var _card: GlassPanel
var _icon: TextureRect
var _title: Label
var _dot: Label
var _detail: Label
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -96.0
	offset_bottom = -34.0
	_card = GlassPanel.new(Vector4(18, 8, 16, 9), 16.0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)
	_icon = UiTheme.icon_rect(UiTheme.glyph("speaker"), 22, UiTheme.GOLD_SOFT)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	_title = UiTheme.make_label("", UiTheme.heading(20, UiTheme.TEXT, 700, 1))
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_title)
	_dot = UiTheme.make_label("·", UiTheme.heading(20, UiTheme.TEXT_DIM, 700, 0))
	_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_dot)
	_detail = UiTheme.make_label("", UiTheme.heading(17, UiTheme.TEXT_MUTED, 700, 0))
	_detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_detail)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	for h: Array in [["R", "HINT_RADIO"], ["T", "HINT_STATION"]]:
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 5)
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_child(UiTheme.keycap(h[0], 13))
		var l := UiTheme.make_label(UiTheme.caps(tr(h[1])), UiTheme.heading(13, UiTheme.TEXT_MUTED, 700, 1))
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(l)
		row.add_child(pair)
	visible = false
	modulate.a = 0.0
	Audio.radio.shown.connect(show_line)


func _process(_delta: float) -> void:
	if not visible:
		return
	# Only over the road: not over a menu, not once the driver is out.
	var p := Game.player as Player
	_card.visible = not Game.is_ui_open() and p != null and p.driving != null


## Shows the station and its track (or, with the set off, just that) for a few seconds.
func show_line(p_title: String, p_detail: String, on: bool) -> void:
	title = p_title
	detail = p_detail
	# (A station's name as it is written: no capitals made of it.)
	_title.text = p_title
	_detail.text = p_detail
	_detail.visible = p_detail != ""
	_dot.visible = p_detail != ""
	_icon.modulate = UiTheme.GOLD_SOFT if on else UiTheme.TEXT_DIM
	_title.label_settings.font_color = UiTheme.TEXT if on else UiTheme.TEXT_MUTED
	if _tween and _tween.is_valid():
		_tween.kill()
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN * (1.0 - modulate.a) if modulate.a < 1.0 else 0.0)
	_tween.tween_interval(HOLD)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(func() -> void: visible = false)
