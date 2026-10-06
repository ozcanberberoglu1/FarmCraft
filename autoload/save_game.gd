extends Node
## Saved games: three slots plus an autosave, so that continuing loses nothing: written
## every morning after sleeping (SleepScreen), a moment after a story goal is done, every
## AUTOSAVE_SECONDS of play, on going back to the title screen and on quitting (the pause
## menu's and the title's "quit", the window closed). The ones the game makes by itself
## wait until the player is free (can_autosave: no window or conversation open, not
## asleep or fainting, no pack on the farm) and are quiet (no note). "Continue" on the
## title screen loads the newest save of any slot (latest).
## One compressed file per slot: a small header (version, day, money, play time,
## date) that the slot list reads on its own, then each system's save_data(). Godot
## variants keep ids, vectors and transforms exactly.
##
## Loading applies the state the world is built from (clock, wallet, weather, farm,
## bag), rebuilds the game scene from scratch, then restores what lives in it:
## fields, troughs, animals, vehicles and where the player stands.
## Automated runs use their own folder so tests never touch the player's saves.

signal saved(slot: String)
signal loaded(slot: String)

## Bump when the format changes and convert older data in _migrate().
const VERSION := 2
const AUTO := "auto"
const SLOTS: Array[String] = ["auto", "slot_1", "slot_2", "slot_3"]
const THUMB := Vector2i(384, 216)
## Seconds of play (the pause menu and its like not counted) between the autosaves the
## game makes by itself.
const AUTOSAVE_SECONDS := 180.0
## A story goal done is saved this long after it (goals done one after another make one
## save), and never sooner than AUTOSAVE_GAP after the last save.
const AUTOSAVE_GOAL_DELAY := 1.5
const AUTOSAVE_GAP := 20.0
## Quitting waits at most this long for the save's picture to come back from the GPU.
const QUIT_THUMB_WAIT := 0.4

## Seconds played in this game (menus and loading excluded).
var play_seconds := 0.0
## True from the moment a load or new game starts until the rebuilt scene is ready.
var loading := false
## A game has been started this session (a fresh launch needs no rebuild to begin).
var started := false

var _dir := "user://saves/"
var _pending := {}
var _pending_slot := ""
## A new game is being built: Grandpa's letter waits once the world is up.
var _fresh := false
## Screens to open again once a reload in place is done (e.g. pause + settings).
var _reopen: Array = []
var _thumb: Image
## A snapshot is on its way back from the GPU.
var _thumb_pending := false
## Slots saved while it was: they get the picture when it lands.
var _thumb_slots: Array[String] = []
## Pictures being scaled down or written off the main thread (WorkerThreadPool task ids).
var _thumb_tasks: Array[int] = []
var _veil: ColorRect
## Set by tests: the game autosaves by itself in this automated run (other runs only on
## the mornings, so their checks never write a save behind their backs).
var testing_autosave := false
## Autosaves made since the game started (the mornings' not counted), and why the last
## one was made: "goal", "timer", "title" or "quit".
var autosaves := 0
var last_autosave := ""
## Seconds of play until the next autosave by the clock.
var _auto_left := AUTOSAVE_SECONDS
## A story goal was done: autosave once the player is free (and how long from now at the
## earliest).
var _auto_asked := false
var _auto_wait := 0.0
## Real seconds since the last save into any slot.
var _since_save := INF
## The story's step as last seen: a goal done is a step further.
var _quest_step := 0
## The window was asked to close: the game is saved and quits (once).
var _quitting := false
## Set by tests: save_and_quit saves and counts (quits) but the run goes on.
var testing_quit := false
var quits := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DebugTools.is_automated():
		_dir = "user://test_saves/"
	DirAccess.make_dir_recursive_absolute(_dir)
	_build_veil()
	_quest_step = Quests.step
	Quests.tutorial_changed.connect(_on_goal_changed)
	# Closing the window saves first (_notification); automated runs quit as they are.
	if not DebugTools.is_automated():
		get_tree().auto_accept_quit = false


func _process(delta: float) -> void:
	if started and not loading and Game.player and not Game.is_ui_open():
		play_seconds += delta
	_tick_autosave(delta)
	if not _thumb_tasks.is_empty():
		_reap_thumb_tasks()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not get_tree().auto_accept_quit:
		save_and_quit()


func path_of(slot: String) -> String:
	return _dir + slot + ".save"


func thumb_path(slot: String) -> String:
	return _dir + slot + ".png"


# --- Saving ------------------------------------------------------------------------------

## Keeps the current frame as the next save's picture (call before a menu covers it).
## On RenderingDevice renderers the frame is copied back without stalling the GPU
## and lands a few frames later, scaled down off the main thread (an autosave in the
## middle of play must not cost a frame); otherwise it is read at once, which stalls for
## a moment: not with `may_stall` off (the last picture stays).
func snapshot(may_stall := true) -> void:
	# Nothing is drawn when running headless (tests).
	if DisplayServer.get_name() == "headless":
		return
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var rd := RenderingServer.get_rendering_device()
	var rid := RenderingServer.texture_get_rd_texture(tex.get_rid()) if rd else RID()
	if rid.is_valid():
		var fmt := rd.texture_get_format(rid)
		if fmt.format == RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM \
				and rd.texture_get_data_async(rid, 0, _on_snapshot_read.bind(fmt.width, fmt.height)) == OK:
			_thumb_pending = true
			return
	if may_stall:
		_keep_thumb(tex.get_image())


func _on_snapshot_read(data: PackedByteArray, width: int, height: int) -> void:
	if data.size() != width * height * 4:
		_snapshot_landed(null)
		return
	# Like get_image(): an opaque viewport's picture has no alpha.
	var opaque := not get_viewport().transparent_bg
	var scale_down := func() -> void:
		var img := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)
		if opaque:
			img.convert(Image.FORMAT_RGB8)
		img.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
		_snapshot_landed.call_deferred(img)
	_thumb_tasks.append(WorkerThreadPool.add_task(scale_down))


## The snapshot is ready (null: it could not be read, the last picture stays): the slots
## saved while it was on its way get it.
func _snapshot_landed(img: Image) -> void:
	_thumb_pending = false
	if img and not img.is_empty():
		_thumb = img
	if _thumb and not _thumb_slots.is_empty():
		_write_thumb(_thumb_slots, true)
	_thumb_slots.clear()


func _keep_thumb(img: Image) -> void:
	if img == null or img.is_empty():
		return
	img.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
	_thumb = img


## Writes the kept picture as `slots`' own. `later`: off the main thread (packing a PNG
## takes several milliseconds), for the saves made in the middle of play.
func _write_thumb(slots: Array[String], later: bool) -> void:
	var img := _thumb
	var paths := PackedStringArray()
	for slot in slots:
		paths.append(ProjectSettings.globalize_path(thumb_path(slot)))
	if not later:
		for path in paths:
			img.save_png(path)
		return
	# (The picture is never changed once kept, only replaced: safe to read from a thread.)
	var write := func() -> void:
		for path in paths:
			img.save_png(path)
	_thumb_tasks.append(WorkerThreadPool.add_task(write))


## Finished picture tasks are let go of; `wait`: all of them, finished first (quitting).
func _reap_thumb_tasks(wait := false) -> void:
	for id: int in _thumb_tasks.duplicate():
		if wait or WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_thumb_tasks.erase(id)


## Writes the game into `slot`. `picture_later`: its picture is written off the main
## thread (the game's own autosaves in the middle of play).
func save(slot: String, picture_later := false) -> bool:
	if Game.player == null or loading:
		return false
	var path := path_of(slot)
	var tmp := path + ".tmp"
	var f := FileAccess.open_compressed(tmp, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		push_error("SaveGame: can't write %s (error %d)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_var(_header())
	f.store_var(_collect())
	f.close()
	# Replace the old file only once the new one is complete.
	var real := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(real)
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), real) != OK:
		push_error("SaveGame: can't move %s into place" % tmp)
		return false
	if _thumb_pending:
		_thumb_slots.append(slot)
	elif _thumb:
		var one: Array[String] = [slot]
		_write_thumb(one, picture_later)
	# Just saved: the game's own autosaves start counting again.
	_auto_left = AUTOSAVE_SECONDS
	_auto_asked = false
	_since_save = 0.0
	saved.emit(slot)
	return true


# --- Autosaves ---------------------------------------------------------------------------

## The game autosaves by itself in this run (always in play; automated runs only when a
## test asks).
func autosave_enabled() -> bool:
	return testing_autosave or not DebugTools.is_automated()


## A game is in progress and in a state a save can hold: not while loading, not in a
## faint (the morning's autosave follows it anyway).
func can_save() -> bool:
	if not started or loading or Game.player == null or not is_instance_valid(Game.player):
		return false
	return not PlayerState.knocked_out


## The game may save by itself now: the player is free (no window, conversation or letter
## open, not asleep) and no pack is on the farm (a raid is saved before it or after, never
## in the middle of its bites).
func can_autosave() -> bool:
	if not can_save() or Game.is_ui_open():
		return false
	var hud := Game.hud as HUD
	if hud == null or not is_instance_valid(hud) or hud.sleep_screen.is_busy():
		return false
	return not (String(WolfRaids.tonight.get("phase", "")) in ["active", "asleep"])


## Writes the autosave now, quietly (`reason`: "goal", "timer", "title" or "quit"). With
## no window over the game its picture is the frame as it is; under a menu, the one kept
## when the menu opened. False when nothing was saved (no game in progress, a faint...).
func autosave(reason: String) -> bool:
	if not can_save():
		return false
	if not Game.is_ui_open():
		snapshot(false)
	if not save(AUTO, true):
		return false
	autosaves += 1
	last_autosave = reason
	return true


## Saves the game in progress and quits: the pause menu's and the title's "quit", and the
## window's close button. (A fresh launch's farm behind the title screen is no game yet:
## nothing is saved.)
func save_and_quit() -> void:
	if _quitting:
		return
	_quitting = true
	if autosave_enabled():
		autosave("quit")
	# The save's picture may still be on its way back from the GPU: give it a moment,
	# and let it be written.
	var waited := 0.0
	while _thumb_pending and waited < QUIT_THUMB_WAIT:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_reap_thumb_tasks(true)
	if testing_quit:
		_quitting = false
		quits += 1
		return
	Game.quit_game()


## Going back to the title screen from the pause menu: the game in progress is saved.
func autosave_for_title() -> void:
	if autosave_enabled():
		autosave("title")


## A story goal done (the step went on): an autosave is due once the player is free.
func _on_goal_changed() -> void:
	var step := Quests.step
	if step == _quest_step:
		return
	var went_on := step > _quest_step
	_quest_step = step
	if went_on and started and not loading:
		_auto_asked = true
		_auto_wait = AUTOSAVE_GOAL_DELAY


## The autosaves the game makes by itself: after a goal, and every AUTOSAVE_SECONDS of
## play. One that is due waits for the player to be free (can_autosave).
func _tick_autosave(delta: float) -> void:
	_since_save += delta
	if not autosave_enabled() or not started or loading:
		return
	if not Game.is_paused():
		_auto_left -= delta
		_auto_wait -= delta
	var goal := _auto_asked and _auto_wait <= 0.0
	if not goal and _auto_left > 0.0:
		return
	if _since_save < AUTOSAVE_GAP or not can_autosave():
		return
	autosave("goal" if goal else "timer")


func _header() -> Dictionary:
	return {"version": VERSION, "saved_at": Time.get_unix_time_from_system(), "day": GameClock.day,
		"season": GameClock.get_season(), "day_of_season": GameClock.get_day_of_season(),
		"year": GameClock.get_year(), "minute": GameClock.minute, "money": Economy.money,
		"play_seconds": play_seconds, "animals": Animals.animals.size(), "level": Progress.level,
		"farm_name": FarmIdentity.farm_name()}


func _collect() -> Dictionary:
	var player := Game.player as Player
	# Mid-drive the player is saved standing by the door.
	var spot := player.driving.exit_point() if player.driving else player.global_position
	var vehicles := []
	for v: Vehicle in get_tree().get_nodes_in_group(Vehicle.GROUP):
		vehicles.append(v.save_data())
	return {
		"clock": GameClock.save_data(), "economy": Economy.save_data(), "weather": Weather.save_data(),
		"farm": FarmState.save_data(), "animals": Animals.save_data(), "bag": PlayerState.save_data(),
		"progress": Progress.save_data(), "achievements": Achievements.save_data(), "quests": Quests.save_data(),
		"carnival": Carnival.save_data(), "fishing_contest": FishingContest.save_data(), "relations": Relations.save_data(), "side_story": SideStory.save_data(),
		"mail": Mail.save_data(),
		"wolf_raids": WolfRaids.save_data(), "pet": Pet.save_data(),
		"plots": _collect_group(&"farm_plots"), "troughs": _collect_group(&"troughs"),
		"vehicles": vehicles, "play_seconds": play_seconds,
		"player": {"pos": spot, "yaw": player.rotation.y, "pitch": player.head.rotation.x},
	}


func _collect_group(group: StringName) -> Dictionary:
	var out := {}
	for n in get_tree().get_nodes_in_group(group):
		out[_key(n)] = n.save_data()
	return out


## Nodes are matched by where they stand: the world is generated the same way each time.
static func _key(n: Node) -> String:
	var p := (n as Node3D).global_position
	return "%.1f,%.1f" % [p.x, p.z]


# --- Slots -------------------------------------------------------------------------------

## A slot's header for the slot list; {} when the slot is empty or unreadable.
func info(slot: String) -> Dictionary:
	var f := FileAccess.open_compressed(path_of(slot), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return {}
	var header = f.get_var()
	f.close()
	return header if header is Dictionary else {}


func thumbnail(slot: String) -> Texture2D:
	var path := ProjectSettings.globalize_path(thumb_path(slot))
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	return ImageTexture.create_from_image(img) if img else null


## The most recently written slot, or "" when there are no saves.
func latest() -> String:
	var best := ""
	var when := -1.0
	for s in SLOTS:
		var h := info(s)
		if not h.is_empty() and float(h.get("saved_at", 0.0)) > when:
			best = s
			when = float(h["saved_at"])
	return best


func delete(slot: String) -> void:
	for p in [path_of(slot), thumb_path(slot)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


# --- Loading -----------------------------------------------------------------------------

func load_game(slot: String) -> bool:
	var f := FileAccess.open_compressed(path_of(slot), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	var header = f.get_var()
	var data = f.get_var()
	f.close()
	if not (header is Dictionary and data is Dictionary):
		Game.notify(tr("MSG_LOAD_FAILED"), UiTheme.RED)
		return false
	var version := int(header.get("version", 0))
	if version > VERSION:
		Game.notify(tr("MSG_SAVE_TOO_NEW"), UiTheme.RED)
		return false
	data = _migrate(data, version)
	_pending = data
	_pending_slot = slot
	_rebuild(func() -> void:
		# What the world is built from goes in before the rebuild.
		GameClock.load_data(data.get("clock", {}))
		Economy.load_data(data.get("economy", {}))
		Weather.load_data(data.get("weather", {}))
		FarmState.load_data(data.get("farm", {}))
		PlayerState.load_data(data.get("bag", {}))
		Progress.load_data(data.get("progress", {}))
		Achievements.load_data(data.get("achievements", {}))
		Quests.load_data(data.get("quests", {}))
		Carnival.load_data(data.get("carnival", {}))
		FishingContest.load_data(data.get("fishing_contest", {}))
		Relations.load_data(data.get("relations", {}))
		SideStory.load_data(data.get("side_story", {}))
		Mail.load_data(data.get("mail", {}))
		WolfRaids.load_data(data.get("wolf_raids", {}))
		Pet.load_data(data.get("pet", {}))
		play_seconds = float(data.get("play_seconds", 0.0)))
	return true


func new_game() -> void:
	_pending = {}
	_pending_slot = ""
	_fresh = true
	_rebuild(func() -> void:
		GameClock.new_game()
		Economy.new_game()
		Weather.new_game()
		FarmState.new_game()
		PlayerState.new_game()
		Progress.new_game()
		Achievements.new_game()
		Quests.new_game()
		Carnival.new_game()
		FishingContest.new_game()
		Relations.new_game()
		SideStory.new_game()
		Mail.new_game()
		WolfRaids.new_game()
		Pet.new_game()
		play_seconds = 0.0)


## Rebuilds the game scene in place, keeping the game as it is (a language change:
## every text is created in the new language). `reopen` names the screens to show
## again afterwards, bottom first ("title", "pause", "settings").
func reload_in_place(reopen: Array) -> void:
	if loading:
		return
	_reopen = reopen
	_pending = _collect() if started and Game.player else {}
	_pending_slot = ""
	_rebuild(Callable(), false)


## Older saves are brought up to the current format here, one version at a time.
func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	# v2: a new farm starts with Grandpa's run-down house and warehouse, repaired from
	# the construction board. Older games had both sound: they count as repaired.
	if from_version < 2:
		var farm: Dictionary = data.get("farm", {})
		var built: Array = farm.get("built", ["field_0"])
		for id: String in ["house_1", "warehouse_1"]:
			if not built.has(id):
				built.append(id)
		farm["built"] = built
		data["farm"] = farm
	return data


## Fades to black, applies `apply` (the state the new world is built from) out of
## sight, then rebuilds the game scene.
func _rebuild(apply: Callable, start := true) -> void:
	loading = true
	started = started or start
	# The world built next is as its save left it (or new): nothing to autosave yet.
	_auto_left = AUTOSAVE_SECONDS
	_auto_asked = false
	await _fade_veil(1.0, 0.25)
	if apply.is_valid():
		apply.call()
	Animals.new_game()
	Game.reset_ui()
	get_tree().reload_current_scene()


## Called by the game scene once it is built: restores what lives in it.
func on_world_ready() -> void:
	if not loading:
		return
	var data := _pending
	_pending = {}
	if not data.is_empty():
		Animals.load_data(data.get("animals", {}))
		_apply_group(&"farm_plots", data.get("plots", {}))
		_apply_group(&"troughs", data.get("troughs", {}))
		for vd: Dictionary in data.get("vehicles", []):
			for v: Vehicle in get_tree().get_nodes_in_group(Vehicle.GROUP):
				if String(v.kind) == String(vd.get("kind", "")):
					v.load_data(vd)
					break
		var p: Dictionary = data.get("player", {})
		if p.get("pos") is Vector3:
			Game.player.global_position = p["pos"]
			(Game.player as Player).look_at_yaw_pitch(float(p.get("yaw", 0.0)), float(p.get("pitch", 0.0)))
	loading = false
	Game.capture_mouse()
	if _pending_slot != "":
		loaded.emit(_pending_slot)
	var reopen := _reopen
	_reopen = []
	for screen: String in reopen:
		match screen:
			"title":
				Game.hud.show_title()
			"pause":
				Game.hud.pause_menu.show_screen()
			"settings":
				Game.hud.open_settings()
	var fresh := _fresh
	_fresh = false
	await _fade_veil(0.0, 0.5)
	if fresh and not DebugTools.is_automated():
		Game.hud.letter_screen.open("intro")


func _apply_group(group: StringName, saved_nodes: Dictionary) -> void:
	for n in get_tree().get_nodes_in_group(group):
		var key := _key(n)
		if saved_nodes.has(key):
			n.load_data(saved_nodes[key])


# --- Loading veil --------------------------------------------------------------------------

## A black screen with a "loading" line over the rebuild; lives here so it outlasts
## the game scene.
func _build_veil() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_veil = ColorRect.new()
	_veil.color = Color(0.03, 0.035, 0.03)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.modulate.a = 0.0
	_veil.visible = false
	layer.add_child(_veil)
	var label := UiTheme.make_label(UiTheme.caps(tr("UI_LOADING")), UiTheme.heading(26, UiTheme.TEXT_MUTED, 700, 6))
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_veil.add_child(label)


func _fade_veil(to: float, seconds: float) -> void:
	_veil.visible = true
	var tw := create_tween()
	tw.tween_property(_veil, "modulate:a", to, seconds)
	await tw.finished
	_veil.visible = to > 0.0
