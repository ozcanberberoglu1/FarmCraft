class_name FarmIdentity
extends RefCounted
## What the farmer puts of himself into the farm: its NAME (written on Grandpa's old name
## board at the entrance: NameBoard), its COLOURS (cans of paint from the town market,
## brushed onto the house, the coops, the doghouse, the mailbox and the board's frame:
## Painter) and a few DECORATIONS (Decor: a flower pot, a garden bench, a scarecrow, a flag
## pole, a bird bath).
##
## Everything is kept in the save without a format of its own: the name and the fixed
## buildings' colours in FarmState.flags (NAME_FLAG, PAINT_FLAG), a placed thing's colour
## in its own entry ("paint"), so an old save simply has none: its farm is called
## default_name() until the farmer writes another on the board, and nothing is painted.
## Nodes that show the name or the last colour used join the LISTENERS group and are
## told when either changes (farm_identity_changed(what): &"name" or &"paint").

## FarmState.flags: the farm's name (String), set once the farmer has been to the board
## (NAMED_FLAG, bool: the story's "farm_name" goal reads it; a skipped prompt counts).
const NAME_FLAG := "farm_name"
const NAMED_FLAG := "farm_named"
## FarmState.flags: {part: colour id} of the things that are not placed ("house_walls",
## "house_trim", "board_frame"), and the colour last brushed on anything (the flag pole's
## pennant flies it).
const PAINT_FLAG := "paint"
const LAST_PAINT_FLAG := "last_paint"
## FarmState.flags: what a townsperson has said a kind word about already ({what: true}),
## the quiet side goal to paint the house done, and the one-line hint on decorations shown.
const PRAISED_FLAG := "farm_praised"
const PAINT_GOAL_FLAG := "paint_goal_done"
const DECOR_HINT_FLAG := "decor_hint"
## The longest name the board takes.
const MAX_NAME := 24
const LISTENERS := &"farm_identity"

## The paints (PaintTable: the cans are the items "paint_<colour>").
const COLORS := PaintTable.COLORS
const COLOR_ORDER := PaintTable.ORDER
const DEFAULT_COLOR := PaintTable.DEFAULT
## The decorations (PlaceableTable kind "decor"; all sold at the town market).
const DECOR: Array[StringName] = [&"flower_pot", &"garden_bench", &"scarecrow", &"flag_pole", &"bird_bath"]


# --- The name ---------------------------------------------------------------------------------

## What the farm is called until the farmer writes a name of his own on the board.
static func default_name() -> String:
	return TranslationServer.translate("FARM_NAME_DEFAULT")


static func farm_name() -> String:
	var n := String(FarmState.flags.get(NAME_FLAG, "")).strip_edges()
	return n if n != "" else default_name()


## The farmer has been to the board (written a name, or kept Grandpa's).
static func is_named() -> bool:
	return bool(FarmState.flags.get(NAMED_FLAG, false))


## Writes `new_name` on the board (an empty one keeps what it was called); the board,
## the shipping bin and the rest are told.
static func set_farm_name(new_name: String) -> void:
	var n := new_name.strip_edges().left(MAX_NAME)
	if n == "":
		n = farm_name()
	FarmState.flags[NAME_FLAG] = n
	FarmState.flags[NAMED_FLAG] = true
	notify_changed(&"name")


## Names offered under the field: the farmer's own animals' first ("Fındık Çiftliği",
## "Gıdık Çiftliği"), then a few of the valley's.
static func name_ideas() -> PackedStringArray:
	var out := PackedStringArray()
	var pattern := TranslationServer.translate("FARM_NAME_PATTERN")
	if Pet.has_dog():
		out.append(pattern % Pet.dog_name)
	if not Animals.animals.is_empty():
		out.append(pattern % (Animals.animals[0] as AnimalData).name)
	for idea: String in String(TranslationServer.translate("FARM_NAME_IDEAS")).split("|", false):
		if idea.strip_edges() != "" and not out.has(idea.strip_edges()):
			out.append(idea.strip_edges())
	return out


## "Sen · Yeşil Vadi Çiftliği": how the farmer stands on the town's boards once his farm
## has a name of his own (FishingContest).
static func contest_entrant(you: String) -> String:
	return "%s · %s" % [you, farm_name()] if is_named() else you


# --- The colours ------------------------------------------------------------------------------

static func is_paint(item_id: StringName) -> bool:
	return PaintTable.is_paint(item_id)


static func paint_item(color: StringName) -> StringName:
	return PaintTable.item(color)


## The colour id of a can of paint (&"" for anything else).
static func color_of(item_id: StringName) -> StringName:
	return PaintTable.color_of(item_id)


## The colour (sRGB) of colour id `color` (the default one's for an unknown id).
static func rgb(color: StringName) -> Color:
	return PaintTable.rgb(color)


static func color_name(color: StringName) -> String:
	return TranslationServer.translate("COLOR_" + String(color).to_upper())


## The colour on a fixed part ("house_walls", "house_trim", "board_frame"); &"" for bare.
static func part_color(part: String) -> StringName:
	var paints: Variant = FarmState.flags.get(PAINT_FLAG)
	var c := StringName(String((paints as Dictionary).get(part, ""))) if paints is Dictionary else &""
	return c if COLORS.has(c) else &""


static func set_part_color(part: String, color: StringName) -> void:
	var paints: Variant = FarmState.flags.get(PAINT_FLAG)
	var d: Dictionary = (paints as Dictionary) if paints is Dictionary else {}
	d[part] = String(color)
	FarmState.flags[PAINT_FLAG] = d
	_used(color)


## The colour on a placed thing (its FarmState.placed entry); &"" for bare.
static func entry_color(e: Dictionary) -> StringName:
	var c := StringName(String(e.get("paint", "")))
	return c if COLORS.has(c) else &""


static func set_entry_color(e: Dictionary, color: StringName) -> void:
	e["paint"] = String(color)
	_used(color)


## The colour last brushed on anything (the default before the first).
static func last_color() -> StringName:
	var c := StringName(String(FarmState.flags.get(LAST_PAINT_FLAG, "")))
	return c if COLORS.has(c) else DEFAULT_COLOR


## Something on the farm has been painted by hand.
static func anything_painted() -> bool:
	return FarmState.flags.has(LAST_PAINT_FLAG)


static func _used(color: StringName) -> void:
	FarmState.flags[LAST_PAINT_FLAG] = String(color)
	notify_changed(&"paint")


# --- The market, the townspeople ----------------------------------------------------------------

## The town market's paints and decorations, added to its `stock` (ShopStock.town_market).
static func add_market_stock(stock: Array) -> void:
	var ids: Array[StringName] = []
	for c: StringName in COLOR_ORDER:
		ids.append(paint_item(c))
	ids.append_array(DECOR)
	for id: StringName in ids:
		if ItemDB.has_item(id) and id not in stock:
			stock.append(id)


## A townsperson greeted by the farmer (Townsperson.interact, after his own greeting): the
## first one after the farm got its name has a warm word about it, and the first one
## after something was painted about its colours (once each, in his speech bubble).
static func greeted(person: Node) -> void:
	if person == null or not person.has_method("say"):
		return
	var praised: Variant = FarmState.flags.get(PRAISED_FLAG)
	var done: Dictionary = (praised as Dictionary) if praised is Dictionary else {}
	if String(FarmState.flags.get(NAME_FLAG, "")) != "" and is_named() and not done.has("name"):
		done["name"] = true
		FarmState.flags[PRAISED_FLAG] = done
		person.say(TranslationServer.translate("SAY_FARM_NAME") % farm_name())
	elif anything_painted() and not done.has("paint"):
		done["paint"] = true
		FarmState.flags[PRAISED_FLAG] = done
		person.say(TranslationServer.translate("SAY_FARM_PAINT"))


# --- The world --------------------------------------------------------------------------------

## Puts up Grandpa's name board at the entrance and the node that keeps the colours on
## their buildings and the quiet goals (Farm._place_props).
static func setup(farm: Node3D) -> void:
	var board := NameBoard.new()
	board.name = "NameBoard"
	var at := WorldLayout.NAME_BOARD_POS
	board.position = Vector3(at.x, TerrainData.height(at.x, at.z), at.z)
	board.rotation.y = deg_to_rad(WorldLayout.NAME_BOARD_YAW)
	farm.add_child(board)
	if Game.world and Game.world.has_method("block_grass"):
		Game.world.block_grass(Rect2(at.x - 1.9, at.z - 0.8, 3.8, 1.6))
	var works := IdentityWorks.new()
	works.name = "IdentityWorks"
	farm.add_child(works)


## The name board (null before the farm is built).
static func board() -> NameBoard:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group(NameBoard.GROUP) as NameBoard if tree else null


## The node that keeps the colours on and runs the quiet goals (null before the farm is built).
static func works() -> IdentityWorks:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group(IdentityWorks.GROUP) as IdentityWorks if tree else null


## Tells the LISTENERS that the name or the last colour changed.
static func notify_changed(what: StringName) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.call_group(LISTENERS, "farm_identity_changed", what)
