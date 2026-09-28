class_name AchievementToast
extends Control
## Top-centre banner when an achievement unlocks (Events.achievement_unlocked): a gold
## medal whose ring fills around the achievement's icon, "ACHIEVEMENT" over its title
## and a line under it, on gold-edged glass, with a chime. It drops in, holds, then rises
## away; several queue up, and they wait while a menu or the night's report covers the
## screen.

const HOLD := 4.5
const WIDTH := 640.0
const HEIGHT := 110.0
const TOP := 22.0


## The medal, drawn by hand (a container would reset a child's scale).
class Medal extends Control:
	var icon: Texture2D
	var tint := UiTheme.GOLD_SOFT
	var fill := 0.0:
		set(v):
			fill = v
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5 - 3.0
		draw_circle(c, r + 3.0, Color(0, 0, 0, 0.35))
		draw_circle(c, r, Color(0.16, 0.12, 0.05, 0.92))
		draw_circle(c, r - 5.0, Color(UiTheme.GOLD, 0.1 + 0.08 * fill))
		draw_arc(c, r, 0.0, TAU, 56, Color(1, 1, 1, 0.12), 3.0, true)
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * fill, 56, UiTheme.GOLD, 3.2, true)
		if icon:
			var s := size.x * 0.52 * (0.8 + 0.2 * fill)
			draw_texture_rect(icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, tint)


## Achievements waiting to be shown, oldest first. Read by tests.
var queue: Array[StringName] = []
## The one on screen now (&"" when none).
var showing: StringName = &""
var _medal: Medal
var _card: GlassPanel
var _title: Label
var _desc: Label
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.place(self, Vector2(0.5, 0.0), Vector2(-WIDTH * 0.5, TOP), Vector2(WIDTH, HEIGHT))
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = GlassPanel.new(Vector4(16, 12, 30, 13), 22.0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.set_look(UiTheme.GLASS, Color(UiTheme.GOLD, 0.5), Color(UiTheme.GOLD, 0.32))
	center.add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)
	_medal = Medal.new()
	_medal.custom_minimum_size = Vector2(64, 64)
	_medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_medal)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	head.add_child(UiTheme.icon_rect(UiTheme.glyph("sparkles"), 15, UiTheme.GOLD))
	var kicker := UiTheme.make_label(UiTheme.caps(tr("HUD_ACHIEVEMENT")), UiTheme.heading(15, UiTheme.GOLD, 700, 4))
	kicker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(kicker)
	_title = UiTheme.make_label("", UiTheme.heading(30, UiTheme.TEXT, 700, 1))
	col.add_child(_title)
	_desc = UiTheme.make_label("", UiTheme.text(16, UiTheme.TEXT_MUTED, 500))
	col.add_child(_desc)
	Events.achievement_unlocked.connect(func(id: StringName) -> void:
		queue.append(id)
		_next.call_deferred())
	Events.ui_closed.connect(func(_n: StringName) -> void: _next())


## Shows the next waiting achievement once nothing covers the HUD.
func _next() -> void:
	if showing != &"" or queue.is_empty() or Game.is_ui_open() or SaveGame.loading:
		return
	var id: StringName = queue.pop_front()
	showing = id
	_medal.icon = Achievements.icon(id)
	_medal.tint = UiTheme.GOLD_SOFT if Achievements.icon_is_glyph(id) else Color.WHITE
	_medal.fill = 0.0
	_title.text = UiTheme.caps(Achievements.title(id))
	_desc.text = Achievements.description(id)
	visible = true
	modulate.a = 0.0
	position.y = TOP - 46.0
	_glow(1.0)
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.3)
	_tween.tween_property(self, "position:y", TOP, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_property(_medal, "fill", 1.0, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# The gold edge glows as the medal fills, then settles.
	_tween.tween_method(_glow, 1.0, 0.0, 1.2)
	_tween.chain().tween_interval(HOLD)
	_tween.chain().tween_property(self, "modulate:a", 0.0, 0.4)
	_tween.tween_property(self, "position:y", TOP - 30.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(_done)
	if not DebugTools.is_automated():
		Audio.ui("confirm", -3.0)
		Audio.ui("coins_small", -12.0)


## The card's gold edge: 1 bright (as the medal fills), 0 settled.
func _glow(t: float) -> void:
	_card.set_look(UiTheme.GLASS, Color(UiTheme.GOLD, lerpf(0.5, 0.9, t)), Color(UiTheme.GOLD, lerpf(0.32, 0.55, t)))


func _done() -> void:
	visible = false
	showing = &""
	_next()
