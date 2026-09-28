@tool
class_name Field
extends Node3D
## A grid of garden beds. Advances every bed on each clock tick and reacts to
## season changes and rain.

@export var rows := 3
@export var cols := 4
@export var gap := 0.8
@export var rebuild := false:
	set(value):
		if value and is_inside_tree():
			_build()

var plots: Array[FarmPlot] = []


func _ready() -> void:
	add_to_group(&"fields")
	_build()
	if not Engine.is_editor_hint():
		Events.clock_tick.connect(_on_tick)
		Events.season_changed.connect(_on_season_changed)


func _build() -> void:
	for c in get_children():
		c.queue_free()
	plots.clear()
	var step := FarmPlot.SIZE + gap
	var origin := Vector3(-(cols - 1) * step * 0.5, 0, -(rows - 1) * step * 0.5)
	for r in rows:
		for c in cols:
			var p := FarmPlot.new()
			p.name = "Plot_%d_%d" % [r, c]
			p.variant = (r * cols + c) % 3
			p.position = origin + Vector3(c * step, 0, r * step)
			add_child(p)
			plots.append(p)


func _on_tick(_total: float, delta_minutes: float) -> void:
	var hours := delta_minutes / 60.0
	for p in plots:
		p.advance(hours)


func _on_season_changed(season: int) -> void:
	for p in plots:
		p.on_season_changed(season)


## Rain waters every bed.
func rain() -> void:
	for p in plots:
		p.soak()
