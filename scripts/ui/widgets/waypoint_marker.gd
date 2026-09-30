class_name WaypointMarker
extends Control
## The guide dot of the story's goals: a white dot in a gold ring over the place the
## current goal sends the player (Quests.guide_point(): a Node3D it follows, or a world
## position; first a building just finished), with the distance in metres on a small
## frosted pill under it (after the new building's line: "Your Open Barn is here · 40 m"). Off screen,
## or behind the camera, it rides the screen edge with a chevron pointing the way
## (behind: the left or right edge, the way to turn). It pulses while in view, dims over
## the crosshair so it never hides a prompt, and fades out within a few metres of the
## place. Works from the driver's seat (the viewport's current camera); hidden in menus,
## on the title, while a game loads and when the goal names no place.

## Inset from the screen edges while clamped: left, top, right, bottom (clears the
## money and clock cards at the top and the hotbar at the bottom).
const INSET := Vector4(70, 96, 70, 176)
const DOT := 6.0
const RING := 12.0
## Faded out closer than FADE_NEAR metres, fully shown from FADE_FAR.
const FADE_NEAR := 2.0
const FADE_FAR := 5.0
## Screen radius around the crosshair where the dot dims (it sits over the prompts).
const CENTER_DIM := 90.0
## A jump of the target farther than this is a new place: the dot pops in again.
const NEW_PLACE := 3.0
## Places the story can point at: Node3D anchors in this group, each with its id in the
## meta &"waypoint" (see tag() and anchor()).
const ANCHOR_GROUP := &"waypoint_anchors"

## Points the dot here instead of the story's place (a Vector3 or a Node3D; null for
## the story's): tests and screenshot runs.
var target_override: Variant = null
## Where the dot points, whether it is in view, and how far away (metres, on the
## ground). Read by tests.
var world_point := Vector3.ZERO
var on_screen := false
var distance := 0.0
var _has_target := false
var _target_id := 0
var _pos := Vector2.ZERO
var _dir := Vector2.ZERO
var _alpha := 0.0
var _pulse := 0.0
var _pop := 1.0
var _pop_tween: Tween
var _shown_m := -1
var _shown_label := ""
var _pill: GlassPanel
var _label: Label


## Marks `node` as the place `id` for the dot (put it where the dot should float, e.g. a
## Marker3D a metre over a prop).
static func tag(node: Node3D, id: StringName) -> void:
	node.add_to_group(ANCHOR_GROUP)
	node.set_meta(&"waypoint", id)


## The anchor tagged `id` in the current world, or null.
static func anchor(id: StringName) -> Node3D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group(ANCHOR_GROUP):
		if n is Node3D and StringName(n.get_meta(&"waypoint", &"")) == id and n.is_inside_tree():
			return n as Node3D
	return null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pill = GlassPanel.new(Vector4(10, 1, 10, 2), 11.0)
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.shadow = 0.35
	add_child(_pill)
	_label = UiTheme.make_label("", UiTheme.heading(17, UiTheme.TEXT, 700, 1))
	_pill.add_child(_label)
	modulate.a = 0.0
	visible = false


func _process(delta: float) -> void:
	var want := 0.0
	_update_target()
	var cam := get_viewport().get_camera_3d()
	var player := Game.player
	if _has_target and cam != null and player != null and not Game.is_ui_open() and not SaveGame.loading:
		_place(cam)
		distance = Vector2(world_point.x - player.global_position.x, world_point.z - player.global_position.z).length()
		want = smoothstep(FADE_NEAR, FADE_FAR, distance)
		if on_screen:
			want *= lerpf(0.35, 1.0, clampf((_pos.distance_to(size * 0.5) - 20.0) / CENTER_DIM, 0.0, 1.0))
		var m := roundi(distance)
		var line := Quests.guide_label() if typeof(target_override) == TYPE_NIL else ""
		if m != _shown_m or line != _shown_label:
			_shown_m = m
			_shown_label = line
			# A missing translation (the bare key) has nothing to format into.
			var fmt := tr("HUD_DISTANCE_M")
			_label.text = fmt % m if fmt.contains("%") else "%d m" % m
			if line != "":
				_label.text = "%s · %s" % [line, _label.text]
			_pill.reset_size()
	elif not _has_target:
		_shown_m = -1
	# Menus hide it at once; otherwise it eases in and out.
	_alpha = 0.0 if Game.is_ui_open() else move_toward(_alpha, want, delta * 4.0)
	modulate.a = _alpha
	visible = _alpha > 0.005
	if visible:
		_pulse = fposmod(_pulse + delta / 1.6, 1.0)
		var below := _dir.y < 0.5
		_pill.position = _pos + Vector2(-_pill.size.x * 0.5, RING + 9.0 if below else -RING - 9.0 - _pill.size.y)
		# A new building's line makes it wide: kept on screen at the edges.
		_pill.position.x = clampf(_pill.position.x, 12.0, maxf(size.x - _pill.size.x - 12.0, 12.0))
		queue_redraw()


## Reads the goal's place into `world_point`; pops the dot when the place is new.
func _update_target() -> void:
	var target: Variant = target_override if typeof(target_override) != TYPE_NIL else Quests.guide_point()
	var point := world_point
	var id := 0
	var found := false
	if typeof(target) == TYPE_VECTOR3:
		point = target
		found = true
	# A freed node can't even be asked what it is.
	elif typeof(target) == TYPE_OBJECT and is_instance_valid(target) and target is Node3D:
		var node := target as Node3D
		if node.is_inside_tree():
			point = node.global_position
			id = node.get_instance_id()
			found = true
	if not found:
		_has_target = false
		return
	if not _has_target or id != _target_id or point.distance_to(world_point) > NEW_PLACE:
		_pop_in()
	_has_target = true
	_target_id = id
	world_point = point


func _pop_in() -> void:
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop = 0.0
	_pop_tween = create_tween()
	_pop_tween.tween_property(self, "_pop", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Screen spot: projected when in view, else on the inset edge along the way to it.
func _place(cam: Camera3D) -> void:
	var c := size * 0.5
	var lo := Vector2(INSET.x, INSET.y)
	var hi := size - Vector2(INSET.z, INSET.w)
	var behind := cam.is_position_behind(world_point)
	var p := cam.unproject_position(world_point)
	on_screen = not behind and Rect2(lo, hi - lo).has_point(p)
	if on_screen:
		_pos = p
		_dir = Vector2.ZERO
		return
	var d := p - c
	if behind:
		# Behind the camera the projection mirrors: point to the side to turn to instead.
		var local := cam.global_transform.affine_inverse() * world_point
		d = Vector2(signf(local.x) if absf(local.x) > 0.001 else 1.0,
				clampf(-local.y / maxf(absf(local.z), 0.001), -0.3, 0.3))
	if d.length_squared() < 0.0001:
		d = Vector2.DOWN
	_dir = d.normalized()
	var tx := ((hi.x - c.x) if _dir.x > 0.0 else (c.x - lo.x)) / maxf(absf(_dir.x), 0.0001)
	var ty := ((hi.y - c.y) if _dir.y > 0.0 else (c.y - lo.y)) / maxf(absf(_dir.y), 0.0001)
	_pos = c + _dir * minf(tx, ty)


func _draw() -> void:
	var s := _pop
	draw_circle(_pos, (RING + 5.0) * s, Color(0, 0, 0, 0.3))
	if on_screen:
		draw_arc(_pos, (RING + 2.0 + _pulse * 16.0) * s, 0.0, TAU, 40, Color(UiTheme.GOLD, 0.55 * (1.0 - _pulse)), 2.0, true)
	draw_arc(_pos, RING * s, 0.0, TAU, 40, UiTheme.GOLD, 2.6, true)
	draw_circle(_pos, DOT * s, Color(1, 1, 1, 0.97))
	if _dir != Vector2.ZERO:
		# The chevron outside the ring, pointing the way.
		var tip := _pos + _dir * (RING + 15.0) * s
		var base := _pos + _dir * (RING + 5.0) * s
		var side := _dir.orthogonal() * 7.5 * s
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(0, 0, 0, 0.35))
		draw_colored_polygon(PackedVector2Array([tip - _dir * 1.5, base + side * 0.8, base - side * 0.8]), UiTheme.GOLD)
