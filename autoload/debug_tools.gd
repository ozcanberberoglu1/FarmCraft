extends Node
## Development helpers: automated screenshots driven by command-line arguments,
## F12 screenshots and an F3 debug overlay.
##
## Usage (arguments after `--`):
##   --shots=/abs/shots.json   JSON list of {out, pos, look | yaw+pitch, hour, wait, hud}
##   --shot=/abs/out.png       single capture from the player camera
##   --hour=13.5               start time of day
##   --freeze-time             stop the clock
##   --profile                 after 300 frames: CPU/GPU frame times and the heaviest geometry
##   --hide=TownMesh,HillForest  hide nodes by name (digits ignored), to measure their cost

var args: Dictionary = {}

var _shots: Array = []
var _shot_index := -1
var _frames_left := 0
var _capturing := false
var _done := false
var _debug_cam: Camera3D
var _bench_time := 0.0
var _bench_frames := 0
var _bench_worst := 0.0
var _bench_deltas := PackedFloat32Array()
var _overlay: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	if args.has("shots"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(args["shots"]))
		if parsed is Array:
			_shots = parsed
		else:
			push_error("DebugTools: could not parse shots file %s" % args["shots"])
	elif args.has("shot"):
		_shots = [{"out": args["shot"], "wait": int(args.get("wait", "90"))}]
	if args.has("hour"):
		GameClock.set_time_of_day(float(args["hour"]))
	if args.has("freeze-time") or is_automated():
		GameClock.running = false
	if args.has("weather"):
		Weather.force.call_deferred(Weather.Kind.keys().find(String(args["weather"]).to_upper()))
	_build_overlay()


func is_automated() -> bool:
	return not _shots.is_empty() or args.has("scenario")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("screenshot"):
		var dir := "user://screenshots"
		DirAccess.make_dir_recursive_absolute(dir)
		var path := "%s/shot_%s.png" % [dir, Time.get_datetime_string_from_system().replace(":", "-")]
		get_viewport().get_texture().get_image().save_png(path)
		Game.notify(tr("MSG_SCREENSHOT_SAVED"))
	elif event.is_action_pressed("debug_overlay"):
		_overlay.visible = not _overlay.visible


func _process(delta: float) -> void:
	if args.has("bench"):
		_update_bench(delta)
	if _overlay.visible:
		var p := Game.player.global_position if Game.player else Vector3.ZERO
		_overlay.text = "FPS %d  |  %.1f, %.1f, %.1f  |  %s  Gün %d" % [
			Engine.get_frames_per_second(), p.x, p.y, p.z, GameClock.time_string(), GameClock.day]
	if args.has("stats") and Engine.get_process_frames() == 10:
		_print_stats()
	if args.has("profile"):
		_update_profile()
	if args.has("hide") and Engine.get_process_frames() == 8:
		var names := String(args["hide"]).split(",")
		var digits := RegEx.create_from_string("[0-9_]+")
		for n in _all_nodes(get_tree().current_scene):
			if n is Node3D and digits.sub(String(n.name), "", true) in names:
				(n as Node3D).visible = false
	if args.has("scenario") and Engine.get_process_frames() == 10:
		_run_scenario(args["scenario"])
	if _shots.is_empty() or _capturing or _done:
		return
	if _shot_index < 0:
		# Give the main scene a few frames to build itself.
		if Engine.get_process_frames() < 5:
			return
		_next_shot()
		return
	_frames_left -= 1
	if _frames_left <= 0:
		if _shots[_shot_index].has("flicker"):
			_measure_flicker(_shots[_shot_index])
		else:
			_capture()


func _next_shot() -> void:
	_shot_index += 1
	if _shot_index >= _shots.size():
		_done = true
		print("DEBUG_SHOTS_DONE")
		Game.quit_game()
		return
	var shot: Dictionary = _shots[_shot_index]
	if shot.has("hour"):
		GameClock.set_time_of_day(float(shot["hour"]))
	for hud in get_tree().get_nodes_in_group("hud"):
		hud.visible = bool(shot.get("hud", true))
	var scene := get_tree().current_scene
	for path in shot.get("hide", []):
		var n := scene.get_node_or_null(NodePath(path))
		if n is Node3D:
			n.visible = false
	for path in shot.get("show", []):
		var n := scene.get_node_or_null(NodePath(path))
		if n is Node3D:
			n.visible = true
	if shot.has("env"):
		var we := scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
		if we:
			for key in shot["env"]:
				we.environment.set(key, shot["env"][key])
	if shot.has("pos"):
		_place_debug_camera(shot)
	elif _debug_cam and is_instance_valid(_debug_cam) and _debug_cam.current and Game.player:
		Game.player.camera.make_current()
	if shot.has("player"):
		var pp: Array = shot["player"]
		Game.player.global_position = Vector3(pp[0], pp[1], pp[2])
		Game.player.look_at_yaw_pitch(deg_to_rad(float(shot.get("yaw", 0.0))), deg_to_rad(float(shot.get("pitch", 0.0))))
	if shot.has("flags"):
		# One-off farm states (the house door, the drawer...): the house is rebuilt with them.
		FarmState.flags.merge(shot["flags"] as Dictionary, true)
		var house := get_tree().current_scene.find_child("FarmHouse", true, false)
		if house and house.has_method("build"):
			house.build()
	if shot.has("give"):
		for g: Array in shot["give"]:
			PlayerState.give(StringName(g[0]), int(g[1]), false)
	if shot.has("crates"):
		# {"bed": n, "warehouse": n}: hens in crates on Grandpa's pickup and in the warehouse.
		var c: Dictionary = shot["crates"]
		var town := get_tree().get_first_node_in_group(&"town") as Town
		if town and town.farm_truck and int(c.get("bed", 0)) > 0:
			town.farm_truck.cargo.add(&"chicken_crate", int(c["bed"]))
		if int(c.get("warehouse", 0)) > 0:
			FarmState.warehouse.add(&"chicken_crate", int(c["warehouse"]))
	if shot.has("select"):
		PlayerState.select(int(shot["select"]))
	if Game.player and shot.has("held_pose"):
		# [item id, 0..1 through its use animation]: freezes the held tool for pose shots.
		var hp: Array = shot["held_pose"]
		(Game.player as Player).held.debug_pose(StringName(hp[0]), float(hp[1]))
	if shot.has("bag"):
		# false: the hotbar locked as on a new farm; "reveal": play its reveal.
		if shot["bag"] is bool:
			PlayerState.hotbar_unlocked = bool(shot["bag"])
		elif String(shot["bag"]) == "reveal":
			PlayerState.hotbar_unlocked = true
			Game.hud.hotbar.reveal()
	if shot.has("waypoint"):
		var w: Array = shot["waypoint"]
		Game.hud.waypoint.target_override = Vector3(w[0], w[1], w[2])
	if shot.has("achievement"):
		var aid := StringName(String(shot["achievement"]))
		Achievements.unlocked.erase(aid)
		Achievements.unlock(aid)
	if shot.has("sale_badge"):
		Game.hud.show_sale_badge(int(shot["sale_badge"]))
	if shot.has("letter"):
		Game.hud.letter_screen.open(String(shot["letter"]))
	if shot.get("audio_report", false):
		# Which beds and loops are playing, and how loud (checks the mix without ears).
		var parts := PackedStringArray()
		for key: String in Audio._loops:
			var loop = Audio._loops[key]
			if loop.level > 0.01:
				parts.append("%s=%.2f" % [key, loop.level])
		print("AUDIO loops: %s | music: %s %s | indoors %.2f" % [", ".join(parts),
				Audio._music.playing, Audio._last_track.get_file(), Audio._indoors])
	if shot.has("place"):
		# [[id, x, z, yaw_deg, state]] where state is "", "working" or "done".
		for p: Array in shot["place"]:
			var pos := Vector3(float(p[1]), 0.0, float(p[2]))
			pos.y = TerrainData.height(pos.x, pos.z)
			var e := FarmState.add_placed(StringName(p[0]), pos, deg_to_rad(float(p[3])))
			var state: String = p[4] if p.size() > 4 else ""
			if PlaceableTable.is_building(StringName(p[0])):
				# A kit: "site" is still being built, anything else is finished.
				if state == "site":
					e["stage"] = "site"
					e["build_left"] = 120.0
			elif state != "" and String(PlaceableTable.get_info(StringName(p[0])).get("kind", "")) == "campfire":
				# A campfire's state: "laid", "lit", "embers" or "ash" (and how burnt).
				e["state"] = state
				e["char"] = float(p[5]) if p.size() > 5 else (0.0 if state == "laid" else 0.4)
				if state == "lit":
					e["burn_left"] = 240.0
			elif state != "":
				var recipe: Dictionary = RecipeTable.processing(StringName(p[0]))[0]
				e["out"] = String(recipe["out"])
				e["qty"] = 1
				e["quality"] = 0
				e["ready_at"] = GameClock.total_minutes + (-1.0 if state == "done" else 240.0)
			Game.world.farm.spawn_placed(e)
	if shot.get("sprinkle", false):
		for n in get_tree().get_nodes_in_group(&"placed"):
			if n is Sprinkler:
				(n as Sprinkler).water()
	if shot.has("manure"):
		FarmState.manure = float(shot["manure"])
		FarmState.manure_changed.emit()
	if shot.has("fertilize"):
		for plot: FarmPlot in get_tree().get_nodes_in_group(&"farm_plots"):
			if plot.soil == FarmPlot.Soil.TILLED:
				plot.fertility = int(shot["fertilize"])
				plot._refresh()
	if shot.has("plot"):
		# [bed index in field_0, FarmPlot.load_data dict, aim = true]: sets one bed for
		# crop-card shots and stands the player in front of it, looking at its soil.
		var pd: Array = shot["plot"]
		var field := get_tree().current_scene.find_child("field_0", true, false) as Field
		var bed: FarmPlot = field.plots[int(pd[0])]
		bed.load_data(pd[1])
		if pd.size() < 3 or bool(pd[2]):
			var at := bed.global_position + Vector3(0, 0.1, 2.4)
			var d := bed.global_position + Vector3(0, 0.15, 0) - (at + Vector3(0, 1.62, 0))
			Game.player.global_position = at
			Game.player.look_at_yaw_pitch(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	if shot.has("tutorial"):
		# [step or goal id, count]: show the tutorial at that goal.
		var t: Array = shot["tutorial"]
		Quests.step = Quests.index_of(String(t[0])) if t[0] is String else int(t[0])
		Quests.step_count = int(t[1])
		Quests.tutorial_changed.emit()
		Quests._nudge()
	if shot.has("note"):
		# Grandpa's note of a chapter under the goal.
		Game.hud.show_chapter_note(int(shot["note"]))
	if shot.has("farm_level"):
		Progress.level = int(shot["farm_level"])
		Progress.xp_changed.emit(Progress.xp, Progress.level)
	if shot.has("money"):
		Economy.money = int(shot["money"])
		Events.money_changed.emit(Economy.money, 0)
	if shot.has("load_slot"):
		# Rebuilds the game scene; later shots continue in the loaded game.
		SaveGame.load_game(String(shot["load_slot"]))
	if shot.has("save_slot"):
		# Saves the game as it is when this shot is taken (test save folder).
		SaveGame.snapshot()
		SaveGame.save(String(shot["save_slot"]))
	if shot.has("hand"):
		# [item id, count, hotbar slot]: puts a stack in hand.
		var h: Array = shot["hand"]
		PlayerState.inventory.set_stack(int(h[2]), ItemStack.create(StringName(h[0]), int(h[1])))
		PlayerState.select(int(h[2]))
	if shot.has("day"):
		GameClock.day = int(shot["day"])
	if shot.has("weather"):
		Weather.force(Weather.Kind.keys().find(String(shot["weather"]).to_upper()))
	elif shot.has("day"):
		Weather._snap_visuals()
	if shot.has("clock"):
		GameClock.running = bool(shot["clock"])
	if shot.has("wind"):
		Weather.wind_override = float(shot["wind"])
	if shot.has("snow"):
		Weather.snow_cover = float(shot["snow"])
	if shot.has("wet"):
		Weather.wetness = float(shot["wet"])
	if shot.get("use", false):
		Input.action_press("use")
	else:
		Input.action_release("use")
	for id in shot.get("build", []):
		if not FarmState.is_built(StringName(id)):
			FarmState.built[StringName(id)] = true
			FarmState.project_built.emit(StringName(id))
	for entry in shot.get("animals", []):
		Economy.money += 100000
		Animals.buy(StringName(entry[0]), bool(entry[1]))
	if shot.has("wet_animals"):
		for an in Animals.animals:
			an.wet = float(shot["wet_animals"])
	if shot.has("field"):
		_setup_field(String(shot["field"]))
	_setup_vehicle(shot)
	match String(shot.get("ui", "")):
		"inventory":
			Game.hud.inventory_screen.open()
		"chest":
			var chest := get_tree().current_scene.find_child("Chest", true, false)
			if chest:
				chest.interact(Game.player)
		"close":
			Game.hud.inventory_screen.close()
			Game.hud.build_screen.close_screen()
			Game.hud.shop_screen.close_screen()
			Game.hud.rancher_screen.close_screen()
			Game.hud.animal_panel.close_panel()
			Game.hud.storage_screen.hide_screen()
			Game.hud.dealer_screen.hide_screen()
			Game.hud.confirm_dialog.hide_screen()
			Game.hud.save_screen.hide_screen()
			Game.hud.crafting_screen.hide_screen()
			Game.hud.order_screen.hide_screen()
			Game.hud.letter_screen.hide_screen()
			Game.hud.level_up_screen.hide_screen()
			Game.hud.settings_screen.hide_screen()
			Game.hud.pause_menu.hide_screen()
			Game.hud.title_screen.hide_screen()
		"pause":
			Game.hud.pause_menu.show_screen()
		"settings":
			Game.hud.open_settings()
			if shot.has("tab"):
				Game.hud.settings_screen._select(String(shot["tab"]))
		"title":
			Game.hud.show_title()
			if shot.has("angle"):
				Game.hud.title_screen._angle = float(shot["angle"])
		"build":
			Game.hud.open_build_board(StringName(shot.get("focus", "")))
		"shop":
			Game.hud.open_shop(ShopStock.general_store())
		"shop_sell":
			PlayerState.inventory.add_item(&"pumpkin", 3)
			PlayerState.inventory.add_item(&"tomato", 14)
			PlayerState.inventory.add_item(&"potato", 8)
			Game.hud.open_shop(ShopStock.general_store())
			Game.hud.shop_screen._set_tab("sell")
		"rancher":
			Game.hud.open_rancher()
		"animal_panel":
			if not Animals.animals.is_empty():
				Game.hud.open_animal_panel(Animals.animals[int(shot.get("index", 0))])
		"ride":
			for an in Animals.animals:
				if an.species == &"horse" and an.adult:
					var hn := Animals.node_of(an)
					if shot.has("at"):
						var at: Array = shot["at"]
						hn.indoors = false
						hn.global_position = Vector3(at[0], at[1], at[2])
						hn.rotation.y = deg_to_rad(float(shot.get("yaw", 0.0)))
						hn.reset_physics_interpolation()
					Game.player.global_position = hn.global_position
					Game.player.mount(hn)
					if shot.has("at"):
						Game.player.look_at_yaw_pitch(hn.rotation.y, deg_to_rad(float(shot.get("pitch", -12.0))))
					break
		"storage":
			Game.hud.open_storage(_shot_vehicle(shot) if shot.get("bed", false) else null)
		"dealer":
			Game.hud.open_dealer(_town_vehicle())
		"saves":
			Game.hud.open_saves(String(shot.get("mode", "load")))
		"orders":
			Game.hud.open_orders()
		"letter":
			# "kind": "intro" or "final".
			Game.hud.letter_screen.open(String(shot.get("kind", "intro")))
		"level_up":
			Game.hud.level_up_screen.open(int(shot.get("level", 2)))
		"crafting":
			for item: Array in shot.get("give", []):
				PlayerState.inventory.add_item(StringName(item[0]), int(item[1]))
			if shot.has("level"):
				Progress.level = int(shot["level"])
			Game.hud.open_crafting()
			if shot.has("tab"):
				Game.hud.crafting_screen._tab = String(shot["tab"])
				Game.hud.crafting_screen._tabs.select(String(shot["tab"]))
				Game.hud.crafting_screen._refresh()
		"confirm":
			Game.hud.confirm_dialog.ask(tr("UI_OVERWRITE_TITLE"), tr("UI_OVERWRITE_TEXT"), tr("UI_SAVE"), Callable())
		"market_sell":
			Game.hud.open_shop(ShopStock.town_market())
			Game.hud.shop_screen._set_tab("sell")
		"sleep":
			Economy.add_money(340, "test")
			Economy.add_money(-60, "test")
			Game.hud.sleep_screen.start_sleep()
	_frames_left = int(shot.get("wait", 30))


func _town_vehicle() -> Vehicle:
	var town := get_tree().get_first_node_in_group(&"town") as Town
	return town.for_sale if town else null


## The vehicle a shot works on: the dealer's pickup, or Grandpa's with "farm_truck".
func _shot_vehicle(shot: Dictionary) -> Vehicle:
	if shot.get("farm_truck", false):
		var town := get_tree().get_first_node_in_group(&"town") as Town
		return town.farm_truck if town else null
	return _town_vehicle()


## Vehicle keys: farm_truck, own_vehicle, vehicle_at [x, y, z, yaw], clear_cargo, cargo /
## stock [[id, n]], drive, exit_vehicle, chase, throttle (-1..1), steer (-1..1).
func _setup_vehicle(shot: Dictionary) -> void:
	var v := _shot_vehicle(shot)
	if v == null:
		return
	if shot.get("own_vehicle", false):
		v.owned = true
		v.changed.emit()
	if shot.has("vehicle_at"):
		var a: Array = shot["vehicle_at"]
		v.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(float(a[3]))), Vector3(a[0], a[1], a[2])))
	if shot.get("clear_cargo", false):
		v.cargo.from_dict({"capacity": v.cargo.capacity, "items": {}})
	for e: Array in shot.get("cargo", []):
		v.cargo.add(StringName(e[0]), int(e[1]))
	for e: Array in shot.get("stock", []):
		FarmState.warehouse.add(StringName(e[0]), int(e[1]))
	if shot.get("drive", false) and Game.player.driving == null:
		Game.player.enter_vehicle(v)
	if shot.get("exit_vehicle", false) and Game.player.driving:
		Input.action_release("move_forward")
		Input.action_release("move_back")
		Game.player.exit_vehicle()
	if shot.has("chase"):
		v.chase_camera = bool(shot["chase"])
		if v.driver:
			v._snap_chase()
			v._current_camera().make_current()
	if shot.has("throttle"):
		var t := float(shot["throttle"])
		Input.action_release("move_forward")
		Input.action_release("move_back")
		if t > 0.0:
			Input.action_press("move_forward", t)
		elif t < 0.0:
			Input.action_press("move_back", -t)
	if shot.has("steer"):
		var st := float(shot["steer"])
		Input.action_release("move_left")
		Input.action_release("move_right")
		if st > 0.0:
			Input.action_press("move_left", st)
		elif st < 0.0:
			Input.action_press("move_right", -st)


func _place_debug_camera(shot: Dictionary) -> void:
	# A loaded game rebuilds the scene and frees the old camera.
	if _debug_cam == null or not is_instance_valid(_debug_cam):
		_debug_cam = Camera3D.new()
		_debug_cam.fov = float(shot.get("fov", 70.0))
		_debug_cam.far = 600.0
		_debug_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		get_tree().current_scene.add_child(_debug_cam)
	var p: Array = shot["pos"]
	_debug_cam.global_position = Vector3(p[0], p[1], p[2])
	if shot.has("look"):
		var l: Array = shot["look"]
		_debug_cam.look_at(Vector3(l[0], l[1], l[2]), Vector3.UP)
	else:
		_debug_cam.rotation = Vector3(deg_to_rad(float(shot.get("pitch", 0.0))), deg_to_rad(float(shot.get("yaw", 0.0))), 0.0)
	if shot.has("fov"):
		_debug_cam.fov = float(shot["fov"])
	_debug_cam.make_current()


func _capture() -> void:
	_capturing = true
	await RenderingServer.frame_post_draw
	var shot: Dictionary = _shots[_shot_index]
	var img := get_viewport().get_texture().get_image()
	var out: String = shot.get("out", "user://shot_%d.png" % _shot_index)
	var err := img.save_png(out)
	print("DEBUG_SHOT %s -> %s" % [out, error_string(err)])
	_capturing = false
	_next_shot()


## Flicker probe: grabs `flicker` consecutive frames (optionally advancing the clock
## by `sun_step` game minutes per frame, like normal play at 60 fps = 0.022) and
## prints the mean frame-to-frame luminance change; writes a heat map to `out`.
func _measure_flicker(shot: Dictionary) -> void:
	_capturing = true
	var frames := int(shot.get("flicker", 40))
	var step := float(shot.get("sun_step", 0.0))
	const W := 480
	const H := 270
	var imgs: Array[Image] = []
	for f in frames + 1:
		if step > 0.0:
			GameClock.minute += step
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(W, H, Image.INTERPOLATE_BILINEAR)
		img.convert(Image.FORMAT_RGB8)
		imgs.append(img)
	var acc := PackedFloat32Array()
	acc.resize(W * H)
	var prev := PackedFloat32Array()
	var total := 0.0
	for img in imgs:
		var data := img.get_data()
		var lum := PackedFloat32Array()
		lum.resize(W * H)
		for i in W * H:
			lum[i] = (0.299 * data[i * 3] + 0.587 * data[i * 3 + 1] + 0.114 * data[i * 3 + 2]) / 255.0
		if not prev.is_empty():
			for i in W * H:
				var d := absf(lum[i] - prev[i])
				acc[i] += d
				total += d
		prev = lum
	var busy := 0
	var heat := Image.create(W, H, false, Image.FORMAT_RGB8)
	for i in W * H:
		var m := acc[i] / frames
		if m > 1.5 / 255.0:
			busy += 1
		var t := clampf(m * 60.0, 0.0, 1.0)
		var base := prev[i] * 0.35
		var col := Color(base, base, base).lerp(Color(1.0, 0.25 + 0.75 * t, t * t), t)
		heat.set_pixel(i % W, i / W, col)
	var out: String = shot.get("out", "user://flicker_%d.png" % _shot_index)
	heat.save_png(out)
	print("FLICKER %s mean=%.5f busy=%.2f%%" % [shot.get("label", out.get_file()), total / (frames * W * H), 100.0 * busy / (W * H)])
	_capturing = false
	_next_shot()


func _run_scenario(scenario_name: String) -> void:
	# Loaded by path: the tests aren't part of exported builds.
	const RUNNER := "res://tests/scenario_runner.gd"
	if not ResourceLoader.exists(RUNNER):
		push_error("Scenario tests aren't included in this build.")
		get_tree().quit(1)
		return
	var runner = load(RUNNER).new(get_tree())
	await runner.run(scenario_name)
	get_tree().quit(1 if runner.failures > 0 else 0)


## Fills the starter field with crops for visual checks.
func _setup_field(mode: String) -> void:
	var field := get_tree().current_scene.find_child("field_0", true, false) as Field
	if field == null:
		return
	var layout := []
	if mode.begins_with("all:"):
		# "all:<crop>": every plot ready to harvest (a heavy field for benchmarks).
		for i in field.plots.size():
			layout.append([StringName(mode.substr(4)), 3])
	elif mode.begins_with("front:"):
		# "front:<crop>": the front row shows the crop's four stages, the rest is bare.
		for i in field.plots.size() - 4:
			layout.append(["tilled", 0])
		for st in 4:
			layout.append([StringName(mode.substr(6)), st])
	elif mode.begins_with("stages"):
		# "stages" or "stages:carrot,potato,...": each crop at its four growth stages.
		var crops: Array = [&"wheat", &"tomato", &"corn"]
		if mode.begins_with("stages:"):
			crops = Array(mode.substr(7).split(",")).map(func(c: String) -> StringName: return StringName(c))
		for crop in crops:
			for st in 4:
				layout.append([crop, st])
	else:
		layout = [[&"wheat", 3], [&"carrot", 3], [&"potato", 3], [&"tomato", 3], [&"corn", 3], [&"eggplant", 3],
			[&"strawberry", 3], [&"pumpkin", 3], ["untilled", 0], ["tilled", 0], ["wet", 0], [&"potato", -1]]
	for i in mini(layout.size(), field.plots.size()):
		var p: FarmPlot = field.plots[i]
		var entry: Array = layout[i]
		p.soil = FarmPlot.Soil.TILLED
		p.crop = &""
		p.withered = false
		p.wet_hours = 0.0
		match String(entry[0]):
			"untilled":
				p.soil = FarmPlot.Soil.UNTILLED
			"tilled":
				pass
			"wet":
				p.wet_hours = 10.0
			_:
				p.crop = entry[0]
				var st: int = entry[1]
				if st < 0:
					p.withered = true
				else:
					p.growth = p.target_hours() * (float(st) / 3.0 + (0.01 if st == 3 else 0.02))
					p.wet_hours = 5.0 if st < 3 else 0.0
		p.advance(0.0)
		p._refresh()


## Measures frame times for `--bench=seconds` after a warm-up (`--bench-warmup`,
## 2 s by default), then quits. Hitches: frames over 33 ms and 50 ms, 1% low fps.
func _update_bench(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if t < float(args.get("bench-warmup", "2")):
		return
	_bench_time += delta
	_bench_frames += 1
	_bench_worst = maxf(_bench_worst, delta)
	_bench_deltas.append(delta)
	if _bench_time >= float(args["bench"]):
		var sorted := _bench_deltas.duplicate()
		sorted.sort()
		var p99: float = sorted[int(sorted.size() * 0.99)] if sorted.size() > 0 else 0.0
		var over33 := 0
		var over50 := 0
		for d in sorted:
			over33 += int(d > 0.0334)
			over50 += int(d > 0.05)
		print("BENCH window=%s scale3d=%.2f avg_fps=%.1f low1_fps=%.1f worst_frame_ms=%.1f hitches33=%d hitches50=%d frames=%d draw_calls=%d prims=%d" % [
			DisplayServer.window_get_size(), get_tree().root.scaling_3d_scale,
			_bench_frames / _bench_time, 1.0 / maxf(p99, 0.0001), _bench_worst * 1000.0, over33, over50, _bench_frames,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		args.erase("bench")
		if not is_automated():
			Game.quit_game()


## Prints a summary of the generated world (used by automated checks).
func _print_stats() -> void:
	var scene := get_tree().current_scene
	var counts := {}
	for n in _all_nodes(scene):
		var k := n.get_class()
		counts[k] = counts.get(k, 0) + 1
	var instances := 0
	for mmi in _all_nodes(scene):
		if mmi is MultiMeshInstance3D and mmi.multimesh:
			instances += mmi.multimesh.instance_count
	print("STATS nodes=%d multimesh_instances=%d trees=%d rocks=%d" % [
		_all_nodes(scene).size(), instances,
		get_tree().get_nodes_in_group(&"trees").size(), get_tree().get_nodes_in_group(&"rocks").size()])
	print("STATS classes=", counts)
	print("STATS player=", Game.player.global_position if Game.player else "none",
		" on_floor=", Game.player.is_on_floor() if Game.player else false)
	print("STATS locale=", TranslationServer.get_locale(), " day=", tr("HUD_DAY") % 1)
	if args.get("stats") == "quit":
		Game.quit_game()


var _profile_started := false


## Frame times from the renderer and triangles per kind of geometry (instances times
## mesh triangles, grouped by node name without numbers), heaviest first.
func _update_profile() -> void:
	var vp := get_viewport().get_viewport_rid()
	if not _profile_started:
		RenderingServer.viewport_set_measure_render_time(vp, true)
		_profile_started = true
	if Engine.get_process_frames() < 300:
		return
	args.erase("profile")
	print("PROFILE cpu_ms=%.2f gpu_ms=%.2f fps=%d draw_calls=%d prims=%d" % [
		RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
		RenderingServer.viewport_get_measured_render_time_gpu(vp), Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	var groups := {}
	var digits := RegEx.create_from_string("[0-9_]+")
	for n in _all_nodes(get_tree().current_scene):
		var mesh: Mesh = null
		var count := 1
		if n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
			mesh = (n as MultiMeshInstance3D).multimesh.mesh
			count = (n as MultiMeshInstance3D).multimesh.instance_count
		elif n is MeshInstance3D:
			mesh = (n as MeshInstance3D).mesh
		if mesh == null or not (n as GeometryInstance3D).is_visible_in_tree():
			continue
		var tris := 0
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var idx = arr[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null and idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		var key := digits.sub(String(n.name), "", true)
		if tris * count > 500000 and not (n is MultiMeshInstance3D):
			var parts := PackedStringArray()
			for si in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(si)
				var idx = arr[Mesh.ARRAY_INDEX]
				var st: int = (idx.size() if idx != null and idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
				parts.append("%s=%d" % [mesh.surface_get_name(si), st])
			print("PROFILE surfaces of %s: %s" % [n.name, ", ".join(parts)])
		var g: Array = groups.get(key, [0, 0, 0, false, 0.0])
		g[0] += 1
		g[1] += count
		g[2] += tris * count
		g[3] = g[3] or (n as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g[4] = (n as GeometryInstance3D).visibility_range_end
		groups[key] = g
	var keys := groups.keys()
	keys.sort_custom(func(a, b) -> bool: return groups[a][2] > groups[b][2])
	for k in keys.slice(0, 16):
		var g: Array = groups[k]
		print("PROFILE %-22s nodes=%4d instances=%6d tris=%9d shadows=%s vis_end=%.0f" % [k, g[0], g[1], g[2], g[3], g[4]])


func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	for c in root.get_children():
		out.append_array(_all_nodes(c))
	return out


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_overlay = Label.new()
	_overlay.position = Vector2(12, 1040)
	_overlay.add_theme_color_override("font_outline_color", Color.BLACK)
	_overlay.add_theme_constant_override("outline_size", 4)
	_overlay.visible = Settings.show_fps
	layer.add_child(_overlay)
