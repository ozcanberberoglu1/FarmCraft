extends Node
## Saved games: three slots plus an autosave written every morning after sleeping.
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
var _veil: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DebugTools.is_automated():
		_dir = "user://test_saves/"
	DirAccess.make_dir_recursive_absolute(_dir)
	_build_veil()


func _process(delta: float) -> void:
	if started and not loading and Game.player and not Game.is_ui_open():
		play_seconds += delta


func path_of(slot: String) -> String:
	return _dir + slot + ".save"


func thumb_path(slot: String) -> String:
	return _dir + slot + ".png"


# --- Saving ------------------------------------------------------------------------------

## Keeps the current frame as the next save's picture (call before a menu covers it).
## On RenderingDevice renderers the frame is copied back without stalling the GPU
## and lands a few frames later; otherwise it is read at once.
func snapshot() -> void:
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
	_keep_thumb(tex.get_image())


func _on_snapshot_read(data: PackedByteArray, width: int, height: int) -> void:
	_thumb_pending = false
	if data.size() == width * height * 4:
		var img := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)
		# Like get_image(): an opaque viewport's picture has no alpha.
		if not get_viewport().transparent_bg:
			img.convert(Image.FORMAT_RGB8)
		_keep_thumb(img)
	if _thumb:
		for slot in _thumb_slots:
			_thumb.save_png(ProjectSettings.globalize_path(thumb_path(slot)))
	_thumb_slots.clear()


func _keep_thumb(img: Image) -> void:
	if img == null or img.is_empty():
		return
	img.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
	_thumb = img


func save(slot: String) -> bool:
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
		_thumb.save_png(ProjectSettings.globalize_path(thumb_path(slot)))
	saved.emit(slot)
	return true


func _header() -> Dictionary:
	return {"version": VERSION, "saved_at": Time.get_unix_time_from_system(), "day": GameClock.day,
		"season": GameClock.get_season(), "day_of_season": GameClock.get_day_of_season(),
		"year": GameClock.get_year(), "minute": GameClock.minute, "money": Economy.money,
		"play_seconds": play_seconds, "animals": Animals.animals.size(), "level": Progress.level}


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
		"carnival": Carnival.save_data(),
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
