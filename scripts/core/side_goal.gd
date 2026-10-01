class_name SideGoal
extends RefCounted
## A side goal up beside the story's and Zeynep's (SideStory.goals: the wolves' lesson, the
## vet's): what its card says (a title with a glyph in its own colour, the goal, a hint
## under it) and where its dot points. Its owner keeps it up to date (set); the HUD shows
## a card and a dot for each one in SideStory.goals (a goal with no text shows neither).

## Its text, hint, dot or label changed (the HUD refreshes its card).
signal changed

var id: StringName
## The card's heading ("WOLVES · SIDE GOAL") and its glyph and colour.
var title := ""
var glyph := "info"
var color := Color.WHITE
var text := ""
var hint := ""
## The line on the dot's pill (who or what it points at).
var label := ""
## Where the dot points: a Vector3, a Node3D it follows, or null for no dot.
var point: Variant = null
## An errand that can wait (the mailbox): a compact card whose hint shows only for a while
## and near the place, a smaller, fainter dot (HUD). Urgent goals (the wolves', the
## vet's) stay prominent.
var quiet := false


func _init(goal_id: StringName, goal_title: String, goal_glyph: String, goal_color: Color) -> void:
	id = goal_id
	title = goal_title
	glyph = goal_glyph
	color = goal_color


## Sets what the card says and where the dot points; `changed` when any of it did.
func set_goal(goal_text: String, goal_hint := "", where: Variant = null, where_label := "") -> void:
	var moved: bool = typeof(where) != typeof(point) or (where is Vector3 and (where as Vector3).distance_to(point) > 0.05) \
			or (typeof(where) == TYPE_OBJECT and where != point)
	if goal_text == text and goal_hint == hint and where_label == label and not moved:
		return
	text = goal_text
	hint = goal_hint
	label = where_label
	point = where
	changed.emit()


## Where the dot points (WaypointMarker's source): null once a node it followed is gone.
func guide_point() -> Variant:
	if typeof(point) == TYPE_OBJECT and not is_instance_valid(point):
		return null
	return point


func guide_label() -> String:
	return label
