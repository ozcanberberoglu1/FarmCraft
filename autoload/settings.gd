extends Node
## Player preferences, persisted to user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"
## Game languages (Godot locale codes) with their names in their own language.
const LANGUAGES := ["tr", "en", "de", "es", "fr", "it", "pt_BR", "ru", "pl", "ja", "ko", "zh_CN", "zh_TW"]
const LANGUAGE_NAMES := {
	"tr": "Türkçe", "en": "English", "de": "Deutsch", "es": "Español", "fr": "Français",
	"it": "Italiano", "pt_BR": "Português (Brasil)", "ru": "Русский", "pl": "Polski",
	"ja": "日本語", "ko": "한국어", "zh_CN": "简体中文", "zh_TW": "繁體中文",
}
## Audio buses (default_bus_layout.tres) and the setting that sets each one's volume.
const BUS_VOLUMES := {"Music": "music_volume", "Effects": "effects_volume", "Ambience": "ambience_volume", "UI": "ui_volume"}
## Graphics presets (see DayNightCycle.apply_quality for what each turns on).
enum Quality { LOW, MEDIUM, HIGH, ULTRA }
## How often wolves come to the farm at night (WolfRaids): never, now and then, or as the
## game means them to.
enum Raids { OFF, RARE, NORMAL }
## How the game takes the screen: the whole screen for itself, a borderless window over
## the whole screen (other windows come up over it at once) or an ordinary window.
enum DisplayMode { FULLSCREEN, BORDERLESS, WINDOWED }
## The engine's window mode for each (Windows and macOS). Godot's "exclusive" full screen
## is the game alone on the screen; its plain full screen is the borderless window.
const WINDOW_MODES := {
	DisplayMode.FULLSCREEN: Window.MODE_EXCLUSIVE_FULLSCREEN,
	DisplayMode.BORDERLESS: Window.MODE_FULLSCREEN,
	DisplayMode.WINDOWED: Window.MODE_WINDOWED,
}
## The sizes offered under the screen's own, when they fit on it (see resolutions).
const COMMON_RESOLUTIONS: Array[Vector2i] = [Vector2i(3840, 2160), Vector2i(2560, 1440), Vector2i(1920, 1080),
	Vector2i(1600, 900), Vector2i(1366, 768), Vector2i(1280, 720)]
## Most pixels the 3D scene is drawn at before upscaling (2560x1440). A maximized
## window on a Retina or 4K screen is 8-10 million pixels; drawing GI, fog and MSAA
## at that size costs 3x the frame time for detail the eye can barely see.
const MAX_3D_PIXELS := 2560 * 1440
## The smallest 3D scale: the upscalers (FSR 2, MetalFX) go up to three times a side.
const MIN_3D_SCALE := 0.34
## Upscaler sharpening (Viewport.fsr_sharpness: 0 sharpest .. 2 none). The temporal
## upscalers get none: their output is as sharp as the scene, and sharpening on top
## only draws halos round far branches and crackles on foliage. FSR 1's spatial
## upscale (LOW and MEDIUM in big windows) gets a light touch.
const SHARPNESS_TEMPORAL := 2.0
const SHARPNESS_SPATIAL := 1.2
## Texture mip bias per anti-aliasing kind. Godot sharpens textures under temporal AA
## and FXAA with a negative bias of its own; these take most of it back, so ground,
## bark and far leaves do not glitter in motion.
const MIP_BIAS_TEMPORAL := 0.35
const MIP_BIAS_FXAA := 0.25
## How long a day can be (real minutes, see day_length_minutes): a brisk one, the
## default and a leisurely one.
const DAY_LENGTHS: Array[float] = [8.0, 10.0, 12.0]
const DEFAULT_DAY_LENGTH := 10.0

## First launch follows the system language (see detect_language).
var language := ""
var mouse_sensitivity := 0.0022
var invert_y := false
var fov := 75.0
## How much the view jolts when a tool strikes or a tree comes down (0 = off).
var camera_shake := 1.0
var master_volume := 0.8
var music_volume := 0.55
var effects_volume := 0.9
var ambience_volume := 0.8
var ui_volume := 0.7
## Real-time minutes for one in-game day, 06:00-02:00 (20 game hours): one of
## DAY_LENGTHS (the settings offer just these; a saved value from the old 5-40 slider
## snaps to the nearest: snap_day_length).
var day_length_minutes := DEFAULT_DAY_LENGTH
var wolf_raids := Raids.NORMAL
## Big cartoon eyes on the poultry and the fish, and a few silly moments (ComicFx); off,
## the animals look as real as they can.
var comic_animals := true
## Test shortcuts (TestKeys: F6 held runs time ×30, F7 skips to the next morning, F8 is
## an hour on). On for now, while the game is being tested; to be turned off (and the
## option taken out) before release.
var test_shortcuts := true
var show_fps := false
## A new install starts in full screen; a settings file from before this choice keeps its
## full screen switch (see load_settings).
var display_mode := DisplayMode.FULLSCREEN
## The picked resolution, Vector2i.ZERO for the screen's own (whatever screen that is).
## As a window it is the window's size; in full screen and borderless the window is the
## screen and this is the size the 3D scene is drawn at before upscaling (by its height:
## see scale_3d_for), so the interface stays at the screen's own sharpness.
var resolution := Vector2i.ZERO
var vsync := true
var quality := Quality.ULTRA
## An extra 3D scale for tests and benchmarks only (-- --render-scale=0.6). It was a
## setting of its own; the resolution choice took its place, so a scale is never applied
## twice.
var render_scale := 1.0
## display19: the window follows the settings in an automated run too.
var window_in_tests := false

## The display mode and resolution the window was last put in (see _apply_window).
var _window_asked: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Physics interpolation (project setting) is opt-in per node: only bodies moved in
	# physics ticks (player, vehicles, animals, pickups) turn it on. Everything moved
	# in _process or by tweens keeps being drawn exactly where it is set.
	get_tree().root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# The 3D scale follows the window: the switch to full screen resizes it right away on
	# Windows and a moment later on macOS.
	get_tree().root.size_changed.connect(_apply_3d_scale)
	load_settings()
	apply()


func apply() -> void:
	# Screenshot and test runs can pick the language: -- --lang=ja
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			language = a.substr(7)
		# ... and the graphics preset: -- --quality=high
		elif a.begins_with("--quality=") and Quality.has(a.substr(10).to_upper()):
			quality = Quality[a.substr(10).to_upper()]
		# ... and the 3D resolution scale, to see the upscalers: -- --render-scale=0.6
		elif a.begins_with("--render-scale="):
			render_scale = clampf(a.substr(15).to_float(), 0.5, 1.0)
	if language == "":
		language = detect_language()
	TranslationServer.set_locale(language)
	UiTheme.refresh_locale()
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	for bus_name: String in BUS_VOLUMES:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(float(get(BUS_VOLUMES[bus_name])), 0.0001)))
	# The window is left alone in automated runs and headless tests.
	if manages_window():
		_apply_window()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	_apply_3d_scale()
	changed.emit()


## Whether the window follows display_mode and resolution: not in automated runs
## (scenarios, screenshots, benchmarks: they keep the project's window) nor headless.
func manages_window() -> bool:
	return DisplayServer.get_name() != "headless" and (window_in_tests or not _automated())


## The engine's window mode for the picked display mode.
func window_mode() -> Window.Mode:
	return WINDOW_MODES[display_mode]


## The size of the screen the window is on, in pixels.
func screen_size() -> Vector2i:
	var size := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	return size if size.x > 0 and size.y > 0 else get_tree().root.size


## The resolutions to pick from on a screen of `screen` pixels: its own first, then the
## common smaller ones that fit on it, largest first.
func resolutions(screen := screen_size()) -> Array[Vector2i]:
	var list: Array[Vector2i] = [screen]
	for r in COMMON_RESOLUTIONS:
		if r != screen and r.x <= screen.x and r.y <= screen.y:
			list.append(r)
	return list


## Where the picked resolution is in resolutions(): 0 for the screen's own, and for a
## size kept from another screen the largest one that is no bigger.
func resolution_index(screen := screen_size()) -> int:
	var list := resolutions(screen)
	if resolution == Vector2i.ZERO or list.has(resolution):
		return maxi(list.find(resolution), 0)
	for i in list.size():
		if list[i].x <= resolution.x and list[i].y <= resolution.y:
			return i
	return list.size() - 1


## Picks the resolution at `index` of resolutions(). The screen's own is kept as "the
## screen's own", not as its numbers, so it stays that on another screen.
func set_resolution_index(index: int, screen := screen_size()) -> void:
	var list := resolutions(screen)
	resolution = Vector2i.ZERO if index <= 0 else list[mini(index, list.size() - 1)]


## The picked resolution in pixels on a screen of `screen` pixels.
func current_resolution(screen := screen_size()) -> Vector2i:
	return resolutions(screen)[resolution_index(screen)]


## Puts the window in the picked display mode and, as an ordinary window, at the picked
## size in the middle of the desktop. Only when that choice changed (and at the start):
## a window the player dragged bigger or maximized is not pulled back by a volume slider.
func _apply_window() -> void:
	var asked := [display_mode, resolution]
	if asked == _window_asked:
		return
	_window_asked = asked
	var root := get_tree().root
	if display_mode != DisplayMode.WINDOWED:
		if root.mode != window_mode():
			root.mode = window_mode()
		return
	var was_full := root.mode == Window.MODE_FULLSCREEN or root.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	_place_window(asked)
	if was_full:
		# macOS leaves full screen with an animation; the desktop's free area and the
		# title bar are only known for sure once it is over.
		get_tree().create_timer(0.6, true, false, true).timeout.connect(_place_window.bind(asked))


## The ordinary window at the picked size, centred on the part of the screen the taskbar
## or the Dock and menu bar leave free; maximized when it would not fit there with its
## title bar (the screen's own size never does).
func _place_window(asked: Array) -> void:
	if asked != _window_asked:
		return
	var root := get_tree().root
	if root.mode != Window.MODE_WINDOWED:
		root.mode = Window.MODE_WINDOWED
	var size := current_resolution()
	var free := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	# Title bar and borders: how much bigger the window is than its picture, and where
	# the picture starts in it.
	var frame := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	var inset := DisplayServer.window_get_position() - DisplayServer.window_get_position_with_decorations()
	if size.x + frame.x > free.size.x or size.y + frame.y > free.size.y:
		root.mode = Window.MODE_MAXIMIZED
		return
	root.size = size
	root.position = free.position + (free.size - size - frame) / 2 + inset


## 3D resolution and anti-aliasing. The resolution is scale_3d_for the window.
## HIGH and ULTRA resolve edges over several frames (uses_temporal_aa): MetalFX
## temporal on Macs, FSR 2 elsewhere, at native resolution too. Alpha-cut leaves,
## grass blades and far tree pictures then read soft and still instead of crunchy and
## shimmering, and the upscale from a capped resolution stays clean. It replaces MSAA
## (MetalFX temporal cannot combine with it, FSR 2 has no use for it).
## MEDIUM: 2x MSAA (foliage shaders turn their cut-outs into coverage with it) and
## FXAA; LOW: FXAA only. Both upscale with MetalFX spatial or FSR 1 when capped.
func _apply_3d_scale() -> void:
	var root := get_tree().root
	var s := scale_3d_for(root.size)
	root.scaling_3d_scale = s
	root.use_taa = false
	if uses_temporal_aa():
		# MSAA off first: MetalFX temporal refuses to start with it on.
		root.msaa_3d = Viewport.MSAA_DISABLED
		root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_TEMPORAL if _has_rd_feature(RenderingDevice.SUPPORTS_METALFX_TEMPORAL) \
				else Viewport.SCALING_3D_MODE_FSR2
		root.fsr_sharpness = SHARPNESS_TEMPORAL
		root.texture_mipmap_bias = MIP_BIAS_TEMPORAL
		return
	if s >= 0.99:
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	elif _has_rd_feature(RenderingDevice.SUPPORTS_METALFX_SPATIAL):
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_SPATIAL
	else:
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	root.fsr_sharpness = SHARPNESS_SPATIAL
	root.msaa_3d = Viewport.MSAA_2X if quality == Quality.MEDIUM else Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	root.texture_mipmap_bias = MIP_BIAS_FXAA


## The share of a window of `size` pixels' width and height the 3D scene is drawn at
## (Viewport.scaling_3d_scale; the interface is always drawn at the window's own size).
## Two ceilings, the lower one counts (they are never multiplied):
## - MAX_3D_PIXELS, so a big window stays affordable;
## - in full screen and borderless, the picked resolution's height over the window's
##   (1920x1080 on a 2560x1440 screen: 0.75). An ordinary window is its resolution.
## render_scale (tests only) scales the result.
func scale_3d_for(size: Vector2i) -> float:
	var s := minf(1.0, sqrt(MAX_3D_PIXELS / maxf(float(size.x * size.y), 1.0)))
	if display_mode != DisplayMode.WINDOWED and manages_window():
		s = minf(s, float(current_resolution().y) / maxf(float(size.y), 1.0))
	return clampf(s * render_scale, MIN_3D_SCALE, 1.0)


## Whether the graphics preset anti-aliases over time (HIGH and ULTRA): DayNightCycle
## then lets the sky's cloud dithering vary from frame to frame, to be averaged away.
func uses_temporal_aa() -> bool:
	return quality >= Quality.HIGH


func _has_rd_feature(feature: RenderingDevice.Features) -> bool:
	var rd := RenderingServer.get_rendering_device()
	return rd != null and rd.has_feature(feature)


func _automated() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot") or a.begins_with("--scenario") or a.begins_with("--bench"):
			return true
	return false


## In-game minutes that pass per real second.
func game_minutes_per_second() -> float:
	return (20.0 * 60.0) / maxf(day_length_minutes * 60.0, 1.0)


## The day length on offer (DAY_LENGTHS) nearest to `minutes`.
static func snap_day_length(minutes: float) -> float:
	var best := DEFAULT_DAY_LENGTH
	for option: float in DAY_LENGTHS:
		if absf(option - minutes) < absf(best - minutes):
			best = option
	return best


## The game language closest to the system's (pt_PT -> pt_BR, zh_HK -> zh_TW, ...),
## English when there is none.
static func detect_language() -> String:
	var os_locale := OS.get_locale()
	if os_locale in LANGUAGES:
		return os_locale
	var lang := OS.get_locale_language()
	if lang == "zh":
		var traditional := os_locale.contains("TW") or os_locale.contains("HK") or os_locale.contains("MO") or os_locale.contains("Hant")
		return "zh_TW" if traditional else "zh_CN"
	if lang == "pt":
		return "pt_BR"
	return lang if lang in LANGUAGES else "en"


func reset_defaults() -> void:
	mouse_sensitivity = 0.0022
	invert_y = false
	fov = 75.0
	camera_shake = 1.0
	master_volume = 0.8
	music_volume = 0.55
	effects_volume = 0.9
	ambience_volume = 0.8
	ui_volume = 0.7
	day_length_minutes = DEFAULT_DAY_LENGTH
	wolf_raids = Raids.NORMAL
	comic_animals = true
	test_shortcuts = true
	show_fps = false
	display_mode = DisplayMode.FULLSCREEN
	resolution = Vector2i.ZERO
	vsync = true
	quality = Quality.ULTRA


## `path`: display19 reads a file of its own.
func load_settings(path := PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	language = cfg.get_value("general", "language", language)
	if language not in LANGUAGES:
		language = ""
	day_length_minutes = snap_day_length(float(cfg.get_value("general", "day_length_minutes", day_length_minutes)))
	wolf_raids = clampi(cfg.get_value("general", "wolf_raids", wolf_raids), Raids.OFF, Raids.NORMAL) as Raids
	comic_animals = bool(cfg.get_value("general", "comic_animals", comic_animals))
	test_shortcuts = bool(cfg.get_value("general", "test_shortcuts", test_shortcuts))
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	invert_y = cfg.get_value("controls", "invert_y", invert_y)
	fov = cfg.get_value("video", "fov", fov)
	camera_shake = clampf(float(cfg.get_value("video", "camera_shake", camera_shake)), 0.0, 1.0)
	show_fps = cfg.get_value("video", "show_fps", show_fps)
	if cfg.has_section_key("video", "display_mode"):
		display_mode = clampi(cfg.get_value("video", "display_mode", display_mode), DisplayMode.FULLSCREEN, DisplayMode.WINDOWED) as DisplayMode
		resolution = Vector2i(maxi(int(cfg.get_value("video", "resolution_width", 0)), 0), maxi(int(cfg.get_value("video", "resolution_height", 0)), 0))
	elif cfg.has_section_key("video", "fullscreen"):
		_load_old_display(bool(cfg.get_value("video", "fullscreen", false)), float(cfg.get_value("video", "render_scale", 1.0)))
	vsync = cfg.get_value("video", "vsync", vsync)
	quality = clampi(cfg.get_value("video", "quality", quality), Quality.LOW, Quality.ULTRA) as Quality
	master_volume = cfg.get_value("audio", "master_volume", master_volume)
	for key: String in BUS_VOLUMES.values():
		set(key, clampf(float(cfg.get_value("audio", key, get(key))), 0.0, 1.0))


## A settings file from before the display mode and the resolution keeps what it chose:
## its full screen switch, the window at the size the game opened at (the project's), and
## in full screen its resolution scale as the resolution nearest to it.
func _load_old_display(was_fullscreen: bool, old_scale: float, screen := screen_size()) -> void:
	display_mode = DisplayMode.FULLSCREEN if was_fullscreen else DisplayMode.WINDOWED
	resolution = Vector2i.ZERO
	var list := resolutions(screen)
	if not was_fullscreen:
		var opened := Vector2i(int(ProjectSettings.get_setting("display/window/size/window_width_override", 0)),
				int(ProjectSettings.get_setting("display/window/size/window_height_override", 0)))
		if list.has(opened):
			resolution = opened
	elif old_scale < 0.99:
		var nearest := 0
		for i in list.size():
			if absf(list[i].y - screen.y * old_scale) < absf(list[nearest].y - screen.y * old_scale):
				nearest = i
		set_resolution_index(nearest, screen)


## `path`: display19 writes a file of its own.
func save_settings(path := PATH) -> void:
	# Screenshot and test runs change settings on purpose; never keep those.
	if DebugTools.is_automated() and path == PATH:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("general", "language", language)
	cfg.set_value("general", "day_length_minutes", day_length_minutes)
	cfg.set_value("general", "wolf_raids", wolf_raids)
	cfg.set_value("general", "comic_animals", comic_animals)
	cfg.set_value("general", "test_shortcuts", test_shortcuts)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "camera_shake", camera_shake)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("video", "display_mode", display_mode)
	cfg.set_value("video", "resolution_width", resolution.x)
	cfg.set_value("video", "resolution_height", resolution.y)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("audio", "master_volume", master_volume)
	for key: String in BUS_VOLUMES.values():
		cfg.set_value("audio", key, get(key))
	cfg.save(path)
