class_name GrowthRing
extends Control
## Round progress meter: a faint track cut into `segments` (a crop's growth stages),
## an arc filling clockwise from twelve o'clock with round ends, a picture in the
## middle (a crop's icon) and an optional status badge sitting on the ring at the
## lower right. The arc eases to new values like StatBar; `pulse` makes it breathe
## with a soft glow. Redraws only while it moves or pulses, and only when shown.

const POINTS := 72

var ratio := 0.0
var color := UiTheme.GREEN
var icon: Texture2D
var icon_tint := Color.WHITE
var badge: Texture2D
var pulse := false
var segments := 1
var thickness := 7.0

var _shown := 0.0
var _time := 0.0


func _init(diameter := 84.0, p_thickness := 7.0) -> void:
	thickness = p_thickness
	custom_minimum_size = Vector2(diameter, diameter)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## The fill (0..1) and its colour; `snap` jumps there (a newly aimed bed), otherwise
## the arc eases there.
func set_state(p_ratio: float, p_color: Color, snap := false) -> void:
	var r := clampf(p_ratio, 0.0, 1.0)
	if r == ratio and p_color == color and (not snap or _shown == r):
		return
	ratio = r
	color = p_color
	if snap:
		_shown = r
	_wake()


## The picture in the middle (tinted by `p_tint`), the corner badge (null: none),
## whether the ring pulses and how many stages the track is cut into.
func set_look(p_icon: Texture2D, p_badge: Texture2D = null, p_tint := Color.WHITE, p_pulse := false,
		p_segments := 1) -> void:
	if p_icon == icon and p_badge == badge and p_tint == icon_tint and p_pulse == pulse and p_segments == segments:
		return
	icon = p_icon
	badge = p_badge
	icon_tint = p_tint
	pulse = p_pulse
	segments = maxi(p_segments, 1)
	_wake()


## Lands the arc where it is heading (the ring was hidden).
func settle() -> void:
	_shown = ratio
	set_process(false)
	queue_redraw()


func _wake() -> void:
	set_process(is_visible_in_tree() and (pulse or _shown != ratio))
	queue_redraw()


## Shown again (the card, or the whole HUD in a debug shot): a ripe crop pulses on.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_wake()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		_shown = ratio
		set_process(false)
		return
	# Eases out: quick over a big change (a harvest resets a regrowing crop), with a
	# floor so it always lands.
	_shown = move_toward(_shown, ratio, maxf(absf(ratio - _shown) * 7.0, 0.3) * delta)
	if pulse:
		_time += delta
	queue_redraw()
	if not pulse and _shown == ratio:
		set_process(false)


func _draw() -> void:
	var c := size * 0.5
	var outer := minf(size.x, size.y) * 0.5
	var r := outer - thickness * 0.5 - 3.0
	# A dark disc under it keeps the ring readable over bright sky and pale soil.
	draw_circle(c, outer - 1.0, Color(0, 0, 0, 0.3), true, -1.0, true)
	draw_circle(c, r - thickness * 0.5 - 1.0, Color(1, 1, 1, 0.035), true, -1.0, true)
	draw_arc(c, r, 0.0, TAU, POINTS, Color(1, 1, 1, 0.1), thickness, true)
	if pulse:
		var k := 0.5 + 0.5 * sin(_time * 3.6)
		draw_arc(c, r, 0.0, TAU, POINTS, Color(color, 0.1 + 0.16 * k), thickness + 4.0 + 6.0 * k, true)
	if _shown >= 0.999:
		# Full: a closed ring, no caps meeting at the top.
		draw_arc(c, r, 0.0, TAU, POINTS, color, thickness, true)
	elif _shown > 0.003:
		var a0 := -PI * 0.5
		var a1 := a0 + TAU * _shown
		draw_arc(c, r, a0, a1, maxi(8, ceili(POINTS * _shown)), color, thickness, true)
		# Round ends; the leading one a shade lighter, like a moving head.
		draw_circle(c + Vector2.from_angle(a0) * r, thickness * 0.5, color, true, -1.0, true)
		draw_circle(c + Vector2.from_angle(a1) * r, thickness * 0.5, color.lightened(0.2), true, -1.0, true)
	# Stage marks: thin dark cuts across the ring where each later stage begins.
	for i in range(1, segments):
		var dir := Vector2.from_angle(-PI * 0.5 + TAU * i / float(segments))
		draw_line(c + dir * (r - thickness * 0.5 - 1.0), c + dir * (r + thickness * 0.5 + 1.0),
				Color(0.03, 0.04, 0.035, 0.85), 2.0, true)
	if icon:
		var s := (r - thickness * 0.5 - 4.0) * 1.56
		draw_texture_rect(icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, icon_tint)
	if badge:
		var b := outer * 0.6
		var at := c + Vector2.from_angle(PI * 0.25) * r
		draw_circle(at, b * 0.5 + 1.5, Color(0, 0, 0, 0.35), true, -1.0, true)
		draw_texture_rect(badge, Rect2(at - Vector2(b, b) * 0.5, Vector2(b, b)), false)
