class_name PaintTable
extends RefCounted
## The paints the town market sells: a handful of country colours (sRGB) the farmer can
## brush onto his buildings (Painter): brick red, the green of unripe almonds, sky blue,
## cream, mustard, deep green and white. Their cans are the items "paint_<id>"
## (ItemTable), their names COLOR_<ID>. (Plain data: the tools that render icons read it
## without the game's autoloads.)

const COLORS := {
	&"brick": Color(0.6, 0.2, 0.15), &"sage": Color(0.58, 0.68, 0.42), &"sky": Color(0.45, 0.64, 0.8),
	&"cream": Color(0.93, 0.85, 0.64), &"mustard": Color(0.8, 0.6, 0.17), &"forest": Color(0.16, 0.31, 0.21),
	&"white": Color(0.94, 0.94, 0.9),
}
const ORDER: Array[StringName] = [&"brick", &"sage", &"sky", &"cream", &"mustard", &"forest", &"white"]
## The colour of anything that flies the farm's colour before the first coat of paint.
const DEFAULT := &"brick"
const PREFIX := "paint_"


static func is_paint(item_id: StringName) -> bool:
	return String(item_id).begins_with(PREFIX) and COLORS.has(StringName(String(item_id).trim_prefix(PREFIX)))


static func item(color: StringName) -> StringName:
	return StringName(PREFIX + String(color))


## The colour id of a can of paint (&"" for anything else).
static func color_of(item_id: StringName) -> StringName:
	return StringName(String(item_id).trim_prefix(PREFIX)) if is_paint(item_id) else &""


## The colour (sRGB) of colour id `color` (the default one's for an unknown id).
static func rgb(color: StringName) -> Color:
	return COLORS.get(color, COLORS[DEFAULT])
