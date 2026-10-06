class_name Painter
extends RefCounted
## Painting the farm by hand. With a can of paint in hand (FarmIdentity.COLORS, the items
## "paint_<colour>" from the town market), LMB on something that takes paint brushes it
## on in a few strokes (the brush's swish, the can used up: one can a building or part):
##
##   the farmhouse   LMB its walls, E its trim (casings, corner boards, fascia), once it
##                   is repaired; aimed at from outside (PaintSpot: the walls are no
##                   interactable of their own)
##   a kit coop      LMB its walls (PaintSpot too)
##   the doghouse, the mailbox, the name board's frame, and any placed thing that says
##   what takes paint on it (`paint_spec()`, or a fence gate: its kind has "gate" in it)
##
## The colour is a parameter of the surface's own photo-textured material (the `paint`
## uniform of textured.gdshader: the wood's grain shows through the coat, and the stains,
## grime and snow lie over it), set on a copy of the material as the mesh's surface
## override. The colours are saved per object (FarmIdentity: the house's and the board's
## in FarmState.flags, a placed thing's in its entry); IdentityWorks puts them back on
## after a load, a house upgrade or a coop's expansion (their meshes are built anew).

## The action's id (ToolAnim.ACTIONS: the brush's side-to-side strokes) and its length.
const ACTION := "paint"
const SECONDS := 1.6
## How thickly a coat covers (the old colour shows through a little).
const COVER := 0.93
## Mean luminance of the photos behind the paintable materials (the grain is read
## against it): weathered_brown_planks and rough_wood.
const PHOTO_REF := {&"planks": 0.08, &"planks_ext": 0.08, &"planks_old": 0.08}
const WOOD_REF := 0.128

static var _mats := {}
static var _spot: PaintSpot


## The colour id of the can in `stack` (&"" when it is no paint).
static func holding(stack: ItemStack) -> StringName:
	return FarmIdentity.color_of(stack.item.id) if stack != null and stack.item != null else &""


## The copy of material `key` wearing colour `color` (made once).
static func painted(key: StringName, color: StringName) -> Material:
	return coat(key, FarmIdentity.rgb(color))


## The copy of material `key` under a coat of the colour `c` (sRGB; made once): the name
## board's fresh face wears one that is no can's colour.
static func coat(key: StringName, c: Color) -> Material:
	var id := "%s/%s" % [key, c.to_html(false)]
	if not _mats.has(id):
		var m := Mats.get_mat(key).duplicate() as ShaderMaterial
		if m != null:
			m.set_shader_parameter("paint", Color(c.r, c.g, c.b, COVER))
			m.set_shader_parameter("paint_ref", float(PHOTO_REF.get(key, WOOD_REF)))
		_mats[id] = m
	return _mats[id]


## Puts colour `color` on the surfaces of `mi` made of the materials `keys` (&"": takes
## the paint off). Returns how many surfaces wear it.
static func tint(mi: MeshInstance3D, keys: Array, color: StringName) -> int:
	if mi == null or not is_instance_valid(mi) or mi.mesh == null:
		return 0
	var n := 0
	for i in mi.mesh.get_surface_count():
		var base := mi.mesh.surface_get_material(i)
		for key: StringName in keys:
			if base == Mats.get_mat(key):
				var want: Material = painted(key, color) if color != &"" else null
				if mi.get_surface_override_material(i) != want:
					mi.set_surface_override_material(i, want)
				n += 1
				break
	return n


## What takes paint on `node`: {"meshes": the MeshInstance3Ds, "keys": the material keys
## painted on them, "verb": the prompt's translation key, "part": where its colour is kept
## in FarmState.flags ("" for a placed thing: its entry)}; {} for something that takes none.
static func spec(node: Node) -> Dictionary:
	if node == null or not is_instance_valid(node):
		return {}
	if node.has_method("paint_spec"):
		return node.paint_spec()
	if node is NameBoard:
		return {"meshes": [node.get_node_or_null("Frame")], "keys": [&"paint"], "verb": "ACTION_PAINT_FRAME", "part": "board_frame"}
	if node is Doghouse:
		if not (node as Doghouse).is_built():
			return {}
		return {"meshes": [node.get_node_or_null("Body")], "keys": [&"planks"], "verb": "ACTION_PAINT", "part": ""}
	if node is Mailbox:
		return {"meshes": [node.get_node_or_null("Body")], "keys": [&"paint"], "verb": "ACTION_PAINT", "part": ""}
	if node is ChickenCoop:
		return coop_spec(node as ChickenCoop)
	if node is PlacedObject and "gate" in String(PlaceableTable.get_info((node as PlacedObject).item_id).get("kind", "")):
		# A fence gate (should the farm have them): every wooden part of it.
		return {"meshes": node.find_children("*", "MeshInstance3D", true, false),
			"keys": [&"fence_wood", &"wood", &"wood_ext", &"planks", &"planks_ext", &"paint"], "verb": "ACTION_PAINT", "part": ""}
	return {}


## A finished kit coop's walls (its house is built anew when it is made longer).
static func coop_spec(coop: ChickenCoop) -> Dictionary:
	if coop == null or not coop.is_built() or coop.housing == null:
		return {}
	var building := coop.housing.get_node_or_null("Structure/Building")
	if building == null:
		return {}
	var meshes := []
	for c: Node in building.get_children():
		if c is MeshInstance3D:
			meshes.append(c)
	return {"meshes": meshes, "keys": [&"planks_ext"], "verb": "ACTION_PAINT_COOP", "part": ""}


## The farmhouse's `part` ("house_walls" or "house_trim"); {} while it is run down.
static func house_spec(part: String) -> Dictionary:
	var house := _house()
	if house == null or house.level < 1:
		return {}
	var meshes := [house.get_node_or_null("Mesh"), house.get_node_or_null("Detail")]
	if part == "house_trim":
		return {"meshes": meshes, "keys": [&"paint_ext"], "verb": "ACTION_PAINT_TRIM", "part": part}
	return {"meshes": meshes, "keys": [&"planks_ext"], "verb": "ACTION_PAINT_WALLS", "part": part}


## The colour `node` wears now (&"" for bare).
static func color_on(node: Node, s: Dictionary) -> StringName:
	var part := String(s.get("part", ""))
	if part != "":
		return FarmIdentity.part_color(part)
	return FarmIdentity.entry_color((node as PlacedObject).entry) if node is PlacedObject else &""


## Puts the saved colour of `node` on its meshes (bare when it has none).
static func apply(node: Node, s: Dictionary = {}) -> void:
	var sp := s if not s.is_empty() else spec(node)
	if sp.is_empty():
		return
	var color := color_on(node, sp)
	for mi: Variant in sp["meshes"]:
		if mi is MeshInstance3D:
			tint(mi as MeshInstance3D, sp["keys"], color)


## Paints `node` with `color`, kept in the save. False when it takes no paint.
static func paint(node: Node, color: StringName, s: Dictionary = {}) -> bool:
	var sp := s if not s.is_empty() else spec(node)
	if sp.is_empty() or not FarmIdentity.COLORS.has(color):
		return false
	var part := String(sp.get("part", ""))
	if part != "":
		FarmIdentity.set_part_color(part, color)
	elif node is PlacedObject:
		FarmIdentity.set_entry_color((node as PlacedObject).entry, color)
	else:
		return false
	apply(node, sp)
	return true


# --- The hand's side (a target's use_* methods call these) -----------------------------------

static func use_prompt(node: Node, stack: ItemStack, s: Dictionary = {}) -> String:
	var a := use_action(node, stack, s)
	return TranslationServer.translate(String(a["verb"])) if not a.is_empty() else ""


## The brushing action on `node` with the can in `stack` ({} with no paint in hand, on
## something that takes none, or on a coat of the same colour).
static func use_action(node: Node, stack: ItemStack, s: Dictionary = {}) -> Dictionary:
	var color := holding(stack)
	if color == &"":
		return {}
	var sp := s if not s.is_empty() else spec(node)
	if sp.is_empty() or color_on(node, sp) == color:
		return {}
	return {"id": ACTION, "verb": String(sp.get("verb", "ACTION_PAINT")), "label": "PROGRESS_PAINTING", "duration": SECONDS}


## A stroke of the brush landing: its swish, and a few drops of the colour.
static func use_impact(node: Node, stack: ItemStack, hit: Dictionary) -> void:
	var at: Vector3 = hit.get("point", (node as Node3D).global_position if node is Node3D else Vector3.ZERO)
	Audio.play("brush", at, -5.0, 0.12, &"Effects", 4.0, 0.9)
	var color := holding(stack)
	if color != &"":
		var n: Vector3 = hit.get("normal", Vector3.UP)
		Fx.seed_scatter(at + n * 0.05, at + n * 0.02 + Vector3(0, -0.35, 0), 0.3, FarmIdentity.rgb(color))


## The coat is on: one can used, the colour kept, the listeners told.
static func complete_use(node: Node, stack: ItemStack, s: Dictionary = {}) -> bool:
	var color := holding(stack)
	if color == &"" or not PlayerState.inventory.has_item(stack.item.id):
		return false
	var sp := s if not s.is_empty() else spec(node)
	if not paint(node, color, sp):
		return false
	PlayerState.inventory.remove_item(stack.item.id, 1)
	Game.notify(TranslationServer.translate("MSG_PAINTED") % FarmIdentity.color_name(color), FarmIdentity.rgb(color).lightened(0.35))
	var works := FarmIdentity.works()
	if works:
		works.painted(node, String(sp.get("part", "")))
	return true


# --- Walls (no interactables of their own) ----------------------------------------------------

## The paint target under the crosshair when it is on a wall of the repaired farmhouse
## (from outside) or of a finished kit coop and a can of paint is in hand: the PaintSpot
## the player's hands then work on (Player._update_target); null otherwise.
static func wall_target(player: Node3D, ray: RayCast3D) -> Node:
	if holding(PlayerState.selected_stack()) == &"" or not ray.is_colliding():
		return null
	var n := ray.get_collider() as Node
	var what: Node = null
	for i in 8:
		if n == null:
			break
		if n is FarmHouse or n is ChickenCoop:
			what = n
			break
		n = n.get_parent()
	if what == null:
		return null
	if what is FarmHouse:
		# From the yard, not from the kitchen.
		var at := Vector2(player.global_position.x, player.global_position.z)
		if WorldLayout.house_rect((what as FarmHouse).level).has_point(at):
			return null
	elif coop_spec(what as ChickenCoop).is_empty():
		return null
	if _spot == null or not is_instance_valid(_spot):
		_spot = PaintSpot.new()
		_spot.name = "PaintSpot"
		Game.world.add_child(_spot)
	_spot.aim(what, ray.get_collision_point())
	return _spot


static func _house() -> FarmHouse:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group(&"farm_house") as FarmHouse if tree else null
