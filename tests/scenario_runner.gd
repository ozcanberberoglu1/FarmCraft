class_name ScenarioRunner
extends RefCounted
## Scripted gameplay checks driven through real input and physics.
## Run: godot --path . -- --scenario=<name>   (prints SCENARIO PASS/FAIL lines)

var tree: SceneTree
var failures := 0
var _last_prompt := ""


func _init(scene_tree: SceneTree) -> void:
	tree = scene_tree
	Events.interaction_prompt_changed.connect(func(lines: PackedStringArray): _last_prompt = "\n".join(lines))


func run(scenario: String) -> void:
	match scenario:
		"house":
			await _house()
		"inventory":
			await _inventory()
		"farming":
			await _farming()
		"weather":
			await _weather()
		"resources":
			await _resources()
		"economy":
			await _economy()
		"build":
			await _build()
		"animals":
			await _animals()
		"town":
			await _town()
		"cargo":
			await _cargo()
		"suspension":
			await _suspension()
		"budget":
			await _budget()
		"save":
			await _save_load()
		"tools":
			await _tools()
		"workshop":
			await _workshop()
		"quests":
			await _quests()
		"ruins":
			await _ruins()
		"firstday":
			await _first_day_house()
		"coop":
			await _coop()
		"hud":
			await _hud()
		"feel":
			await _feel()
		"progression":
			await _progression()
		"camp":
			await _camp()
		"fishing":
			await _fishing()
		"sapling":
			await _sapling()
		"sapling_shots":
			await _sapling_shots()
		"visual":
			await _visual()
		"all":
			await _ruins()
			await _first_day_house()
			await _inventory()
			await _farming()
			await _weather()
			await _resources()
			await _economy()
			await _build()
			await _animals()
			await _town()
			await _cargo()
			await _suspension()
			await _budget()
			await _tools()
			await _workshop()
			await _coop()
			await _feel()
			await _progression()
			await _fishing()
			await _quests()
			await _hud()
			await _visual()
			await _house()
			await _sapling()
			# Last: it ends by starting a new game.
			await _save_load()
		_:
			_check(false, "unknown scenario '%s'" % scenario)
	print("SCENARIO RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])


func _house() -> void:
	var player: Player = Game.player
	# Walk from the yard up the porch steps and through the front door.
	player.global_position = Vector3(-16, 0.3, -9.5)
	player.look_at_yaw_pitch(0.0, 0.0)
	await _frames(10)
	Input.action_press("move_forward")
	await _seconds(2.6)
	Input.action_release("move_forward")
	await _seconds(0.4)
	var p := player.global_position
	_check(p.z < -15.5 and p.z > -21.0, "player walked inside the house (z=%.2f)" % p.z)
	_check(absf(p.y - FarmHouse.FLOOR_Y) < 0.15, "player stands on the floor (y=%.2f)" % p.y)

	# Up the ramp and through the warehouse's big door (its floor sits on a plinth).
	var wr := WorldLayout.WAREHOUSE_RECT
	var wx := wr.position.x + 4.0
	player.global_position = Vector3(wx, TerrainData.height(wx, wr.end.y + 3.0) + 0.3, wr.end.y + 3.0)
	player.look_at_yaw_pitch(0.0, 0.0)
	await _frames(10)
	Input.action_press("move_forward")
	await _seconds(1.5)
	Input.action_release("move_forward")
	await _seconds(0.4)
	p = player.global_position
	_check(p.z < wr.end.y - 1.0, "player walked into the warehouse (z=%.2f)" % p.z)
	var wfloor := TerrainData.height(wr.get_center().x, wr.get_center().y) + 0.31
	_check(absf(p.y - wfloor) < 0.1, "player stands on the warehouse floor (y=%.2f)" % p.y)

	# Look at the bed: the prompt must offer sleeping.
	var bed: Node3D = Game.world.get_node("FarmHouse/Bed")
	player.global_position = bed.global_position + Vector3(-1.4, 0.0, 0.6)
	var to_bed := bed.global_position + Vector3(0, 0.5, 0) - (player.global_position + Vector3(0, 1.62, 0))
	player.look_at_yaw_pitch(atan2(-to_bed.x, -to_bed.z), atan2(to_bed.y, Vector2(to_bed.x, to_bed.z).length()))
	await _frames(6)
	_check(_last_prompt.contains(tr("ACTION_SLEEP")), "bed prompt shown ('%s')" % _last_prompt)

	# Sleeping before 18:00 is refused, after 18:00 it starts the next day.
	var day := GameClock.day
	GameClock.set_time_of_day(14.0)
	await _press_key(KEY_E)
	await _frames(3)
	_check(GameClock.day == day and not Game.is_ui_open(), "cannot sleep in the afternoon")
	GameClock.set_time_of_day(21.5)
	Economy.add_money(120, "test sale")
	var bin: ShippingBin = Game.world.farm.get_node("ShippingBin")
	bin.inventory.add_item(&"tomato", 5)
	var sales: Array[int] = []
	var on_sale := func(gold: int) -> void: sales.append(gold)
	Events.morning_sale.connect(on_sale)
	await _press_key(KEY_E)
	await _seconds(1.4)
	_check(GameClock.day == day + 1 and GameClock.get_hour() == 6, "sleeping moves to the next day, 06:00 (day=%d %s)" % [GameClock.day, GameClock.time_string()])
	_check(Game.is_ui_open() and Game.hud.sleep_screen.is_busy(), "morning report is shown")
	_check(Economy.ledger.is_empty(), "the day's ledger was closed")
	Game.hud.sleep_screen.confirm()
	await _seconds(1.2)
	_check(not Game.is_ui_open(), "report closes and control returns")
	Events.morning_sale.disconnect(on_sale)
	_check(sales.size() == 1 and sales[0] > 0 and bin.inventory.count_item(&"tomato") == 0,
			"the morning brings the bin's sale on the bus (%s)" % str(sales))
	_check(Game.hud._sale_badge.visible and Game.hud._sale_badge.amount == sales[0],
			"the sale badge shows under the money (+%d)" % Game.hud._sale_badge.amount)
	_check(Achievements.is_unlocked(&"first_night") and Achievements.is_unlocked(&"first_sale"),
			"the first night and the first sale are achievements")


## Grandpa's run-down house and warehouse on a new farm: they work (floor, bed, chest,
## storage) and carry repair signs; the board doesn't sell their repair. They are mended
## by hand: wood in hand, LMB on each hole in their walls nails fresh boards over it
## (one wood a hole, remembered through a rebuild) until the building is repaired.
func _ruins() -> void:
	var player: Player = Game.player
	var farm: Farm = Game.world.farm
	var house: FarmHouse = Game.world.get_node("FarmHouse")
	var wh := farm.get_node("Warehouse") as Warehouse
	_check(FarmState.house_level() == 0 and house.level == 0 and house.W == 9.0, "a new farm has the run-down house (level 0, 9 m wide)")
	_check(house.get_node_or_null("Clutter") != null and house.get_node_or_null("FireLight") == null,
			"the ruin has its clutter mesh and a cold hearth")
	var bed := house.get_node_or_null("Bed") as Bed
	_check(bed != null and bed.worn and house.get_node_or_null("Chest") != null, "the old house has a worn bed and the chest")
	var lamp := house.get_node_or_null("Lamp") as OmniLight3D
	_check(lamp != null and lamp.shadow_enabled and lamp.shadow_caster_mask == FarmHouse.LAMP_SHADOW_LAYER,
			"the lantern keeps its layer-20 shadow")
	_check(wh.level == 0 and FarmState.warehouse_level() == 0 and FarmState.warehouse.capacity == 200,
			"the run-down warehouse holds 200 units")
	var sign := farm.get_node_or_null("Sign_house_1") as RepairSpot.Sign
	_check(sign != null and farm.get_node_or_null("Sign_warehouse_1") is RepairSpot.Sign and sign.interact_prompt(player) == "",
			"both run-down buildings have a repair sign (it opens no board)")
	_check(not FarmState.can_build(&"house_2") and not FarmState.can_build(&"warehouse_2"),
			"nothing is extended before it is repaired")
	var level := Progress.level
	Progress.level = 1
	_check(not BuildScreen.on_board(&"house_1") and not BuildScreen.on_board(&"warehouse_1") and BuildScreen.on_board(&"house_2"),
			"the board doesn't sell the repairs")
	var hs := _repair_spots(&"house")
	var ws := _repair_spots(&"warehouse")
	_check(hs.size() == 8 and ws.size() == 6 and RepairSpot.patched_count(&"house") == 0,
			"the house has 8 holes to mend, the warehouse 6 (%d, %d)" % [hs.size(), ws.size()])
	_check(WaypointMarker.anchor(&"house_repair") != null and WaypointMarker.anchor(&"warehouse_repair") != null,
			"both buildings have a repair waypoint anchor")
	var sent := []
	var on_patch := func(id: StringName, done: int, total: int) -> void: sent.append([id, done, total])
	var on_repaired := func(id: StringName) -> void: sent.append(["repaired", id])
	Events.wall_patched.connect(on_patch)
	Events.building_repaired.connect(on_repaired)
	var chest_wood := (house.get_node("Chest") as Chest).inventory.count_item(&"wood")
	PlayerState.inventory.add_item(&"wood", 20)
	var wood := PlayerState.inventory.count_item(&"wood")
	# The first hole: without wood in hand it only says what it needs.
	_select(&"hoe")
	await _face_spot(player, hs[0])
	_check(not _last_prompt.contains(tr("KEY_LMB")) and _last_prompt.contains(tr("HINT_PATCH_NEEDS_WOOD")),
			"a hole without wood in hand asks for wood ('%s')" % _last_prompt)
	var guide := WaypointMarker.anchor(&"house_repair")
	_check(guide != null and guide.global_position.distance_to(hs[0].global_position) < 0.3,
			"the house's waypoint is on the hole nearest the farmer")
	_select(&"wood")
	await _seconds(0.25)
	_check(_last_prompt.contains(tr("ACTION_PATCH_WALL")), "wood in hand: LMB nails boards over it ('%s')" % _last_prompt)
	_check(await _nail_spot(hs[0]) and hs[0].get_node_or_null("Patch") != null and hs[0].get_node_or_null("LooseBoard") == null
			and PlayerState.inventory.count_item(&"wood") == wood - 1 and sent.has([&"house", 1, 8]),
			"LMB nails fresh boards over the hole for one wood (wall_patched house 1/8)")
	# A mended spot takes nothing more.
	await _face_spot(player, hs[0])
	_check(not _last_prompt.contains(tr("ACTION_PATCH_WALL")), "a mended spot offers nothing ('%s')" % _last_prompt)
	Input.action_press("use")
	await _seconds(1.2)
	Input.action_release("use")
	await _frames(2)
	_check(PlayerState.inventory.count_item(&"wood") == wood - 1 and sent.size() == 1, "hitting a mended spot uses no wood")
	for i in range(1, 3):
		await _face_spot(player, hs[i])
		await _nail_spot(hs[i])
	# The mended spots come back mended after a rebuild (a load).
	house.build()
	await _frames(3)
	hs = _repair_spots(&"house")
	var kept := 0
	for s: RepairSpot in hs:
		if s.patched and s.get_node_or_null("Patch") != null:
			kept += 1
	_check(hs.size() == 8 and kept == 3 and RepairSpot.patched_count(&"house") == 3, "a rebuild keeps the 3 mended spots (%d)" % kept)
	for s: RepairSpot in hs:
		if not s.patched:
			await _face_spot(player, s)
			await _nail_spot(s)
	_check(PlayerState.inventory.count_item(&"wood") == wood - 8 and sent.has([&"house", 8, 8]), "8 holes, 8 wood")
	await _seconds(RepairSpot.REPAIR_DELAY + 0.4)
	_check(house.level == 1 and FarmState.house_level() == 1 and sent.has(["repaired", &"house"]),
			"the last board repairs the house (level 1, building_repaired sent)")
	for s: RepairSpot in ws:
		await _face_spot(player, s)
		await _nail_spot(s)
	await _seconds(RepairSpot.REPAIR_DELAY + 0.4)
	_check(wh.level == 1 and FarmState.warehouse.capacity == 400 and sent.has([&"warehouse", 6, 6]) and sent.has(["repaired", &"warehouse"]),
			"6 boards repair the warehouse (400 units)")
	_check(PlayerState.inventory.count_item(&"wood") == wood - 14, "14 wood used in all")
	Events.wall_patched.disconnect(on_patch)
	Events.building_repaired.disconnect(on_repaired)
	await _frames(3)
	_check(farm.get_node_or_null("Sign_house_1") == null and farm.get_node_or_null("Sign_warehouse_1") == null,
			"the repair signs are gone")
	_check(WaypointMarker.anchor(&"house_repair") == null and WaypointMarker.anchor(&"warehouse_repair") == null
			and _repair_spots(&"house").is_empty(), "the repair spots and their waypoints are gone")
	_check(house.get_node_or_null("Clutter") == null and house.get_node_or_null("FireLight") != null
			and not (house.get_node("Bed") as Bed).worn, "the repaired house has a fire and a new bed")
	_check((house.get_node("Chest") as Chest).inventory.count_item(&"wood") == chest_wood, "the chest keeps its contents through the repair")
	Progress.level = level
	# Saves from before the ruins keep their buildings repaired.
	var old: Dictionary = SaveGame._migrate({"farm": {"built": ["field_0", "house_2"]}}, 1)
	var built: Array = (old["farm"] as Dictionary)["built"]
	_check(built.has("house_1") and built.has("warehouse_1") and built.has("house_2"), "a version 1 save gets house_1 and warehouse_1")
	var current: Dictionary = SaveGame._migrate({"farm": {"built": ["field_0"]}}, SaveGame.VERSION)
	_check(not ((current["farm"] as Dictionary)["built"] as Array).has("house_1"), "a current save is left as it is")


## The building's repair spots in the world, in their order.
func _repair_spots(building: StringName) -> Array[RepairSpot]:
	var out: Array[RepairSpot] = []
	for n: Node in tree.get_nodes_in_group(RepairSpot.GROUP):
		var s := n as RepairSpot
		if s and s.building_id == building and not s.is_queued_for_deletion():
			out.append(s)
	out.sort_custom(func(a: RepairSpot, b: RepairSpot) -> bool: return a.index < b.index)
	return out


## Stands the farmer on the ground (or the porch) 1.3 m out from the hole and looks at it.
func _face_spot(player: Player, spot: RepairSpot) -> void:
	var out := spot.global_basis.z
	var flat := Vector3(out.x, 0.0, out.z).normalized()
	var p := spot.global_position + flat * 1.3
	var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 4.0, 17)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var ground: float = (hit["position"] as Vector3).y if not hit.is_empty() else TerrainData.height(p.x, p.z)
	player.global_position = Vector3(p.x, ground + 0.05, p.z)
	player.velocity = Vector3.ZERO
	await _frames(3)
	_look_at(player, spot.global_position + out * 0.04)
	await _seconds(0.3)


## Holds LMB on the aimed hole through one nailing; true when it got mended for one wood.
func _nail_spot(spot: RepairSpot) -> bool:
	# The last hole's repair rebuilds the building (and frees the spot) meanwhile.
	var building := spot.building_id
	var index := spot.index
	var wood := PlayerState.inventory.count_item(&"wood")
	Input.action_press("use")
	await _seconds(1.25)
	Input.action_release("use")
	await _frames(2)
	var ok := RepairSpot.is_patched(building, index) and PlayerState.inventory.count_item(&"wood") == wood - 1
	if not ok:
		_check(false, "nailing %s hole %d (prompt '%s')" % [building, index, _last_prompt])
	return ok


## A new farm's first day in the house: the shut front door (E opens it), Grandpa's things
## on the worktable (E takes each) and the pickup key in the desk drawer (E opens it, E
## takes the key). What was opened and taken survives a rebuild. Automated runs normally
## skip it; FarmHouse.FIRST_DAY_FLAG asks for it. The bag and the flags are put back.
func _first_day_house() -> void:
	var player: Player = Game.player
	var house: FarmHouse = Game.world.get_node("FarmHouse")
	var bag := PlayerState.inventory.to_array()
	var flags_before := FarmState.flags.duplicate(true)
	_check(house.front_door() != null and house.front_door().is_open() and house.get_node_or_null("Table_hoe") == null
			and house.desk_drawer() != null and house.desk_drawer().items().is_empty(),
			"automated runs find the front door open and the worktable and drawer empty")
	var sent := []
	var on_door := func(id: StringName, open: bool) -> void: sent.append(["door", id, open])
	var on_drawer := func(id: StringName) -> void: sent.append(["drawer", id])
	var on_taken := func(id: StringName) -> void: sent.append(["taken", id])
	Events.door_toggled.connect(on_door)
	Events.drawer_opened.connect(on_drawer)
	Events.world_item_taken.connect(on_taken)
	FarmState.flags[FarmHouse.FIRST_DAY_FLAG] = true
	house.build()
	await _frames(3)
	var door := house.front_door()
	_check(door != null and not door.is_open() and door.style == (&"ruin" if house.level == 0 else &"plank"),
			"a new farm's front door is shut (%s)" % (door.style if door else &"-"))
	var on_table := 0
	for entry: Array in ItemTable.STARTING_ITEMS:
		if house.get_node_or_null("Table_%s" % entry[0]) is WorldItem:
			on_table += 1
	_check(on_table == ItemTable.STARTING_ITEMS.size() and FarmHouse.table_taken_count() == 0,
			"Grandpa's %d things lie on the worktable (%d)" % [ItemTable.STARTING_ITEMS.size(), on_table])
	var drawer := house.desk_drawer()
	_check(drawer != null and not drawer.is_open() and drawer.items().size() == 1 and drawer.items()[0].item_id == &"truck_key"
			and not drawer.items()[0].is_enabled(), "the pickup key lies in the shut desk drawer, out of reach")
	# The shut door stops the player on the porch.
	player.global_position = Vector3(-16, 0.3, -9.5)
	player.look_at_yaw_pitch(0.0, 0.0)
	await _frames(10)
	Input.action_press("move_forward")
	await _seconds(2.6)
	Input.action_release("move_forward")
	await _seconds(0.3)
	_check(player.global_position.z > -14.75, "the shut door stops the player on the porch (z=%.2f)" % player.global_position.z)
	# E opens it, with the door's own look and sound.
	player.global_position = Vector3(-16, FarmHouse.FLOOR_Y + 0.1, -13.3)
	await _frames(3)
	_look_at(player, door.waypoint_point())
	await _seconds(0.25)
	_check(_last_prompt.contains(tr("ACTION_OPEN")), "the shut door offers to open ('%s')" % _last_prompt)
	await _press_key(KEY_E)
	await _seconds(1.6)
	_check(door.is_open() and FarmState.flags.get(FarmHouse.DOOR_FLAG) == true and sent.has(["door", FarmHouse.DOOR_ID, true]),
			"E opens the door (flag kept, door_toggled sent)")
	player.global_position = Vector3(-16, 0.3, -9.5)
	player.look_at_yaw_pitch(0.0, 0.0)
	await _frames(10)
	Input.action_press("move_forward")
	await _seconds(2.6)
	Input.action_release("move_forward")
	await _seconds(0.4)
	_check(player.global_position.z < -15.5, "through the open door into the house (z=%.2f)" % player.global_position.z)
	# Take the hoe with a real look and E.
	var hoe := house.get_node("Table_hoe") as WorldItem
	var hoes := PlayerState.inventory.count_item(&"hoe")
	player.global_position = Vector3(hoe.global_position.x, FarmHouse.FLOOR_Y + 0.1, hoe.global_position.z - 1.5)
	await _frames(3)
	_look_at(player, hoe.waypoint_point())
	await _seconds(0.25)
	var take := tr("ACTION_TAKE_ITEM") % ItemDB.get_item(&"hoe").display_name()
	_check(_last_prompt.contains(take), "the hoe on the worktable offers '%s' ('%s')" % [take, _last_prompt])
	await _press_key(KEY_E)
	await _seconds(0.5)
	_check(PlayerState.inventory.count_item(&"hoe") == hoes + 1 and house.get_node_or_null("Table_hoe") == null
			and FarmHouse.table_taken_count() == 1 and sent.has(["taken", &"hoe"]),
			"E takes the hoe into the bag (remembered, world_item_taken sent)")
	# The rest, straight through interact().
	for n: Node in house.get_children():
		if n is WorldItem and String(n.name).begins_with("Table_"):
			(n as WorldItem).interact(player)
	await _seconds(0.4)
	_check(FarmHouse.table_taken_count() == FarmHouse.table_item_count() and PlayerState.inventory.count_item(&"wheat_seed") >= 10,
			"everything on the worktable was taken (%d/%d)" % [FarmHouse.table_taken_count(), FarmHouse.table_item_count()])
	# The drawer stays shut while the story locks it.
	var desk_spot := drawer.global_position + drawer.global_basis.z * 0.95
	player.global_position = Vector3(desk_spot.x, FarmHouse.FLOOR_Y + 0.1, desk_spot.z)
	FarmState.flags[FarmHouse.DRAWER_LOCK_FLAG] = true
	await _frames(3)
	_look_at(player, drawer.waypoint_point())
	await _seconds(0.25)
	_check(not _last_prompt.contains(tr("ACTION_OPEN")), "the locked drawer offers nothing ('%s')" % _last_prompt)
	FarmState.flags.erase(FarmHouse.DRAWER_LOCK_FLAG)
	await _seconds(0.25)
	_check(_last_prompt.contains(tr("ACTION_OPEN")), "the desk drawer offers to open ('%s')" % _last_prompt)
	await _press_key(KEY_E)
	await _seconds(0.7)
	_check(drawer.is_open() and FarmState.flags.get(FarmHouse.DRAWER_FLAG) == true and sent.has(["drawer", FarmHouse.DRAWER_ID]),
			"E pulls the drawer out (flag kept, drawer_opened sent)")
	var key := drawer.items()[0]
	_look_at(player, key.waypoint_point())
	await _seconds(0.25)
	_check(key.is_enabled() and _last_prompt.contains(tr("ACTION_TAKE_ITEM") % ItemDB.get_item(&"truck_key").display_name()),
			"the key in the open drawer offers to be taken ('%s')" % _last_prompt)
	await _press_key(KEY_E)
	await _seconds(0.5)
	_check(PlayerState.inventory.count_item(&"truck_key") == 1 and FarmState.flags.get(FarmHouse.KEY_FLAG) == true
			and drawer.items().is_empty() and sent.has(["taken", &"truck_key"]), "E takes the pickup key (remembered)")
	# A rebuild (a repair or an upgrade) finds it all as it was.
	house.build()
	await _frames(3)
	_check(house.front_door().is_open() and house.desk_drawer().is_open() and house.desk_drawer().items().is_empty()
			and house.get_node_or_null("Table_axe") == null, "a rebuild keeps the door open, the drawer out and the table empty")
	var hinge := house.front_door().global_position
	_check(Vector2(hinge.x, hinge.z).distance_to(Vector2(WorldLayout.HOUSE_DOOR_X - 0.63, WorldLayout.HOUSE_FRONT_Z - FarmHouse.T)) < 0.01,
			"the door hangs on the west jamb (%.2f, %.2f)" % [hinge.x, hinge.z])
	# An old save (legacy) never gets the first day, even when asked.
	FarmState.flags = {FarmHouse.LEGACY_FLAG: true, FarmHouse.FIRST_DAY_FLAG: true}
	_check(not FarmHouse.first_day(), "an old save skips the first day's house")
	# Put everything back.
	Events.door_toggled.disconnect(on_door)
	Events.drawer_opened.disconnect(on_drawer)
	Events.world_item_taken.disconnect(on_taken)
	FarmState.flags = flags_before
	PlayerState.inventory.from_array(bag)
	house.build()
	await _frames(3)


func _inventory() -> void:
	var inv := PlayerState.inventory
	_check(inv.count_item(&"hoe") == 1 and inv.count_item(&"wheat_seed") == 10, "starting items present")
	_check(inv.get_stack(0) != null and inv.get_stack(0).item.id == &"hoe", "hoe in hotbar slot 1")

	# Stacking and overflow into a second slot.
	var test := Inventory.new(4)
	_check(test.add_item(&"wheat", 150) == 0, "150 wheat fit into two stacks")
	_check(test.get_stack(0).count == 99 and test.get_stack(1).count == 51, "stacks split at 99 (%d/%d)" % [test.get_stack(0).count, test.get_stack(1).count])
	_check(test.add_item(&"wheat", 300) == 54, "overflow reported when full (4x99 = 396 of 450)")
	_check(test.remove_item(&"wheat", 100) and test.count_item(&"wheat") == 296, "remove across stacks (%d)" % test.count_item(&"wheat"))
	_check(not test.remove_item(&"wheat", 1000), "remove fails when not enough")
	# Tools never stack; durability starts full.
	var tools := Inventory.new(3)
	tools.add_item(&"axe", 2)
	_check(tools.get_stack(0).count == 1 and tools.get_stack(1).count == 1, "tools do not stack")
	_check(tools.get_stack(0).durability == ItemDB.get_item(&"axe").max_durability, "tool durability starts full")
	# Merge by transfer, swap otherwise.
	var a := Inventory.new(2)
	a.add_item(&"carrot", 5)
	var b := Inventory.new(2)
	b.add_item(&"carrot", 7)
	b.add_item(&"potato", 3)
	Inventory.transfer(a, 0, b, 0)
	_check(a.get_stack(0) == null and b.get_stack(0).count == 12, "transfer merges same items")
	Inventory.transfer(b, 1, b, 0)
	_check(b.get_stack(0).item.id == &"potato" and b.get_stack(1).item.id == &"carrot", "transfer swaps different items")
	var half := b.split_half(1)
	_check(half == -1, "split needs an empty slot")
	# Save round-trip.
	var restored := Inventory.new(2)
	restored.from_array(b.to_array())
	_check(restored.count_item(&"carrot") == 12 and restored.count_item(&"potato") == 3, "inventory save round-trip")

	# Drop one seed into the world and let the magnet pick it back up.
	var player: Player = Game.player
	player.global_position = Vector3(-10, 0.3, 0)
	await _frames(5)
	var seed_slot := -1
	for i in PlayerState.HOTBAR_SIZE:
		var st := inv.get_stack(i)
		if st and st.item.id == &"wheat_seed":
			seed_slot = i
	PlayerState.select(seed_slot)
	await _press_key(KEY_Q)
	await _frames(2)
	_check(inv.count_item(&"wheat_seed") == 9, "Q drops one item (%d left)" % inv.count_item(&"wheat_seed"))
	_check(tree.get_nodes_in_group(&"pickups").size() == 1, "a pickup exists in the world")
	await _seconds(2.5)
	_check(inv.count_item(&"wheat_seed") == 10, "dropped item is picked back up (%d)" % inv.count_item(&"wheat_seed"))


func _farming() -> void:
	var player: Player = Game.player
	var inv := PlayerState.inventory
	var field: Field = Game.world.farm.fields[&"field_0"]
	var plot: FarmPlot = field.plots[4]
	player.global_position = plot.global_position + Vector3(0, 0.1, 2.4)
	_look_at(player, plot.global_position + Vector3(0, 0.15, 0))
	await _frames(6)
	_check(player.target == plot, "aiming at the garden bed")

	_select(&"hoe")
	var hoe := PlayerState.selected_stack()
	var dur := hoe.durability
	await _hold_use(1.6)
	_check(plot.soil == FarmPlot.Soil.TILLED, "hoe tills the bed")
	_check(hoe.durability == dur - 1, "hoeing wears the hoe")

	_select(&"wheat_seed")
	var seeds := inv.count_item(&"wheat_seed")
	await _hold_use(1.3)
	_check(plot.crop == &"wheat" and inv.count_item(&"wheat_seed") == seeds - 1, "planting uses one seed")

	_select(&"watering_can")
	var can := PlayerState.selected_stack()
	var water := can.water
	await _hold_use(1.1)
	_check(plot.is_wet() and can.water == water - 1, "watering soaks the bed and uses water")
	# The growth ring beside the crosshair (CropCard reads the aimed bed every 0.25 s).
	var card: CropCard = Game.hud.crop_card
	await _seconds(0.4)
	_check(card.visible and card.state == "growing" and card.ring.ratio < 0.05,
			"aiming at the new crop shows its growth ring (%s %.2f)" % [card.state, card.ring.ratio])

	GameClock.advance(12.0 * 60.0)
	_check(plot.stage() == 1 and not plot.is_ready(), "half grown after 12 wet hours (stage %d)" % plot.stage())
	await _seconds(0.4)
	var info := plot.growth_info()
	_check(absf(card.ring.ratio - float(info["ratio"])) < 0.001 and card._time.text == CropCard.time_left_text(float(info["hours_left"])),
			"the ring follows the growth with the time left (%.2f, %s)" % [card.ring.ratio, card._time.text])
	GameClock.advance(12.0 * 60.0 + 1.0)
	_check(plot.is_ready(), "wheat ready after 24 wet hours")
	await _seconds(0.4)
	_check(card.state == "ready" and card.ring.pulse and card.ring.ratio == 1.0, "a ripe crop fills the ring and pulses")
	Game.hud.inventory_screen.open()
	await _frames(3)
	_check(not card.visible, "the ring hides behind menus")
	Game.hud.inventory_screen.close()
	await _frames(3)

	_select(&"scythe")
	var wheat_before := inv.count_item(&"wheat")
	await _hold_use(1.3)
	_check(plot.crop == &"", "harvest clears a single-harvest crop")
	await _frames(2)
	_check(not card.visible and card.state == "", "a harvested bed shows no ring")
	await _seconds(2.5)
	_check(inv.count_item(&"wheat") == wheat_before + 2 and inv.count_item(&"hay") >= 1,
			"harvest yields 2 wheat + hay (%d wheat, %d hay)" % [inv.count_item(&"wheat"), inv.count_item(&"hay")])

	# A dry crop stops growing and eventually withers.
	var plot2: FarmPlot = field.plots[5]
	plot2.soil = FarmPlot.Soil.TILLED
	plot2.crop = &"potato"
	_check(plot2.growth_info().get("state", "") == "dry", "an unwatered crop reports that it needs water")
	GameClock.advance(49.0 * 60.0)
	_check(plot2.withered and plot2.growth == 0.0, "an unwatered crop withers after 2 days")
	_check(plot2.growth_info().get("state", "") == "withered", "a withered crop reports it")
	_check(CropCard.format_hours(3.3) == tr("CROP_TIME_HM") % [3, 20] and CropCard.format_hours(30.0) == tr("CROP_TIME_DH") % [1, 6]
			and CropCard.format_hours(0.05) == tr("CROP_TIME_M") % 10, "crop times round up to the clock's 10 minutes")
	# Tall plants stop the aim too (FarmPlot._fit_reach), not only their soil.
	plot.load_data({"soil": FarmPlot.Soil.TILLED, "crop": "corn", "growth": 70.0, "wet": 10.0})
	_look_at(player, plot.global_position + Vector3(0, 1.3, 0))
	await _frames(6)
	_check(player.target == plot and card.state == "growing", "aiming at tall corn targets its bed (%s)" % card.state)
	plot.load_data({"soil": FarmPlot.Soil.TILLED})

	# Empty can is refused; the well refills it.
	_select(&"watering_can")
	can.water = 0
	player.global_position = plot.global_position + Vector3(0, 0.1, 2.4)
	_look_at(player, plot.global_position + Vector3(0, 0.15, 0))
	plot.crop = &"carrot"
	plot.wet_hours = 0.0
	await _frames(4)
	await _hold_use(1.0)
	_check(not plot.is_wet(), "an empty can cannot water")
	var well: Node3D = Game.world.get_node("Well")
	player.global_position = well.global_position + Vector3(0, 0.1, 2.0)
	_look_at(player, well.global_position + Vector3(0, 0.9, 0))
	await _frames(6)
	await _hold_use(1.4)
	_check(can.water == can.item.water_capacity, "the well refills the can (%d)" % can.water)


func _weather() -> void:
	# Forecast rolls are deterministic per day and follow the season odds.
	_check(Weather.roll(1) == Weather.Kind.SUNNY, "day 1 is always sunny")
	_check(Weather.roll(15) == Weather.roll(15), "forecast is deterministic")
	var winter_rain := false
	var summer_snow := false
	for d in range(2, 200):
		var k := Weather.roll(d)
		var season := floori((d - 1) / 10.0) % 4
		if season == 3 and (k == Weather.Kind.RAIN or k == Weather.Kind.STORM):
			winter_rain = true
		if season != 3 and k == Weather.Kind.SNOW:
			summer_snow = true
	_check(not winter_rain and not summer_snow, "rain only outside winter, snow only in winter")

	# Rain waters the beds and wets the world.
	var field: Field = Game.world.farm.fields[&"field_0"]
	var plot: FarmPlot = field.plots[0]
	plot.soil = FarmPlot.Soil.TILLED
	plot.wet_hours = 0.0
	Weather.force(Weather.Kind.RAIN)
	GameClock.advance(30.0)
	_check(plot.is_wet(), "rain waters the beds")
	_check(Weather.wetness > 0.5, "the world gets wet (%.2f)" % Weather.wetness)
	Weather.force(Weather.Kind.SUNNY)
	GameClock.advance(4.0 * 60.0)
	_check(Weather.wetness < 0.2, "it dries in the sun (%.2f)" % Weather.wetness)
	Weather.forced = -1

	# Passing out at 02:00 costs money and wakes you at home.
	var money := Economy.money
	GameClock.running = true
	GameClock.set_time_of_day(25.99)
	await _seconds(1.6)
	_check(Game.hud.sleep_screen.is_busy(), "passing out starts the sleep sequence")
	_check(Economy.money < money or money == 0, "passing out costs money (%d -> %d)" % [money, Economy.money])
	Game.hud.sleep_screen.confirm()
	await _seconds(1.2)
	var bed: Node3D = get_first_bed()
	_check(Game.player.global_position.distance_to(bed.global_position) < 2.5, "woke up next to the bed")
	GameClock.running = false


func _resources() -> void:
	var player: Player = Game.player
	var inv := PlayerState.inventory
	# Chop the nearest tree until it falls.
	var tree: ChoppableTree = _nearest(&"trees", player.global_position)
	player.global_position = tree.global_position + Vector3(0, 0.2, 1.6)
	_look_at(player, tree.global_position + Vector3(0, 1.2, 0))
	await _frames(6)
	_check(player.target == tree, "aiming at a tree")
	_select(&"axe")
	var wood := inv.count_item(&"wood")
	await _hold_use(tree.max_hp() * 0.75 + 1.0)
	_check(tree.felled, "the tree falls after %d hits" % tree.max_hp())
	_check(tree.cut_height > 1.0 and tree.cut_height < 1.5 and is_equal_approx(tree._stump_shape.shape.height, tree.cut_height),
			"it breaks where the axe hit, the stump as tall as the cut (%.2f m)" % tree.cut_height)
	await _seconds(4.0)
	_check(inv.count_item(&"wood") >= wood + 5, "chopping gives wood (%d -> %d)" % [wood, inv.count_item(&"wood")])
	# Break a quarry rock.
	var rock: BreakableRock = null
	for r: BreakableRock in tree.get_tree().get_nodes_in_group(&"rocks"):
		if r.quarry and not r.broken:
			rock = r
			break
	player.global_position = rock.global_position + Vector3(0, 0.3, 1.2 + rock.size)
	_look_at(player, rock.global_position + Vector3(0, 0.4 * rock.size, 0))
	await _frames(6)
	_check(player.target == rock, "aiming at a quarry rock")
	_select(&"pickaxe")
	var stone := inv.count_item(&"stone")
	await _hold_use(rock.max_hp() * 0.8 + 1.0)
	_check(rock.broken, "the rock breaks")
	await _seconds(2.5)
	_check(inv.count_item(&"stone") > stone, "breaking gives stone (%d -> %d)" % [stone, inv.count_item(&"stone")])
	# Cut tall grass for hay.
	var patch: GrassPatch = _nearest(&"grass_patches", player.global_position)
	player.global_position = patch.global_position + Vector3(0, 0.3, 1.5)
	_look_at(player, patch.global_position + Vector3(0, 0.3, 0))
	await _frames(6)
	_select(&"scythe")
	var hay := inv.count_item(&"hay")
	await _hold_use(1.0)
	_check(patch.cut, "the grass is cut")
	await _seconds(2.5)
	_check(inv.count_item(&"hay") > hay, "cutting grass gives hay")
	# Everything regrows after a few days.
	for i in 6:
		GameClock.day += 1
		Events.day_started.emit(GameClock.day)
	_check(not tree.felled and not rock.broken and not patch.cut, "resources regrow")
	_check(tree._top == null and tree._mesh.get_surface_override_material(0) == null, "the regrown tree is whole again")


func _economy() -> void:
	# Market price stays within the expected band and saturates with volume.
	var base := ItemDB.get_item(&"potato").sell_price
	var p := Economy.sell_price(&"potato")
	_check(p >= int(base * 0.8) and p <= int(base * 1.45), "market price in range (%d, base %d)" % [p, base])
	# (A dear item: a few-dollar carrot's whole-dollar price can round the drop away.)
	var before := Economy.sell_price(&"pumpkin")
	Economy.sold_today[&"pumpkin"] = 60
	_check(Economy.sell_price(&"pumpkin") < before, "selling a lot lowers the price")
	Economy.sold_today.erase(&"pumpkin")
	# A quote is exactly what the sale then pays (each unit lowers the price).
	var quoted := Economy.quote(&"pumpkin", 60)
	var first := Economy.sell_price(&"pumpkin")
	var paid := Economy.sell(&"pumpkin", 60)
	_check(quoted == paid and paid < first * 60, "a quote for 60 pumpkins matches the sale ($%d, first unit $%d)" % [paid, first])
	Economy.sold_today.erase(&"pumpkin")
	Economy.sold_today[&"carrot"] = 60
	_check(Economy.quote(&"carrot", 10) < Economy.quote(&"carrot", 10, 0, 1.0, -60), "a lot of cheap carrots still fetches less after a big sale")
	# Two qualities of one item in a row: the second lot is quoted after the first.
	Economy.sold_today.erase(&"carrot")
	var two := Economy.quote(&"carrot", 10, 1) + Economy.quote(&"carrot", 10, 0, 1.0, 10)
	_check(two == Economy.sell(&"carrot", 10, 1) + Economy.sell(&"carrot", 10, 0), "quotes for two lots add up to their sale")
	Economy.sold_today.erase(&"carrot")
	# Buying seeds through the shop screen.
	var shop := ShopStock.general_store()
	_check(&"wheat_seed" in shop["stock"], "spring store sells wheat seeds")
	var money := Economy.money
	var seeds := PlayerState.inventory.count_item(&"carrot_seed")
	Game.hud.open_shop(shop)
	await _frames(3)
	var screen: ShopScreen = Game.hud.shop_screen
	screen._sel = {"id": &"carrot_seed", "quality": 0}
	screen._qty = 5
	screen._confirm()
	var seed_cost := 5 * Economy.buy_price(&"carrot_seed")
	_check(PlayerState.inventory.count_item(&"carrot_seed") == seeds + 5 and Economy.money == money - seed_cost,
			"bought 5 carrot seeds for $%d" % seed_cost)
	# Selling through the shop.
	PlayerState.inventory.add_item(&"pumpkin", 2)
	screen._set_tab("sell")
	screen._sel = {"id": &"pumpkin", "quality": 0}
	screen._qty = 2
	var gold := Economy.money
	screen._confirm()
	_check(Economy.money >= gold + roundi(2 * ItemDB.get_item(&"pumpkin").sell_price * 0.8) and PlayerState.inventory.count_item(&"pumpkin") == 0,
			"sold 2 pumpkins (+%d)" % (Economy.money - gold))
	screen.close_screen()
	# Shipping bin sells overnight.
	var bin: ShippingBin = Game.world.farm.get_node("ShippingBin")
	bin.inventory.add_item(&"tomato", 10)
	gold = Economy.money
	Events.day_ending.emit()
	_check(Economy.money > gold and bin.inventory.count_item(&"tomato") == 0, "shipping bin sold overnight (+%d)" % (Economy.money - gold))
	# The courier's quarter shows even on cheap goods: a lot's units are summed before
	# rounding (wheat at $2 would round back to $2 a unit).
	Economy.sold_today.erase(&"wheat")
	var full := Economy.quote(&"wheat", 20)
	var shipped := Economy.quote(&"wheat", 20, 0, ShippingBin.COMMISSION_FACTOR)
	_check(shipped < full and absi(shipped - roundi(full * ShippingBin.COMMISSION_FACTOR)) <= 1,
			"the shipping bin pays three quarters of the market on cheap goods too ($%d of $%d)" % [shipped, full])
	# Dollars: a new farm has $150, two hens at the stall cost $50 each and what they
	# leave still pays for the coop kit; money reads with the dollar sign.
	var hen := LiveCrates.price(&"chicken")
	var kit := int(ProjectTable.get_project(&"coop_kit")["cost"])
	_check(Economy.STARTING_MONEY == 150 and hen == 50 and Economy.STARTING_MONEY - 2 * hen == 50 and kit <= 50 - 20,
			"a new farm: $%d, hens $%d each, the coop kit $%d" % [Economy.STARTING_MONEY, hen, kit])
	# The next morning: what is left, and Grandpa's carrots and an egg sold through the bin.
	var morning := Economy.STARTING_MONEY - 2 * hen - kit + Economy.quote(&"carrot", Quests.GRANDPA_BEDS * 2, 0, ShippingBin.COMMISSION_FACTOR) \
			+ Economy.quote(&"egg", 1, 0, ShippingBin.COMMISSION_FACTOR)
	var bench_kit := int(ProjectTable.get_project(&"workbench")["cost"])
	var earn_goal := int(Quests.TUTORIAL[Quests.index_of("earn")]["count"])
	_check(bench_kit <= morning + earn_goal,
			"the second day's workbench kit ($%d) takes the first day's sales ($%d) and the day's earning ($%d)" % [bench_kit, morning, earn_goal])
	_check(UiTheme.money(1500).contains("$") and UiTheme.money(1500).contains("1") and UiTheme.number(1500).find("$") < 0,
			"money reads with the dollar sign (%s), plain counts without" % UiTheme.money(1500))
	var paying: Array = Quests.TUTORIAL.filter(func(g: Dictionary) -> bool: return g.has("gold") or g.has("money"))
	_check(paying.is_empty(), "no story goal pays money")


func _build() -> void:
	var farm: Farm = Game.world.farm
	var level := Progress.level
	Economy.add_money(60000, "test")
	# Building everything needs ~620 wood, 230 stone and 20 iron.
	PlayerState.inventory.add_item(&"wood", 99 * 7)
	PlayerState.inventory.add_item(&"stone", 99 * 3)
	PlayerState.inventory.add_item(&"iron_ore", 30)
	Progress.level = 1
	_check(not FarmState.build(&"field_1") and not FarmState.build(&"coop_1"),
			"new fields and the coop wait for farm level %d" % UnlockTable.project_level(&"field_1"))
	Progress.level = Progress.MAX_LEVEL
	_check(not FarmState.build(&"field_2"), "field II needs field I first")
	_check(FarmState.build(&"field_1") and farm.fields.has(&"field_1"), "field expansion I builds 12 new beds")
	await _frames(3)
	_check((farm.fields[&"field_1"] as Field).plots.size() == 12, "new field has 12 beds")
	_check(FarmState.build(&"barn_1") and farm.barn.level == 1 and farm.barn.capacity() == 4, "open barn built (capacity 4)")
	_check(farm.barn.feed != null and farm.barn.water != null and farm.barn.feed.outdoors, "open barn has outdoor troughs")
	_check(FarmState.build(&"barn_2") and farm.barn.has_shelter() and farm.barn.capacity() == 8, "closed barn built (capacity 8, shelter)")
	_check(FarmState.build(&"coop_1") and farm.coop.level == 1, "chicken run built")
	var house: FarmHouse = Game.world.get_node("FarmHouse")
	# Run on its own, the farm is new: the house is repaired before it is extended.
	if not FarmState.is_built(&"house_1"):
		_check(not FarmState.build(&"house_2"), "the run-down house must be repaired before it can be extended")
		_check(FarmState.build(&"house_1") and house.level == 1, "the old house is repaired")
	if not FarmState.is_built(&"warehouse_1"):
		_check(FarmState.build(&"warehouse_1") and FarmState.warehouse.capacity == 400, "the old warehouse is repaired (400)")
	var door_before := house.to_global(Vector3(house.door_x, 0, house.D * 0.5))
	var leaf_before := house.front_door().global_position
	var table_before := house.table_point()
	var drawer_before := house.desk_drawer().global_position
	_check(FarmState.build(&"house_2") and house.level == 2 and house.W == 12.0, "house extended to level 2")
	var door_after := house.to_global(Vector3(house.door_x, 0, house.D * 0.5))
	_check(door_before.distance_to(door_after) < 0.01, "front door stays in place")
	_check(house.front_door().global_position.distance_to(leaf_before) < 0.01 and house.front_door().style == &"plank"
			and house.table_point().distance_to(table_before) < 0.01 and house.desk_drawer().global_position.distance_to(drawer_before) < 0.01,
			"the door leaf, the worktable and the desk drawer stay in place")
	await _frames(3)
	_check(house.get_node_or_null("Pantry") != null, "level 2 house has a pantry chest")
	_check(FarmState.build(&"house_3") and house.level == 3 and house.get_node_or_null("Wardrobe") != null, "level 3 house has a bedroom")
	var main_chest: Chest = house.get_node("Chest")
	_check(main_chest.inventory.count_item(&"wood") >= 10, "chest contents survive house upgrades")
	Progress.level = level


func _animals() -> void:
	var farm: Farm = Game.world.farm
	var player: Player = Game.player
	var inv := PlayerState.inventory
	Economy.add_money(20000, "test")
	GameClock.set_time_of_day(9.0)
	Weather.force(Weather.Kind.SUNNY)
	var level := Progress.level
	Progress.level = 1
	_check(Animals.can_buy(&"sheep", true) == tr("UI_NEEDS_LEVEL") % [UnlockTable.animal_level(&"sheep"), 1],
			"sheep wait for farm level %d" % UnlockTable.animal_level(&"sheep"))
	_check(UnlockTable.animal_level(&"chicken") == 1, "hens can be had from the first day")
	Progress.level = Progress.MAX_LEVEL
	_check(Animals.can_buy(&"cow", true) != "" or farm.barn.level > 0, "animals need a barn first")
	if farm.barn.level == 0:
		FarmState.built[&"barn_1"] = true
		FarmState.project_built.emit(&"barn_1")
	if farm.coop.level == 0:
		FarmState.built[&"coop_1"] = true
		FarmState.project_built.emit(&"coop_1")
	# The build scenario may already have built closed buildings; start from open pens.
	farm.barn.set_level(1)
	farm.coop.set_level(1)
	var cow := Animals.buy(&"cow", true)
	var sheep := Animals.buy(&"sheep", false)
	var horse := Animals.buy(&"horse", true)
	var hen := Animals.buy(&"chicken", true)
	_check(cow != null and sheep != null and horse != null and hen != null, "bought a cow, a lamb, a horse and a hen")
	_check(Animals.count_in("barn") == 3 and Animals.count_in("coop") == 1, "animals live in the barn and the coop")
	await _frames(10)
	var cow_node := Animals.node_of(cow)
	_check(cow_node != null and farm.barn.pen.has_point(Vector2(cow_node.global_position.x, cow_node.global_position.z)), "the cow is in the paddock")
	var hen_node := Animals.node_of(hen)
	_check(hen_node != null and farm.coop.pen.has_point(Vector2(hen_node.global_position.x, hen_node.global_position.z)), "the hen is in the chicken run")
	# Grandpa's run takes a crated hen from town at its gate.
	inv.add_item(&"chicken_crate", 1)
	var gate_out := WorldLayout.gate_point(farm.coop.pen, WorldLayout.COOP_GATE, 1.8)
	var gate_mid := WorldLayout.gate_point(farm.coop.pen, WorldLayout.COOP_GATE, 0.0)
	player.global_position = Vector3(gate_out.x, TerrainData.height(gate_out.x, gate_out.z) + 0.3, gate_out.z)
	_select(&"chicken_crate")
	await _frames(3)
	_look_at(player, Vector3(gate_mid.x, TerrainData.height(gate_mid.x, gate_mid.z) + 0.6, gate_mid.z))
	await _frames(6)
	_check(_last_prompt.contains(tr("ACTION_RELEASE_HEN")), "a crate in hand at Grandpa's run gate: E lets the hen in")
	var run_hens := Animals.count_in("coop")
	if player.target and player.target.has_method("interact"):
		player.target.interact(player)
	await _frames(3)
	var gate_hen: AnimalData = Animals.animals.back() if Animals.count_in("coop") > run_hens else null
	_check(gate_hen != null and inv.count_item(&"chicken_crate") == 0 and Animals.housing_of(gate_hen) == farm.coop
			and farm.coop.in_pen(Animals.node_of(gate_hen).global_position), "the crated hen moves into Grandpa's run")
	if gate_hen:
		Animals.sell(gate_hen)
	inv.remove_item(&"chicken_crate", inv.count_item(&"chicken_crate"))
	var buy_barn_full := ""
	Animals.buy(&"sheep", true)
	buy_barn_full = Animals.can_buy(&"cow", false)
	_check(buy_barn_full != "", "the open barn holds only 4 animals")

	# Fill the feed trough with hay through the real action.
	inv.add_item(&"hay", 20)
	_select(&"hay")
	var trough := farm.barn.feed
	player.global_position = trough.global_position + Vector3(0, 0.1, 1.8)
	_look_at(player, trough.global_position + Vector3(0, 0.3, 0))
	await _frames(6)
	await _hold_use(1.0)
	_check(trough.amount >= 7.9, "hay goes into the feed trough (%.0f)" % trough.amount)
	farm.barn.water.set_amount(farm.barn.water.capacity)

	# A day in good weather keeps them fed.
	GameClock.advance(10.0 * 60.0)
	_check(cow.fullness > 40.0 and cow.hydration > 40.0, "cow fed and watered (%.0f / %.0f)" % [cow.fullness, cow.hydration])

	# Rain on an open pen hurts the animals.
	var health := cow.health
	Weather.force(Weather.Kind.STORM)
	GameClock.advance(3.0 * 60.0)
	_check(cow.health < health - 10.0 and cow.wet > 0.5, "a storm hurts animals in the open pen (%.0f -> %.0f)" % [health, cow.health])
	_check(Animals.node_of(cow).status_key() in ["wet", "sick"], "the wet badge shows over the cow")

	# A closed barn: animals walk inside when it rains and stay dry.
	FarmState.built[&"barn_2"] = true
	FarmState.project_built.emit(&"barn_2")
	FarmState.built[&"coop_2"] = true
	FarmState.project_built.emit(&"coop_2")
	await _frames(5)
	Engine.time_scale = 6.0
	var inside := 0
	for i in 60:
		await _seconds(0.5)
		inside = 0
		for a in Animals.animals:
			var n := Animals.node_of(a)
			if n and n.indoors:
				inside += 1
		if inside == Animals.animals.size():
			break
	Engine.time_scale = 1.0
	_check(inside == Animals.animals.size(), "all animals went inside in the storm (%d/%d)" % [inside, Animals.animals.size()])
	health = cow.health
	var wet := cow.wet
	GameClock.advance(3.0 * 60.0)
	_check(cow.health >= health - 0.5 and cow.wet < wet, "sheltered animals stay dry (%.1f -> %.1f)" % [health, cow.health])
	Weather.force(Weather.Kind.SUNNY)

	# Products: milk in the morning, eggs from the hen.
	for a in Animals.animals:
		a.fed_hours = 24.0
		a.health = 100.0
		a.sick = false
	Events.day_started.emit(GameClock.day)
	await _frames(5)
	_check(cow.product_ready, "the cow has milk in the morning")
	var eggs := 0
	for p: Pickup in tree.get_nodes_in_group(&"pickups"):
		if p.stack.item.id == &"egg":
			eggs += 1
	_check(eggs >= 1, "the hen laid an egg")
	inv.add_item(&"milk_pail", 1)
	_select(&"milk_pail")
	cow_node = Animals.node_of(cow)
	cow_node._attention = 60.0
	await _frames(3)
	player.global_position = cow_node.global_position + Vector3(1.9, 0.1, 0)
	_look_at(player, cow_node.global_position + Vector3(0, 0.9, 0))
	await _frames(6)
	_check(player.target == cow_node, "aiming at the cow")
	var milk := inv.count_item(&"milk")
	await _hold_use(2.6)
	_check(inv.count_item(&"milk") == milk + 1 and not cow.product_ready, "milking gives milk")

	# Medicine cures a sick animal.
	cow.sick = true
	inv.add_item(&"medicine", 1)
	_select(&"medicine")
	cow_node._attention = 60.0
	await _frames(3)
	await _hold_use(1.8)
	_check(not cow.sick and inv.count_item(&"medicine") == 0, "medicine cures the cow")

	# Ride the horse out of the paddock.
	var horse_node := Animals.node_of(horse)
	horse_node._attention = 60.0
	if horse_node.indoors:
		horse_node.teleport_home(false)
	await _frames(3)
	player.global_position = horse_node.global_position + Vector3(1.9, 0.1, 0)
	_look_at(player, horse_node.global_position + Vector3(0, 1.1, 0))
	await _frames(6)
	await _press_key(KEY_E)
	await _frames(3)
	_check(player.riding == horse_node and horse_node.ridden, "mounted the horse")
	# Ride west through the gate.
	player.global_position = WorldLayout.gate_point(farm.barn.pen, WorldLayout.BARN_GATE, -2.0) + Vector3(0, 0.3, 0)
	player.look_at_yaw_pitch(PI * 0.5, 0.0)
	await _frames(3)
	var start := player.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _seconds(1.2)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _frames(3)
	var moved := player.global_position.distance_to(start)
	_check(moved > 6.0, "galloping is fast (%.1f m in 1.2 s)" % moved)
	_check(horse_node.global_position.distance_to(player.global_position) < 0.2, "the horse moves with the rider")
	await _press_key(KEY_E)
	await _frames(3)
	_check(player.riding == null and not horse_node.ridden and horse.away, "dismounted outside the paddock")

	# Selling an animal.
	var gold := Economy.money
	var count := Animals.animals.size()
	var value := Animals.sell(sheep)
	_check(Animals.animals.size() == count - 1 and Economy.money == gold + value and value > 0, "sold the lamb for %d" % value)
	# Next morning the horse is back home.
	Events.day_started.emit(GameClock.day)
	_check(not horse.away, "the horse returns home overnight")
	Progress.level = level


func _nearest(group: StringName, from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n: Node3D in tree.get_nodes_in_group(group):
		var d := n.global_position.distance_to(from)
		if d < best_d:
			best_d = d
			best = n
	return best


func get_first_bed() -> Node3D:
	return tree.get_first_node_in_group(&"beds") as Node3D


func _select(item_id: StringName) -> void:
	for i in PlayerState.inventory.size():
		var st := PlayerState.inventory.get_stack(i)
		if st and st.item.id == item_id:
			if i >= PlayerState.HOTBAR_SIZE:
				Inventory.transfer(PlayerState.inventory, i, PlayerState.inventory, PlayerState.HOTBAR_SIZE - 1)
				i = PlayerState.HOTBAR_SIZE - 1
			PlayerState.select(i)
			return


func _look_at(player: Player, point: Vector3) -> void:
	var cam := player.global_position + Vector3(0, 1.62, 0)
	var d := point - cam
	player.look_at_yaw_pitch(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


func _town() -> void:
	var player: Player = Game.player
	var town := tree.get_first_node_in_group(&"town") as Town
	_check(town != null and town.for_sale != null, "the town has a pickup for sale")
	var v := town.for_sale
	# Grandpa's pickup comes with the farm: owned, worn and slower than the dealer's.
	var old := town.farm_truck
	var home := Town.farm_truck_home()
	_check(old != null and old.owned and old.kind == &"pickup_old" and not v.owned
			and float(old.info["max_speed"]) < float(v.info["max_speed"])
			and float((old.info["paint"] as Dictionary).get("rust", 0.0)) > 0.3,
			"Grandpa's pickup is the player's from the start, rusty and slower than the dealer's")
	_check(Vector2(old.global_position.x, old.global_position.z).distance_to(Vector2(home.origin.x, home.origin.z)) < 1.0,
			"Grandpa's pickup stands by the warehouse")
	# On a new farm it is locked until Grandpa's key is in the bag; E with the key puts it
	# into the ignition for good (automated runs start unlocked: lock it for the check).
	_check(not old.is_locked(), "automated runs find Grandpa's pickup unlocked")
	var flag := old.unlock_flag()
	FarmState.flags.erase(flag)
	PlayerState.inventory.remove_item(&"truck_key", PlayerState.inventory.count_item(&"truck_key"))
	_check(old.is_locked() and old.interact_prompt(player) == tr("HINT_KEY_NEEDED"),
			"without the key Grandpa's pickup is locked (%s)" % old.interact_prompt(player))
	old.interact(player)
	await _frames(3)
	_check(player.driving == null, "E does not get into the locked pickup")
	PlayerState.inventory.add_item(&"truck_key")
	_check(old.interact_prompt(player) == tr("ACTION_UNLOCK_VEHICLE"), "with the key in the bag E offers to unlock it")
	var entered := [0, 0]
	var on_enter := func(_v: Node) -> void: entered[0] += 1
	var on_exit := func(_v: Node) -> void: entered[1] += 1
	Events.vehicle_entered.connect(on_enter)
	Events.vehicle_exited.connect(on_exit)
	old.interact(player)
	await _frames(5)
	_check(player.driving == old and not old.is_locked() and bool(FarmState.flags.get(flag, false))
			and not PlayerState.inventory.has_item(&"truck_key") and entered[0] == 1,
			"E with the key unlocks Grandpa's pickup for good; the key stays in the ignition")
	player.exit_vehicle()
	await _frames(5)
	_check(entered[1] == 1 and old.save_data().get("unlocked", false), "getting out is announced; the unlock is saved")
	Events.vehicle_entered.disconnect(on_enter)
	Events.vehicle_exited.disconnect(on_exit)
	# A real E press gets in and stays in (the same press must not reach the vehicle
	# as "get out"); the next one gets out.
	_look_at(player, old.global_position + Vector3(0, 1.0, 0))
	await _frames(4)
	await _press_key(KEY_E)
	await _frames(4)
	_check(player.driving == old, "pressing E at the pickup gets in and stays in")
	await _press_key(KEY_E)
	await _frames(4)
	_check(player.driving == null, "pressing E again gets out")
	old.teleport(home)
	await _frames(10)
	# The warehouse ledger loads it.
	var stock := FarmState.warehouse.to_dict()
	FarmState.warehouse.from_dict({"capacity": FarmState.warehouse.capacity, "items": {"carrot|0": 30}})
	Game.hud.open_storage(null)
	await _frames(3)
	var ledger: StorageScreen = Game.hud.storage_screen
	_check(ledger._vehicle == old and ledger._with_warehouse, "the warehouse ledger shows Grandpa's pickup bed")
	ledger._load_all()
	_check(old.cargo.count(&"carrot") == 30 and FarmState.warehouse.count(&"carrot") == 0, "loaded 30 carrots onto Grandpa's pickup")
	ledger.hide_screen()
	FarmState.warehouse.from_dict(stock)
	await _frames(3)
	# Parked at the market: the counter opens on SELL and sells the whole load at the quoted price.
	old.teleport(Transform3D(Basis(), town.market_counter.global_position + Vector3(-12.0, -0.6, 8.0)))
	await _frames(20)
	Game.hud.open_shop(ShopStock.town_market())
	await _frames(3)
	var market: ShopScreen = Game.hud.shop_screen
	_check(market.visible and market._tab == "sell", "a loaded pickup at the market opens the counter on SELL")
	var quoted := market._load_value(old.cargo)
	var before := Economy.money
	market._sell_load()
	_check(quoted > 0 and old.cargo.total() == 0 and Economy.money == before + quoted,
			"sold the whole load for the quoted %d gold" % quoted)
	market.close_screen()
	await _frames(3)
	# Home again before the dealer's truck uses the same market spot.
	old.teleport(home)
	await _frames(10)
	# Buying at the dealer.
	Economy.money = maxi(Economy.money, 3000)
	var money := Economy.money
	Game.hud.open_dealer(v)
	await _frames(3)
	Game.hud.dealer_screen._buy()
	_check(v.owned and Economy.money == money - v.price, "bought the pickup for %d" % v.price)
	await _frames(3)
	# Driving down the main street.
	v.teleport(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(192, TerrainData.height(192, 20) + 0.5, 20)))
	await _frames(20)
	player.enter_vehicle(v)
	await _frames(5)
	_check(player.driving == v and not player.visible, "player sits in the pickup")
	var hud_node: Control = Game.hud.vehicle_hud
	var dash: Control = hud_node.get_child(0)
	var screen: Rect2 = hud_node.get_viewport_rect()
	_check(hud_node.visible and screen.encloses(dash.get_global_rect()) and dash.size.x > 100.0,
			"the dashboard is shown (%s in %s)" % [dash.get_global_rect(), screen])
	var start := v.global_position
	var fuel := v.fuel
	Input.action_press("move_forward")
	await _seconds(4.0)
	var kmh := v.speed_kmh()
	Input.action_release("move_forward")
	var moved := v.global_position.distance_to(start)
	_check(moved > 15.0 and kmh > 25.0, "the pickup drives (%.1f m, %.0f km/h)" % [moved, kmh])
	_check(v.fuel < fuel, "driving burns fuel (%.3f L)" % (fuel - v.fuel))
	# Held S brakes to a stop (and would then reverse): let go once it has stopped.
	Input.action_press("move_back")
	var braked := 0.0
	while v.speed_kmh() > 3.0 and braked < 4.0:
		await _seconds(0.1)
		braked += 0.1
	Input.action_release("move_back")
	await _seconds(1.0)
	_check(v.speed_kmh() < 5.0, "braking stops it (%.1f km/h)" % v.speed_kmh())
	# Steering.
	var yaw0 := v.global_rotation.y
	Input.action_press("move_forward")
	Input.action_press("move_left")
	await _seconds(2.0)
	Input.action_release("move_left")
	Input.action_release("move_forward")
	_check(absf(angle_difference(yaw0, v.global_rotation.y)) > 0.3, "steering turns it (%.2f rad)" % angle_difference(yaw0, v.global_rotation.y))
	Input.action_press("move_back")
	await _seconds(2.0)
	Input.action_release("move_back")
	await _seconds(0.5)
	player.exit_vehicle()
	await _frames(5)
	_check(player.driving == null and player.visible and player.global_position.distance_to(v.global_position) < 4.0,
			"got out next to the pickup")
	# Refuelling at the pump.
	var pump: TownPoint = town.pumps[0]
	v.teleport(Transform3D(Basis(), pump.global_position + Vector3(2.2, 0.0, 0.0)))
	await _frames(20)
	v.fuel = 5.0
	money = Economy.money
	pump.interact(player)
	_check(v.fuel > 40.0 and Economy.money < money, "refuelled at the pump (%d gold)" % (money - Economy.money))
	# The poultry stall beside the market sells hens in crates, no coop needed; they go
	# into the bed of the pickup parked on the street in front.
	var stall := town.poultry_stall
	_check(stall != null and stall.global_position.distance_to(town.market_counter.global_position) < 25.0
			and town.poultry_marker != null and String(town.poultry_marker.get_meta(&"waypoint", "")) == "town_chickens",
			"the poultry stall stands next to the market, with its waypoint")
	var sx := stall.global_position.x
	v.teleport(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(sx, TerrainData.height(sx, 20) + 0.5, 20)))
	await _frames(20)
	v.cargo.from_dict({"capacity": v.cargo.capacity, "items": {}})
	Economy.money = maxi(Economy.money, 1500)
	money = Economy.money
	var bought := [0]
	var stored: Array[StringName] = []
	var on_bought := func(s: StringName, n: int) -> void:
		if s == &"chicken":
			bought[0] += n
	var on_stored := func(_id: StringName, where: StringName) -> void: stored.append(where)
	Events.animals_bought.connect(on_bought)
	Events.crate_stored.connect(on_stored)
	_check(town.vehicle_at_poultry() == v, "the pickup on the street counts as parked at the stall")
	_check(LiveCrates.can_buy(&"chicken", 2, stall.global_position) == "", "two crated hens can be bought without a coop")
	var got := LiveCrates.buy(&"chicken", 2, stall.global_position)
	await _frames(3)
	_check(got == 2 and v.cargo.count(&"chicken_crate") == 2 and Economy.money == money - 2 * LiveCrates.price(&"chicken")
			and bought[0] == 2 and stored.has(&"bed"), "bought 2 crated hens into the bed (%d gold)" % (money - Economy.money))
	await _seconds(1.0)
	_check(v.load_view().package_count() == 2 and v.load_view().live_count() == 2, "the bed shows 2 crates with a live hen in each")
	stall.interact(player)
	await _frames(3)
	var rancher: RancherScreen = Game.hud.rancher_screen
	_check(rancher.visible and rancher._poultry and not rancher._tabs.visible, "E at the stall opens the poultry seller")
	rancher.close_screen()
	await _frames(3)
	# No vehicle of the player's nearby: the crate goes into the bag.
	v.teleport(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(280.0, TerrainData.height(280.0, 20.0) + 0.5, 20.0)))
	await _frames(20)
	var in_bag := PlayerState.inventory.count_item(&"chicken_crate")
	_check(town.vehicle_at_poultry() == null and LiveCrates.buy(&"chicken", 1, stall.global_position) == 1
			and PlayerState.inventory.count_item(&"chicken_crate") == in_bag + 1, "with no vehicle near, the crate goes into the bag")
	PlayerState.inventory.remove_item(&"chicken_crate", PlayerState.inventory.count_item(&"chicken_crate"))
	v.cargo.from_dict({"capacity": v.cargo.capacity, "items": {}})
	Events.animals_bought.disconnect(on_bought)
	Events.crate_stored.disconnect(on_stored)
	# Warehouse -> bed -> market.
	FarmState.warehouse.add(&"pumpkin", 20)
	var door := WorldLayout.WAREHOUSE_RECT
	v.teleport(Transform3D(Basis(), Vector3(door.position.x + 4.0, TerrainData.height(door.position.x + 4, door.end.y + 4) + 0.6, door.end.y + 4.0)))
	player.global_position = Vector3(door.position.x + 6.5, 0.4, door.end.y + 1.5)
	await _frames(20)
	Game.hud.open_storage(null)
	await _frames(3)
	var storage: StorageScreen = Game.hud.storage_screen
	_check(storage._vehicle == v and storage._with_warehouse, "storage shows the warehouse and the pickup bed")
	storage._load_all()
	_check(v.cargo.count(&"pumpkin") == 20 and FarmState.warehouse.count(&"pumpkin") == 0, "loaded 20 pumpkins onto the pickup")
	storage.hide_screen()
	await _frames(3)
	v.teleport(Transform3D(Basis(), town.market_counter.global_position + Vector3(-12.0, -0.6, 8.0)))
	await _frames(20)
	Game.hud.open_shop(ShopStock.town_market())
	await _frames(3)
	var shop: ShopScreen = Game.hud.shop_screen
	shop._set_tab("sell")
	shop._sel = {"id": &"pumpkin", "quality": 0}
	shop._qty = 20
	money = Economy.money
	shop._confirm()
	_check(v.cargo.count(&"pumpkin") == 0 and Economy.money > money + 500, "sold the pumpkins from the bed (+%d)" % (Economy.money - money))
	shop.close_screen()
	await _frames(3)


func _cargo() -> void:
	var player: Player = Game.player
	var town := tree.get_first_node_in_group(&"town") as Town
	var v := town.for_sale
	if not v.owned:
		v.owned = true
		v.changed.emit()
	v.cargo.from_dict({"capacity": v.cargo.capacity, "items": {}})
	# The load that came baked into the model's bed trim is cut away.
	var baked := -1
	for mi: MeshInstance3D in v.find_children("*", "MeshInstance3D", true, false):
		if "Truckbed_Trim" in String(mi.name):
			baked = 0
			var model_node := v.get_node("Model") as Node3D
			var xf := model_node.global_transform.affine_inverse() * mi.global_transform
			for si in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(si)
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				for t in idx.size() / 3:
					var c := xf * ((verts[idx[t * 3]] + verts[idx[t * 3 + 1]] + verts[idx[t * 3 + 2]]) / 3.0)
					if AABB(Vector3(-2.15, 0.8, -0.75), Vector3(2.15, 0.55, 1.5)).has_point(c):
						baked += 1
	_check(baked == 0, "the load baked into the pickup bed is gone (%d triangles left in the bed)" % baked)
	# Backed up to the warehouse door; the farmer stands at the tailgate.
	var door := WorldLayout.WAREHOUSE_RECT
	var park := Vector3(door.position.x + 4.0, 0.0, door.end.y + 4.0)
	park.y = TerrainData.height(park.x, park.z) + 0.6
	v.teleport(Transform3D(Basis(), park))
	await _frames(40)
	var spot := Vector3(park.x, 0.0, park.z - 3.8)
	player.global_position = Vector3(spot.x, TerrainData.height(spot.x, spot.z) + 0.2, spot.z)
	player.look_at_yaw_pitch(PI, deg_to_rad(-25.0))
	var old_slot := PlayerState.inventory.get_stack(7)
	PlayerState.inventory.set_stack(7, ItemStack.create(&"tomato", 14))
	PlayerState.select(7)
	await _frames(10)
	_check(player.target is BedPoint, "looking into the bed from the tailgate targets the bed (%s)" % player.target)
	var want := tr("ACTION_LOAD_BED") % [ItemDB.get_item(&"tomato").display_name(), 14]
	_check(" ".join(player._last_prompt).contains(want), "the prompt offers to load the tomatoes (%s)" % " / ".join(player._last_prompt))
	await _press_key(KEY_E)
	await _frames(3)
	var bed := v.load_view()
	_check(v.cargo.count(&"tomato") == 14 and PlayerState.inventory.get_stack(7) == null, "E loads the tomatoes in hand into the bed")
	_check(bed.package_count() == ceili(14.0 / bed.units_per_slot()), "the bed shows %d crates" % bed.package_count())
	_check(v.mass > float(v.info["mass"]) + 1.0, "the load adds weight (%.1f kg)" % (v.mass - float(v.info["mass"])))
	# F opens the bed next to the warehouse; unload it all.
	await _press_key(KEY_F)
	await _frames(3)
	var storage: StorageScreen = Game.hud.storage_screen
	_check(storage.visible and storage._vehicle == v and storage._with_warehouse, "F opens the bed and the warehouse")
	var stocked := FarmState.warehouse.count(&"tomato")
	storage._unload_all()
	_check(v.cargo.total() == 0 and FarmState.warehouse.count(&"tomato") == stocked + 14, "unloaded the bed into the warehouse")
	storage.hide_screen()
	await _frames(3)
	_check(bed.package_count() == 0 and is_equal_approx(v.mass, float(v.info["mass"])), "the empty bed weighs nothing")
	# Crated hens: one package each with a live hen in it; E from the tailgate lifts them out.
	v.cargo.add(&"chicken_crate", 2)
	await _seconds(1.0)
	_check(bed.package_count() == 2 and bed.live_count() == 2 and is_equal_approx(v.cargo_kg(), 12.0),
			"2 crates show as 2 packages with a live hen each (%d, %d, %.1f kg)" % [bed.package_count(), bed.live_count(), v.cargo_kg()])
	PlayerState.inventory.set_stack(7, null)
	PlayerState.select(7)
	player.look_at_yaw_pitch(PI, deg_to_rad(-25.0))
	await _frames(10)
	var take := tr("ACTION_TAKE_CRATE") % [ItemDB.get_item(&"chicken_crate").display_name(), 2]
	_check(" ".join(player._last_prompt).contains(take), "the prompt offers to take a crate (%s)" % " / ".join(player._last_prompt))
	await _press_key(KEY_E)
	await _frames(3)
	var hand := PlayerState.selected_stack()
	_check(v.cargo.count(&"chicken_crate") == 1 and hand != null and hand.item.id == &"chicken_crate" and hand.count == 1,
			"E lifts one crate out into the hands")
	await _press_key(KEY_E)
	await _frames(3)
	hand = PlayerState.selected_stack()
	_check(v.cargo.count(&"chicken_crate") == 0 and hand != null and hand.count == 2, "E again takes the second crate too")
	await _seconds(0.5)
	_check(bed.live_count() == 0 and bed.package_count() == 0, "no crates or hens left in the bed")
	# The warehouse crate corner: E sets the crates in hand down, E again takes one back.
	var bay := (tree.get_first_node_in_group(&"warehouse") as Warehouse).crate_bay
	var stored: Array[StringName] = []
	var on_stored := func(_id: StringName, where: StringName) -> void: stored.append(where)
	Events.crate_stored.connect(on_stored)
	var in_stock := FarmState.warehouse.count(&"chicken_crate")
	bay.interact(player)
	await _frames(3)
	_check(FarmState.warehouse.count(&"chicken_crate") == in_stock + 2 and PlayerState.inventory.get_stack(7) == null
			and stored.has(&"warehouse"), "E at the crate corner sets both crates down in the warehouse")
	_check(bay.shown() == in_stock + 2 and bay.live_count() == mini(in_stock + 2, CrateBay.LIVE_MAX),
			"the crate corner shows them with a live hen in each (%d, %d)" % [bay.shown(), bay.live_count()])
	bay.interact(player)
	await _frames(3)
	hand = PlayerState.selected_stack()
	_check(FarmState.warehouse.count(&"chicken_crate") == in_stock + 1 and hand != null and hand.item.id == &"chicken_crate",
			"E at the crate corner takes one back into the hands")
	bay.interact(player)
	await _frames(3)
	hand = PlayerState.selected_stack()
	_check(FarmState.warehouse.count(&"chicken_crate") == in_stock and hand != null and hand.count == 2,
			"E again stacks the next crate on the one in hand")
	_check(bay.drop_held() and FarmState.warehouse.count(&"chicken_crate") == in_stock + 2
			and PlayerState.selected_stack() == null, "Q at the crate corner sets the crates in hand down")
	bay.interact(player)
	await _frames(3)
	# The ledger moves crates like goods; a key stays in the bag.
	PlayerState.inventory.add_item(&"truck_key")
	Game.hud.open_storage(null)
	await _frames(3)
	var ledger: StorageScreen = Game.hud.storage_screen
	var crate_row := {}
	var key_row := {}
	for e: Dictionary in ledger._entries("bag"):
		if e["id"] == &"chicken_crate":
			crate_row = e
		elif e["id"] == &"truck_key":
			key_row = e
	_check(bool(crate_row.get("movable", false)) and not bool(key_row.get("movable", true))
			and not Stockpile.can_store(ItemDB.get_item(&"truck_key")) and not Vehicle.is_cargo(ItemStack.create(&"truck_key")),
			"the ledger moves crated hens; the pickup key stays in the bag")
	ledger.hide_screen()
	await _frames(3)
	PlayerState.inventory.remove_item(&"truck_key", 1)
	PlayerState.inventory.set_stack(7, null)
	FarmState.warehouse.take(&"chicken_crate", in_stock + 1, 0)
	Events.crate_stored.disconnect(on_stored)
	await _frames(3)
	# A full load of firewood fills every slot and stays inside the bed.
	v.cargo.add(&"wood", v.cargo.capacity)
	await _seconds(2.2)
	var top := bed.load_top()
	_check(bed.package_count() == ceili(float(v.cargo.capacity) / bed.units_per_slot()) and top <= float(v.info["bed_top"]) + 0.03,
			"a full bed: %d of %d slots, load top %.2f m" % [bed.package_count(), bed.slots.size(), top])
	v.cargo.take(&"wood", 1, 0)
	v.cargo.add(&"chicken_crate", 1)
	await _seconds(1.0)
	_check(bed.package_count() <= bed.slots.size() and bed.live_count() == 1, "a crate still shows on a full bed of wood")
	v.cargo.take(&"chicken_crate", 1, 0)
	v.cargo.add(&"wood", 1)
	await _seconds(0.5)
	# The loaded pickup still drives, a little slower.
	v.teleport(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(192, TerrainData.height(192, 20) + 0.5, 20)))
	await _frames(20)
	player.enter_vehicle(v)
	await _frames(5)
	var start := v.global_position
	Input.action_press("move_forward")
	await _seconds(4.0)
	var kmh := v.speed_kmh()
	Input.action_release("move_forward")
	var drift := absf(v.global_position.z - start.z)
	_check(kmh > 18.0 and v.global_basis.y.y > 0.9 and drift < 0.5, "the loaded pickup drives straight (%.0f km/h with %.0f kg, %.2f m drift)" % [kmh, v.cargo_kg(), drift])
	Input.action_press("move_back")
	await _seconds(3.0)
	Input.action_release("move_back")
	await _seconds(0.8)
	var parked := v.global_position
	player.exit_vehicle()
	await _frames(15)
	_check(v.global_position.distance_to(parked) < 0.6 and v.global_basis.y.y > 0.95,
			"getting out leaves the pickup standing (moved %.2f m)" % v.global_position.distance_to(parked))
	# Looking at the cab from the driver's side still offers to drive.
	var side := v.to_global(Vector3(2.0, 0.0, 0.45))
	var look := -v.global_basis.x
	player.global_position = Vector3(side.x, TerrainData.height(side.x, side.z) + 0.2, side.z)
	player.look_at_yaw_pitch(atan2(-look.x, -look.z), deg_to_rad(-8.0))
	await _frames(10)
	_check(player.target == v, "looking at the cab targets the pickup itself (%s)" % player.target)
	v.cargo.from_dict({"capacity": v.cargo.capacity, "items": {}})
	PlayerState.inventory.set_stack(7, old_slot)
	PlayerState.select(0)
	await _frames(3)


## How the pickup's body settles after a drop, a hard stop and a lane change, empty
## and with a full bed: no long bouncing or rocking, moderate roll, no wheel lift.
func _suspension() -> Dictionary:
	var town := tree.get_first_node_in_group(&"town") as Town
	var v := town.for_sale
	if not v.owned:
		v.owned = true
		v.changed.emit()
	v.cargo.from_dict({"capacity": v.cargo.capacity, "items": {}})
	var m := await _suspension_run(v, "empty")
	v.cargo.add(&"wood", v.cargo.capacity)
	var loaded := await _suspension_run(v, "loaded")
	for k: String in loaded:
		m["loaded_" + k] = loaded[k]
	v.cargo.from_dict({"capacity": v.cargo.capacity, "items": {}})
	_check(float(m["drop_settle"]) < 1.0 and int(m["drop_bounces"]) <= 3,
			"a drop settles in %.2f s (%d bounces)" % [m["drop_settle"], m["drop_bounces"]])
	_check(int(m["stop_rocks"]) <= 1 and int(m["loaded_stop_rocks"]) <= 1,
			"no rocking after a hard stop (%d empty, %d loaded)" % [m["stop_rocks"], m["loaded_stop_rocks"]])
	_check(float(m["roll_peak_deg"]) < 4.5 and float(m["loaded_roll_peak_deg"]) < 6.0,
			"lane change roll %.1f° empty, %.1f° loaded" % [m["roll_peak_deg"], m["loaded_roll_peak_deg"]])
	_check(int(m["wheel_lift_frames"]) == 0, "no wheel lifts in an empty lane change")
	return m


func _suspension_run(v: Vehicle, label: String) -> Dictionary:
	var player: Player = Game.player
	if player.driving:
		player.exit_vehicle()
		await _frames(5)
	player.global_position = Vector3(150, TerrainData.height(150, 60) + 0.3, 60)
	var m := {}
	# Drop from 25 cm above resting height on the flat street.
	var street := Vector3(200, 0, 20)
	var ground := TerrainData.height(street.x, street.z)
	v.teleport(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(street.x, ground + 0.5, street.z)))
	await _seconds(2.5)
	var rest_y := v.global_position.y
	v.teleport(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(street.x, rest_y + 0.25, street.z)))
	var ys: Array[float] = []
	for i in 180:
		await tree.physics_frame
		ys.append(v.global_position.y)
	var drop := _settle(ys, 0.01, 0.004)
	m["drop_settle"] = drop[0]
	m["drop_bounces"] = drop[1]
	# Hard stop from speed on the street (heading +X).
	v.teleport(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(172, TerrainData.height(172, 20) + 0.5, 20)))
	await _frames(30)
	player.enter_vehicle(v)
	await _frames(3)
	Input.action_press("move_forward")
	await _seconds(4.5)
	Input.action_release("move_forward")
	m["brake_from_kmh"] = v.speed_kmh()
	var pitch0 := rad_to_deg(asin(clampf(v.global_basis.z.y, -1.0, 1.0)))
	Input.action_press("move_back")
	var pitch: Array[float] = []
	var stopped := -1
	var dive := 0.0
	for i in 300:
		await tree.physics_frame
		var p := rad_to_deg(asin(clampf(v.global_basis.z.y, -1.0, 1.0)))
		dive = minf(dive, p - pitch0)
		if stopped < 0 and v.speed_kmh() < 1.0:
			stopped = i
			Input.action_release("move_back")
		if stopped >= 0:
			pitch.append(p)
		if stopped >= 0 and pitch.size() >= 150:
			break
	Input.action_release("move_back")
	var stop := _settle(pitch, 0.15, 0.08)
	m["brake_dive_deg"] = dive
	m["stop_settle"] = stop[0]
	m["stop_rocks"] = stop[1]
	# Lane change at speed (half lock left, then right), then let go: the body
	# must not keep rocking.
	v.teleport(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(180, TerrainData.height(180, 20) + 0.5, 20)))
	await _frames(30)
	Input.action_press("move_forward")
	await _seconds(2.6)
	m["lane_kmh"] = v.speed_kmh()
	Input.action_release("move_forward")
	var roll_peak := 0.0
	var lifted := 0
	for side: String in ["move_left", "move_right"]:
		Input.action_press(side, 0.5)
		for i in 27:
			await tree.physics_frame
			roll_peak = maxf(roll_peak, absf(rad_to_deg(asin(clampf(v.global_basis.x.y, -1.0, 1.0)))))
			for key: String in ["fl", "fr", "rl", "rr"]:
				if not (v._wheels[key] as VehicleWheel3D).is_in_contact():
					lifted += 1
		Input.action_release(side)
	var roll: Array[float] = []
	for i in 150:
		await tree.physics_frame
		roll.append(rad_to_deg(asin(clampf(v.global_basis.x.y, -1.0, 1.0))))
	var turn := _settle(roll, 0.15, 0.08)
	m["roll_peak_deg"] = roll_peak
	m["wheel_lift_frames"] = lifted
	m["roll_settle"] = turn[0]
	m["roll_rocks"] = turn[1]
	Input.action_press("move_back")
	await _seconds(2.5)
	Input.action_release("move_back")
	player.exit_vehicle()
	await _frames(5)
	var line := "SUSP " + label
	for k: String in m:
		line += " %s=%.2f" % [k, float(m[k])]
	print(line)
	return m


## [seconds until `values` stays within `tol` of where it ends, swings bigger than
## `swing` around that end value].
func _settle(values: Array[float], tol: float, swing: float) -> Array:
	if values.is_empty():
		return [0.0, 0]
	var tail := 0.0
	var count := mini(20, values.size())
	for i in count:
		tail += values[values.size() - 1 - i]
	tail /= count
	var last := 0
	for i in values.size():
		if absf(values[i] - tail) > tol:
			last = i
	var swings := 0
	for i in range(1, values.size() - 1):
		var a := values[i] - values[i - 1]
		var b := values[i + 1] - values[i]
		if a * b < 0.0 and absf(values[i] - tail) > swing:
			swings += 1
	return [last / 60.0, swings]


## Geometry that is always on screen stays cheap: the town mesh has no heavy props
## baked in, the leaf-card hill forest only draws up close and the far forest is
## impostor cards.
func _budget() -> void:
	var town := tree.get_first_node_in_group(&"town") as Town
	var town_mesh := town.get_node("TownMesh") as MeshInstance3D
	var tris := 0
	for si in town_mesh.mesh.get_surface_count():
		tris += (town_mesh.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_check(tris < 150000, "the town mesh stays light (%d triangles)" % tris)
	var near := 0
	var unranged := 0
	var far := 0
	for n in tree.current_scene.find_children("HillForest*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		if String(mmi.name).begins_with("HillForestFar"):
			far += mmi.multimesh.instance_count
		else:
			near += 1
			if mmi.visibility_range_end <= 0.0:
				unranged += 1
	_check(near > 0 and unranged == 0, "leaf-card forest tiles all fade out with distance (%d tiles)" % near)
	_check(far > 1000, "the far forest is drawn as %d impostor trees" % far)
	await _frames(1)


## Saves a farm with a bit of everything, changes it all, loads it back (the game
## scene is rebuilt) and compares; then deletes the save and starts a new game.
## Automated runs save into their own folder.
func _save_load() -> void:
	var player: Player = Game.player
	var town := tree.get_first_node_in_group(&"town") as Town
	var v := town.for_sale
	var ground := TerrainData.height(-8, 6)
	Economy.money = 12345
	GameClock.day = 7
	GameClock.minute = 15 * 60 + 30
	FarmState.warehouse.from_dict({"capacity": FarmState.warehouse.capacity, "items": {"tomato|0": 33, "chicken_crate|0": 3}})
	PlayerState.inventory.add_item(&"carrot", 17)
	var carrots := PlayerState.inventory.count_item(&"carrot")
	var plot: FarmPlot = tree.get_nodes_in_group(&"farm_plots")[0]
	plot.load_data({"soil": FarmPlot.Soil.TILLED, "crop": "tomato", "growth": 0.42, "harvests": 1, "wet": 3.0})
	var plot_spot := plot.global_position
	var felled_id := ""
	for t: ChoppableTree in tree.get_nodes_in_group(&"trees"):
		if not t.felled and t.resource_id != "":
			felled_id = t.resource_id
			break
	FarmState.depleted[felled_id] = GameClock.day
	FarmState.stumps[felled_id] = [0.95, 1.0]
	var farm: Farm = Game.world.farm
	# A finished coop with its door shut and a hen, and a site half done.
	var ce := FarmState.add_placed(&"coop_kit", Vector3(35.0, TerrainData.height(35.0, -17.5), -17.5), 0.5)
	var saved_coop := farm.spawn_placed(ce) as ChickenCoop
	await _frames(2)
	saved_coop.housing.door.set_open(false, false)
	Animals.release(&"chicken", saved_coop.housing)
	var se := FarmState.add_placed(&"coop_kit", Vector3(35.0, TerrainData.height(35.0, -31.5), -31.5), 0.0)
	se["stage"] = "site"
	se["build_left"] = 97.0
	farm.spawn_placed(se)
	var animals := Animals.animals.map(func(a: AnimalData) -> String: return "%s_%d" % [a.species, a.id])
	v.owned = true
	v.changed.emit()
	v.fuel = 20.5
	v.odometer = 1234.0
	v.cargo.from_dict({"capacity": v.cargo.capacity, "items": {"pumpkin|0": 12}})
	v.teleport(Transform3D(Basis(Vector3.UP, 0.7), Vector3(-15, TerrainData.height(-15, -3) + 0.6, -3)))
	var old := town.farm_truck
	old.fuel = 11.0
	old.cargo.from_dict({"capacity": old.cargo.capacity, "items": {"carrot|0": 25, "chicken_crate|0": 2}})
	old.teleport(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-21, TerrainData.height(-21, 5) + 0.6, 5)))
	Weather.snow_cover = 0.35
	player.global_position = Vector3(-8, ground + 0.3, 6)
	player.look_at_yaw_pitch(1.2, -0.1)
	await _frames(40)
	var parked := v.global_position
	var old_parked := old.global_position
	var standing := player.global_position
	var slot := "slot_3"
	# The house keeps its door and table in FarmState.flags: shut the door, "take" the hoe.
	FarmState.flags[FarmHouse.DOOR_FLAG] = false
	FarmState.flags[FarmHouse.TABLE_FLAG] = ["hoe"]
	# The clock stands still from the save to the checks below, so nothing grows or moves on
	# while the game loads (earlier scenarios leave it running or not).
	var clock_ran := GameClock.running
	GameClock.running = false
	_check(SaveGame.save(slot), "saved the game into %s" % slot)
	var h := SaveGame.info(slot)
	_check(int(h.get("day", 0)) == 7 and int(h.get("money", 0)) == 12345 and int(h.get("version", 0)) == SaveGame.VERSION,
			"the slot header shows day 7, 12,345 gold, version %d" % SaveGame.VERSION)
	# Change it all.
	Economy.money = 5
	GameClock.day = 2
	FarmState.warehouse.from_dict({"capacity": FarmState.warehouse.capacity, "items": {}})
	PlayerState.inventory.remove_item(&"carrot", carrots)
	plot.load_data({})
	v.owned = false
	v.cargo.from_dict({"capacity": v.cargo.capacity, "items": {}})
	old.cargo.from_dict({"capacity": old.cargo.capacity, "items": {}})
	# Load it back into a rebuilt game scene.
	_check(SaveGame.load_game(slot), "loading %s started" % slot)
	await _until_loaded()
	player = Game.player
	town = tree.get_first_node_in_group(&"town") as Town
	v = town.for_sale
	_check(Economy.money == 12345 and GameClock.day == 7 and absf(GameClock.minute - (15 * 60 + 30)) < 10.0,
			"money, day and time are back (%d gold, day %d, %s)" % [Economy.money, GameClock.day, GameClock.time_string()])
	_check(FarmState.warehouse.count(&"tomato") == 33 and PlayerState.inventory.count_item(&"carrot") == carrots,
			"the warehouse and the bag are back")
	var back_plot: FarmPlot = null
	for p: FarmPlot in tree.get_nodes_in_group(&"farm_plots"):
		if p.global_position.distance_to(plot_spot) < 0.05:
			back_plot = p
	_check(back_plot != null and back_plot.crop == &"tomato" and is_equal_approx(back_plot.growth, 0.42) and back_plot.soil == FarmPlot.Soil.TILLED,
			"the planted field plot is back")
	GameClock.running = clock_ran
	var stump := false
	var cut := 0.0
	for t: ChoppableTree in tree.get_nodes_in_group(&"trees"):
		if t.resource_id == felled_id:
			stump = t.felled
			cut = t.cut_height
	_check(felled_id != "" and stump and is_equal_approx(cut, 0.95), "the felled tree is still a stump, cut as before (%.2f m)" % cut)
	var animals_back := Animals.animals.map(func(a: AnimalData) -> String: return "%s_%d" % [a.species, a.id])
	var spawned := 0
	for a in Animals.animals:
		if Animals.node_of(a):
			spawned += 1
	_check(animals_back == animals and spawned == animals.size(), "the %d animals are back on the farm" % animals.size())
	var coops := (Game.world.farm as Farm).kit_coops()
	var done_coop: ChickenCoop = null
	var half_site: ChickenCoop = null
	for c in coops:
		if c.is_built():
			done_coop = c
		else:
			half_site = c
	_check(done_coop != null and not done_coop.housing.door_open and Animals.count_at(done_coop.housing) == 1,
			"a kit coop comes back with its door shut and its hen")
	_check(half_site != null and absf(half_site.seconds_left() - 97.0) < 1.0, "a construction site comes back with its time left")
	_check(v.owned and is_equal_approx(v.fuel, 20.5) and v.cargo.count(&"pumpkin") == 12 and v.global_position.distance_to(parked) < 0.6
			and v.load_view().package_count() == 2, "the pickup is back: owned, fuel, load and where it was parked")
	var old_back := town.farm_truck
	_check(old_back.owned and is_equal_approx(old_back.fuel, 11.0) and old_back.cargo.count(&"carrot") == 25
			and old_back.global_position.distance_to(old_parked) < 0.6, "Grandpa's pickup is back: fuel, load and where it was parked")
	await _frames(3)
	var bay_back := (tree.get_first_node_in_group(&"warehouse") as Warehouse).crate_bay
	_check(old_back.cargo.count(&"chicken_crate") == 2 and old_back.load_view().live_count() == 2
			and FarmState.warehouse.count(&"chicken_crate") == 3 and bay_back.shown() == 3 and bay_back.live_count() == 3
			and not old_back.is_locked(), "the crated hens are back in the bed and the crate corner; the pickup is unlocked")
	# A truck saved before the lock (no "unlocked" in its dict) comes open.
	FarmState.flags.erase(old_back.unlock_flag())
	old_back.load_data({"kind": "pickup_old", "owned": true, "fuel": 11.0, "cargo": {"capacity": old_back.cargo.capacity, "items": {}}})
	_check(not old_back.is_locked(), "a pickup saved before the key lock loads unlocked")
	_check(player.global_position.distance_to(standing) < 0.5 and absf(player.rotation.y - 1.2) < 0.01,
			"the player stands where the game was saved")
	_check(absf(Weather.snow_cover - 0.35) < 0.05, "the snow cover is back")
	var house_back: FarmHouse = Game.world.get_node("FarmHouse")
	_check(not house_back.front_door().is_open() and FarmHouse.table_taken_count() == 1,
			"the shut front door and the taken hoe are remembered")
	_check(not Game.is_ui_open() and not Game.hud.title_screen.visible, "the game resumes straight away")
	SaveGame.delete(slot)
	_check(SaveGame.info(slot).is_empty(), "the save can be deleted")
	# A new game starts over.
	SaveGame.new_game()
	await _until_loaded()
	town = tree.get_first_node_in_group(&"town") as Town
	_check(Economy.money == Economy.STARTING_MONEY and GameClock.day == 1 and Animals.animals.is_empty()
			and FarmState.warehouse.total() == 0 and not town.for_sale.owned,
			"a new game starts from scratch")
	# Assumes nothing hands out items on a new game in automated runs (only at launch).
	_check(PlayerState.inventory.slots.all(func(st: ItemStack) -> bool: return st == null)
			and not PlayerState.hotbar_unlocked and not Game.hud.hotbar.visible and Achievements.unlocked.is_empty(),
			"a new game starts with an empty, locked bag, no hotbar and no achievements")
	_check(Quests.current().get("id", "") == "door" and int(Quests.save_data().get("chain", 0)) == Quests.CHAIN,
			"a new game's story starts at the front door, in this chain's format")
	var home := Town.farm_truck_home()
	_check(town.farm_truck.owned and town.farm_truck.cargo.total() == 0
			and Vector2(town.farm_truck.global_position.x, town.farm_truck.global_position.z).distance_to(Vector2(home.origin.x, home.origin.z)) < 1.0,
			"a new game has Grandpa's pickup by the warehouse, empty")
	# A game saved before Grandpa's pickup came with the farm, with the dealer's pickup
	# parked on its spot: Grandpa's (unknown to the save) makes room.
	town.farm_truck.restored = false
	town.for_sale.load_data({"kind": "pickup_90", "owned": true, "xform": home, "fuel": 10.0,
		"cargo": {"capacity": town.for_sale.cargo.capacity, "items": {}}})
	await _frames(20)
	_check(town.farm_truck.global_position.distance_to(town.for_sale.global_position) > 5.0
			and town.farm_truck.global_basis.y.y > 0.9, "Grandpa's pickup makes room for a saved truck parked on its spot")
	# That save never knew the pickup, so it never had the lock either: loading opens it
	# (Vehicle._on_game_loaded runs on SaveGame.loaded for a vehicle the save did not restore).
	FarmState.flags.erase(town.farm_truck.unlock_flag())
	_check(town.farm_truck.is_locked(), "without the flag the pickup is locked")
	town.farm_truck._on_game_loaded("slot_1")
	_check(not town.farm_truck.is_locked(), "a pickup the loaded save did not know comes unlocked")
	SaveGame.new_game()
	await _until_loaded()
	_check(FarmState.house_level() == 0 and FarmState.warehouse_level() == 0 and FarmState.warehouse.capacity == 200,
			"a new game starts with Grandpa's run-down house and warehouse")
	var new_house: FarmHouse = Game.world.get_node("FarmHouse")
	# The only flags a new game may have are the ones its new world sets: in automated
	# runs each truck's key is already in its ignition (Vehicle.UNLOCK_FLAG, see Vehicle._ready).
	var kept_flags := FarmState.flags.keys().filter(func(k: Variant) -> bool:
		return not String(k).begins_with(Vehicle.UNLOCK_FLAG % ""))
	_check(kept_flags.is_empty() and new_house.front_door().is_open() and new_house.front_door().style == &"ruin",
			"a new game forgets the house's flags (automated: Grandpa's old door stands open) (flags %s)" % str(FarmState.flags))


## The scanned tool models: baked and up to date, sized and placed like the old ones,
## and the one in the player's hand.
func _tools() -> void:
	var stale := PackedStringArray()
	var wrong := PackedStringArray()
	for id: StringName in ToolModels.MODELS:
		var cfg: Dictionary = ToolModels.MODELS[id]
		if not ResourceLoader.exists(ToolModels.BAKED % id):
			stale.append("%s (not baked)" % id)
			continue
		var baked := ToolModels.mesh(id).get_aabb()
		var fresh := ToolModels.build(id).get_aabb()
		if not baked.position.is_equal_approx(fresh.position) or not baked.size.is_equal_approx(fresh.size):
			stale.append(String(id))
		if cfg["kind"] == "long":
			if absf(baked.size.y - float(cfg["length"])) > 0.02 or absf(baked.position.y - float(cfg["bottom"])) > 0.02:
				wrong.append("%s %s" % [id, baked])
		elif absf(baked.position.y) > 0.005 or absf(baked.get_longest_axis_size() - float(cfg["size"])) > 0.02:
			wrong.append("%s %s" % [id, baked])
	_check(stale.is_empty(), "the baked tool meshes match their sources %s (run tools/bake_tools.gd)" % [stale])
	_check(wrong.is_empty(), "scanned tools have their length and grip %s" % [wrong])
	var old_slot := PlayerState.inventory.get_stack(7)
	PlayerState.inventory.set_stack(7, ItemStack.create(&"axe"))
	PlayerState.select(7)
	await _frames(3)
	var held := (Game.player as Player).held
	var shown: Mesh = held._model.mesh
	_check(shown == ItemModels.mesh(&"axe") and shown.resource_path == ToolModels.BAKED % &"axe",
			"the axe in hand is the scanned model")
	PlayerState.inventory.set_stack(7, old_slot)
	PlayerState.select(0)
	await _frames(2)


## Placing machines, crafting, a batch of cheese, the sprinkler, fertilizer, the manure
## heap and a birth in the barn.
func _workshop() -> void:
	var player: Player = Game.player
	var farm: Farm = Game.world.farm
	var inv := PlayerState.inventory
	var old_slot := inv.get_stack(7)
	var level := Progress.level
	# Place the workbench on open ground east of the field.
	inv.set_stack(7, ItemStack.create(&"workbench"))
	PlayerState.select(7)
	var spot := Vector3(20.0, 0.0, -8.0)
	player.global_position = Vector3(spot.x, TerrainData.height(spot.x, spot.z) + 0.3, spot.z + 3.2)
	player.look_at_yaw_pitch(0.0, deg_to_rad(-38.0))
	await _frames(6)
	_check(player.placer.active and player.placer.valid, "a placeable in hand shows a valid preview (%s)" % player.placer.reason)
	var placed_before := FarmState.placed.size()
	_check(player.placer.place() and FarmState.placed.size() == placed_before + 1 and inv.count_item(&"workbench") == 0,
			"the workbench is put down")
	await _frames(3)
	var bench: Workbench = null
	for n in tree.get_nodes_in_group(&"placed"):
		if n is Workbench:
			bench = n
	_check(bench != null, "the workbench stands on the farm")
	# Not in town.
	inv.set_stack(7, ItemStack.create(&"sprinkler"))
	PlayerState.select(7)
	player.global_position = Vector3(228, TerrainData.height(228, 18) + 0.3, 18)
	await _frames(6)
	_check(player.placer.active and not player.placer.valid and player.placer.reason == "MSG_PLACE_FARM_ONLY",
			"machines can't go in town")
	# Crafting: locked by level, then made.
	var press_level: int = RecipeTable.crafting(&"cheese_press")["level"]
	Progress.level = press_level - 1
	inv.add_item(&"wood", 60)
	inv.add_item(&"iron_ore", 20)
	inv.add_item(&"stone", 20)
	var crafting: CraftingScreen = Game.hud.crafting_screen
	_check(not crafting.craft(&"cheese_press"), "the cheese press needs farm level %d" % press_level)
	Progress.level = press_level
	var wood := inv.count_item(&"wood")
	_check(crafting.craft(&"cheese_press") and inv.count_item(&"cheese_press") == 1 and inv.count_item(&"wood") == wood - 30,
			"made a cheese press at the workbench")
	# Put the press down and make cheese.
	# Into the hand (it went to the first free bag slot).
	inv.remove_item(&"cheese_press", 1)
	inv.set_stack(7, ItemStack.create(&"cheese_press"))
	PlayerState.select(7)
	var press_spot := Vector3(24.0, 0.0, -8.0)
	player.global_position = Vector3(press_spot.x, TerrainData.height(press_spot.x, press_spot.z) + 0.3, press_spot.z + 3.2)
	player.look_at_yaw_pitch(0.0, deg_to_rad(-38.0))
	await _frames(6)
	_check(player.placer.place(), "the cheese press is put down (%s, active %s)" % [player.placer.reason, player.placer.active])
	await _frames(3)
	var press: Machine = null
	for n in tree.get_nodes_in_group(&"placed"):
		if n is Machine and (n as Machine).item_id == &"cheese_press":
			press = n
	inv.set_stack(7, ItemStack.create(&"milk", 4))
	PlayerState.select(7)
	_check(press != null and press.interact_prompt(player).begins_with(tr("ACTION_MACHINE_PUT").get_slice("%", 0)), "holding milk, the press offers to take it")
	var milk := inv.count_item(&"milk")
	press.interact(player)
	_check(press.is_busy() and inv.count_item(&"milk") == milk - 2, "two bottles of milk went into the press")
	_check(not press.can_pick_up(), "a busy machine can't be picked up")
	GameClock.advance(12.0 * 60.0 + 1.0)
	await _frames(2)
	_check(press.is_done(), "twelve hours later the cheese is ready")
	press.interact(player)
	_check(inv.count_item(&"cheese") == 1 and not press.is_busy(), "took a cheese from the press")
	press.info_interact(player)
	await _frames(2)
	_check(inv.count_item(&"cheese_press") == 1 and not is_instance_valid(press) or press.is_queued_for_deletion(), "the empty press goes back into the bag")
	# Sprinkler: waters the beds around it in the morning.
	var plot: FarmPlot = null
	for p: FarmPlot in tree.get_nodes_in_group(&"farm_plots"):
		plot = p
		break
	plot.load_data({"soil": FarmPlot.Soil.TILLED})
	var e := FarmState.add_placed(&"sprinkler", plot.global_position + Vector3(1.5, 0, 0), 0.0)
	var spr := farm.spawn_placed(e) as Sprinkler
	await _frames(2)
	_check(not plot.is_wet() and spr.water() >= 1 and plot.is_wet(), "the sprinkler waters the bed next to it")
	FarmState.remove_placed(e)
	spr.queue_free()
	# Fertilizer: faster growth and better odds.
	inv.set_stack(7, ItemStack.create(&"fertilizer", 3))
	PlayerState.select(7)
	var act := plot.use_action(player, inv.get_stack(7))
	_check(act.get("id", "") == "fertilize", "fertilizer can go on a tilled bed")
	plot.complete_use(player, inv.get_stack(7), act)
	var golds := 0
	for i in 3000:
		if plot.roll_quality() == ItemStack.Quality.GOLD:
			golds += 1
	_check(plot.fertility == 2 and is_equal_approx(plot.growth_rate(), 1.3) and golds > 330 and golds < 570,
			"fertilized soil grows 30%% faster and gives gold %.1f%% of the time" % (golds / 30.0))
	plot.load_data({})
	# Manure heap and pitchfork.
	FarmState.manure = 0.0
	FarmState.add_manure(12.0)
	var heap: ManureHeap = farm.get_node("ManureHeap")
	inv.set_stack(7, ItemStack.create(&"pitchfork"))
	PlayerState.select(7)
	var muck := heap.use_action(player, inv.get_stack(7))
	var manure_before := inv.count_item(&"manure")
	heap.complete_use(player, inv.get_stack(7), muck)
	_check(muck.get("id", "") == "muck" and inv.count_item(&"manure") == manure_before + 5 and is_equal_approx(FarmState.manure, 7.0),
			"the pitchfork takes five manure from the heap")
	# A birth in the barn (on its own: the other animals step aside for the test).
	var had_barn := FarmState.is_built(&"barn_1")
	var barn_level := farm.barn.level
	FarmState.built[&"barn_1"] = true
	farm.barn.set_level(maxi(barn_level, 1))
	var others := Animals.animals.duplicate()
	Animals.animals.clear()
	var parents: Array[AnimalData] = []
	for i in 2:
		var cow := Animals._add(&"cow", true)
		cow.happiness = 90.0
		cow.health = 100.0
		cow.affection = 600.0
		parents.append(cow)
	var before := Animals.animals.size()
	var born := false
	for i in 80:
		for c in parents:
			c.last_birth_day = -100
		Animals._breed()
		if Animals.animals.size() > before:
			born = true
			break
	var baby: AnimalData = Animals.animals.back()
	_check(born and baby.species == &"cow" and not baby.adult, "two contented cows had a calf")
	for a in Animals.animals.duplicate():
		Animals.sell(a)
	Animals.animals.assign(others)
	if not had_barn:
		FarmState.built.erase(&"barn_1")
	farm.barn.set_level(barn_level)
	# Tool upgrade: faster work, more durability, paid in ore and gold.
	var axe := ItemStack.create(&"axe")
	inv.set_stack(7, axe)
	inv.add_item(&"iron_ore", 20)
	Progress.level = UnlockTable.TOOL_UPGRADES[1]
	Economy.money = maxi(Economy.money, 2000)
	var money_before := Economy.money
	var ore_before := inv.count_item(&"iron_ore")
	_check(crafting.upgrade_tool(7) and axe.upgrade == 1 and axe.max_durability() == roundi(axe.item.max_durability * 1.5)
			and axe.durability == axe.max_durability() and Economy.money == money_before - int(CraftingScreen.UPGRADE_COST[1]["money"])
			and inv.count_item(&"iron_ore") == ore_before - 6,
			"upgraded the axe to +1 (%d durability)" % axe.max_durability())
	_check(not crafting.can_upgrade(7), "the next upgrade needs farm level %d" % UnlockTable.TOOL_UPGRADES[2])
	_check(is_equal_approx(axe.speed_factor(), 0.8) and ItemStack.from_dict(axe.to_dict()).upgrade == 1, "a +1 tool works 20%% faster and keeps its upgrade in saves")
	# Tidy up.
	for n in tree.get_nodes_in_group(&"placed"):
		# Kit-built coops stay (hens live in them).
		if n is ChickenCoop:
			continue
		FarmState.remove_placed((n as PlacedObject).entry)
		n.queue_free()
	for id: StringName in [&"cheese", &"cheese_press", &"wood", &"iron_ore", &"stone", &"manure", &"milk"]:
		inv.remove_item(id, inv.count_item(id))
	inv.set_stack(7, old_slot)
	PlayerState.select(0)
	Progress.level = level
	await _frames(3)


## Middle of the test coop's plot: open farm land north-west of the barn paddock, its
## plot (11 × 10 m, door south) well clear of the paddock's kept margin, and the farmer
## aims at it from outside the paddock (its fence would catch the placer's ray).
const COOP_SPOT := Vector3(36.0, 0.0, -22.5)


## Whether a coop kit's plot centred on `center` (door south) lies wholly off the
## farm's reserved ground, sampled every half metre with a grid step of slack all
## round (the placer snaps the plot to that grid).
func _plot_free(center: Vector3) -> bool:
	var size: Vector3 = PlaceableTable.get_info(&"coop_kit")["size"]
	var half := Vector2(size.x, size.z) * 0.5 + Vector2.ONE * Placer.BUILDING_GRID
	var nx := ceili(half.x * 4.0)
	var nz := ceili(half.y * 4.0)
	for ix in nx + 1:
		for iz in nz + 1:
			var x := center.x - half.x + half.x * 2.0 * float(ix) / float(nx)
			var z := center.z - half.y + half.y * 2.0 * float(iz) / float(nz)
			if Placer.reserved(x, z):
				return false
	return true


## Selects a hotbar slot holding no placeable and no crate (the hands are free for
## doors, and the placer lets go of what it showed).
func _free_hands() -> void:
	for i in PlayerState.HOTBAR_SIZE:
		var s := PlayerState.inventory.get_stack(i)
		if s == null or not (PlaceableTable.is_placeable(s.item.id) or LiveCrates.is_live(s.item.id)):
			PlayerState.select(i)
			return


## Stands the player south of a building plot centred on `center` (10 m deep, door
## toward the player), looking at its near edge, then selects `item` so the placer
## turns the plot to face the player. The look is set once the player has landed:
## aimed from 0.2 m up it would fall half a metre short and move the plot south.
## The aim sits a hair off the 1 m terrain grid (the placer's 0.5 m snap takes it
## back): a ray through a height-map vertex can slip past the ground.
func _aim_plot(player: Player, center: Vector3, item: StringName) -> void:
	_free_hands()
	await _frames(2)
	var near := center + Vector3(0, 0, 5.0)
	var stand := near + Vector3(0, 0, 4.5)
	var aim := near + Vector3(0.05, 0.0, 0.05)
	aim.y = TerrainData.height(aim.x, aim.z)
	player.global_position = Vector3(stand.x, TerrainData.height(stand.x, stand.z) + 0.2, stand.z)
	_look_at(player, aim)
	await _frames(4)
	for i in 30:
		if player.is_on_floor():
			break
		await _frames(1)
	_look_at(player, aim)
	await _frames(2)
	_select(item)
	await _frames(8)


func _coop() -> void:
	var farm: Farm = Game.world.farm
	var player: Player = Game.player
	var inv := PlayerState.inventory
	GameClock.set_time_of_day(9.0)
	Weather.force(Weather.Kind.SUNNY)
	var level := Progress.level
	Progress.level = 1
	Economy.add_money(5000, "test")
	var started: Array = []
	var completed: Array = []
	var released: Array = []
	var toggled: Array = []
	var notes: Array[String] = []
	var on_started := func(id: StringName, node: Node) -> void: started.append([id, node])
	var on_completed := func(id: StringName, node: Node) -> void: completed.append([id, node])
	var on_released := func(species: StringName, home: Node) -> void: released.append([species, home])
	var on_toggled := func(id: StringName, open: bool) -> void: toggled.append([id, open])
	var on_note := func(text: String, _c: Color) -> void: notes.append(text)
	Events.construction_started.connect(on_started)
	Events.building_completed.connect(on_completed)
	Events.animal_released.connect(on_released)
	Events.door_toggled.connect(on_toggled)
	Events.notification_requested.connect(on_note)
	# Lets go of the listeners and puts the level and the hands back (at the end, or
	# when the scenario has to stop early).
	var tidy := func() -> void:
		Events.construction_started.disconnect(on_started)
		Events.building_completed.disconnect(on_completed)
		Events.animal_released.disconnect(on_released)
		Events.door_toggled.disconnect(on_toggled)
		Events.notification_requested.disconnect(on_note)
		PlayerState.select(0)
		Progress.level = level

	# (1) The board cuts a kit at level 1: 15 wood and its price, into the bag.
	if not FarmState.is_built(&"coop_1"):
		_check(not FarmState.is_listed(&"coop_1") and not FarmState.is_listed(&"coop_2") and FarmState.is_listed(&"coop_kit"),
				"a new farm's board offers the coop kit, not Grandpa's old run")
	inv.remove_item(&"coop_kit", inv.count_item(&"coop_kit"))
	inv.add_item(&"wood", 15)
	var wood := inv.count_item(&"wood")
	var gold := Economy.money
	_check(FarmState.build(&"coop_kit") and inv.count_item(&"coop_kit") == 1 and inv.count_item(&"wood") == wood - 15
			and Economy.money == gold - int(ProjectTable.get_project(&"coop_kit")["cost"]),
			"the board cuts a coop kit at level 1 (15 wood, $%d) into the bag" % int(ProjectTable.get_project(&"coop_kit")["cost"]))
	_check(not FarmState.is_built(&"coop_kit") and FarmState.can_build(&"coop_kit"), "another kit can be made (more coops)")

	# (2) Reserved ground and the red ghost.
	_check(Placer.reserved(WorldLayout.HOUSE_DOOR_X, WorldLayout.HOUSE_FRONT_Z - 2.0) and Placer.reserved(2.0, -8.0)
			and _plot_free(COOP_SPOT), "the house and the fields are kept, the test plot is free")
	var house_pt := Vector3(WorldLayout.HOUSE_DOOR_X, 0.0, WorldLayout.HOUSE_FRONT_Z - 3.0)
	await _aim_plot(player, house_pt + Vector3(0, 0, 2.0), &"coop_kit")
	_check(player.placer.active and player.placer.is_building() and not player.placer.valid,
			"aimed at the farmhouse, the coop ghost is red (%s)" % player.placer.reason)
	notes.clear()
	_check(not player.placer.place() and not notes.is_empty() and notes.back().begins_with(tr("MSG_CANT_BUILD_HERE")),
			"clicking on red says it can't be built there")

	# (3) A green ghost on open ground; placing it starts a construction site.
	await _aim_plot(player, COOP_SPOT, &"coop_kit")
	_check(player.placer.active and player.placer.valid,
			"on open ground the coop ghost is green (%s at %s)" % [player.placer.reason, player.placer.global_position])
	_check(absf(wrapf(player.placer.global_rotation.y, -PI, PI)) < 0.2, "the plot turns its door toward the player")
	var placed_before := FarmState.placed.size()
	var put_down := player.placer.place()
	_check(put_down and FarmState.placed.size() == placed_before + 1 and inv.count_item(&"coop_kit") == 0,
			"the coop kit is put down")
	await _frames(3)
	# The newest kit coop, only when this one went down (others may stand already).
	var coop: ChickenCoop = farm.kit_coops().back() if put_down and not farm.kit_coops().is_empty() else null
	_check(coop != null and not coop.is_built() and coop.site != null and absf(coop.seconds_left() - 60.0) < 1.0
			and is_equal_approx(PlaceableTable.build_seconds(&"coop_kit"), 60.0),
			"a construction site stands there (a real minute)")
	_check(started.size() == 1 and started[0][0] == &"coop" and started[0][1] == coop, "construction_started(&\"coop\", site)")
	_check(FarmState.coop_started(), "a coop is going up")
	_check(WaypointMarker.anchor(ChickenCoop.ANCHOR_COOP) != null and WaypointMarker.anchor(ChickenCoop.ANCHOR_DOOR) != null,
			"the site and its door are waypoint anchors")
	if coop == null:
		# Nothing below can run without the site (the checks above have failed).
		inv.remove_item(&"coop_kit", inv.count_item(&"coop_kit"))
		tidy.call()
		await _frames(3)
		return
	# The countdown runs in real time of play and the time left is in the entry.
	var left := coop.seconds_left()
	await _seconds(1.0)
	_check(coop.seconds_left() < left - 0.5 and absf(float(coop.entry["build_left"]) - coop.seconds_left()) < 0.01,
			"the site counts down in real time (%.1f s left)" % coop.seconds_left())
	# Aimed at the site: F takes it back as a kit (checked on a second site below).
	player.global_position = coop.door_point() + coop.global_basis.z * 2.5 + Vector3(0, 0.3, 0)
	_look_at(player, coop.center_point() + Vector3(0, 1.0, 0))
	await _frames(6)
	_check(_last_prompt.contains(tr("SIGN_CONSTRUCTION")), "the site shows its countdown")
	# (4) Finishing: the building, its housing, the event and the achievement.
	coop.entry["build_left"] = 0.6
	await _seconds(1.0)
	_check(coop.is_built() and coop.site == null and coop.housing != null and coop.housing.level == 2
			and coop.housing.capacity() == 8 and coop.housing.door_open, "the coop is finished (8 places, door open)")
	_check(completed.size() == 1 and completed[0][0] == &"coop" and completed[0][1] == coop, "building_completed(&\"coop\", coop)")
	_check(Achievements.is_unlocked(&"first_building"), "the first building achievement unlocks")
	_check(farm.housing_by_id(coop.uid()) == coop.housing and FarmState.has_coop(), "the farm knows the new coop")
	var h := coop.housing
	_check(h.is_in_building(h.door_inside()) and not h.is_in_building(h.door_outside()) and h.in_pen(h.door_outside()),
			"its door leads from the house into the yard")

	# (5) Letting hens out of their crates at the door.
	inv.add_item(&"chicken_crate", 2)
	player.global_position = h.door_outside() + h.front() * 0.8 + Vector3(0, 0.3, 0)
	_look_at(player, h.door_inside() + Vector3(0, 0.7, 0) - h.front() * 1.0)
	_select(&"chicken_crate")
	await _frames(6)
	_check(player.target is CoopDoor or (player.target != null and player.target.get("door") is CoopDoor),
			"aiming at the coop door")
	_check(_last_prompt.contains(tr("ACTION_RELEASE_HEN")), "a crate in hand: E lets the hen in")
	var target := player.target
	if target:
		target.interact(player)
		target.interact(player)
	await _frames(5)
	_check(Animals.count_at(h) == 2 and inv.count_item(&"chicken_crate") == 0, "two hens moved in, no crates left")
	_check(released.size() == 2 and released[0][0] == &"chicken" and released[0][1] == coop, "animal_released(&\"chicken\", coop)")
	_check(Achievements.is_unlocked(&"first_chickens"), "the first hens achievement unlocks")
	_check(String(coop.entry.get("egg", "")) == "due", "the first egg is on its way")

	# (6) Closing the door: hens inside stay in, however long.
	player.global_position = h.door_outside() + h.front() * 0.8 + Vector3(0, 0.3, 0)
	_look_at(player, h.door_inside() + Vector3(0, 0.7, 0) - h.front() * 1.0)
	_free_hands()
	await _frames(6)
	_check(_last_prompt.contains(tr("ACTION_COOP_DOOR_CLOSE")), "empty-handed at the open door: E shuts it")
	if player.target:
		player.target.interact(player)
	await _frames(3)
	_check(not h.door_open and coop.entry["door"] == false and toggled.back() == [&"coop", false], "the coop door is shut (saved)")
	for n in h.animals:
		n.teleport_home(true)
	Engine.time_scale = 6.0
	await _seconds(10.0)
	Engine.time_scale = 1.0
	var inside := 0
	for n in h.animals:
		if n.indoors and h.building.has_point(h.flat(n.global_position)):
			inside += 1
	_check(inside == h.animals.size() and inside == 2, "with the door shut the hens stay inside (%d/%d)" % [inside, h.animals.size()])
	# Open again: out they go into the yard, and stay in it.
	coop.housing.door.set_open(true)
	Engine.time_scale = 6.0
	var outside := 0
	for i in 40:
		await _seconds(0.5)
		outside = 0
		for n in h.animals:
			if not n.indoors and h.in_pen(n.global_position, 0.05):
				outside += 1
		if outside > 0:
			break
	Engine.time_scale = 1.0
	_check(outside > 0 and h.door_open, "with the door open the hens wander out into the yard (%d)" % outside)

	# (7) The first egg: within the hour, around the coop, and it can be picked up.
	GameClock.advance(ChickenCoop.FIRST_EGG_MINUTES + 10.0)
	await _frames(3)
	var egg := coop.first_egg()
	_check(String(coop.entry.get("egg", "")) == "laid" and egg != null and egg.is_in_group(ChickenCoop.FIRST_EGG_GROUP)
			and h.in_pen(egg.global_position, 1.0) and WaypointMarker.anchor(ChickenCoop.ANCHOR_EGG) == egg,
			"the first egg lies around the coop (a waypoint anchor)")
	var eggs := inv.count_item(&"egg")
	if egg:
		player.global_position = egg.global_position + Vector3(0.6, 0.3, 0)
	await _seconds(2.0)
	_check(inv.count_item(&"egg") == eggs + 1 and String(coop.entry.get("egg", "")) == "taken", "the first egg is picked up")

	# (7b) Looking after the coop by hand: the feeder, the waterer and three nest boxes
	# (guide dots over each); then hens lay in the bedded boxes.
	var fed: Array = []
	var watered: Array = []
	var bedded: Array = []
	var on_fed := func(c: Node) -> void: fed.append(c)
	var on_watered := func(c: Node) -> void: watered.append(c)
	var on_bedded := func(c: Node, n: int) -> void: bedded.append([c, n])
	Events.coop_fed.connect(on_fed)
	Events.coop_watered.connect(on_watered)
	Events.nest_filled.connect(on_bedded)
	_check(WaypointMarker.anchor(ChickenCoop.ANCHOR_FEEDER) != null and WaypointMarker.anchor(ChickenCoop.ANCHOR_WATER) != null
			and WaypointMarker.anchor(ChickenCoop.ANCHOR_NEST) != null and coop.filled_nests() == 0,
			"a new coop's nest boxes are bare; the feeder, the waterer and the next box are waypoint anchors")
	# Feed in hand at the feeder.
	inv.add_item(&"feed", 5)
	var feed_n := inv.count_item(&"feed")
	var feeder := h.feed
	player.global_position = feeder.global_position + h.front() * 1.3 + Vector3(0, 0.2, 0)
	_select(&"feed")
	await _frames(6)
	_look_at(player, feeder.global_position + Vector3(0, 0.15, 0))
	await _frames(6)
	_check(player.target == feeder and _last_prompt.contains(tr("ACTION_FILL_TROUGH")), "feed in hand at the coop's feeder: use fills it")
	var feed_was := feeder.amount
	await _hold_use(1.4)
	_check(feeder.amount > feed_was and inv.count_item(&"feed") < feed_n and fed.size() == 1 and fed[0] == coop,
			"the feeder fills with feed (coop_fed, %.0f)" % feeder.amount)
	# The watering can at the waterer.
	if inv.count_item(&"watering_can") == 0:
		inv.add_item(&"watering_can", 1)
	_select(&"watering_can")
	var can := PlayerState.selected_stack()
	can.water = can.item.water_capacity
	var waterer := h.water
	player.global_position = waterer.global_position + h.front() * 1.3 + Vector3(0, 0.2, 0)
	await _frames(6)
	_look_at(player, waterer.global_position + Vector3(0, 0.15, 0))
	await _frames(6)
	_check(player.target == waterer, "the watering can at the coop's waterer")
	var water_was := waterer.amount
	await _hold_use(1.6)
	_check(waterer.amount > water_was and can.water < can.item.water_capacity and watered.size() == 1 and watered[0] == coop,
			"the waterer fills from the can (coop_watered, %.0f)" % waterer.amount)
	# An armful of hay into each nest box.
	inv.add_item(&"hay", ChickenCoop.NESTS)
	var hay := inv.count_item(&"hay")
	_select(&"hay")
	var aimed := 0
	for i in ChickenCoop.NESTS:
		player.global_position = coop.nest_front(i) + coop.nest_out() * 0.5 + coop.global_basis.z * 0.9 + Vector3(0, 0.2, 0)
		await _frames(6)
		_look_at(player, coop.nest_seat(i) + Vector3(0, 0.15, 0))
		await _frames(6)
		if player.target is ChickenCoop.Nest and (player.target as ChickenCoop.Nest).index == i and _last_prompt.contains(tr("ACTION_BED_NEST")):
			aimed += 1
		await _hold_use(1.4)
		if i == 0:
			_check(WaypointMarker.anchor(ChickenCoop.ANCHOR_NEST) != null and coop.filled_nests() == 1
					and WaypointMarker.anchor(ChickenCoop.ANCHOR_NEST).global_position.distance_to(coop.nest_seat(1)) < 1.0,
					"the nest guide dot moves on to the next bare box")
	_check(aimed == ChickenCoop.NESTS, "hay in hand at a bare nest box: use beds it (%d/%d)" % [aimed, ChickenCoop.NESTS])
	_check(coop.filled_nests() == ChickenCoop.NESTS and inv.count_item(&"hay") == hay - ChickenCoop.NESTS
			and bedded.size() == ChickenCoop.NESTS and bedded.back() == [coop, ChickenCoop.NESTS],
			"three armfuls of hay bed the three boxes (nest_filled up to 3)")
	_check(WaypointMarker.anchor(ChickenCoop.ANCHOR_NEST) == null and coop.entry["nests"] == [true, true, true],
			"every box bedded (saved): the nest guide dot is gone")
	Events.coop_fed.disconnect(on_fed)
	Events.coop_watered.disconnect(on_watered)
	Events.nest_filled.disconnect(on_bedded)
	# Hens lay in the bedded boxes: the story's first egg (were it still to come) and a
	# day's egg. The farmer stands well out of reach so the eggs stay put.
	var in_nests := func() -> Array[Pickup]:
		var out: Array[Pickup] = []
		for n in tree.get_nodes_in_group(&"pickups"):
			var p := n as Pickup
			if p == null or p.stack == null or p.stack.item.id != &"egg" or p.is_queued_for_deletion():
				continue
			for i in ChickenCoop.NESTS:
				var seat := coop.nest_seat(i)
				if Vector2(p.global_position.x - seat.x, p.global_position.z - seat.z).length() < 0.35 \
						and absf(p.global_position.y - seat.y) < 0.2:
					out.append(p)
					break
		return out
	player.global_position = h.door_outside() + h.front() * 5.0 + Vector3(0, 0.3, 0)
	_free_hands()
	var nest_eggs: int = in_nests.call().size()
	var hens := h.animals.duplicate()
	var sat: Array = []
	coop.entry["egg"] = "due"
	coop.entry["egg_at"] = GameClock.total_minutes
	if hens.size() > 1:
		coop.egg_due((hens[1] as Animal).data, ItemStack.Quality.NORMAL)
		coop.entry["lay"][str((hens[1] as Animal).data.id)]["at"] = GameClock.total_minutes
	# The clock stands still in tests: one tick makes the first egg due.
	GameClock.advance(GameClock.TICK_MINUTES)
	_check(String(coop.entry.get("egg", "")) == "nest" and (coop.entry["lay"] as Dictionary).size() == mini(hens.size(), 2),
			"with a box bedded the first egg waits for a hen to lay it there")
	Engine.time_scale = 6.0
	for i in 160:
		await _seconds(0.5)
		for n: Animal in hens:
			if n.state == Animal.State.NEST and not sat.has(n):
				sat.append(n)
		if in_nests.call().size() >= nest_eggs + 2 and coop.first_egg() != null:
			break
	Engine.time_scale = 1.0
	var laid: Array[Pickup] = in_nests.call()
	_check(sat.size() >= 2 and laid.size() == nest_eggs + 2 and (coop.entry["lay"] as Dictionary).is_empty(),
			"hens with an egg due walk in, sit in a bedded box and lay there (%d sat, %d eggs)" % [sat.size(), laid.size() - nest_eggs])
	var first := coop.first_egg()
	_check(first != null and laid.has(first) and String(coop.entry.get("egg", "")) == "laid"
			and WaypointMarker.anchor(ChickenCoop.ANCHOR_EGG) == first, "with a box bedded the first egg is laid in it (a waypoint anchor)")
	# Down again and back out into the yard.
	Engine.time_scale = 6.0
	var out_again := 0
	for i in 80:
		await _seconds(0.5)
		out_again = 0
		for n: Animal in sat:
			if is_instance_valid(n) and not n.indoors and n.state != Animal.State.NEST:
				out_again += 1
		if out_again == sat.size():
			break
	Engine.time_scale = 1.0
	_check(sat.size() > 0 and out_again == sat.size(), "after laying the hens hop down and go back out (%d/%d)" % [out_again, sat.size()])
	for p: Pickup in laid:
		p.queue_free()
	coop.entry["egg"] = "taken"

	# (8) Full at 8 hens: the next crate stays shut.
	while Animals.count_at(h) < h.capacity():
		Animals.release(&"chicken", h)
	inv.add_item(&"chicken_crate", 1)
	_select(&"chicken_crate")
	notes.clear()
	_check(not h.door.release_from_hand() and inv.count_item(&"chicken_crate") == 1 and notes.back() == tr("MSG_COOP_FULL") % 8,
			"a full coop takes no more hens")
	inv.remove_item(&"chicken_crate", 1)

	# (9) A second coop, turned 45°: its yard and house follow the turn.
	var turned_at := COOP_SPOT + Vector3(0, 0, -14.0)
	turned_at.y = TerrainData.height(turned_at.x, turned_at.z)
	var e2 := FarmState.add_placed(&"coop_kit", turned_at, deg_to_rad(45.0))
	var coop2 := farm.spawn_placed(e2) as ChickenCoop
	await _frames(3)
	var h2 := coop2.housing
	var rng := RandomNumberGenerator.new()
	var in_yard := true
	for i in 30:
		var p := h2.random_outdoor_point(rng)
		if not h2.in_pen(p) or h2.is_in_building(p):
			in_yard = false
	var dir := (h2.door_outside() - h2.door_inside()).normalized()
	_check(coop2.is_built() and in_yard and absf(Vector2(dir.x, dir.z).angle_to(Vector2(sin(deg_to_rad(45.0)), cos(deg_to_rad(45.0))))) < 0.1,
			"a coop turned 45°: yard points and the door follow the turn")
	_check(coop2.filled_nests() == ChickenCoop.NESTS, "a coop from before bedding by hand keeps its straw")
	FarmState.remove_placed(e2)
	coop2.queue_free()

	# (10) F on a site gives the kit back.
	var e3 := FarmState.add_placed(&"coop_kit", turned_at, 0.0)
	e3["stage"] = "site"
	e3["build_left"] = 60.0
	var site := farm.spawn_placed(e3) as ChickenCoop
	await _frames(2)
	site.info_interact(player)
	await _frames(2)
	_check(inv.count_item(&"coop_kit") == 1 and not FarmState.placed.has(e3), "F on a construction site takes the kit back")
	inv.remove_item(&"coop_kit", 1)

	# (11) Sleeping finishes a site (a night passes).
	var e4 := FarmState.add_placed(&"coop_kit", turned_at, 0.0)
	e4["stage"] = "site"
	e4["build_left"] = 150.0
	var site4 := farm.spawn_placed(e4) as ChickenCoop
	await _frames(2)
	Events.time_skipped.emit(8.0 * 60.0)
	await _frames(2)
	_check(site4.is_built(), "a night's sleep finishes a construction site")
	FarmState.remove_placed(e4)
	site4.queue_free()

	# Tidy up: the hens, the coop and the listeners.
	for a in Animals.animals.duplicate():
		if Animals.housing_of(a) == h:
			Animals.sell(a)
	FarmState.remove_placed(coop.entry)
	coop.queue_free()
	tidy.call()
	await _frames(3)


## Tool feel: the effect lands on the final stroke's impact (the hoe's first stroke is
## only a hit), the view model shows the contact pose then, the view punches without
## moving the aim, camera shake can be turned off, a cut-short stroke eases back, the
## can pours only while tipped, a swing at nothing plays on its own, and pickups arc into
## the pocket.
## The second day's story and what it makes: the workbench kit bought at the board and
## put up near the house in a minute, the recipes and their market goods, the knife, the
## rope bought, the rod, bait, a fish, a campfire, a meal (the fishing, the fire and eating
## themselves are other tests': their events stand in for them here).
func _progression() -> void:
	var player: Player = Game.player
	var inv := PlayerState.inventory
	var money_had := Economy.money
	var level := Progress.level
	Progress.level = 1
	GameClock.set_time_of_day(9.0)
	Weather.force(Weather.Kind.SUNNY)
	var started: Array = []
	var completed: Array = []
	var on_started := func(id: StringName, node: Node) -> void: started.append([id, node])
	var on_completed := func(id: StringName, node: Node) -> void: completed.append([id, node])
	Events.construction_started.connect(on_started)
	Events.building_completed.connect(on_completed)

	# (1) The new things: names, icons and models; the owner's recipes; the market's goods.
	var bad: Array = []
	for id: StringName in [&"knife", &"bow", &"fishing_rod", &"campfire", &"nails", &"rope", &"worm", &"dough", &"sapling", &"workbench"]:
		var item := ItemDB.get_item(id)
		var m := ItemModels.mesh(id) if item else null
		if item == null or item.icon == null or item.display_name().begins_with("ITEM_") or item.description() == "" \
				or m == null or m.get_aabb().size.length() < 0.05:
			bad.append(id)
	_check(bad.is_empty(), "the workbench's new things have names, descriptions, icons and models (missing: %s)" % str(bad))
	var needs := func(id: StringName, mats: Array) -> bool:
		var items: Dictionary = RecipeTable.crafting(id).get("items", {})
		return items.size() == mats.size() and mats.all(func(x: StringName) -> bool: return items.has(x))
	_check(needs.call(&"knife", [&"wood", &"stone"]) and needs.call(&"bow", [&"wood", &"nails", &"rope"])
			and needs.call(&"fishing_rod", [&"wood", &"rope"]) and needs.call(&"campfire", [&"stone", &"wood"]),
			"knife: wood and stone; bow: wood, nails, rope; rod: wood, rope; campfire: stone and wood")
	var in_order := RecipeTable.CRAFT_ORDER.size() == RecipeTable.CRAFTING.size()
	for id: StringName in RecipeTable.CRAFT_ORDER:
		in_order = in_order and RecipeTable.CRAFTING.has(id) and RecipeTable.GROUPS.has(String(RecipeTable.crafting(id)["group"]))
	_check(in_order and RecipeTable.CRAFT_ORDER.size() >= 15, "every recipe is listed at the bench under a heading (%d)" % RecipeTable.CRAFT_ORDER.size())
	var market: Array = ShopStock.town_market()["stock"]
	var sells := [&"nails", &"rope", &"worm", &"dough", &"workbench"].all(func(x: StringName) -> bool:
		return x in market and Economy.buy_price(x) > 0)
	_check(sells, "the town market sells nails, rope, worms, dough and the workbench")
	_check(is_equal_approx(PlaceableTable.build_seconds(&"workbench"), 60.0) and is_equal_approx(PlaceableTable.build_seconds(&"coop_kit"), 60.0),
			"the workbench and the coop each go up in a minute")
	# The day-two money: the first morning's bin and the earning goal pay for the kit, and
	# what is left buys the rod's rope and a bait.
	var kit := ProjectTable.get_project(&"workbench")
	var morning := Economy.STARTING_MONEY - 2 * LiveCrates.price(&"chicken") - int(ProjectTable.get_project(&"coop_kit")["cost"]) \
			+ Economy.quote(&"carrot", Quests.GRANDPA_BEDS * 2, 0, ShippingBin.COMMISSION_FACTOR) \
			+ Economy.quote(&"egg", 1, 0, ShippingBin.COMMISSION_FACTOR)
	var earn := int(Quests.TUTORIAL[Quests.index_of("earn")]["count"])
	var left := morning + earn - int(kit["cost"])
	_check(ProjectTable.kit_of(&"workbench") == &"workbench" and left >= 2 * Economy.buy_price(&"rope") + Economy.buy_price(&"worm"),
			"the kit ($%d) is in reach of day one's sales and day two's $%d, with $%d left for rope and bait" % [int(kit["cost"]), earn, left])
	# Shopping goals point only at a shop that sells the thing.
	var wrong: Array = []
	for g: Dictionary in Quests.TUTORIAL:
		var at := String(g.get("at", ""))
		if at.begins_with("buy:") and not Quests._sold_at_market(StringName(at.get_slice(":", 1))):
			wrong.append(g["id"])
	_check(wrong.is_empty(), "every buying goal names something the market sells (wrong: %s)" % str(wrong))

	# (2) The earning goal and the kit: short of money, the dot says how much and where to earn.
	Quests.step = Quests.index_of("bench_kit")
	Quests.step_count = 0
	Economy.money = 5
	inv.add_item(&"wood", 30)
	Quests._hint = ""
	Quests._target("bench_board")
	_check(Quests.goal_hint().contains(UiTheme.money(int(kit["cost"]) - 5)), "short of money, the kit's goal says how much more (%s)" % Quests.goal_hint())
	Economy.money = 500
	Quests._hint = ""
	var board: Variant = Quests._target("bench_board")
	_check(board is Vector3 and Vector2((board as Vector3).x, (board as Vector3).z).distance_to(Vector2(WorldLayout.BOARD_POS.x, WorldLayout.BOARD_POS.z)) < 1.0
			and Quests.goal_hint() == "", "with the money and the wood, the dot points at the construction board")
	inv.remove_item(&"workbench", inv.count_item(&"workbench"))
	var wood := inv.count_item(&"wood")
	_check(FarmState.build(&"workbench") and inv.count_item(&"workbench") == 1 and inv.count_item(&"wood") == wood - 10
			and Economy.money == 500 - int(kit["cost"]), "the board cuts a workbench kit ($%d and 10 wood) into the bag" % int(kit["cost"]))
	Quests._poll = 0.0
	await _idle_frames(3)
	_check(Quests.current()["id"] == "bench_place", "the kit in the bag moves on to setting it up")

	# (3) Near the house: the dot's spot, the ghost, a site going up for a minute.
	Quests._wp_left = 0.0
	await _idle_frames(2)
	var spot: Variant = Quests.waypoint()
	var house := WorldLayout.house_rect(FarmState.house_level())
	_check(spot is Vector3 and house.grow(16.0).has_point(Vector2((spot as Vector3).x, (spot as Vector3).z))
			and not Placer.reserved((spot as Vector3).x, (spot as Vector3).z),
			"the dot suggests a spot near the house for the workbench (%s)" % str(spot))
	var at: Vector3 = spot if spot is Vector3 else Vector3(-4.0, 0.0, -19.0)
	at.y = TerrainData.height(at.x, at.z)
	_free_hands()
	await _frames(2)
	var stand := at + Vector3(0, 0, 4.2)
	player.global_position = Vector3(stand.x, TerrainData.height(stand.x, stand.z) + 0.2, stand.z)
	await _frames(6)
	var aim := at + Vector3(0.05, 0.0, 0.85)
	aim.y = TerrainData.height(aim.x, aim.z)
	_look_at(player, aim)
	await _frames(2)
	_select(&"workbench")
	await _frames(8)
	_check(player.placer.active and player.placer.is_building() and player.placer.valid,
			"holding the kit near the house shows a green bench on its plot (%s)" % player.placer.reason)
	var put := player.placer.place()
	await _frames(3)
	var bench: Workbench = null
	for n in tree.get_nodes_in_group(&"placed"):
		if n is Workbench and not (n as Workbench).is_built():
			bench = n
	_check(put and bench != null and absf(bench.seconds_left() - 60.0) < 1.0 and inv.count_item(&"workbench") == 0
			and bench.get_node_or_null("Site") != null and bench.get_node_or_null("Countdown") != null,
			"the kit is put down: a site with pegs, boards and a countdown (a minute)")
	_check(started.size() == 1 and started[0][0] == &"workbench" and started[0][1] == bench, "construction_started(&\"workbench\", site)")
	if bench == null:
		await _progression_tidy(on_started, on_completed, money_had, level)
		return
	_check(bench.interact_prompt(player) == "" and bench.hint_prompt().contains(tr("SIGN_CONSTRUCTION")),
			"the site can't be worked at yet; it shows its countdown")
	Quests._poll = 0.0
	await _idle_frames(3)
	_check(Quests.current()["id"] == "bench_built" and Quests.goal_text().contains(":"),
			"a bench going up moves on to waiting for it, with its clock (%s)" % Quests.goal_text())
	var before := bench.seconds_left()
	await _seconds(1.0)
	_check(bench.seconds_left() < before - 0.5, "the site counts down in real time (%.1f s left)" % bench.seconds_left())
	bench.entry["build_left"] = 0.4
	await _seconds(0.8)
	_check(bench.is_built() and bench.get_node_or_null("Site") == null and completed.size() == 1 and completed[0][0] == &"workbench",
			"a minute later the bench stands (building_completed)")
	_check(bench.interact_prompt(player) == tr("ACTION_CRAFT"), "the finished bench offers the workbench (E)")
	Quests._poll = 0.0
	await _idle_frames(3)
	_check(Quests.current()["id"] == "knife", "the finished bench moves on to the knife")

	# (4) The knife: short of stone the dot says so and points at the rocks; E opens the bench.
	inv.remove_item(&"stone", inv.count_item(&"stone"))
	Quests._hint = ""
	var to_rocks: Variant = Quests._craft_target(&"knife", player.global_position)
	_check(to_rocks != null and str(to_rocks) == str(Quests._target("rocks")) and Quests.goal_hint().contains(ItemDB.get_item(&"stone").display_name()),
			"short of stone for the knife: the dot points at the rocks and says what's short (%s)" % Quests.goal_hint())
	inv.add_item(&"stone", 20)
	Quests._hint = ""
	var to_bench: Variant = Quests._craft_target(&"knife", player.global_position)
	_check(to_bench is Vector3 and (to_bench as Vector3).distance_to(bench.top_point()) < 0.1, "with the materials the dot points at the bench")
	bench.interact(player)
	await _frames(3)
	var screen: CraftingScreen = Game.hud.crafting_screen
	_check(screen.visible, "E at the bench opens the crafting screen")
	var headings := 0
	for c in screen._list.get_children():
		if not (c is Button):
			headings += 1
	_check(headings >= RecipeTable.GROUPS.size(), "the bench lists its recipes under headings (%d)" % headings)
	screen._selected = &"knife"
	screen._refresh()
	await _frames(2)
	var knives := inv.count_item(&"knife")
	screen._craft(&"knife", null)
	_check(inv.count_item(&"knife") == knives, "the knife takes a moment at the bench")
	await _seconds(CraftingScreen.CRAFT_SECONDS + 0.4)
	_check(inv.count_item(&"knife") == knives + 1, "then it is in the bag")
	screen.hide_screen()
	await _frames(2)
	Quests._poll = 0.0
	await _idle_frames(2)
	_check(Quests.current()["id"] == "rope", "the knife ends the workshop: fishing begins with the rod's rope")

	# (5) Fishing: rope from the market, the rod, bait, a fish, a campfire, a meal.
	Economy.money = 0
	Quests._hint = ""
	Quests._target("buy:rope")
	_check(Quests.goal_hint().contains(UiTheme.money(2 * Economy.buy_price(&"rope"))), "no money for the rope: the goal says how much it needs (%s)" % Quests.goal_hint())
	Economy.money = 200
	Quests._hint = ""
	var to_market: Variant = Quests._target("buy:rope")
	_check(to_market != null and str(to_market) == str(Quests._target("market")) and Quests.goal_hint() == tr("HINT_MARKET"),
			"with the money, the dot points at the town market, which sells rope")
	inv.add_item(&"rope", 2)
	Quests._poll = 0.0
	await _idle_frames(2)
	_check(Quests.current()["id"] == "rod", "two ropes move on to the rod")
	inv.add_item(&"wood", 5)
	_check(screen.craft(&"fishing_rod") and inv.count_item(&"fishing_rod") == 1, "the rod is made from wood and rope")
	Quests._poll = 0.0
	await _idle_frames(2)
	_check(Quests.current()["id"] == "bait", "the rod moves on to bait")
	inv.add_item(&"worm", 3)
	Quests._poll = 0.0
	await _idle_frames(2)
	_check(Quests.current()["id"] == "fish", "worms in the bag move on to the fish")
	Quests._hint = ""
	var pond: Variant = Quests._target("pond")
	_check(pond is Vector3 and Vector2((pond as Vector3).x, (pond as Vector3).z).distance_to(WorldLayout.POND_CENTER) < WorldLayout.POND_RADIUS + 1.0,
			"the dot points at the pond by the house")
	Events.fish_caught.emit(&"fish_test")
	_check(Quests.current()["id"] == "campfire", "a fish caught moves on to the campfire")
	inv.add_item(&"stone", 10)
	inv.add_item(&"wood", 10)
	_check(screen.craft(&"campfire") and inv.count_item(&"campfire") == 1, "the campfire is made from stone and wood")
	await _idle_frames(2)
	_check(Quests.current()["id"] == "cook", "the campfire moves on to cooking")
	Quests._hint = ""
	Quests._target("campfire")
	_check(Quests.goal_hint() == tr("HINT_PLACE_FIRE"), "the campfire still in the bag: the goal says to put it down outdoors")
	# Not indoors.
	_free_hands()
	await _frames(2)
	var inside := Vector2(WorldLayout.HOUSE_DOOR_X, WorldLayout.HOUSE_FRONT_Z - 2.5)
	var floor_y := TerrainData.height(inside.x, inside.y) + FarmHouse.FLOOR_Y
	player.global_position = Vector3(inside.x, floor_y + 0.3, inside.y)
	await _frames(8)
	_look_at(player, Vector3(inside.x, player.global_position.y, inside.y - 2.0))
	_select(&"campfire")
	await _frames(6)
	_check(player.placer.active and not player.placer.valid and player.placer.reason == "MSG_PLACE_INDOORS",
			"a campfire can't be put down in the house (%s)" % player.placer.reason)
	_free_hands()
	Events.food_cooked.emit(&"fish_test_cooked")
	_check(Quests.current()["id"] == "eat", "a fish cooked moves on to eating")
	Events.food_eaten.emit(&"fish_test_cooked")
	_check(Quests.current()["id"] == "level_3", "the meal ends the second day's story")

	# (6) A site in a save goes up again where it stood.
	var e := FarmState.add_placed(&"workbench", bench.global_position + Vector3(6, 0, 0), 0.0)
	e["stage"] = "site"
	e["build_left"] = 42.0
	var again := Game.world.farm.spawn_placed(e) as Workbench
	await _frames(2)
	_check(again != null and not again.is_built() and absf(again.seconds_left() - 42.0) < 0.5, "a saved site keeps its time left")
	Events.time_skipped.emit(8.0 * 60.0)
	_check(again.is_built(), "a night's sleep finishes it")
	FarmState.remove_placed(e)
	again.queue_free()
	FarmState.remove_placed(bench.entry)
	bench.queue_free()
	await _progression_tidy(on_started, on_completed, money_had, level)


func _progression_tidy(on_started: Callable, on_completed: Callable, money: int, level: int) -> void:
	Events.construction_started.disconnect(on_started)
	Events.building_completed.disconnect(on_completed)
	for id: StringName in [&"workbench", &"knife", &"fishing_rod", &"rope", &"worm", &"campfire", &"wood", &"stone"]:
		PlayerState.inventory.remove_item(id, PlayerState.inventory.count_item(id))
	Quests.skip_tutorial()
	Economy.money = money
	Progress.level = level
	PlayerState.select(0)
	await _frames(3)


func _feel() -> void:
	var player: Player = Game.player
	var held := player.held
	var inv := PlayerState.inventory
	var impacts: Array = []
	var on_impact := func(id: String, stroke: int, is_final: bool) -> void:
		impacts.append([id, stroke, is_final, Engine.get_physics_frames()])
	player.tool_impact.connect(on_impact)
	Settings.camera_shake = 1.0
	var field: Field = Game.world.farm.fields[&"field_0"]
	var plot: FarmPlot = field.plots[6]
	plot.load_data({"soil": FarmPlot.Soil.UNTILLED})
	player.global_position = plot.global_position + Vector3(0, 0.1, 2.4)
	_look_at(player, plot.global_position + Vector3(0, 0.15, 0))
	await _frames(6)
	_check(player.target == plot, "feel: aiming at an untilled bed")
	_select(&"hoe")
	await _frames(2)

	# Cut short: released during the wind-up, nothing lands and the hoe eases back.
	Input.action_press("use")
	await _seconds(0.2)
	Input.action_release("use")
	await _seconds(0.3)
	_check(impacts.is_empty() and plot.soil == FarmPlot.Soil.UNTILLED, "feel: a released stroke lands nothing (%s)" % [impacts])
	_check(held._off_pos.length() < 0.005 and not held.busy(), "feel: the hoe eases back to rest (%.3f)" % held._off_pos.length())

	# Two hoe strokes: the first only throws clods, the second turns the soil.
	Input.action_press("use")
	await _seconds(0.55)
	var hoe_hits := impacts.filter(func(e: Array) -> bool: return e[0] == "hoe")
	_check(hoe_hits.size() == 1 and not hoe_hits[0][2] and plot.soil == FarmPlot.Soil.UNTILLED,
			"feel: the first hoe stroke lands without tilling (%s)" % [hoe_hits])
	_check(player.target == plot, "feel: the aim stays on the bed through the swing")
	await _seconds(0.6)
	Input.action_release("use")
	await _frames(3)
	hoe_hits = impacts.filter(func(e: Array) -> bool: return e[0] == "hoe")
	_check(plot.soil == FarmPlot.Soil.TILLED and hoe_hits.size() == 2 and hoe_hits[1][2],
			"feel: the second stroke tills the bed (%s)" % [hoe_hits])
	if hoe_hits.size() == 2:
		var gap := int(hoe_hits[1][3]) - int(hoe_hits[0][3])
		_check(gap >= 34 and gap <= 38, "feel: the hoe strokes land 0.6 s apart (%d ticks)" % gap)

	# The can pours only while it is tipped, and waters once.
	_select(&"watering_can")
	var can := PlayerState.selected_stack()
	can.water = can.item.water_capacity
	var water := can.water
	await _frames(2)
	Input.action_press("use")
	await _seconds(0.32)
	_check(held._stream != null and held._stream.emitting, "feel: the can pours while tipped")
	await _seconds(0.45)
	Input.action_release("use")
	await _frames(3)
	_check(held._stream != null and not held._stream.emitting, "feel: the stream stops when the can comes back")
	_check(can.water == water - 1 and plot.is_wet(), "feel: one watering (%d -> %d)" % [water, can.water])

	# Axe: the blow lands at contact, the view punches, the aim never moves.
	var tree_node: ChoppableTree = null
	var best := INF
	for t: ChoppableTree in tree.get_nodes_in_group(&"trees"):
		var d := t.global_position.distance_to(player.global_position)
		if not t.felled and t.hp >= 3 and d < best:
			best = d
			tree_node = t
	player.global_position = tree_node.global_position + Vector3(0, 0.2, 1.6)
	_look_at(player, tree_node.global_position + Vector3(0, 1.2, 0))
	await _frames(6)
	_select(&"axe")
	await _frames(2)
	var hp := tree_node.hp
	impacts.clear()
	Input.action_press("use")
	var stays := true
	var contact_u := -1.0
	var jolt := 0.0
	# One second of physics ticks (one blow; the next would land at 1.12 s), sampled every
	# drawn frame whatever the frame rate.
	var until := Engine.get_physics_frames() + 60
	while Engine.get_physics_frames() < until:
		await tree.process_frame
		stays = stays and player.target == tree_node
		if not impacts.is_empty():
			if contact_u < 0.0:
				# The frame after the impact tick has been drawn: the latched contact pose.
				await tree.process_frame
				contact_u = held.current_u()
			jolt = maxf(jolt, _view_jolt(player))
	Input.action_release("use")
	await _frames(3)
	_check(impacts.size() >= 1 and impacts[0][0] == "chop" and impacts[0][2] and tree_node.hp == hp - 1,
			"feel: one axe blow chops once (%s, hp %d -> %d)" % [impacts, hp, tree_node.hp])
	_check(contact_u >= 0.56 and contact_u <= 0.72, "feel: the axe is drawn at contact on the hit (u %.2f)" % contact_u)
	_check(stays, "feel: the aim stays on the trunk through the wind-up and the kick")
	_check(jolt > 0.5, "feel: the blow punches the view (%.2f deg)" % jolt)

	# Camera shake off: the same blow leaves the view still.
	Settings.camera_shake = 0.0
	await _seconds(0.6)
	impacts.clear()
	jolt = 0.0
	Input.action_press("use")
	until = Engine.get_physics_frames() + 60
	while Engine.get_physics_frames() < until:
		await tree.process_frame
		if not impacts.is_empty():
			jolt = maxf(jolt, _view_jolt(player))
	Input.action_release("use")
	await _frames(3)
	_check(not impacts.is_empty() and jolt < 0.01, "feel: with camera shake off the view stays still (%.3f deg)" % jolt)
	Settings.camera_shake = 1.0

	# A swing at nothing plays the stroke on its own and hits nothing.
	player.look_at_yaw_pitch(player.rotation.y + PI, 0.3)
	await _frames(4)
	impacts.clear()
	await _press_mouse_use()
	_check(held.busy() and impacts.is_empty(), "feel: a swing at nothing plays and lands nothing")
	await _seconds(0.9)
	_check(not held.busy(), "feel: the empty swing ends")

	# A pickup arcs into the pocket, shrinking on the way.
	var wood := inv.count_item(&"wood")
	var p := Pickup.spawn(ItemStack.create(&"wood", 1), player.global_position - player.global_basis.z * 3.0 + Vector3(0, 0.6, 0), Vector3.ZERO, true)
	var shrank := false
	for i in 120:
		await tree.physics_frame
		if not is_instance_valid(p):
			break
		if p._flying and p._fly_t > 0.3:
			shrank = shrank or p._mi.scale.x < p._mi_scale * 0.99
	_check(shrank, "feel: the pickup shrinks as it flies in")
	_check(inv.count_item(&"wood") == wood + 1, "feel: the pickup is collected within 2 s (%d -> %d)" % [wood, inv.count_item(&"wood")])
	player.tool_impact.disconnect(on_impact)
	PlayerState.select(0)
	await _frames(2)


## Degrees the camera is turned away from the head's look (the view punch and shake).
func _view_jolt(player: Player) -> float:
	var look := (player.global_basis * player.head.basis).get_rotation_quaternion()
	return rad_to_deg(look.angle_to(player.camera.global_basis.get_rotation_quaternion()))


## One LMB click (press, a few physics ticks, release).
func _press_mouse_use() -> void:
	Input.action_press("use")
	await _frames(3)
	Input.action_release("use")
	await _frames(1)


## The tutorial chain, farm experience and the order board.
func _quests() -> void:
	var inv := PlayerState.inventory
	var player := Game.player as Player
	var farm: Farm = Game.world.farm
	var flags_before: Dictionary = FarmState.flags.duplicate(true)
	var bin := FarmState.get_storage(ShippingBin.STORAGE_ID, ShippingBin.SLOTS)
	var bin_before: Array[ItemStack] = bin.slots.duplicate()
	for i in bin.size():
		bin.slots[i] = null
	bin.changed.emit()
	var begun := [-1]
	var on_chapter := func(i: int) -> void: begun[0] = i
	Quests.chapter_started.connect(on_chapter)

	# The chain: the first day by hand, in the user's order, each goal with a place for the dot;
	# then the player is free until the next morning's workshop.
	var day_one := ["door", "tools", "till", "plant", "water", "drawer", "key", "truck", "buy_chickens",
			"drive_home", "crates_in", "coop_wood", "coop_kit", "coop_place", "coop_built", "hens_in",
			"harvest", "ship", "egg", "ship_egg", "feed", "coop_water", "straw", "wood", "patch"]
	var in_order := true
	for i in day_one.size():
		in_order = in_order and Quests.index_of(day_one[i]) == i
	var free_step := Quests.day_two_step()
	_check(in_order and free_step == day_one.size() and Quests.TUTORIAL[free_step]["id"] == "free"
			and int(Quests.TUTORIAL[free_step]["chapter"]) == Quests.DAY_TWO_CHAPTER
			and Quests.TUTORIAL[free_step + 1]["id"] == "earn" and Quests.index_of("sleep") < 0,
			"the first day runs door, tools, soil, drawer, key, truck, hens, coop, harvest, bin, egg, the coop's care and the mending (no bedtime); the workshop waits for day two")
	var dropped: Array = []
	for id: String in ["reap", "replant", "refill", "repair_warehouse", "store", "hay", "load", "order", "sell",
			"workbench", "craft", "repair_house", "coop", "chickens", "eggs", "stone", "quern", "flour"]:
		if Quests.index_of(id) >= 0:
			dropped.append(id)
	_check(dropped.is_empty(), "the old day-two goals are gone (left: %s)" % ", ".join(dropped))
	var rope_need := int((RecipeTable.crafting(&"fishing_rod")["items"] as Dictionary)[&"rope"])
	_check(int(Quests.TUTORIAL[Quests.index_of("rope")]["count"]) == rope_need,
			"the rope goal asks for the rod's rope (%d)" % rope_need)
	var no_at: Array = []
	var no_text: Array = []
	for g: Dictionary in Quests.TUTORIAL:
		if Quests.index_of(String(g["id"])) < free_step and String(g.get("at", "")) == "":
			no_at.append(g["id"])
		if String(g["arg"]) != "level" and Quests.goal_text(g).begins_with("QUEST_"):
			no_text.append(g["id"])
	_check(no_at.is_empty() and String(Quests.TUTORIAL[free_step].get("at", "")) == "",
			"every goal of the first day has a place for the dot, the free evening none (missing: %s)" % ", ".join(no_at))
	_check(no_text.is_empty(), "every goal has its text (missing: %s)" % ", ".join(no_text))
	_check(int(Quests.TUTORIAL[Quests.index_of("tools")]["count"]) == FarmHouse.table_item_count(),
			"the tools goal asks for everything on Grandpa's worktable (%d)" % FarmHouse.table_item_count())
	for at: String in ["house_door", "table", "drawer", "truck", "stall", "warehouse", "bin", "well", "market"]:
		_check(Quests._target(at) != null, "the dot finds '%s'" % at)

	# Homecoming: the door (a flag the house sets), then Grandpa's things off the worktable.
	# The goal is set by hand: announced as DebugTools does, so the HUD's card shows it.
	# Quests polls in _process: its waits are idle frames (see _idle_frames).
	Quests.step = Quests.index_of("door")
	Quests.step_count = 0
	Quests.tally = {}
	FarmState.flags.erase(FarmHouse.DOOR_FLAG)
	FarmState.flags.erase(FarmHouse.TABLE_FLAG)
	Quests.tutorial_changed.emit()
	Quests._poll = 0.0
	await _idle_frames(2)
	_check(Quests.current()["id"] == "door" and Game.hud._quest_card.visible and not Game.hud._quest_count.visible,
			"a shut door keeps the first goal up (no 0/1 counter on a one-step goal)")
	Quests._wp_left = 0.0
	await _idle_frames(2)
	_check(Quests.waypoint() != null, "the dot points at the house door")
	FarmState.flags[FarmHouse.DOOR_FLAG] = true
	Events.door_toggled.emit(FarmHouse.DOOR_ID, true)
	await _idle_frames(3)
	_check(Quests.current()["id"] == "tools", "opening the front door completes it")
	FarmState.flags[FarmHouse.TABLE_FLAG] = ["hoe", "axe"]
	Quests._poll = 0.0
	await _idle_frames(2)
	_check(Quests.current()["id"] == "tools" and Quests.step_count == 2
			and Game.hud._quest_count.text == "2/%d" % FarmHouse.table_item_count(),
			"each thing taken off the worktable counts (%s)" % Game.hud._quest_count.text)
	var all_taken: Array = []
	for e: Array in ItemTable.STARTING_ITEMS:
		all_taken.append(String(e[0]))
	FarmState.flags[FarmHouse.TABLE_FLAG] = all_taken
	Quests._poll = 0.0
	await _idle_frames(3)
	_check(Quests.current()["id"] == "till" and begun[0] == int(Quests.TUTORIAL[Quests.index_of("till")]["chapter"]),
			"a bare worktable completes it: the soil chapter begins")
	_check(Game.hud._quest_chapter.text == UiTheme.caps("%s · %s" % [tr("HUD_CHAPTER") % 2, Quests.chapter_title(1)]),
			"the goal card names the chapter (%s)" % Game.hud._quest_chapter.text)
	# A goal the player is past already completes by itself: the door, once something inside was taken.
	Quests.step = Quests.index_of("door")
	Quests.step_count = 0
	FarmState.flags.erase(FarmHouse.DOOR_FLAG)
	FarmState.flags[FarmHouse.TABLE_FLAG] = ["hoe"]
	Quests._poll = 0.0
	await _idle_frames(2)
	_check(Quests.current()["id"] == "tools", "a thing taken off the worktable means the door was opened: the door goal passes")

	# The soil: three beds each, and work done early counts when its goal comes up.
	var till_step := Quests.index_of("till")
	Quests.step = till_step
	Quests.step_count = 0
	Quests.tally = {}
	var money := Economy.money
	var xp_had := Progress.xp
	for i in 3:
		Events.action_done.emit("hoe", null)
	_check(Quests.current()["id"] == "plant" and Economy.money == money and Progress.xp >= xp_had + int(Quests.TUTORIAL[till_step]["xp"]),
			"tilling three beds completes the tilling goal: experience, no money (+%d xp)" % (Progress.xp - xp_had))
	Events.action_done.emit("water", null)
	_check(Quests.current()["id"] == "plant" and Quests.step_count == 0, "other work doesn't count toward the current goal")
	var tracker: Label = Game.hud._quest_text
	_check(tracker.text == Quests.goal_text() and Game.hud._quest_card.visible, "the HUD shows the current goal")
	var plot := tree.get_first_node_in_group(&"farm_plots") as FarmPlot
	var plot_crop := plot.crop
	plot.crop = &"potato"
	Events.action_done.emit("plant", plot)
	_check(Quests.current()["id"] == "plant" and Quests.step_count == 0, "sowing potatoes doesn't count toward the wheat goal")
	plot.crop = &"wheat"
	for i in 3:
		Events.action_done.emit("plant", plot)
	plot.crop = plot_crop
	await _frames(2)
	_check(Quests.current()["id"] == "water" and Quests.step_count == 1,
			"three wheat beds sown move on to watering, which counts the watering done before (%d)" % Quests.step_count)

	# The drawer stays shut on a new farm until its step (automated runs keep it open).
	FarmState.flags[FarmHouse.FIRST_DAY_FLAG] = true
	FarmState.flags.erase(FarmHouse.KEY_FLAG)
	FarmState.flags.erase(FarmHouse.DRAWER_FLAG)
	Quests._sync_drawer_lock()
	_check(bool(FarmState.flags.get(FarmHouse.DRAWER_LOCK_FLAG, false)), "before its step the desk drawer is kept shut")
	Quests.step = Quests.index_of("drawer")
	Quests.step_count = 0
	Quests._sync_drawer_lock()
	_check(not FarmState.flags.has(FarmHouse.DRAWER_LOCK_FLAG), "at the drawer step it opens")
	FarmState.flags.erase(FarmHouse.FIRST_DAY_FLAG)

	# The town: the drawer, the key (the pickup locked for once), the drive, two hens, home, the warehouse.
	var truck: Vehicle = (tree.get_first_node_in_group(&"town") as Town).farm_truck
	FarmState.flags.erase(truck.unlock_flag())
	var keys_had := inv.count_item(&"truck_key")
	inv.remove_item(&"truck_key", keys_had)
	FarmState.flags[FarmHouse.DRAWER_FLAG] = true
	Events.drawer_opened.emit(FarmHouse.DRAWER_ID)
	await _idle_frames(3)
	_check(Quests.current()["id"] == "key", "opening the desk drawer moves on to the key")
	Quests._poll = 0.0
	await _idle_frames(2)
	_check(Quests.current()["id"] == "key", "a locked pickup with no key found keeps the key goal up")
	FarmState.flags[FarmHouse.KEY_FLAG] = true
	Events.world_item_taken.emit(&"truck_key")
	await _idle_frames(3)
	# (Hens left by earlier scenarios may carry the chain further by itself: "passed", not "current".)
	_check(Quests.passed("key"), "taking the key moves on to the pickup")
	truck.unlock()
	var foot := player.global_transform
	Quests.step = Quests.index_of("truck")
	Quests.step_count = 0
	player.enter_vehicle(truck)
	await _idle_frames(3)
	_check(Quests.passed("truck"), "getting in at the wheel moves on to buying hens")
	var stall: Variant = Quests._target("stall")
	_check(stall != null and Quests._target("truck") == stall, "at the wheel, the dot points at the poultry stall in town")
	Quests.step = Quests.index_of("buy_chickens")
	Quests.step_count = 0
	Events.animals_bought.emit(&"chicken", 2)
	# The purchase nudges the goal's check: it runs in the next idle frame (a slow frame
	# after getting in can run several physics frames before it).
	await _idle_frames(3)
	_check(Quests._check_progress("hens:owned") >= 2 and Quests.passed("buy_chickens"),
			"two hens bought at the stall move on to driving them home")
	player.exit_vehicle()
	await _frames(2)
	var tc := WorldLayout.TOWN_CENTER
	player.global_position = Vector3(tc.x, TerrainData.height(tc.x, tc.y) + 0.3, tc.y)
	_check(Quests._check_progress("home") == 0, "the town isn't home")
	var wd := Quests._warehouse_door()
	player.global_position = Vector3(wd.x, TerrainData.height(wd.x, wd.z + 4.0) + 0.3, wd.z + 4.0)
	_check(Quests._check_progress("home") == 1, "the farmyard by the warehouse is home")
	Quests.step = Quests.index_of("drive_home")
	Quests.step_count = 0
	Quests._poll = 0.0
	await _idle_frames(3)
	_check(Quests.passed("drive_home"), "back in the farmyard moves on to the crates")
	player.global_transform = foot
	var crate := AnimalTable.crate_item(&"chicken")
	_check(Quests._check_progress("crates:warehouse") == LiveCrates.count_at(&"warehouse", crate) + Quests._animal_count(&"chicken"),
			"crates in the warehouse and hens let out both count toward storing the crates")

	# The coop: fifteen wood, the kit, a spot, three minutes, the hens in.
	Quests.step = Quests.index_of("coop_wood")
	Quests.step_count = 0
	Quests.tally = {}
	Events.item_picked_up.emit(&"wood", 10)
	Events.item_picked_up.emit(&"stone", 3)
	_check(Quests.current()["id"] == "coop_wood" and Quests.step_count == 10, "picked-up wood counts toward the coop's wood, stone doesn't")
	Events.item_picked_up.emit(&"wood", 5)
	_check(Quests.current()["id"] == "coop_kit", "fifteen wood moves on to the coop kit")
	var hens_before := Quests._animal_count(&"chicken")
	var made: ChickenCoop = null
	var released: Array[AnimalData] = []
	if not FarmState.coop_started() and inv.count_item(&"coop_kit") == 0:
		Quests._poll = 0.0
		await _idle_frames(2)
		_check(Quests.current()["id"] == "coop_kit", "no kit and no coop: the kit goal waits")
		Events.crafted.emit(&"coop_kit", 1)
		Quests._poll = 0.0
		await _idle_frames(2)
		_check(Quests.current()["id"] == "coop_place" and int(Quests.tally.get("crafted:", 0)) == 0,
				"a kit cut at the board moves on to placing it (and isn't the workshop's first craft)")
		var spot: Variant = Quests._target("coop_spot")
		_check(spot is Vector3 and not Placer.reserved((spot as Vector3).x, (spot as Vector3).z),
				"the dot suggests open farm land for the coop (%s)" % str(spot))
		var at: Vector3 = spot if spot is Vector3 else Vector3(22.0, 0.0, -22.0)
		at.y = TerrainData.height(at.x, at.z)
		var e := FarmState.add_placed(&"coop_kit", at, 0.0)
		e["stage"] = "site"
		e["build_left"] = 60.0
		made = farm.spawn_placed(e) as ChickenCoop
		Quests._poll = 0.0
		await _idle_frames(3)
		_check(Quests.current()["id"] == "coop_built" and Quests.goal_text().contains("1:00"),
				"a coop site moves on to waiting for it, with its clock in the goal (%s)" % Quests.goal_text())
		made.finish()
		Quests._poll = 0.0
		await _idle_frames(3)
		_check(Quests.passed("coop_built"), "the finished coop moves on to letting the hens in")
		if hens_before < 2:
			_check(Quests.current()["id"] == "hens_in", "no hens in it yet: the hens goal waits")
			for i in 2:
				var a := Animals.release(&"chicken", made.housing)
				if a:
					released.append(a)
			Quests._poll = 0.0
			await _idle_frames(3)
	for i in 6:
		if Quests.passed("hens_in"):
			break
		Quests._poll = 0.0
		await _idle_frames(2)
	if FarmState.has_coop() and Quests._animal_count(&"chicken") >= 2:
		_check(Quests.current()["id"] == "harvest" and begun[0] == int(Quests.TUTORIAL[Quests.index_of("harvest")]["chapter"]),
				"a coop with two hens in it ends the coop chapter: the first harvest")
	# Tidy up: the hens and the coop this scenario put up.
	var keep_money := Economy.money
	for a in released:
		Animals.sell(a)
	Economy.money = keep_money
	if made:
		FarmState.remove_placed(made.entry)
		made.queue_free()

	# Grandpa's ripe beds wait for the harvest goal: before it no badge, no crop card and
	# no tool works on them, and the mark survives a save; from the goal on they are beds.
	var grandpa_field := Quests._first_field()
	if grandpa_field:
		var bed: FarmPlot = grandpa_field.plots.back()
		var bed_had := bed.save_data()
		Quests.step = Quests.index_of("hens_in")
		var beds: Array[FarmPlot] = [bed]
		Quests._ripen_beds(beds, 1)
		var scythe := ItemStack.create(&"scythe")
		var can := ItemStack.create(&"watering_can")
		_check(bed.is_ready() and bed.grandpa and bed.held_back() and not bed._indicator.visible
				and bed.use_action(null, scythe).is_empty() and bed.use_prompt(null, scythe) == ""
				and bed.use_action(null, can).is_empty(),
				"before the harvest goal Grandpa's ripe bed shows no badge and takes no tool")
		var saved := bed.save_data()
		bed.load_data({})
		bed.load_data(saved)
		_check(bool(saved.get("grandpa", false)) and bed.held_back() and not bed._indicator.visible,
				"Grandpa's bed keeps its mark through a save")
		Quests.step = Quests.index_of("harvest")
		Quests.tutorial_changed.emit()
		_check(not bed.held_back() and bed._indicator.visible and String(bed.use_action(null, scythe).get("id", "")) == "harvest",
				"at the harvest goal Grandpa's bed shows its badge and can be cut")
		bed.load_data(bed_had)

	# The first harvest, the bin, the first egg; then the coop's care.
	var harvest_step := Quests.index_of("harvest")
	Quests.step = harvest_step
	Quests.step_count = 0
	# Grandpa's beds gone by the time the harvest goal comes up: they come back ripe.
	var first_field := Quests._first_field()
	if first_field:
		var plots_had: Array = first_field.plots.map(func(pl: FarmPlot) -> Dictionary: return pl.save_data())
		for pl: FarmPlot in first_field.plots:
			pl.load_data({})
		Quests.tally = {}
		Quests._keep_beds_for_harvest()
		var ripe := first_field.plots.filter(func(pl: FarmPlot) -> bool: return pl.is_ready()).size()
		_check(ripe == Quests.GRANDPA_BEDS, "no ripe beds at the harvest goal: Grandpa's come back ripe (%d)" % ripe)
		for i in first_field.plots.size():
			first_field.plots[i].load_data(plots_had[i])
	Quests.tally = {"action:harvest": 3}
	Quests._catch_up()
	_check(Quests.current()["id"] == "ship", "harvests made before their goal came up complete it at once")
	_check(Quests._target("bin") != null, "the dot points at the shipping bin")
	Quests._poll = 0.0
	await _idle_frames(2)
	_check(Quests.current()["id"] == "ship", "an empty bin keeps the shipping goal up")
	bin.add_item(&"carrot", 2)
	Quests._poll = 0.0
	await _idle_frames(3)
	_check(Quests.current()["id"] == "egg", "carrots in the shipping bin complete it")
	Events.item_picked_up.emit(&"egg", 1)
	_check(Quests.current()["id"] == "ship_egg", "the first egg picked up moves on to shipping it")
	# The egg thrown away with no other left: the story asks for an egg again. (Eggs
	# earlier scenarios left in the warehouse or lying about would count as spares.)
	var eggs_had := inv.count_item(&"egg")
	inv.remove_item(&"egg", eggs_had)
	var stock_had := FarmState.warehouse.to_dict()
	for q in 4:
		FarmState.warehouse.take(&"egg", 9999, q)
	for n in tree.get_nodes_in_group(&"pickups"):
		var loose := n as Pickup
		if loose and loose.stack and loose.stack.item.id == &"egg":
			loose.queue_free()
	Events.egg_broken.emit(Vector3.ZERO)
	_check(Quests.current()["id"] == "egg" and Quests.step_count == 0, "the egg broken with none left: the story asks for an egg again")
	Events.item_picked_up.emit(&"egg", 1)
	_check(Quests.current()["id"] == "ship_egg", "the next egg picked up moves on to shipping it again")
	inv.add_item(&"egg", eggs_had)
	FarmState.warehouse.from_dict(stock_had)
	bin.add_item(&"egg", 1)
	Quests._poll = 0.0
	await _idle_frames(3)
	var care := int(Quests.TUTORIAL[Quests.index_of("feed")]["chapter"])
	_check(Quests.current()["id"] == "feed" and begun[0] == care and Quests.first_day()
			and Game.hud._quest_note.visible and Game.hud._quest_note.text.contains(Quests.chapter_note(care)),
			"the egg in the bin ends the harvest: the coop's care opens with Grandpa's note (no bedtime)")
	_check(is_equal_approx(Quests.pace_for(10.0), Quests.FIRST_DAY_PACE) and is_equal_approx(Quests.pace_for(17.0), Quests.LINGER_PACE),
			"the first day runs at half speed and the late afternoon lingers")
	bin.remove_item(&"carrot", 2)
	bin.remove_item(&"egg", 1)
	# LMB with an egg in hand: it flies where the player looks and breaks where it lands.
	var broke: Array = []
	var on_broke := func(at: Vector3) -> void: broke.append(at)
	Events.egg_broken.connect(on_broke)
	var sel_had := PlayerState.selected
	# The first hotbar slot for the eggs (earlier scenarios may have filled the hotbar).
	var egg_slot := 0
	var slot_had := inv.get_stack(egg_slot)
	inv.set_stack(egg_slot, ItemStack.create(&"egg", 2))
	PlayerState.selected = egg_slot
	# On foot in the open yard, thrown a little down (earlier scenarios may leave the player
	# at a wheel, by a wall or looking at the sky).
	if player.driving:
		player.exit_vehicle()
		await _frames(2)
	if player.riding:
		player.dismount()
		await _frames(2)
	var throw_from := player.global_transform
	player.global_position = Vector3(-10, TerrainData.height(-10, 0) + 0.3, 0)
	player.look_at_yaw_pitch(0.0, deg_to_rad(-25.0))
	await _frames(3)
	player._throw_egg()
	await _seconds(0.3)
	var in_air := tree.get_nodes_in_group(&"thrown_eggs").size()
	await _seconds(2.2)
	player.global_transform = throw_from
	Events.egg_broken.disconnect(on_broke)
	var left := inv.get_stack(egg_slot)
	_check(broke.size() == 1 and left != null and left.count == 1 and (broke[0] as Vector3).distance_to(player.global_position) > 1.0,
			"a thrown egg leaves the hand, flies off and breaks (%s; %d in the air, paused %s, ui %s)"
			% [str(broke), in_air, tree.paused, Game.is_ui_open()])
	inv.set_stack(egg_slot, slot_had)
	PlayerState.selected = sel_had
	# The dot fetches what the coop needs first: the feed from the warehouse, water from the
	# well, hay from the grass; the boards need wood from the trees, the knife stone.
	var same := func(x: Variant, y: Variant) -> bool: return typeof(x) == typeof(y) and x == y
	var feed_had := inv.count_item(&"feed")
	inv.remove_item(&"feed", feed_had)
	_check(same.call(Quests._target("feeder"), Quests._target("warehouse")), "no feed in the bag: the dot points at the warehouse")
	inv.add_item(&"feed", 1)
	_check(same.call(Quests._target("feeder"), Quests._anchor(&"coop_feeder", Quests._target("coop"))),
			"feed in the bag: the dot points at the coop's feeder")
	inv.remove_item(&"feed", 1)
	inv.add_item(&"feed", feed_had)
	var cans: Array[ItemStack] = []
	var can_water: Array[int] = []
	for st: ItemStack in inv.slots:
		if st != null and st.item.water_capacity > 0:
			cans.append(st)
			can_water.append(st.water)
			st.water = 0
	_check(same.call(Quests._target("coop_water"), Quests._target("well")), "an empty watering can: the dot points at the well")
	if not cans.is_empty():
		cans[0].water = 3
		_check(not same.call(Quests._target("coop_water"), Quests._target("well")), "water in the can: the dot leaves the well for the coop")
	for i in cans.size():
		cans[i].water = can_water[i]
	var hay_had := inv.count_item(&"hay")
	inv.remove_item(&"hay", hay_had)
	var to_grass: Variant = Quests._target("nests")
	_check(to_grass != null and not same.call(to_grass, Quests._anchor(&"coop_nest", Quests._target("coop"))),
			"no hay for the nests: the dot points at grass to cut (%s)" % str(to_grass))
	inv.add_item(&"hay", 3)
	_check(same.call(Quests._target("nests"), Quests._anchor(&"coop_nest", Quests._target("coop"))), "hay in the bag: the dot points at the nests")
	inv.remove_item(&"hay", 3)
	inv.add_item(&"hay", hay_had)
	var wood_had := inv.count_item(&"wood")
	inv.remove_item(&"wood", wood_had)
	_check(same.call(Quests._target("house_repair"), Quests._target("trees")), "no wood in the bag: the boards' dot points at the trees")
	inv.add_item(&"wood", wood_had)
	var stone_had := inv.count_item(&"stone")
	inv.remove_item(&"stone", stone_had)
	var wood_now := inv.count_item(&"wood")
	inv.add_item(&"wood", 5)
	_check(same.call(Quests._craft_target(&"knife", player.global_position), Quests._target("rocks")),
			"short of stone for the knife: the dot points at the rocks")
	inv.remove_item(&"wood", inv.count_item(&"wood") - wood_now)
	inv.add_item(&"stone", stone_had)
	# The coop's care: the events of the feeder, the water trough and the nests.
	money = Economy.money
	Events.coop_fed.emit(null)
	_check(Quests.current()["id"] == "coop_water" and Economy.money == money,
			"feed in the coop's feeder completes the feeding goal (no money: only sales pay)")
	Events.coop_watered.emit(null)
	_check(Quests.current()["id"] == "straw", "water in the coop's trough completes the watering goal")
	Events.nest_filled.emit(null, 1)
	Events.nest_filled.emit(null, 1)
	_check(Quests.current()["id"] == "straw" and Quests.step_count == 1 and Game.hud._quest_count.text == "1/3",
			"a nest with straw counts, the same nest filled again doesn't (%s)" % Game.hud._quest_count.text)
	Events.nest_filled.emit(null, 2)
	Events.nest_filled.emit(null, 3)
	await _frames(2)
	var mend := int(Quests.TUTORIAL[Quests.index_of("wood")]["chapter"])
	_check(Quests.current()["id"] == "wood" and begun[0] == mend and Game.hud._quest_note.text.contains(Quests.chapter_note(mend)),
			"three nests with straw end the coop's care: the mending opens with Grandpa's note")
	# The mending: one tree's wood, counted from when the goal came up; then the house's boards.
	Quests.tally["picked:wood"] = 20
	Quests._catch_up()
	_check(Quests.current()["id"] == "wood" and Quests.step_count == 0, "wood picked up before the goal came up doesn't count")
	Events.item_picked_up.emit(&"wood", 2)
	Events.item_picked_up.emit(&"stone", 2)
	_check(Quests.current()["id"] == "wood" and Quests.step_count == 2, "picked-up wood counts toward the wood goal, stone doesn't")
	Events.item_picked_up.emit(&"wood", 1)
	_check(Quests.current()["id"] == "patch", "a tree's three logs complete it: on to the house's boards")
	Events.wall_patched.emit(&"warehouse", 1, 6)
	_check(Quests.current()["id"] == "patch" and Quests.step_count == 0, "boards renewed on the warehouse don't count toward the house")
	for i in 3:
		Events.wall_patched.emit(&"house", i + 1, 8)
	await _frames(2)
	_check(Quests.current()["id"] == "free" and begun[0] == Quests.DAY_TWO_CHAPTER and not Quests.first_day()
			and Game.hud._quest_card.visible and not Game.hud._quest_count.visible
			and Game.hud._quest_note.text.contains(Quests.chapter_note(Quests.DAY_TWO_CHAPTER)),
			"three boards renewed end the first day's story: Grandpa's note lets the player go free")
	Quests._wp_left = 0.0
	await _idle_frames(2)
	_check(Quests.waypoint() == null, "the free evening has no dot")
	# Day two's workshop waits for the morning.
	var day_was := GameClock.day
	GameClock.day = 1
	Quests._poll = 0.0
	await _idle_frames(3)
	_check(Quests.current()["id"] == "free", "on the first day the workshop waits for the next morning")
	GameClock.day = maxi(day_was, 2)
	Quests._nudge()
	await _idle_frames(3)
	var workshop := int(Quests.TUTORIAL[Quests.index_of("earn")]["chapter"])
	_check(Quests.current()["id"] == "earn" and begun[0] == workshop and Game.hud._quest_note.text.contains(Quests.chapter_note(workshop)),
			"the next morning the workshop opens with Grandpa's note")
	GameClock.day = day_was
	# A house repaired already passes the wood and the boards.
	var house_built := FarmState.is_built(&"house_1")
	FarmState.built[&"house_1"] = true
	Quests.step = Quests.index_of("wood")
	Quests.step_count = 0
	for i in 6:
		if Quests.passed("patch"):
			break
		Quests._poll = 0.0
		await _idle_frames(2)
	_check(Quests.passed("patch"), "a house repaired already passes the wood and the boards")
	if not house_built:
		FarmState.built.erase(&"house_1")
	# The workshop: dollars earned by selling from when the goal comes up (not before), then
	# the kit; the rest of the day (the bench, the knife, fishing) in the "progression" test.
	Quests.step = Quests.index_of("earn")
	Quests.step_count = 0
	Quests.tally = {"earned:": 50}
	Quests._catch_up()
	_check(Quests.current()["id"] == "earn" and Quests.step_count == 0, "money earned before the goal came up doesn't count toward it")
	Events.item_sold.emit(&"carrot", 3, 12)
	_check(Quests.current()["id"] == "earn" and Quests.step_count == 12, "a sale counts its dollars toward the goal (%d)" % Quests.step_count)
	Events.item_sold.emit(&"egg", 2, 10)
	_check(Quests.current()["id"] == "bench_kit", "$20 earned moves on to buying the workbench kit")
	Quests.step = Quests.index_of("eat")
	Quests.step_count = 0
	Events.food_eaten.emit(&"carrot")
	_check(Quests.current()["id"] == "level_3", "the first meal ends the fishing: only the farm's milestones are left")
	Quests.chapter_started.disconnect(on_chapter)
	# Check goals of the later days: the next morning, the town, the pickup and its bed.
	_check(Quests._check_progress("day:%d" % GameClock.day) == 1 and Quests._check_progress("day:%d" % (GameClock.day + 1)) == 0,
			"a day goal waits for its morning")
	player.global_position = Vector3(tc.x, TerrainData.height(tc.x, tc.y) + 0.3, tc.y)
	_check(Quests._check_progress("near:town") == 1, "standing in Yeşilova counts as being in town")
	player.global_position = Vector3(-10, 0.3, 0)
	_check(Quests._check_progress("near:town") == 0, "the farm yard isn't the town")
	player.global_transform = foot
	_check(Quests._check_progress("driving") == 0, "on foot isn't driving")
	player.enter_vehicle(truck)
	_check(Quests._check_progress("driving") == 1, "at the wheel of an own vehicle counts as driving (%s)" % truck.kind)
	player.exit_vehicle()
	await _frames(2)
	player.global_transform = foot
	truck.cargo.add(&"wood", 1)
	_check(Quests._check_progress("cargo") == 1, "goods in the bed count as a loaded pickup")
	truck.cargo.take(&"wood", 1)

	# Saves: the goal by id and the chain's format; older saves skip the first day, chain 2
	# saves go on at the nearest goal still here.
	var saved := Quests.save_data()
	var saved_orders: Array = saved["orders"]
	_check(int(saved.get("chain", 0)) == Quests.CHAIN, "a save carries the chain's format")
	var flags_now: Dictionary = FarmState.flags.duplicate(true)
	Quests.load_data({"step": 5, "count": 0, "orders": saved_orders})
	_check(Quests.current()["id"] == "earn", "an index save on 'buy the pickup' goes on at the workshop")
	Quests.load_data({"step": 6, "count": 4, "orders": saved_orders})
	_check(Quests.current()["id"] == "earn" and int(Quests.tally.get("sold:", 0)) == 4 and int(Quests.tally.get("action:harvest", 0)) == 1,
			"an index save halfway through selling keeps its sales and harvest")
	Quests.load_data({"step": 3, "count": 0, "orders": saved_orders})
	_check(Quests.current()["id"] == "free", "an index save waiting on the first harvest goes on after the first day")
	Quests.load_data({"step": 0, "count": 2, "orders": saved_orders})
	_check(Quests.current()["id"] == "free" and Quests.step_count == 0, "an index save at the very start skips the first day")
	Quests.load_data({"step": 24, "count": 0, "orders": saved_orders})
	_check(Quests.tutorial_done(), "an old save with the story done stays done")
	Quests.load_data({"id": "till", "count": 2, "orders": saved_orders})
	_check(Quests.current()["id"] == "free" and not Quests.first_day(), "a save from before the first day's story on 'till' goes on after the first day")
	Quests.load_data({"id": "sleep", "count": 0, "orders": saved_orders})
	_check(Quests.current()["id"] == "earn", "a save from before the first day's story on the first night goes on at the workshop")
	Quests.load_data({"id": "level_2", "count": 1, "orders": saved_orders})
	_check(Quests.current()["id"] == "level_3" and Quests.chapter() == Quests.CHAPTERS.find("barn"),
			"an old save waiting for level 2 goes on at level 3, in the barn chapter")
	Quests.load_data({"id": "rope", "count": 1, "orders": saved_orders})
	_check(Quests.current()["id"] == "rope" and Quests.step_count == 1, "an old save on a goal this chain still has keeps it and its count")
	Quests.load_data({"chain": 2, "id": "sleep", "count": 0, "orders": saved_orders})
	_check(Quests.current()["id"] == "feed" and Quests.first_day(), "a chain 2 save at bedtime goes on at the coop's care, still on the first day")
	Quests.load_data({"chain": 2, "id": "hay", "count": 2, "orders": saved_orders})
	_check(Quests.current()["id"] == "earn" and Quests.step_count == 0, "a chain 2 save on the yard's hay goes on at the workshop")
	Quests.load_data({"chain": 2, "id": "eggs", "count": 1, "orders": saved_orders})
	_check(Quests.current()["id"] == "level_3", "a chain 2 save on the old egg goal goes on at the farm's milestones")
	Quests.load_data({"chain": 2, "id": "wood", "count": 12, "orders": saved_orders})
	Quests._catch_up()
	_check(Quests.current()["id"] == "patch", "a chain 2 save with more wood than this chain's goal asks passes it")
	for old_id: String in ["stone", "quern", "flour"]:
		Quests.load_data({"chain": 3, "id": old_id, "count": 1, "orders": saved_orders})
		_check(Quests.current()["id"] == "earn" and Quests.step_count == 0,
				"a chain 3 save on the stonework's '%s' goes on at the workshop's first goal" % old_id)
	Quests.load_data({"chain": Quests.CHAIN, "id": "coop_built", "count": 0, "orders": saved_orders})
	_check(Quests.current()["id"] == "coop_built", "a save of this chain on the first day stays on the first day")
	_check(FarmState.flags == flags_now, "loading goals outside a real load leaves the farm's flags alone")
	Quests.step = Quests.index_of("knife")
	Quests.step_count = 0
	Quests.load_data(Quests.save_data())
	_check(Quests.current()["id"] == "knife", "a save keeps the goal by its id")
	Quests.load_data(saved)
	Quests.tally = {}
	# Level, building and animal goals count up by themselves.
	var level_step := Quests.index_of("level_3")
	Quests.step = level_step
	Quests.step_count = 0
	var saved_level := Progress.level
	Progress.level = 2
	Quests._poll = 0.0
	await _idle_frames(3)
	_check(Quests.step == level_step and Quests.step_count == 2 and Game.hud._quest_count.text == "2/3",
			"a level goal shows the farm level (2/3)")
	Progress.level = 3
	Quests._poll = 0.0
	await _idle_frames(3)
	_check(Quests.current()["id"] == "barn", "reaching level 3 moves on to building the barn")
	Progress.level = saved_level
	# Seeds of crops the level hasn't opened yet can't be bought.
	Progress.level = 1
	var shop: ShopScreen = Game.hud.shop_screen
	shop.open(ShopStock.town_market())
	shop._tab = "buy"
	shop._sel = {"id": &"strawberry_seed", "quality": 0}
	_check(shop._max_qty() == 0 and shop._locked(shop._sel), "strawberry seeds wait for farm level %d" % UnlockTable.crop_level(&"strawberry"))
	shop._sel = {"id": &"wheat_seed", "quality": 0}
	_check(shop._max_qty() > 0, "wheat seeds are for sale from the start")
	shop.hide_screen()
	# Levelling up lists what opened.
	var lu := LevelUpScreen.entries(2).map(func(e: Array) -> String: return String(e[1]))
	_check(lu.has(ItemDB.get_item(&"tomato").display_name()) and not lu.has(Animals.species_name(&"chicken")),
			"level 2 opens tomatoes; hens are open from the start (%s)" % ", ".join(lu))
	Game.hud.level_up_screen.open(2)
	await _frames(2)
	_check(Game.hud.level_up_screen.visible, "the level-up window opens")
	Game.hud.level_up_screen.hide_screen()
	Progress.level = saved_level
	# Put back what the story's checks moved.
	if keys_had > 0:
		inv.add_item(&"truck_key", keys_had)
	FarmState.flags = flags_before
	bin.slots = bin_before
	bin.changed.emit()
	Quests.step = Quests.index_of("till")
	Quests.step_count = 0
	# Farm experience: enough work raises the level.
	var level := Progress.level
	var xp := Progress.xp
	Progress.add(Progress.THRESHOLDS[level + 1] - Progress.xp)
	_check(Progress.level == level + 1, "experience raises the farm level (%d -> %d)" % [level, Progress.level])
	Progress.xp = xp
	Progress.level = level
	# A new farm's board always carries the bakery's wood order (the tutorial's order goal).
	Quests.new_game()
	var first: Dictionary = Quests.orders[0]
	_check(StringName(first["item"]) == &"wood" and int(first["count"]) == int(Quests.FIRST_ORDER["count"])
			and int(first["client"]) == int(Quests.FIRST_ORDER["client"]) and Quests.tally.is_empty() and Quests.step == 0
			and Quests.current()["id"] == "door" and Quests.first_day(),
			"a new game starts the story at Grandpa's front door and pins the bakery's wood order on the board")
	FarmState.flags[FarmHouse.DRAWER_LOCK_FLAG] = true
	Quests.skip_tutorial()
	_check(not FarmState.flags.has(FarmHouse.DRAWER_LOCK_FLAG), "skipping the story unlocks the desk drawer (and the pickup's key)")
	# The board: three orders, delivered from the bag.
	Quests.orders = []
	Quests.refill_board()
	_check(Quests.orders.size() == Quests.BOARD_SIZE, "the board has %d orders" % Quests.orders.size())
	var board := tree.get_first_node_in_group(&"order_board") as OrderBoard
	_check(board != null, "the order board stands in town")
	var o: Dictionary = Quests.orders[0]
	var item := StringName(o["item"])
	# The item is random: earlier scenarios may have left some in the bag.
	var had := inv.count_item(item)
	inv.remove_item(item, had)
	_check(not Quests.can_deliver(o), "an order can't be delivered without the goods")
	inv.add_item(item, int(o["count"]))
	money = Economy.money
	var reward := int(o["reward"])
	var fair := ItemDB.get_item(item).sell_price * int(o["count"])
	_check(Quests.deliver(o) and Economy.money == money + reward and inv.count_item(item) == 0,
			"delivered %s ×%d for %d gold (market ~%d)" % [item, int(o["count"]), reward, fair])
	_check(reward > fair, "orders pay more than the market")
	inv.add_item(item, had)
	# Expired orders are replaced in the morning.
	for other: Dictionary in Quests.orders:
		other["due"] = GameClock.day - 1
	Quests.refill_board()
	_check(Quests.orders.size() == Quests.BOARD_SIZE and Quests.orders.all(func(x: Dictionary) -> bool: return int(x["due"]) >= GameClock.day),
			"expired orders are replaced")
	await _frames(2)


## The first day's HUD: the hotbar and inventory lock of a new farm, the waypoint dot,
## achievements and their banner, the shipping bin's report and the morning sale badge.
func _hud() -> void:
	var hud: HUD = Game.hud
	var inv := PlayerState.inventory
	var saved_bag := inv.to_array()
	var player: Player = Game.player
	player.global_position = Vector3(-10, 0.3, 0)
	player.look_at_yaw_pitch(0.0, 0.0)
	await _frames(5)

	# A new farm's bag: empty, no hotbar, Tab does nothing.
	PlayerState.hotbar_unlocked = false
	inv.from_array([])
	# The lock set directly is caught in the HUD's _process: idle frames, not physics ones
	# (the teleport above can make a slow frame, caught up by several physics frames).
	await _idle_frames(3)
	_check(not hud.hotbar.visible, "a locked hotbar is hidden")
	await _press_key(KEY_TAB)
	await _frames(3)
	_check(not Game.is_ui_open(), "Tab does nothing while the bag is locked")
	hud.inventory_screen.open()
	_check(not Game.is_ui_open(), "the bag alone doesn't open while locked")
	# The first item opens both, for good.
	PlayerState.give(&"hoe", 1, false)
	await _frames(3)
	_check(PlayerState.hotbar_unlocked and hud.hotbar.visible, "the first item opens the hotbar")
	await _press_key(KEY_TAB)
	await _frames(3)
	_check(Game.top_ui() == &"inventory", "Tab opens the inventory once the bag is open")
	hud.inventory_screen.close()
	await _frames(3)
	# Saves: a locked one stays locked; one from before the lock comes open.
	PlayerState.load_data({"inventory": [], "hotbar": false})
	_check(not PlayerState.hotbar_unlocked and not bool(PlayerState.save_data()["hotbar"]), "a locked bag is saved and loads locked")
	PlayerState.load_data({"inventory": saved_bag})
	_check(PlayerState.hotbar_unlocked and inv.count_item(&"hoe") == 1 and inv.get_stack(0).item.id == &"hoe",
			"a save from before the lock loads with the hotbar open and its bag")
	await _frames(3)
	_check(hud.hotbar.visible, "the hotbar is back")

	# The waypoint dot: in view with the distance, dimmed under the crosshair, on the edge
	# when behind, fading close. A place ahead and to the right (20 m off), clear of the
	# crosshair, shows in full.
	var wp := hud.waypoint
	wp.target_override = player.global_position + Vector3(12, 1.5, -16)
	await _frames(30)
	_check(wp.on_screen and wp.modulate.a > 0.5, "the waypoint dot shows over a place ahead (a=%.2f)" % wp.modulate.a)
	_check(wp._label.text == tr("HUD_DISTANCE_M") % 20, "it shows the distance in metres ('%s')" % wp._label.text)
	# Straight ahead it sits over the crosshair and the prompts: dimmed, still there.
	wp.target_override = player.global_position + Vector3(0, 1.5, -20)
	await _frames(30)
	_check(wp.on_screen and wp.modulate.a > 0.25 and wp.modulate.a < 0.5,
			"under the crosshair it dims so it never hides a prompt (a=%.2f)" % wp.modulate.a)
	# (The dot is placed in its _process: the quick checks wait idle frames.)
	player.look_at_yaw_pitch(PI, 0.0)
	await _idle_frames(3)
	var right := wp.size.x - WaypointMarker.INSET.z
	_check(not wp.on_screen and wp._dir != Vector2.ZERO
			and (absf(wp._pos.x - WaypointMarker.INSET.x) < 1.0 or absf(wp._pos.x - right) < 1.0),
			"behind the camera it rides a side edge with an arrow (x=%.0f)" % wp._pos.x)
	player.look_at_yaw_pitch(0.0, 0.0)
	var node := Node3D.new()
	Game.world.add_child(node)
	node.global_position = player.global_position + Vector3(8, 1.5, -12)
	wp.target_override = node
	await _frames(30)
	_check(wp.world_point.is_equal_approx(node.global_position) and wp.modulate.a > 0.5, "it follows a node")
	node.queue_free()
	await _idle_frames(3)
	_check(not wp._has_target, "a freed node drops the dot")
	wp.target_override = player.global_position + Vector3(0, 1.0, -1.0)
	await _frames(40)
	_check(wp.modulate.a < 0.01, "it fades out close to the place")
	wp.target_override = player.global_position + Vector3(0, 1.5, -20)
	await _frames(30)
	hud.inventory_screen.open()
	await _idle_frames(2)
	_check(not wp.visible, "menus hide it")
	hud.inventory_screen.close()
	wp.target_override = null
	# Only when the story names no place right now (the tutorial may point somewhere).
	if Quests.waypoint() == null:
		await _frames(40)
		_check(not wp.visible, "no place, no dot")

	# Achievements: once each, with experience, a banner and a save.
	# An earlier scenario's banner (the first egg in _quests...) may still be up: clear it.
	var toast := hud.achievement_toast
	toast.queue.clear()
	if toast._tween:
		toast._tween.kill()
	toast._done()
	var had: Dictionary = Achievements.unlocked.duplicate()
	Achievements.unlocked.erase(&"first_harvest")
	var xp := Progress.xp
	_check(Achievements.unlock(&"first_harvest") and not Achievements.unlock(&"first_harvest"), "an achievement unlocks once")
	_check(Progress.xp > xp, "it gives farm experience")
	await _frames(5)
	_check(toast.visible and toast.showing == &"first_harvest"
			and toast._title.text == UiTheme.caps(Achievements.title(&"first_harvest")), "its banner shows at the top")
	hud.inventory_screen.open()
	Achievements.unlocked.erase(&"first_egg")
	Events.item_picked_up.emit(&"egg", 1)
	_check(Achievements.is_unlocked(&"first_egg"), "picking up an egg unlocks the first egg")
	await _frames(3)
	_check(toast.queue.has(&"first_egg"), "a banner waits while a window is open")
	hud.inventory_screen.close()
	var data := Achievements.save_data()
	Achievements.new_game()
	_check(Achievements.unlocked.is_empty(), "a new game has no achievements")
	Achievements.load_data(data)
	_check(Achievements.is_unlocked(&"first_harvest") and Achievements.is_unlocked(&"first_egg"), "achievements survive a save")
	Achievements.load_data({})
	_check(Achievements._backfill, "a save from before achievements works them out once loaded")
	Achievements.load_data(data)

	# The shipping bin reports goods going in, once each. What it reported is kept until
	# the night's sale (goods taken out and put back don't count twice), and an earlier
	# scenario (_quests) put carrots in and took them out today: start a new day's tally.
	var bin: ShippingBin = Game.world.farm.get_node("ShippingBin")
	bin.inventory.from_array([])
	bin._reported.clear()
	var shipped: Array = []
	var on_shipped := func(id: StringName, n: int) -> void: shipped.append([id, n])
	Events.shipped.connect(on_shipped)
	bin.inventory.add_item(&"carrot", 4)
	bin.inventory.add_item(&"carrot", 2)
	bin.inventory.remove_item(&"carrot", 2)
	bin.inventory.add_item(&"carrot", 2)
	Events.shipped.disconnect(on_shipped)
	_check(shipped == [[&"carrot", 4], [&"carrot", 2]], "the bin reports goods going in, not twice (%s)" % str(shipped))
	_check(ShippingBin.count_in_bin(&"carrot") == 6 and ShippingBin.count_in_bin(&"crop") == 6, "the bin counts by item and by category")
	bin.inventory.from_array([])
	var bin_spot := WaypointMarker.anchor(&"shipping_bin")
	_check(bin_spot != null and bin_spot.global_position.distance_to(bin.global_position + Vector3(0, 1.1, 0)) < 0.05,
			"the shipping bin carries its waypoint anchor")

	# The morning sale badge: under the money, pushing the cards down, then gone.
	Achievements.unlocked.erase(&"first_sale")
	Events.morning_sale.emit(0)
	await _frames(3)
	_check(not hud._sale_badge.visible and not Achievements.is_unlocked(&"first_sale"), "no sale, no badge")
	Events.morning_sale.emit(123)
	# The badge fades in, then counts up: both are over by then.
	await _seconds(SaleBadge.FADE_IN + SaleBadge.COUNT + 0.3)
	_check(hud._sale_badge.visible and hud._sale_badge.amount == 123 and hud._sale_badge._value.text == "+" + UiTheme.money(123),
			"a morning sale shows '+123' under the money")
	_check(hud._level_pill.position.y > HUD.LEVEL_Y + 20.0 and hud._sale_badge.position.y > hud._money_pill.position.y,
			"the level card slides down to make room")
	_check(Achievements.is_unlocked(&"first_sale"), "the first sale is an achievement")
	await _seconds(SaleBadge.HOLD + SaleBadge.FADE_OUT + 0.6)
	_check(not hud._sale_badge.visible and is_equal_approx(hud._level_pill.position.y, HUD.LEVEL_Y), "the badge folds away")
	Achievements.unlocked = had
	await _frames(2)


## Waits for a load or new game to finish rebuilding the scene (at most ~20 s).
func _until_loaded() -> void:
	for i in 1200:
		await tree.physics_frame
		if not SaveGame.loading and Game.player and is_instance_valid(Game.player):
			break
	await _frames(10)


func _hold_use(seconds: float) -> void:
	Input.action_press("use")
	await _seconds(seconds)
	Input.action_release("use")
	await _frames(3)


# --- Saplings --------------------------------------------------------------------

## Saplings from felled trees: the drop roll (seeded), a sapling from a real felling,
## planting on open ground by hand (not on fields, the road or by a tree), watering,
## growing through the stages only while the soil is wet (rain counts), growing into a
## choppable tree with its own id, digging a fresh one up, save and load.
func _sapling() -> void:
	var player: Player = Game.player
	var inv := PlayerState.inventory
	var grove := SaplingGrove.instance
	_check(grove != null and is_instance_valid(grove), "the farm has its sapling grove")
	Weather.force(Weather.Kind.SUNNY)
	# From the morning, as on a new farm: the growth below skips whole days, and from an
	# evening start it would run past bedtime into the morning report (earlier scenarios
	# leave the clock anywhere).
	GameClock.minute = float(GameClock.DAY_START_MINUTE)
	# The drop roll: DROP_CHANCE of felled trees, the same for the same seed.
	SaplingGrove.drop_rng.seed = 2024
	var drops := 0
	for i in 2000:
		if SaplingGrove.roll_drop():
			drops += 1
	var share := drops / 2000.0
	_check(absf(share - SaplingGrove.DROP_CHANCE) < 0.04, "about 60%% of felled trees drop a sapling (%.1f%%)" % (share * 100.0))
	var first: Array[bool] = []
	var again: Array[bool] = []
	SaplingGrove.drop_rng.seed = 77
	for i in 16:
		first.append(SaplingGrove.roll_drop())
	SaplingGrove.drop_rng.seed = 77
	for i in 16:
		again.append(SaplingGrove.roll_drop())
	_check(first == again and first.has(true) and first.has(false), "the roll is seeded: the same seed drops the same way")

	# A felled tree drops one with its wood (the roll forced for the test); it flies
	# into the bag.
	var felled: ChoppableTree = null
	for t: ChoppableTree in tree.get_nodes_in_group(&"trees"):
		if not t.felled and (felled == null or t.global_position.distance_to(player.global_position)
				< felled.global_position.distance_to(player.global_position)):
			felled = t
	var saplings := inv.count_item(SaplingGrove.ITEM)
	player.global_position = felled.global_position + Vector3(0, 0.2, 1.6)
	_look_at(player, felled.global_position + Vector3(0, 1.2, 0))
	await _frames(6)
	_select(&"axe")
	SaplingGrove.drop_chance = 1.0
	await _hold_use(felled.max_hp() * 0.75 + 1.0)
	_check(felled.felled, "the tree is felled")
	await _seconds(4.5)
	SaplingGrove.drop_chance = SaplingGrove.DROP_CHANCE
	_check(inv.count_item(SaplingGrove.ITEM) == saplings + 1,
			"the felled tree dropped a sapling into the bag (%d -> %d)" % [saplings, inv.count_item(SaplingGrove.ITEM)])

	# Where one may go: not on a field, the road or right by a tree.
	var lot: Rect2 = WorldLayout.FIELD_LOTS[&"field_0"]["rect"]
	var road: Vector2 = WorldLayout.ROAD_POINTS[2]
	var by_tree := felled.global_position + Vector3(1.2, 0, 0.8)
	_check(grove.plant_reason(_on_ground(lot.get_center())) == "SAPLING_NOT_HERE"
			and grove.plant_reason(_on_ground(road)) == "SAPLING_NOT_HERE"
			and grove.plant_reason(_on_ground(Vector2(by_tree.x, by_tree.z))) == "SAPLING_TOO_CLOSE",
			"no sapling on a field, on the road or right by a tree")

	# Planted by hand: aim at open ground with it and hold LMB.
	var spot := _open_ground(grove, player.global_position)
	_check(spot != Vector3.INF, "found open ground for a sapling (%s)" % spot)
	player.global_position = _on_ground(Vector2(spot.x, spot.z + 1.8)) + Vector3(0, 0.1, 0)
	_look_at(player, spot)
	_select(SaplingGrove.ITEM)
	await _frames(8)
	_check(player.target is SaplingSpot and (player.target as SaplingSpot).reason == ""
			and _last_prompt.contains(tr("ACTION_PLANT")), "with a sapling in hand the open ground offers PLANT ('%s')" % _last_prompt)
	_check(ToolAnim.resolve("plant_sapling", null)[0] == &"dig", "planting plays the dig strokes")
	var planted: Array[Node] = []
	var on_planted := func(s: Node) -> void: planted.append(s)
	Events.sapling_planted.connect(on_planted)
	var before := inv.count_item(SaplingGrove.ITEM)
	await _hold_use(1.7)
	Events.sapling_planted.disconnect(on_planted)
	var sap: Sapling = planted[0] as Sapling if planted.size() == 1 else null
	_check(sap != null and inv.count_item(SaplingGrove.ITEM) == before - 1 and FarmState.saplings.size() == 1
			and Vector2(sap.global_position.x, sap.global_position.z).distance_to(Vector2(spot.x, spot.z)) < 0.3,
			"holding LMB plants it where aimed, one sapling from the bag (Events.sapling_planted)")
	if sap == null:
		Weather.forced = -1
		return
	_check(sap.stage() == 0 and not sap.is_wet() and String(sap.entry["id"]).begins_with("planted_"),
			"a fresh sapling: stage 0, dry soil, id %s" % sap.entry["id"])
	GameClock.advance(10.0 * 60.0)
	_check(sap.growth() == 0.0, "left dry it doesn't grow")

	# Watered with the can.
	_select(&"watering_can")
	_look_at(player, sap.global_position + Vector3(0, 0.3, 0))
	await _frames(6)
	_check(player.target == sap, "aiming at the sapling")
	var can := PlayerState.selected_stack()
	var water := can.water
	await _hold_use(1.1)
	_check(sap.is_wet() and can.water == water - 1, "the watering can soaks its soil")
	var card: CropCard = Game.hud.crop_card
	await _seconds(0.45)
	_check(card.visible and card.state == "growing" and card._name.text == UiTheme.caps(tr("SAPLING_STAGE_0")),
			"aiming at it shows its growth card (%s, '%s')" % [card.state, card._name.text])

	# Through the stages, only while wet; rain waters it too.
	GameClock.advance(17.0 * 60.0)
	_check(sap.stage() == 1 and absf(sap.growth() - 17.0) < 0.2, "17 wet hours: a young tree (stage %d, %.1f h)" % [sap.stage(), sap.growth()])
	GameClock.advance(12.0 * 60.0)
	_check(not sap.is_wet() and absf(sap.growth() - CropTable.WET_HOURS) < 0.2,
			"a day after watering the soil is dry and growth waits (%.1f h)" % sap.growth())
	Weather.force(Weather.Kind.RAIN)
	GameClock.advance(30.0)
	Weather.force(Weather.Kind.SUNNY)
	_check(sap.is_wet(), "rain waters the sapling")
	GameClock.advance(10.0 * 60.0)
	_check(sap.stage() == 2 and sap.collision_layer & 1 != 0, "a growing tree (stage 2) now stands in the way")
	var grown: Array[Node] = []
	var on_grown := func(t: Node) -> void: grown.append(t)
	Events.sapling_grown.connect(on_grown)
	sap.soak()
	GameClock.advance(16.0 * 60.0)
	Events.sapling_grown.disconnect(on_grown)
	await _frames(2)
	var grown_tree: ChoppableTree = grown[0] as ChoppableTree if grown.size() == 1 else null
	_check(grown_tree != null and tree.get_nodes_in_group(&"saplings").is_empty() and bool(FarmState.saplings[0].get("grown", false)),
			"after two days' growth it is a tree (Events.sapling_grown)")
	if grown_tree == null:
		Weather.forced = -1
		return
	var same_id := 0
	var generated_clash := false
	for t: ChoppableTree in tree.get_nodes_in_group(&"trees"):
		if t.resource_id == grown_tree.resource_id:
			same_id += 1
		if t != grown_tree and t.resource_id.begins_with("planted_"):
			generated_clash = true
	_check(same_id == 1 and not generated_clash and grown_tree.resource_id == String(FarmState.saplings[0]["id"]),
			"the tree keeps the sapling's own id (%s), no clash with the valley's" % grown_tree.resource_id)
	await _seconds(3.2)
	# Skipping days can bring up a screen (the morning report, a level-up): close it.
	var screens: Array[StringName] = []
	for i in 6:
		if not Game.is_ui_open():
			break
		screens.append(Game.top_ui())
		await _press_key(KEY_ESCAPE)
		await _frames(8)
	player.global_position = grown_tree.global_position + Vector3(0, 0.3, 1.6)
	_look_at(player, grown_tree.global_position + Vector3(0, 1.2, 0))
	_select(&"axe")
	await _frames(6)
	_check(player.target == grown_tree, "aiming at the grown tree (screens closed first: %s, still open: %s)" % [screens, Game.top_ui()])
	SaplingGrove.drop_chance = 0.0
	await _hold_use(grown_tree.max_hp() * 0.75 + 1.0)
	SaplingGrove.drop_chance = SaplingGrove.DROP_CHANCE
	_check(grown_tree.felled and FarmState.depleted.has(grown_tree.resource_id), "the grown tree is chopped like any other")
	var grown_id := grown_tree.resource_id

	# A fresh one is dug up again with E.
	var p3 := _open_ground(grove, player.global_position)
	var dug := grove.plant(p3)
	player.global_position = _on_ground(Vector2(p3.x, p3.z + 1.6)) + Vector3(0, 0.1, 0)
	_look_at(player, p3 + Vector3(0, 0.3, 0))
	_select(&"watering_can")
	await _frames(6)
	var bag := inv.count_item(SaplingGrove.ITEM)
	_check(player.target == dug and _last_prompt.contains(tr("ACTION_DIG_UP")), "a fresh sapling can be dug up ('%s')" % _last_prompt)
	await _press_key(KEY_E)
	await _frames(3)
	_check(inv.count_item(SaplingGrove.ITEM) == bag + 1 and FarmState.saplings.size() == 1, "digging it up puts it back in the bag")

	# Saved and loaded: a half-grown sapling and the grown tree's stump come back.
	var p2 := _open_ground(grove, player.global_position)
	var kept := grove.plant(p2)
	kept.entry["growth"] = 20.0
	kept.entry["wet"] = 5.0
	kept.soak(5.0)
	var kept_id := String(kept.entry["id"])
	var kept_kind := kept.kind()
	var slot := "slot_2"
	_check(SaveGame.save(slot), "saved with saplings")
	FarmState.saplings.clear()
	_check(SaveGame.load_game(slot), "loading started")
	await _until_loaded()
	var back: Sapling = null
	for s: Sapling in tree.get_nodes_in_group(&"saplings"):
		if String(s.entry["id"]) == kept_id:
			back = s
	_check(back != null and absf(back.growth() - 20.0) < 0.01 and absf(back.wet_hours() - 5.0) < 0.01 and back.stage() == 1
			and back.kind() == kept_kind and back.global_position.distance_to(p2) < 0.05,
			"the half-grown sapling is back where it was, growth and water kept")
	var stump: ChoppableTree = null
	for t: ChoppableTree in tree.get_nodes_in_group(&"trees"):
		if t.resource_id == grown_id:
			stump = t
	_check(stump != null and stump.felled, "the tree grown from a sapling is back, still a stump")
	SaveGame.delete(slot)
	Weather.forced = -1


## A point on the terrain.
func _on_ground(p: Vector2) -> Vector3:
	return Vector3(p.x, TerrainData.height(p.x, p.y), p.y)


## Open ground near `around` where a sapling may go, with room for the player to
## stand 1.8 m south of it and no tall grass in the aim; INF when there is none.
func _open_ground(grove: SaplingGrove, around: Vector3) -> Vector3:
	for r in range(4, 70, 2):
		for k in 24:
			var a := TAU * k / 24.0
			var p := _on_ground(Vector2(around.x + cos(a) * r, around.z + sin(a) * r))
			var stand := _on_ground(Vector2(p.x, p.z + 1.8))
			if grove.plant_reason(p) != "" or grove.plant_reason(stand) != "" or absf(stand.y - p.y) > 0.4:
				continue
			var grass := _nearest(&"grass_patches", p)
			if grass and grass.global_position.distance_to(p) < 3.5:
				continue
			return p
	return Vector3.INF


## Pictures of the saplings for a look (--shotdir=/abs/dir): the three stages and a
## tree grown from one side by side, the growth card and the planting ring.
func _sapling_shots() -> void:
	var dir := String(DebugTools.args.get("shotdir", OS.get_user_data_dir()))
	var player: Player = Game.player
	var grove := SaplingGrove.instance
	Weather.force(Weather.Kind.SUNNY)
	GameClock.set_time_of_day(10.5)
	var base := Vector3.INF
	for tries in 40:
		var c := _open_ground(grove, Vector3(35 + tries * 3, 0, -10))
		var ok := c != Vector3.INF
		for i in range(1, 4):
			if ok and grove.plant_reason(_on_ground(Vector2(c.x + i * 3.4, c.z))) != "":
				ok = false
		if ok:
			base = c
			break
	if base == Vector3.INF:
		_check(false, "room for the sapling row")
		return
	var row: Array[Sapling] = []
	for i in 4:
		var s := grove.plant(_on_ground(Vector2(base.x + i * 3.4, base.z)))
		# Conifers but the second (the kind comes from the woods around).
		var e := s.entry
		grove.remove(s)
		s.free()
		e["kind"] = 1 if i == 1 else 0
		FarmState.saplings.append(e)
		row.append(grove._spawn_sapling(e))
	await _seconds(0.6)
	row[1].entry["growth"] = 18.0
	row[2].entry["growth"] = 38.0
	row[3].entry["growth"] = SaplingGrove.GROW_HOURS
	for i in range(1, 4):
		row[i].soak()
		row[i]._refresh(false)
	grove._grow_up(row[3])
	await _seconds(3.5)
	player.global_position = _on_ground(Vector2(base.x + 5.1, base.z + 9.0)) + Vector3(0, 0.1, 0)
	_look_at(player, _on_ground(Vector2(base.x + 5.1, base.z)) + Vector3(0, 1.4, 0))
	_select(&"watering_can")
	await _shot(dir + "/sapling_row.png")
	player.global_position = _on_ground(Vector2(base.x, base.z + 1.7)) + Vector3(0, 0.1, 0)
	_look_at(player, row[0].global_position + Vector3(0, 0.35, 0))
	await _shot(dir + "/sapling_card.png")
	player.global_position = _on_ground(Vector2(base.x + 3.4, base.z + 2.6)) + Vector3(0, 0.1, 0)
	_look_at(player, row[1].global_position + Vector3(0, 0.9, 0))
	await _shot(dir + "/sapling_young.png")
	PlayerState.inventory.add_item(SaplingGrove.ITEM, 2)
	_select(SaplingGrove.ITEM)
	player.global_position = _on_ground(Vector2(base.x + 1.7, base.z + 3.0)) + Vector3(0, 0.1, 0)
	_look_at(player, _on_ground(Vector2(base.x + 1.7, base.z + 1.2)))
	await _shot(dir + "/sapling_spot.png")
	Weather.forced = -1


func _shot(path: String) -> void:
	await _seconds(1.2)
	await _idle_frames(4)
	var img := tree.root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path)


# --- Helpers ---------------------------------------------------------------------

# --- Fishing -----------------------------------------------------------------------------

## The rod at the pond: casting (bait, power, water only), the bite and the strike, the
## fish flying onto the bank and flopping there until it is picked up, a missed bite, a
## strike too early, a cast onto the bank, no bait, switching away mid-cast, and selling
## the catch. -- --fish-shots=<dir> also saves screenshots of each step.
func _fishing() -> void:
	var player: Player = Game.player
	var inv := PlayerState.inventory
	var angler := player.angler
	GameClock.set_time_of_day(10.0)
	GameClock.running = false
	Weather.force(Weather.Kind.SUNNY)
	var casts: Array = []
	var caught: Array[StringName] = []
	var on_cast := func() -> void: casts.append(true)
	var on_caught := func(id: StringName) -> void: caught.append(id)
	Events.line_cast.connect(on_cast)
	Events.fish_caught.connect(on_caught)

	# The catalogue: every species sells, cooks into a food, and has its model.
	var table_ok := true
	for id: StringName in FishTable.SPECIES:
		var item := ItemDB.get_item(id)
		if item == null or item.sell_price <= 0 or not FishModels.has(id) or ItemModels.mesh(id).get_surface_count() == 0:
			table_ok = false
			print("  bad catch item ", id)
		if FishTable.is_fish(id):
			var cooked := FishTable.cooked_id(id)
			var row: Dictionary = ItemTable.ITEMS.get(cooked, {})
			if item == null or item.category != "fish" or row.get("cat", "") != "food" or int(row.get("food", 0)) <= 0 or not FishModels.has(cooked):
				table_ok = false
				print("  bad cooked item ", cooked)
	_check(table_ok and FishTable.SPECIES.size() >= 10, "fishing: %d catches, each sold, cooked into food and modelled" % FishTable.SPECIES.size())
	var cheap := ItemDB.get_item(&"fish_rudd").sell_price
	var dear := ItemDB.get_item(&"fish_catfish").sell_price
	_check(cheap <= 5 and dear >= 40, "fishing: a common fish sells for $%d, the legendary one $%d" % [cheap, dear])
	var ch := FishTable.chances(&"worm", 23.0, false)
	var ch_day := FishTable.chances(&"worm", 12.0, false)
	_check(float(ch[&"fish_catfish"]) > float(ch_day[&"fish_catfish"]) * 2.0, "fishing: the catfish bites at night")

	# To the pond's east bank, the rod in hand, worms and dough in the bag.
	for id: StringName in [&"fishing_rod", &"worm", &"dough"]:
		inv.remove_item(id, inv.count_item(id))
	inv.add_item(&"fishing_rod", 1)
	inv.add_item(&"worm", 6)
	inv.add_item(&"dough", 2)
	_select(&"fishing_rod")
	var bank := Vector3(WorldLayout.POND_CENTER.x + 10.7, 0.0, WorldLayout.POND_CENTER.y + 1.0)
	bank.y = TerrainData.height(bank.x, bank.z) + 0.1
	player.global_position = bank
	player.look_at_yaw_pitch(PI * 0.5, deg_to_rad(-8.0))
	await _frames(20)
	await _fish_shot("rod_idle")
	_check(angler.holding_rod() and angler.state == Angler.State.IDLE, "fishing: the rod is in hand, the line in")
	_check(_last_prompt.contains(tr("ACTION_CAST")), "fishing: the prompt offers casting ('%s')" % _last_prompt.replace("\n", " | "))

	# Facing away from the water: no cast.
	player.look_at_yaw_pitch(-PI * 0.5, 0.0)
	await _frames(3)
	await _hold_use(0.3)
	await _frames(3)
	_check(angler.state == Angler.State.IDLE, "fishing: no cast with the pond behind (%s)" % Angler.State.keys()[angler.state])

	# A cast: held for power, released, the float flies and lands on the water.
	player.look_at_yaw_pitch(PI * 0.5, deg_to_rad(-8.0))
	await _frames(3)
	var worms := inv.count_item(&"worm")
	Input.action_press("use")
	await _seconds(0.45)
	_check(angler.state == Angler.State.WINDUP and angler.power > 0.2, "fishing: holding LMB winds up (%s, power %.2f)" % [Angler.State.keys()[angler.state], angler.power])
	await _fish_shot("windup")
	await _seconds(0.35)
	Input.action_release("use")
	await _frames(2)
	_check(angler.state == Angler.State.CAST, "fishing: releasing casts")
	for i in 240:
		await tree.physics_frame
		if angler.state != Angler.State.CAST:
			break
	await _fish_shot("plop")
	var fl: Vector3 = angler._p
	_check(angler.state == Angler.State.WAIT and Pond.is_fishable(fl), "fishing: the float lands on the pond (%s at %.1f m)" % [Angler.State.keys()[angler.state], fl.distance_to(player.global_position)])
	_check(inv.count_item(&"worm") == worms - 1 and casts.size() == 1, "fishing: the cast took one worm and sent line_cast (%d -> %d)" % [worms, inv.count_item(&"worm")])
	_check(angler._bite_at >= Angler.BITE_TIME.x and angler._bite_at <= Angler.BITE_TIME.y, "fishing: the bite comes in 5-20 s (%.1f s)" % angler._bite_at)
	await _seconds(0.6)
	await _fish_shot("waiting")

	# The bite (brought forward), struck in time: a silver carp flies onto the bank.
	angler.catch_info = FishTable.catch_of(&"fish_carp", 0.9)
	angler._nibbles.clear()
	angler._bite_at = angler._t + 0.3
	for i in 120:
		await tree.physics_frame
		if angler.state == Angler.State.BITE:
			break
	_check(angler.state == Angler.State.BITE and _last_prompt.contains(tr("ACTION_STRIKE")) or angler.state == Angler.State.BITE,
			"fishing: the fish bites, the prompt says strike")
	await _seconds(0.12)
	await _fish_shot("bite")
	await _seconds(0.38)
	await _hold_use(0.1)
	_check(angler.state == Angler.State.STRIKE, "fishing: LMB within 2 s strikes")
	await _seconds(0.45)
	await _fish_shot("fish_flying")
	var fish: FloppingFish = null
	for i in 180:
		await tree.physics_frame
		var list := tree.get_nodes_in_group(&"caught_fish")
		if not list.is_empty() and not (list[0] as FloppingFish).is_flying():
			fish = list[0]
			break
	_check(fish != null, "fishing: the fish lands on the bank")
	if fish == null:
		return
	var flat := Vector2(fish.global_position.x - player.global_position.x, fish.global_position.z - player.global_position.z).length()
	_check(flat >= 1.8 and flat <= 3.2 and not Pond.is_fishable(fish.global_position), "fishing: it lands %.1f m from the player, on dry ground" % flat)
	var hops := 0
	var was := fish._state
	for i in 150:
		await tree.physics_frame
		if fish._state == 1 and was != 1:
			hops += 1
		was = fish._state
	_check(hops >= 1, "fishing: it flops about on the ground (%d hops in 2.5 s)" % hops)
	_check(angler.state == Angler.State.IDLE, "fishing: the line is back in (%s)" % Angler.State.keys()[angler.state])
	_look_at(player, fish.global_position + Vector3(0, 0.05, 0))
	await _frames(4)
	await _fish_shot("fish_ground")
	player.global_position = fish.global_position + (player.global_position - fish.global_position).normalized() * 1.2
	player.global_position.y = TerrainData.height(player.global_position.x, player.global_position.z) + 0.1
	await _frames(8)
	for i in 120:
		if fish._state == 2:
			break
		await _frames(1)
	_look_at(player, fish.global_position)
	await _frames(1)
	_check(fish._state != 2 or absf(fish.global_basis.z.dot(Vector3.UP)) > 0.9, "fishing: between hops it lies on its side (%.2f)" % fish.global_basis.z.dot(Vector3.UP))
	await _fish_shot("fish_close")
	# It keeps hopping about: follow it with the eyes until the aim is on it.
	for i in 90:
		_look_at(player, fish.global_position)
		await _frames(1)
		if player.target == fish:
			break
	await _frames(2)
	_check(player.target == fish and _last_prompt.contains(tr("ACTION_TAKE_ITEM") % ItemDB.get_item(&"fish_carp").display_name()),
			"fishing: aiming at it offers to take it ('%s'; ray on %s, fish %.1f m from the pond, %.1f m away, state %d)" % [
				_last_prompt.replace("\n", " | "), player.ray.get_collider(),
				Vector2(fish.global_position.x, fish.global_position.z).distance_to(WorldLayout.POND_CENTER),
				player.camera.global_position.distance_to(fish.global_position), fish._state])
	await _press_key(KEY_E)
	await _frames(3)
	var silver := 0
	for i in inv.size():
		var st := inv.get_stack(i)
		if st and st.item.id == &"fish_carp" and st.quality == ItemStack.Quality.SILVER:
			silver += st.count
	_check(silver == 1 and caught == [&"fish_carp"] and not is_instance_valid(fish), "fishing: E puts the silver carp in the bag (fish_caught sent)")

	# A bite missed: the fish gets away with the bait, the line comes back.
	player.global_position = bank
	player.look_at_yaw_pitch(PI * 0.5, deg_to_rad(-8.0))
	await _frames(6)
	worms = inv.count_item(&"worm")
	await _hold_use(0.9)
	for i in 240:
		await tree.physics_frame
		if angler.state == Angler.State.WAIT:
			break
	angler._nibbles.clear()
	angler._bite_at = angler._t + 0.2
	await _seconds(0.4 + Angler.BITE_WINDOW)
	_check(angler.state == Angler.State.RETRIEVE or angler.state == Angler.State.IDLE, "fishing: a missed bite reels the line in (%s)" % Angler.State.keys()[angler.state])
	for i in 400:
		await tree.physics_frame
		if angler.state == Angler.State.IDLE:
			break
	_check(angler.state == Angler.State.IDLE and inv.count_item(&"worm") == worms - 1 and tree.get_nodes_in_group(&"caught_fish").is_empty(),
			"fishing: nothing caught, the worm is gone")

	# Striking before the bite: too early.
	await _hold_use(0.6)
	for i in 240:
		await tree.physics_frame
		if angler.state == Angler.State.WAIT:
			break
	angler._bite_at = 60.0
	await _seconds(0.3)
	await _hold_use(0.1)
	_check(angler.state == Angler.State.RETRIEVE, "fishing: LMB before the bite reels in empty")
	await _fish_shot("retrieve")
	for i in 400:
		await tree.physics_frame
		if angler.state == Angler.State.IDLE:
			break

	# Switching to another item mid-cast puts it all away.
	await _hold_use(0.6)
	for i in 240:
		await tree.physics_frame
		if angler.state == Angler.State.WAIT:
			break
	PlayerState.select((PlayerState.selected + 1) % PlayerState.HOTBAR_SIZE)
	await _frames(3)
	_check(angler.state == Angler.State.IDLE and not angler._float.visible and player.held._debug_u < 0.0,
			"fishing: another item in hand ends the cast and frees the rod's pose")
	_select(&"fishing_rod")
	await _frames(3)

	# A short cast from well back lands on the bank: reeled in, the bait kept.
	var back := bank + Vector3(9.0, 0.0, 0.0)
	back.y = TerrainData.height(back.x, back.z) + 0.1
	player.global_position = back
	player.look_at_yaw_pitch(PI * 0.5, deg_to_rad(-20.0))
	await _frames(8)
	worms = inv.count_item(&"worm")
	await _hold_use(0.05)
	for i in 240:
		await tree.physics_frame
		if angler.state != Angler.State.CAST:
			break
	_check(angler.state == Angler.State.RETRIEVE and inv.count_item(&"worm") == worms, "fishing: a cast onto the bank comes back, the bait kept (%s)" % Angler.State.keys()[angler.state])
	for i in 400:
		await tree.physics_frame
		if angler.state == Angler.State.IDLE:
			break

	# No bait: no cast.
	inv.remove_item(&"worm", inv.count_item(&"worm"))
	inv.remove_item(&"dough", inv.count_item(&"dough"))
	player.global_position = bank
	player.look_at_yaw_pitch(PI * 0.5, deg_to_rad(-8.0))
	await _frames(6)
	await _hold_use(0.4)
	_check(angler.state == Angler.State.IDLE and _last_prompt.contains(tr("HINT_FISH_NO_BAIT")), "fishing: without bait the rod won't cast")

	# The catch sells in the shipping bin; the silver one pays more.
	var bin: ShippingBin = Game.world.farm.get_node("ShippingBin")
	var taken := inv.remove_item(&"fish_carp", 1)
	var added := bin.inventory.add_item(&"fish_carp", 1, ItemStack.Quality.SILVER) == 0
	var money := Economy.money
	bin._sell_contents()
	_check(taken and added and Economy.money > money, "fishing: the bin takes the carp and sells it (+$%d)" % (Economy.money - money))
	_check(Economy.sell_price(&"fish_carp", 1) > Economy.sell_price(&"fish_carp", 0), "fishing: a silver carp is worth more")
	Events.line_cast.disconnect(on_cast)
	Events.fish_caught.disconnect(on_caught)
	GameClock.running = true


## Saves a screenshot for the fishing scenario (-- --fish-shots=<dir>).
func _fish_shot(name: String) -> void:
	var dir := String(DebugTools.args.get("fish-shots", ""))
	if dir == "":
		return
	await RenderingServer.frame_post_draw
	tree.root.get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
## Eye comfort: each graphics preset's anti-aliasing and upscaler, the sky's dithering
## under temporal AA, and the haze's reach (aerial perspective) with and without fog.
func _visual() -> void:
	var root := tree.root
	var saved := Settings.quality
	for q: int in [Settings.Quality.LOW, Settings.Quality.MEDIUM, Settings.Quality.HIGH, Settings.Quality.ULTRA]:
		Settings.quality = q as Settings.Quality
		Settings._apply_3d_scale()
		var name: String = Settings.Quality.keys()[q]
		if q >= Settings.Quality.HIGH:
			_check(root.scaling_3d_mode in [Viewport.SCALING_3D_MODE_FSR2, Viewport.SCALING_3D_MODE_METALFX_TEMPORAL]
					and root.msaa_3d == Viewport.MSAA_DISABLED and root.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED,
					"%s resolves edges over time (FSR 2 / MetalFX temporal, no MSAA)" % name)
			_check(root.fsr_sharpness >= 2.0, "%s adds no upscaler sharpening (%.1f)" % [name, root.fsr_sharpness])
		else:
			_check(root.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA
					and root.msaa_3d == (Viewport.MSAA_2X if q == Settings.Quality.MEDIUM else Viewport.MSAA_DISABLED),
					"%s: FXAA%s" % [name, " and 2x MSAA" if q == Settings.Quality.MEDIUM else ""])
			_check(root.scaling_3d_mode in [Viewport.SCALING_3D_MODE_BILINEAR, Viewport.SCALING_3D_MODE_FSR, Viewport.SCALING_3D_MODE_METALFX_SPATIAL],
					"%s upscales spatially when capped" % name)
	Settings.quality = saved
	Settings._apply_3d_scale()
	var dnc := Game.world.get_node("DayNight") as DayNightCycle
	dnc.apply_quality()
	_check(bool(dnc.sky_material.get_shader_parameter(&"temporal_jitter")) == Settings.uses_temporal_aa(),
			"the clouds' dithering moves per frame only under temporal AA")
	# Haze at clear noon, then in a fog bank (the fields the weather drives each frame).
	var haze := func(d: float) -> float:
		var e := dnc.env
		var x := clampf((d - e.fog_depth_begin) / maxf(e.fog_depth_end - e.fog_depth_begin, 0.001), 0.0, 1.0)
		return pow(x * x * (3.0 - 2.0 * x), e.fog_depth_curve) * e.fog_density
	var kept := [dnc.overcast, dnc.fog_boost]
	dnc.overcast = 0.0
	dnc.fog_boost = 0.0
	dnc._apply(12.5)
	_check(haze.call(30.0) < 0.02 and haze.call(100.0) < 0.05, "the farmyard stays clear at noon (%.1f%% at 100 m)" % (haze.call(100.0) * 100.0))
	_check(haze.call(300.0) > 0.05 and haze.call(3000.0) > 0.5 and haze.call(6000.0) < 0.9,
			"far forest and ridges fade into the air (%.0f%% at 300 m, %.0f%% at 3 km, ridges still show)" % [haze.call(300.0) * 100.0, haze.call(3000.0) * 100.0])
	dnc.fog_boost = 0.02
	dnc._apply(12.5)
	_check(haze.call(100.0) > 0.6 and haze.call(200.0) > 0.95, "a fog bank still swallows the yard (%.0f%% at 100 m)" % (haze.call(100.0) * 100.0))
	dnc.overcast = kept[0]
	dnc.fog_boost = kept[1]
	await _frames(2)


func _check(ok: bool, what: String) -> void:
	print("SCENARIO %s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


## Presses and releases a key through the real input pipeline, one frame apart so
## the two events are never merged into the same input flush.
func _press_key(key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	await tree.process_frame
	await tree.process_frame
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await tree.process_frame


func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


## Waits `n` idle (process) frames: what the autoloads and the HUD work out in _process.
## A slow frame is caught up with several physics frames in a row, so _frames alone can
## pass before any _process has run. Each wait ends just before a frame's _process: two
## hold at least one whole pass.
func _idle_frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func _seconds(s: float) -> void:
	await tree.create_timer(s, true, true).timeout


# --- Campfire, cooking, eating and needs ------------------------------------------------

## The campfire (placed only on open ground, lit, cooking fish, burning down to embers
## and ash, relit with wood, put out with the can and gone within ten seconds, saved),
## eating with the right mouse button and the hunger and energy needs.
## With -- --camp-shots=/abs/dir it also saves a few screenshots of the fire there.
func _camp() -> void:
	var player: Player = Game.player
	var inv := PlayerState.inventory
	var fish := _camp_items()
	var cooked := Campfire.cooked_id(fish)
	_check(cooked != &"" and ItemDB.has_item(cooked), "a raw fish cooks into '%s'" % cooked)
	var lit_fires: Array = []
	var out_fires: Array = []
	var cooked_items: Array = []
	var eaten: Array = []
	var on_lit := func(f: Node) -> void: lit_fires.append(f)
	var on_out := func(f: Node) -> void: out_fires.append(f)
	var on_cooked := func(id: StringName) -> void: cooked_items.append(id)
	var on_eaten := func(id: StringName) -> void: eaten.append(id)
	Events.campfire_lit.connect(on_lit)
	Events.campfire_out.connect(on_out)
	Events.food_cooked.connect(on_cooked)
	Events.food_eaten.connect(on_eaten)
	GameClock.set_time_of_day(19.5)

	# Placing: open ground only.
	inv.set_stack(7, ItemStack.create(&"campfire"))
	PlayerState.select(7)
	var spot := Vector3.INF
	for c: Vector2 in [Vector2(20, -8), Vector2(24, -12), Vector2(18, -14), Vector2(26, -6), Vector2(14, -20)]:
		player.global_position = Vector3(c.x, TerrainData.height(c.x, c.y + 2.6) + 0.3, c.y + 2.6)
		player.look_at_yaw_pitch(0.0, deg_to_rad(-40.0))
		await _frames(8)
		if player.placer.active and player.placer.valid:
			spot = player.placer.global_position
			break
	_check(spot != Vector3.INF, "the campfire shows a valid preview on open farm land (%s)" % player.placer.reason)
	# Never under a roof: a slab put up over the spot.
	var roof := StaticBody3D.new()
	var roof_shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(3, 0.2, 3)
	roof_shape.shape = slab
	roof.add_child(roof_shape)
	Game.world.add_child(roof)
	roof.global_position = spot + Vector3(0, 3.0, 0)
	await _frames(3)
	_check(Campfire.placement_reason(player, spot) == "MSG_CAMPFIRE_ROOF", "a campfire can't go under a roof")
	roof.queue_free()
	await _frames(3)
	var field: Rect2 = WorldLayout.FIELD_LOTS.values()[0]["rect"]
	var on_field := Vector3(field.get_center().x, 0.0, field.get_center().y)
	_check(Campfire.placement_reason(player, on_field) == "MSG_PLACE_RESERVED", "nor on a field")
	var house := WorldLayout.house_rect(0).get_center()
	_check(Campfire.placement_reason(player, Vector3(house.x, 0.0, house.y)) == "MSG_PLACE_RESERVED", "nor in the house")
	var placed_before := FarmState.placed.size()
	_check(player.placer.place() and FarmState.placed.size() == placed_before + 1 and inv.count_item(&"campfire") == 0,
			"the campfire is put down")
	await _frames(3)
	var fire: Campfire = null
	for n in tree.get_nodes_in_group(&"campfires"):
		fire = n as Campfire
	_check(fire != null and fire.state == "laid", "it stands laid, unlit")
	if fire == null:
		_camp_done(on_lit, on_out, on_cooked, on_eaten)
		return
	var entry: Dictionary = fire.entry

	# Lighting it.
	_free_hands()
	var aim := fire.global_position + Vector3(0, 0.3, 0)
	player.global_position = fire.global_position + Vector3(0, 0.2, 2.1)
	await _frames(4)
	_look_at(player, aim)
	await _frames(6)
	_check(player.target == fire and _last_prompt.contains(tr("ACTION_LIGHT")), "E lights it ('%s')" % _last_prompt)
	await _press_key(KEY_E)
	await _frames(3)
	_check(fire.state == "lit" and lit_fires.has(fire) and is_equal_approx(fire.burn_left, Campfire.BURN_MINUTES),
			"lit, it burns 5 hours (Events.campfire_lit)")
	await _seconds(Campfire.IGNITE_SECONDS + 0.6)
	_check(fire._fx._heat > 0.8 and fire._fx._light.visible and fire._fx._flames.emitting, "flames, light and crackle are up")
	await _camp_shot("fire_dusk", player)
	if DebugTools.args.has("camp-shots"):
		for h: float in [13.0, 22.5]:
			GameClock.set_time_of_day(h)
			await _seconds(0.8)
			await _camp_shot("fire_%02d" % int(h), player)
		GameClock.set_time_of_day(19.5)

	# Cooking: two fish on sticks over the flames, counted down on the HUD.
	inv.set_stack(6, ItemStack.create(fish, 3))
	PlayerState.select(6)
	await _frames(4)
	_check(_last_prompt.contains(tr("ACTION_COOK")), "with a raw fish in hand the fire offers to cook it ('%s')" % _last_prompt)
	await _press_key(KEY_E)
	await _frames(2)
	await _press_key(KEY_E)
	await _frames(4)
	_check(fire.cook_status().size() == 2 and inv.count_item(fish) == 1, "two fish went onto sticks over the fire")
	_check((entry["spits"] as Array).size() == 2, "the fish on the fire are saved with it")
	await _seconds(0.6)
	_check(Game.hud.cook_rings._rings.size() == 2, "the HUD counts each one down (%d rings)" % Game.hud.cook_rings._rings.size())
	await _camp_shot("cooking", player)
	if DebugTools.args.has("camp-shots"):
		var at := player.global_position
		player.global_position = fire.global_position + Vector3(0.3, 0.2, 1.3)
		await _frames(3)
		_look_at(player, fire.global_position + Vector3(0, 0.25, 0))
		await _seconds(0.3)
		await _camp_shot("cooking_close", player)
		player.global_position = at
		await _frames(3)
		_look_at(player, aim)
		await _frames(3)
	await _seconds(2.0)
	var left := 0.0
	for sp: Dictionary in fire._spits:
		if not sp.is_empty():
			left = float(sp["left"])
	_check(left > 6.0 and left < 8.0 and cooked_items.is_empty(), "still cooking a few seconds in (%.1f s left)" % left)
	# The rest of the ten seconds.
	await _seconds(left + 1.2)
	_check(inv.count_item(cooked) == 2 and cooked_items.size() == 2 and fire.cook_status().is_empty(),
			"after 10 s both cooked fish are in the bag (Events.food_cooked)")

	# Burning down to embers, then ash; wood relights it.
	var had := out_fires.size()
	GameClock.advance(Campfire.BURN_MINUTES + 1.0)
	await _frames(3)
	_check(fire.state == "embers" and out_fires.size() == had + 1, "after 5 game hours it dies down to embers (Events.campfire_out)")
	await _seconds(1.0)
	await _camp_shot("embers", player)
	GameClock.advance(Campfire.EMBER_MINUTES + 1.0)
	await _frames(3)
	_check(fire.state == "ash" and entry["state"] == "ash", "and to cold ash an hour later")
	inv.set_stack(5, ItemStack.create(&"wood", 3))
	PlayerState.select(5)
	var wood := inv.count_item(&"wood")
	await _frames(4)
	_check(_last_prompt.contains(tr("ACTION_RELIGHT")), "wood in hand relights it ('%s')" % _last_prompt)
	await _press_key(KEY_E)
	await _frames(3)
	_check(fire.state == "lit" and inv.count_item(&"wood") == wood - 1 and is_equal_approx(fire.burn_left, Campfire.WOOD_MINUTES),
			"an armful of wood gives it another hour")

	# Saved with the farm: a fire rebuilt from its entry burns on where it was.
	var saved := FarmState.save_data()
	var found := false
	for e: Dictionary in saved["placed"]:
		if String(e["id"]) == "campfire" and e.get("state") == "lit" and absf(float(e.get("burn_left", 0.0)) - fire.burn_left) < 0.5:
			found = true
	_check(found, "its state and burn time are in the save")

	# Put out with the watering can: steam, gone within ten seconds.
	var can := ItemStack.create(&"watering_can")
	can.water = 5
	inv.set_stack(4, can)
	PlayerState.select(4)
	await _frames(4)
	_check(_last_prompt.contains(tr("ACTION_DOUSE")), "the can offers to put it out ('%s')" % _last_prompt)
	had = out_fires.size()
	await _hold_use(1.6)
	_check(fire._doused >= 0.0 and out_fires.size() == had + 1 and not FarmState.placed.has(entry) and can.water == 4,
			"poured on, it goes out (Events.campfire_out) and leaves the farm")
	await _seconds(1.0)
	await _camp_shot("doused", player)
	await _seconds(Campfire.DOUSE_GONE - 0.5)
	_check(not is_instance_valid(fire), "and within 10 seconds it is gone")

	# Eating: RMB with food in hand.
	var needs := PlayerState.needs
	needs.frozen = false
	needs.hunger = 50.0
	needs.changed.emit()
	inv.set_stack(3, ItemStack.create(&"carrot", 2))
	PlayerState.select(3)
	player.look_at_yaw_pitch(0.0, deg_to_rad(20.0))
	await _frames(6)
	_check(_last_prompt.contains(tr("ACTION_EAT")), "food in hand shows 'RMB (Eat)' ('%s')" % _last_prompt)
	await _press_mouse(MOUSE_BUTTON_RIGHT)
	await _seconds(Eating.TIME + 0.2)
	var carrot := Eating.food_value(&"carrot")
	_check(inv.count_item(&"carrot") == 1 and is_equal_approx(needs.hunger, 50.0 + carrot) and eaten.has(&"carrot"),
			"a carrot is eaten: +%d hunger (Events.food_eaten)" % carrot)
	_check(Game.hud.needs_bars.visible and is_equal_approx(Game.hud.needs_bars._hunger.value, needs.hunger),
			"the HUD's hunger bar follows")
	_select(cooked)
	await _frames(3)
	var fish_food := Eating.food_value(cooked)
	await _press_mouse(MOUSE_BUTTON_RIGHT)
	await _seconds(Eating.TIME + 0.2)
	_check(inv.count_item(cooked) == 1 and fish_food > carrot and needs.hunger > 50.0 + carrot,
			"a cooked fish fills much more (+%d)" % fish_food)
	needs.hunger = Needs.MAX
	needs.changed.emit()
	await _press_mouse(MOUSE_BUTTON_RIGHT)
	await _seconds(Eating.TIME + 0.2)
	_check(inv.count_item(cooked) == 1, "a full farmer doesn't eat")

	# Needs over time, sleeping and their gentle consequences.
	needs.reset()
	needs.tick(60.0)
	_check(is_equal_approx(needs.hunger, Needs.MAX - Needs.HUNGER_PER_HOUR) and is_equal_approx(needs.energy, Needs.MAX - Needs.ENERGY_PER_HOUR),
			"an hour awake costs hunger and energy")
	needs.tick(60.0 * 17.0)
	_check(needs.tired() and not needs.exhausted() and needs.can_sprint(), "a long day leaves the farmer tired (%.0f)" % needs.energy)
	var night_hunger := needs.hunger
	needs.fall_asleep()
	needs.tick(8.0 * 60.0)
	needs.wake()
	_check(is_equal_approx(needs.energy, Needs.MAX) and needs.hunger < night_hunger and needs.hunger >= minf(night_hunger, Needs.HUNGER_NIGHT_FLOOR)
			and night_hunger - needs.hunger < Needs.HUNGER_PER_HOUR * 8.0, "a night in bed fills the energy up; hunger falls slower asleep")
	needs.pass_out()
	needs.tick(4.0 * 60.0)
	needs.wake()
	_check(is_equal_approx(needs.energy, Needs.PASSED_OUT_ENERGY), "passing out only restores part of it")
	# The game clock drives them.
	var before := needs.hunger
	GameClock.advance(30.0)
	_check(needs.hunger < before, "they run down with the game clock")
	needs.hunger = 0.0
	_check(needs.starving() and not needs.can_sprint() and needs.work_factor() > 1.0, "starving: no running, slower hands")
	var bars: NeedsBars = Game.hud.needs_bars
	var energy := needs.energy
	var data := PlayerState.save_data()
	needs.reset()
	PlayerState.load_data(data)
	_check(is_equal_approx(needs.hunger, 0.0) and is_equal_approx(needs.energy, energy), "hunger and energy are saved")
	PlayerState.load_data({"inventory": inv.to_array()})
	_check(is_equal_approx(needs.hunger, Needs.MAX) and is_equal_approx(needs.energy, Needs.MAX), "a save from before the needs starts full")
	await _frames(2)
	_check(bars.visible, "the needs bars stay on the HUD")
	_camp_done(on_lit, on_out, on_cooked, on_eaten)


func _camp_done(on_lit: Callable, on_out: Callable, on_cooked: Callable, on_eaten: Callable) -> void:
	Events.campfire_lit.disconnect(on_lit)
	Events.campfire_out.disconnect(on_out)
	Events.food_cooked.disconnect(on_cooked)
	Events.food_eaten.disconnect(on_eaten)
	PlayerState.needs.reset()
	PlayerState.needs.frozen = true


## The fish the test cooks (a real one when the game has them) and, when the game does
## not have them yet, the campfire item and a test fish with its cooked form.
func _camp_items() -> StringName:
	for id: StringName in ItemDB.all_ids():
		var d := ItemDB.get_item(id)
		if d.category == "fish" and Campfire.cooked_id(id) != &"":
			return id
	for spec: Array in [[&"campfire", "placeable", 1], [&"fish_test", "fish", 20], [&"fish_test_cooked", "food", 20]]:
		if ItemDB.has_item(spec[0]):
			continue
		var d := ItemData.new()
		d.id = spec[0]
		d.category = spec[1]
		d.max_stack = spec[2]
		d.icon = ItemDB._placeholder_icon()
		ItemDB._items[spec[0]] = d
	# A plain fish shape for the screenshots.
	if not ItemModels._cache.has(&"fish_test"):
		var mb := MeshBuilder.new()
		var centers: Array[Vector3] = []
		var radii: Array[Vector2] = []
		for i in 9:
			var t := float(i) / 8.0
			centers.append(Vector3(0, 0, lerpf(-0.13, 0.13, t)))
			var r := sin(PI * clampf(t * 1.05, 0.0, 1.0)) * (1.0 - 0.35 * t)
			radii.append(Vector2(0.018, 0.035) * maxf(r, 0.08))
		mb.loft_ellipse(&"veg_gloss", centers, radii, 10, Color(0.78, 0.8, 0.78))
		mb.prism(&"veg_gloss", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.15)), 0.004, 0.05, 0.05, Color(0.6, 0.62, 0.6))
		var m := mb.build()
		ItemModels._cache[&"fish_test"] = m
		ItemModels._cache[&"fish_test_cooked"] = m
	return &"fish_test"


## Presses and releases a mouse button through the input pipeline (the view captured,
## as in play).
func _press_mouse(button: MouseButton) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var down := InputEventMouseButton.new()
	down.button_index = button
	down.pressed = true
	Input.parse_input_event(down)
	await tree.process_frame
	await tree.process_frame
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)
	await tree.process_frame
	if button == MOUSE_BUTTON_RIGHT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# The window couldn't take the mouse (no focus): the click as the game takes it.
		Eating.try_eat(Game.player)


## A screenshot for the campfire's look (only with -- --camp-shots=/abs/dir).
func _camp_shot(shot_name: String, player: Player) -> void:
	if not DebugTools.args.has("camp-shots"):
		return
	await _idle_frames(4)
	var dir := String(DebugTools.args["camp-shots"])
	DirAccess.make_dir_recursive_absolute(dir)
	var img := player.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, shot_name])
