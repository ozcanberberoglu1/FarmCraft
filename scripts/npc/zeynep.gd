class_name ZeynepHome
extends Node3D
## Zeynep's home, the last house on the left at the far end of Yeşilova's street (Town's
## first house, on the north side, its front garden facing the street), and Zeynep and
## her dog Karamel in it. Town adds it for that house; SideStory decides what is up.
##
## The house: a working front door (Door) that swings in, which the player knocks on (E)
## rather than opens; the doorway stays closed to him even when it stands open (an
## unseen wall behind the one standing in it). A warm lamp lights the hallway behind it
## (Town builds the hallway) while it is open, with a soft fill toward the doorway. From
## dusk while she is up (not SideStory.asleep) the porch light under the canopy over the
## door is on and her windows glow warm through drawn curtains. Before she moves in
## (SideStory.MOVE_DAY) a "for sale" sign stands in the garden; from then on Karamel's
## doghouse, his water and food bowls, and moving boxes by the door that get fewer each
## day for BOXES_DAYS days.
##
## Zeynep (ZeynepPerson, a Townsperson): out in the garden down on a knee beside Karamel
## stroking his back (he sits at her right, both facing the street, looking round and up
## at her; her other hand on her raised knee, clear of his head) while her day has her
## out (SideStory.outside_now), indoors otherwise (hidden). With the player about she
## walks in and out through the door (it shuts behind her; she is out of sight once it
## has; the player in her way, she waits and asks to get by); far away she is simply
## where she should be. Scripted scenes: meeting her in the garden (she gets up, they
## talk, she goes in), a knock (after a moment the door opens, she steps into the doorway,
## in the frame facing him, a hand resting on the open door by her hip, and they talk; a
## bag of dog food she asked for she comes out on to the step to take in both hands; she
## steps back in and the door shuts; whoever knocked gone by then, nothing comes of it),
## handing her the bag in the garden (she fills Karamel's bowl) and a chat. A heart for a
## bag only once it is in her hands. Karamel eats from the bowl once it is filled (after
## the bag at her door, from indoors, while the player isn't looking at it).
##
## On the town's event days (EventCrowd: the carnival nights, the fishing contest) she goes
## too, Karamel at her heels: from the garden she walks out of the gate and over (he
## trots after her), from indoors she just has gone once nobody is about, and far from
## the player both are simply there; she stands where the event has her
## (EventCrowd.zeynep_spot), he potters about at her feet. Her errands wait for her to be
## home again: a knock meanwhile finds the house empty (a note says where she is), and E
## on her at the event is a friendly word. When it is over they walk home (or are home).

const GROUP := &"zeynep_home"
const MODEL := &"zeynep"
## The door leaf fits the frame in the house's 1.1 m doorway.
const DOOR_WIDTH := 0.94
const DOOR_HEIGHT := 2.1
## The door swings this far open for her to walk through, this far while she stands in it
## (back along the hall's side, clear of her).
const OPEN_WIDE := 96.0
const OPEN_DOORWAY := 84.0
## In the doorway she stands this far in from the front wall's outer face (in the frame,
## where the day outside reaches her face), and her hand rests on the open door's face by
## her hip: this far along it from the hinge, this high over its foot (metres).
const DOORWAY_IN := 0.32
const DOOR_HAND := Vector2(0.17, 0.8)
## The porch light and her windows come on once the day is this dark
## (DayNightCycle.night_factor).
const DUSK := 0.35
## The porch light's glass glows this bright while it is on.
const PORCH_GLOW := 1.6
## Seconds from a knock to the door opening.
const KNOCK_ANSWER := 1.5
## She waits in the hall for the door to shut as long as the player stands in the doorway
## (holding it open), and this long at most for anything else.
const SHUT_WAIT := 60.0
## The player in her way on a walk: she asks to get by after this long, and again every
## so often while he stays (seconds).
const EXCUSE_AFTER := 1.2
const EXCUSE_AGAIN := 9.0
## Within this distance of the player she walks in and out; farther, she just is there.
const WATCH_RANGE := 45.0
## How far from the person the player can be for a door conversation to start.
const TALK_RANGE := 6.0
## Taking the bag from the player she comes this near him (metres between them), and it
## goes from his hands to hers in this long (seconds).
const HAND_GAP := 1.0
const PASS_TIME := 0.45
## The moving boxes by the door stand this many days after moving day (fewer each day).
const BOXES_DAYS := 3
## Karamel's food is gone once he has eaten (Dog.ate), or this long after it was put
## out at the latest (seconds).
const BOWL_TIME := 45.0
## Petting him: where she kneels from where he sits (XZ: at his side, level with him),
## and how far he sits turned from the way to her (radians: facing the street, as she
## does), looking round and up at her.
const PET_OFFSET := Vector2(0.54, 0.0)
const PET_TURN := 1.5

## The house's footprint and floor height, and its front garden (world XZ).
var house := Rect2(268, -2, 11, 10)
var floor_y := 0.0
var garden := Rect2(267, 8, 13, 4)

var door: Door
var zeynep: ZeynepPerson
## Karamel.
var dog: Dog

## Where she is: &"away" (not moved in), &"garden", &"inside", &"door" (in the doorway),
## &"walking" or &"event" (at the town's event, or on her way there or back).
var where: StringName = &"away"
## At the event: the crowd she went with, her spot there ({pos, yaw, via}), on her way
## there or back ("there", "back"; "" standing there), Karamel's garden.
var _event: EventCrowd
var _event_spot := {}
var _event_walk := ""
var _garden_area := Rect2()

var _knocker: Knocker
var _blocker: StaticBody3D
var _light: OmniLight3D
var _fill: OmniLight3D
var _porch: OmniLight3D
var _porch_mat: StandardMaterial3D
## The drawn curtains glowing in her windows and the lamps behind them (lit together).
var _window_glow: Array[Node3D] = []
var _marker: Marker3D
var _sign: Node3D
var _dressing: Node3D
var _boxes: Array[Node3D] = []
var _bowl_food: MeshInstance3D
var _bowl_left := 0.0
## She fills the bowl from indoors (after the bag at her door) once the player can't see
## the bowl: the food never appears before his eyes.
var _fill_pending := false
var _held: Node3D
## The bag is on its way to her hands (she is coming for it); it has left the player's bag
## in this scene (only then is it delivered).
var _passing := false
var _bag_given := false
## The door scene's errand fills Karamel's bowl (dog food).
var _door_feeds := false
## What a door scene came to once she opened: "meet", "deliver", "chat", or "" (whoever
## knocked had gone).
var _door_outcome := ""
## A scripted scene's steps, run in order: {wait: seconds} | {do: Callable} |
## {until: Callable, limit: seconds, hold: Callable (the limit stands still while it
## holds), timeout: Callable (run if the limit runs out)}.
var _steps: Array[Dictionary] = []
## Her walk (_walk) has got where it goes, and where that is.
var _arrived := false
var _walk_end := Vector3.INF
## How long the player has stood in her way (negative: she asked to get by just now).
var _in_way_t := 0.0
## A scene's conversation is open (lambdas capture locals by value: kept here).
var _talking := false
var _pet_resume := 0.0
## The door shuts once nobody stands in its way (_shut_door); the hall light goes out after.
var _shut_pending := false
var _light_off := 0.0
var _sync_left := 0.0
var _boxes_day := -1


## The front door's interaction: knocking (the Door itself doesn't open for the player).
class Knocker extends Node3D:
	var home: ZeynepHome

	func interact_title() -> String:
		return tr("ZEYNEP_HOUSE") if SideStory.moved_in() else ""

	func interact_prompt(_player: Node) -> String:
		return tr("ACTION_KNOCK") if home.can_knock() else ""

	func interact(_player: Node) -> void:
		home.knock()


func _ready() -> void:
	name = "ZeynepHome"
	add_to_group(GROUP)
	_build_door()
	_build_light()
	_build_porch()
	_build_windows()
	_build_blocker()
	_dressing = Node3D.new()
	_dressing.name = "Garden"
	add_child(_dressing)
	_build_doghouse()
	_build_bowls()
	_build_boxes()
	_build_sign()
	_sync(true)


# --- Places -------------------------------------------------------------------------------------

## The middle of the doorway on the outer face of the front wall, at the floor.
func door_center() -> Vector3:
	return Vector3(house.position.x + 5.5, floor_y, house.end.y)


func _ground(x: float, z: float, near_y := INF) -> float:
	var from_y := (floor_y if near_y == INF else near_y) + 1.5
	if is_inside_tree():
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, from_y - 4.0, z), 1)
		q.exclude = [_blocker.get_rid()] if _blocker else []
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			return (hit["position"] as Vector3).y
	return TerrainData.height(x, z)


func _at(x: float, z: float) -> Vector3:
	return Vector3(x, _ground(x, z), z)


## Where Karamel is petted, and where Zeynep kneels by him (garden XZ): at his side,
## the side toward her door.
func _dog_spot() -> Vector2:
	return garden.position + Vector2(3.9, 2.6)


func _pet_spot() -> Vector2:
	return _dog_spot() + PET_OFFSET


## Well into the hall (out of sight once the door is shut); just in from the doorway and
## clear of the door's swing (where she steps back to for it to shut); in the doorway,
## DOORWAY_IN inside the frame beside the door opened OPEN_DOORWAY (her right hand on it),
## or a little further back when the player stands right on the threshold (never walking
## into him).
func _inside_spot() -> Vector3:
	var c := door_center()
	return Vector3(c.x + 0.05, floor_y + 0.02, c.z - 2.1)


func _back_spot() -> Vector3:
	var c := door_center()
	return Vector3(c.x + 0.4, floor_y + 0.02, c.z - 1.2)


func _doorway_spot() -> Vector3:
	var c := door_center()
	var z := c.z - DOORWAY_IN
	var p := Game.player as Node3D
	if p != null and is_instance_valid(p) and absf(p.global_position.x - c.x) < 0.9:
		z = clampf(p.global_position.z - 0.65, c.z - 0.88, z)
	return Vector3(c.x - 0.17, floor_y + 0.02, z)


## In front of the door step, on the garden path.
func _step_front() -> Vector3:
	var c := door_center()
	return _at(c.x, c.z + 1.25)


## The side dot: over Zeynep's head (it follows her), or at her door.
func zeynep_marker() -> Node3D:
	return _marker


func door_point() -> Vector3:
	return door.waypoint_point() + Vector3(0, 0.3, 0.35)


## She is out in the garden, or on her way to or from it (what the side hint and dot go
## by). Answering the door isn't: she is at home then, even with the door open.
func zeynep_outside() -> bool:
	return zeynep != null and (where == &"garden" or where == &"walking")


## Where the food bowl stands (Karamel eats there).
func bowl_point() -> Vector3:
	return _bowl_food.get_parent().global_position if _bowl_food else Vector3.INF


func bowl_full() -> bool:
	return _bowl_food != null and _bowl_food.visible


# --- Building -----------------------------------------------------------------------------------

func _build_door() -> void:
	_knocker = Knocker.new()
	_knocker.name = "FrontDoor"
	_knocker.home = self
	_knocker.add_to_group(&"interactable")
	add_child(_knocker)
	door = Door.new()
	door.name = "Door"
	door.style = &"plank"
	door.width = DOOR_WIDTH
	door.height = DOOR_HEIGHT
	door.open_angle = OPEN_WIDE
	door.door_id = &"zeynep_door"
	var c := door_center()
	# On the hinge line in the middle of the wall, the leaf running east across the frame.
	door.position = Vector3(c.x - DOOR_WIDTH * 0.5, floor_y + 0.025, c.z - 0.15 - Door.LEAF_T * 0.5)
	_knocker.add_child(door)
	# Knocked on, not opened: the knocker answers E for it.
	door.remove_from_group(&"interactable")


## A warm lamp in the hall, lit while the door is open, and with it a soft fill toward the
## doorway from outside it (the lamp's light off the hall's walls and the open door, and
## the day's or the porch light's off the step): whoever stands in the doorway is never a
## dark shape against the lit hall.
func _build_light() -> void:
	var c := door_center()
	_light = OmniLight3D.new()
	_light.name = "HallLight"
	_light.light_color = Color(1.0, 0.76, 0.5)
	_light.light_energy = 1.4
	_light.omni_range = 3.4
	_light.omni_attenuation = 1.2
	_light.shadow_enabled = false
	_light.position = Vector3(c.x, floor_y + 2.2, c.z - 2.0)
	_light.visible = false
	add_child(_light)
	_fill = OmniLight3D.new()
	_fill.name = "DoorwayFill"
	_fill.light_color = Color(1.0, 0.82, 0.64)
	_fill.light_energy = 0.4
	_fill.light_specular = 0.0
	_fill.omni_range = 2.3
	_fill.omni_attenuation = 1.4
	_fill.shadow_enabled = false
	_fill.position = Vector3(c.x, floor_y + 1.55, c.z + 0.8)
	_fill.visible = false
	add_child(_fill)


## The porch light under the canopy over the door: a frosted glass dome on a round black
## base, and its warm light down over the step and whoever opens the door.
func _build_porch() -> void:
	var c := door_center()
	var at := Vector3(c.x, floor_y + 2.455, c.z + 0.42)
	var base := MeshInstance3D.new()
	base.name = "PorchLamp"
	var bm := CylinderMesh.new()
	bm.top_radius = 0.075
	bm.bottom_radius = 0.08
	bm.height = 0.02
	bm.radial_segments = 16
	bm.rings = 1
	base.mesh = bm
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.1, 0.1, 0.1)
	metal.metallic = 0.6
	metal.roughness = 0.45
	base.material_override = metal
	base.position = at
	base.visibility_range_end = 60.0
	add_child(base)
	var dome := MeshInstance3D.new()
	dome.name = "Glass"
	var dm := SphereMesh.new()
	dm.radius = 0.065
	dm.height = 0.1
	dm.is_hemisphere = true
	dm.radial_segments = 16
	dm.rings = 6
	dome.mesh = dm
	_porch_mat = StandardMaterial3D.new()
	_porch_mat.albedo_color = Color(0.94, 0.92, 0.86)
	_porch_mat.roughness = 0.3
	_porch_mat.emission_enabled = true
	_porch_mat.emission = Color(1.0, 0.8, 0.55)
	_porch_mat.emission_energy_multiplier = 0.0
	dome.material_override = _porch_mat
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Hung under the base, the dome's round side down.
	dome.position = at - Vector3(0, 0.01, 0)
	dome.rotation.x = PI
	dome.visibility_range_end = 60.0
	add_child(dome)
	_porch = OmniLight3D.new()
	_porch.name = "PorchLight"
	_porch.light_color = Color(1.0, 0.79, 0.55)
	_porch.light_energy = 1.1
	_porch.omni_range = 4.6
	_porch.omni_attenuation = 1.3
	_porch.shadow_enabled = false
	_porch.distance_fade_enabled = true
	_porch.distance_fade_begin = 70.0
	_porch.distance_fade_length = 15.0
	_porch.position = at - Vector3(0, 0.09, 0)
	_porch.visible = false
	add_child(_porch)


## Her two front windows at night: the curtains drawn behind the glass, warm with the
## lamps in the rooms behind them (soft folds, brightest toward the middle), and a little
## of that light out over the sills and the garden. Lit together (_update_lamps).
func _build_windows() -> void:
	var img := Image.create(64, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 64:
			var u := (x + 0.5) / 64.0
			var v := (y + 0.5) / 32.0
			var fold := 0.8 + 0.2 * sin(u * TAU * 6.5 + sin(u * 11.0) * 0.8)
			var mid := 1.0 - 0.4 * pow(absf(u - 0.5) * 2.0, 2.0) - 0.3 * pow(absf(v - 0.6) * 1.6, 2.0)
			img.set_pixel(x, y, Color(1.0, 0.6, 0.28) * clampf(fold * mid, 0.0, 1.0))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.04, 0.03)
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mat.emission_texture = ImageTexture.create_from_image(img)
	mat.emission_energy_multiplier = 0.7
	# The two windows either side of the door (Town's house openings), their panes 1.46 x
	# 1.26 m from 0.97 m up; the curtains just behind the glass.
	for wx: float in [house.position.x + 2.5, house.position.x + 8.5]:
		var q := QuadMesh.new()
		q.size = Vector2(1.44, 1.24)
		var mi := MeshInstance3D.new()
		mi.name = "Curtains"
		mi.mesh = q
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(wx, floor_y + 1.6, house.end.y - 0.23)
		mi.visibility_range_end = 160.0
		mi.visible = false
		add_child(mi)
		_window_glow.append(mi)
		var l := OmniLight3D.new()
		l.name = "WindowLight"
		l.light_color = Color(1.0, 0.74, 0.46)
		l.light_energy = 0.6
		l.light_specular = 0.2
		l.omni_range = 2.8
		l.omni_attenuation = 1.2
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 60.0
		l.distance_fade_length = 15.0
		l.position = Vector3(wx, floor_y + 1.5, house.end.y - 0.5)
		l.visible = false
		add_child(l)
		_window_glow.append(l)


## The unseen wall just inside the doorway: the player never walks into her home.
func _build_blocker() -> void:
	var c := door_center()
	_blocker = StaticBody3D.new()
	_blocker.name = "Doorway"
	_blocker.collision_layer = 1
	_blocker.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 2.2, 0.2)
	cs.shape = box
	cs.position = Vector3(c.x, floor_y + 1.1, c.z - 1.02)
	_blocker.add_child(cs)
	add_child(_blocker)


func _mesh(mb: MeshBuilder, node_name: String, parent: Node3D, range_end := 70.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mb.build()
	mi.visibility_range_end = range_end
	mi.visibility_range_end_margin = 6.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mi)
	return mi


func _collider(parent: Node3D, center: Vector3, size: Vector3, yaw := 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = center
	cs.rotation.y = yaw
	body.add_child(cs)
	parent.add_child(body)


## Karamel's doghouse at the west end of the garden, its door facing the path: a board
## house on a raised floor, a gabled roof of shingles, a round-topped doorway and his
## name on a board over it.
func _build_doghouse() -> void:
	var at := garden.position + Vector2(1.6, 1.3)
	var root := Node3D.new()
	root.name = "Doghouse"
	root.position = _at(at.x, at.y)
	# Its doorway faces east, toward the path.
	root.rotation.y = PI * 0.5
	_dressing.add_child(root)
	var mb := MeshBuilder.new()
	var wood := Color(0.62, 0.46, 0.32)
	var trim := Color(0.93, 0.9, 0.84)
	var w := 0.9
	var d := 1.1
	var h := 0.72
	# Floor on runners, clear of the wet ground.
	for rx: float in [-w * 0.4, w * 0.4]:
		mb.box_at(&"wood", Vector3(rx, 0.03, 0), Vector3(0.06, 0.06, d), wood.darkened(0.25))
	mb.box_at(&"planks", Vector3(0, 0.075, 0), Vector3(w, 0.03, d), wood.darkened(0.1))
	# Board walls: back, sides and the front around the doorway (local +Z is the front).
	var t := 0.03
	mb.box_at(&"planks", Vector3(0, 0.09 + h * 0.5, -d * 0.5 + t * 0.5), Vector3(w, h, t), wood)
	for sx: float in [-1.0, 1.0]:
		mb.box_at(&"planks", Vector3(sx * (w * 0.5 - t * 0.5), 0.09 + h * 0.5, 0), Vector3(t, h, d), wood, Vector3.ZERO, true)
	var hole := 0.38
	for sx: float in [-1.0, 1.0]:
		var pw := (w - hole) * 0.5
		mb.box_at(&"planks", Vector3(sx * (hole * 0.5 + pw * 0.5), 0.09 + h * 0.5, d * 0.5 - t * 0.5), Vector3(pw, h, t), wood)
	mb.box_at(&"planks", Vector3(0, 0.09 + h - 0.08, d * 0.5 - t * 0.5), Vector3(hole, 0.16, t), wood)
	# The doorway's rounded top and its painted trim.
	for k in 7:
		var a := PI * float(k) / 6.0
		var p := Vector3(cos(a) * hole * 0.5, 0.09 + 0.46 + sin(a) * 0.12, d * 0.5 + 0.004)
		mb.box_at(&"paint", p, Vector3(0.07, 0.035, 0.012), trim, Vector3(0, 0, rad_to_deg(a) - 90.0))
	for sx: float in [-1.0, 1.0]:
		mb.box_at(&"paint", Vector3(sx * hole * 0.5, 0.09 + 0.23, d * 0.5 + 0.004), Vector3(0.035, 0.46, 0.012), trim)
	# Gable ends and the roof: two shingled slopes over the gable.
	var rise := 0.32
	var eave := 0.09 + h
	for sz: float in [-1.0, 1.0]:
		var z := sz * (d * 0.5 - t * 0.5)
		mb.tri(&"planks", Vector3(-w * 0.5, eave, z), Vector3(w * 0.5, eave, z), Vector3(0, eave + rise, z), wood)
		mb.tri(&"planks", Vector3(w * 0.5, eave, z), Vector3(-w * 0.5, eave, z), Vector3(0, eave + rise, z), wood)
	var slope := atan2(rise, w * 0.5)
	var run := sqrt(rise * rise + w * w * 0.25) + 0.08
	for sx: float in [-1.0, 1.0]:
		var c := Vector3(sx * w * 0.25, eave + rise * 0.5 + 0.03, 0)
		mb.box(&"roof", Transform3D(Basis(Vector3.BACK, -sx * slope), c), Vector3(run, 0.035, d + 0.16), Color(0.36, 0.3, 0.28))
	mb.box_at(&"wood", Vector3(0, eave + rise + 0.03, 0), Vector3(0.06, 0.05, d + 0.18), wood.darkened(0.3))
	# Some straw inside.
	mb.box_at(&"straw", Vector3(0, 0.1, -0.05), Vector3(w - 0.1, 0.02, d - 0.2), Color(0.8, 0.68, 0.42))
	_mesh(mb, "Doghouse", root)
	# His name on a small board over the doorway.
	var board := MeshBuilder.new()
	board.box_at(&"paint", Vector3(0, eave - 0.06, d * 0.5 + 0.012), Vector3(0.36, 0.1, 0.012), trim)
	_mesh(board, "NameBoard", root, 30.0)
	var label := Label3D.new()
	label.text = tr("DOG_KARAMEL")
	label.font = UiTheme.font(700)
	label.font_size = 36
	label.pixel_size = 0.0018
	label.modulate = Color(0.32, 0.2, 0.12)
	label.outline_size = 0
	label.shaded = true
	label.double_sided = false
	label.position = Vector3(0, eave - 0.06, d * 0.5 + 0.02)
	label.visibility_range_end = 25.0
	root.add_child(label)
	_collider(root, Vector3(0, 0.5, 0), Vector3(w + 0.04, 1.0, d + 0.1))


## Karamel's water and food bowls in front of the doghouse (the food shows once filled).
func _build_bowls() -> void:
	var spots := [garden.position + Vector2(2.6, 1.0), garden.position + Vector2(2.65, 1.6)]
	for i in 2:
		var p: Vector2 = spots[i]
		var root := Node3D.new()
		root.name = "WaterBowl" if i == 0 else "FoodBowl"
		root.position = _at(p.x, p.y)
		_dressing.add_child(root)
		var mb := MeshBuilder.new()
		var steel := Color(0.72, 0.73, 0.74)
		mb.cylinder(&"steel", Transform3D(Basis(), Vector3(0, 0.0, 0)), 0.1, 0.13, 0.065, 20, steel)
		mb.ring(&"steel", Transform3D(Basis(), Vector3(0, 0.063, 0)), 0.132, 0.115, 0.006, 20, steel.lightened(0.1))
		if i == 0:
			mb.disc(&"water_still", Transform3D(Basis(), Vector3(0, 0.05, 0)), 0.112, 20, Color(0.32, 0.38, 0.4))
		_mesh(mb, "Bowl", root, 40.0)
		if i == 1:
			var food := MeshBuilder.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = 12
			food.disc(&"veg_rough", Transform3D(Basis(), Vector3(0, 0.045, 0)), 0.108, 18, Color(0.36, 0.22, 0.12))
			for k in 26:
				var a := rng.randf() * TAU
				var r := sqrt(rng.randf()) * 0.09
				food.sphere(&"veg_rough", Transform3D(Basis(), Vector3(cos(a) * r, 0.052 + rng.randf() * 0.012, sin(a) * r)),
						Vector3(0.011, 0.008, 0.011), 5, 3, Color(0.42, 0.26, 0.14).lightened(rng.randf_range(-0.1, 0.1)))
			_bowl_food = _mesh(food, "Food", root, 30.0)
			_bowl_food.visible = false


## Moving boxes by the door: brown cardboard with packing tape, one standing open.
func _build_boxes() -> void:
	var c := door_center()
	var specs := [
		[Vector3(c.x + 1.55, 0.0, c.z + 0.4), Vector3(0.55, 0.42, 0.45), 0.12, false],
		[Vector3(c.x + 2.12, 0.0, c.z + 0.45), Vector3(0.5, 0.38, 0.42), -0.18, false],
		[Vector3(c.x + 1.6, 0.42, c.z + 0.38), Vector3(0.44, 0.32, 0.36), 0.32, false],
		[Vector3(c.x - 1.75, 0.0, c.z + 0.45), Vector3(0.52, 0.4, 0.42), 0.22, false],
		[Vector3(c.x + 2.75, 0.0, c.z + 0.95), Vector3(0.48, 0.36, 0.4), 0.6, true],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 606
	for s: Array in specs:
		var base: Vector3 = s[0]
		var size: Vector3 = s[1]
		var root := Node3D.new()
		root.name = "Box"
		# On the garden's ground (a stacked one on the box under it).
		root.position = Vector3(base.x, TerrainData.height(base.x, base.z) + base.y, base.z)
		root.rotation.y = float(s[2])
		_dressing.add_child(root)
		var mb := MeshBuilder.new()
		var card := Color(0.62, 0.46, 0.3).lightened(rng.randf_range(-0.06, 0.05))
		var open: bool = s[3]
		if open:
			# Four walls and the floor, the flaps folded out.
			var t := 0.008
			mb.box_at(&"paper", Vector3(0, 0.004, 0), Vector3(size.x, t, size.z), card.darkened(0.2))
			for sz: float in [-1.0, 1.0]:
				mb.box_at(&"paper", Vector3(0, size.y * 0.5, sz * (size.z - t) * 0.5), Vector3(size.x, size.y, t), card)
				mb.box_at(&"paper", Vector3(0, size.y + 0.1, sz * (size.z * 0.5 + 0.07)), Vector3(size.x - 0.01, 0.005, 0.2), card.darkened(0.05),
						Vector3(sz * -62.0, 0, 0))
			for sx: float in [-1.0, 1.0]:
				mb.box_at(&"paper", Vector3(sx * (size.x - t) * 0.5, size.y * 0.5, 0), Vector3(t, size.y, size.z), card.darkened(0.04))
			# Packing paper crumpled in the top.
			for k in 4:
				mb.blob(&"paper", Transform3D(Basis(), Vector3(rng.randf_range(-0.12, 0.12), size.y - 0.04, rng.randf_range(-0.1, 0.1))),
						0.07, 1, Color(0.9, 0.88, 0.84), 0.35, 4.0, k, 0.05)
		else:
			mb.box_at(&"paper", Vector3(0, size.y * 0.5, 0), size, card)
			# Tape along the seam over the top and down the ends; the seam itself.
			mb.box_at(&"paper", Vector3(0, size.y + 0.001, 0), Vector3(0.05, 0.002, size.z + 0.002), Color(0.72, 0.6, 0.42))
			for sz: float in [-1.0, 1.0]:
				mb.box_at(&"paper", Vector3(0, size.y - 0.07, sz * (size.z * 0.5 + 0.001)), Vector3(0.05, 0.14, 0.002), Color(0.72, 0.6, 0.42))
			mb.box_at(&"paper", Vector3(0, size.y + 0.0015, 0), Vector3(0.004, 0.002, size.z), card.darkened(0.35))
			# A few words in marker on the side.
			for k in 3:
				mb.box_at(&"paper", Vector3(-size.x * 0.2 + k * 0.06, size.y * 0.55, size.z * 0.5 + 0.002), Vector3(0.045, 0.012, 0.002),
						Color(0.08, 0.08, 0.1), Vector3(0, 0, rng.randf_range(-8.0, 8.0)))
		_mesh(mb, "Mesh", root, 60.0)
		_collider(root, Vector3(0, size.y * 0.5, 0), size)
		_boxes.append(root)


## "For sale" on a board on a post in the garden, facing the street, until she moves in.
func _build_sign() -> void:
	var p := garden.position + Vector2(garden.size.x - 2.6, garden.size.y - 0.6)
	_sign = Node3D.new()
	_sign.name = "ForSale"
	_sign.position = _at(p.x, p.y)
	add_child(_sign)
	var mb := MeshBuilder.new()
	var post := Color(0.45, 0.42, 0.4)
	mb.box_at(&"wood", Vector3(0, 0.75, 0), Vector3(0.08, 1.5, 0.08), post)
	mb.box_at(&"wood", Vector3(0.28, 1.42, 0), Vector3(0.62, 0.05, 0.05), post, Vector3.ZERO, true)
	mb.box_at(&"paint", Vector3(0.3, 1.14, 0), Vector3(0.62, 0.4, 0.02), Color(0.92, 0.9, 0.84))
	mb.box_at(&"paint", Vector3(0.3, 1.27, 0.0), Vector3(0.62, 0.12, 0.024), Color(0.74, 0.14, 0.1))
	for sx: float in [0.08, 0.52]:
		mb.cylinder_between(&"metal", Vector3(sx, 1.4, 0), Vector3(sx, 1.33, 0), 0.004, 0.004, 4, Color(0.3, 0.3, 0.3))
	_mesh(mb, "Sign", _sign)
	for side: float in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = tr("SIGN_FOR_SALE")
		l.font = UiTheme.font(800)
		l.font_size = 30
		l.pixel_size = 0.0022
		l.modulate = Color(1, 1, 1)
		l.outline_size = 0
		l.shaded = true
		l.double_sided = false
		l.position = Vector3(0.3, 1.27, 0.014 * side)
		l.rotation.y = 0.0 if side > 0.0 else PI
		l.visibility_range_end = 40.0
		_sign.add_child(l)
	_collider(_sign, Vector3(0, 0.75, 0), Vector3(0.12, 1.5, 0.12))


# --- The people ---------------------------------------------------------------------------------

func _spawn() -> void:
	if zeynep != null:
		return
	dog = Dog.new()
	dog.name = "Karamel"
	dog.home_area = Rect2(garden.position.x, garden.position.y + 0.75, garden.size.x, garden.size.y - 0.75)
	_garden_area = dog.home_area
	dog.name_key = "DOG_KARAMEL"
	dog.ate.connect(_on_dog_ate)
	var ds := _dog_spot()
	dog.position = _at(ds.x, ds.y)
	add_child(dog)
	zeynep = ZeynepPerson.new()
	zeynep.name = "Zeynep"
	zeynep.person = SideStory.WHO
	zeynep.home = self
	zeynep.setup(MODEL)
	zeynep.act = Townsperson.Act.STAND
	# Karamel on her right, both facing the street.
	zeynep.pet_hand = "_r"
	var zs := _pet_spot()
	zeynep.position = _at(zs.x, zs.y)
	add_child(zeynep)
	_marker = Marker3D.new()
	_marker.name = "Dot"
	_marker.position = Vector3(0, 2.05, 0)
	zeynep.add_child(_marker)
	where = &"garden"


func _despawn() -> void:
	_steps.clear()
	_event = null
	_event_walk = ""
	_passing = false
	_bag_given = false
	_fill_pending = false
	if zeynep:
		zeynep.queue_free()
	if dog:
		dog.queue_free()
	zeynep = null
	dog = null
	_marker = null
	where = &"away"
	_shut_pending = false
	if door.is_open():
		door.set_open(false, false)
	_light.visible = false


func _dog_mode(mode: StringName, at := Vector3.INF) -> void:
	if dog:
		dog.set_mode(mode, at)


## Her yaw to face `p`.
func _yaw_to(p: Vector3) -> float:
	var d := p - zeynep.global_position
	return atan2(d.x, d.z)


func _face(p: Vector3, seconds := 0.5) -> void:
	var yaw := _yaw_to(p)
	var tw := zeynep.create_tween()
	tw.tween_property(zeynep, "rotation:y", zeynep.rotation.y + wrapf(yaw - zeynep.rotation.y, -PI, PI), seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Kneeling by Karamel in the garden, petting him (`instant`: both put there at once).
func _start_petting(instant: bool) -> void:
	if instant:
		zeynep.stop_walk()
		var ds := _dog_spot()
		dog.global_position = _at(ds.x, ds.y)
		var zs := _pet_spot()
		zeynep.global_position = _at(zs.x, zs.y)
		# Already turned as she kneels (walking up, she turns herself).
		zeynep.rotation.y = _yaw_to(dog.pet_point()) + Townsperson.PET_ASIDE
	zeynep.set_indoors(false)
	zeynep.pet_target = dog
	zeynep.act = Townsperson.Act.PET
	# He sits beside her facing the street as she does, his head round to her.
	var to_her := Vector2(zeynep.global_position.x - dog.global_position.x, zeynep.global_position.z - dog.global_position.z)
	var a := to_her.rotated(PET_TURN)
	var b := to_her.rotated(-PET_TURN)
	var facing := a if a.y > b.y else b
	dog.petted_toward = dog.global_position + Vector3(facing.x, 0.0, facing.y).normalized() * 2.0
	_dog_mode(&"petted", zeynep.global_position)
	where = &"garden"


## Out in the garden at once (nobody near to see her come out).
func _place_in_garden() -> void:
	_start_petting(true)


## Indoors at once.
func _place_inside() -> void:
	zeynep.stop_walk()
	zeynep.global_position = _inside_spot()
	zeynep.act = Townsperson.Act.STAND
	zeynep.set_indoors(true)
	_dog_mode(&"roam")
	where = &"inside"


## Walks her along `points` (Townsperson.walk_to: feet on the ground, at a walking pace),
## then `_arrived` is set.
func _walk(points: Array[Vector3]) -> void:
	_arrived = false
	_walk_end = points.back() if not points.is_empty() else zeynep.global_position
	zeynep.walk_to(points, func() -> void: _arrived = true)


## Waits for her walk to get there: as long as the player stands in her way, else `limit`
## seconds at most (then she is put where it ends: never left out of place).
func _until_arrived(limit: float) -> Dictionary:
	return {"until": func() -> bool: return _arrived, "limit": limit, "hold": _in_her_way, "timeout": _finish_walk}


func _in_her_way() -> bool:
	return zeynep != null and zeynep.blocked_by_player()


func _finish_walk() -> void:
	if zeynep == null or _arrived:
		return
	zeynep.stop_walk()
	if _walk_end.is_finite():
		zeynep.global_position = _walk_end
	_arrived = true


## Hands `item` to her: she takes it in both hands and holds it (Townsperson.receive; it
## is hers from then on, nothing here moves it).
func _give(item: Node3D) -> void:
	_held = item
	zeynep.receive(item)


func _drop_held() -> void:
	_passing = false
	if zeynep:
		zeynep.drop_held()
	if _held and is_instance_valid(_held):
		_held.queue_free()
	_held = null


## Small talking gestures and nods for a line of `text`.
func _talk_for(text: String) -> void:
	if zeynep:
		zeynep.talk(clampf(text.length() / 16.0, 1.2, 6.0))


# --- Scenes -------------------------------------------------------------------------------------

func busy() -> bool:
	return not _steps.is_empty()


func can_talk() -> bool:
	return not busy() and where == &"garden" and zeynep != null and not zeynep.is_indoors() \
			and not _dialogue().is_open()


func can_knock() -> bool:
	return SideStory.moved_in() and zeynep != null and not busy() and not door.is_open() and not door.is_moving()


func _dialogue() -> DialogueScreen:
	return (Game.hud as HUD).dialogue_screen


func _play(steps: Array[Dictionary]) -> void:
	_steps.append_array(steps)


static func _wait(seconds: float) -> Dictionary:
	return {"wait": seconds}


static func _do(c: Callable) -> Dictionary:
	return {"do": c}


static func _until(c: Callable, limit := 20.0) -> Dictionary:
	return {"until": c, "limit": limit}


func _run_steps(delta: float) -> void:
	while not _steps.is_empty():
		var s: Dictionary = _steps[0]
		if s.has("wait"):
			s["wait"] = float(s["wait"]) - delta
			if float(s["wait"]) > 0.0:
				return
			delta = 0.0
		elif s.has("until"):
			if not (s.has("hold") and (s["hold"] as Callable).call()):
				s["limit"] = float(s["limit"]) - delta
			if not (s["until"] as Callable).call():
				if float(s["limit"]) > 0.0:
					return
				if s.has("timeout"):
					(s["timeout"] as Callable).call()
		_steps.pop_front()
		if s.has("do"):
			(s["do"] as Callable).call()


## Opens the conversation `lines` (SideStory's, their tags turned into cues) facing her.
func _talk_lines(lines: Array, on_done: Callable) -> void:
	var talk: Array = []
	for l: Dictionary in lines:
		var line := l.duplicate()
		var tag := String(l.get("tag", ""))
		var text := String(l.get("text", ""))
		var hers := StringName(l.get("who", &"")) == SideStory.WHO
		line["cue"] = func() -> void:
			if hers:
				_talk_for(text)
			_cue(tag)
		talk.append(line)
	_dialogue().open(talk, on_done, zeynep)


func _cue(tag: String) -> void:
	match tag:
		"stand":
			zeynep.act = Townsperson.Act.STAND
			_face(Game.player.global_position, 0.8)
			_dog_mode(&"greet", Game.player.global_position)
		"take":
			_hand_over()


## What the errand asked for (a bag of dog food, the milk, the flowers...) from the
## player's bag into her hands: she lets go of the door and comes out to him (on to the
## door step at most, or across her garden) until they are HAND_GAP apart, and it goes
## from his hands to hers.
func _hand_over() -> void:
	var item := SideStory.errand_item()
	var n := SideStory.errand_count()
	if item == &"" or PlayerState.inventory.count_item(item) < n:
		return
	PlayerState.inventory.remove_item(item, n)
	_bag_given = true
	var bag := MeshInstance3D.new()
	bag.name = "Given"
	bag.mesh = ItemModels.mesh(item)
	bag.visible = false
	add_child(bag)
	_held = bag
	_passing = true
	var to := _hand_over_spot()
	if to.distance_to(zeynep.global_position) < 0.15:
		zeynep.act = Townsperson.Act.STAND
		_face(Game.player.global_position, 0.3)
		_pass_bag(bag)
		return
	zeynep.walk_to([to], func() -> void:
		if is_instance_valid(bag) and is_instance_valid(zeynep):
			_face(Game.player.global_position, 0.3)
			_pass_bag(bag))


## Where she takes the bag: toward the player until HAND_GAP from him, out through the
## doorway no further than the door step, or within her garden.
func _hand_over_spot() -> Vector3:
	var here := zeynep.global_position
	var p := Game.player as Node3D
	if p == null:
		return here
	var to := Vector3(p.global_position.x - here.x, 0.0, p.global_position.z - here.z)
	var at := here + to.normalized() * maxf(to.length() - HAND_GAP, 0.0) if to.length() > 0.01 else here
	var c := door_center()
	if where == &"door":
		at.z = minf(at.z, c.z + 0.4)
		at.x = clampf(at.x, c.x - (0.3 if at.z < c.z else 0.5), c.x + (0.3 if at.z < c.z else 0.5))
		return Vector3(at.x, floor_y + 0.02 if at.z < c.z + 0.7 else _ground(at.x, at.z), at.z)
	var g := garden.grow(-0.45)
	at.x = clampf(at.x, g.position.x, g.end.x)
	at.z = clampf(at.z, g.position.y + 0.4, g.end.y)
	return _at(at.x, at.z)


## The bag from the player's hands to in front of her, and into hers.
func _pass_bag(bag: MeshInstance3D) -> void:
	var p := Game.player as Player
	var reach := zeynep.global_transform * Vector3(0.0, 1.02, 0.4)
	var yaw := zeynep.rotation.y + PI
	if p:
		bag.global_transform = Transform3D(Basis(Vector3.UP, yaw), p.camera.global_transform * Vector3(0.12, -0.3, -0.5))
	else:
		bag.global_transform = Transform3D(Basis(Vector3.UP, yaw), reach)
	bag.visible = true
	var tw := bag.create_tween()
	tw.tween_property(bag, "global_position", reach, PASS_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_give(bag)
	_passing = false


## Nothing on its way to her hands any more: the bag is in them (or there is none).
func _bag_taken() -> bool:
	if _passing:
		return false
	return _held == null or not is_instance_valid(_held) or _held.get_parent() == zeynep.rig


## E on her in the garden: meeting her, the bag she asked for, or a word.
func talk() -> void:
	if not can_talk():
		return
	if not SideStory.met:
		_scene_meet_garden()
	elif SideStory.can_deliver():
		_scene_deliver_garden()
	else:
		_scene_chat_garden()


## The first meeting in the garden: she gets up from Karamel and they talk, then she goes
## in.
func _scene_meet_garden() -> void:
	_talking = true
	_play([
		_do(func() -> void: _talk_lines(SideStory.lines_meet(false), func() -> void: _talking = false)),
		_until(func() -> bool: return not _talking, 600.0),
		_do(func() -> void:
			SideStory.on_met()
			_dog_mode(&"roam")),
		_wait(0.6),
	])
	_play_walk_in()


## Handing her the bag in the garden: she gets up, takes it, fills Karamel's bowl.
func _scene_deliver_garden() -> void:
	_talking = true
	_bag_given = false
	_play([
		_do(func() -> void:
			zeynep.act = Townsperson.Act.STAND
			_face(Game.player.global_position, 0.7)),
		_wait(0.8),
		_do(func() -> void:
			# The bag gone from his bag while she got up: only a word, then.
			var lines: Array = SideStory.lines_deliver(false) if SideStory.can_deliver() else SideStory.lines_chat(false)
			_talk_lines(lines, func() -> void: _talking = false)),
		_until(func() -> bool: return not _talking, 600.0),
		_until(_bag_taken, 6.0),
		_wait(0.4),
		_do(_after_garden_bag),
	])


## After the talk in the garden: with the bag in her hands (and only then) the heart, and
## she fills Karamel's bowl and comes back to him; without it she goes back down to him.
## Other things (the milk, the flowers) she takes in later; a visit or the pup needs
## nothing handed over.
func _after_garden_bag() -> void:
	if not _bag_given and SideStory.errand_needs_item():
		SideStory.on_chat()
		_pet_resume = 1.0
		return
	var feeds := SideStory.errand_kind() in SideStory.FEEDS_KARAMEL
	SideStory.on_delivered()
	if not feeds:
		_play([
			_wait(0.6),
			_do(func() -> void:
				_drop_held()
				where = &"walking"
				var zs := _pet_spot()
				_walk([_at(zs.x, zs.y)])),
			_until_arrived(12.0),
			_do(func() -> void:
				where = &"garden"
				zeynep.act = Townsperson.Act.STAND
				_pet_resume = 1.0),
		])
		return
	_play([
		_do(func() -> void:
			where = &"walking"
			var b := bowl_point()
			var side := b + (Vector3(_pet_spot().x, b.y, _pet_spot().y) - b).normalized() * 0.55
			_walk([_at(side.x, side.z)])),
		_until_arrived(12.0),
		_do(func() -> void:
			zeynep.rotation.y = _yaw_to(bowl_point())
			_drop_held()
			_fill_bowl()),
		_wait(1.2),
		_do(func() -> void:
			var zs := _pet_spot()
			_walk([_at(zs.x, zs.y)])),
		_until_arrived(12.0),
		_do(func() -> void:
			# (She turns to Karamel herself as she goes down to him.)
			where = &"garden"
			zeynep.act = Townsperson.Act.STAND
			_pet_resume = 1.0),
	])


## A word with her in the garden, still crouched by Karamel.
func _scene_chat_garden() -> void:
	_talking = true
	_play([
		_do(func() -> void: _talk_lines(SideStory.lines_chat(false), func() -> void: _talking = false)),
		_until(func() -> bool: return not _talking, 600.0),
		_do(func() -> void: SideStory.on_chat()),
	])


## E on the front door: three knocks, then her answer (see the class notes).
func knock() -> void:
	if not can_knock():
		return
	Audio.play("knock", door.handle_point(), -2.0, 0.05)
	if where == &"garden" or where == &"walking":
		# She is out in the garden: she calls over.
		_play([_wait(0.7), _do(func() -> void:
			if zeynep and not zeynep.is_indoors():
				zeynep.say(tr("ZEYNEP_SAY_GARDEN"))
				_face(Game.player.global_position, 0.6))])
		return
	if where == &"event":
		# Out at the town's event: nobody home.
		_play([_wait(KNOCK_ANSWER + 0.6), _do(func() -> void: Game.notify(tr("MSG_ZEYNEP_AT_EVENT"), UiTheme.TEXT_MUTED))])
		return
	if SideStory.asleep():
		_play([_wait(KNOCK_ANSWER + 0.6), _do(func() -> void: Game.notify(tr("MSG_ZEYNEP_ASLEEP"), UiTheme.TEXT_MUTED))])
		return
	if SideStory.met and not SideStory.can_deliver() and SideStory.knock_cooling():
		_play([_wait(KNOCK_ANSWER + 0.3), _do(func() -> void: Game.notify(tr("MSG_ZEYNEP_BUSY"), UiTheme.TEXT_MUTED))])
		return
	_scene_door()


## She answers the door: steps into the doorway, they talk (meeting her, the bag, or a
## word: whichever it is when she opens, with what he has on him then), she steps back
## in and the door shuts; once it has, she is indoors. If whoever knocked has gone by
## then, nothing comes of it.
func _scene_door() -> void:
	_talking = true
	_bag_given = false
	_door_outcome = ""
	var c := door_center()
	_play([
		_wait(KNOCK_ANSWER),
		_do(func() -> void:
			where = &"door"
			zeynep.global_position = _back_spot()
			zeynep.rotation.y = 0.0
			zeynep.act = Townsperson.Act.STAND
			zeynep.set_indoors(false)
			door.open_angle = OPEN_DOORWAY
			door.set_open(true)
			_light.visible = true),
		_wait(0.6),
		_do(func() -> void: _walk([_doorway_spot()])),
		_until_arrived(5.0),
		_do(func() -> void:
			zeynep.act = Townsperson.Act.DOORWAY
			_face(Game.player.global_position, 0.4)),
		_wait(0.5),
		_do(func() -> void:
			var p := Game.player as Node3D
			if p == null or p.global_position.distance_to(zeynep.global_position) > TALK_RANGE:
				# Whoever knocked has gone.
				zeynep.say(tr("ZEYNEP_SAY_NOBODY"))
				_talking = false
				return
			_door_outcome = "meet" if not SideStory.met else ("deliver" if SideStory.can_deliver() else "chat")
			var lines: Array = SideStory.lines_meet(true) if _door_outcome == "meet" else \
					(SideStory.lines_deliver(true) if _door_outcome == "deliver" else SideStory.lines_chat(true))
			_talk_lines(lines, func() -> void: _talking = false)),
		_until(func() -> bool: return not _talking, 600.0),
		_until(_bag_taken, 6.0),
		_do(func() -> void:
			_door_done()
			zeynep.act = Townsperson.Act.STAND
			# Back in (from the door step if she came out for the bag), out of the door's way.
			_walk([Vector3(c.x + 0.15, floor_y + 0.02, c.z - 0.7), _back_spot()])),
		_until_arrived(6.0),
		_do(_shut_door),
		_until_shut(),
		_do(func() -> void:
			_drop_held()
			zeynep.set_indoors(true)
			zeynep.global_position = _inside_spot()
			where = &"inside"
			if _door_outcome == "deliver" and _bag_given and _door_feeds:
				# After the bag she fills Karamel's bowl from indoors (while the player
				# isn't looking at it).
				_play([_wait(1.2), _do(func() -> void: _fill_pending = true)])),
	])


## What came of a door scene: meeting her, the bag (a heart only once it is in her
## hands), or a word; nothing when whoever knocked had gone.
func _door_done() -> void:
	match _door_outcome:
		"meet":
			SideStory.on_met()
		"deliver":
			_door_feeds = SideStory.errand_kind() in SideStory.FEEDS_KARAMEL
			if _bag_given or not SideStory.errand_needs_item():
				SideStory.on_delivered()
			else:
				SideStory.on_chat()
		"chat":
			SideStory.on_chat()
			SideStory.note_knock()


## Shuts the front door as soon as nobody stands in its way (the shutting leaf would
## catch the player in the doorway, between it and the unseen wall behind).
func _shut_door() -> void:
	_shut_pending = true


## The door has swung shut (she goes out of sight behind it only then).
func _door_shut() -> bool:
	return not _shut_pending and not door.is_open() and not door.is_moving()


## Waits for the door to shut: as long as the player stands in the doorway (she waits in
## the hall), else SHUT_WAIT at most.
func _until_shut() -> Dictionary:
	return {"until": _door_shut, "limit": SHUT_WAIT, "hold": _player_in_doorway}


## The player stands in the doorway, where the door swings.
func _player_in_doorway() -> bool:
	var p := Game.player as Node3D
	if p == null or not is_instance_valid(p):
		return false
	var c := door_center()
	var at := p.global_position
	return absf(at.x - c.x) < DOOR_WIDTH * 0.5 + 0.35 and at.z < c.z + 0.3 and at.z > c.z - 1.3


## Food in Karamel's bowl, and Karamel eats.
func _fill_bowl() -> void:
	_fill_pending = false
	if _bowl_food == null:
		return
	_bowl_food.visible = true
	_bowl_left = BOWL_TIME
	_dog_mode(&"eat", bowl_point())


## The bowl is out of the player's view.
func _bowl_unseen() -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam == null or not cam.is_position_in_frustum(bowl_point() + Vector3(0, 0.05, 0))


## Karamel has eaten up.
func _on_dog_ate() -> void:
	_bowl_left = 0.0
	if _bowl_food:
		_bowl_food.visible = false


## Walks her from where she is up the path and in; the door opens for her and shuts
## behind her once she is down the hall (then she is indoors).
func _play_walk_in() -> void:
	var c := door_center()
	_play([
		_do(func() -> void:
			where = &"walking"
			zeynep.act = Townsperson.Act.STAND
			_walk([_at(c.x - 0.15, c.z + 1.7), _step_front()])),
		_until_arrived(20.0),
		_do(func() -> void:
			door.open_angle = OPEN_WIDE
			door.set_open(true)
			_light.visible = true),
		_wait(0.7),
		_do(func() -> void: _walk([Vector3(c.x, floor_y + 0.02, c.z - 0.2), _inside_spot()])),
		_until_arrived(12.0),
		_do(_shut_door),
		_until_shut(),
		_do(func() -> void:
			zeynep.set_indoors(true)
			where = &"inside"),
	])


## Out of the door, down the path to Karamel, and she kneels by him.
func _play_come_out() -> void:
	var c := door_center()
	_play([
		_do(func() -> void:
			where = &"walking"
			zeynep.global_position = _inside_spot()
			zeynep.rotation.y = 0.0
			zeynep.act = Townsperson.Act.STAND
			zeynep.set_indoors(false)
			door.open_angle = OPEN_WIDE
			door.set_open(true)
			_light.visible = true),
		_wait(0.8),
		_do(func() -> void: _walk([Vector3(c.x, floor_y + 0.02, c.z - 0.2), _step_front()])),
		_until_arrived(10.0),
		_do(func() -> void:
			_shut_door()
			var zs := _pet_spot()
			_call_dog()
			_walk([_at(c.x - 0.25, c.z + 1.9), _at(zs.x, zs.y)])),
		_until_arrived(20.0),
		_until(_dog_at_spot, 6.0),
		_do(func() -> void: _start_petting(false)),
	])


## Back to Karamel where she kneels by him (she is at her spot): called over from where he
## is (done eating first), he sits by her and she goes down to him.
func _play_pet() -> void:
	_play([
		_until(func() -> bool: return dog.mode != &"eat", 20.0),
		_do(_call_dog),
		_until(_dog_at_spot, 8.0),
		_do(func() -> void:
			if where == &"garden":
				_start_petting(false)),
	])


## Karamel called over to where he is petted: greeting there, he stops on the spot.
func _call_dog() -> void:
	var ds := _dog_spot()
	var spot := _at(ds.x, ds.y)
	var n := spot - dog.global_position
	n.y = 0.0
	n = n.normalized() if n.length() > 0.01 else Vector3.BACK
	_dog_mode(&"greet", spot + n * Dog.GREET_GAP)


func _dog_at_spot() -> bool:
	var ds := _dog_spot()
	return Vector2(dog.global_position.x, dog.global_position.z).distance_to(ds) < 0.35


# --- Frame ---------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_run_steps(delta)
	# The player standing in her way: she waits and asks to get by.
	if _in_her_way():
		_in_way_t += delta
		if _in_way_t > EXCUSE_AFTER:
			zeynep.say(tr("ZEYNEP_SAY_EXCUSE"))
			_in_way_t = -EXCUSE_AGAIN
	else:
		_in_way_t = minf(_in_way_t + delta, 0.0)
	if _shut_pending and not door.is_moving() and not _player_in_doorway():
		_shut_pending = false
		door.set_open(false)
		door.open_angle = OPEN_WIDE
		_light_off = 0.8
	if _light_off > 0.0:
		_light_off -= delta
		if _light_off <= 0.0 and not door.is_open():
			_light.visible = false
	if where == &"door" and zeynep:
		# Her hand resting on the open door's face by her hip (it goes where the door does).
		zeynep.door_hand = door.leaf_point(Vector3(DOOR_HAND.x, DOOR_HAND.y, Door.LEAF_T + 0.012))
	elif zeynep:
		zeynep.door_hand = Vector3.INF
	_update_lamps()
	if _fill_pending and dog and _bowl_unseen():
		_fill_bowl()
	if _bowl_left > 0.0:
		_bowl_left -= delta
		if _bowl_left <= 0.0:
			_bowl_food.visible = false
	if _event_walk != "" and zeynep and dog and dog.mode == &"greet":
		# Karamel at her heels on the way.
		dog.target = zeynep.global_position
	if _pet_resume > 0.0:
		_pet_resume -= delta
		if _pet_resume <= 0.0 and not busy() and where == &"garden":
			_play_pet()
	_sync_left -= delta
	if _sync_left <= 0.0:
		_sync_left = 0.5
		_sync(false)


## The porch light and her windows: on from dusk while she is up (the porch light also
## while the door stands open); the doorway's fill with the hall lamp.
func _update_lamps() -> void:
	var dark := DayNightCycle.night_factor > DUSK
	var up := SideStory.moved_in() and not SideStory.asleep() and where != &"event"
	var porch := dark and (up or (SideStory.moved_in() and door.is_open()))
	if porch != _porch.visible:
		_porch.visible = porch
		_porch_mat.emission_energy_multiplier = PORCH_GLOW if porch else 0.0
	var windows := dark and up
	if _window_glow[0].visible != windows:
		for n: Node3D in _window_glow:
			n.visible = windows
	_fill.visible = _light.visible


## Puts everything where the day wants it: the sign or her things, and her in the
## garden or indoors (walking there when the player is about to see it).
func _sync(first: bool) -> void:
	var moved := SideStory.moved_in()
	_sign.visible = not moved
	_sign.process_mode = Node.PROCESS_MODE_DISABLED if moved else Node.PROCESS_MODE_INHERIT
	_set_body_enabled(_sign, not moved)
	_dressing.visible = moved
	_set_body_enabled(_dressing, moved)
	if not moved:
		if zeynep != null:
			_despawn()
		return
	_sync_boxes()
	if busy() or _dialogue_open():
		return
	var out := SideStory.outside_now()
	var ev := _event_now()
	if zeynep == null:
		_spawn()
		if ev:
			_go_to_event(ev, true)
		elif out:
			_place_in_garden()
		else:
			_place_inside()
		return
	if ev and where != &"event":
		_go_to_event(ev, first)
		return
	if where == &"event":
		if ev == null and _event_walk != "back":
			_come_home()
		return
	if out and where == &"inside":
		if _watched() and not first:
			_play_come_out()
		else:
			_place_in_garden()
	elif not out and where == &"garden":
		if _watched() and not first:
			_dog_mode(&"roam")
			_play_walk_in()
		else:
			_place_inside()


func _dialogue_open() -> bool:
	# While a game loads the old HUD may be gone before the new one is up.
	if not is_instance_valid(Game.hud):
		return false
	var hud := Game.hud as HUD
	return hud != null and hud.dialogue_screen != null and hud.dialogue_screen.is_open()


## Whether the player is near enough to see her go in or come out.
func _watched() -> bool:
	var p := Game.player as Node3D
	return p != null and is_instance_valid(p) and p.global_position.distance_to(door_center()) < WATCH_RANGE


## The moving boxes: all of them on moving day, one fewer each day, none after BOXES_DAYS
## days.
func _sync_boxes() -> void:
	if GameClock.day == _boxes_day:
		return
	_boxes_day = GameClock.day
	var keep := clampi(_boxes.size() - (GameClock.day - SideStory.MOVE_DAY), 0, _boxes.size())
	if GameClock.day > SideStory.MOVE_DAY + BOXES_DAYS:
		keep = 0
	for i in _boxes.size():
		var on := i < keep
		_boxes[i].visible = on
		_set_body_enabled(_boxes[i], on)


static func _set_body_enabled(root: Node, on: bool) -> void:
	for body: Node in root.find_children("*", "StaticBody3D", true, false):
		for cs: Node in body.get_children():
			if cs is CollisionShape3D:
				(cs as CollisionShape3D).disabled = not on


# --- The town's events ---------------------------------------------------------------------------

## The event the town is at now, if she goes (she lives here, and it has a place for her).
func _event_now() -> EventCrowd:
	if not SideStory.moved_in():
		return null
	var ev := EventCrowd.active(get_tree())
	return ev if ev and not ev.zeynep_spot().is_empty() else null


## On the pavement in front of her garden gate; just inside the gate.
func _gate_out() -> Vector3:
	return Vector3(garden.get_center().x, 0.0, EventCrowd.NORTH_WALK)


func _gate_in() -> Vector3:
	return Vector3(garden.get_center().x, 0.0, garden.end.y - 0.8)


func _camera_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3(0, 1000, 0)


## Off to the event: from the garden, while the player is about, she walks out of the
## gate and over with Karamel; from indoors she goes once nobody is about; with nobody
## near either end (or `instant`) both are just there.
func _go_to_event(ev: EventCrowd, instant: bool) -> void:
	var spot := ev.zeynep_spot()
	var to: Vector3 = spot["pos"]
	var watched := _watched() and not instant
	if watched and where != &"garden":
		return
	_event = ev
	_event_spot = spot
	_steps.clear()
	_pet_resume = 0.0
	zeynep.stop_walk()
	zeynep.pet_target = null
	zeynep.act = Townsperson.Act.STAND
	zeynep.set_indoors(false)
	where = &"event"
	if instant or (not watched and _camera_pos().distance_to(to) > EventCrowd.SEEN):
		_at_event()
		return
	var path: Array[Vector3] = []
	if watched:
		path.append(_gate_in())
	else:
		# Nobody about her house: she has already come out of her gate.
		zeynep.place_at(_gate_out(), PI * 0.5)
		dog.global_position = _gate_out() + Vector3(0.9, 0.0, -0.4)
	path.append(_gate_out())
	path.append_array(ev._path_to_venue(_gate_out()))
	path.append_array(spot.get("via", []) as Array)
	path.append(to)
	_event_walk = "there"
	dog.home_area = Rect2()
	_dog_mode(&"greet", zeynep.global_position)
	zeynep.walk_to(path, _at_event)


## At her place at the event, Karamel pottering about at her feet.
func _at_event() -> void:
	_event_walk = ""
	if zeynep == null or _event_spot.is_empty():
		return
	var to: Vector3 = _event_spot["pos"]
	var yaw := float(_event_spot["yaw"])
	zeynep.place_at(to, yaw)
	zeynep.act = Townsperson.Act.STAND
	var side := Vector3(cos(yaw), 0.0, -sin(yaw))
	var c := to + side * 1.2
	dog.home_area = Rect2(c.x - 1.0, c.z - 1.0, 2.0, 2.0)
	if Vector2(dog.global_position.x, dog.global_position.z).distance_to(Vector2(c.x, c.z)) > 6.0:
		dog.global_position = Vector3(c.x, _ground(c.x, c.z, zeynep.global_position.y), c.z)
	_dog_mode(&"roam")


## Home again when it is over: walking back while the player can see her (in from the
## pavement if only her house is in view), else simply home.
func _come_home() -> void:
	var path: Array[Vector3] = []
	if _event and _camera_pos().distance_to(zeynep.global_position) < EventCrowd.SEEN:
		var via: Array = (_event_spot.get("via", []) as Array).duplicate()
		via.reverse()
		path.append_array(via)
		var way := _event._path_to_venue(_gate_out())
		way.reverse()
		path.append_array(way)
	elif _watched():
		zeynep.place_at(_gate_out(), -PI * 0.5)
		dog.global_position = _gate_out() + Vector3(0.9, 0.0, 0.4)
	else:
		_home_again()
		return
	path.append(_gate_out())
	path.append(_gate_in())
	_event_walk = "back"
	zeynep.stop_walk()
	dog.home_area = Rect2()
	_dog_mode(&"greet", zeynep.global_position)
	zeynep.walk_to(path, _home_again)


## Back in her garden (walked in, or put there): on with her day.
func _home_again() -> void:
	_event_walk = ""
	_event = null
	_event_spot = {}
	if zeynep == null:
		return
	dog.home_area = _garden_area
	var ds := _dog_spot()
	if not dog.home_area.has_point(Vector2(dog.global_position.x, dog.global_position.z)):
		dog.global_position = _at(ds.x, ds.y)
	_dog_mode(&"roam")
	where = &"garden"
	zeynep.act = Townsperson.Act.STAND
	if not _watched():
		if SideStory.outside_now():
			_place_in_garden()
		else:
			_place_inside()
		return
	if SideStory.outside_now():
		_play_pet()
	else:
		_play_walk_in()


## E on her at the event: a friendly word (her errands wait for her to be home).
func event_hello() -> void:
	if not at_event_spot():
		return
	var p := Game.player as Node3D
	if p:
		_face(p.global_position, 0.5)
	var line := tr("ZEYNEP_SAY_EVENT")
	zeynep.say(line)
	_talk_for(line)
	SideStory.on_chat()


## At the town's event (or on her way there or back).
func at_event() -> bool:
	return where == &"event"


## Standing at her place at the event (not on her way).
func at_event_spot() -> bool:
	return zeynep != null and where == &"event" and _event_walk == ""
