class_name NeedsBars
extends GlassPanel
## The farmer's hunger and energy at the bottom left, level with the hotbar: a glass
## pill with a bowl and a moon, each over a thin bar (PlayerState.needs). A need running
## low turns its bar red and it breathes, with a word beside it (HUNGRY, TIRED...);
## eating fills the hunger bar with a little glow.

const BAR_WIDTH := 132.0
const HUNGER_COLOR := Color("f0a04b")
const ENERGY_COLOR := Color("78b8f0")

var _hunger: StatBar
var _energy: StatBar
var _hunger_icon: TextureRect
var _energy_icon: TextureRect
var _hunger_word: Label
var _energy_word: Label
var _time := 0.0
var _flash := 0.0


func _init() -> void:
	super(Vector4(14, 10, 16, 11), 16.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	super()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var h := _row(col, "food", HUNGER_COLOR)
	_hunger_icon = h[0]
	_hunger = h[1]
	_hunger_word = h[2]
	var e := _row(col, "moon", ENERGY_COLOR)
	_energy_icon = e[0]
	_energy = e[1]
	_energy_word = e[2]
	# Bottom left, its foot level with the hotbar's.
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = 28.0
	offset_right = 28.0
	offset_top = -22.0
	offset_bottom = -22.0
	PlayerState.needs.changed.connect(_refresh)
	Events.food_eaten.connect(func(_id: StringName) -> void:
		_flash = 1.0
		set_process(true))
	_refresh(false)


func _row(parent: Control, glyph: String, color: Color) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var icon := UiTheme.icon_rect(UiTheme.glyph(glyph), 18, color)
	row.add_child(icon)
	var bar := StatBar.new(6.0, color)
	bar.custom_minimum_size = Vector2(BAR_WIDTH, 18)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var word := UiTheme.make_label("", UiTheme.heading(13, UiTheme.RED, 700, 2))
	word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	word.visible = false
	row.add_child(word)
	return [icon, bar, word]


func _refresh(animate := true) -> void:
	var n := PlayerState.needs
	_hunger.set_value(n.hunger, animate)
	_energy.set_value(n.energy, animate)
	_hunger.fixed_color = UiTheme.RED if n.hungry() else HUNGER_COLOR
	_energy.fixed_color = UiTheme.RED if n.tired() else ENERGY_COLOR
	_hunger_icon.modulate = _hunger.fixed_color
	_energy_icon.modulate = _energy.fixed_color
	_set_word(_hunger_word, "HUD_STARVING" if n.starving() else ("HUD_HUNGRY" if n.hungry() else ""))
	_set_word(_energy_word, "HUD_EXHAUSTED" if n.exhausted() else ("HUD_TIRED" if n.tired() else ""))
	_hunger.queue_redraw()
	_energy.queue_redraw()
	set_process(n.hungry() or n.tired() or _flash > 0.0)


func _set_word(label: Label, key: String) -> void:
	label.visible = key != ""
	if key != "":
		label.text = UiTheme.caps(tr(key))


## A low need breathes; a meal glows through the hunger bar.
func _process(delta: float) -> void:
	_time += delta
	var n := PlayerState.needs
	var breathe := 0.62 + 0.38 * (0.5 + 0.5 * sin(_time * 4.2))
	_hunger_icon.modulate.a = breathe if n.hungry() else 1.0
	_hunger_word.modulate.a = breathe
	_energy_icon.modulate.a = breathe if n.tired() else 1.0
	_energy_word.modulate.a = breathe
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 1.6, 0.0)
		var glow := Color(1.0, 0.95, 0.8).lerp(HUNGER_COLOR, 1.0 - _flash)
		_hunger.fixed_color = glow if not n.hungry() else UiTheme.RED.lerp(Color.WHITE, _flash * 0.6)
		_hunger_icon.scale = Vector2.ONE * (1.0 + 0.25 * _flash)
		_hunger_icon.pivot_offset = _hunger_icon.size * 0.5
		_hunger.queue_redraw()
		if _flash <= 0.0:
			_refresh()
	elif not (n.hungry() or n.tired()):
		set_process(false)
