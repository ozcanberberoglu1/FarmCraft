class_name CookRings
extends Control
## Round countdowns over the fish cooking on a campfire near the farmer (Campfire.
## cook_status): a dark disc under each fish with a gold arc running down from twelve
## o'clock and the seconds left in the middle; done, it turns green with a tick. Draws
## only while there is something cooking in view.

const RANGE := 11.0
const RADIUS := 23.0
const THICK := 5.0

var _rings: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var had := not _rings.is_empty()
	_rings.clear()
	var cam := get_viewport().get_camera_3d()
	if cam == null or Game.is_ui_open() or not is_visible_in_tree():
		if had:
			queue_redraw()
		return
	for fire: Node in get_tree().get_nodes_in_group(&"campfires"):
		if not fire.has_method("cook_status") or (fire as Node3D).global_position.distance_to(cam.global_position) > RANGE:
			continue
		for s: Array in fire.cook_status():
			var at: Vector3 = s[0] + Vector3(0, 0.2, 0)
			if cam.is_position_behind(at):
				continue
			var p := cam.unproject_position(at)
			if not get_viewport_rect().grow(-RADIUS).has_point(p):
				continue
			_rings.append([p, float(s[1]), bool(s[2])])
	if had or not _rings.is_empty():
		queue_redraw()


func _draw() -> void:
	var font := UiTheme.font(800)
	for r: Array in _rings:
		var p: Vector2 = r[0]
		var left: float = r[1]
		var done: bool = r[2]
		draw_circle(p, RADIUS + 3.0, Color(0.03, 0.035, 0.03, 0.62))
		if done:
			draw_circle(p, RADIUS - 1.0, Color(UiTheme.GREEN, 0.9))
			draw_polyline(PackedVector2Array([p + Vector2(-9, 0), p + Vector2(-3, 6), p + Vector2(9, -6)]),
					UiTheme.TEXT_DARK, 3.5, true)
			continue
		var frac := clampf(left / Campfire.COOK_SECONDS, 0.0, 1.0)
		draw_arc(p, RADIUS - 2.0, 0.0, TAU, 48, Color(1, 1, 1, 0.16), THICK, true)
		if frac > 0.0:
			draw_arc(p, RADIUS - 2.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, UiTheme.GOLD, THICK, true)
		var text := str(ceili(left))
		var size := 19
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		draw_string(font, p + Vector2(-w * 0.5, size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, UiTheme.TEXT)
