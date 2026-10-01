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
## Most pixels the 3D scene is drawn at before upscaling (2560x1440). A maximized
## window on a Retina or 4K screen is 8-10 million pixels; drawing GI, fog and MSAA
## at that size costs 3x the frame time for detail the eye can barely see.
const MAX_3D_PIXELS := 2560 * 1440
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
## Real-time minutes for one in-game hour span of 06:00-02:00 (20 game hours).
var day_length_minutes := 15.0
var wolf_raids := Raids.NORMAL
## Big cartoon eyes on the poultry and the fish, and a few silly moments (ComicFx); off,
## the animals look as real as they can.
var comic_animals := true
var show_fps := false
var fullscreen := false
var vsync := true
var quality := Quality.ULTRA
## 3D resolution scale on top of the MAX_3D_PIXELS cap (upscaled when below 1).
var render_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Physics interpolation (project setting) is opt-in per node: only bodies moved in
	# physics ticks (player, vehicles, animals, pickups) turn it on. Everything moved
	# in _process or by tweens keeps being drawn exactly where it is set.
	get_tree().root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# Connected before apply(): on Windows the switch to fullscreen resizes the window
	# right away, inside apply(), after the 3D scale was worked out for the old size.
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
	_apply_3d_scale()
	# The window is left alone in automated runs and headless tests.
	if DisplayServer.get_name() != "headless" and not _automated():
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and not (want == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(want)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	changed.emit()


## 3D resolution and anti-aliasing. The resolution is render_scale, further lowered
## so big windows stay within MAX_3D_PIXELS.
## HIGH and ULTRA resolve edges over several frames (uses_temporal_aa): MetalFX
## temporal on Macs, FSR 2 elsewhere, at native resolution too. Alpha-cut leaves,
## grass blades and far tree pictures then read soft and still instead of crunchy and
## shimmering, and the upscale from a capped resolution stays clean. It replaces MSAA
## (MetalFX temporal cannot combine with it, FSR 2 has no use for it).
## MEDIUM: 2x MSAA (foliage shaders turn their cut-outs into coverage with it) and
## FXAA; LOW: FXAA only. Both upscale with MetalFX spatial or FSR 1 when capped.
func _apply_3d_scale() -> void:
	var root := get_tree().root
	var px := maxf(float(root.size.x * root.size.y), 1.0)
	var s := clampf(render_scale * minf(1.0, sqrt(MAX_3D_PIXELS / px)), 0.5, 1.0)
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
	day_length_minutes = 15.0
	wolf_raids = Raids.NORMAL
	comic_animals = true
	show_fps = false
	fullscreen = false
	vsync = true
	quality = Quality.ULTRA
	render_scale = 1.0


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	language = cfg.get_value("general", "language", language)
	if language not in LANGUAGES:
		language = ""
	day_length_minutes = cfg.get_value("general", "day_length_minutes", day_length_minutes)
	wolf_raids = clampi(cfg.get_value("general", "wolf_raids", wolf_raids), Raids.OFF, Raids.NORMAL) as Raids
	comic_animals = bool(cfg.get_value("general", "comic_animals", comic_animals))
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	invert_y = cfg.get_value("controls", "invert_y", invert_y)
	fov = cfg.get_value("video", "fov", fov)
	camera_shake = clampf(float(cfg.get_value("video", "camera_shake", camera_shake)), 0.0, 1.0)
	show_fps = cfg.get_value("video", "show_fps", show_fps)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	vsync = cfg.get_value("video", "vsync", vsync)
	quality = clampi(cfg.get_value("video", "quality", quality), Quality.LOW, Quality.ULTRA) as Quality
	render_scale = clampf(cfg.get_value("video", "render_scale", render_scale), 0.5, 1.0)
	master_volume = cfg.get_value("audio", "master_volume", master_volume)
	for key: String in BUS_VOLUMES.values():
		set(key, clampf(float(cfg.get_value("audio", key, get(key))), 0.0, 1.0))


func save_settings() -> void:
	# Screenshot and test runs change settings on purpose; never keep those.
	if DebugTools.is_automated():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("general", "language", language)
	cfg.set_value("general", "day_length_minutes", day_length_minutes)
	cfg.set_value("general", "wolf_raids", wolf_raids)
	cfg.set_value("general", "comic_animals", comic_animals)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "camera_shake", camera_shake)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "render_scale", render_scale)
	cfg.set_value("audio", "master_volume", master_volume)
	for key: String in BUS_VOLUMES.values():
		cfg.set_value("audio", key, get(key))
	cfg.save(PATH)
