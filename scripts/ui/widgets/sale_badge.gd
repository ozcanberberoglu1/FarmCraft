class_name SaleBadge
extends GlassPanel
## Under the money in the morning after the shipping bin sold overnight: a coin and
## "+123 SALE" counting up with a clink, on green-edged glass. It holds for a few
## seconds, then fades away (the HUD makes room for it under the money pill).

## Emitted as it starts to fade out (the HUD closes the room it made).
signal folding

const FADE_IN := 0.35
const COUNT := 0.9
const HOLD := 6.0
const FADE_OUT := 0.6

## Last amount shown (tests read it).
var amount := 0
var _value: Label
var _coin: TextureRect
var _tween: Tween


func _init() -> void:
	super(Vector4(12, 5, 18, 6), 16.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_look(UiTheme.GLASS, Color(UiTheme.GREEN, 0.42), Color(UiTheme.GREEN, 0.22))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_coin = UiTheme.icon_rect(UiTheme.glyph("coin"), 26)
	_coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_coin)
	_value = UiTheme.make_label("", UiTheme.heading(28, UiTheme.GREEN, 700, 1))
	_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_value)
	var l := UiTheme.make_label(UiTheme.caps(tr("HUD_SALE")), UiTheme.heading(17, UiTheme.TEXT_MUTED, 700, 2))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)


## Shows `gold` counting up; returns the badge's height (the room it needs).
func show_amount(gold: int) -> float:
	amount = gold
	if _tween and _tween.is_valid():
		_tween.kill()
	_set_shown(float(gold))
	reset_size()
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tween.tween_method(_set_shown, 0.0, float(gold), COUNT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(HOLD)
	_tween.tween_callback(func() -> void: folding.emit())
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(func() -> void: visible = false)
	if not DebugTools.is_automated():
		Audio.ui("coins", -6.0)
	return get_combined_minimum_size().y


func _set_shown(v: float) -> void:
	_value.text = "+" + UiTheme.money(roundi(v))
